extends CanvasLayer
## WeatherFX — screen-space rain, snow, wind-blown leaves and spring petals.

var _particles: CPUParticles2D
var _kind := ""


func _ready() -> void:
	layer = 2
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	add_child(_particles)
	Events.weather_changed.connect(func(_w): apply())
	Events.season_changed.connect(func(_s): apply())
	get_viewport().size_changed.connect(apply)


func apply() -> void:
	var w := GameState.weather
	var kind := ""
	match w:
		"rain": kind = "rain"
		"snow": kind = "snow"
		"windy": kind = "petal" if GameState.season == 0 else "leaf"
	_kind = kind
	var vs := get_viewport().get_visible_rect().size
	var p := _particles
	p.emitting = false
	if kind == "":
		return
	p.texture = PixelArt.particle_tex(kind)
	p.position = Vector2(vs.x / 2, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vs.x * 0.75, 4)
	p.local_coords = false
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = Color.WHITE
	match kind:
		"rain":
			p.amount = 260
			p.lifetime = 0.9
			p.direction = Vector2(-0.2, 1)
			p.spread = 3
			p.gravity = Vector2(0, 0)
			p.initial_velocity_min = vs.y * 1.0
			p.initial_velocity_max = vs.y * 1.25
			p.scale_amount_min = 3.0
			p.scale_amount_max = 4.0
		"snow":
			p.amount = 160
			p.lifetime = 7.0
			p.direction = Vector2(0.2, 1)
			p.spread = 25
			p.gravity = Vector2(0, 0)
			p.initial_velocity_min = 60
			p.initial_velocity_max = 120
		_:
			p.amount = 40
			p.lifetime = 5.0
			p.position = Vector2(-30, vs.y / 2)
			p.emission_rect_extents = Vector2(4, vs.y * 0.6)
			p.direction = Vector2(1, 0.15)
			p.spread = 20
			p.gravity = Vector2(0, 20)
			p.initial_velocity_min = 260
			p.initial_velocity_max = 420
			p.angular_velocity_min = -200
			p.angular_velocity_max = 200
	p.emitting = true
