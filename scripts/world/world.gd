extends Node2D
## World — builds the 120x90 tile world (nine 40x30 regions), bakes the
## terrain into textures, owns collision, and resolves every gardening /
## interaction action the player performs.
##
## Generation is deterministic (seeded per region), so only player-made
## changes (plots, decor, unlocks) need to be saved.

const TILE := 16
const BW := 40
const BH := 30
const W := 120
const H := 90
const HOME := Vector2i(40, 30)   ## top-left tile of the home region

enum G { GRASS, PATH, WATER, SAND, STONE, CAVE, CRYSTAL, FAIRY, RUIN, FLOWER, FARM, WALL, PLAZA, SNOW, GLASS, MAGIC, PATIO, JUNGLE, DARKGRASS }
const G_TILE := ["grass", "path", "water", "sand", "stone", "cave", "crystal", "fairy", "ruin", "flower", "farm", "wall", "plaza", "snow", "glass", "magic", "patio", "jungle", "darkgrass"]
const WALL_STYLES := ["wall_hedge", "wall_rock", "wall_cave", "wall_crystal", "wall_ruin", "wall_glass"]

const NPCScript := preload("res://scripts/world/npc.gd")

var ground := PackedByteArray()
var wstyle := PackedByteArray()
var solid := PackedByteArray()
var reserved := PackedByteArray()
var reachable := PackedByteArray()
var interact := {}          ## "x,y" -> {type, id}
var block_region := {}      ## Vector2i(gx,gy) -> region id

var ground_layer: Node2D
var garden_layer: Node2D
var ysort: Node2D
var fog_layer: Node2D
var cursor: Sprite2D
var player = null
var static_nodes: Array = []
var plant_nodes := {}
var ready_marks := {}
var decor_nodes := {}
var forage_nodes := {}
var npcs: Array = []
var lights: Array = []
var sway_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()
var _last_region := ""
var _anim_t := 0.0


func _ready() -> void:
	rng.randomize()
	for r in GameState.REGIONS:
		var d: Dictionary = GameState.REGIONS[r]
		block_region[Vector2i(d["gx"], d["gy"])] = r
	ground_layer = Node2D.new()
	ground_layer.name = "Ground"
	add_child(ground_layer)
	garden_layer = GardenLayer.new()
	garden_layer.world = self
	garden_layer.name = "Garden"
	add_child(garden_layer)
	ysort = Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	add_child(ysort)
	fog_layer = Node2D.new()
	fog_layer.z_index = 20
	add_child(fog_layer)
	cursor = Sprite2D.new()
	cursor.texture = PixelArt.ui_icon("cursor")
	cursor.z_index = 15
	cursor.centered = false
	add_child(cursor)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.6;
