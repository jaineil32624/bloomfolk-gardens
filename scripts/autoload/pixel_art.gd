extends Node
## PixelArt — draws EVERY sprite in the game procedurally at runtime.
##
## No image files are needed: plants (5 growth stages each), item icons,
## terrain tiles, buildings, the player, villagers and critters are all
## painted pixel-by-pixel with small drawing primitives, then given a
## "selective outline" (each edge darkened from its own color) for a
## clean, professional pixel-art look. Results are cached.
##
## To swap in hand-drawn art later, just return your own textures from
## the public functions below (plant_tex, icon, tile, object_tex, ...).

const SOIL := Color("8a5a3a")
const SOIL_WET := Color("5a3a28")
const WOOD := Color("9a6438")
const WOOD_DARK := Color("6a4026")
const STONE := Color("a8a8a0")
const CREAM := Color("efe6d2")

var _cache: Dictionary = {}


# ================================================================= PRIMITIVES
func new_img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func to_tex(im: Image) -> ImageTexture:
	return ImageTexture.create_from_image(im)


func px(im: Image, x: float, y: float, c: Color) -> void:
	var ix := floori(x)
	var iy := floori(y)
	if ix >= 0 and iy >= 0 and ix < im.get_width() and iy < im.get_height():
		if c.a >= 0.999:
			im.set_pixel(ix, iy, c)
		else:
			im.set_pixel(ix, iy, im.get_pixel(ix, iy).blend(c))


