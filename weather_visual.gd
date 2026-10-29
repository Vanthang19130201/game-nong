extends Control

## Presentation only: GameClock, WeatherManager, and WorldLighting remain authoritative.
const RAIN_TEXTURE := preload("res://assets/environment/rain_drop.svg")

const TIME_COLOR_KEYS: Array[Dictionary] = [
	{"minute": 0.0, "color": Color("1e315d")},
	{"minute": 270.0, "color": Color("344c76")},
	{"minute": 345.0, "color": Color("d99d8d")},
	{"minute": 450.0, "color": Color("f3dcbb")},
	{"minute": 720.0, "color": Color("fff9e8")},
	{"minute": 930.0, "color": Color("ffe7c4")},
	{"minute": 1050.0, "color": Color("eeb184")},
	{"minute": 1110.0, "color": Color("d1879b")},
	{"minute": 1170.0, "color": Color("796d9c")},
	{"minute": 1260.0, "color": Color("354778")},
	{"minute": 1440.0, "color": Color("1e315d")}
]

const FAR_CLOUDS: Array[Dictionary] = [
	{"x": 0.03, "y": 0.13, "w": 180.0, "h": 64.0, "speed": 5.0},
	{"x": 0.32, "y": 0.24, "w": 220.0, "h": 74.0, "speed": 6.5},
	{"x": 0.63, "y": 0.15, "w": 165.0, "h": 56.0, "speed": 4.3},
	{"x": 0.89, "y": 0.30, "w": 235.0, "h": 78.0, "speed": 7.0},
	{"x": 0.18, "y": 0.43, "w": 190.0, "h": 63.0, "speed": 5.4},
	{"x": 0.72, "y": 0.45, "w": 210.0, "h": 70.0, "speed": 6.0}
]

const NEAR_CLOUDS: Array[Dictionary] = [
	{"x": 0.16, "y": 0.18, "w": 300.0, "h": 104.0, "speed": 11.0},
	{"x": 0.54, "y": 0.32, "w": 355.0, "h": 122.0, "speed": 14.0},
	{"x": 0.92, "y": 0.20, "w": 275.0, "h": 92.0, "speed": 12.0},
	{"x": 0.37, "y": 0.52, "w": 325.0, "h": 108.0, "speed": 16.0},
	{"x": 0.76, "y": 0.48, "w": 265.0, "h": 90.0, "speed": 13.0}
]

var weather_overlay: ColorRect
var rain_particles: CPUParticles2D
var near_rain_particles: CPUParticles2D
var cloud_phase := 0.0
var celestial_phase := 0.0
var cloud_visible := false
var rain_visible := false
var cloud_coverage := 0.18
var target_cloud_coverage := 0.18
var rain_strength := 0.0
var target_rain_strength := 0.0
var current_weather := "sunny"
var time_minutes := 360.0
var _view_size := Vector2.ZERO


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
	rain_particles = _make_rain_particles("FarRainParticles", 0.72, 500.0, 720.0, Color(0.67, 0.81, 0.89, 0.46))
	near_rain_particles = _make_rain_particles("NearRainParticles", 1.18, 650.0, 900.0, Color(0.77, 0.89, 0.94, 0.62))
	near_rain_particles.z_index = 2
	add_child(rain_particles)
	add_child(near_rain_particles)
	WeatherManager.changed.connect(_on_weather_changed)
	GameClock.changed.connect(_on_clock_changed)
	get_viewport().size_changed.connect(_resize)
	time_minutes = GameClock.minutes
	_on_weather_changed(WeatherManager.current_weather)
	_resize()


func _make_rain_particles(node_name: String, visual_scale: float, velocity_minimum: float, velocity_maximum: float, tint: Color) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.texture = RAIN_TEXTURE
	particles.amount = 180
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(600, 0)
	particles.direction = Vector2(0.16, 1.0)
	particles.spread = 3.0
	particles.gravity = Vector2(38, 96)
	particles.initial_velocity_min = velocity_minimum
	particles.initial_velocity_max = velocity_maximum
	particles.angle_min = -10.0
	particles.angle_max = 5.0
	particles.scale_amount_min = visual_scale * 0.75
	particles.scale_amount_max = visual_scale * 1.2
	particles.color = tint
	particles.emitting = false
	return particles


