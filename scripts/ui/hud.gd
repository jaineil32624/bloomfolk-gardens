extends CanvasLayer
## HUD — clock/date/weather, coins, garden level, hotbar, water meter,
## action prompt, toasts, discovery pop-ups and region banners.

const UI := preload("res://scripts/ui/ui_theme.gd")

var root: Control
var date_l: Label
var time_l: Label
var weather_icon: TextureRect
var coins_l: Label
var level_l: Label
var xp_bar: ProgressBar
var book_l: Label
var hotbar_box: HBoxContainer
var hotbar_name: Label
var prompt_l: Label
var water_bar: ProgressBar
var toast_box: VBoxContainer
var popup_holder: Control
var banner: Label
var _popup_queue: Array = []
var _popup_busy := false
var player = null


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)
	_build_info()
	_build_buttons()
	_build_hotbar()
	_build_toasts()
	Events.coins_changed.connect(func(_c): refresh())
	Events.xp_changed.connect(func(_a, _b, _c): refresh())
	Events.time_tick.connect(func(_m): refresh())
	Events.day_started.connect(refresh)
	Events.weather_changed.connect(func(_w): refresh())
	Events.inventory_changed.connect(refresh_hotbar)
	Events.hotbar_changed.connect(refresh_hotbar)
	Events.water_changed.connect(func(_a, _b): refresh())
	Events.tool_upgraded.connect(func(_a, _b): refresh())
	Events.toast.connect(toast)
	Events.milestone_reached.connect(func(t): toast(t, UI.GOLD, 6.0))
	Events.item_discovered.connect(_on_discovered)
	Events.discovery_popup.connect(func(k, title): _queue_popup(k, title))
	Events.seed_seen.connect(func(id): toast("New seed found: " + ItemDB.items[id]["seed_name"], Color("c8f0a0")))
	Events.region_entered.connect(_on_region)
	Events.level_up.connect(func(lv): _queue_popup("", "Garden Level %d!" % lv))


# ---------------------------------------------------------------- BUILD
func _build_info() -> void:
	var c := UI.dark_card(10)
	c.position = Vector2(14, 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	c.add_child(v)
	var row1 := HBoxContainer.new()
	weather_icon = UI.icon_rect(PixelArt.ui_icon("sun"), 28)
	row1.add_child(weather_icon)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", -2)
	date_l = UI.outlined("Spring 1", 18, Color("fff4d8"))
	time_l = UI.outlined("6:00 AM", 22, Color("ffffff"))
	v2.add_child(date_l)
	v2.add_child(time_l)
	row1.add_child(v2)
	v.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_child(UI.icon_rect(PixelArt.ui_icon("coin"), 24))
	coins_l = UI.outlined("0", 20, UI.GOLD)
	row2.add_child(coins_l)
	v.add_child(row2)
	level_l = UI.outlined("Garden Lv 1", 15, Color("c8f0a0"))
	v.add_child(level_l)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(180, 10)
	xp_bar.show_percentage = false
	v.add_child(xp_bar)
	var row3 := HBoxContainer.new()
	row3.add_child(UI.icon_rect(PixelArt.ui_icon("drop"), 20))
	water_bar = ProgressBar.new()
	water_bar.custom_minimum_size = Vector2(152, 12)
	water_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	water_bar.show_percentage = false
	var fill := UI.box(Color("5aa8f0"), Color("3a78c0"), 2, 0, 3)
	water_bar.add_theme_stylebox_override("fill", fill)
	row3.add_child(water_bar)
	v.add_child(row3)
	var row4 := HBoxContainer.new()
	row4.add_child(UI.icon_rect(PixelArt.ui_icon("book"), 20))
	book_l = UI.outlined("0 / 0", 15, Color("e0d0ff"))
	row4.add_child(book_l)
	v.add_child(row4)


func _build_buttons() -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	h.position = Vector2(-560, 12)
	h.custom_minimum_size = Vector2(546, 0)
	h.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(h)
	for b in [["Collection [Tab]", "book"], ["Bag [I]", "inventory"], ["Requests [J]", "requests"], ["Map [M]", "map"], ["Menu", "pause"]]:
		var btn := UI.button(b[0], func(): Events.open_panel.emit(b[1], null))
		btn.add_theme_font_size_override("font_size", 15)
		h.add_child(btn)


func _build_hotbar() -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.position.y -= 14
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	prompt_l = UI.outlined("", 20, Color("fffbe8"))
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(prompt_l)
	hotbar_name = UI.outlined("", 16, Color("e8f8d0"))
	hotbar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(hotbar_name)
	var c := UI.dark_card(6)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(c)
	hotbar_box = HBoxContainer.new()
	hotbar_box.add_theme_constant_override("separation", 4)
	c.add_child(hotbar_box)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_box.position = Vector2(-470, 64)
	toast_box.custom_minimum_size = Vector2(456, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 6)
	root.add_child(toast_box)
	popup_holder = Control.new()
	popup_holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_holder.position.y = 90
	root.add_child(popup_holder)
	banner = UI.outlined("", 40, Color("fff4d0"))
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.position.y = -200
	banner.add_theme_constant_override("outline_size", 9)
	banner.modulate.a = 0.0
	root.add_child(banner)


# ---------------------------------------------------------------- REFRESH
func refresh() -> void:
	date_l.text = GameState.date_text() + ("   FESTIVAL!" if GameState.is_festival() else "")
	time_l.text = GameState.clock_text()
	var wi := {"sunny": "sun", "rain": "rain", "cloudy": "cloud", "snow": "snow", "windy": "wind"}
	weather_icon.texture = PixelArt.ui_icon(wi.get(GameState.weather, "sun"))
	weather_icon.tooltip_text = GameState.weather.capitalize()
	coins_l.text = "%d" % GameState.coins
	level_l.text = "Garden Level %d" % GameState.level
	xp_bar.max_value = GameState.xp_needed()
	xp_bar.value = GameState.xp
	water_bar.max_value = GameState.capacity()
	water_bar.value = GameState.water
	book_l.text = "Collection %d / %d" % [GameState.collected_count(), ItemDB.total_collectibles()]


func refresh_hotbar() -> void:
	UI.clear(hotbar_box)
	var hb := GameState.hotbar_items()
	if hb.is_empty():
		hotbar_name.text = "No seeds - buy some at the Village Shop!"
		var l := UI.outlined("  empty  ", 16)
		hotbar_box.add_child(l)
		return
	if not (GameState.hotbar_key in hb):
		GameState.hotbar_key = hb[0]
	var sel := hb.find(GameState.hotbar_key)
	var start := clampi(sel - 4, 0, max(0, hb.size() - 9))
	for i in range(start, min(start + 9, hb.size())):
		var key: String = hb[i]
		var s := UI.slot(key, GameState.count(key), 52)
		if key == GameState.hotbar_key:
			s.add_theme_stylebox_override("panel", UI.box(Color("fff4c0"), UI.GOLD, 3, 3))
			s.custom_minimum_size = Vector2(58, 58)
		var num := UI.outlined(str(i - start + 1), 11, Color("e0e0e0"))
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		num.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		s.add_child(num)
		s.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				GameState.hotbar_key = key
				Events.hotbar_changed.emit())
		hotbar_box.add_child(s)
	var it := ItemDB.item(GameState.hotbar_key)
	var extra := ""
	if ItemDB.is_seed(GameState.hotbar_key):
		extra = "  (%s)" % ItemDB.season_text(GameState.hotbar_key.substr(5))
	hotbar_name.text = "Q/E or wheel:  " + ItemDB.display_name(GameState.hotbar_key) + extra
	if it.is_empty():
		hotbar_name.text = ""