func rect(im: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	for yy in range(floori(y), floori(y + h)):
		for xx in range(floori(x), floori(x + w)):
			px(im, xx, yy, c)


func disc(im: Image, cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(im, cx, cy, r, r, c)


func ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for y in range(floori(cy - ry - 1), ceili(cy + ry + 1)):
		for x in range(floori(cx - rx - 1), ceili(cx + rx + 1)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(im, x, y, c)


func line(im: Image, x0: float, y0: float, x1: float, y1: float, c: Color, w: int = 1) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
	for i in steps + 1:
		var t := float(i) / maxi(1, steps)
		var x: float = lerp(x0, x1, t)
		var y: float = lerp(y0, y1, t)
		px(im, x, y, c)
		if w > 1:
			px(im, x + 1, y, c)


## Adds a 1px outline around opaque pixels, colored as a darker version
## of the neighbor ("selective outlining" used in pro pixel art).
func outline(im: Image, dark: float = 0.6, outer: Color = Color(0, 0, 0, 0)) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var src: Image = im.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			var n := Color(0, 0, 0, 0)
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx >= 0 and yy >= 0 and xx < w and yy < h:
					var c := src.get_pixel(xx, yy)
					if c.a > 0.6:
						n = c
						break
			if n.a > 0:
				if outer.a > 0:
					im.set_pixel(x, y, outer)
				else:
					var o := n.darkened(dark)
					o.a = 1.0
					im.set_pixel(x, y, o)


## Soft glow aura around a sprite (used for magical plants).
func glow(im: Image, c: Color, radius: int = 2) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var src: Image = im.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.05:
				continue
			var best := 99.0
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and src.get_pixel(xx, yy).a > 0.6:
						best = min(best, Vector2(dx, dy).length())
			if best <= radius:
				var a := 0.42 * (1.0 - (best - 1.0) / radius)
				im.set_pixel(x, y, Color(c.r, c.g, c.b, clamp(a, 0.08, 0.42)))


func sparkles(im: Image, rng: RandomNumberGenerator, n: int, c: Color = Color(1, 1, 1)) -> void:
	for i in n:
		var x := rng.randi_range(1, im.get_width() - 2)
		var y := rng.randi_range(1, im.get_height() - 6)
		px(im, x, y, c)
		px(im, x - 1, y, Color(c, 0.5))
		px(im, x + 1, y, Color(c, 0.5))
		px(im, x, y - 1, Color(c, 0.5))
		px(im, x, y + 1, Color(c, 0.5))


func _rng(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return r


# ================================================================= FLOWER HEADS
func bloom(im: Image, cx: float, cy: float, shape: String, c1: Color, c2: Color, s: float = 1.0) -> void:
	match shape:
		"daisy":
			for i in 8:
				var a := TAU * i / 8.0
				ellipse(im, cx + cos(a) * 2.5 * s, cy + sin(a) * 2.5 * s, 1.2 * s, 1.2 * s, c1 if i % 2 == 0 else c1.darkened(0.08))
			disc(im, cx, cy, 1.6 * s, c2)
			px(im, cx - 0.6 * s, cy - 0.6 * s, c2.lightened(0.4))
		"star":
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2
				disc(im, cx + cos(a) * 1.7 * s, cy + sin(a) * 1.7 * s, 1.5 * s, c1)
				disc(im, cx + cos(a) * 3.2 * s, cy + sin(a) * 3.2 * s, 0.95 * s, c1.lightened(0.1))
			disc(im, cx, cy, 1.4 * s, c1.darkened(0.15))
			disc(im, cx, cy, 0.8 * s, c2)
		"cup":
			ellipse(im, cx, cy + 0.6 * s, 2.7 * s, 2.8 * s, c1)
			disc(im, cx - 1.8 * s, cy - 2.0 * s, 1.0 * s, c1)
			disc(im, cx, cy - 2.4 * s, 1.0 * s, c1.lightened(0.08))
			disc(im, cx + 1.8 * s, cy - 2.0 * s, 1.0 * s, c1.darkened(0.05))
			line(im, cx - 1 * s, cy - 1 * s, cx - 1 * s, cy + 2 * s, c1.lightened(0.3))
			line(im, cx + 1.4 * s, cy - 0.5 * s, cx + 1.4 * s, cy + 2.4 * s, c1.darkened(0.15))
		"rose":
			disc(im, cx, cy, 3.1 * s, c1.darkened(0.08))
			disc(im, cx - 0.4, cy - 0.4, 2.3 * s, c1)
			disc(im, cx - 0.8, cy - 0.8, 1.0 * s, c1.lightened(0.25))
			for i in 7:
				var a := i * 0.95
				px(im, cx + cos(a) * 1.6 * s, cy + sin(a) * 1.6 * s, c1.darkened(0.35))
		"bell":
			line(im, cx, cy - 2 * s, cx - 3 * s, cy, c1.darkened(0.6))
			line(im, cx, cy - 2 * s, cx + 3 * s, cy, c1.darkened(0.6))
			for o in [Vector2(-3, 1.6), Vector2(0, 1.0), Vector2(3, 1.6)]:
				var bx: float = cx + o.x * s
				var by: float = cy + o.y * s
				ellipse(im, bx, by, 1.4 * s, 1.8 * s, c1)
				px(im, bx - 0.5 * s, by - 0.8 * s, c1.lightened(0.35))
				px(im, bx - 1, by + 1.6 * s, c1.darkened(0.2))
				px(im, bx + 1, by + 1.6 * s, c1.darkened(0.2))
		"spike":
			for i in 6:
				var yy := cy - 3.5 * s + i * 1.4 * s
				disc(im, cx + (0.6 if i % 2 == 0 else -0.6) * s, yy, (1.0 + i * 0.12) * s, c1 if i % 2 == 0 else c1.darkened(0.12))
			px(im, cx, cy - 4 * s, c1.lightened(0.3))
		"dense":
			disc(im, cx, cy, 3.4 * s, c1.darkened(0.12))
			for i in 10:
				var a := TAU * i / 10.0
				px(im, cx + cos(a) * 2.6 * s, cy + sin(a) * 2.6 * s, c1.darkened(0.3))
			disc(im, cx, cy, 2.0 * s, c1)
			disc(im, cx - 0.5, cy - 0.5, 1.0 * s, c1.lightened(0.25))
		"sun":
			for i in 12:
				var a := TAU * i / 12.0
				disc(im, cx + cos(a) * 3.4 * s, cy + sin(a) * 3.4 * s, 1.25 * s, c1 if i % 2 == 0 else c1.darkened(0.1))
			disc(im, cx, cy, 2.3 * s, c2)
			px(im, cx - 1, cy - 1, c2.lightened(0.3))
			px(im, cx + 1, cy, c2.darkened(0.3))
		"umbel":
			for i in 9:
				var a := PI + PI * i / 8.0
				disc(im, cx + cos(a) * 3.0 * s, cy + sin(a) * 2.2 * s + 1.5, 0.9 * s, c1)
				line(im, cx, cy + 2, cx + cos(a) * 3.0 * s, cy + sin(a) * 2.2 * s + 1.5, c2)
			disc(im, cx, cy - 0.5, 1.0 * s, c1.lightened(0.2))
		"puffs":
			for o in [Vector2(-2.5, 0.5), Vector2(2.5, 0), Vector2(0, -2)]:
				disc(im, cx + o.x * s, cy + o.y * s, 1.9 * s, c1)
				px(im, cx + o.x * s - 0.5, cy + o.y * s - 0.7, Color.WHITE)
		_:  # round
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2
				disc(im, cx + cos(a) * 2.3 * s, cy + sin(a) * 2.3 * s, 1.75 * s, c1 if i % 2 == 0 else c1.darkened(0.07))
			disc(im, cx, cy, 1.25 * s, c2)
			px(im, cx - 2.5 * s, cy - 1.2 * s, c1.lightened(0.35))


# ================================================================= PLANTS
func plant_tex(id: String, stage: int) -> Texture2D:
	var key := "p:%s:%d" % [id, stage]
	if _cache.has(key):
		return _cache[key]
	var it: Dictionary = ItemDB.items[id]
	var im := new_img(16, 24)
	var rng := _rng(id)
	_draw_plant(im, it, stage, rng)
	outline(im)
	if stage >= 3 and (it["cat"] in ["mythical", "crystal"] or it["opts"].get("glow", false)):
		glow(im, it["c1"].lightened(0.3), 2)
		if stage == 4:
			sparkles(im, rng, 3, Color(1, 1, 0.9))
	var t := to_tex(im)
	_cache[key] = t
	return t


func _draw_plant(im: Image, it: Dictionary, stage: int, rng: RandomNumberGenerator) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	var leaf: Color = it["leaf"]
	var arch: String = it["arch"]
	var shape: String = it["shape"]
	var stem := leaf.darkened(0.25)
	if stage == 0:
		ellipse(im, 8, 21.5, 3.5, 1.6, Color("6b4a32"))
		ellipse(im, 8, 21.0, 2.5, 1.0, Color("7d5a3c"))
		px(im, 7, 20, c1.darkened(0.15))
		px(im, 9, 21, c1.darkened(0.3))
		return
	if arch == "mushroom":
		_draw_mushroom(im, it, stage)
		return
	if arch == "crystal":
		_draw_crystal(im, it, stage, rng)
		return
	if stage == 1:
		line(im, 8, 22, 8, 19, stem)
		ellipse(im, 6.2, 18.6, 1.7, 1.0, leaf)
		ellipse(im, 9.8, 18.2, 1.7, 1.0, leaf.lightened(0.1))
		return
	if stage == 2:
		if arch == "tree":
			line(im, 8, 22, 8, 14, WOOD)
			ellipse(im, 6, 14.5, 2, 1.2, leaf)
			ellipse(im, 10, 13.5, 2, 1.2, leaf.lightened(0.1))
			disc(im, 8, 12.5, 1.5, leaf)
			return
		line(im, 8, 22, 8, 14, stem)
		ellipse(im, 5.6, 19, 2.3, 1.2, leaf)
		ellipse(im, 10.4, 17.4, 2.3, 1.2, leaf.lightened(0.08))
		ellipse(im, 6.2, 15.4, 2.0, 1.1, leaf.lightened(0.15))
		disc(im, 8, 13.6, 1.1, leaf.lightened(0.2))
		return
	var b := stage == 4
	match arch:
		"flower", "mythic":
			if shape == "fern":
				_fern(im, leaf if not b else c1.lerp(leaf, 0.4), c1, b, 1.0)
			elif shape == "mandrake":
				_mandrake(im, it, b)
			elif shape == "worldtree":
				_tree(im, Color("8fffb0"), c2, b, "worldtree", rng)
			else:
				var h := 12
				line(im, 8, 22, 8, 22 - h, stem)
				ellipse(im, 5.5, 22 - h * 0.35, 2.3, 1.0, leaf)
				ellipse(im, 10.5, 22 - h * 0.62, 2.3, 1.0, leaf.lightened(0.08))
				if b:
					bloom(im, 8, 22 - h, shape, c1, c2, 1.0)
				else:
					ellipse(im, 8, 22 - h, 1.5, 2.2, c1.lerp(leaf, 0.35))
					px(im, 8, 21 - h, c1)
		"tall":
			_tall(im, it, b)
		"root":
			_root(im, it, b)
		"leafy":
			var r := 4.2 if not b else 5.6
			ellipse(im, 8, 21.6 - r * 0.6, r, r * 0.78, leaf.darkened(0.12))
			ellipse(im, 8, 21.4 - r * 0.6, r * 0.66, r * 0.56, c1)
			ellipse(im, 7, 20.6 - r * 0.7, r * 0.3, r * 0.25, c1.lightened(0.25))
			for i in 4:
				var a := PI + PI * (i + 0.5) / 4.0
				px(im, 8 + cos(a) * r * 0.8, 21.4 - r * 0.6 + sin(a) * r * 0.6, leaf.darkened(0.3))
			if b and it["name"] in ["Broccoli", "Cauliflower", "Artichoke"]:
				for o in [Vector2(-2, -1), Vector2(1, -2), Vector2(0, 0), Vector2(2, 0)]:
					disc(im, 8 + o.x, 18 + o.y, 1.4, c1.lightened(0.1))
		"vine":
			var h2 := 13 if not b else 16
			rect(im, 7.5, 22 - h2, 1, h2, WOOD)
			px(im, 7.5, 22 - h2, WOOD_DARK)
			for i in 5:
				var y := 21.0 - i * 3.0
				if y < 22 - h2:
					break
				var side := -1 if i % 2 == 0 else 1
				ellipse(im, 8 + side * 2.6, y, 2.4, 1.3, leaf if i % 2 == 0 else leaf.lightened(0.1))
			var spots := [Vector2(5, 15), Vector2(11, 12), Vector2(5.5, 9), Vector2(11, 18)]
			if b:
				for i in (4 if h2 > 14 else 3):
					var p: Vector2 = spots[i]
					if it["opts"].get("pod", false):
						ellipse(im, p.x, p.y + 1, 1.0, 2.3, c1)
						px(im, p.x - 0.5, p.y, c1.lightened(0.35))
					else:
						disc(im, p.x, p.y, 1.8, c1)
						px(im, p.x - 0.6, p.y - 0.7, c1.lightened(0.45))
						px(im, p.x, p.y - 1.9, leaf.darkened(0.2))
			else:
				for i in 3:
					var p2: Vector2 = spots[i]
					px(im, p2.x, p2.y, Color("f8e85a"))
					px(im, p2.x + 1, p2.y, Color("f8e85a"))
		"gourd":
			line(im, 1, 21, 15, 20, leaf.darkened(0.25))
			ellipse(im, 3, 18.8, 2.6, 2.0, leaf)
			ellipse(im, 13, 18.2, 2.6, 2.0, leaf.lightened(0.06))
			ellipse(im, 8, 16.6, 2.3, 1.8, leaf.darkened(0.06))
			if b:
				ellipse(im, 8, 19.4, 4.6, 3.3, c1)
				line(im, 8, 16.6, 8, 22, c1.darkened(0.18))
				line(im, 5.5, 17.2, 5.5, 21.6, c1.darkened(0.1))
				line(im, 10.5, 17.2, 10.5, 21.6, c1.darkened(0.1))
				px(im, 6, 17.5, c1.lightened(0.4))
				px(im, 6, 18.5, c1.lightened(0.25))
				rect(im, 7.5, 15, 1, 2, WOOD_DARK)
			else:
				ellipse(im, 8, 20, 2.0, 1.5, c1.lerp(leaf, 0.55))
				px(im, 11, 17, Color("f8e85a"))
				px(im, 12, 17, Color("f8e85a"))
		"grain":
			var h3 := 11 if not b else 14
			var stalk := leaf if not b else c1.darkened(0.12)
			for i in 5:
				var x := 4.0 + i * 2.0
				var top := 22 - h3 + absi(i - 2)
				line(im, x, 22, x + (i - 2) * 0.4, top, stalk if i % 2 == 0 else stalk.lightened(0.08))
				if b:
					ellipse(im, x + (i - 2) * 0.4, top - 1, 0.9, 2.1, c1)
		"bush":
			_bush(im, it, b)
		"herb":
			var h4 := 8 if not b else 10
			for i in 3:
				var x0 := 5.0 + i * 3.0
				var top2 := 22 - h4 + (i % 2) * 2
				line(im, x0, 22, x0 + (i - 1), top2, stem)
				for j in range(0, h4 - 1, 2):
					var yy := 21.0 - j
					if yy < top2:
						break
					var xx: float = lerp(x0, x0 + (i - 1), float(j) / h4)
					ellipse(im, xx - 1.3, yy, 1.3, 0.8, leaf)
					ellipse(im, xx + 1.3, yy - 1, 1.3, 0.8, leaf.lightened(0.1))
				if b:
					px(im, x0 + (i - 1), top2 - 1, c2)
					px(im, x0 + (i - 1) - 1, top2, c2)
					px(im, x0 + (i - 1) + 1, top2, c2.darkened(0.1))
		"tree":
			_tree(im, leaf, c1, b, shape, rng)
		"fern":
			if shape == "moss":
				var r2 := 3.5 if not b else 5.0
				ellipse(im, 8, 22 - r2 * 0.5, r2 + 1, r2 * 0.7, leaf)
				for i in 10:
					px(im, rng.randf_range(8 - r2, 8 + r2), rng.randf_range(21 - r2, 21), leaf.lightened(0.25))
				if b:
					for i in 4:
						px(im, rng.randf_range(4, 12), rng.randf_range(17, 21), c2)
			else:
				_fern(im, leaf, c1, b, 1.0)
				if b and shape == "cone":
					ellipse(im, 8, 15, 1.9, 3.0, c2)
					for y in [13, 15, 17]:
						px(im, 7, y, c2.darkened(0.3))
						px(im, 9, y + 1, c2.darkened(0.3))
		"exotic":
			_exotic(im, it, b, rng)


func _tall(im: Image, it: Dictionary, b: bool) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	var leaf: Color = it["leaf"]
	if it["shape"] == "corn":
		var top := 3 if b else 6
		rect(im, 7.5, top, 1.5, 22 - top, leaf.darkened(0.15))
		for i in 4:
			var y := 20.0 - i * 4.0
			var side := -1 if i % 2 == 0 else 1
			line(im, 8, y, 8 + side * 5, y - 3, leaf if i % 2 == 0 else leaf.lightened(0.1))
			line(im, 8, y + 1, 8 + side * 4, y - 2, leaf.darkened(0.05))
		if b:
			ellipse(im, 10.6, 12.5, 1.6, 3.4, c1)
			for y in range(10, 16, 2):
				px(im, 10, y, c1.darkened(0.2))
			line(im, 9.5, 16, 11.8, 9.5, leaf.lightened(0.15))
			for x in [7, 8, 9]:
				px(im, x, top - 1, c2)
	else:
		var top2 := 5 if b else 7
		rect(im, 7.5, top2, 1.5, 22 - top2, leaf.darkened(0.2))
		ellipse(im, 4.5, 17, 3.0, 1.4, leaf)
		ellipse(im, 11.5, 13.5, 3.0, 1.4, leaf.lightened(0.08))
		ellipse(im, 5, 11, 2.4, 1.2, leaf.lightened(0.12))
		if b:
			bloom(im, 8, top2 + 1, "sun", c1, c2, 1.0)
		else:
			disc(im, 8, top2, 2.4, leaf.lightened(0.05))
			px(im, 8, top2 - 2, c1)


func _root(im: Image, it: Dictionary, b: bool) -> void:
	var c1: Color = it["c1"]
	var leaf: Color = it["leaf"]
	var g := 0.75 if not b else 1.0
	for i in 5:
		var xe := 8 + (i - 2) * 1.7
		var ye := 19 - (6 + (2 - absi(i - 2)) * 2) * g
		line(im, 8, 19, xe, ye, leaf if i % 2 == 0 else leaf.lightened(0.12))
		if i == 2:
			line(im, 9, 19, xe + 1, ye + 1, leaf.darkened(0.08))
	var long: bool = it["opts"].get("long", false)
	if b:
		ellipse(im, 8, 20.6, 2.2 if long else 3.2, 2.0, c1)
		px(im, 7, 19.5, c1.lightened(0.4))
		px(im, 8, 21.6, c1.darkened(0.2))
	else:
		ellipse(im, 8, 21.2, 1.8, 1.2, c1)


func _bush(im: Image, it: Dictionary, b: bool) -> void:
	var c1: Color = it["c1"]
	var leaf: Color = it["leaf"]
	var small: bool = it["opts"].get("small", false)
	var s := 0.7 if small else 1.0
	var cy := 22 - 5 * s
	ellipse(im, 8, cy + 0.5, 6 * s, 4.8 * s, leaf.darkened(0.2))
	disc(im, 6, cy - 0.5, 3.0 * s, leaf)
	disc(im, 10.5, cy - 1, 2.8 * s, leaf.lightened(0.08))
	disc(im, 8, cy - 2.5 * s, 2.5 * s, leaf.lightened(0.16))
	if b:
		var spots := [Vector2(4, 1), Vector2(7, -2), Vector2(11, 0), Vector2(9, 2), Vector2(5.5, -1.5), Vector2(12, -2.5), Vector2(8, 0.5)]
		for p in spots:
			var x: float = 8 + (p.x - 8) * s
			var y: float = cy + p.y * s
			match it["shape"]:
				"flowers":
					disc(im, x, y - 0.5, 1.4, c1)
					px(im, x - 0.5, y - 1, c1.lightened(0.35))
				"tea":
					ellipse(im, x, y, 1.2, 0.7, leaf.lightened(0.35))
				_:
					px(im, x, y, c1)
					px(im, x + 1, y, c1.darkened(0.2))
					px(im, x, y + 1, c1.darkened(0.25))
					px(im, x + 1, y + 1, c1.darkened(0.35))
					px(im, x, y, c1.lightened(0.3))


func _tree(im: Image, leaf: Color, c1: Color, b: bool, shape: String, rng: RandomNumberGenerator) -> void:
	var g := 0.82 if not b else 1.0
	var th := 9.0 * g
	rect(im, 7, 22 - th, 2, th + 1, WOOD)
	rect(im, 8.5, 22 - th, 1, th + 1, WOOD_DARK)
	var cy := 22 - th - 3.2 * g
	var lc := leaf
	if shape == "sakura" and b:
		lc = c1
	disc(im, 8, cy, 5.8 * g, lc.darkened(0.18))
	disc(im, 7.2, cy - 0.8, 4.8 * g, lc)
	disc(im, 6, cy - 2, 2.5 * g, lc.lightened(0.15))
	if shape == "worldtree":
		sparkles(im, rng, 2, Color(1, 1, 0.8))
	if b and shape != "sakura" and shape != "oak":
		for i in 5:
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.0, 4.0)
			var x := 8 + cos(a) * r
			var y := cy + sin(a) * r * 0.8
			disc(im, x, y, 1.15, c1)
			px(im, x - 0.5, y - 0.5, c1.lightened(0.4))
	if b and shape == "oak":
		for i in 4:
			px(im, rng.randf_range(4, 12), rng.randf_range(cy - 2, cy + 3), c1)
	if b and shape == "sakura":
		for i in 6:
			px(im, rng.randf_range(3, 13), rng.randf_range(cy - 4, cy + 4), Color("ffffff"))


func _fern(im: Image, leaf: Color, c1: Color, b: bool, s: float) -> void:
	var L := (8.0 if not b else 10.0) * s
	for f in 5:
		var a: float = lerp(-1.0, 1.0, f / 4.0)
		var prev := Vector2(8, 22)
		for j in int(L):
			var t := float(j) / L
			var p := Vector2(8 + sin(a) * j * 0.9 + sin(a) * t * t * 3, 22 - cos(a) * j * 1.0)
			px(im, p.x, p.y, leaf.darkened(0.15))
			if j > 1 and j % 2 == 0:
				px(im, p.x - 1, p.y, leaf)
				px(im, p.x + 1, p.y - 0.5, leaf.lightened(0.1))
			prev = p


func _mandrake(im: Image, it: Dictionary, b: bool) -> void:
	var leaf: Color = it["c2"]
	for i in 5:
		line(im, 8, 18, 8 + (i - 2) * 2, 18 - (5 if b else 3) - (2 - abs(i - 2)), leaf if i % 2 == 0 else leaf.lightened(0.15))
	if b:
		ellipse(im, 8, 20.5, 3, 2.2, it["c1"])
		px(im, 7, 20, Color("2a1a1a"))
		px(im, 9, 20, Color("2a1a1a"))
		px(im, 8, 21, Color("6a2a2a"))
	else:
		ellipse(im, 8, 21, 2, 1.3, it["c1"])


func _exotic(im: Image, it: Dictionary, b: bool, rng: RandomNumberGenerator) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	var leaf: Color = it["leaf"]
	match it["shape"]:
		"cactus":
			var h := 9 if not b else 11
			ellipse(im, 8, 22 - h * 0.5, 2.6, h * 0.5 + 0.5, Color("4f9f5a"))
			rect(im, 3, 13, 2, 4, Color("4f9f5a"))
			rect(im, 4, 16, 3, 1.5, Color("4f9f5a"))
			rect(im, 11, 11, 2, 4, Color("5faf6a"))
			rect(im, 9, 14, 3, 1.5, Color("5faf6a"))
			line(im, 8, 22 - h + 1, 8, 21, Color("3f8a4a"))
			for i in 4:
				px(im, rng.randi_range(6, 10), rng.randi_range(22 - h, 21), Color("f0f0d0"))
			if b:
				if it["name"] in ["Dragon Fruit", "Kiwano"]:
					ellipse(im, 8, 22 - h - 1, 2.2, 2.6, c1)
					px(im, 7, 22 - h - 2, c1.lightened(0.4))
					px(im, 10, 22 - h, c2)
				else:
					bloom(im, 8, 22 - h - 1, "round", c1, c2, 0.75)
		"aloe":
			for i in 6:
				var a: float = lerp(-1.1, 1.1, i / 5.0)
				line(im, 8, 22, 8 + sin(a) * (7 if b else 5), 22 - cos(a) * (8 if b else 6), leaf if i % 2 == 0 else leaf.lightened(0.12), 2)
			if b:
				line(im, 8, 21, 9, 6, Color("6a8a4a"))
				for y in [6, 7, 8]:
					px(im, 9, y, c2)
		"bamboo":
			var h2 := 14 if not b else 19
			for i in 3:
				var x := 5 + i * 3
				var top := 22 - h2 + i * 2
				rect(im, x, top, 2, 22 - top, Color("8fcf5a") if i != 1 else Color("7fbf4a"))
				for y in range(22, top, -4):
					rect(im, x, y, 2, 1, Color("5a8f3a"))
				ellipse(im, x + 3, top + 2, 2, 0.8, leaf)
		"pineapple":
			for i in 7:
				var a: float = lerp(-1.2, 1.2, i / 6.0)
				line(im, 8, 21, 8 + sin(a) * 7, 21 - cos(a) * 5, Color("4f9f5a"))
			if b:
				ellipse(im, 8, 15, 2.6, 3.4, c1)
				for y in range(13, 18, 2):
					px(im, 7, y, c1.darkened(0.3))
					px(im, 9, y + 1, c1.darkened(0.3))
				for i in 3:
					line(im, 8, 11.5, 6 + i * 2, 8, c2)
		"trap":
			line(im, 6, 22, 5, 15, leaf)
			line(im, 10, 22, 11, 13, leaf)
			for p in [Vector2(5, 14), Vector2(11, 12)]:
				var s := 1.0 if b else 0.7
				ellipse(im, p.x - 1.4 * s, p.y, 1.4 * s, 2.2 * s, leaf.lightened(0.1))
				ellipse(im, p.x + 1.4 * s, p.y, 1.4 * s, 2.2 * s, leaf.lightened(0.1))
				ellipse(im, p.x, p.y, 1.2 * s, 1.6 * s, c1)
				px(im, p.x - 2.5 * s, p.y - 1, Color.WHITE)
				px(im, p.x + 2.5 * s, p.y - 1, Color.WHITE)
		"pitcher":
			line(im, 8, 22, 8, 18, leaf)
			ellipse(im, 4, 20, 2.5, 1.0, leaf)
			ellipse(im, 12, 20, 2.5, 1.0, leaf)
			var hh := 5.0 if not b else 7.0
			ellipse(im, 8, 18 - hh * 0.5, 2.8, hh * 0.55, c1)
			ellipse(im, 8, 18 - hh, 2.6, 0.9, c2)
			px(im, 7, 17 - hh * 0.5, c1.lightened(0.3))
		"titan":
			ellipse(im, 8, 20, 6, 2.0, leaf.darkened(0.2))
			if b:
				ellipse(im, 8, 17, 5.2, 4.5, c1)
				ellipse(im, 8, 17, 3.2, 3.0, c1.darkened(0.3))
				rect(im, 7, 5, 2, 12, c2)
				px(im, 7, 5, c2.lightened(0.3))
			else:
				ellipse(im, 8, 15, 2.5, 5, c1.lerp(leaf, 0.5))
		_:  # palm-style big leaves
			var ends := [Vector2(1, 13), Vector2(3.5, 8.5), Vector2(8, 6.5), Vector2(12.5, 8.5), Vector2(15, 13)]
			for i in ends.size():
				var e: Vector2 = ends[i]
				var ee := Vector2(8, 21).lerp(e, 0.75 if not b else 1.0)
				line(im, 8, 21, ee.x, ee.y, leaf if i % 2 == 0 else leaf.lightened(0.1), 2)
				disc(im, ee.x, ee.y + 0.5, 1.2, leaf.darkened(0.08))
			if b:
				var fr: String = it["opts"].get("fruit", "round")
				if fr == "flower":
					bloom(im, 8, 11, "star", c1, c2, 0.9)
				elif fr == "round":
					for p in [Vector2(6.5, 15), Vector2(9.5, 14), Vector2(8, 17)]:
						disc(im, p.x, p.y, 1.4, c1)
						px(im, p.x - 0.5, p.y - 0.6, c1.lightened(0.4))


func _draw_mushroom(im: Image, it: Dictionary, stage: int) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	var o: Dictionary = it["opts"]
	var shape: String = it["shape"]
	var size: float = [0.0, 1.4, 2.4, 3.6, 4.8][stage]
	if shape == "truffle":
		ellipse(im, 8, 21.5, 3.5, 1.4, Color("6b4a32"))
		disc(im, 8, 21 - size * 0.4, size * 0.65, c1)
		px(im, 7, 20 - size * 0.4, c2)
		return
	if shape == "puff":
		disc(im, 8, 22 - size * 0.8, size * 0.9, c1)
		px(im, 7, 21 - size, Color.WHITE)
		if it["name"] == "Lion's Mane" and stage >= 3:
			for x in range(5, 12, 2):
				line(im, x, 22 - size * 0.6, x, 22 - size * 0.1, c2)
		return
	if shape == "coral":
		for i in 5:
			var x := 4 + i * 2
			line(im, 8, 22, x, 22 - size * 1.8 + abs(i - 2), c1 if i % 2 == 0 else c2)
		return
	if o.get("cluster", false) and stage >= 2:
		_shroom(im, 5, 22, size * 0.6, c1, c2, o)
		_shroom(im, 11, 22, size * 0.55, c1.darkened(0.06), c2, o)
		_shroom(im, 8, 20, size * 0.75, c1, c2, o)
	else:
		_shroom(im, 8, 22, size, c1, c2, o)


func _shroom(im: Image, x: float, base: float, size: float, c1: Color, c2: Color, o: Dictionary) -> void:
	var sh := size * 1.1
	rect(im, x - max(1, size * 0.32), base - sh, max(1.0, size * 0.64), sh, CREAM)
	px(im, x + size * 0.2, base - sh * 0.5, CREAM.darkened(0.15))
	var cy := base - sh
	ellipse(im, x, cy, size, size * 0.62, c1)
	line(im, x - size + 0.5, cy + size * 0.3, x + size - 0.5, cy + size * 0.3, c1.darkened(0.3))
	px(im, x - size * 0.45, cy - size * 0.3, c1.lightened(0.4))
	if o.get("spots", false) and size > 2:
		px(im, x - size * 0.3, cy - size * 0.1, c2)
		px(im, x + size * 0.4, cy - size * 0.25, c2)
		px(im, x + size * 0.05, cy - size * 0.45, c2)


func _draw_crystal(im: Image, it: Dictionary, stage: int, rng: RandomNumberGenerator) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	ellipse(im, 8, 21.6, 4.5, 1.6, Color("5a5070"))
	var sz: float = [0.0, 0.35, 0.6, 0.85, 1.0][stage]
	if it["shape"] in ["shard", "prism"] or stage < 3:
		_shard(im, 8, 21, 13 * sz, 5 * sz + 1, c1)
		if stage >= 2:
			_shard(im, 4.5, 21, 7 * sz, 3, c1.darkened(0.1))
			_shard(im, 11.5, 21, 8 * sz, 3, c1.lightened(0.05))
		if it["shape"] == "prism" and stage == 4:
			for i in 5:
				px(im, 3 + i * 2, 4 + (i % 2), Color.from_hsv(i / 5.0, 0.6, 1.0))
	else:
		line(im, 8, 21, 8, 10, c2)
		_shard(im, 5, 21, 5, 3, c1.darkened(0.1))
		_shard(im, 11, 21, 4, 3, c1.darkened(0.15))
		if stage == 4:
			bloom(im, 8, 9, it["shape"], c1, c2, 1.0)
		else:
			ellipse(im, 8, 10, 1.6, 2.4, c1)


func _shard(im: Image, x: float, base: float, h: float, w: float, c: Color) -> void:
	var hi := int(max(1, h))
	for i in hi:
		var t := float(i) / hi
		var ww: float = max(1.0, w * (1.0 - t * 0.8))
		var y := base - i
		for xx in range(floori(x - ww / 2.0), floori(x + ww / 2.0) + 1):
			px(im, xx, y, c.lightened(0.28) if xx < x - 0.5 else c.darkened(0.1))
	px(im, x, base - hi, c.lightened(0.5))


# ================================================================= ICONS
func icon(key: String) -> Texture2D:
	var ck := "i:" + key
	if _cache.has(ck):
		return _cache[ck]
	var im := new_img(16, 16)
	var it := ItemDB.item(key)
	if it.is_empty():
		rect(im, 4, 4, 8, 8, Color.MAGENTA)
	elif ItemDB.is_seed(key):
		_icon_seed(im, it)
	else:
		_icon_item(im, it)
	if it.get("icon", "") != "decor":
		outline(im, 0.65)
	if not ItemDB.is_seed(key) and (it.get("cat", "") in ["mythical", "crystal"] or it.get("mutation", "") != ""):
		glow(im, it.get("c1", Color.WHITE).lightened(0.3) if it.get("mutation", "") == "" else (Color("ffe07a") if it["mutation"] == "golden" else Color("ff9af0")), 1)
	var t := to_tex(im)
	_cache[ck] = t
	return t


func _icon_seed(im: Image, it: Dictionary) -> void:
	var c1: Color = it["c1"]
	match it["cat"]:
		"crystal":
			ellipse(im, 8, 9, 5.5, 5, Color("7a7088"))
			ellipse(im, 8, 9, 3.5, 3.2, Color("4a4058"))
			_shard(im, 7, 11, 5, 3, c1)
			_shard(im, 10, 11, 3, 2, c1.darkened(0.1))
			return
		"ancient":
			ellipse(im, 8, 9, 4.5, 5.5, Color("8a6a4a"))
			ellipse(im, 7, 7.5, 1.5, 2, Color("a88a6a"))
			line(im, 7, 7, 9, 12, c1.lightened(0.4))
			px(im, 9, 8, c1.lightened(0.5))
			return
	if it["arch"] == "tree":
		rect(im, 4, 10, 8, 5, Color("c06a3a"))
		rect(im, 4, 10, 8, 1, Color("d8824a"))
		line(im, 8, 10, 8, 5, WOOD)
		ellipse(im, 6, 5, 2, 1.2, it["leaf"])
		ellipse(im, 10, 4, 2, 1.2, it["leaf"].lightened(0.1))
		return
	var paper := Color("efe0bc")
	if it["arch"] == "mushroom":
		paper = Color("d8d0e8")
	rect(im, 3, 2, 10, 12, paper)
	rect(im, 3, 2, 10, 2, paper.darkened(0.15))
	ellipse(im, 8, 8, 3.6, 3.2, c1.lightened(0.6))
	disc(im, 8, 8, 2.2, c1)
	px(im, 7, 7, c1.lightened(0.4))
	px(im, 10, 6, it["leaf"])
	px(im, 11, 5, it["leaf"])
	rect(im, 5, 12, 6, 1, paper.darkened(0.3))
	px(im, 12, 3, paper.darkened(0.25))


func _icon_item(im: Image, it: Dictionary) -> void:
	match it.get("icon", ""):
		"mutation":
			var base: Dictionary = ItemDB.items[it["base"]]
			_icon_plant(im, base)
			_recolor_mutation(im, it["mutation"])
			var r := _rng(it["id"])
			sparkles(im, r, 2, Color(1, 1, 0.85))
		"tool":
			_icon_tool(im, it["tool"], ItemDB.TOOL_TIER_COLORS[int(it["tier"]) - 1])
		"fert":
			_icon_bag(im, it["c1"])
		"decor":
			var t := decor_tex(it["id"])
			var src := t.get_image()
			if src.get_width() == 16 and src.get_height() == 16:
				im.blit_rect(src, Rect2i(0, 0, 16, 16), Vector2i.ZERO)
			else:
				var s2: Image = src.duplicate()
				var sw := src.get_width()
				var sh := src.get_height()
				var k: float = max(sw, sh) / 16.0
				s2.resize(int(sw / k), int(sh / k), Image.INTERPOLATE_NEAREST)
				im.blit_rect(s2, Rect2i(0, 0, s2.get_width(), s2.get_height()), Vector2i((16 - s2.get_width()) / 2, 16 - s2.get_height()))
			# decor textures already have outlines; clear to avoid double outline
		"treasure":
			_icon_treasure(im, it)
		_:
			_icon_plant(im, it)


func _recolor_mutation(im: Image, kind: String) -> void:
	for y in 16:
		for x in 16:
			var c := im.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var l := c.get_luminance()
			if kind == "golden":
				im.set_pixel(x, y, Color("8a5a10").lerp(Color("ffe46a"), clamp(l * 1.4, 0.0, 1.0)))
			else:
				var hue := fmod((x + y) / 16.0, 1.0)
				im.set_pixel(x, y, Color.from_hsv(hue, 0.55, clamp(0.55 + l * 0.6, 0.0, 1.0)))


func _icon_plant(im: Image, it: Dictionary) -> void:
	var c1: Color = it["c1"]
	var c2: Color = it["c2"]
	var leaf: Color = it["leaf"]
	match it["icon"]:
		"round_root":
			line(im, 8, 6, 6, 1, leaf)
			line(im, 8, 6, 8, 1, leaf.lightened(0.1))
			line(im, 8, 6, 10, 1, leaf)
			ellipse(im, 8, 9.5, 4.3, 4.0, c1)
			line(im, 8, 13, 8, 15, c1.darkened(0.25))
			px(im, 6, 8, c1.lightened(0.45))
			px(im, 6, 9, c1.lightened(0.3))
			px(im, 10, 11, c1.darkened(0.2))
		"long_root":
			for i in 10:
				var t := i / 9.0
				disc(im, lerp(5.5, 12.0, t), lerp(5.5, 14.0, t), 2.5 * (1.0 - t) + 0.6, c1)
			for y in [8, 10, 12]:
				px(im, y - 1, y, c1.darkened(0.22))
			line(im, 5, 5, 2, 1, leaf)
			line(im, 5, 5, 5, 1, leaf.lightened(0.1))
			line(im, 5, 5, 1, 4, leaf)
		"leaf_ball":
			ellipse(im, 8, 9, 6.2, 5.6, leaf.darkened(0.1))
			ellipse(im, 8, 9.5, 4.2, 3.8, c1)
			px(im, 6, 7, c1.lightened(0.35))
			line(im, 8, 6, 8, 13, leaf.darkened(0.25))
		"fruit", "acorn_big":
			if it["icon"] == "acorn_big":
				ellipse(im, 8, 10, 3.5, 4.0, Color("b07a3a"))
				ellipse(im, 8, 6.5, 4.2, 2.0, Color("7a5a2a"))
				px(im, 8, 3, WOOD_DARK)
				return
			disc(im, 8, 9.5, 4.6, c1)
			disc(im, 6.4, 7.8, 1.4, c1.lightened(0.38))
			px(im, 10, 12, c1.darkened(0.2))
			line(im, 8, 5, 8, 3, WOOD_DARK)
			ellipse(im, 10.5, 3.5, 2.0, 1.0, leaf)
		"pod":
			for i in 8:
				var t := i / 7.0
				disc(im, lerp(5.0, 11.0, t), lerp(3.5, 13.0, t) , 2.1 - abs(t - 0.5) * 1.2, c1)
			px(im, 6, 5, c1.lightened(0.35))
			line(im, 5, 3, 3, 1, leaf.darkened(0.2))
		"big_fruit":
			ellipse(im, 8, 9.5, 6.5, 5.0, c1)
			for x in [5, 8, 11]:
				line(im, x, 5.5, x, 13.5, c1.darkened(0.15))
			px(im, 4, 7, c1.lightened(0.4))
			rect(im, 7, 2, 2, 3, WOOD_DARK)
			ellipse(im, 11, 3.5, 2, 1, leaf)
		"berries", "flower_cluster", "tea":
			if it["icon"] == "tea":
				for p in [Vector2(6, 7), Vector2(10, 8), Vector2(8, 11)]:
					ellipse(im, p.x, p.y, 2.5, 1.6, leaf.lightened(0.15))
					line(im, p.x - 2, p.y, p.x + 2, p.y, leaf.darkened(0.2))
				return
			line(im, 8, 3, 8, 6, WOOD_DARK)
			line(im, 8, 6, 4.5, 9, WOOD_DARK)
			line(im, 8, 6, 11.5, 8.5, WOOD_DARK)
			ellipse(im, 10.5, 3, 2.4, 1.1, leaf)
			for p in [Vector2(4.5, 10), Vector2(11.5, 9.5), Vector2(8, 9), Vector2(6, 13), Vector2(10, 13)]:
				disc(im, p.x, p.y, 1.8 if it["icon"] == "berries" else 2.1, c1)
				px(im, p.x - 0.6, p.y - 0.8, c1.lightened(0.45))
		"bundle":
			for i in 5:
				var x := 4.0 + i * 2
				line(im, 8, 15, x, 4, c1.darkened(0.15))
				ellipse(im, x, 3.5, 1, 2.2, c1)
			rect(im, 6, 10, 4, 2, Color("a0683a"))
		"cob":
			ellipse(im, 8, 7.5, 3.2, 6.0, c1)
			for y in range(3, 13, 2):
				for x in [7, 9]:
					px(im, x, y, c1.darkened(0.2))
			line(im, 4, 15, 7, 5, leaf)
			line(im, 12, 15, 9, 5, leaf.lightened(0.1))
			line(im, 5, 15, 7, 8, leaf)
		"bloom":
			line(im, 8, 15, 8, 9, leaf.darkened(0.2))
			ellipse(im, 10.5, 13, 2, 1, leaf)
			var sh: String = it["shape"] if it["shape"] != "" else "round"
			if sh == "corn":
				sh = "sun"
			if sh == "sakura":
				sh = "round"
			bloom(im, 8, 6.5, sh, c1, c2, 1.25)
		"sprig":
			line(im, 4, 15, 11, 2, leaf.darkened(0.25))
			for i in 4:
				var t := 0.2 + i * 0.2
				var p := Vector2(lerp(4.0, 11.0, t), lerp(15.0, 2.0, t))
				ellipse(im, p.x - 2, p.y, 1.8, 1.0, leaf)
				ellipse(im, p.x + 2, p.y - 1, 1.8, 1.0, leaf.lightened(0.12))
			disc(im, 11, 2, 1, c2)
		"mushroom":
			rect(im, 6.5, 8, 3, 7, CREAM)
			ellipse(im, 8, 7, 6.2, 4.2, c1)
			line(im, 3, 8.5, 13, 8.5, c1.darkened(0.3))
			px(im, 5, 5, c1.lightened(0.45))
			if it["opts"].get("spots", false):
				px(im, 7, 4, c2)
				px(im, 10, 6, c2)
				px(im, 5, 7, c2)
		"gem":
			for y in range(3, 14):
				var w: int = 3 if y == 3 else (5 if y < 7 else int(5 - (y - 6) * 0.72))
				for x in range(8 - w, 8 + w):
					px(im, x, y, c1.lightened(0.3) if x < 8 else c1.darkened(0.08))
			line(im, 3, 6, 13, 6, c1.lightened(0.5))
			px(im, 6, 4, Color.WHITE)
			if it["shape"] == "prism":
				for i in 4:
					px(im, 5 + i * 2, 9, Color.from_hsv(i / 4.0, 0.6, 1.0))
		"crystal_bloom":
			line(im, 8, 15, 8, 9, it["c2"])
			bloom(im, 8, 6.5, it["shape"], c1, c2, 1.2)
		"cactus":
			rect(im, 4, 11, 8, 4, Color("c06a3a"))
			ellipse(im, 8, 7, 2.5, 4.5, Color("4f9f5a"))
			rect(im, 4, 5, 2, 4, Color("4f9f5a"))
			line(im, 8, 4, 8, 10, Color("3f8a4a"))
			disc(im, 8, 2.5, 1.6, c1)
		"trap":
			ellipse(im, 6, 8, 3, 4.5, leaf.lightened(0.1))
			ellipse(im, 10, 8, 3, 4.5, leaf.lightened(0.1))
			ellipse(im, 8, 8, 2.5, 3.5, c1)
			for y in [5, 7, 9, 11]:
				px(im, 3, y, Color.WHITE)
				px(im, 12, y, Color.WHITE)
		"bamboo":
			rect(im, 5, 1, 2, 14, Color("8fcf5a"))
			rect(im, 9, 3, 2, 12, Color("7fbf4a"))
			for y in [5, 10]:
				rect(im, 5, y, 2, 1, Color("5a8f3a"))
				rect(im, 9, y + 1, 2, 1, Color("5a8f3a"))
			ellipse(im, 12, 4, 2, 1, leaf)
		"pineapple":
			ellipse(im, 8, 10.5, 3.6, 4.5, c1)
			for y in range(8, 15, 2):
				px(im, 7, y, c1.darkened(0.3))
				px(im, 9, y + 1, c1.darkened(0.3))
			for i in 3:
				line(im, 8, 6, 5 + i * 3, 1, c2)
		"leaf":
			ellipse(im, 8, 8, 5.5, 6, c1)
			for y in [5, 8, 11]:
				im.set_pixel(4, y, Color(0, 0, 0, 0))
				im.set_pixel(12, y + 1, Color(0, 0, 0, 0))
			line(im, 8, 2, 8, 15, c1.darkened(0.3))
		"frond":
			line(im, 3, 15, 12, 2, leaf.darkened(0.2))
			for i in 6:
				var t := 0.12 + i * 0.15
				var p := Vector2(lerp(3.0, 12.0, t), lerp(15.0, 2.0, t))
				line(im, p.x, p.y, p.x - 2.5, p.y - 1, leaf)
				line(im, p.x, p.y, p.x + 1, p.y + 2.5, leaf.lightened(0.12))
			if it["cat"] == "mythical":
				disc(im, 12, 2, 1.4, c2)
		"cone":
			ellipse(im, 8, 9, 3.8, 5.5, c2)
			for y in range(5, 14, 2):
				line(im, 5, y, 11, y + 1, c2.darkened(0.25))
			px(im, 6, 6, c2.lightened(0.4))
		"moss":
			ellipse(im, 8, 11, 6.5, 3.8, leaf)
			for i in 8:
				px(im, 3 + i * 1.4, 8 + (i % 3), leaf.lightened(0.25))
			px(im, 5, 9, c2)
			px(im, 11, 10, c2)
		"mandrake":
			ellipse(im, 8, 11, 3.5, 4, c1)
			px(im, 7, 10, Color("2a1a1a"))
			px(im, 9, 10, Color("2a1a1a"))
			px(im, 8, 12, Color("6a2a2a"))
			for i in 3:
				line(im, 8, 7, 6 + i * 2, 2, c2)
		"sapling":
			line(im, 8, 15, 8, 7, WOOD)
			disc(im, 8, 5.5, 4, c1)
			disc(im, 7, 4.5, 2, c1.lightened(0.25))
			px(im, 10, 6, c2)
			px(im, 5, 6, c2)
		"puffs":
			line(im, 8, 15, 8, 8, Color("6a5a3a"))
			bloom(im, 8, 6, "puffs", c1, c2, 1.3)
		_:
			disc(im, 8, 8, 5, c1)


func _icon_tool(im: Image, tool: String, c: Color) -> void:
	match tool:
		"watering_can":
			ellipse(im, 7, 10, 4.2, 3.6, c)
			rect(im, 3, 7, 8, 5, c)
			line(im, 10, 9, 14, 5, c.darkened(0.1))
			rect(im, 13, 3, 2, 2, c.darkened(0.2))
			line(im, 4, 6, 6, 3, c.darkened(0.25))
			line(im, 6, 3, 9, 3, c.darkened(0.25))
			line(im, 9, 3, 10, 6, c.darkened(0.25))
			px(im, 4, 8, c.lightened(0.4))
		"shovel":
			line(im, 3, 2, 9, 8, WOOD, 2)
			rect(im, 2, 1, 3, 2, WOOD_DARK)
			ellipse(im, 11.5, 11.5, 3, 3.2, c)
			px(im, 10.5, 10, c.lightened(0.4))
		"seed_pouch":
			ellipse(im, 8, 10, 5, 4.6, Color("c8a070").lerp(c, 0.4))
			rect(im, 6, 4, 4, 2, Color("c8a070").lerp(c, 0.4).darkened(0.1))
			line(im, 5, 6, 11, 6, c.darkened(0.3))
			for p in [Vector2(6, 10), Vector2(9, 11), Vector2(8, 8)]:
				px(im, p.x, p.y, Color("6a4a2a"))
		"collection_bag":
			rect(im, 3, 6, 10, 8, Color("8a6a4a"))
			rect(im, 3, 6, 10, 4, c)
			line(im, 4, 6, 8, 1, Color("5a3a2a"))
			line(im, 12, 6, 8, 1, Color("5a3a2a"))
			px(im, 8, 9, Color("f2e23a"))
		"spreader":
			for y in range(4, 10):
				var w := 6 - (y - 4) * 0.6
				rect(im, 8 - w, y, w * 2, 1, c)
			rect(im, 7, 10, 2, 5, WOOD)
			line(im, 9, 12, 13, 12, WOOD_DARK)
			px(im, 5, 5, c.lightened(0.4))
		"sickle":
			for i in 10:
				var a := PI * 1.1 + i * 0.13
				px(im, 8 + cos(a) * 5, 7 + sin(a) * 5, c)
				px(im, 8 + cos(a) * 4, 7 + sin(a) * 4, c.lightened(0.25))
			line(im, 8, 7, 12, 14, WOOD, 2)


func _icon_bag(im: Image, c: Color) -> void:
	rect(im, 4, 4, 8, 10, Color("e8dcc0"))
	rect(im, 4, 7, 8, 4, c)
	rect(im, 5, 2, 6, 2, Color("d0c4a8"))
	px(im, 5, 5, Color("ffffff"))
	for p in [Vector2(6, 8), Vector2(9, 9), Vector2(7, 10)]:
		px(im, p.x, p.y, c.lightened(0.4))


func _icon_treasure(im: Image, it: Dictionary) -> void:
	var c: Color = it["c1"]
	match it["kind"]:
		"pebble":
			ellipse(im, 8, 10, 5, 3.5, c)
			px(im, 6, 8, c.lightened(0.4))
		"feather":
			for i in 10:
				var t := i / 9.0
				ellipse(im, lerp(4.0, 12.0, t), lerp(13.0, 3.0, t), 2.0 * sin(t * PI) + 0.4, 1.0, c)
			line(im, 3, 14, 12, 3, c.darkened(0.4))
		"cone":
			ellipse(im, 8, 9, 4, 5.5, c)
			for y in range(5, 14, 2):
				line(im, 5, y, 11, y, c.darkened(0.3))
		"acorn":
			ellipse(im, 8, 10, 3.5, 4, Color("c08a3a"))
			ellipse(im, 8, 6.5, 4.4, 2.2, c)
			px(im, 8, 3, WOOD_DARK)
		"clover":
			for o in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
				disc(im, 8 + o.x, 7 + o.y, 2.2, c)
			line(im, 8, 9, 10, 15, c.darkened(0.3))
		"gem":
			for y in range(4, 13):
				var w: int = 2 if y == 4 else (4 if y < 7 else int(4 - (y - 6) * 0.65))
				for x in range(8 - w, 8 + w):
					px(im, x, y, c.lightened(0.25) if x < 8 else c.darkened(0.1))
			px(im, 6, 5, Color.WHITE)
		"geode":
			disc(im, 8, 9, 5.5, Color("8a8070"))
			disc(im, 8, 9, 3.5, c)
			px(im, 7, 8, c.lightened(0.5))
			px(im, 9, 10, Color.WHITE)
		"dust":
			ellipse(im, 8, 10, 3.5, 4, Color("e8f0ff", 0.9))
			rect(im, 6, 4, 4, 2, Color("a0683a"))
			for p in [Vector2(7, 9), Vector2(9, 11), Vector2(8, 12), Vector2(6, 11)]:
				px(im, p.x, p.y, c)
		"wing":
			ellipse(im, 6, 7, 4, 5, c)
			ellipse(im, 10, 10, 3, 3.5, c.lightened(0.2))
			px(im, 5, 6, Color.WHITE)
			line(im, 8, 3, 8, 14, c.darkened(0.4))
		"coin":
			disc(im, 8, 8, 5, c)
			disc(im, 8, 8, 3.4, c.darkened(0.15))
			px(im, 6, 6, c.lightened(0.5))
			line(im, 8, 6, 8, 10, c.lightened(0.3))
		"tablet":
			rect(im, 3, 3, 10, 11, c)
			for y in [5, 8, 11]:
				line(im, 5, y, 11, y, c.darkened(0.3))
		"fossil":
			disc(im, 8, 8.5, 5.5, c)
			line(im, 5, 12, 11, 5, c.darkened(0.35))
			for i in 3:
				line(im, 6 + i * 2, 11 - i * 2, 4 + i * 2, 8 - i * 2, c.darkened(0.3))
		"idol":
			rect(im, 5, 6, 6, 8, c)
			disc(im, 8, 5, 3, c)
			px(im, 7, 5, Color("6a3a1a"))
			px(im, 9, 5, Color("6a3a1a"))
			px(im, 6, 7, c.lightened(0.4))
		"shell":
			disc(im, 8, 9, 5, c)
			for i in 12:
				var a := i * 0.55
				var r := 4.5 - i * 0.35
				px(im, 8 + cos(a) * r, 9 + sin(a) * r, c.darkened(0.35))
		"moss":
			ellipse(im, 8, 10, 5.5, 3.5, c)
			for i in 6:
				px(im, 4 + i * 1.5, 8 + (i % 2), c.lightened(0.4))
		"pearl":
			disc(im, 8, 9, 4.5, c)
			disc(im, 6.5, 7.5, 1.3, c.lightened(0.5))
		"ore":
			ellipse(im, 8, 9.5, 5.5, 4.5, c)
			for p in [Vector2(6, 8), Vector2(10, 10), Vector2(8, 11)]:
				px(im, p.x, p.y, Color("f2d23a"))
		"map":
			rect(im, 2, 4, 12, 9, c)
			line(im, 4, 10, 8, 7, Color("c04a3a"))
			line(im, 8, 7, 11, 9, Color("c04a3a"))
			px(im, 11, 9, Color("2a2a2a"))
		"comb":
			for y in 3:
				for x in 3:
					disc(im, 4.5 + x * 3.5 + (y % 2) * 1.5, 5 + y * 3, 1.7, c)
			px(im, 6, 5, c.lightened(0.4))
		_:
			disc(im, 8, 8, 4, c)


# ================================================================= DECOR
func decor_tex(id: String) -> Texture2D:
	var ck := "d:" + id
	if _cache.has(ck):
		return _cache[ck]
	var it: Dictionary = ItemDB.items[id]
	var kind: String = it["kind"]
	var size := Vector2i(16, 16)
	if kind in ["arch", "trellis", "hanging", "scarecrow", "birdhouse", "wishing_well", "lamp", "statue_angel", "statue_gardener", "fairy_lights"]:
		size = Vector2i(16, 24)
	elif kind == "windmill":
		size = Vector2i(16, 32)
	elif kind == "fountain_big":
		size = Vector2i(32, 28)
	var im := new_img(size.x, size.y)
	_draw_decor(im, kind, it["c1"], it["c2"])
	if not it.get("floor", false):
		outline(im, 0.6)
	var t := to_tex(im)
	_cache[ck] = t
	return t


func _draw_decor(im: Image, kind: String, c1: Color, c2: Color) -> void:
	var H := im.get_height()
	var W := im.get_width()
	match kind:
		"bench":
			rect(im, 1, 7, 14, 2, c1.lightened(0.1))
			rect(im, 1, 10, 14, 2, c1)
			rect(im, 2, 12, 2, 3, c1.darkened(0.3))
			rect(im, 12, 12, 2, 3, c1.darkened(0.3))
			rect(im, 1, 4, 14, 2, c1.lightened(0.15))
		"stone_bench":
			rect(im, 1, 8, 14, 3, c1)
			rect(im, 1, 8, 14, 1, c1.lightened(0.2))
			rect(im, 2, 11, 3, 4, c1.darkened(0.2))
			rect(im, 11, 11, 3, 4, c1.darkened(0.2))
		"table":
			rect(im, 1, 6, 14, 5, c2)
			for x in range(1, 15, 2):
				for y in range(6, 11, 2):
					px(im, x + (y / 2) % 2, y, Color.WHITE)
			rect(im, 2, 11, 2, 4, c1.darkened(0.2))
			rect(im, 12, 11, 2, 4, c1.darkened(0.2))
		"chair":
			rect(im, 4, 3, 8, 5, c1)
			rect(im, 3, 8, 10, 2, c1.darkened(0.05))
			rect(im, 4, 10, 1, 5, c1.darkened(0.2))
			rect(im, 11, 10, 1, 5, c1.darkened(0.2))
		"birdbath":
			ellipse(im, 8, 6, 6, 2.5, c1)
			ellipse(im, 8, 5.6, 4.5, 1.5, c2)
			rect(im, 7, 7, 2, 6, c1.darkened(0.15))
			rect(im, 5, 13, 6, 2, c1.darkened(0.1))
		"fountain":
			ellipse(im, 8, 11, 7, 3.6, c1)
			ellipse(im, 8, 10.5, 5.5, 2.4, c2)
			rect(im, 7, 4, 2, 7, c1.lightened(0.1))
			ellipse(im, 8, 4.5, 3, 1.2, c1)
			px(im, 8, 2, c2.lightened(0.5))
			px(im, 6, 3, c2.lightened(0.3))
			px(im, 10, 3, c2.lightened(0.3))
		"fountain_big":
			ellipse(im, 16, 20, 15, 6.5, c1)
			ellipse(im, 16, 19.5, 12.5, 4.6, c2)
			for i in 6:
				px(im, 8 + i * 3, 19 + (i % 2), c2.lightened(0.4))
			rect(im, 14, 8, 4, 12, c1.darkened(0.05))
			ellipse(im, 16, 9, 6, 2.2, c1)
			ellipse(im, 16, 8.6, 4.4, 1.2, c2)
			rect(im, 15, 3, 2, 6, c1.lightened(0.1))
			disc(im, 16, 2.5, 1.6, c2.lightened(0.4))
			for i in 4:
				line(im, 16, 3, 10 + i * 4, 8, Color(c2.lightened(0.5), 0.7))
		"gnome":
			ellipse(im, 8, 11, 3.5, 3.5, c2)
			disc(im, 8, 7, 2.2, Color("f2c8a0"))
			ellipse(im, 8, 9, 2.5, 1.6, Color.WHITE)
			for y in range(1, 6):
				rect(im, 8 - (y - 1) * 0.7, y, (y - 1) * 1.4 + 1, 1, c1)
			rect(im, 5, 14, 2, 1, Color("4a3020"))
			rect(im, 9, 14, 2, 1, Color("4a3020"))
		"statue_angel", "statue_gardener":
			rect(im, 4, H - 4, 8, 4, Color("a8a8a0") if kind == "statue_angel" else Color("8a7a5a"))
			ellipse(im, 8, H - 10, 3, 6, c1)
			disc(im, 8, H - 17, 2.2, c1.lightened(0.05))
			if kind == "statue_angel":
				ellipse(im, 3.5, H - 12, 2.5, 4, c1.darkened(0.08))
				ellipse(im, 12.5, H - 12, 2.5, 4, c1.darkened(0.08))
				ellipse(im, 8, H - 20, 2.5, 0.8, Color("f2e27a"))
			else:
				ellipse(im, 8, H - 19, 4.5, 1.3, c1.darkened(0.1))
				line(im, 11, H - 12, 13, H - 17, c1.darkened(0.2))
				disc(im, 13, H - 18, 1.5, c1.lightened(0.2))
		"statue_fox":
			rect(im, 3, 12, 10, 3, Color("a8a8a0"))
			ellipse(im, 8, 9, 3.5, 3, c1)
			disc(im, 8, 5, 2.5, c1)
			px(im, 6, 2, c1)
			px(im, 10, 2, c1)
			px(im, 6, 3, c1)
			px(im, 10, 3, c1)
			ellipse(im, 12, 9, 2, 1.5, c2)
			px(im, 7, 5, Color("2a1a1a"))
			px(im, 9, 5, Color("2a1a1a"))
		"statue_owl":
			rect(im, 4, 13, 8, 2, Color("8a6a4a"))
			ellipse(im, 8, 8, 4, 5, c1)
			disc(im, 6.5, 6, 1.5, c2)
			disc(im, 9.5, 6, 1.5, c2)
			px(im, 6.5, 6, Color("2a1a1a"))
			px(im, 9.5, 6, Color("2a1a1a"))
			px(im, 8, 8, Color("e0903a"))
		"statue_frog":
			ellipse(im, 8, 11, 5, 3.5, c1)
			disc(im, 5.5, 7.5, 1.8, c1)
			disc(im, 10.5, 7.5, 1.8, c1)
			px(im, 5.5, 7.5, Color("2a1a1a"))
			px(im, 10.5, 7.5, Color("2a1a1a"))
			line(im, 6, 12, 10, 12, c1.darkened(0.3))
			ellipse(im, 8, 12.5, 2.5, 1, c2)
		"lantern":
			rect(im, 5, 13, 6, 2, c1.darkened(0.1))
			rect(im, 7, 9, 2, 4, c1)
			rect(im, 4, 5, 8, 4, c1)
			rect(im, 6, 6, 4, 2, c2)
			for y in [3, 4]:
				rect(im, 4 - (4 - y), y, 8 + (4 - y) * 2, 1, c1.darkened(0.15))
		"lamp":
			rect(im, 7, 6, 2, H - 7, c1)
			rect(im, 5, H - 2, 6, 2, c1)
			rect(im, 5, 2, 6, 5, c1)
			rect(im, 6, 3, 4, 3, c2)
			rect(im, 4, 1, 8, 1, c1)
		"arch":
			for x in [2, 13]:
				rect(im, x, 6, 2, H - 6, c1)
			for i in 11:
				var a := PI + PI * i / 10.0
				disc(im, 8 + cos(a) * 6, 8 + sin(a) * 6, 1.3, c1)
			for i in 9:
				var a2 := PI + PI * i / 8.0
				disc(im, 8 + cos(a2) * 6.5, 7.5 + sin(a2) * 6.5, 1.0, c2 if i % 2 == 0 else Color("5fae3f"))
			for y in range(10, H - 2, 4):
				px(im, 2, y, c2)
				px(im, 14, y + 2, c2)
				px(im, 3, y + 1, Color("5fae3f"))
		"trellis":
			for x in [3, 7, 11]:
				rect(im, x, 2, 1, H - 2, c1)
			for y in range(3, H - 2, 4):
				rect(im, 2, y, 12, 1, c1)
			for i in 9:
				var y2 := 4 + i * 2.2
				disc(im, 4 + (i % 3) * 4 + (i % 2), y2, 1.3, Color("5fae3f"))
				if i % 2 == 0:
					disc(im, 5 + (i % 3) * 3.5, y2 + 1, 1.2, c2)
		"fence":
			rect(im, 2, 4, 2, 11, c1)
			rect(im, 12, 4, 2, 11, c1)
			rect(im, 0, 6, 16, 2, c1.lightened(0.1))
			rect(im, 0, 11, 16, 2, c1.lightened(0.1))
		"picket":
			for x in [1, 5, 9, 13]:
				rect(im, x, 4, 2, 11, c1)
				px(im, x, 3, c1)
			rect(im, 0, 7, 16, 1, c1.darkened(0.1))
			rect(im, 0, 12, 16, 1, c1.darkened(0.1))
		"path_stone":
			for p in [Vector2(4, 4), Vector2(11, 4), Vector2(4, 11), Vector2(11, 11), Vector2(8, 8)]:
				ellipse(im, p.x, p.y, 3.2, 2.6, c1)
				px(im, p.x - 1, p.y - 1, c1.lightened(0.25))
				px(im, p.x + 1, p.y + 1, c1.darkened(0.2))
		"path_brick":
			for y in 8:
				for x in 4:
					var ox := (x * 4 + (2 if y % 2 == 1 else 0)) % 16
					rect(im, ox, y * 2, 3, 1, c1 if (x + y) % 3 != 0 else c1.darkened(0.12))
					rect(im, ox, y * 2 + 1, 3, 1, c1.darkened(0.2))
		"stepping":
			ellipse(im, 5, 5, 3.5, 2.5, c1)
			ellipse(im, 11, 11, 3.5, 2.5, c1)
			px(im, 4, 4, c1.lightened(0.3))
			px(im, 10, 10, c1.lightened(0.3))
		"pot":
			rect(im, 4, 9, 8, 6, c1)
			rect(im, 3, 8, 10, 2, c1.lightened(0.15))
			px(im, 5, 10, c1.lightened(0.35))
			ellipse(im, 6, 5, 2, 1.5, Color("5fae3f"))
			ellipse(im, 10, 4.5, 2, 1.5, Color("6fbf4f"))
			disc(im, 8, 3.5, 1.5, c2)
			line(im, 8, 8, 8, 5, Color("3f8a3a"))
		"hanging":
			line(im, 8, 0, 8, 10, Color("6a4a2a"))
			line(im, 8, 2, 4, 10, Color("6a4a2a"))
			line(im, 8, 2, 12, 10, Color("6a4a2a"))
			ellipse(im, 8, 12, 5, 2.5, c1)
			for i in 6:
				line(im, 4 + i * 1.6, 12, 3 + i * 1.8, 18 + (i % 3) * 2, Color("5fae3f"))
				disc(im, 3 + i * 1.8, 17 + (i % 3) * 2, 1, c2)
			rect(im, 7, H - 2, 2, 2, Color("6a4a2a"))
		"windmill":
			rect(im, 5, 12, 6, H - 12, c1)
			rect(im, 4, 10, 8, 3, c2)
			rect(im, 7, H - 5, 2, 5, c1.darkened(0.4))
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				line(im, 8, 8, 8 + d.x * 7, 8 + d.y * 7, Color("e8e0d0"), 2)
			disc(im, 8, 8, 1.4, c2.darkened(0.2))
		"scarecrow":
			rect(im, 7, 7, 2, H - 7, WOOD)
			rect(im, 2, 10, 12, 2, WOOD)
			rect(im, 5, 10, 6, 7, c2)
			disc(im, 8, 6, 3, Color("e8d090"))
			rect(im, 3, 2, 10, 2, c1)
			rect(im, 5, 0, 6, 3, c1)
			px(im, 7, 6, Color("2a1a1a"))
			px(im, 9, 6, Color("2a1a1a"))
			for x in [2, 13]:
				px(im, x, 12, c1)
		"beehive":
			for i in 4:
				ellipse(im, 8, 5 + i * 2.6, 3 + i * 0.9, 1.6, c1 if i % 2 == 0 else c1.darkened(0.12))
			rect(im, 6, 13, 4, 2, c2)
			disc(im, 8, 11, 1, Color("3a2a1a"))
			px(im, 13, 4, Color("2a2a2a"))
			px(im, 12, 4, Color("f2e23a"))
		"birdhouse":
			rect(im, 7, 12, 2, H - 12, WOOD)
			rect(im, 4, 6, 8, 7, c2)
			for y in 4:
				rect(im, 8 - y - 1, 2 + y, (y + 1) * 2, 1, c1)
			disc(im, 8, 9, 1.4, Color("2a1a1a"))
			rect(im, 7, 11, 2, 1, WOOD_DARK)
		"wheelbarrow":
			rect(im, 3, 6, 9, 5, c1)
			rect(im, 3, 6, 9, 1, c1.lightened(0.2))
			ellipse(im, 7.5, 5.5, 4, 1, Color("6a4a2a"))
			disc(im, 12.5, 12, 2.2, Color("3a3a3a"))
			line(im, 3, 9, 0, 13, c2)
			line(im, 4, 11, 4, 14, c2)
		"sundial":
			rect(im, 6, 8, 4, 6, c1.darkened(0.1))
			rect(im, 5, 14, 6, 1, c1.darkened(0.2))
			ellipse(im, 8, 7, 6, 2.5, c1)
			line(im, 8, 7, 11, 3, c2)
			line(im, 8, 7, 11, 7, c2.darkened(0.2))
		"wishing_well":
			ellipse(im, 8, H - 5, 6.5, 3.5, c1)
			ellipse(im, 8, H - 6, 4.5, 1.8, Color("2a4a6a"))
			rect(im, 2, 6, 2, H - 10, c2)
			rect(im, 12, 6, 2, H - 10, c2)
			for y in 4:
				rect(im, 8 - y * 2 - 2, 2 + y, y * 4 + 4, 1, Color("b0503a"))
			line(im, 4, 9, 12, 9, Color("6a4a2a"))
			rect(im, 7, 9, 2, 5, Color("6a4a2a"))
		"mushroom_lamp":
			rect(im, 6, 8, 4, 7, Color("efe6d2"))
			ellipse(im, 8, 7, 6.5, 4, c1)
			px(im, 6, 5, c2)
			px(im, 10, 6, c2)
			px(im, 8, 4, c2)
			ellipse(im, 8, 12, 1.5, 1.5, c2)
		"crystal_lamp":
			rect(im, 5, 13, 6, 2, Color("5a5070"))
			_shard(im, 8, 13, 12, 5, c1)
			_shard(im, 5, 13, 6, 2, c1.darkened(0.1))
			_shard(im, 11, 13, 7, 2, c1.lightened(0.1))
		"fairy_lights":
			for x in [1, 14]:
				rect(im, x, 4, 1, H - 4, c1)
			for i in 14:
				var y := 6 + sin(i / 13.0 * PI) * 5
				px(im, 1 + i, y, Color("3a3a3a"))
				if i % 2 == 0:
					disc(im, 1 + i, y + 1, 1, Color.from_hsv(i / 14.0, 0.4, 1.0))
		"trophy":
			rect(im, 5, 13, 6, 2, Color("6a4a2a"))
			rect(im, 7, 10, 2, 3, c1.darkened(0.1))
			ellipse(im, 8, 6, 4.5, 4, c1)
			rect(im, 3, 3, 10, 2, c1.lightened(0.1))
			px(im, 2, 6, c1)
			px(im, 13, 6, c1)
			px(im, 6, 5, c1.lightened(0.5))
			if c1 == Color("ff6ab0"):
				for i in 5:
					px(im, 5 + i, 7, Color.from_hsv(i / 5.0, 0.7, 1.0))
		_:
			rect(im, 4, 4, 8, 8, c1)


# ================================================================= TILES
## Season-aware palette for grass-type grounds.
func season_grass(season: int) -> Color:
	return [Color("6fbf4a"), Color("57a83c"), Color("b8a24a"), Color("e8eef4")][season]


func tile(kind: String, variant: int, season: int) -> Image:
	var ck := "t:%s:%d:%d" % [kind, variant, season]
	if _cache.has(ck):
		return _cache[ck]
	var im := new_img(16, 16)
	var rng := _rng(ck)
	var g := season_grass(season)
	var winter := season == 3
	match kind:
		"grass", "farm", "flower", "fairy", "jungle", "darkgrass":
			var base := g
			if kind == "fairy":
				base = Color("9fe8c0") if not winter else Color("e0f0f8")
			elif kind == "jungle":
				base = g.darkened(0.18) if not winter else g.darkened(0.06)
			elif kind == "farm":
				base = g.darkened(0.16).lerp(Color("8a6a40"), 0.12)
			elif kind == "darkgrass":
				base = g.darkened(0.12)
			im.fill(base)
			for i in 14:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), base.lightened(0.08) if i % 2 == 0 else base.darkened(0.07))
			for i in (3 if kind != "farm" else 1):
				var x := rng.randi_range(1, 14)
				var y := rng.randi_range(2, 14)
				px(im, x, y, base.darkened(0.18))
				px(im, x - 1, y - 1, base.darkened(0.14))
				px(im, x + 1, y - 1, base.darkened(0.14))
			if kind == "farm":
				for i in 4:
					px(im, rng.randi_range(1, 14), rng.randi_range(1, 14), Color("7a5a3a"))
				for xx in range(0, 16, 4):
					px(im, xx, 0, base.darkened(0.12))
					px(im, 0, xx, base.darkened(0.12))
			if kind == "flower" and variant % 2 == 0 and not winter:
				var cols := [Color("f06a8a"), Color("f2e25a"), Color("ffffff"), Color("a07ae0"), Color("f0903a")]
				for i in rng.randi_range(1, 3):
					var fx := rng.randi_range(2, 13)
					var fy := rng.randi_range(2, 13)
					var fc: Color = cols[rng.randi_range(0, cols.size() - 1)]
					px(im, fx, fy, fc)
					px(im, fx + 1, fy, fc.darkened(0.15))
					px(im, fx, fy + 1, Color("3f8a3a"))
			if kind == "fairy":
				for i in 2:
					px(im, rng.randi_range(1, 14), rng.randi_range(1, 14), Color("ffd0f0") if i == 0 else Color("fff8a0"))
			if winter and kind != "fairy":
				for i in 6:
					px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("c8d8e8"))
		"path":
			var pc := Color("c8a070") if not winter else Color("d8c8b0")
			im.fill(pc)
			for i in 10:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), pc.darkened(0.1))
			for i in 3:
				var x2 := rng.randi_range(1, 14)
				var y2 := rng.randi_range(1, 14)
				px(im, x2, y2, Color("9a8a7a"))
				px(im, x2 + 1, y2, Color("b8a898"))
		"plaza":
			im.fill(Color("b8b0a0"))
			for y in 4:
				for x in 4:
					var ox := x * 4 + (2 if y % 2 == 1 else 0)
					rect(im, ox % 16, y * 4, 3, 3, Color("c8c0b0") if (x + y + variant) % 3 else Color("b0a898"))
					px(im, ox % 16, y * 4, Color("d8d0c0"))
		"patio":
			im.fill(Color("a89890"))
			rect(im, 0, 0, 8, 8, Color("c8b8a8"))
			rect(im, 8, 8, 8, 8, Color("c8b8a8"))
			rect(im, 8, 0, 8, 8, Color("b8a898"))
			rect(im, 0, 8, 8, 8, Color("b8a898"))
			for p in [Vector2i(7, 0), Vector2i(15, 0), Vector2i(0, 7), Vector2i(0, 15)]:
				pass
		"water":
			im.fill(Color("4a90d0"))
			for i in 3:
				var x3 := rng.randi_range(0, 11)
				var y3 := rng.randi_range(1, 14)
				rect(im, x3, y3, rng.randi_range(2, 4), 1, Color("78b8f0"))
			if winter:
				im.fill(Color("b8d8f0"))
				line(im, 2, 3, 6, 7, Color("e8f4ff"))
				line(im, 9, 8, 13, 12, Color("e8f4ff"))
		"sand":
			im.fill(Color("e8d8a0"))
			for i in 8:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("d8c890"))
		"stone":
			var sc := Color("8a8a84") if not winter else Color("b8bcc8")
			im.fill(sc)
			for i in 12:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), sc.lightened(0.1) if i % 2 else sc.darkened(0.1))
			line(im, rng.randi_range(0, 8), rng.randi_range(2, 13), rng.randi_range(8, 15), rng.randi_range(2, 13), sc.darkened(0.15))
		"snow":
			im.fill(Color("eef4fa"))
			for i in 6:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("d0dcea"))
		"cave":
			im.fill(Color("4a4258"))
			for i in 12:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("564e66") if i % 2 else Color("3e3850"))
			if variant == 0:
				px(im, rng.randi_range(2, 13), rng.randi_range(2, 13), Color("5af0b0"))
		"crystal":
			im.fill(Color("8070a8"))
			for i in 10:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("9080b8") if i % 2 else Color("7060a0"))
			if variant % 2 == 0:
				var x4 := rng.randi_range(2, 13)
				var y4 := rng.randi_range(2, 13)
				px(im, x4, y4, Color("e0d0ff"))
				px(im, x4 + 1, y4 + 1, Color("b8a0f0"))
		"ruin":
			im.fill(Color("a09a88"))
			rect(im, 0, 0, 16, 1, Color("8a8474"))
			rect(im, 0, 8, 16, 1, Color("8a8474"))
			rect(im, (variant * 5) % 16, 0, 1, 8, Color("8a8474"))
			rect(im, (variant * 5 + 8) % 16, 8, 1, 8, Color("8a8474"))
			if variant == 1:
				line(im, 3, 3, 9, 12, Color("7a7464"))
			if variant >= 2:
				px(im, rng.randi_range(1, 14), rng.randi_range(1, 14), Color("5f9a3f"))
				px(im, rng.randi_range(1, 14), rng.randi_range(1, 14), Color("4f8a3f"))
		"glass":
			im.fill(Color("c8dcd4"))
			rect(im, 0, 0, 16, 1, Color("a8c0b8"))
			rect(im, 0, 0, 1, 16, Color("a8c0b8"))
			px(im, 4, 4, Color("e0f0ec"))
		"magic":
			im.fill(Color("7a6aa0"))
			for i in 10:
				px(im, rng.randi_range(0, 15), rng.randi_range(0, 15), Color("8a7ab8") if i % 2 else Color("6a5a90"))
			px(im, rng.randi_range(1, 14), rng.randi_range(1, 14), Color("fff0a0"))
		"soil", "soil_wet", "soil_magic":
			var sc2 := SOIL
			if kind == "soil_wet":
				sc2 = SOIL_WET
			elif kind == "soil_magic":
				sc2 = Color("6a4a7a")
			im.fill(sc2)
			rect(im, 0, 0, 16, 1, sc2.lightened(0.12))
			rect(im, 0, 0, 1, 16, sc2.lightened(0.08))
			rect(im, 0, 15, 16, 1, sc2.darkened(0.25))
			rect(im, 15, 0, 1, 16, sc2.darkened(0.2))
			for y in [4, 8, 12]:
				line(im, 2, y, 13, y, sc2.darkened(0.22))
				line(im, 2, y + 1, 13, y + 1, sc2.lightened(0.08))
			for i in 4:
				px(im, rng.randi_range(2, 13), rng.randi_range(2, 13), sc2.darkened(0.12))
			if kind == "soil_magic":
				px(im, rng.randi_range(2, 13), rng.randi_range(2, 13), Color("fff0a0"))
				px(im, rng.randi_range(2, 13), rng.randi_range(2, 13), Color("ffb0f0"))
		"wall_glass":
			im.fill(Color("bfe0f0"))
			rect(im, 0, 0, 16, 2, Color("f4f4f0"))
			rect(im, 0, 7, 16, 1, Color("f4f4f0"))
			rect(im, 0, 0, 2, 16, Color("f4f4f0"))
			rect(im, 8, 0, 1, 12, Color("f4f4f0"))
			line(im, 3, 5, 6, 2, Color("ffffff"))
			line(im, 10, 11, 13, 8, Color("ffffff"))
			rect(im, 0, 12, 16, 4, Color("8a9aa0"))
		"wall_hedge":
			var hc := Color("3f7f3a") if not winter else Color("5a7a6a")
			im.fill(hc)
			for i in 6:
				disc(im, rng.randi_range(1, 14), rng.randi_range(1, 10), 2, hc.lightened(0.12))
			rect(im, 0, 12, 16, 4, hc.darkened(0.3))
			if winter:
				rect(im, 0, 0, 16, 3, Color("eef4fa"))
				for x in range(0, 16, 3):
					px(im, x, 3, Color("eef4fa"))
		"wall_rock":
			im.fill(Color("6a6670"))
			for i in 5:
				ellipse(im, rng.randi_range(1, 14), rng.randi_range(1, 11), 3, 2, Color("7a7680"))
			rect(im, 0, 12, 16, 4, Color("4a4650"))
			px(im, 4, 3, Color("8a8690"))
			if winter:
				rect(im, 0, 0, 16, 2, Color("eef4fa"))
		"wall_cave":
			im.fill(Color("2e2838"))
			for i in 5:
				ellipse(im, rng.randi_range(1, 14), rng.randi_range(1, 11), 3, 2, Color("3a3448"))
			rect(im, 0, 12, 16, 4, Color("221e2a"))
			px(im, rng.randi_range(2, 13), rng.randi_range(2, 10), Color("5af0b0"))
		"wall_crystal":
			im.fill(Color("4a3a70"))
			_shard(im, 4, 13, 9, 4, Color("a080e0"))
			_shard(im, 11, 13, 7, 3, Color("8ac0f0"))
			rect(im, 0, 13, 16, 3, Color("342a50"))
		"wall_ruin":
			im.fill(Color("8a8474"))
			for y in 3:
				for x in 2:
					rect(im, x * 8 + (4 if y % 2 else 0), y * 4, 7, 3, Color("a09a88"))
			rect(im, 0, 12, 16, 4, Color("6a6458"))
			px(im, 3, 2, Color("5f9a3f"))
			px(im, 12, 6, Color("5f9a3f"))
		_:
			im.fill(Color.MAGENTA)
	_cache[ck] = im
	return im


