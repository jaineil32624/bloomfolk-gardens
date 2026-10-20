extends Node
## Main — creates the world, player, HUD and menus, sets up input,
## and runs the day cycle (sleeping, passing out, autosave, day/night tint).

const World := preload("res://scripts/world/world.gd")
const Player := preload("res://scripts/world/player.gd")
const Critters := preload("res://scripts/world/critters.gd")
const WeatherFX := preload("res://scripts/world/weather_fx.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const UIRoot := preload("res://scripts/ui/ui_root.gd")

var world
var player
var critters
var weather_fx
var hud
var ui
var modulate_node: CanvasModulate
var _sleeping := false


func _ready() -> void:
	_setup_input()
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	world = World.new()
	world.name = "World"
	add_child(world)
	critters = Critters.new()
	critters.world = world
	world.add_child(critters)
	weather_fx = WeatherFX.new()
	add_child(weather_fx)
	hud = HUD.new()
	add_child(hud)
	hud.visible = false
	ui = UIRoot.new()
	ui.world = world
	add_child(ui)
	ui.new_game_requested.connect(start_new_game)
	ui.continue_requested.connect(continue_game)
	ui.sleep_requested.connect(func(): sleep(false))
	ui.quit_to_title.connect(_to_title)
	Events.open_panel.connect(func(n, _d):
		if n == "_sync_player" and player:
			GameState.player_pos = player.position)
	Events.day_started.connect(func(): weather_fx.apply())
	ui.show_title()
	if OS.get_cmdline_user_args().has("--autostart"):
		start_new_game()


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "act": [KEY_SPACE, KEY_ENTER], "secondary": [KEY_X],
		"hotbar_next": [KEY_E], "hotbar_prev": [KEY_Q], "open_book": [KEY_TAB, KEY_C],
		"open_bag": [KEY_I], "open_requests": [KEY_J], "open_map": [KEY_M], "menu": [KEY_ESCAPE],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# gamepad support
	var pad := {"act": JOY_BUTTON_A, "secondary": JOY_BUTTON_X, "hotbar_next": JOY_BUTTON_RIGHT_SHOULDER,
		"hotbar_prev": JOY_BUTTON_LEFT_SHOULDER, "open_book": JOY_BUTTON_Y, "menu": JOY_BUTTON_START, "run": JOY_BUTTON_B}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)
	for a in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[1]
		jm.axis_value = a[2]
		InputMap.action_add_event(a[0], jm)


# ================================================================= GAME FLOW
func _spawn_player() -> void:
	if player:
		player.queue_free()
	player = Player.new()
	player.world = world
	world.player = player
	hud.player = player
	world.ysort.add_child(player)


func start_new_game() -> void:
	GameState.reset_new_game()
	_begin(false)
	Events.toast.emit("Welcome to Bloomfolk Gardens! Till the dark meadow below your house and plant some seeds.", Color("fff0c0"))
	Events.toast.emit("Press Esc > How to Play for controls. Collect all %d items!" % ItemDB.total_collectibles(), Color("c8f0a0"))
	SaveManager.save_game(true)


func continue_game() -> void:
	if not SaveManager.load_game():
		start_new_game()
		return
	_begin(true)
	Events.toast.emit("Welcome back! %s" % GameState.date_text(), Color("fff0c0"))


func _begin(from_save: bool) -> void:
	ui.hide_title()
	_spawn_player()
	world.build()
	if not from_save or GameState.forage.is_empty():
		world.spawn_forage()
	player.position = GameState.player_pos if from_save and GameState.player_pos != Vector2.ZERO else world.spawn_point()
	player.camera.reset_smoothing()
	hud.visible = true
	hud.refresh()
	hud.refresh_hotbar()
	weather_fx.apply()
	GameState.playing = true
	player.input_enabled = true
	Events.water_changed.emit(GameState.water, GameState.capacity())


func _to_title() -> void:
	GameState.playing = false
	hud.visible = false
	critters.clear_all()
	ui.show_title()


func sleep(passed_out: bool) -> void:
	if _sleeping:
		return
	_sleeping = true
	GameState.playing = false
	player.input_enabled = false
	var text := "You passed out from exhaustion..." if passed_out else "Zzz..."
	await ui.fade_through(func():
		var res: Dictionary = GameState.new_day()
		critters.clear_all()
		world.build()
		world.spawn_forage()
		player.position = world.spawn_point()
		player.camera.reset_smoothing()
		GameState.water = GameState.capacity()
		GameState.player_pos = player.position
		SaveManager.save_game(true)
		hud.refresh()
		hud.refresh_hotbar()
		var msg := "Good morning! %s - %s." % [GameState.date_text(), GameState.weather.capitalize()]
		if res["ready"] > 0:
			msg += "  %d plant(s) are ready to harvest!" % res["ready"]
		Events.toast.emit(msg, Color("fff0c0"))
		if GameState.day == 1:
			Events.toast.emit("A new season begins: %s! New seeds are in the shop." % ItemDB.SEASON_NAMES[GameState.season], ItemDB.SEASON_COLORS[GameState.season])
		if GameState.is_festival():
			Events.toast.emit("Today is the %s! Visit the village stall." % ItemDB.FESTIVAL_NAMES[GameState.season], Color("ffb0d0"))
		if GameState.station_ready():
			Events.toast.emit("Your Rare Seed Station has a new seed!", Color("9fd4ff")), text)
	_sleeping = false
	GameState.playing = not ui.is_open()
	player.input_enabled = not ui.is_open()


func _process(_delta: float) -> void:
	# Day / night + weather tint
	var d := GameState.daylight()
	var night := Color(0.32, 0.36, 0.62)
	var dusk := Color(1.0, 0.82, 0.7)
	var c := Color.WHITE
	if GameState.minutes > 1020 and GameState.minutes < 1260:
		c = night.lerp(dusk, d) if d < 0.9 else dusk.lerp(Color.WHITE, (d - 0.9) * 10.0)
	else:
		c = night.lerp(Color.WHITE, d)
	match GameState.weather:
		"rain": c *= Color(0.78, 0.8, 0.88)
		"cloudy": c *= Color(0.9, 0.9, 0.94)
		"snow": c *= Color(0.92, 0.95, 1.02)
	if world and world.player and world.region_at(world.tile_of(world.player.position)) == "mushroom_caves":
		c *= Color(0.7, 0.68, 0.85)
	modulate_node.color = c
	if GameState.playing and not _sleeping and GameState.minutes >= GameState.DAY_END:
		sleep(true)
