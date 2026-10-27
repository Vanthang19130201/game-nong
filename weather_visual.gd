extends Control

var rain_overlay: ColorRect
var rain_particles: CPUParticles2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rain_overlay = ColorRect.new()
	rain_overlay.color = Color(0.32, 0.43, 0.47, 0.07)
	rain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rain_overlay)
	rain_particles = CPUParticles2D.new()
	rain_particles.name = "RainParticles"
	rain_particles.texture = preload("res://assets/environment/rain_drop.svg")
	rain_particles.amount = 72
	rain_particles.lifetime = 0.85
	rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_particles.emission_rect_extents = Vector2(600, 0)
	rain_particles.position = Vector2(576, -4)
	rain_particles.direction = Vector2(0.12, 1.0)
	rain_particles.spread = 7.0
	rain_particles.gravity = Vector2(70, 650)
	rain_particles.initial_velocity_min = 430.0
	rain_particles.initial_velocity_max = 560.0
	rain_particles.scale_amount_min = 0.55
	rain_particles.scale_amount_max = 0.85
	rain_particles.color = Color(1, 1, 1, 0.58)
	add_child(rain_particles)
	WeatherManager.changed.connect(_on_weather_changed)
	get_viewport().size_changed.connect(_resize)
	_on_weather_changed(WeatherManager.current_weather)
	_resize()

func _on_weather_changed(weather_id: String) -> void:
	var raining := weather_id == "rain"
	rain_overlay.visible = raining
	rain_particles.emitting = raining

func _resize() -> void:
	var view := get_viewport_rect().size
	rain_particles.position = Vector2(view.x * 0.5, -4)
	rain_particles.emission_rect_extents = Vector2(view.x * 0.5, 0)