# ================================================================= OBJECTS
## Large static world objects: trees, rocks, buildings, signs ...
func object_tex(kind: String, season: int = 0, variant: int = 0) -> Texture2D:
	var ck := "o:%s:%d:%d" % [kind, season, variant]
	if _cache.has(ck):
		return _cache[ck]
	var im: Image
	var rng := _rng(ck)
	var winter := season == 3
	match kind:
		"tree":
			im = new_img(32, 40)
			var leafc: Color = [Color("5aae4a"), Color("3f8f3a"), [Color("e8873a"), Color("d0602a"), Color("e8b03a")][variant % 3], Color("5a7a5a")][season]
			rect(im, 14, 26, 4, 14, WOOD)
			rect(im, 16, 26, 2, 14, WOOD_DARK)
			px(im, 13, 39, WOOD)
			px(im, 18, 39, WOOD_DARK)
			if winter:
				line(im, 16, 26, 8, 14, WOOD, 2)
				line(im, 16, 24, 24, 12, WOOD, 2)
				line(im, 16, 26, 16, 8, WOOD, 2)
				line(im, 12, 18, 9, 10, WOOD_DARK)
				for p in [Vector2(8, 13), Vector2(23, 11), Vector2(16, 7), Vector2(9, 9)]:
					ellipse(im, p.x, p.y, 2.5, 1.2, Color("f4f8ff"))
			else:
				disc(im, 16, 18, 11, leafc.darkened(0.22))
				disc(im, 11, 16, 7, leafc.darkened(0.08))
				disc(im, 20, 14, 7.5, leafc)
				disc(im, 15, 10, 7, leafc.lightened(0.08))
				disc(im, 13, 8, 3.5, leafc.lightened(0.2))
				for i in 8:
					px(im, rng.randi_range(7, 25), rng.randi_range(6, 26), leafc.darkened(0.3))
		"pine":
			im = new_img(24, 40)
			rect(im, 10, 32, 4, 8, WOOD)
			var pc := Color("2f6f4a") if not winter else Color("3f6a5a")
			for i in 4:
				var y := 6 + i * 7
				var w := 4 + i * 2.6
				for yy in 9:
					var ww := w * (yy / 8.0)
					rect(im, 12 - ww, y + yy, ww * 2, 1, pc.lightened(0.06) if yy < 3 else pc)
				if winter:
					rect(im, 12 - w * 0.5, y + 4, w, 1, Color("f4f8ff"))
			px(im, 12, 4, pc)
			px(im, 11, 5, pc)
			px(im, 12, 5, pc)
		"rock":
			im = new_img(16, 16)
			ellipse(im, 8, 10, 6.5, 5, Color("8a8a90"))
			ellipse(im, 7, 8.5, 4.5, 3, Color("a0a0a8"))
			px(im, 5, 7, Color("c0c0c8"))
			if winter:
				ellipse(im, 7, 6.5, 4, 1.2, Color("f4f8ff"))
		"bigrock":
			im = new_img(32, 24)
			ellipse(im, 16, 15, 14, 8.5, Color("7a7a82"))
			ellipse(im, 13, 12, 9, 6, Color("929298"))
			ellipse(im, 21, 14, 6, 4, Color("86868e"))
			px(im, 9, 9, Color("b8b8c0"))
			if winter:
				ellipse(im, 14, 8, 9, 2.5, Color("f4f8ff"))
		"bush":
			im = new_img(16, 16)
			var bc: Color = [Color("4f9f3a"), Color("3f8a3a"), Color("a08a3a"), Color("5a7a6a")][season]
			ellipse(im, 8, 10, 7, 5.5, bc.darkened(0.15))
			disc(im, 5.5, 8, 3.5, bc)
			disc(im, 10.5, 8.5, 3.2, bc.lightened(0.08))
			if season == 1 or season == 0:
				for i in 3:
					px(im, rng.randi_range(3, 12), rng.randi_range(6, 12), Color("e04a5a"))
			if winter:
				ellipse(im, 8, 5.5, 5, 1.5, Color("f4f8ff"))
		"crystal_rock":
			im = new_img(16, 24)
			ellipse(im, 8, 21, 7, 2.5, Color("4a3a70"))
			var cc: Color = [Color("a080e0"), Color("80c0f0"), Color("f080c0")][variant % 3]
			_shard(im, 8, 21, 16, 5, cc)
			_shard(im, 4, 21, 9, 3, cc.darkened(0.1))
			_shard(im, 12, 21, 11, 3, cc.lightened(0.1))
		"pillar":
			im = new_img(16, 32)
			rect(im, 4, 6, 8, 24, Color("b0aa98"))
			rect(im, 4, 6, 2, 24, Color("c8c2b0"))
			rect(im, 10, 6, 2, 24, Color("8a8474"))
			rect(im, 2, 3, 12, 3, Color("c0baa8"))
			rect(im, 2, 29, 12, 3, Color("a09a88"))
			if variant % 2 == 0:
				for i in 6:
					px(im, rng.randi_range(4, 11), rng.randi_range(8, 28), Color("5f9a3f"))
				line(im, 5, 10, 9, 22, Color("4f8a3f"))
			else:
				im.fill_rect(Rect2i(2, 0, 12, 6), Color(0, 0, 0, 0))
				line(im, 4, 7, 12, 4, Color("a09a88"))
		"giant_mushroom":
			im = new_img(32, 32)
			var mc: Color = [Color("e04a8a"), Color("4ac0e0"), Color("8a6ae0")][variant % 3]
			rect(im, 13, 14, 6, 18, Color("e8e0d0"))
			rect(im, 17, 14, 2, 18, Color("c8c0b0"))
			ellipse(im, 16, 12, 14, 9, mc)
			line(im, 3, 16, 29, 16, mc.darkened(0.35))
			for p in [Vector2(10, 8), Vector2(20, 6), Vector2(16, 11), Vector2(24, 11)]:
				disc(im, p.x, p.y, 1.6, mc.lightened(0.5))
		"giant_flower":
			im = new_img(16, 32)
			var fc: Color = [Color("f06aa0"), Color("f2d23a"), Color("a07ae0")][variant % 3]
			line(im, 8, 31, 8, 10, Color("4f9f4a"))
			line(im, 9, 31, 9, 10, Color("3f8f3a"))
			ellipse(im, 4, 22, 3.5, 1.5, Color("5fae4a"))
			ellipse(im, 12, 17, 3.5, 1.5, Color("5fae4a"))
			bloom(im, 8, 7, "round", fc, Color("fff0a0"), 1.6)
		"stump":
			im = new_img(16, 16)
			ellipse(im, 8, 11, 6, 3.5, WOOD)
			rect(im, 2, 8, 12, 4, WOOD)
			ellipse(im, 8, 8, 6, 2.5, Color("c8a070"))
			ellipse(im, 8, 8, 3, 1.2, Color("b08a5a"))
		"house":
			im = new_img(64, 56)
			_building(im, Color("e8d8b8"), Color("c0503a"), true)
		"shop":
			im = new_img(64, 56)
			_building(im, Color("d8c8a8"), Color("3a7ac0"), false)
			rect(im, 8, 30, 48, 4, Color("f2f0e8"))
			for x in range(8, 56, 8):
				rect(im, x, 30, 4, 4, Color("e04a4a"))
			rect(im, 22, 18, 20, 6, Color("8a5a32"))
			rect(im, 24, 20, 16, 2, Color("f2d23a"))
		"cottage":
			im = new_img(48, 48)
			var rc: Color = [Color("6a8ac0"), Color("8a6ab0"), Color("c08a3a"), Color("5a9a6a")][variant % 4]
			_building(im, Color("efe2c8"), rc, true)
		"well":
			im = new_img(16, 24)
			ellipse(im, 8, 19, 7, 4, Color("a8a8a0"))
			ellipse(im, 8, 18, 5, 2, Color("2a4a6a"))
			rect(im, 1, 6, 2, 12, WOOD)
			rect(im, 13, 6, 2, 12, WOOD)
			for y in 5:
				rect(im, 8 - y * 2 - 2, 1 + y, y * 4 + 4, 1, Color("b0503a"))
			rect(im, 7, 7, 2, 6, Color("8a6a4a"))
		"bin":
			im = new_img(16, 16)
			rect(im, 1, 5, 14, 10, WOOD)
			rect(im, 1, 5, 14, 2, Color("b07a48"))
			for x in [4, 8, 12]:
				rect(im, x, 7, 1, 8, WOOD_DARK)
			rect(im, 0, 3, 16, 2, Color("7a4a2a"))
		"board":
			im = new_img(16, 24)
			rect(im, 2, 14, 2, 10, WOOD_DARK)
			rect(im, 12, 14, 2, 10, WOOD_DARK)
			rect(im, 0, 3, 16, 13, WOOD)
			rect(im, 1, 4, 14, 11, Color("c8a070"))
			rect(im, 2, 5, 5, 4, Color("f8f0e0"))
			rect(im, 9, 6, 5, 5, Color("f8f0e0"))
			rect(im, 3, 10, 4, 4, Color("fff0a0"))
			px(im, 4, 5, Color("e04a4a"))
			px(im, 11, 6, Color("e04a4a"))
		"sign":
			im = new_img(16, 16)
			rect(im, 7, 9, 2, 7, WOOD_DARK)
			rect(im, 1, 2, 14, 8, WOOD)
			rect(im, 2, 3, 12, 6, Color("c8a070"))
			line(im, 4, 5, 11, 5, WOOD_DARK)
			line(im, 4, 7, 9, 7, WOOD_DARK)
		"construction":
			im = new_img(16, 16)
			rect(im, 3, 9, 2, 7, WOOD_DARK)
			rect(im, 11, 9, 2, 7, WOOD_DARK)
			rect(im, 1, 3, 14, 7, Color("f2c23a"))
			for x in range(1, 15, 4):
				line(im, x, 9, x + 3, 3, Color("2a2a2a"))
			rect(im, 0, 12, 16, 2, Color("e04a3a"))
		"gate":
			im = new_img(16, 24)
			rect(im, 0, 4, 3, 20, WOOD_DARK)
			rect(im, 13, 4, 3, 20, WOOD_DARK)
			for x in range(3, 13, 2):
				rect(im, x, 8, 1, 14, WOOD)
			rect(im, 3, 9, 10, 2, Color("b07a48"))
			rect(im, 3, 17, 10, 2, Color("b07a48"))
			rect(im, 6, 11, 4, 4, Color("d8b030"))
			rect(im, 7, 9, 2, 2, Color("8a8a8a"))
			px(im, 8, 13, Color("2a2a2a"))
		"station":
			im = new_img(16, 24)
			rect(im, 2, 10, 12, 14, Color("6a8ac0"))
			rect(im, 2, 10, 12, 2, Color("8aaae0"))
			ellipse(im, 8, 8, 5, 5, Color("c8e8f8", 0.9))
			disc(im, 8, 8, 2, Color("6faf4a"))
			px(im, 8, 6, Color("f06a8a"))
			rect(im, 5, 16, 6, 4, Color("3a4a6a"))
			px(im, 6, 17, Color("5af08a"))
			px(im, 9, 17, Color("f2d23a"))
		"lab":
			im = new_img(32, 24)
			rect(im, 1, 12, 30, 3, WOOD)
			rect(im, 2, 15, 2, 9, WOOD_DARK)
			rect(im, 28, 15, 2, 9, WOOD_DARK)
			for i in 4:
				var fx := 5 + i * 7
				var fc2: Color = [Color("5af0b0"), Color("f06aa0"), Color("f2d23a"), Color("8a9af0")][i]
				ellipse(im, fx, 9, 2.5, 2.5, Color("d8f0f8", 0.8))
				ellipse(im, fx, 10, 2, 1.5, fc2)
				rect(im, fx - 1, 4, 2, 4, Color("d8f0f8", 0.8))
			rect(im, 20, 16, 8, 6, Color("8a6a4a"))
		"stall":
			im = new_img(32, 32)
			rect(im, 2, 18, 28, 14, WOOD)
			rect(im, 2, 18, 28, 3, Color("b07a48"))
			rect(im, 3, 6, 2, 12, WOOD_DARK)
			rect(im, 27, 6, 2, 12, WOOD_DARK)
			for x in range(0, 32, 6):
				rect(im, x, 3, 3, 5, Color("f06a8a"))
				rect(im, x + 3, 3, 3, 5, Color("fff0e0"))
			for i in 4:
				disc(im, 7 + i * 6, 22, 2, Color.from_hsv(i / 4.0, 0.5, 1.0))
		"fountain_village":
			im = new_img(32, 28)
			_draw_decor(im, "fountain_big", Color("d8d0c0"), Color("5aa8f0"))
		"fairy_ring":
			im = new_img(16, 16)
			for i in 8:
				var a := TAU * i / 8.0
				_shroom(im, 8 + cos(a) * 5.5, 9 + sin(a) * 4.5, 1.6, Color("f06aa0"), Color.WHITE, {"spots": false})
		"bones":
			im = new_img(32, 16)
			ellipse(im, 16, 10, 12, 4, Color("e8e0c8"))
			for x in range(6, 28, 4):
				line(im, x, 6, x + 1, 13, Color("d8d0b8"))
			disc(im, 27, 8, 3, Color("e8e0c8"))
		_:
			im = new_img(16, 16)
			im.fill(Color.MAGENTA)
	if kind != "fountain_village":
		outline(im, 0.55)
	var t := to_tex(im)
	_cache[ck] = t
	return t


