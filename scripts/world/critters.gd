extends Node2D
## Critters — butterflies, bees, birds and fireflies that bring the garden to life.
## Spawned around the player based on time of day, weather, region,
## blooming flowers and your garden's decor "beauty".

var world = null
var _items: Array = []
var _spawn_t := 0.0
var _rng := RandomNumberGenerator.new()

const DAY_REGIONS := ["home", "flower_fields", "fairy_garden", "forest", "village"]
const BIRD_REGIONS := ["home", "forest", "village", "mountains", "flower_fields"]
const NIGHT_REGIONS := ["home", "forest", "fairy_garden", "flower_fields", "mushroom_caves"]


func _ready() -> void:
	_rng.randomize()
	z_index = 8


func _count(kind: String) -> int:
	var n := 0
	for c in _items:
		if c["kind"] == kind:
			n += 1
	return n


func _spawn(kind: String, pos: Vector2, anchor: Vector2 = Vector2.ZERO) -> void:
	var s := Sprite2D.new()
	var variant := _rng.randi_range(0, 9)
	var frames: Array = PixelArt.critter_frames(kind, variant)
	s.texture = frames[0]
	s.position = pos
	add_child(s)
	_items.append({"kind": kind, "node": s, "frames": frames, "t": _rng.randf() * 10.0,
		"vel": Vector2.ZERO, "anchor": anchor if anchor != Vector2.ZERO else pos, "state": 0, "life": 0.0})


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var pp: Vector2 = world.player.position
	var region: String = world.region_at(world.tile_of(pp))
	var day := GameState.daylight()
	var wet := GameState.weather in ["rain", "snow"]
	_spawn_t -= delta
	if _spawn_t <= 0:
		_spawn_t = 0.8
		var beauty: int = world.beauty_score()
		# butterflies
		var want_b := 0
		if day > 0.6 and not wet and region in DAY_REGIONS and GameState.season != 3:
			want_b = 3 + mini(7, beauty / 4) + (3 if region in ["flower_fields", "fairy_garden"] else 0)
		if _count("butterfly") < want_b:
			_spawn("butterfly", pp + Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-110, 110)))
		# bees near ready flowers
		if day > 0.6 and not wet and _count("bee") < 4:
			for key in world.ready_marks:
				var p: Dictionary = GameState.plots.get(key, {})
				if p.get("plant", "") != "" and ItemDB.items[p["plant"]]["cat"] in ["flower", "herb", "bush"]:
					var t: Vector2i = world.parse_key(key)
					var wp := Vector2(t.x * 16 + 8, t.y * 16 + 2)
					if wp.distance_to(pp) < 200 and _rng.randf() < 0.3:
						_spawn("bee", wp, wp)
						break
		# birds
		if day > 0.5 and not wet and region in BIRD_REGIONS and _count("bird") < 3 and _rng.randf() < 0.35:
			var bp := pp + Vector2(_rng.randf_range(-150, 150), _rng.randf_range(-100, 100))
			if not world.is_solid_tile(int(bp.x / 16), int(bp.y / 16)) and bp.distance_to(pp) > 60:
				_spawn("bird", bp)
		# fireflies
		if day < 0.35 and region in NIGHT_REGIONS and _count("firefly") < 12 and GameState.season != 3:
			_spawn("firefly", pp + Vector2(_rng.randf_range(-170, 170), _rng.randf_range(-110, 110)))
	for c in _items.duplicate():
		var s: Sprite2D = c["node"]
		c["t"] += delta
		c["life"] += delta
		var t2: float = c["t"]
		var far := s.position.distance_to(pp) > 300
		match c["kind"]:
			"butterfly":
				c["vel"] = c["vel"].lerp(Vector2(cos(t2 * 0.7 + c["anchor"].x), sin(t2 * 1.3 + c["anchor"].y)) * 18.0, delta * 2.0)
				s.position += c["vel"] * delta + Vector2(0, sin(t2 * 9.0) * 0.3)
				s.texture = c["frames"][int(t2 * 7.0) % 2]
				if day < 0.5 or wet:
					c["life"] = 999.0
			"bee":
				s.position = c["anchor"] + Vector2(cos(t2 * 2.7) * 9.0, sin(t2 * 3.9) * 6.0 - 6.0)
				s.texture = c["frames"][int(t2 * 20.0) % 2]
				s.flip_h = cos(t2 * 2.7 + 1.57) > 0
				if c["life"] > 25.0:
					c["life"] = 999.0
			"bird":
				if c["state"] == 0:
					s.texture = c["frames"][1 if fmod(t2, 1.6) < 0.25 else 0]
					if s.position.distance_to(pp) < 34:
						c["state"] = 1
						c["vel"] = (s.position - pp).normalized() * 70.0 + Vector2(0, -50)
				else:
					s.position += c["vel"] * delta
					c["vel"].y -= 30.0 * delta
					s.texture = c["frames"][int(t2 * 12.0) % 2]
					if c["life"] > 40.0 or s.position.distance_to(pp) > 220:
						c["life"] = 999.0
				s.flip_h = c["vel"].x < 0
			"firefly":
				s.position += Vector2(cos(t2 * 0.9 + c["anchor"].x), sin(t2 * 1.1 + c["anchor"].y)) * 8.0 * delta
				s.texture = c["frames"][int(t2 * 3.0) % 2]
				s.modulate.a = 0.5 + 0.5 * sin(t2 * 2.5)
				if day > 0.45:
					c["life"] = 999.0
		if far or c["life"] > 900.0:
			s.queue_free()
			_items.erase(c)


func clear_all() -> void:
	for c in _items:
		c["node"].queue_free()
	_items.clear()
