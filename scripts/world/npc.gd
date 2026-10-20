extends Node2D
## Villager NPC — wanders the plaza and chats about requests, seasons and festivals.

var world = null
var npc_name := ""
var palette := {}
var bounds := Rect2()
var frames: Array = []
var sprite: Sprite2D
var _target := Vector2.ZERO
var _wait := 0.0
var _dir := 0
var _anim := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	frames = PixelArt.person_frames(palette)
	sprite = Sprite2D.new()
	sprite.offset = Vector2(0, -12)
	add_child(sprite)
	sprite.texture = frames[0][0]
	_pick()


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 5.5, Color(0, 0, 0, 0.22))


func _pick() -> void:
	_target = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))


func _process(delta: float) -> void:
	if _wait > 0:
		_wait -= delta
		sprite.texture = frames[_dir][0]
		return
	var d := _target - position
	if d.length() < 2.0:
		_wait = _rng.randf_range(1.5, 4.5)
		_pick()
		return
	var np := position + d.normalized() * 26.0 * delta
	var r := Rect2(np + Vector2(-5, -5), Vector2(10, 5))
	var blocked: bool = world.box_blocked(r)
	if world.player and Rect2(world.player.position + Vector2(-6, -6), Vector2(12, 7)).intersects(r):
		blocked = true
	if blocked:
		_wait = 0.8
		_pick()
		return
	position = np
	if abs(d.x) > abs(d.y):
		_dir = 3 if d.x > 0 else 2
	else:
		_dir = 0 if d.y > 0 else 1
	_anim += delta * 6.0
	sprite.texture = frames[_dir][int(_anim) % 4]


func talk() -> void:
	var lines := []
	for r in GameState.requests:
		if r["npc"] == npc_name and not r["done"]:
			lines.append("Could you bring me %d %s? It's on the Request Board!" % [r["qty"], ItemDB.items[r["item"]]["name"]])
	if GameState.is_festival():
		lines.append("The %s is today! Visit the stall for rare seeds!" % ItemDB.FESTIVAL_NAMES[GameState.season])
	else:
		lines.append("The next festival is on %s %d. Don't miss it!" % [ItemDB.SEASON_NAMES[GameState.season], ItemDB.FESTIVAL_DAY])
	match GameState.season:
		0: lines.append("Spring rain is the best for tulips and turnips!")
		1: lines.append("Summer sun makes melons extra sweet.")
		2: lines.append("Pumpkins are the pride of every fall harvest.")
		3: lines.append("Winter's quiet... but Kale and Snowdrops don't mind the cold.")
	lines.append("Have you heard? Flowers sometimes grow GOLDEN. Some say even rainbow!")
	lines.append("Magic Mulch makes mutations three times more likely, or so I hear.")
	lines.append("Your collection book has %d of %d entries filled. Impressive!" % [GameState.collected_count(), ItemDB.total_collectibles()])
	if GameState.unlocked.size() < GameState.REGIONS.size():
		lines.append("Unexplored lands hide seeds you can't buy anywhere.")
	var line: String = lines[_rng.randi_range(0, lines.size() - 1)]
	if lines.size() > 0 and not GameState.requests.is_empty() and lines[0].begins_with("Could you"):
		line = lines[0]
	Events.toast.emit('%s: "%s"' % [npc_name, line], Color("ffe8c0"))
	var pd: Vector2 = world.player.position - position
	if abs(pd.x) > abs(pd.y):
		_dir = 3 if pd.x > 0 else 2
	else:
		_dir = 0 if pd.y > 0 else 1
	_wait = 3.0