func _building(im: Image, wall: Color, roof: Color, chimney: bool) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var roof_h := int(h * 0.45)
	rect(im, 4, roof_h - 2, w - 8, h - roof_h + 2, wall)
	rect(im, 4, h - 3, w - 8, 3, wall.darkened(0.2))
	for y in range(roof_h, h - 3, 4):
		rect(im, 4, y, w - 8, 1, wall.darkened(0.07))
	for y in roof_h:
		var inset := int((roof_h - y) * 0.55)
		rect(im, inset, y, w - inset * 2, 1, roof if (y / 3) % 2 == 0 else roof.darkened(0.12))
	rect(im, 0, roof_h - 1, w, 2, roof.darkened(0.3))
	if chimney:
		rect(im, w - 18, 2, 6, 10, Color("8a5a4a"))
		rect(im, w - 19, 1, 8, 2, Color("6a4a3a"))
	var dw := 10
	var dx := w / 2 - dw / 2
	rect(im, dx, h - 16, dw, 16, Color("7a4a2a"))
	rect(im, dx + 1, h - 15, dw - 2, 14, Color("9a6438"))
	px(im, dx + dw - 3, h - 8, Color("f2d23a"))
	for wx in [8, w - 18]:
		rect(im, wx, h - 20, 10, 8, Color("5a7aa0"))
		rect(im, wx + 1, h - 19, 8, 6, Color("9ac8f0"))
		rect(im, wx + 4, h - 19, 1, 6, Color("5a7aa0"))
		rect(im, wx - 1, h - 12, 12, 2, Color("7a4a2a"))
		for i in 4:
			px(im, wx + 1 + i * 3, h - 13, [Color("f06a8a"), Color("f2d23a"), Color("ffffff"), Color("a07ae0")][i])


