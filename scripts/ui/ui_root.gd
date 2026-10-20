extends CanvasLayer
## UIRoot — every modal menu: Collection Book, Bag, Shop (seeds / tools /
## land / decor / sell / trade / festival), Requests, Plant Lab, Map,
## Pause, confirmation dialogs and the Title screen.
## Panels are rebuilt from GameState each time they open, so they are
## always in sync and easy to extend.

const UI := preload("res://scripts/ui/ui_theme.gd")

signal new_game_requested
signal continue_requested
signal sleep_requested
signal quit_to_title

var root: Control
var dim: ColorRect
var window: PanelContainer
var content: VBoxContainer
var fade: ColorRect
var title_screen: Control
var current := ""
var world = null
var _book_cat := "crop"
var _book_sel := ""
var _shop_tab := "seeds"
var _inv_sel := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)
	window = PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.visible = false
	root.add_child(window)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	window.add_child(content)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.02, 0.05, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Events.open_panel.connect(_on_open_panel)
	Events.inventory_changed.connect(_live_refresh)
	Events.coins_changed.connect(func(_c): _live_refresh())


func is_open() -> bool:
	return current != "" or (title_screen != null and title_screen.visible)


func _live_refresh() -> void:
	if current in ["shop", "inventory", "requests", "lab"]:
		_rebuild()


func _on_open_panel(name: String, data: Variant) -> void:
	if name.begins_with("_"):
		return
	if title_screen and title_screen.visible:
		return
	match name:
		"confirm_sleep":
			confirm("Go to sleep and end the day?\nPlants you watered will grow overnight.", func(): sleep_requested.emit())
		"confirm_expansion":
			var e := GameState.expansion_def(data)
			confirm("Build %s?\n%s\n\nCost: %d coins   (Requires Garden Lv %d)" % [e["name"], e["desc"], e["cost"], e["level"]], func(): GameState.buy_expansion(data))
		"confirm_region":
			var d: Dictionary = GameState.REGIONS[data]
			confirm("Unlock %s?\n%s\n\nCost: %d coins   (Requires Garden Lv %d)" % [ItemDB.REGION_NAMES[data], d["desc"], d["cost"], d["level"]], func(): GameState.unlock_region(data))
		"shop":
			_shop_tab = data if data != null else "seeds"
			open("shop")
		_:
			if current == name:
				close()
			else:
				open(name)


func open(name: String) -> void:
	if current == "":
		Audio.play("open")
	current = name
	dim.visible = true
	window.visible = true
	_set_game_paused(true)
	_rebuild()


func close() -> void:
	if current != "":
		Audio.play("close")
	current = ""
	dim.visible = false
	window.visible = false
	UI.clear(content)
	_set_game_paused(false)


func _set_game_paused(p: bool) -> void:
	if world and world.player:
		world.player.input_enabled = not p
	GameState.playing = not p and (title_screen == null or not title_screen.visible)


func _unhandled_input(event: InputEvent) -> void:
	if title_screen and title_screen.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if current != "":
			close()
		else:
			open("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_book"):
		_toggle("book")
	elif event.is_action_pressed("open_bag"):
		_toggle("inventory")
	elif event.is_action_pressed("open_requests"):
		_toggle("requests")
	elif event.is_action_pressed("open_map"):
		_toggle("map")


func _toggle(n: String) -> void:
	if current == n:
		close()
	elif current == "" or current != "confirm":
		open(n)
	get_viewport().set_input_as_handled()


func _rebuild() -> void:
	UI.clear(content)
	match current:
		"book": _build_book()
		"inventory": _build_inventory()
		"shop": _build_shop()
		"requests": _build_requests()
		"lab": _build_lab()
		"map": _build_map()
		"pause": _build_pause()
		"help": _build_help()
	await get_tree().process_frame
	_center()


func _center() -> void:
	window.reset_size()
	window.position = (root.size - window.size) / 2


func _header(title: String) -> void:
	var h := HBoxContainer.new()
	var t := UI.label(title, 28, UI.WOOD_D)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var coins := HBoxContainer.new()
	coins.add_child(UI.icon_rect(PixelArt.ui_icon("coin"), 24))
	coins.add_child(UI.label(str(GameState.coins), 20, Color("a06a10")))
	h.add_child(coins)
	h.add_child(UI.button("  X  ", close))
	content.add_child(h)