void vertex() {
	float top = 1.0 - UV.y;
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	VERTEX.x += sin(TIME * 2.2 + wp.x * 0.13 + wp.y * 0.07) * top * top * strength;
}"""
	sway_mat = ShaderMaterial.new()
	sway_mat.shader = sh
	Events.world_changed.connect(_on_world_changed)
	Events.inventory_changed.connect(_update_cursor_soon)
	Events.hotbar_changed.connect(_update_cursor_soon)


# ================================================================= HELPERS
static func k(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func kv(t: Vector2i) -> String:
	return "%d,%d" % [t.x, t.y]


static func parse_key(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1]))


func idx(x: int, y: int) -> int:
	return y * W + x


func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func g_at(t: Vector2i) -> int:
	if not inb(t.x, t.y):
		return G.WALL
	return ground[idx(t.x, t.y)]


func region_at(t: Vector2i) -> String:
	return block_region.get(Vector2i(clampi(t.x / BW, 0, 2), clampi(t.y / BH, 0, 2)), "home")


func region_origin(r: String) -> Vector2i:
	var d: Dictionary = GameState.REGIONS[r]
	return Vector2i(int(d["gx"]) * BW, int(d["gy"]) * BH)


func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func is_solid_tile(x: int, y: int) -> bool:
	if not inb(x, y):
		return true
	return solid[idx(x, y)] == 1


## Axis-aligned box (world px) vs solid tiles and NPCs.
func box_blocked(r: Rect2) -> bool:
	var x0 := floori(r.position.x / TILE)
	var y0 := floori(r.position.y / TILE)
	var x1 := floori((r.end.x - 0.01) / TILE)
	var y1 := floori((r.end.y - 0.01) / TILE)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if is_solid_tile(x, y):
				return true
	return false


func tillable(t: Vector2i) -> bool:
	var g := g_at(t)
	return g == G.FARM or g == G.GLASS or g == G.MAGIC


func zone_of(t: Vector2i) -> String:
	match g_at(t):
		G.GLASS: return "greenhouse"
		G.MAGIC: return "magic"
	return "farm"


func farm_rect() -> Rect2i:
	var w := 10
	var h := 6
	if GameState.has_exp("plot_1"): w = 15
	if GameState.has_exp("plot_2"): h = 10
	if GameState.has_exp("plot_3"): w = 20
	if GameState.has_exp("plot_4"): h = 12
	return Rect2i(HOME.x + 8, HOME.y + 8, w, h)


func spawn_point() -> Vector2:
	return Vector2((HOME.x + 8) * TILE, (HOME.y + 5) * TILE + 10)


# ================================================================= BUILD
func _on_world_changed() -> void:
	build()
	spawn_forage(true)


func build() -> void:
	for n in static_nodes:
		if is_instance_valid(n):
			n.queue_free()
	static_nodes.clear()
	for c in ground_layer.get_children():
		c.queue_free()
	for c in fog_layer.get_children():
		c.queue_free()
	for n in npcs:
		n.queue_free()
	npcs.clear()
	lights.clear()
	for key in plant_nodes:
		plant_nodes[key].queue_free()
	plant_nodes.clear()
	for key in ready_marks:
		ready_marks[key].queue_free()
	ready_marks.clear()
	for key in decor_nodes:
		decor_nodes[key].queue_free()
	decor_nodes.clear()
	for key in forage_nodes:
		forage_nodes[key].queue_free()
	forage_nodes.clear()
	interact.clear()
	ground.resize(W * H)
	ground.fill(G.GRASS)
	wstyle.resize(W * H)
	wstyle.fill(0)
	solid.resize(W * H)
	solid.fill(0)
	reserved.resize(W * H)
	reserved.fill(0)
	for r in GameState.REGIONS:
		_gen_region(r)
	_place_gates()
	_compute_reachable()
	_bake()
	_make_fog()
	refresh_decor()
	refresh_all_plants()
	refresh_forage()
	garden_layer.queue_redraw()


func _set_g(x: int, y: int, g: int) -> void:
	if inb(x, y):
		ground[idx(x, y)] = g
		solid[idx(x, y)] = 0


func _set_wall(x: int, y: int, style: int) -> void:
	if inb(x, y):
		ground[idx(x, y)] = G.WALL
		wstyle[idx(x, y)] = style
		solid[idx(x, y)] = 1


func _reserve_rect(r: Rect2i, pad: int = 0) -> void:
	for y in range(r.position.y - pad, r.end.y + pad):
		for x in range(r.position.x - pad, r.end.x + pad):
			if inb(x, y):
				reserved[idx(x, y)] = 1


func _free(x: int, y: int) -> bool:
	return inb(x, y) and reserved[idx(x, y)] == 0 and solid[idx(x, y)] == 0 and ground[idx(x, y)] != G.WATER and ground[idx(x, y)] != G.WALL and not interact.has(k(x, y))


func _obj(kind: String, tx: int, ty: int, fw: int = 1, fh: int = 1, is_solid: bool = true, tex: Texture2D = null, itype: String = "", iid: String = "", variant: int = 0) -> Sprite2D:
	if tex == null:
		tex = PixelArt.object_tex(kind, GameState.season, variant)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = Vector2((tx + fw / 2.0) * TILE, (ty + fh) * TILE)
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	ysort.add_child(s)
	static_nodes.append(s)
	for yy in range(ty, ty + fh):
		for xx in range(tx, tx + fw):
			if inb(xx, yy):
				if is_solid:
					solid[idx(xx, yy)] = 1
				reserved[idx(xx, yy)] = 1
				if itype != "":
					interact[k(xx, yy)] = {"type": itype, "id": iid}
	return s


func _add_light(pos: Vector2, color: Color, scale: float = 1.0) -> void:
	var l := PointLight2D.new()
	l.texture = PixelArt.light_texture()
	l.texture_scale = 0.9 * scale
	l.color = color
	l.energy = 0.0
	l.position = pos
	ysort.add_child(l)
	static_nodes.append(l)
	lights.append(l)


func _gen_region(r: String) -> void:
	var d: Dictionary = GameState.REGIONS[r]
	var gx: int = d["gx"]
	var gy: int = d["gy"]
	var o := Vector2i(gx * BW, gy * BH)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash(r + "-world")
	var base := G.GRASS
	var style := 0
	var path_g := G.PATH
	match r:
		"village": base = G.GRASS
		"flower_fields": base = G.FLOWER
		"forest": base = G.DARKGRASS
		"mushroom_caves":
			base = G.CAVE
			style = 2
			path_g = G.CAVE
		"mountains":
			base = G.STONE
			style = 1
		"fairy_garden": base = G.FAIRY
		"crystal_biome":
			base = G.CRYSTAL
			style = 3
			path_g = G.CRYSTAL
		"ancient_ruins":
			base = G.JUNGLE
			style = 4
			path_g = G.RUIN
	for y in BH:
		for x in BW:
			_set_g(o.x + x, o.y + y, base)
	for x in BW:
		_set_wall(o.x + x, o.y, style)
		_set_wall(o.x + x, o.y + BH - 1, style)
	for y in BH:
		_set_wall(o.x, o.y + y, style)
		_set_wall(o.x + BW - 1, o.y + y, style)
	# gate openings toward neighbours + cross-shaped main paths through hub (20,22)
	var has_n := gy > 0
	var has_s := gy < 2
	var has_w := gx > 0
	var has_e := gx < 2
	if has_n:
		for x in range(19, 22):
			_set_g(o.x + x, o.y, path_g)
	if has_s:
		for x in range(19, 22):
			_set_g(o.x + x, o.y + BH - 1, path_g)
	if has_w:
		for y in range(21, 24):
			_set_g(o.x, o.y + y, path_g)
	if has_e:
		for y in range(21, 24):
			_set_g(o.x + BW - 1, o.y + y, path_g)
	var x_from := 0 if has_w else 20
	var x_to := BW - 1 if has_e else 20
	for x in range(x_from, x_to + 1):
		_set_g(o.x + x, o.y + 22, path_g)
	var y_from := 0 if has_n else 22
	var y_to := BH - 1 if has_s else 22
	if r == "home":
		y_from = 0
	for y in range(y_from, y_to + 1):
		_set_g(o.x + 20, o.y + y, path_g)
	_reserve_rect(Rect2i(o.x, o.y + 20, BW, 5))
	_reserve_rect(Rect2i(o.x + 18, o.y, 5, BH))
	match r:
		"home": _gen_home(o, rr)
		"village": _gen_village(o, rr)
		"flower_fields": _gen_flower_fields(o, rr)
		"forest": _gen_forest(o, rr)
		"mushroom_caves": _gen_caves(o, rr)
		"mountains": _gen_mountains(o, rr)
		"fairy_garden": _gen_fairy(o, rr)
		"crystal_biome": _gen_crystal(o, rr)
		"ancient_ruins": _gen_ruins(o, rr)


func _pond(o: Vector2i, r: Rect2i, rim: int = G.SAND) -> void:
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			var dx := (x + 0.5 - (r.position.x + r.size.x / 2.0)) / (r.size.x / 2.0)
			var dy := (y + 0.5 - (r.position.y + r.size.y / 2.0)) / (r.size.y / 2.0)
			var dd := dx * dx + dy * dy
			if dd <= 1.0:
				_set_g(o.x + x, o.y + y, G.WATER)
				solid[idx(o.x + x, o.y + y)] = 1
			elif dd <= 1.6 and rim >= 0:
				_set_g(o.x + x, o.y + y, rim)
	_reserve_rect(Rect2i(o.x + r.position.x - 1, o.y + r.position.y - 1, r.size.x + 2, r.size.y + 2))


func _scatter(o: Vector2i, rr: RandomNumberGenerator, p: float, fn: Callable) -> void:
	for y in range(2, BH - 2):
		for x in range(2, BW - 2):
			if rr.randf() < p and _free(o.x + x, o.y + y):
				fn.call(o.x + x, o.y + y, rr)


func _noise(seed_s: String, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = hash(seed_s)
	n.frequency = freq
	return n


# ---------------------------------------------------------------- HOME
func _gen_home(o: Vector2i, rr: RandomNumberGenerator) -> void:
	# path in front of the house + to the farm
	for x in range(4, 22):
		_set_g(o.x + x, o.y + 5, G.PATH)
	for y in range(5, 8):
		_set_g(o.x + 12, o.y + y, G.PATH)
	_reserve_rect(Rect2i(o.x + 2, o.y + 1, 20, 6))
	_obj("house", o.x + 6, o.y + 2, 4, 2, true, null)
	interact[k(o.x + 7, o.y + 3)] = {"type": "bed", "id": ""}
	interact[k(o.x + 8, o.y + 3)] = {"type": "bed", "id": ""}
	_add_light(Vector2((o.x + 6.6) * TILE, (o.y + 3.3) * TILE), Color("ffd88a"), 0.6)
	_add_light(Vector2((o.x + 9.4) * TILE, (o.y + 3.3) * TILE), Color("ffd88a"), 0.6)
	_obj("well", o.x + 13, o.y + 4, 1, 1, true, null, "well")
	_obj("bin", o.x + 15, o.y + 4, 1, 1, true, null, "bin")
	_obj("sign", o.x + 17, o.y + 4, 1, 1, true, null, "sign", "home")
	# farm
	var fr := farm_rect()
	var max_fr := Rect2i(HOME.x + 8, HOME.y + 8, 20, 12)
	_reserve_rect(max_fr, 1)
	for y in range(fr.position.y, fr.end.y):
		for x in range(fr.position.x, fr.end.x):
			_set_g(x, y, G.FARM)
	# pond
	_pond(o, Rect2i(2, 24, 5, 4))
	# greenhouse
	_reserve_rect(Rect2i(o.x + 29, o.y + 1, 10, 11))
	if GameState.has_exp("greenhouse"):
		for y in range(2, 10):
			for x in range(30, 38):
				if x == 30 or x == 37 or y == 2 or y == 9:
					if not (y == 9 and (x == 33 or x == 34)):
						_set_wall(o.x + x, o.y + y, 5)
						continue
				_set_g(o.x + x, o.y + y, G.GLASS if y < 9 else G.PATH)
	else:
		_obj("construction", o.x + 33, o.y + 9, 1, 1, true, null, "construct", "greenhouse")
	# magical garden
	_reserve_rect(Rect2i(o.x + 29, o.y + 12, 10, 10))
	if GameState.has_exp("magic_garden"):
		for y in range(13, 21):
			for x in range(30, 38):
				var edge := x == 30 or x == 37 or y == 13 or y == 20
				_set_g(o.x + x, o.y + y, G.FAIRY if edge else G.MAGIC)
		for c in [Vector2i(30, 13), Vector2i(37, 13), Vector2i(30, 20), Vector2i(37, 20)]:
			_obj("giant_flower", o.x + c.x, o.y + c.y, 1, 1, true, null, "", "", c.x + c.y)
			_add_light(Vector2((o.x + c.x + 0.5) * TILE, (o.y + c.y) * TILE), Color("f0a0ff"), 0.5)
	else:
		_obj("construction", o.x + 33, o.y + 16, 1, 1, true, null, "construct", "magic_garden")
	# seed station & lab
	_reserve_rect(Rect2i(o.x + 1, o.y + 9, 6, 9))
	if GameState.has_exp("seed_station"):
		_obj("station", o.x + 3, o.y + 10, 1, 1, true, null, "station")
		_add_light(Vector2((o.x + 3.5) * TILE, (o.y + 10.5) * TILE), Color("8af0ff"), 0.4)
	else:
		_obj("construction", o.x + 3, o.y + 10, 1, 1, true, null, "construct", "seed_station")
	if GameState.has_exp("plant_lab"):
		_obj("lab", o.x + 2, o.y + 15, 2, 1, true, null, "lab")
	else:
		_obj("construction", o.x + 3, o.y + 15, 1, 1, true, null, "construct", "plant_lab")
	# patio
	_reserve_rect(Rect2i(o.x + 8, o.y + 23, 11, 6))
	if GameState.has_exp("patio"):
		for y in range(24, 29):
			for x in range(9, 18):
				_set_g(o.x + x, o.y + y, G.PATIO)
		_obj("fountain_village", o.x + 12, o.y + 26, 2, 1, true, null)
		for c in [Vector2i(9, 24), Vector2i(17, 24)]:
			_obj("lamp", c.x + o.x, c.y + o.y, 1, 1, true, PixelArt.decor_tex("lamp_post"))
			_add_light(Vector2((o.x + c.x + 0.5) * TILE, (o.y + c.y - 1) * TILE), Color("ffe08a"), 0.8)
	else:
		_obj("construction", o.x + 13, o.y + 25, 1, 1, true, null, "construct", "patio")
	# a few trees and bushes for charm
	_scatter(o, rr, 0.035, func(x, y, r2): _obj("tree", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.02, func(x, y, _r2): _obj("bush", x, y))


# ---------------------------------------------------------------- VILLAGE
func _gen_village(o: Vector2i, rr: RandomNumberGenerator) -> void:
	for y in range(9, 26):
		for x in range(11, 29):
			_set_g(o.x + x, o.y + y, G.PLAZA)
	_reserve_rect(Rect2i(o.x + 10, o.y + 2, 20, 25))
	_obj("shop", o.x + 14, o.y + 6, 4, 2, true, null)
	interact[k(o.x + 15, o.y + 7)] = {"type": "shop", "id": ""}
	interact[k(o.x + 16, o.y + 7)] = {"type": "shop", "id": ""}
	_add_light(Vector2((o.x + 14.6) * TILE, (o.y + 7.3) * TILE), Color("ffd88a"), 0.6)
	_add_light(Vector2((o.x + 17.4) * TILE, (o.y + 7.3) * TILE), Color("ffd88a"), 0.6)
	_obj("board", o.x + 22, o.y + 7, 1, 1, true, null, "board")
	_obj("sign", o.x + 24, o.y + 7, 1, 1, true, null, "sign", "village")
	_obj("fountain_village", o.x + 19, o.y + 16, 2, 1, true, null)
	if GameState.is_festival():
		_obj("stall", o.x + 12, o.y + 11, 2, 1, true, null, "festival")
		_add_light(Vector2((o.x + 13) * TILE, (o.y + 11) * TILE), Color("ffb0d0"), 0.8)
	for c in [Vector2i(11, 9), Vector2i(28, 9), Vector2i(11, 25), Vector2i(28, 25)]:
		_obj("lamp", o.x + c.x, o.y + c.y, 1, 1, true, PixelArt.decor_tex("lamp_post"))
		_add_light(Vector2((o.x + c.x + 0.5) * TILE, (o.y + c.y - 1) * TILE), Color("ffe08a"), 0.9)
	var cots := [Vector2i(3, 4), Vector2i(32, 4), Vector2i(3, 13), Vector2i(33, 13), Vector2i(3, 26), Vector2i(32, 26)]
	for i in cots.size():
		var c2: Vector2i = cots[i]
		_reserve_rect(Rect2i(o.x + c2.x - 1, o.y + c2.y - 2, 5, 5))
		_obj("cottage", o.x + c2.x, o.y + c2.y, 3, 2, true, null, "", "", i)
		_add_light(Vector2((o.x + c2.x + 0.7) * TILE, (o.y + c2.y + 1.4) * TILE), Color("ffd88a"), 0.45)
	_scatter(o, rr, 0.05, func(x, y, r2): _obj("tree", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.02, func(x, y, _r2): _obj("bush", x, y))
	# villagers
	var palettes := [
		{"shirt": Color("e06a8a"), "hair": Color("f2c860"), "has_hat": false, "pants": Color("6a4a8a")},
		{"shirt": Color("6a8ac0"), "hair": Color("8a8a8a"), "hat": Color("6a4a2a"), "band": Color("2a2a2a")},
		{"shirt": Color("f2d23a"), "hair": Color("3a2a2a"), "has_hat": false, "skin": Color("c08a60")},
		{"shirt": Color("8acf8a"), "hair": Color("c0502a"), "has_hat": false, "overalls": true},
	]
	var names := ["Rosie", "Mr. Fern", "Clover", "Hazel"]
	for i in 4:
		var n = NPCScript.new()
		n.world = self
		n.npc_name = names[i]
		n.palette = palettes[i]
		n.bounds = Rect2(Vector2((o.x + 12) * TILE, (o.y + 10) * TILE), Vector2(15 * TILE, 14 * TILE))
		n.position = Vector2((o.x + 13 + i * 4) * TILE, (o.y + 12 + (i % 2) * 8) * TILE)
		ysort.add_child(n)
		npcs.append(n)


# ---------------------------------------------------------------- WILD REGIONS
func _gen_flower_fields(o: Vector2i, rr: RandomNumberGenerator) -> void:
	_pond(o, Rect2i(6, 5, 6, 4))
	_pond(o, Rect2i(29, 10, 5, 4))
	_scatter(o, rr, 0.03, func(x, y, r2): _obj("giant_flower", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.025, func(x, y, _r2): _obj("bush", x, y))
	_scatter(o, rr, 0.015, func(x, y, r2): _obj("tree", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.01, func(x, y, _r2): _obj("decor", x, y, 1, 1, true, PixelArt.decor_tex("beehive")))


func _gen_forest(o: Vector2i, rr: RandomNumberGenerator) -> void:
	_pond(o, Rect2i(27, 5, 6, 4))
	_reserve_rect(Rect2i(o.x + 8, o.y + 7, 8, 7))
	_reserve_rect(Rect2i(o.x + 27, o.y + 24, 7, 4))
	_scatter(o, rr, 0.24, func(x, y, r2):
		if r2.randf() < 0.3:
			_obj("pine", x, y)
		else:
			_obj("tree", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.03, func(x, y, _r2): _obj("stump", x, y))
	_scatter(o, rr, 0.04, func(x, y, _r2): _obj("bush", x, y))


func _gen_caves(o: Vector2i, rr: RandomNumberGenerator) -> void:
	var n := _noise("caves", 0.11)
	for y in range(1, BH - 1):
		for x in range(1, BW - 1):
			if reserved[idx(o.x + x, o.y + y)] == 0 and n.get_noise_2d(x, y) > 0.22:
				_set_wall(o.x + x, o.y + y, 2)
	_pond(o, Rect2i(5, 5, 4, 3), G.CAVE)
	_pond(o, Rect2i(31, 9, 4, 3), G.CAVE)
	_scatter(o, rr, 0.03, func(x, y, r2):
		_obj("giant_mushroom", x, y, 1, 1, true, null, "", "", r2.randi() % 3)
		_add_light(Vector2((x + 0.5) * TILE, (y - 0.5) * TILE), [Color("ff7ac0"), Color("6ae0ff"), Color("b08aff")][r2.randi() % 3], 0.7))
	_scatter(o, rr, 0.03, func(x, y, _r2): _obj("rock", x, y))


func _gen_mountains(o: Vector2i, rr: RandomNumberGenerator) -> void:
	var n := _noise("mountains", 0.09)
	var n2 := _noise("mountains-grass", 0.07)
	for y in range(1, BH - 1):
		for x in range(1, BW - 1):
			var gx := o.x + x
			var gy := o.y + y
			if ground[idx(gx, gy)] == G.WALL:
				continue
			if ground[idx(gx, gy)] == G.STONE:
				if y < 7:
					_set_g(gx, gy, G.SNOW)
				elif n2.get_noise_2d(x, y) > 0.15:
					_set_g(gx, gy, G.GRASS)
			if reserved[idx(gx, gy)] == 0 and n.get_noise_2d(x, y) > 0.3:
				_set_wall(gx, gy, 1)
	_pond(o, Rect2i(30, 14, 4, 3))
	_scatter(o, rr, 0.06, func(x, y, _r2): _obj("pine", x, y))
	_scatter(o, rr, 0.04, func(x, y, _r2): _obj("rock", x, y))
	_scatter(o, rr, 0.012, func(x, y, _r2):
		if _free(x + 1, y):
			_obj("bigrock", x, y, 2, 1))


func _gen_fairy(o: Vector2i, rr: RandomNumberGenerator) -> void:
	_pond(o, Rect2i(26, 7, 6, 5), G.FLOWER)
	_pond(o, Rect2i(6, 25, 5, 3), G.FLOWER)
	_scatter(o, rr, 0.04, func(x, y, r2):
		_obj("giant_flower", x, y, 1, 1, true, null, "", "", r2.randi() % 3)
		if r2.randf() < 0.3:
			_add_light(Vector2((x + 0.5) * TILE, (y - 1) * TILE), Color("ffb0f0"), 0.5))
	_scatter(o, rr, 0.015, func(x, y, r2): _obj("giant_mushroom", x, y, 1, 1, true, null, "", "", r2.randi() % 3))
	_scatter(o, rr, 0.012, func(x, y, _r2): _obj("fairy_ring", x, y, 1, 1, false))
	_scatter(o, rr, 0.02, func(x, y, _r2): _obj("tree", x, y, 1, 1, true, null, "", "", 0))


func _gen_crystal(o: Vector2i, rr: RandomNumberGenerator) -> void:
	var n := _noise("crystal", 0.1)
	for y in range(1, BH - 1):
		for x in range(1, BW - 1):
			if reserved[idx(o.x + x, o.y + y)] == 0 and n.get_noise_2d(x, y) > 0.3:
				_set_wall(o.x + x, o.y + y, 3)
	_pond(o, Rect2i(8, 8, 5, 4), G.CRYSTAL)
	_scatter(o, rr, 0.05, func(x, y, r2):
		_obj("crystal_rock", x, y, 1, 1, true, null, "", "", r2.randi() % 3)
		if r2.randf() < 0.4:
			_add_light(Vector2((x + 0.5) * TILE, (y - 0.5) * TILE), [Color("c0a0ff"), Color("a0e0ff"), Color("ffa0e0")][r2.randi() % 3], 0.6))


func _gen_ruins(o: Vector2i, rr: RandomNumberGenerator) -> void:
	for rect in [Rect2i(7, 4, 11, 8), Rect2i(24, 13, 11, 6), Rect2i(5, 24, 10, 4)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if ground[idx(o.x + x, o.y + y)] != G.WALL:
					_set_g(o.x + x, o.y + y, G.RUIN)
		for x in range(rect.position.x, rect.end.x, 3):
			if _free(o.x + x, o.y + rect.position.y):
				_obj("pillar", o.x + x, o.y + rect.position.y, 1, 1, true, null, "", "", x)
	for i in 5:
		var sx := rr.randi_range(3, 34)
		var sy := rr.randi_range(3, 26)
		for j in rr.randi_range(3, 6):
			if reserved[idx(o.x + sx + j, o.y + sy)] == 0:
				_set_wall(o.x + sx + j, o.y + sy, 4)
	_obj("bones", o.x + 29, o.y + 5, 2, 1)
	_pond(o, Rect2i(30, 23, 5, 3))
	_scatter(o, rr, 0.12, func(x, y, r2): _obj("tree", x, y, 1, 1, true, null, "", "", 1 if r2.randf() < 0.8 else 0))
	_scatter(o, rr, 0.03, func(x, y, _r2): _obj("bush", x, y))


func _place_gates() -> void:
	for r in GameState.REGIONS:
		if r in GameState.unlocked:
			continue
		var d: Dictionary = GameState.REGIONS[r]
		var o := region_origin(r)
		var gx: int = d["gx"]
		var gy: int = d["gy"]
		var spots := []
		if gy > 0:
			for x in range(19, 22): spots.append(Vector2i(o.x + x, o.y))
		if gy < 2:
			for x in range(19, 22): spots.append(Vector2i(o.x + x, o.y + BH - 1))
		if gx > 0:
			for y in range(21, 24): spots.append(Vector2i(o.x, o.y + y))
		if gx < 2:
			for y in range(21, 24): spots.append(Vector2i(o.x + BW - 1, o.y + y))
		for s in spots:
			_obj("gate", s.x, s.y, 1, 1, true, null, "gate", r)


func _compute_reachable() -> void:
	reachable.resize(W * H)
	reachable.fill(0)
	var start := tile_of(spawn_point())
	var q: Array[Vector2i] = [start]
	reachable[idx(start.x, start.y)] = 1
	var head := 0
	while head < q.size():
		var t: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if inb(n.x, n.y) and reachable[idx(n.x, n.y)] == 0 and solid[idx(n.x, n.y)] == 0:
				reachable[idx(n.x, n.y)] = 1
				q.append(n)


func _bake() -> void:
	var season := GameState.season
	for r in GameState.REGIONS:
		var o := region_origin(r)
		var im := Image.create(BW * TILE, BH * TILE, false, Image.FORMAT_RGBA8)
		for y in BH:
			for x in BW:
				var gx := o.x + x
				var gy := o.y + y
				var g: int = ground[idx(gx, gy)]
				var kind: String = G_TILE[g]
				if g == G.WALL:
					kind = WALL_STYLES[wstyle[idx(gx, gy)]]
				var variant := (gx * 7 + gy * 13 + gx * gy) % 4
				im.blit_rect(PixelArt.tile(kind, variant, season), Rect2i(0, 0, TILE, TILE), Vector2i(x * TILE, y * TILE))
				if g == G.WATER:
					if g_at(Vector2i(gx, gy - 1)) != G.WATER:
						im.fill_rect(Rect2i(x * TILE, y * TILE, TILE, 2), Color("a8d8f8") if season != 3 else Color("e8f4ff"))
					if g_at(Vector2i(gx - 1, gy)) != G.WATER:
						im.fill_rect(Rect2i(x * TILE, y * TILE, 1, TILE), Color("3a78b8"))
				elif g != G.WALL and g_at(Vector2i(gx, gy - 1)) == G.WALL:
					im.fill_rect(Rect2i(x * TILE, y * TILE, TILE, 3), Color(0, 0, 0, 0.18))
					for xx in TILE:
						var c := im.get_pixel(x * TILE + xx, y * TILE)
						im.set_pixel(x * TILE + xx, y * TILE, c.darkened(0.25))
						im.set_pixel(x * TILE + xx, y * TILE + 1, c.darkened(0.15))
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(o.x * TILE, o.y * TILE)
		s.texture = ImageTexture.create_from_image(im)
		ground_layer.add_child(s)


func _make_fog() -> void:
	for r in GameState.REGIONS:
		if r in GameState.unlocked:
			continue
		var o := region_origin(r)
		var poly := Polygon2D.new()
		var p0 := Vector2(o.x * TILE, o.y * TILE)
		var sz := Vector2(BW * TILE, BH * TILE)
		poly.polygon = PackedVector2Array([p0, p0 + Vector2(sz.x, 0), p0 + sz, p0 + Vector2(0, sz.y)])
		poly.color = Color(0.05, 0.06, 0.1, 0.62)
		fog_layer.add_child(poly)
		var lock := Sprite2D.new()
		lock.texture = PixelArt.ui_icon("lock")
		lock.scale = Vector2(4, 4)
		lock.position = p0 + sz / 2
		fog_layer.add_child(lock)


# ================================================================= PLANTS / DECOR / FORAGE
func refresh_all_plants() -> void:
	for key in plant_nodes.keys():
		if not GameState.plots.has(key):
			plant_nodes[key].queue_free()
			plant_nodes.erase(key)
	for key in GameState.plots:
		refresh_plot(key)
	garden_layer.queue_redraw()


func refresh_plot(key: String) -> void:
	var p: Dictionary = GameState.plots.get(key, {})
	var t := parse_key(key)
	if p.is_empty() or p.get("plant", "") == "":
		if plant_nodes.has(key):
			plant_nodes[key].queue_free()
			plant_nodes.erase(key)
		if ready_marks.has(key):
			ready_marks[key].queue_free()
			ready_marks.erase(key)
		garden_layer.queue_redraw()
		return
	var st := GameState.plot_stage(p)
	var s: Sprite2D = plant_nodes.get(key)
	if s == null:
		s = Sprite2D.new()
		s.material = sway_mat
		ysort.add_child(s)
		plant_nodes[key] = s
	s.texture = PixelArt.plant_tex(p["plant"], st)
	s.position = Vector2(t.x * TILE + 8, t.y * TILE + 15)
	s.offset = Vector2(0, -12)
	s.modulate = Color(1, 1, 1) if GameState.growth_block(p) == "" else Color(0.78, 0.72, 0.66)
	if st == 4 and not ready_marks.has(key):
		var m := Sprite2D.new()
		m.texture = PixelArt.ui_icon("star")
		m.scale = Vector2(0.32, 0.32)
		m.modulate = Color(1, 1, 1, 0.85)
		m.z_index = 10
		m.position = Vector2(t.x * TILE + 8, t.y * TILE - 10)
		add_child(m)
		ready_marks[key] = m
	elif st != 4 and ready_marks.has(key):
		ready_marks[key].queue_free()
		ready_marks.erase(key)
	garden_layer.queue_redraw()


func refresh_decor() -> void:
	for key in decor_nodes:
		decor_nodes[key].queue_free()
	decor_nodes.clear()
	for key in GameState.decor:
		var id: String = GameState.decor[key]
		if not ItemDB.items.has(id):
			continue
		var it: Dictionary = ItemDB.items[id]
		var t := parse_key(key)
		if it.get("floor", false):
			continue
		var tex := PixelArt.decor_tex(id)
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(t.x * TILE + 8, (t.y + 1) * TILE)
		s.offset = Vector2(0, -tex.get_height() / 2.0)
		ysort.add_child(s)
		decor_nodes[key] = s
		if it.get("solid", false):
			solid[idx(t.x, t.y)] = 1
		if it.get("light", false):
			var l := PointLight2D.new()
			l.texture = PixelArt.light_texture()
			l.texture_scale = 0.7
			l.color = it["c2"].lightened(0.2)
			l.position = Vector2(8, -tex.get_height() + 4)
			l.energy = 0.0
			s.add_child(l)
			lights.append(l)
	garden_layer.queue_redraw()


func spawn_forage(only_new_regions: bool = false) -> void:
	if not only_new_regions:
		GameState.forage.clear()
	var have := {}
	for key in GameState.forage:
		have[GameState.forage[key]["region"]] = true
	for r in GameState.unlocked:
		if only_new_regions and have.has(r):
			continue
		var o := region_origin(r)
		var cands := []
		for y in range(1, BH - 1):
			for x in range(1, BW - 1):
				var t := Vector2i(o.x + x, o.y + y)
				var g := g_at(t)
				if g == G.WALL or g == G.WATER or g == G.PATH or g == G.PLAZA or tillable(t) or g == G.PATIO:
					continue
				var i := idx(t.x, t.y)
				if solid[i] == 1 or reachable[i] == 0 or interact.has(kv(t)) or GameState.decor.has(kv(t)):
					continue
				if t.distance_to(tile_of(spawn_point())) < 3:
					continue
				cands.append(t)
		var n := 3 if r in ["home", "village"] else 11
		for j in n:
			if cands.is_empty():
				break
			var t2: Vector2i = cands.pop_at(GameState.rng.randi_range(0, cands.size() - 1))
			var kind: String = GameState.REGIONS[r]["forage"]
			if r in ["mountains", "ancient_ruins"] and GameState.rng.randf() < 0.35:
				kind = "dig"
			GameState.forage[kv(t2)] = {"region": r, "kind": kind}
	refresh_forage()


func refresh_forage() -> void:
	for key in forage_nodes:
		forage_nodes[key].queue_free()
	forage_nodes.clear()
	for key in GameState.forage:
		var f: Dictionary = GameState.forage[key]
		var t := parse_key(key)
		var s := Sprite2D.new()
		s.texture = PixelArt.forage_tex(f["kind"], GameState.season)
		s.position = Vector2(t.x * TILE + 8, (t.y + 1) * TILE - 1)
		s.offset = Vector2(0, -8)
		ysort.add_child(s)
		forage_nodes[key] = s


# ================================================================= RUNTIME
func _process(delta: float) -> void:
	_anim_t += delta
	var night := 1.0 - GameState.daylight()
	for l in lights:
		if is_instance_valid(l):
			l.energy = night * 1.1
			l.enabled = night > 0.02
	for key in ready_marks:
		var m: Sprite2D = ready_marks[key]
		var t := parse_key(key)
		m.position.y = t.y * TILE - 12 + sin(_anim_t * 3.0 + t.x) * 1.5
	for key in forage_nodes:
		var s: Sprite2D = forage_nodes[key]
		s.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.0), 0.5 + 0.5 * sin(_anim_t * 3.0 + s.position.x))
	sway_mat.set_shader_parameter("strength", 1.6 if GameState.weather == "windy" else 0.55)
	if player:
		var r := region_at(tile_of(player.position))
		if r != _last_region:
			_last_region = r
			Events.region_entered.emit(r)
		_update_cursor()


var _cursor_dirty := true


func _update_cursor_soon() -> void:
	_cursor_dirty = true


func _update_cursor() -> void:
	var t: Vector2i = player.target_tile()
	cursor.position = Vector2(t.x * TILE, t.y * TILE)
	var label := resolve(t, player.facing, false)
	cursor.visible = label != "" and player.input_enabled
	cursor.modulate = Color(1, 1, 1, 0.55 + 0.35 * sin(_anim_t * 6.0))
	player.action_label = label


func npc_at(t: Vector2i):
	for n in npcs:
		if is_instance_valid(n) and tile_of(n.position) == t:
			return n
	return null


func npc_blocks(r: Rect2) -> bool:
	for n in npcs:
		if is_instance_valid(n) and Rect2(n.position + Vector2(-5, -4), Vector2(10, 5)).intersects(r):
			return true
	return false


# ================================================================= ACTIONS
## Resolves what the action key does on tile t. If do_it is false it only
## returns the label shown in the HUD ("Water", "Harvest Tulip", ...).
func resolve(t: Vector2i, facing: Vector2i, do_it: bool) -> String:
	var key := kv(t)
	var hb: String = GameState.hotbar_key
	var npc = npc_at(t)
	if npc:
		if do_it:
			npc.talk()
		return "Talk to " + npc.npc_name
	if interact.has(key):
		var it: Dictionary = interact[key]
		match it["type"]:
			"bed":
				if do_it: Events.open_panel.emit("confirm_sleep", null)
				return "Sleep (end day)"
			"shop":
				if do_it: Events.open_panel.emit("shop", "seeds")
				return "Shop"
			"board":
				if do_it: Events.open_panel.emit("requests", null)
				return "Request Board"
			"bin":
				if do_it: Events.open_panel.emit("shop", "sell")
				return "Shipping Bin (sell)"
			"well":
				if do_it: _refill()
				return "Refill Watering Can"
			"station":
				if do_it:
					var s := GameState.collect_station()
					if s != "":
						Events.discovery_popup.emit(s, "Seed Station produced:")
					else:
						Events.toast.emit("Next rare seed in %d day(s)." % max(1, 3 - GameState.station_days), Color("9fd4ff"))
				return "Collect Rare Seed" if GameState.station_ready() else "Seed Station"
			"lab":
				if do_it: Events.open_panel.emit("lab", null)
				return "Plant Laboratory"
			"construct":
				if do_it: Events.open_panel.emit("confirm_expansion", it["id"])
				return "Build: " + GameState.expansion_def(it["id"]).get("name", "?")
			"gate":
				if do_it: Events.open_panel.emit("confirm_region", it["id"])
				return "Unlock " + ItemDB.REGION_NAMES[it["id"]]
			"festival":
				if do_it: Events.open_panel.emit("shop", "festival")
				return ItemDB.FESTIVAL_NAMES[GameState.season] + " Stall"
			"sign":
				if do_it:
					if it["id"] == "home":
						Events.toast.emit("Your garden. Till the meadow, plant seeds, water daily!", Color("ffe8b0"))
					else:
						Events.toast.emit("Willowbrook Village - shop, requests & festivals on day %d." % ItemDB.FESTIVAL_DAY, Color("ffe8b0"))
				return "Read Sign"
	if GameState.forage.has(key):
		var f: Dictionary = GameState.forage[key]
		if do_it:
			_collect_forage(key)
		return "Dig Up" if f["kind"] == "dig" else "Forage"
	if g_at(t) == G.WATER:
		if do_it:
			_refill()
		return "Refill Watering Can"
	if GameState.plots.has(key):
		var p: Dictionary = GameState.plots[key]
		var st := GameState.plot_stage(p)
		if st == 4:
			if do_it: _harvest(t, facing)
			return "Harvest " + ItemDB.items[p["plant"]]["name"]
		if ItemDB.is_fertilizer(hb) and p.get("fert", "") == "":
			if do_it: _fertilize(t, facing, hb)
			return "Apply " + ItemDB.display_name(hb)
		if p.get("plant", "") == "" and ItemDB.is_seed(hb):
			if do_it: _plant(t, facing, hb)
			return "Plant " + ItemDB.display_name(hb)
		if not p.get("watered", false):
			if do_it: _water(t, facing)
			return "Water"
		if p.get("plant", "") != "":
			var why := GameState.growth_block(p)
			return why if why != "" else "Growing..."
		return "Select seeds (Q/E)"
	if tillable(t) and not GameState.decor.has(key):
		if do_it: _till(t, facing)
		return "Till Soil"
	if ItemDB.is_decor(hb) and can_place_decor(t):
		if do_it: _place_decor(t, hb)
		return "Place " + ItemDB.display_name(hb)
	return ""


## Secondary action (X): pick up decor / clear a plot.
func secondary(t: Vector2i) -> void:
	var key := kv(t)
	if GameState.decor.has(key):
		var id: String = GameState.decor[key]
		GameState.decor.erase(key)
		GameState.add_item(id, 1, false)
		solid[idx(t.x, t.y)] = 0
		refresh_decor()
		Events.toast.emit("Picked up " + ItemDB.items[id]["name"], Color("e8e0d0"))
	elif GameState.plots.has(key):
		var p: Dictionary = GameState.plots[key]
		if p.get("plant", "") != "":
			Events.toast.emit("Removed " + ItemDB.items[p["plant"]]["name"], Color("e8e0d0"))
			p["plant"] = ""
			p["age"] = 0
		else:
			GameState.plots.erase(key)
		refresh_plot(key)


func area(t: Vector2i, facing: Vector2i, lv: int) -> Array:
	var out := []
	var side := Vector2i(-facing.y, facing.x)
	for o in GameState.tool_pattern(lv):
		out.append(t + facing * o.x + side * o.y)
	return out


func _refill() -> void:
	GameState.water = GameState.capacity()
	Events.water_changed.emit(GameState.water, GameState.capacity())
	Events.toast.emit("Watering can refilled!", Color("9fd4ff"))
	player.play_tool("water")


func _till(t: Vector2i, facing: Vector2i) -> void:
	var n := 0
	for a in area(t, facing, GameState.tool_level("shovel")):
		var key := kv(a)
		if tillable(a) and not GameState.plots.has(key) and not GameState.decor.has(key) and not is_solid_tile(a.x, a.y):
			if GameState.forage.has(key):
				continue
			GameState.plots[key] = {"plant": "", "age": 0, "watered": GameState.weather == "rain" and zone_of(a) == "farm", "fert": "", "zone": zone_of(a)}
			n += 1
	if n > 0:
		player.play_tool("shovel")
		garden_layer.queue_redraw()


func _water(t: Vector2i, facing: Vector2i) -> void:
	if GameState.water <= 0:
		Events.toast.emit("Out of water! Refill at the well or a pond.", Color("ff9a7a"))
		return
	var n := 0
	for a in area(t, facing, GameState.tool_level("watering_can")):
		var key := kv(a)
		if GameState.water <= 0:
			break
		if GameState.plots.has(key) and not GameState.plots[key].get("watered", false):
			GameState.plots[key]["watered"] = true
			GameState.water -= 1
			n += 1
	if n > 0:
		player.play_tool("water")
		Events.water_changed.emit(GameState.water, GameState.capacity())
		garden_layer.queue_redraw()


func _plant(t: Vector2i, facing: Vector2i, seed: String) -> void:
	var pid := seed.substr(5)
	var it: Dictionary = ItemDB.items[pid]
	var warned := false
	var n := 0
	var pouch := GameState.tool_level("seed_pouch")
	for a in area(t, facing, pouch):
		var key := kv(a)
		if GameState.count(seed) <= 0:
			break
		if not GameState.plots.has(key) or GameState.plots[key].get("plant", "") != "":
			continue
		var p: Dictionary = GameState.plots[key]
		if p.get("zone", "farm") == "farm" and not ItemDB.in_season(pid, GameState.season):
			if not warned:
				Events.toast.emit("%s only grows in %s outdoors. Try a Greenhouse!" % [it["name"], ItemDB.season_text(pid)], Color("ffb07a"))
				warned = true
			continue
		p["plant"] = pid
		p["age"] = 0
		if GameState.rng.randf() >= (pouch - 1) * 0.08:
			GameState.remove_item(seed, 1)
		GameState.stats["planted"] += 1
		n += 1
		refresh_plot(key)
	if n > 0:
		player.play_tool("seed")
		if it["needs"] != "" and GameState.plots[kv(t)].get("fert", "") != it["needs"]:
			Events.toast.emit("%s needs %s to grow!" % [it["name"], ItemDB.items[it["needs"]]["name"]], Color("ffd07a"))


func _fertilize(t: Vector2i, facing: Vector2i, fert: String) -> void:
	var lv := GameState.tool_level("spreader")
	var n := 0
	for a in area(t, facing, lv):
		var key := kv(a)
		if GameState.count(fert) <= 0:
			break
		if GameState.plots.has(key) and GameState.plots[key].get("fert", "") == "":
			GameState.plots[key]["fert"] = fert
			if GameState.rng.randf() >= (lv - 1) * 0.1:
				GameState.remove_item(fert, 1)
			n += 1
			refresh_plot(key)
	if n > 0:
		player.play_tool("seed")
		garden_layer.queue_redraw()


func _harvest(t: Vector2i, facing: Vector2i) -> void:
	var lv := GameState.tool_level("sickle")
	var total := 0
	for a in area(t, facing, lv):
		var key := kv(a)
		if not GameState.plots.has(key):
			continue
		var p: Dictionary = GameState.plots[key]
		if GameState.plot_stage(p) != 4:
			continue
		var pid: String = p["plant"]
		var it: Dictionary = ItemDB.items[pid]
		var yield_n := 1
		if p.get("fert", "") == "quality_fertilizer":
			yield_n += 1
		if GameState.rng.randf() < (lv - 1) * 0.15:
			yield_n += 1
		var new_entry := int(GameState.discovered.get(pid, 0)) < 2
		GameState.add_item(pid, yield_n)
		if new_entry:
			Events.discovery_popup.emit(pid, "New plant discovered!")
		GameState.add_xp(ItemDB.HARVEST_XP[it["rarity"]])
		GameState.stats["harvests"] += 1
		total += yield_n
		# Golden & Rainbow mutations (flowers only)
		if it["cat"] == "flower":
			var mult := 1.0 + (lv - 1) * 0.15
			if p.get("fert", "") == "magic_mulch": mult *= 3.0
			if p.get("zone", "") == "magic": mult *= 1.6
			if GameState.count("four_leaf_clover") > 0: mult *= 1.25
			var roll := GameState.rng.randf()
			var mut := ""
			if roll < 0.012 * mult:
				mut = "rainbow_" + pid
			elif roll < 0.05 * mult:
				mut = "golden_" + pid
			if mut != "":
				var first := int(GameState.discovered.get(mut, 0)) < 2
				GameState.add_item(mut, 1, false)
				GameState.stats["mutations"] += 1
				if first:
					GameState.add_xp(ItemDB.DISCOVER_XP[ItemDB.rarity_of(mut)])
					Events.item_discovered.emit(mut)
				Events.discovery_popup.emit(mut, "MUTATION!")
		# Seeds back
		if GameState.rng.randf() < 0.35 + GameState.tool_level("seed_pouch") * 0.03:
			GameState.add_item("seed:" + pid, 1, false)
		if int(it["regrow"]) > 0:
			p["age"] = max(0, int(it["days"]) - int(it["regrow"]))
		else:
			p["plant"] = ""
			p["age"] = 0
			p["fert"] = ""
		refresh_plot(key)
	if total > 0:
		player.play_tool("sickle")
		Events.toast.emit("+%d harvested" % total, Color("c8f0a0"))


func _collect_forage(key: String) -> void:
	var f: Dictionary = GameState.forage[key]
	var dig: bool = f["kind"] == "dig"
	if dig and GameState.tool_level("shovel") < 3:
		Events.toast.emit("The ground is too hard. You need a Silver Shovel to dig here.", Color("ffb07a"))
		return
	var table: Array = ItemDB.forage_table(f["region"])
	if dig:
		table = table.filter(func(e): return ItemDB.rarity_of(e[0]) >= 1)
		if f["region"] == "ancient_ruins":
			for id in ItemDB.plant_ids:
				if ItemDB.items[id]["cat"] == "ancient":
					table.append(["seed:" + id, 6.0])
	var bag := GameState.tool_level("collection_bag")
	var luck := (bag - 1) * 0.35 + (0.8 if dig else 0.0)
	var rolls := 1
	if GameState.rng.randf() < (bag - 1) * 0.22:
		rolls += 1
	var got_text := []
	for i in rolls:
		var got := GameState.roll_loot(table, luck)
		if got == "":
			continue
		var qty := 2 if ItemDB.is_fertilizer(got) else 1
		var is_new := false
		if ItemDB.is_seed(got):
			is_new = int(GameState.discovered.get(got.substr(5), 0)) == 0
		else:
			is_new = int(GameState.discovered.get(got, 0)) < 2
		GameState.add_item(got, qty)
		if is_new and ItemDB.rarity_of(got) >= 2:
			Events.discovery_popup.emit(got, "Rare find!")
		got_text.append("+%d %s" % [qty, ItemDB.display_name(got)])
	GameState.forage.erase(key)
	if forage_nodes.has(key):
		forage_nodes[key].queue_free()
		forage_nodes.erase(key)
	GameState.stats["forage"] += 1
	GameState.add_xp(3)
	player.play_tool("shovel" if dig else "seed")
	Events.toast.emit(", ".join(got_text), Color("f0e0a0"))


func can_place_decor(t: Vector2i) -> bool:
	if region_at(t) != "home":
		return false
	var g := g_at(t)
	if g == G.WALL or g == G.WATER or tillable(t):
		return false
	var key := kv(t)
	if is_solid_tile(t.x, t.y) or interact.has(key) or GameState.decor.has(key) or GameState.forage.has(key):
		return false
	if player and tile_of(player.position) == t:
		return false
	return true


func _place_decor(t: Vector2i, id: String) -> void:
	if not GameState.remove_item(id, 1):
		return
	GameState.decor[kv(t)] = id
	refresh_decor()
	player.play_tool("seed")


func beauty_score() -> int:
	var b := 0
	for key in GameState.decor:
		b += 1 + ItemDB.rarity_of(GameState.decor[key])
	return b


# ================================================================= GARDEN LAYER
## Draws tilled soil, fertilizer markers and floor decorations under everything.
class GardenLayer extends Node2D:
	var world: Node2D

	func _draw() -> void:
		var season: int = GameState.season
		for key in GameState.decor:
			var id: String = GameState.decor[key]
			if ItemDB.items.has(id) and ItemDB.items[id].get("floor", false):
				var t: Vector2i = world.parse_key(key)
				draw_texture(PixelArt.decor_tex(id), Vector2(t.x * 16, t.y * 16))
		for key in GameState.plots:
			var p: Dictionary = GameState.plots[key]
			var t2: Vector2i = world.parse_key(key)
			var kind := "soil"
			if p.get("zone", "") == "magic":
				kind = "soil_magic"
			if p.get("watered", false):
				kind = "soil_wet"
			var v := (t2.x * 3 + t2.y * 5) % 4
			var img: Image = PixelArt.tile(kind, v, season)
			draw_texture(_tex(kind, v, img), Vector2(t2.x * 16, t2.y * 16))
			var f: String = p.get("fert", "")
			if f != "" and ItemDB.items.has(f):
				var c: Color = ItemDB.items[f]["c1"]
				draw_rect(Rect2(t2.x * 16 + 12, t2.y * 16 + 1, 3, 3), c.darkened(0.3))
				draw_rect(Rect2(t2.x * 16 + 13, t2.y * 16 + 2, 1, 1), c.lightened(0.3))

	var _texcache := {}

	func _tex(kind: String, v: int, img: Image) -> Texture2D:
		var ck := kind + str(v)
		if not _texcache.has(ck):
			_texcache[ck] = ImageTexture.create_from_image(img)
		return _texcache[ck]