# ================================================================= CHARACTERS
## 16x24 character frames. dir: 0=down 1=up 2=left 3=right ; frame 0..3
func person_frames(palette: Dictionary) -> Array:
	var ck := "person:" + str(palette)
	if _cache.has(ck):
		return _cache[ck]
	var frames := []
	for d in 4:
		var row := []
		for f in 4:
			var im := new_img(16, 24)
			_draw_person(im, d, f, palette)
			outline(im, 0.65)
			row.append(to_tex(im))
		frames.append(row)
	_cache[ck] = frames
	return frames


func _draw_person(im: Image, dir: int, f: int, p: Dictionary) -> void:
	var skin: Color = p.get("skin", Color("f2c8a0"))
	var hair: Color = p.get("hair", Color("6a3a2a"))
	var shirt: Color = p.get("shirt", Color("5aa04a"))
	var pants: Color = p.get("pants", Color("3a5a9a"))
	var hat: Color = p.get("hat", Color("e8c860"))
	var has_hat: bool = p.get("has_hat", true)
	var bob := 1 if f % 2 == 1 else 0
	var y0 := 2 + bob
	# legs
	var la := 0
	var lb := 0
	if f == 1:
		la = -1
		lb = 1
	elif f == 3:
		la = 1
		lb = -1
	if dir <= 1:
		rect(im, 5, 16 + y0 - 2, 2, 5 + la, pants)
		rect(im, 9, 16 + y0 - 2, 2, 5 + lb, pants)
		rect(im, 5, 20 + y0 - 2 + la, 2, 1, Color("4a3020"))
		rect(im, 9, 20 + y0 - 2 + lb, 2, 1, Color("4a3020"))
	else:
		var step: int = [0, 2, 0, -2][f]
		rect(im, 6 + step * 0.5, 16 + y0 - 2, 2, 5, pants)
		rect(im, 8 - step * 0.5, 16 + y0 - 2, 2, 5, pants.darkened(0.15))
		rect(im, 6 + step * 0.5 + (1 if dir == 3 else -1), 20 + y0 - 2, 2, 1, Color("4a3020"))
		rect(im, 8 - step * 0.5 + (1 if dir == 3 else -1), 20 + y0 - 2, 2, 1, Color("4a3020"))
	# body
	rect(im, 4, 10 + y0 - 1, 8, 7, shirt)
	rect(im, 4, 15 + y0, 8, 1, shirt.darkened(0.2))
	if p.get("overalls", false):
		rect(im, 5, 12 + y0, 6, 5, pants)
		px(im, 5, 11 + y0, pants)
		px(im, 10, 11 + y0, pants)
	# arms
	var swing: int = [0, 1, 0, -1][f]
	if dir <= 1:
		rect(im, 2, 10 + y0 + swing, 2, 5, shirt.darkened(0.08))
		rect(im, 12, 10 + y0 - swing, 2, 5, shirt.darkened(0.08))
		px(im, 2, 15 + y0 + swing, skin)
		px(im, 13, 15 + y0 - swing, skin)
	else:
		var ax := 7 + swing
		rect(im, ax, 10 + y0, 2, 5, shirt.darkened(0.12))
		px(im, ax, 15 + y0, skin)
	# head
	rect(im, 4, 3 + y0, 8, 7, skin)
	match dir:
		0:
			rect(im, 4, 3 + y0, 8, 2, hair)
			px(im, 4, 5 + y0, hair)
			px(im, 11, 5 + y0, hair)
			px(im, 6, 6 + y0, Color("2a1a1a"))
			px(im, 9, 6 + y0, Color("2a1a1a"))
			px(im, 5, 8 + y0, Color("f0a0a0"))
			px(im, 10, 8 + y0, Color("f0a0a0"))
		1:
			rect(im, 4, 3 + y0, 8, 6, hair)
		2:
			rect(im, 6, 3 + y0, 6, 3, hair)
			rect(im, 9, 3 + y0, 3, 6, hair)
			px(im, 5, 6 + y0, Color("2a1a1a"))
			px(im, 3, 7 + y0, skin)
		3:
			rect(im, 4, 3 + y0, 6, 3, hair)
			rect(im, 4, 3 + y0, 3, 6, hair)
			px(im, 10, 6 + y0, Color("2a1a1a"))
			px(im, 12, 7 + y0, skin)
	if has_hat:
		rect(im, 2, 3 + y0, 12, 2, hat)
		rect(im, 4, 0 + y0, 8, 3, hat.lightened(0.08))
		rect(im, 4, 2 + y0, 8, 1, p.get("band", Color("c04a3a")))
		px(im, 2, 4 + y0, hat.darkened(0.2))
		px(im, 13, 4 + y0, hat.darkened(0.2))