func _scroll(min_size: Vector2) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = min_size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _row(icon_key: String, title: String, sub: String, right: Array, tint: Color = UI.INK) -> PanelContainer:
	var c := UI.card(UI.PARCHMENT_D, Color("c8b088"), 6, 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	if icon_key != "":
		h.add_child(UI.icon_rect(PixelArt.icon(icon_key), 40))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", -2)
	v.add_child(UI.label(title, 17, tint))
	if sub != "":
		var s := UI.label(sub, 13, UI.INK_SOFT)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	h.add_child(v)
	for r in right:
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
	return c


# ================================================================= CONFIRM
func confirm(text: String, yes: Callable) -> void:
	current = "confirm"
	dim.visible = true
	window.visible = true
	_set_game_paused(true)
	UI.clear(content)
	var l := UI.label(text, 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 460
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	h.add_child(UI.button("Yes", func():
		close()
		yes.call(), 120))
	h.add_child(UI.button("No", close, 120))
	content.add_child(h)
	await get_tree().process_frame
	_center()


# ================================================================= COLLECTION BOOK
func _build_book() -> void:
	_header("Collection Book")
	var total := GameState.collected_count()
	var all := ItemDB.total_collectibles()
	var top := HBoxContainer.new()
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(560, 22)
	pb.max_value = all
	pb.value = total
	pb.show_percentage = false
	top.add_child(pb)
	top.add_child(UI.label("  %d / %d discovered (%d%%)" % [total, all, int(100.0 * total / all)], 17))
	content.add_child(top)
	var next_m := ""
	for m in GameState.MILESTONES:
		if total < int(m[0]):
			next_m = "Next milestone: %d discoveries  ->  %d coins%s" % [m[0], m[1], (" + " + ItemDB.items[m[2]]["name"]) if String(m[2]) != "" else ""]
			break
	content.add_child(UI.label(next_m if next_m != "" else "Every milestone claimed. Legendary gardener!", 14, UI.INK_SOFT))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)
	# categories
	var cats := VBoxContainer.new()
	cats.add_theme_constant_override("separation", 3)
	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(230, 470)
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	csc.add_child(cats)
	body.add_child(csc)
	for tab in ItemDB.BOOK_TABS:
		var p := GameState.cat_progress(tab[0])
		var done := p.x >= p.y
		var b := UI.button("%s  %d/%d%s" % [tab[1], p.x, p.y, "  *" if done else ""], func():
			_book_cat = tab[0]
			_book_sel = ""
			_rebuild())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.x = 214
		b.add_theme_font_size_override("font_size", 15)
		if tab[0] == _book_cat:
			b.add_theme_stylebox_override("normal", UI.box(UI.GOLD, UI.WOOD, 3, 7))
		elif done:
			b.add_theme_stylebox_override("normal", UI.box(Color("c8e8a0"), UI.GREEN_D, 3, 7))
		cats.add_child(b)
	# grid
	var gsc := ScrollContainer.new()
	gsc.custom_minimum_size = Vector2(440, 470)
	gsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(gsc)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	gsc.add_child(grid)
	var ids := ItemDB.book_ids(_book_cat)
	if _book_sel == "" and ids.size() > 0:
		_book_sel = ids[0]
	for id in ids:
		var st := int(GameState.discovered.get(id, 0))
		var s := UI.slot(id, -1, 58, st)
		if id == _book_sel:
			s.add_theme_stylebox_override("panel", UI.box(Color("fff4c0"), UI.GOLD, 3, 3))
		s.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_book_sel = id
				_rebuild())
		grid.add_child(s)
	# detail
	var det := UI.card(UI.PARCHMENT_D, Color("c8b088"), 12, 2)
	det.custom_minimum_size = Vector2(300, 470)
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	det.add_child(dv)
	if _book_sel != "":
		var it: Dictionary = ItemDB.items[_book_sel]
		var st2 := int(GameState.discovered.get(_book_sel, 0))
		var big := UI.icon_rect(PixelArt.icon(_book_sel), 112)
		if st2 == 0:
			big.modulate = Color(0, 0, 0, 0.3)
		elif st2 == 1:
			big.modulate = Color(0.3, 0.27, 0.25, 0.75)
		dv.add_child(big)
		var r: int = it["rarity"]
		dv.add_child(UI.label(it["name"] if st2 > 0 else "???", 24))
		var rl := UI.outlined(ItemDB.RARITY_NAMES[r], 16, ItemDB.RARITY_COLORS[r])
		dv.add_child(rl)
		var lore := ""
		if st2 >= 2:
			lore = it["lore"]
			if int(it.get("value", 0)) > 0:
				dv.add_child(UI.label("Value: %d coins" % it["value"], 15, Color("8a5a10")))
		elif st2 == 1:
			lore = "You found its seeds! Grow and harvest it to complete this entry."
		else:
			lore = "Not yet discovered."
			if it.get("plant", false):
				lore += "\nHint: seeds come from " + ItemDB.REGION_NAMES.get(it["region"], it["region"]) + "."
			elif it.has("region"):
				lore += "\nHint: " + str(it["region"])
		var ll := UI.label(lore, 15, UI.INK)
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size.x = 270
		dv.add_child(ll)
		if st2 >= 1 and (it.get("plant", false) or st2 >= 2):
			var gc := UI.label(ItemDB.growing_conditions(_book_sel), 14, Color("3a6a2a"))
			gc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gc.custom_minimum_size.x = 270
			dv.add_child(gc)


