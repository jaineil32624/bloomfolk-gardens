extends Node2D
## Player — 4-direction movement with tile collision, walk animation,
## tool feedback (swing + particles) and action input.

const SPEED := 74.0
const RUN_SPEED := 120.0

var world = null
var facing := Vector2i(0, 1)
var dir_index := 0                ## 0 down, 1 up, 2 left, 3 right
var input_enabled := true
var action_label := ""
var sprite: Sprite2D
var tool_sprite: Sprite2D
var camera: Camera2D
var frames: Array = []
var _anim := 0.0
var _tool_t := 0.0
var _step_t := 0.0


func _ready() -> void:
	frames = PixelArt.person_frames({"overalls": true, "shirt": Color("f0e8d8"), "pants": Color("4a7ac0")})
	sprite = Sprite2D.new()
	sprite.offset = Vector2(0, -12)
	add_child(sprite)
	tool_sprite = Sprite2D.new()
	tool_sprite.visible = false
	tool_sprite.z_index = 1
	add_child(tool_sprite)
	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 120 * 16
	camera.limit_bottom = 90 * 16
	camera.offset = Vector2(0, -8)
	add_child(camera)
	sprite.texture = frames[0][0]


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 5.5, Color(0, 0, 0, 0.22))


func feet_tile() -> Vector2i:
	return world.tile_of(position - Vector2(0, 3))


func target_tile() -> Vector2i:
	return feet_tile() + facing


func _hitbox(p: Vector2) -> Rect2:
	return Rect2(p + Vector2(-5, -5), Vector2(10, 5))


func _blocked(p: Vector2) -> bool:
	var r := _hitbox(p)
	return world.box_blocked(r) or world.npc_blocks(r)


func set_facing(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	if abs(d.x) >= abs(d.y):
		facing = Vector2i(signi(d.x), 0)
	else:
		facing = Vector2i(0, signi(d.y))
	match facing:
		Vector2i(0, 1): dir_index = 0
		Vector2i(0, -1): dir_index = 1
		Vector2i(-1, 0): dir_index = 2
		Vector2i(1, 0): dir_index = 3


func _physics_process(delta: float) -> void:
	var moving := false
	if input_enabled:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v.length() > 0.1:
			moving = true
			if abs(v.x) > abs(v.y) + 0.05:
				set_facing(Vector2i(signi(int(sign(v.x))), 0))
			elif abs(v.y) > 0.05:
				set_facing(Vector2i(0, int(sign(v.y))))
			var running := Input.is_action_pressed("run")
			var spd := RUN_SPEED if running else SPEED
			var step := v.normalized() * spd * delta
			var np := position + Vector2(step.x, 0)
			if not _blocked(np):
				position = np
			np = position + Vector2(0, step.y)
			if not _blocked(np):
				position = np
			_anim += delta * (11.0 if running else 7.5)
			_step_t += delta
	var frame := (int(_anim) % 4) if moving else 0
	if not moving:
		_anim = 0.0
	if _tool_t > 0:
		_tool_t -= delta
		frame = 1
		var k := 1.0 - _tool_t / 0.32
		var fv := Vector2(facing)
		tool_sprite.position = fv * 8 + Vector2(0, -10 if facing.y >= 0 else -14)
		tool_sprite.rotation = lerp(-0.9, 0.6, k) * (1 if facing.x >= 0 else -1)
		tool_sprite.flip_h = facing.x < 0
		tool_sprite.z_index = -1 if facing.y < 0 else 1
		if _tool_t <= 0:
			tool_sprite.visible = false
	sprite.texture = frames[dir_index][frame]


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("act"):
		world.resolve(target_tile(), facing, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("secondary"):
		world.secondary(target_tile())
	elif event.is_action_pressed("hotbar_next"):
		GameState.cycle_hotbar(1)
	elif event.is_action_pressed("hotbar_prev"):
		GameState.cycle_hotbar(-1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if kc >= KEY_1 and kc <= KEY_9:
			var hb := GameState.hotbar_items()
			var i := kc - KEY_1
			if i < hb.size():
				GameState.hotbar_key = hb[i]
				Events.hotbar_changed.emit()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mt: Vector2i = world.tile_of(get_global_mouse_position())
			var d := mt - feet_tile()
			if abs(d.x) <= 1 and abs(d.y) <= 1:
				if d != Vector2i.ZERO:
					set_facing(d)
				world.resolve(mt, facing, true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var mt2: Vector2i = world.tile_of(get_global_mouse_position())
			var d2 := mt2 - feet_tile()
			if abs(d2.x) <= 1 and abs(d2.y) <= 1:
				world.secondary(mt2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameState.cycle_hotbar(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameState.cycle_hotbar(1)


## Visual + particle feedback for a tool use.
func play_tool(kind: String) -> void:
	var tex: Texture2D
	var col := Color("8a5a3a")
	match kind:
		"water":
			tex = PixelArt.icon("tool_watering_can_%d" % GameState.tool_level("watering_can"))
			col = Color("6ab0f0")
		"shovel":
			tex = PixelArt.icon("tool_shovel_%d" % GameState.tool_level("shovel"))
		"sickle":
			tex = PixelArt.icon("tool_sickle_%d" % GameState.tool_level("sickle"))
			col = Color("a8e070")
		_:
			tex = PixelArt.icon(GameState.hotbar_key) if GameState.hotbar_key != "" else PixelArt.icon("compost")
			col = Color("c8e8a0")
	tool_sprite.texture = tex
	tool_sprite.visible = true
	_tool_t = 0.32
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70
	p.initial_velocity_min = 18
	p.initial_velocity_max = 38
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = col
	var t: Vector2i = target_tile()
	p.position = Vector2(t.x * 16 + 8, t.y * 16 + 10)
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