func critter_frames(kind: String, variant: int) -> Array:
	var ck := "c:%s:%d" % [kind, variant]
	if _cache.has(ck):
		return _cache[ck]
	var out := []
	for f in 2:
		var im := new_img(8, 8)
		match kind:
			"butterfly":
				var c := Color.from_hsv(fmod(variant * 0.17, 1.0), 0.55, 1.0)
				if f == 0:
					ellipse(im, 2, 3, 2, 2, c)
					ellipse(im, 6, 3, 2, 2, c)
					ellipse(im, 2.5, 5.5, 1.3, 1.3, c.darkened(0.15))
					ellipse(im, 5.5, 5.5, 1.3, 1.3, c.darkened(0.15))
				else:
					ellipse(im, 3, 3.5, 1, 2, c)
					ellipse(im, 5, 3.5, 1, 2, c)
				rect(im, 4, 2, 1, 5, Color("3a2a2a"))
			"bee":
				ellipse(im, 4, 5, 2.5, 1.8, Color("f2c23a"))
				px(im, 4, 5, Color("2a2a2a"))
				px(im, 3, 5, Color("2a2a2a"))
				ellipse(im, 4, 2.5 if f == 0 else 3.5, 1.5, 1, Color("e8f4ff", 0.85))
			"bird":
				var bc: Color = [Color("8a5a3a"), Color("4a7ae0"), Color("e04a3a")][variant % 3]
				ellipse(im, 4, 5, 2.5, 2, bc)
				disc(im, 6, 3.5, 1.3, bc)
				px(im, 7, 3, Color("f2c23a"))
				px(im, 6, 3, Color("1a1a1a"))
				if f == 1:
					line(im, 2, 3, 4, 1, bc.darkened(0.2))
			"firefly":
				disc(im, 4, 4, 2.5 if f == 0 else 1.8, Color("fff08a", 0.35))
				disc(im, 4, 4, 1, Color("fff8c0"))
			"leaf":
				ellipse(im, 4, 4, 2.2, 1.2, Color.from_hsv(0.05 + variant * 0.03, 0.7, 0.9))
		if kind != "firefly":
			outline(im, 0.6)
		out.append(to_tex(im))
	_cache[ck] = out
	return out