# ================================================================= INVENTORY
func _build_inventory() -> void:
	_header("Bag")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	var keys: Array = GameState.inventory.keys()
	keys.sort_custom(func(a, b):
		var ca: String = ("0" if ItemDB.is_seed(a) else "1") + ItemDB.item(a)["cat"] + ItemDB.display_name(a)
		var cb: String = ("0" if ItemDB.is_seed(b) else "1") + ItemDB.item(b)["cat"] + ItemDB.display_name(b)
		return ca < cb)
	if not (_inv_sel in keys):
		_inv_sel = keys[0] if keys.size() > 0 else ""
	for key in keys:
		var s := UI.slot(key, GameState.count(key), 58)
		if key == _inv_sel:
			s.add_theme_stylebox_override("panel", UI.box(Color("fff4c0"), UI.GOLD, 3, 3))
		s.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_inv_sel = key
				_rebuild())
		grid.add_child(s)
	var det := UI.card(UI.PARCHMENT_D, Color("c8b088"), 12, 2)
	det.custom_minimum_size = Vector2(300, 440)
	body.add_child(det)
	var dv := VBoxContainer.new()
	det.add_child(dv)
	if _inv_sel == "":
		dv.add_child(UI.label("Your bag is empty.", 16))
		return
	var it := ItemDB.item(_inv_sel)
	dv.add_child(UI.icon_rect(PixelArt.icon(_inv_sel), 96))
	dv.add_child(UI.label(ItemDB.display_name(_inv_sel), 22))
	var r := ItemDB.rarity_of(_inv_sel)
	dv.add_child(UI.outlined(ItemDB.RARITY_NAMES[r], 15, ItemDB.RARITY_COLORS[r]))
	dv.add_child(UI.label("Owned: %d    Sells for: %d" % [GameState.count(_inv_sel), ItemDB.sell_price(_inv_sel)], 15, Color("8a5a10")))
	var desc := ""
	if ItemDB.is_seed(_inv_sel):
		desc = "Plant on tilled soil.\n" + ItemDB.growing_conditions(_inv_sel.substr(5))
	else:
		desc = it.get("lore", "")
	var dl := UI.label(desc, 14)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 270
	dv.add_child(dl)
	if GameState.is_hotbar_item(_inv_sel):
		dv.add_child(UI.button("Hold in hands", func():
			GameState.hotbar_key = _inv_sel
			Events.hotbar_changed.emit()
			close()))
	if ItemDB.is_decor(_inv_sel):
		dv.add_child(UI.label("Hold it and press Space on grass in your Home Garden to place. X picks it back up.", 13, UI.INK_SOFT))
		dv.get_child(dv.get_child_count() - 1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# ================================================================= SHOP
func _build_shop() -> void:
	_header("Willowbrook Shop")
	var tabs := HBoxContainer.new()
	var names := [["seeds", "Seeds"], ["tools", "Tool Upgrades"], ["land", "Land & Buildings"], ["decor", "Decor"], ["sell", "Sell"], ["trade", "Trade"]]
	if GameState.is_festival():
		names.append(["festival", "Festival!"])
	for n in names:
		var b := UI.button(n[1], func():
			_shop_tab = n[0]
			_rebuild())
		if n[0] == _shop_tab:
			b.add_theme_stylebox_override("normal", UI.box(UI.GOLD, UI.WOOD, 3, 7))
		tabs.add_child(b)
	content.add_child(tabs)
	var list := _scroll(Vector2(820, 470))
	match _shop_tab:
		"seeds": _shop_seeds(list)
		"tools": _shop_tools(list)
		"land": _shop_land(list)
		"decor": _shop_decor(list)
		"sell": _shop_sell(list)
		"trade": _shop_trade(list)
		"festival": _shop_festival(list)


func _buy(key: String, price: int, qty: int) -> void:
	if GameState.spend(price * qty):
		Audio.play("coin")
		GameState.add_item(key, qty)
		Events.toast.emit("Bought %d x %s" % [qty, ItemDB.display_name(key)], Color("c8f0a0"))


func _shop_seeds(list: VBoxContainer) -> void:
	var season := GameState.season
	list.add_child(UI.label("%s seeds in stock. Rare seeds can't be bought - find them by foraging, requests and festivals!" % ItemDB.SEASON_NAMES[season], 14, UI.INK_SOFT))
	var ids := []
	for id in ItemDB.plant_ids:
		var it: Dictionary = ItemDB.items[id]
		if it["cat"] == "seasonal":
			continue
		var sold: bool = it["shop"] or (int(it["rarity"]) == 0 and it["region"] in GameState.unlocked) or (int(it["rarity"]) == 0 and it["region"] != "home" and it["region"] in GameState.unlocked)
		if it["region"] in GameState.unlocked and int(it["rarity"]) <= 1 and it["region"] != "home" and it["region"] != "village":
			sold = true
		if sold and season in it["seasons"]:
			ids.append(id)
	ids.sort_custom(func(a, b): return ItemDB.seed_price(a) < ItemDB.seed_price(b))
	for id in ids:
		var price := ItemDB.seed_price(id)
		var it2: Dictionary = ItemDB.items[id]
		var k: String = "seed:" + id
		var sub := "%s  |  %d days%s  |  sells for %d" % [ItemDB.season_text(id), it2["days"], (" (regrows)" if int(it2["regrow"]) > 0 else ""), it2["value"]]
		list.add_child(_row(k, "%s  -  %d coins" % [it2["seed_name"], price], sub, [
			UI.button("Buy 1", func(): _buy(k, price, 1)),
			UI.button("Buy 5", func(): _buy(k, price, 5))]))
	var ferts := [["compost", 1, ""], ["quality_fertilizer", 2, ""], ["speed_gro", 3, ""], ["magic_mulch", 5, ""],
		["starlight_fertilizer", 1, "fairy_garden"], ["crystal_dust", 1, "crystal_biome"], ["ancient_compost", 1, "ancient_ruins"]]
	list.add_child(UI.label("Fertilizers", 20, UI.WOOD_D))
	for f in ferts:
		var fid: String = f[0]
		var it3: Dictionary = ItemDB.items[fid]
		var ok: bool = GameState.level >= int(f[1]) and (String(f[2]) == "" or f[2] in GameState.unlocked)
		var price2: int = it3["price"]
		var why: String = "" if ok else ("Requires Garden Lv %d" % f[1] if String(f[2]) == "" else "Unlock " + ItemDB.REGION_NAMES[f[2]])
		var b1 := UI.button("Buy 1", func(): _buy(fid, price2, 1))
		var b5 := UI.button("Buy 5", func(): _buy(fid, price2, 5))
		b1.disabled = not ok
		b5.disabled = not ok
		list.add_child(_row(fid, "%s  -  %d coins" % [it3["name"], price2], it3["lore"] + ("   [" + why + "]" if why != "" else ""), [b1, b5]))


func _shop_tools(list: VBoxContainer) -> void:
	for t in ItemDB.TOOL_ORDER:
		var lv := GameState.tool_level(t)
		var def: Dictionary = ItemDB.TOOL_DEFS[t]
		var cur := "tool_%s_%d" % [t, lv]
		if lv >= 5:
			list.add_child(_row(cur, ItemDB.items[cur]["name"] + "  (MAX)", def["desc"], []))
			continue
		var cost: int = ItemDB.TOOL_COSTS[lv]
		var req: int = ItemDB.TOOL_LEVEL_REQ[lv]
		var nxt := "tool_%s_%d" % [t, lv + 1]
		var b := UI.button("Upgrade  %d" % cost, func(): GameState.upgrade_tool(t))
		b.disabled = GameState.level < req or GameState.coins < cost
		list.add_child(_row(nxt, "%s  ->  %s" % [ItemDB.items[cur]["name"], ItemDB.items[nxt]["name"]],
			"%s   Requires Garden Lv %d.   Area: %s" % [def["desc"], req, ["1 tile", "2 tiles", "3 in a row", "3x3", "4x3"][lv]], [b]))


func _shop_land(list: VBoxContainer) -> void:
	list.add_child(UI.label("New Regions", 20, UI.WOOD_D))
	for r in GameState.REGIONS:
		if r in ["home", "village"]:
			continue
		var d: Dictionary = GameState.REGIONS[r]
		var owned: bool = r in GameState.unlocked
		var b := UI.button("Owned" if owned else "Unlock  %d" % d["cost"], func(): GameState.unlock_region(r))
		b.disabled = owned or GameState.can_unlock_region(r) != ""
		list.add_child(_row("", ItemDB.REGION_NAMES[r], "%s   (Garden Lv %d)" % [d["desc"], d["level"]], [b], UI.INK if not owned else Color("3a7a2a")))
	list.add_child(UI.label("Garden Expansions", 20, UI.WOOD_D))
	for e in GameState.EXPANSIONS:
		var owned2: bool = GameState.has_exp(e["id"])
		var b2 := UI.button("Built" if owned2 else "Build  %d" % e["cost"], func(): GameState.buy_expansion(e["id"]))
		b2.disabled = owned2 or GameState.level < int(e["level"]) or GameState.coins < int(e["cost"])
		list.add_child(_row("", e["name"], "%s   (Garden Lv %d)" % [e["desc"], e["level"]], [b2], UI.INK if not owned2 else Color("3a7a2a")))


func _shop_decor(list: VBoxContainer) -> void:
	list.add_child(UI.label("Decor makes your garden beautiful and attracts more butterflies. Place it in your Home Garden.", 14, UI.INK_SOFT))
	for d in ItemDB.DECOR:
		if int(d[2]) <= 0:
			continue
		var id: String = d[0]
		var price: int = d[2]
		list.add_child(_row(id, "%s  -  %d coins" % [d[1], price], d[8] + ("  (owned: %d)" % GameState.count(id) if GameState.count(id) > 0 else ""), [UI.button("Buy", func(): _buy(id, price, 1))]))


func _shop_sell(list: VBoxContainer) -> void:
	var keys := []
	for k in GameState.inventory:
		if ItemDB.sell_price(k) > 0 and not ItemDB.is_decor(k):
			keys.append(k)
	keys.sort_custom(func(a, b): return ItemDB.sell_price(a) * GameState.count(a) > ItemDB.sell_price(b) * GameState.count(b))
	if keys.is_empty():
		list.add_child(UI.label("Nothing to sell yet. Harvest crops and forage treasures!", 16))
		return
	list.add_child(UI.label("Selling keeps your Collection Book entry - you only need one to discover it!", 14, UI.INK_SOFT))
	for k in keys:
		var price := ItemDB.sell_price(k)
		var n := GameState.count(k)
		list.add_child(_row(k, "%s  x%d" % [ItemDB.display_name(k), n], "%d coins each" % price, [
			UI.button("Sell 1", func(): _sell(k, 1)),
			UI.button("Sell all (%d)" % (price * n), func(): _sell(k, GameState.count(k)))]))


func _sell(k: String, n: int) -> void:
	n = mini(n, GameState.count(k))
	if n <= 0:
		return
	var price := ItemDB.sell_price(k)
	GameState.remove_item(k, n)
	GameState.add_coins(price * n)
	Audio.play("coin")
	Events.toast.emit("Sold %d x %s for %d coins" % [n, ItemDB.display_name(k), price * n], Color("ffd45a"))


func _shop_trade(list: VBoxContainer) -> void:
	list.add_child(UI.label("Old Moss the trader swaps 3 of any harvest or treasure (Uncommon or better) for a random seed of HIGHER rarity.", 15))
	var any := false
	for k in GameState.inventory:
		if ItemDB.is_seed(k) or ItemDB.is_decor(k) or ItemDB.is_fertilizer(k):
			continue
		var r := ItemDB.rarity_of(k)
		if r >= 1 and GameState.count(k) >= 3:
			any = true
			list.add_child(_row(k, "%s  x%d" % [ItemDB.display_name(k), GameState.count(k)], "Trade 3 for a random %s+ seed" % ItemDB.RARITY_NAMES[mini(3, r + 1)], [
				UI.button("Trade 3", func():
					if GameState.remove_item(k, 3):
						var s := GameState._random_reward_seed(r + 1)
						GameState.add_item(s, 1)
						Events.discovery_popup.emit(s, "Trade complete!"))]))
	if not any:
		list.add_child(UI.label("You need 3 of the same Uncommon (or rarer) item to trade.", 15, UI.INK_SOFT))


func _shop_festival(list: VBoxContainer) -> void:
	var s := GameState.season
	var tag := "%d-%d" % [GameState.year, s]
	list.add_child(UI.label(ItemDB.FESTIVAL_NAMES[s], 24, Color("c0406a")))
	list.add_child(UI.label("Seasonal plants can ONLY be obtained during festivals!", 15))
	if not (tag in GameState.festival_claimed):
		list.add_child(UI.button("Claim free festival gift!", func():
			GameState.festival_claimed.append(tag)
			var pid: String = ItemDB.FESTIVAL_PLANTS[s][GameState.rng.randi_range(0, 1)]
			GameState.add_item("seed:" + pid, 2)
			GameState.add_coins(150)
			Events.discovery_popup.emit("seed:" + pid, "Festival gift!")
			_rebuild()))
	for pid in ItemDB.FESTIVAL_PLANTS[s]:
		var k: String = "seed:" + pid
		var it: Dictionary = ItemDB.items[pid]
		list.add_child(_row(k, "%s  -  600 coins" % it["seed_name"], it["lore"], [UI.button("Buy", func(): _buy(k, 600, 1))]))


# ================================================================= REQUESTS
func _build_requests() -> void:
	_header("Request Board")
	content.add_child(UI.label("Villagers post new requests every morning. Deliver from anywhere!", 14, UI.INK_SOFT))
	var list := _scroll(Vector2(720, 380))
	if GameState.requests.is_empty():
		list.add_child(UI.label("No requests right now.", 16))
	for i in GameState.requests.size():
		var r: Dictionary = GameState.requests[i]
		var it: Dictionary = ItemDB.items[r["item"]]
		var have := GameState.count(r["item"])
		var reward := "%d coins" % r["coins"]
		if r["bonus"] != "":
			reward += " + " + ItemDB.display_name(r["bonus"])
		var b := UI.button("Done!" if r["done"] else "Deliver", func(): GameState.deliver_request(i))
		b.disabled = r["done"] or have < int(r["qty"])
		var sub := "Reward: %s    (you have %d)" % [reward, have]
		if int(GameState.discovered.get(r["item"], 0)) < 2:
			sub += "   Hint: " + ItemDB.season_text(r["item"]) + ", " + ItemDB.REGION_NAMES.get(it["region"], "")
		list.add_child(_row(r["item"], "%s wants %d x %s" % [r["npc"], r["qty"], it["name"]], sub, [b], Color("3a7a2a") if r["done"] else UI.INK))


# ================================================================= LAB
func _build_lab() -> void:
	_header("Plant Laboratory")
	content.add_child(UI.label("Extract seeds from a harvested plant: 1 plant -> 2 seeds.\n10% chance to discover a HYBRID seed of a plant you haven't found yet!", 15))
	var list := _scroll(Vector2(720, 400))
	var any := false
	for k in GameState.inventory:
		var it := ItemDB.item(k)
		if ItemDB.is_seed(k) or not it.get("plant", false):
			continue
		any = true
		list.add_child(_row(k, "%s  x%d" % [it["name"], GameState.count(k)], "-> 2x %s" % it["seed_name"], [UI.button("Extract", func(): _extract(k))]))
	if not any:
		list.add_child(UI.label("Harvest some plants first!", 16, UI.INK_SOFT))


func _extract(k: String) -> void:
	if not GameState.remove_item(k, 1):
		return
	GameState.add_item("seed:" + k, 2, false)
	Events.toast.emit("+2 " + ItemDB.items[k]["seed_name"], Color("c8f0a0"))
	if GameState.rng.randf() < 0.10:
		var r: int = ItemDB.items[k]["rarity"]
		var cands := []
		for id in ItemDB.plant_ids:
			var it: Dictionary = ItemDB.items[id]
			if it["cat"] != "seasonal" and int(GameState.discovered.get(id, 0)) == 0 and int(it["rarity"]) <= r + 1:
				cands.append(id)
		if cands.size() > 0:
			var pid: String = cands[GameState.rng.randi_range(0, cands.size() - 1)]
			GameState.add_item("seed:" + pid, 1)
			Events.discovery_popup.emit("seed:" + pid, "Hybrid seed discovered!")


# ================================================================= MAP
func _build_map() -> void:
	_header("World Map")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	var cells := {}
	for r in GameState.REGIONS:
		var d: Dictionary = GameState.REGIONS[r]
		cells[int(d["gy"]) * 3 + int(d["gx"])] = r
	var here := ""
	if world and world.player:
		here = world.region_at(world.tile_of(world.player.position))
	var sprites: Array = world.ground_layer.get_children() if world else []
	for i in 9:
		var r: String = cells[i]
		var cell := UI.card(UI.PARCHMENT_D, UI.GOLD if r == here else Color("8a6a4a"), 3, 3)
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(272, 204)
		cell.add_child(stack)
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		for s in sprites:
			if s is Sprite2D and Vector2i(s.position / 16.0) == world.region_origin(r):
				tr.texture = s.texture
		stack.add_child(tr)
		var unlocked: bool = r in GameState.unlocked
		if not unlocked:
			var shade := ColorRect.new()
			shade.color = Color(0.05, 0.05, 0.1, 0.6)
			shade.set_anchors_preset(Control.PRESET_FULL_RECT)
			stack.add_child(shade)
		var v := VBoxContainer.new()
		v.position = Vector2(8, 6)
		v.add_child(UI.outlined(ItemDB.REGION_NAMES[r] + ("  (You)" if r == here else ""), 17))
		if not unlocked:
			var d2: Dictionary = GameState.REGIONS[r]
			v.add_child(UI.outlined("Locked: %d coins, Lv %d" % [d2["cost"], d2["level"]], 14, Color("ffb0a0")))
		var found := 0
		var tot := 0
		for id in ItemDB.plant_ids:
			if ItemDB.items[id]["region"] == r:
				tot += 1
				if int(GameState.discovered.get(id, 0)) >= 2:
					found += 1
		if tot > 0:
			v.add_child(UI.outlined("Plants: %d / %d" % [found, tot], 14, Color("c8f0a0")))
		stack.add_child(v)
		grid.add_child(cell)


# ================================================================= PAUSE / HELP
func _build_pause() -> void:
	_header("Paused")
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 340
	v.add_theme_constant_override("separation", 10)
	content.add_child(v)
	v.add_child(UI.button("Resume", close))
	v.add_child(UI.button("Save Game", func():
		Events.open_panel.emit("_sync_player", null)
		SaveManager.save_game()))
	v.add_child(UI.button("Load Last Save", func():
		close()
		continue_requested.emit()))
	v.add_child(UI.button("How to Play", func(): open("help")))
	v.add_child(UI.button("Music: " + ("ON" if Audio.music_on else "OFF"), func():
		Audio.toggle_music()
		_rebuild()))
	v.add_child(UI.button("Sound Effects: " + ("ON" if Audio.sfx_on else "OFF"), func():
		Audio.sfx_on = not Audio.sfx_on
		_rebuild()))
	v.add_child(UI.button("Toggle Fullscreen", func():
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)))
	v.add_child(UI.button("Save & Quit to Title", func():
		Events.open_panel.emit("_sync_player", null)
		SaveManager.save_game(true)
		close()
		quit_to_title.emit()))
	var s := GameState.stats
	v.add_child(UI.label("Harvests %d  |  Forages %d  |  Mutations %d  |  Requests %d" % [s["harvests"], s["forage"], s["mutations"], s["requests"]], 13, UI.INK_SOFT))


