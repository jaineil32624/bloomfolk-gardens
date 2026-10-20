extends SceneTree
## Dev tool: renders a sprite sheet of generated art to user:// for review.
## Run: godot --headless --path . --script res://tools/art_preview.gd

func _initialize() -> void:
	await process_frame
	var ItemDB = root.get_node("ItemDB")
	var PA = root.get_node("PixelArt")
	print("Collectibles: ", ItemDB.total_collectibles(), "  plants: ", ItemDB.plant_ids.size())
	var ids: Array = ItemDB.plant_ids
	var cols := 5 * 17 + 18
	var rows := ids.size()
	# plant stages sheet (subset)
	var sheet := Image.create(18 * 6 * 4, 26 * 50, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("7cb35a"))
	var i := 0
	for id in ids:
		var col := i / 50
		var row := i % 50
		for s in 5:
			var t: Texture2D = PA.plant_tex(id, s)
			sheet.blend_rect(t.get_image(), Rect2i(0, 0, 16, 24), Vector2i(col * 18 * 6 + s * 17 + 1, row * 26 + 1))
		var ic: Texture2D = PA.icon(id)
		sheet.blend_rect(ic.get_image(), Rect2i(0, 0, 16, 16), Vector2i(col * 18 * 6 + 5 * 17 + 1, row * 26 + 5))
		i += 1
	sheet.save_png(OS.get_environment("OUT") + "/plants.png")
	# icons sheet for every item + seeds
	var all: Array = ItemDB.order.duplicate()
	for id in ItemDB.plant_ids:
		all.append("seed:" + id)
	var per := 24
	var ih := int(ceil(all.size() / float(per)))
	var isheet := Image.create(per * 18, ih * 18, false, Image.FORMAT_RGBA8)
	isheet.fill(Color("e8dcc0"))
	i = 0
	for k in all:
		var t2: Texture2D = PA.icon(k)
		isheet.blend_rect(t2.get_image(), Rect2i(0, 0, 16, 16), Vector2i((i % per) * 18 + 1, (i / per) * 18 + 1))
		i += 1
	isheet.save_png(OS.get_environment("OUT") + "/icons.png")
	# tiles / objects / people
	var o := Image.create(400, 260, false, Image.FORMAT_RGBA8)
	o.fill(Color("7cb35a"))
	var x := 2
	for k in ["grass","farm","flower","fairy","jungle","path","plaza","patio","water","sand","stone","snow","cave","crystal","ruin","glass","magic","wall_hedge","wall_rock","wall_cave","wall_crystal","wall_ruin"]:
		o.blend_rect(PA.tile(k, 0, 0), Rect2i(0,0,16,16), Vector2i(x, 2))
		o.blend_rect(PA.tile(k, 0, 2), Rect2i(0,0,16,16), Vector2i(x, 20))
		o.blend_rect(PA.tile(k, 0, 3), Rect2i(0,0,16,16), Vector2i(x, 38))
		x += 17
	x = 2
	for k in ["tree","pine","rock","bigrock","bush","crystal_rock","pillar","giant_mushroom","giant_flower","stump","house","shop","cottage","well","bin","board","sign","construction","gate","station","lab","stall","fairy_ring","bones"]:
		var t3: Texture2D = PA.object_tex(k, 0, 0)
		var im3 := t3.get_image()
		if x + im3.get_width() > 398:
			break
		o.blend_rect(im3, Rect2i(0,0,im3.get_width(), im3.get_height()), Vector2i(x, 60))
		x += im3.get_width() + 2
	var fr: Array = PA.person_frames({})
	for d in 4:
		for f in 4:
			o.blend_rect(fr[d][f].get_image(), Rect2i(0,0,16,24), Vector2i(2 + (d*4+f) * 17, 160))
	x = 2
	for k in ["bush","flowers","mushroom","rocks","crystal","rubble","dig","fairy"]:
		o.blend_rect(PA.forage_tex(k, 0).get_image(), Rect2i(0,0,16,16), Vector2i(x, 190))
		x += 18
	for k in ["coin","drop","star","book","sun","rain","cloud","snow","wind","lock"]:
		o.blend_rect(PA.ui_icon(k).get_image(), Rect2i(0,0,16,16), Vector2i(x, 190))
		x += 18
	x = 2
	for k in ["tree","pine","bush","rock"]:
		for s in 4:
			var t4: Texture2D = PA.object_tex(k, s, s)
			var im4 := t4.get_image()
			o.blend_rect(im4, Rect2i(0,0,im4.get_width(), im4.get_height()), Vector2i(x, 212))
			x += im4.get_width() + 1
	o.save_png(OS.get_environment("OUT") + "/world.png")
	print("done")
	quit()