func forage_tex(kind: String, season: int) -> Texture2D:
	var ck := "f:%s:%d" % [kind, season]
	if _cache.has(ck):
		return _cache[ck]
	var im := new_img(16, 16)
	var rng := _rng(ck)
	match kind:
		"bush":
			ellipse(im, 8, 10, 6.5, 5, Color("4f9f3a").darkened(0.1))
			disc(im, 6, 8, 3, Color("5fae4a"))
			disc(im, 10, 8, 3, Color("6fbf4a"))
			for i in 4:
				px(im, rng.randi_range(3, 12), rng.randi_range(6, 12), Color("e03a5a"))
		"flowers":
			for i in 4:
				var x := 3 + i * 3
				line(im, x, 15, x, 9 + (i % 2) * 2, Color("4f9f3a"))
				disc(im, x, 8 + (i % 2) * 2, 1.4, [Color("f06a8a"), Color("f2e25a"), Color("a07ae0"), Color("ffffff")][i])
		"mushroom":
			_shroom(im, 5, 15, 2.5, Color("e04a3a"), Color.WHITE, {"spots": true})
			_shroom(im, 11, 15, 3, Color("c8a070"), Color.WHITE, {})
		"rocks":
			ellipse(im, 6, 11, 4.5, 3.5, Color("8a8a90"))
			ellipse(im, 11, 12, 3.5, 2.8, Color("9a9aa0"))
			px(im, 5, 9, Color("f2d23a"))
			px(im, 11, 11, Color("c0c0c8"))
		"crystal":
			_shard(im, 6, 15, 9, 4, Color("a080e0"))
			_shard(im, 11, 15, 7, 3, Color("80c0f0"))
		"rubble":
			ellipse(im, 8, 12, 6, 3, Color("a09a88"))
			rect(im, 3, 8, 4, 4, Color("b0aa98"))
			rect(im, 9, 9, 5, 3, Color("8a8474"))
			px(im, 6, 7, Color("5f9a3f"))
			px(im, 12, 8, Color("5f9a3f"))
		"dig":
			ellipse(im, 8, 11, 5, 2.5, Color("6a4a32"))
			line(im, 5, 9, 11, 13, Color("4a3020"))
			line(im, 11, 9, 5, 13, Color("4a3020"))
		"fairy":
			disc(im, 8, 9, 3, Color("ffd0f0", 0.6))
		_:
			pass
	if kind != "fairy" and kind != "sparkle":
		outline(im, 0.55)
	sparkles(im, rng, 2 if kind != "fairy" and kind != "sparkle" else 4, Color("fffbe0"))
	var t := to_tex(im)
	_cache[ck] = t
	return t