const HELP := """[b]Goal:[/b] discover all %d collectibles and build the ultimate dream garden!

[b]Controls[/b]
WASD / Arrows - move      Shift - run
Space / Left-click - use (till, plant, water, harvest, talk, forage...)
X / Right-click - pick up decor or clear a plot
Q / E / mouse wheel / 1-9 - choose held seed, fertilizer or decor
Tab - Collection Book   I - Bag   J - Requests   M - Map   Esc - Menu

[b]The gardening loop[/b]
1. Till the darker meadow in your garden, hold seeds and plant them.
2. Water every day (refill at the well or any pond). Rain waters for you.
3. Sleep in your house to end the day; watered plants grow overnight.
4. Harvest when a star appears. Flowers can mutate GOLDEN or RAINBOW!
5. Sell, fulfil villager requests, upgrade tools and unlock new regions.
6. Forage sparkling spots in every region for rare seeds and treasures.

[b]Tips[/b]
- Plants only grow outdoors in their season. The Greenhouse ignores seasons.
- Mythical, Crystal and Ancient plants need special fertilizers.
- Festivals happen on day %d of each season, with exclusive seeds.
- Silver Shovel lets you dig up relics in the Mountains and Ancient Ruins."""


func _build_help() -> void:
	_header("How to Play")
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.custom_minimum_size = Vector2(720, 460)
	r.add_theme_color_override("default_color", UI.INK)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 17)
	r.text = HELP % [ItemDB.total_collectibles(), ItemDB.FESTIVAL_DAY]
	content.add_child(r)
	content.add_child(UI.button("Back", func(): open("pause")))