func _process(_delta: float) -> void:
	if player and player.input_enabled and player.action_label != "":
		prompt_l.text = "[Space] " + player.action_label
	else:
		prompt_l.text = ""


# ---------------------------------------------------------------- TOASTS & POPUPS
func toast(text: String, color: Color = Color.WHITE, dur: float = 3.5) -> void:
	var c := UI.dark_card(8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.outlined(text, 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 430
	c.add_child(l)
	toast_box.add_child(c)
	while toast_box.get_child_count() > 6:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_interval(dur)
	tw.tween_property(c, "modulate:a", 0.0, 0.5)
	tw.tween_callback(c.queue_free)


func _on_discovered(id: String) -> void:
	var it: Dictionary = ItemDB.items[id]
	if it.get("plant", false) or it.get("mutation", "") != "":
		return  # plants/mutations already get a big popup from the harvest
	_queue_popup(id, "New Collection Entry!")


func _queue_popup(key: String, title: String) -> void:
	_popup_queue.append([key, title])
	if not _popup_busy:
		_next_popup()


func _next_popup() -> void:
	if _popup_queue.is_empty():
		_popup_busy = false
		return
	_popup_busy = true
	var e: Array = _popup_queue.pop_front()
	var key: String = e[0]
	var title: String = e[1]
	var c := UI.card(UI.PARCHMENT, UI.GOLD, 14, 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	c.add_child(h)
	if key != "":
		h.add_child(UI.icon_rect(PixelArt.icon(key), 72))
	else:
		h.add_child(UI.icon_rect(PixelArt.ui_icon("star"), 64))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UI.label(title, 16, UI.INK_SOFT))
	if key != "":
		var r := ItemDB.rarity_of(key)
		v.add_child(UI.label(ItemDB.display_name(key), 26, UI.INK))
		var rl := UI.outlined("%s  -  added to your Collection Book" % ItemDB.RARITY_NAMES[r] if not ItemDB.is_seed(key) else ItemDB.RARITY_NAMES[r] + " seed", 15, ItemDB.RARITY_COLORS[r])
		v.add_child(rl)
	else:
		v.add_child(UI.label("New regions and upgrades may be available!", 16, UI.INK))
	popup_holder.add_child(c)
	await get_tree().process_frame
	c.position = Vector2(-c.size.x / 2, 0)
	c.pivot_offset = c.size / 2
	c.scale = Vector2(0.4, 0.4)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.set_parallel(false)
	tw.tween_interval(2.4)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next_popup)
	tw.tween_callback(c.queue_free)


func _on_region(r: String) -> void:
	banner.text = ItemDB.REGION_NAMES.get(r, r)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)