## Small UI glyphs
func ui_icon(kind: String) -> Texture2D:
	var ck := "u:" + kind
	if _cache.has(ck):
		return _cache[ck]
	var im := new_img(16, 16)
	match kind:
		"coin":
			disc(im, 8, 8, 6, Color("f2c23a"))
			disc(im, 8, 8, 4.2, Color("e0a82a"))
			line(im, 8, 5, 8, 11, Color("fff0a0"))
			px(im, 5, 5, Color("fff8c0"))
		"drop":
			for y in range(2, 14):
				var w := 0.5 + (y - 2) * 0.55 if y < 9 else 4.5 - (y - 9) * 0.6
				rect(im, 8 - w, y, w * 2, 1, Color("4a9ae0"))
			px(im, 6, 9, Color("c8e8ff"))
		"star":
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2
				line(im, 8, 8, 8 + cos(a) * 6, 8 + sin(a) * 6, Color("ffd45a"), 2)
			disc(im, 8, 8, 3, Color("ffd45a"))
		"book":
			rect(im, 2, 3, 12, 10, Color("6a4a8a"))
			rect(im, 3, 4, 10, 8, Color("8a6aaa"))
			rect(im, 7, 3, 2, 10, Color("4a2a6a"))
			px(im, 5, 6, Color("ffd45a"))
		"sun":
			disc(im, 8, 8, 4, Color("ffd45a"))
			for i in 8:
				var a2 := TAU * i / 8.0
				px(im, 8 + cos(a2) * 6.5, 8 + sin(a2) * 6.5, Color("ffb03a"))
		"rain":
			ellipse(im, 8, 6, 6, 3.5, Color("a8b8c8"))
			for x in [4, 8, 12]:
				line(im, x, 10, x - 1, 13, Color("4a9ae0"))
		"cloud":
			ellipse(im, 6, 9, 4, 3, Color("d0d8e0"))
			ellipse(im, 10, 8, 4.5, 3.5, Color("e0e8f0"))
		"snow":
			for i in 3:
				var a3 := PI * i / 3.0
				line(im, 8 - cos(a3) * 5, 8 - sin(a3) * 5, 8 + cos(a3) * 5, 8 + sin(a3) * 5, Color("c8e8ff"))
		"wind":
			for y in [5, 8, 11]:
				line(im, 2, y, 12 - (y % 3), y, Color("c8d8e0"))
				px(im, 13 - (y % 3), y - 1, Color("c8d8e0"))
		"lock":
			rect(im, 3, 7, 10, 8, Color("d8b030"))
			for i in 7:
				var a4 := PI + PI * i / 6.0
				px(im, 8 + cos(a4) * 3.5, 7 + sin(a4) * 4, Color("8a8a8a"))
			px(im, 8, 10, Color("2a2a2a"))
			px(im, 8, 11, Color("2a2a2a"))
		"cursor":
			im = new_img(16, 16)
			for i in 4:
				px(im, i, 0, Color.WHITE)
				px(im, 0, i, Color.WHITE)
				px(im, 15 - i, 0, Color.WHITE)
				px(im, 15, i, Color.WHITE)
				px(im, i, 15, Color.WHITE)
				px(im, 0, 15 - i, Color.WHITE)
				px(im, 15 - i, 15, Color.WHITE)
				px(im, 15, 15 - i, Color.WHITE)
	if kind != "cursor":
		outline(im, 0.6)
	var t := to_tex(im)
	_cache[ck] = t
	return t


func light_texture() -> Texture2D:
	if _cache.has("light"):
		return _cache["light"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_cache["light"] = gt
	return gt


func particle_tex(kind: String) -> Texture2D:
	var ck := "pt:" + kind
	if _cache.has(ck):
		return _cache[ck]
	var im: Image
	match kind:
		"rain":
			im = new_img(1, 5)
			im.fill(Color(0.75, 0.85, 1.0, 0.75))
		"snow":
			im = new_img(2, 2)
			im.fill(Color(1, 1, 1, 0.95))
		"leaf":
			im = new_img(3, 2)
			im.fill(Color("e8973a"))
			im.set_pixel(0, 1, Color("c0602a"))
		"petal":
			im = new_img(2, 2)
			im.fill(Color("f8b8d0"))
		_:
			im = new_img(2, 2)
			im.fill(Color.WHITE)
	var t := to_tex(im)
	_cache[ck] = t
	return t