func _process(delta: float) -> void:
	cloud_phase = fposmod(cloud_phase + delta, 100000.0)
	celestial_phase = fposmod(celestial_phase + delta, 100000.0)
	cloud_coverage = move_toward(cloud_coverage, target_cloud_coverage, delta * 0.32)
	rain_strength = move_toward(rain_strength, target_rain_strength, delta * 0.8)
	weather_overlay.color = _weather_overlay_color()
	weather_overlay.visible = current_weather != "sunny" or rain_strength > 0.01
	rain_particles.modulate.a = rain_strength * 0.78
	near_rain_particles.modulate.a = rain_strength
	queue_redraw()


func _draw() -> void:
	if _view_size.is_zero_approx():
		return
	_draw_stars()
	_draw_cloud_layers()
	if rain_strength > 0.01:
		_draw_rain_impacts()


func _draw_stars() -> void:
	var visibility := _night_visibility() * (1.0 - cloud_coverage * 0.82)
	if visibility <= 0.02:
		return
	for index in range(28):
		var x := _view_size.x * (0.30 + fposmod(float(index) * 0.173, 0.42))
		var y := _view_size.y * (0.055 + fposmod(float(index) * 0.117, 0.24))
		var twinkle := 0.45 + sin(celestial_phase * (1.2 + float(index % 3) * 0.21) + index * 2.17) * 0.25
		draw_circle(Vector2(x, y), 0.75 + float(index % 3) * 0.28, Color(0.91, 0.95, 1.0, visibility * twinkle * 0.72))


func _draw_cloud_layers() -> void:
	var tint := _cloud_tint()
	var far_count := _visible_cloud_count(FAR_CLOUDS.size(), 0.28)
	var near_count := _visible_cloud_count(NEAR_CLOUDS.size(), 0.22)
	for index in range(far_count):
		_draw_cloud_entry(FAR_CLOUDS[index], index, tint, 0.53)
	for index in range(near_count):
		_draw_cloud_entry(NEAR_CLOUDS[index], index + 17, tint, 0.82)


func _visible_cloud_count(total: int, floor_coverage: float) -> int:
	var normalized := clampf((cloud_coverage - floor_coverage) / (1.0 - floor_coverage), 0.0, 1.0)
	return clampi(1 + roundi(normalized * float(total - 1)), 1, total)


func _draw_cloud_entry(cloud: Dictionary, index: int, tint: Color, alpha_scale: float) -> void:
	var width := float(cloud["w"])
	var height := float(cloud["h"])
	var speed := float(cloud["speed"]) * (1.0 + cloud_coverage * 0.24)
	var x := fposmod(float(cloud["x"]) * _view_size.x + cloud_phase * speed, _view_size.x + width * 2.0) - width
	var y := float(cloud["y"]) * _view_size.y + sin(cloud_phase * 0.12 + float(index)) * (3.0 + cloud_coverage * 3.0)
	_draw_cloud(Vector2(x, y), Vector2(width, height), tint, alpha_scale * lerpf(0.16, 0.54, cloud_coverage))


func _draw_cloud(center: Vector2, size: Vector2, tint: Color, opacity: float) -> void:
	var w := size.x
	var h := size.y
	var underside := Color(tint.r * 0.70, tint.g * 0.76, tint.b * 0.84, opacity * 0.84)
	var body := Color(tint.r, tint.g, tint.b, opacity)
	var highlight := Color(1.0, 0.98, 0.94, opacity * 0.34)
	draw_rect(Rect2(center + Vector2(-w * 0.43, -h * 0.05), Vector2(w * 0.86, h * 0.34)), underside)
	draw_circle(center + Vector2(-w * 0.25, h * 0.05), h * 0.29, underside)
	draw_circle(center + Vector2(w * 0.02, -h * 0.11), h * 0.39, underside)
	draw_circle(center + Vector2(w * 0.27, h * 0.01), h * 0.31, underside)
	draw_rect(Rect2(center + Vector2(-w * 0.40, -h * 0.15), Vector2(w * 0.80, h * 0.33)), body)
	draw_circle(center + Vector2(-w * 0.24, -h * 0.10), h * 0.27, body)
	draw_circle(center + Vector2(0, -h * 0.22), h * 0.37, body)
	draw_circle(center + Vector2(w * 0.24, -h * 0.10), h * 0.28, body)
	draw_circle(center + Vector2(-w * 0.22, -h * 0.19), h * 0.16, highlight)
	draw_circle(center + Vector2(w * 0.02, -h * 0.31), h * 0.20, highlight)