# ================================================================= TITLE
func show_title() -> void:
	close()
	GameState.playing = false
	if title_screen:
		title_screen.queue_free()
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_screen)
	var bg := ColorRect.new()
	bg.color = Color("2f4a2a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)
	# drifting collectible icons
	var drift := Control.new()
	drift.set_anchors_preset(Control.PRESET_FULL_RECT)
	drift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(drift)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 40:
		var id: String = ItemDB.plant_ids[rng.randi_range(0, ItemDB.plant_ids.size() - 1)]
		var ir := UI.icon_rect(PixelArt.icon(id), rng.randi_range(36, 72))
		ir.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 760))
		ir.modulate.a = rng.randf_range(0.25, 0.6)
		drift.add_child(ir)
		var tw := ir.create_tween().set_loops()
		tw.tween_property(ir, "position:y", ir.position.y - rng.randf_range(20, 60), rng.randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ir, "position:y", ir.position.y, rng.randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
	var c := PanelContainer.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	title_screen.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 440
	c.add_child(v)
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_child(UI.icon_rect(PixelArt.icon("sunflower"), 64))
	var tl := UI.label("Bloomfolk\nGardens", 44, UI.WOOD_D)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(tl)
	logo.add_child(UI.icon_rect(PixelArt.icon("golden_tulip"), 64))
	v.add_child(logo)
	var sub := UI.label("Grow. Discover. Collect them all.  (%d collectibles)" % ItemDB.total_collectibles(), 15, UI.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if SaveManager.has_save():
		v.add_child(UI.button("Continue", func(): continue_requested.emit()))
	v.add_child(UI.button("New Game", func():
		if SaveManager.has_save():
			_title_confirm_new(v)
		else:
			new_game_requested.emit()))
	v.add_child(UI.button("Quit", func(): get_tree().quit()))
	await get_tree().process_frame
	c.position = (root.size - c.size) / 2


func _title_confirm_new(v: VBoxContainer) -> void:
	var l := UI.label("Start over? Your current save will be replaced.", 15, Color("a03a2a"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(UI.button("Yes, start a new garden", func(): new_game_requested.emit()))


func hide_title() -> void:
	if title_screen:
		title_screen.queue_free()
		title_screen = null


## Fade to black and back, calling mid() in between.
func fade_through(mid: Callable, text: String = "") -> void:
	var lbl: Label = null
	if text != "":
		lbl = UI.outlined(text, 30, Color("fff4d0"))
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate.a = 0
		root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	if lbl:
		tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.6)
	await tw.finished
	mid.call()
	await get_tree().create_timer(0.9).timeout
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.7)
	if lbl:
		tw2.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	await tw2.finished
	if lbl:
		lbl.queue_free()
