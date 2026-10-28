extends Control

var weather_overlay: ColorRect
var rain_particles: CPUParticles2D
var cloud_phase: float = 0.0
var cloud_visible: bool = false
var rain_visible: bool = false
var _view_size: Vector2 = Vector2.ZERO

const CLOUDS := [
	{"x": 0.08, "y": 0.13, "w": 250.0, "h": 94.0, "speed": 11.0},
	{"x": 0.52, "y": 0.31, "w": 330.0, "h": 118.0, "speed": 17.0},
	{"x": 0.91, "y": 0.53, "w": 230.0, "h": 88.0, "speed": 13.0}
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -2
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather_overlay = ColorRect.new()
	weather_overlay.name = "WeatherOverlay"
	weather_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_overlay.z_index = -1
	weather_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(weather_overlay)
	rain_particles = CPUParticles2D.new()
	rain_particles.name = "RainParticles"
	rain_particles.texture = preload("res://assets/environment/rain_drop.svg")
	rain_particles.z_index = 1
	rain_particles.amount = 300
	rain_particles.lifetime = 1.0
	rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_particles.emission_rect_extents = Vector2(600, 0)
	rain_particles.position = Vector2(576, -28)
	rain_particles.direction = Vector2(0.19, 1.0)
	rain_particles.spread = 4.0
	rain_particles.gravity = Vector2(42, 100)
	rain_particles.initial_velocity_min = 520.0
	rain_particles.initial_velocity_max = 760.0
	rain_particles.angle_min = -8.0
	rain_particles.angle_max = 8.0
	rain_particles.scale_amount_min = 0.78
	rain_particles.scale_amount_max = 1.28
	rain_particles.color = Color(0.73, 0.88, 0.94, 0.72)
	add_child(rain_particles)
	WeatherManager.changed.connect(_on_weather_changed)
	get_viewport().size_changed.connect(_resize)
	_on_weather_changed(WeatherManager.current_weather)
	_resize()


func _process(delta: float) -> void:
	if not cloud_visible:
		return
	cloud_phase = fposmod(cloud_phase + delta, 100000.0)
	queue_redraw()


func _draw() -> void:
	if not cloud_visible:
		return
	var storm := rain_visible
	var body_color := Color(0.38, 0.46, 0.51, 0.25 if storm else 0.21)
	var shadow_color := Color(0.31, 0.39, 0.44, 0.19 if storm else 0.12)
	var light_color := Color(0.88, 0.90, 0.87, 0.11 if storm else 0.16)
	for index in range(CLOUDS.size()):
		var cloud: Dictionary = CLOUDS[index]
		var width: float = float(cloud["w"])
		var x: float = fposmod(float(cloud["x"]) * _view_size.x + cloud_phase * float(cloud["speed"]), _view_size.x + width * 2.0) - width
		var y: float = float(cloud["y"]) * _view_size.y + sin(cloud_phase * 0.12 + index) * 5.0
		_draw_cloud(Vector2(x, y), Vector2(width, float(cloud["h"])), body_color, shadow_color, light_color)
	if rain_visible:
		_draw_rain_impacts()


func _draw_cloud(center: Vector2, size: Vector2, body: Color, shadow: Color, light: Color) -> void:
	var w := size.x
	var h := size.y
	# A broad underside and overlapping soft lobes read as moving cloud cover
	# while leaving most of the farm unobscured.
	draw_rect(Rect2(center + Vector2(-w * 0.43, -h * 0.05), Vector2(w * 0.86, h * 0.34)), shadow)
	draw_circle(center + Vector2(-w * 0.25, h * 0.05), h * 0.29, shadow)
	draw_circle(center + Vector2(w * 0.02, -h * 0.11), h * 0.39, shadow)
	draw_circle(center + Vector2(w * 0.27, h * 0.01), h * 0.31, shadow)
	draw_rect(Rect2(center + Vector2(-w * 0.40, -h * 0.15), Vector2(w * 0.80, h * 0.33)), body)
	draw_circle(center + Vector2(-w * 0.24, -h * 0.10), h * 0.27, body)
	draw_circle(center + Vector2(0, -h * 0.22), h * 0.37, body)
	draw_circle(center + Vector2(w * 0.24, -h * 0.10), h * 0.28, body)
	draw_circle(center + Vector2(-w * 0.22, -h * 0.19), h * 0.16, light)
	draw_circle(center + Vector2(w * 0.02, -h * 0.31), h * 0.20, light)
	draw_circle(center + Vector2(w * 0.24, -h * 0.20), h * 0.15, light)


func _draw_rain_impacts() -> void:
	# Screen-space impacts make rain legible even when the camera is over grass
	# rather than water.  They are faint and sparse so the player stays readable.
	for index in range(18):
		var phase := fposmod(cloud_phase * 1.7 + float(index) * 0.173, 1.0)
		var point := Vector2(
			_view_size.x * (0.05 + fposmod(float(index) * 0.271, 0.9)),
			_view_size.y * (0.20 + fposmod(float(index) * 0.417 + phase * 0.3, 0.72))
		)
		var radius := 1.5 + phase * 3.5
		draw_arc(point, radius, 0.08, PI - 0.08, 10, Color("cde6e4", 0.18 * (1.0 - phase)), 1.0, true)


func _on_weather_changed(weather_id: String) -> void:
	rain_visible = weather_id == "rain"
	cloud_visible = weather_id == "cloudy" or rain_visible
	weather_overlay.visible = weather_id != "sunny"
	weather_overlay.color = Color(0.46, 0.56, 0.64, 0.05) if weather_id == "cloudy" else Color(0.34, 0.44, 0.48, 0.095)
	rain_particles.emitting = rain_visible
	set_process(cloud_visible)
	queue_redraw()


func _resize() -> void:
	_view_size = get_viewport_rect().size
	if not is_instance_valid(rain_particles):
		return
	var area_scale := (_view_size.x * _view_size.y) / (1152.0 * 648.0)
	rain_particles.amount = clampi(roundi(300.0 * area_scale), 240, 700)
	rain_particles.lifetime = maxf(1.0, _view_size.y / 650.0)
	rain_particles.position = Vector2(_view_size.x * 0.5, -28.0)
	rain_particles.emission_rect_extents = Vector2(_view_size.x * 0.58, 0.0)
	queue_redraw()