func _draw_rain_impacts() -> void:
	for index in range(24):
		var phase := fposmod(cloud_phase * 1.7 + float(index) * 0.173, 1.0)
		var point := Vector2(_view_size.x * (0.05 + fposmod(float(index) * 0.271, 0.9)), _view_size.y * (0.20 + fposmod(float(index) * 0.417 + phase * 0.3, 0.72)))
		draw_arc(point, 1.5 + phase * 3.8, 0.08, PI - 0.08, 10, Color(0.78, 0.90, 0.91, rain_strength * 0.18 * (1.0 - phase)), 1.0, true)


func _on_weather_changed(weather_id: String) -> void:
	current_weather = weather_id
	rain_visible = weather_id == "rain"
	cloud_visible = weather_id != "sunny"
	target_cloud_coverage = 0.18 if weather_id == "sunny" else 0.66 if weather_id == "cloudy" else 1.0
	target_rain_strength = 1.0 if rain_visible else 0.0
	rain_particles.emitting = rain_visible
	near_rain_particles.emitting = rain_visible
	queue_redraw()


func _on_clock_changed() -> void:
	time_minutes = GameClock.minutes
	queue_redraw()


func _resize() -> void:
	_view_size = get_viewport_rect().size
	if not is_instance_valid(rain_particles):
		return
	var area_scale := (_view_size.x * _view_size.y) / (1152.0 * 648.0)
	rain_particles.amount = clampi(roundi(220.0 * area_scale), 180, 580)
	near_rain_particles.amount = clampi(roundi(95.0 * area_scale), 75, 260)
	for particles in [rain_particles, near_rain_particles]:
		particles.lifetime = maxf(1.0, _view_size.y / 650.0)
		particles.position = Vector2(_view_size.x * 0.5, -28.0)
		particles.emission_rect_extents = Vector2(_view_size.x * 0.58, 0.0)
	queue_redraw()


func _weather_overlay_color() -> Color:
	var base := _sample_time_color()
	var tint := Color(base.r * 0.76, base.g * 0.86, base.b * 0.96, 0.0)
	if current_weather == "cloudy":
		tint.a = 0.04
	elif current_weather == "rain":
		tint.a = 0.085
	return tint


func _sample_time_color() -> Color:
	var minute := fposmod(time_minutes, 1440.0)
	for index in range(TIME_COLOR_KEYS.size() - 1):
		var left: Dictionary = TIME_COLOR_KEYS[index]
		var right: Dictionary = TIME_COLOR_KEYS[index + 1]
		if minute <= float(right["minute"]):
			var span := maxf(1.0, float(right["minute"]) - float(left["minute"]))
			var amount := clampf((minute - float(left["minute"])) / span, 0.0, 1.0)
			amount = amount * amount * (3.0 - 2.0 * amount)
			return (left["color"] as Color).lerp(right["color"] as Color, amount)
	return TIME_COLOR_KEYS.back()["color"]


func _cloud_tint() -> Color:
	var tint := Color(0.98, 0.97, 0.91).lerp(_sample_time_color(), 0.30)
	# A very small seasonal shift keeps the presentation connected to the
	# existing calendar without inventing a second season or weather system.
	tint = tint.lerp(_seasonal_sky_tint(), 0.14)
	if current_weather == "cloudy":
		tint = tint.lerp(Color(0.62, 0.69, 0.75), 0.48)
	elif current_weather == "rain":
		tint = tint.lerp(Color(0.39, 0.49, 0.59), 0.72)
	return tint


func _seasonal_sky_tint() -> Color:
	match GameClock.season:
		"summer":
			return Color(1.0, 0.95, 0.82)
		"autumn":
			return Color(1.0, 0.86, 0.72)
		"winter":
			return Color(0.79, 0.88, 1.0)
		_:
			return Color(0.90, 1.0, 0.88) # spring


func _night_visibility() -> float:
	var evening := _ramp(1110.0, 1200.0, time_minutes)
	var morning := 1.0 - _ramp(240.0, 345.0, time_minutes)
	return maxf(evening, morning)


func _ramp(start: float, finish: float, value: float) -> float:
	var amount := clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)
