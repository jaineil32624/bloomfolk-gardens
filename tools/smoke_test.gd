extends SceneTree
## Dev tool: automated play-through of the core loop + screenshots.
## Run: godot --path . --script res://tools/smoke_test.gd   (needs a display for screenshots)

var main
var shots := ""


func _initialize() -> void:
	shots = OS.get_environment("OUT")
	create_timer(150).timeout.connect(func(): print("WATCHDOG QUIT"); quit())
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run()


func _wait(n: int = 5) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await _wait(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png(shots + "/" + name + ".png")
		print("shot ", name)


func _run() -> void:
	var GS = root.get_node("GameState")
	var EV = root.get_node("Events")
	await _wait(10)
	await _shot("00_title")
	main.start_new_game()
	await _wait(20)
	var w = main.world
	var p = main.player
	print("player at ", p.position, " tile ", p.feet_tile(), " region ", w.region_at(p.feet_tile()))
	# Give some money/levels to exercise systems
	GS.add_coins(60000)
	GS.level = 13
	GS.add_item("seed:tulip", 20)
	GS.add_item("seed:sunflower", 10)
	GS.add_item("magic_mulch", 10)
	for e in GS.EXPANSIONS:
		GS.buy_expansion(e["id"])
	for r in ["flower_fields", "forest", "mushroom_caves"]:
		GS.unlock_region(r)
	await _wait(5)
	# Till/plant/water a row in the farm
	var fr: Rect2i = w.farm_rect()
	p.position = Vector2((fr.position.x + 1) * 16 + 8, (fr.position.y - 1) * 16 + 12)
	p.set_facing(Vector2i(0, 1))
	var plants := ["seed:turnip", "seed:tulip", "seed:radish", "seed:sunflower", "seed:tulip"]
	for i in 12:
		var t := Vector2i(fr.position.x + i, fr.position.y)
		print("till: ", w.resolve(t, Vector2i(0, 1), true))
		GS.hotbar_key = plants[i % plants.size()]
		if GS.count(GS.hotbar_key) <= 0:
			GS.hotbar_key = "seed:turnip"
		print("plant: ", w.resolve(t, Vector2i(0, 1), true))
		print("water: ", w.resolve(t, Vector2i(0, 1), true))
	# Simulate days
	for d in 7:
		for key in GS.plots:
			GS.plots[key]["watered"] = true
			if GS.plots[key]["plant"] == "" and GS.count("seed:tulip") > 0:
				GS.plots[key]["plant"] = "tulip"
		GS.season = 0
		var res = GS.new_day()
		print("day ", GS.day, " ", res)
	w.build()
	w.refresh_all_plants()
	await _wait(5)
	# Harvest everything ready
	var n := 0
	for key in GS.plots.keys():
		var t2 = w.parse_key(key)
		if GS.plot_stage(GS.plots[key]) == 4:
			w._harvest(t2, Vector2i(0, 1))
			n += 1
	print("harvest calls: ", n, " stats ", GS.stats, " collected ", GS.collected_count())
	# Plant a showcase garden for the screenshot
	var ids := ["tulip", "sunflower", "rose", "pumpkin", "corn", "tomato", "cabbage", "lavender", "blueberry", "apple", "hydrangea", "daisy", "moonpetal", "fly_agaric", "quartz_rose", "melon", "orchid", "peony", "carrot", "poppy"]
	var i2 := 0
	for y in range(fr.position.y + 1, fr.position.y + 5):
		for x in range(fr.position.x, fr.position.x + 15):
			var key2: String = w.k(x, y)
			var pid: String = ids[i2 % ids.size()]
			var stage_age: int = ItemDB_days(pid) if (x + y) % 4 != 0 else 1
			GS.plots[key2] = {"plant": pid, "age": stage_age, "watered": (x % 3) == 0, "fert": "", "zone": "farm"}
			i2 += 1
	GS.decor[w.k(fr.position.x - 2, fr.position.y + 2)] = "gnome"
	GS.decor[w.k(fr.end.x + 1, fr.position.y + 1)] = "lamp_post"
	GS.decor[w.k(fr.end.x + 1, fr.position.y + 3)] = "fountain_small"
	GS.decor[w.k(fr.position.x - 2, fr.position.y + 4)] = "beehive"
	GS.minutes = 600
	GS.weather = "sunny"
	w.build()
	p.position = Vector2((fr.position.x + 7) * 16 + 8, (fr.position.y + 6) * 16 + 4)
	p.set_facing(Vector2i(0, -1))
	p.camera.reset_smoothing()
	main.hud.refresh()
	main.hud.refresh_hotbar()
	await _wait(30)
	main.hud._popup_queue.clear()
	for c in main.hud.toast_box.get_children(): c.queue_free()
	for c in main.hud.popup_holder.get_children(): c.queue_free()
	await _wait(60)
	await _shot("01_garden")
	# Open every panel
	for panel in ["book", "inventory", "requests", "map", "lab", "pause"]:
		EV.open_panel.emit(panel, null)
		await _wait(8)
		await _shot("02_" + panel)
		main.ui.close()
	EV.open_panel.emit("shop", "seeds")
	await _wait(8)
	await _shot("03_shop")
	main.ui.close()
	# Visit other regions
	for r in ["village", "flower_fields", "forest", "mushroom_caves"]:
		var o: Vector2i = w.region_origin(r)
		p.position = Vector2((o.x + 20) * 16 + 8, (o.y + 22) * 16 + 8)
		p.camera.reset_smoothing()
		await _wait(40)
		await _shot("04_" + r)
	# Night scene
	var o2: Vector2i = w.region_origin("village")
	p.position = Vector2((o2.x + 20) * 16 + 8, (o2.y + 20) * 16 + 8)
	GS.minutes = 1300
	p.camera.reset_smoothing()
	await _wait(40)
	await _shot("05_night")
	GS.minutes = 600
	# Forage a few spots
	var fk: Array = GS.forage.keys()
	for j in min(6, fk.size()):
		w._collect_forage(fk[j])
	# Save / load round trip
	root.get_node("SaveManager").save_game()
	var coins = GS.coins
	GS.coins = 0
	root.get_node("SaveManager").load_game()
	print("save/load coins ok: ", GS.coins == coins, " plots ", GS.plots.size(), " collected ", GS.collected_count(), "/", root.get_node("ItemDB").total_collectibles())
	# Sleep flow
	main.sleep(false)
	await _wait(200)
	print("after sleep day ", GS.day, " playing ", GS.playing)
	print("SMOKE TEST DONE")
	quit()


func ItemDB_days(pid: String) -> int:
	return root.get_node("ItemDB").items[pid]["days"]
