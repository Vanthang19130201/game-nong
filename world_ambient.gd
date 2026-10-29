extends Node2D

# One batched world-space illustration layer.  It deliberately owns only
# presentation: no collision, input, save data, or gameplay state lives here.
# Keeping the small ambient motions in one draw node makes the farm feel alive
# without turning every grass tuft and flower into a Node.

var grass_tufts: Array[Vector2] = [
	Vector2(205, 390), Vector2(310, 690), Vector2(445, 508),
	Vector2(532, 960), Vector2(618, 1210), Vector2(748, 915),
	Vector2(812, 785), Vector2(960, 705), Vector2(1022, 830),
	Vector2(1075, 1040), Vector2(1288, 874), Vector2(1375, 1160),
	Vector2(1520, 745), Vector2(1620, 1012), Vector2(1720, 1285),
	Vector2(430, 1530), Vector2(585, 1750), Vector2(962, 1515),
	Vector2(1170, 1700), Vector2(1410, 1560), Vector2(1630, 1810),
	Vector2(320, 2150), Vector2(600, 2390), Vector2(1030, 2250),
	Vector2(1320, 2450), Vector2(1560, 2240), Vector2(370, 2850),
	Vector2(690, 3120), Vector2(1120, 2970), Vector2(1480, 3150)
]

var flower_patches: Array[Dictionary] = [
	{"point": Vector2(255, 470), "color": Color("f1dfb1")},
	{"point": Vector2(455, 760), "color": Color("dca7b7")},
	{"point": Vector2(610, 560), "color": Color("ecc66f")},
	{"point": Vector2(855, 1020), "color": Color("f1dfb1")},
	{"point": Vector2(1010, 1215), "color": Color("dca7b7")},
	{"point": Vector2(1350, 820), "color": Color("ecc66f")},
	{"point": Vector2(1580, 1310), "color": Color("f1dfb1")},
	{"point": Vector2(360, 1690), "color": Color("dca7b7")},
	{"point": Vector2(945, 1770), "color": Color("ecc66f")},
	{"point": Vector2(1500, 1940), "color": Color("f1dfb1")},
	{"point": Vector2(295, 2560), "color": Color("ecc66f")},
	{"point": Vector2(1160, 2740), "color": Color("dca7b7")},
	{"point": Vector2(1515, 3020), "color": Color("f1dfb1")}
]

var water_lanes: Array[Rect2] = [
	Rect2(1782, 18, 176, 760),
	Rect2(1782, 922, 176, 2420),
	Rect2(1980, 1180, 250, 520)
]

var lily_pads: Array[Vector2] = [
	Vector2(1838, 220), Vector2(1888, 505), Vector2(1818, 1110),
	Vector2(1904, 1375), Vector2(1842, 1830), Vector2(1885, 2280),
	Vector2(1840, 2810), Vector2(2045, 1430), Vector2(2165, 1510)
]

var lamp_points: Array[Vector2] = [
	Vector2(620, 872), Vector2(815, 1215), Vector2(980, 748),
	Vector2(1715, 820), Vector2(1550, 1900), Vector2(2370, 455)
]

var window_points: Array[Vector2] = [
	Vector2(655, 390), Vector2(745, 390), Vector2(1165, 910),
	Vector2(1453, 910), Vector2(897, 870), Vector2(2240, 320)
]

var elapsed: float = 0.0
var weather_id: String = "sunny"


func _ready() -> void:
	z_index = -7
	if not WeatherManager.changed.is_connected(_on_weather_changed):
		WeatherManager.changed.connect(_on_weather_changed)
	weather_id = WeatherManager.current_weather
	GameClock.changed.connect(_on_clock_changed)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 100000.0)
	queue_redraw()


func _on_weather_changed(next_weather: String) -> void:
	weather_id = next_weather
	queue_redraw()


func _on_clock_changed() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_water_motion()
	_draw_ground_life()
	if weather_id != "rain":
		_draw_butterflies()
		_draw_birds()
		_draw_falling_leaves()
	if _is_night():
		_draw_night_glow()


func _draw_ground_life() -> void:
	var wind: float = _wind_strength()
	for index in range(grass_tufts.size()):
		var root := grass_tufts[index]
		var sway := sin(elapsed * (1.35 + wind * 0.25) + float(index) * 0.73) * wind
		var blade_color := Color("8ea85d", 0.76)
		draw_line(root, root + Vector2(-5.0 + sway, -12.0), blade_color, 1.5, true)
		draw_line(root + Vector2(2, 1), root + Vector2(2.5 + sway * 0.7, -15.0), Color("b1bd70", 0.78), 1.6, true)
		draw_line(root + Vector2(4, 1), root + Vector2(8.0 + sway * 0.8, -9.0), Color("72934f", 0.82), 1.35, true)

	for index in range(flower_patches.size()):
		var entry := flower_patches[index]
		var center: Vector2 = entry["point"]
		var sway_x := sin(elapsed * 1.4 + float(index) * 1.21) * wind * 0.7
		var color: Color = entry["color"]
		for offset in [Vector2(-5, 2), Vector2(0, -2), Vector2(6, 3)]:
			var bloom: Vector2 = center + offset
			draw_line(bloom + Vector2(0, 8), bloom + Vector2(sway_x, 0), Color("688348", 0.9), 1.35, true)
			draw_circle(bloom + Vector2(sway_x, 0), 2.8, color)
			draw_circle(bloom + Vector2(sway_x, 0.7), 1.05, Color("d7a94e"))


func _draw_water_motion() -> void:
	var rain: bool = weather_id == "rain"
	for lane_index in range(water_lanes.size()):
		var lane := water_lanes[lane_index]
		for index in range(8):
			var phase := fposmod(elapsed * 0.055 + float(index) * 0.173 + float(lane_index) * 0.29, 1.0)
			var point := Vector2(
				lane.position.x + lane.size.x * (0.12 + fposmod(float(index) * 0.237, 0.74)),
				lane.position.y + lane.size.y * phase
			)
			var wave_width := 7.0 + sin(elapsed * 1.7 + index) * 2.0
			draw_line(point - Vector2(wave_width, 0), point + Vector2(wave_width, 0), Color("bde1dc", 0.28), 1.2, true)
			if rain:
				var rain_phase := fposmod(elapsed * 1.28 + float(index) * 0.217 + float(lane_index) * 0.37, 1.0)
				var ripple := Vector2(
					lane.position.x + lane.size.x * (0.16 + fposmod(float(index) * 0.381, 0.68)),
					lane.position.y + lane.size.y * rain_phase
				)
				var radius := 2.0 + rain_phase * 5.0
				draw_arc(ripple, radius, 0.0, TAU, 14, Color("d5edf0", 0.32 * (1.0 - rain_phase)), 1.0, true)

	# A few slow, translucent silhouettes make the river and pond feel inhabited.
	# They are painted in this shared draw pass, rather than spawning fish nodes.
	for index in range(3):
		var lane: Rect2 = water_lanes[1 if index < 2 else 2]
		var cruise := fposmod(elapsed * (0.05 + index * 0.012) + float(index) * 0.29, 1.0)
		var fish_point := Vector2(
			lane.position.x + lane.size.x * (0.5 + 0.25 * sin(cruise * TAU + index)),
			lane.position.y + lane.size.y * cruise
		)
		_draw_ellipse(fish_point, Vector2(6.0, 2.2), Color("1b4d50", 0.16))
		draw_circle(fish_point + Vector2(-5.0, 0.0), 1.65, Color("1b4d50", 0.13))

	for index in range(lily_pads.size()):
		var pad := lily_pads[index] + Vector2(sin(elapsed * 0.75 + index) * 1.4, cos(elapsed * 0.6 + index) * 0.7)
		draw_circle(pad + Vector2(1, 2), 6.2, Color("264e43", 0.24))
		draw_circle(pad, 5.7, Color("5f974e", 0.82))
		draw_line(pad, pad + Vector2(4.5, -1.5), Color("d3e88e", 0.72), 1.0, true)


func _draw_butterflies() -> void:
	var anchors := [Vector2(435, 710), Vector2(990, 1480), Vector2(1510, 1180)]
	for index in range(anchors.size()):
		var point: Vector2 = anchors[index] + Vector2(
			sin(elapsed * 0.95 + index * 1.8) * 18.0,
			cos(elapsed * 1.27 + index * 2.1) * 8.0
		)
		var wing := 1.8 + absf(sin(elapsed * 8.0 + index)) * 1.4
		_draw_ellipse(point + Vector2(-wing, 0), Vector2(wing, 1.8), Color("f4e7a9", 0.88))
		_draw_ellipse(point + Vector2(wing, 0), Vector2(wing, 1.8), Color("e5b4c0", 0.82))
		draw_circle(point, 0.9, Color("66503b"))


func _draw_falling_leaves() -> void:
	for index in range(9):
		var fall := fposmod(elapsed * (0.055 + float(index % 3) * 0.008) + float(index) * 0.113, 1.0)
		var point := Vector2(
			110.0 + fposmod(float(index) * 191.0 + elapsed * 8.0, 1580.0),
			120.0 + fall * 210.0 + sin(elapsed * 1.6 + index) * 16.0
		)
		var color := Color("d6b65c", 0.62) if index % 2 == 0 else Color("a5c165", 0.62)
		var leaf := PackedVector2Array([
			point + Vector2(0, -3), point + Vector2(3, -1), point + Vector2(1, 3),
			point + Vector2(-2, 3), point + Vector2(-3, -1)
		])
		draw_colored_polygon(leaf, color)


func _draw_birds() -> void:
	# Two small distant silhouettes keep the sky/forest edge from feeling still.
	for index in range(2):
		var x := fposmod(elapsed * (12.0 + index * 3.0) + index * 760.0, 1700.0) - 40.0
		var y := 86.0 + index * 46.0 + sin(elapsed * 0.8 + index) * 11.0
		var wing := 4.0 + sin(elapsed * 7.0 + index) * 1.2
		var color := Color("3b4935", 0.55)
		draw_arc(Vector2(x - wing, y), wing, PI * 1.08, TAU * 0.92, 8, color, 1.05, true)
		draw_arc(Vector2(x + wing, y), wing, PI * 1.08, TAU * 0.92, 8, color, 1.05, true)


func _draw_night_glow() -> void:
	var hour := _hour()
	var intensity := 0.42 if hour < 6.0 or hour >= 20.0 else 0.24
	for point in lamp_points:
		_draw_glow(point + Vector2(0, -25), 42.0, Color("f4c96d", intensity))
	for point in window_points:
		_draw_glow(point, 22.0, Color("ffd985", intensity * 0.9))
	# Fireflies are deliberately sparse and only appear in the dark.
	for index in range(8):
		var point := Vector2(
			280.0 + fposmod(float(index) * 239.0 + elapsed * 5.0, 1420.0),
			1450.0 + sin(elapsed * 1.2 + index) * 42.0 + float(index % 3) * 78.0
		)
		var pulse := 0.18 + 0.24 * (0.5 + 0.5 * sin(elapsed * 3.0 + index * 2.3))
		draw_circle(point, 2.0, Color("f8e98e", pulse + intensity * 0.22))


func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for step in range(4, 0, -1):
		var ratio := float(step) / 4.0
		var glow := color
		glow.a *= 0.18 + (1.0 - ratio) * 0.23
		draw_circle(center, radius * ratio, glow)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _wind_strength() -> float:
	var base := 1.0
	if weather_id == "cloudy":
		base = 1.32
	elif weather_id == "rain":
		base = 1.58
	return base * (0.55 + 0.25 * sin(elapsed * 0.42))


func _hour() -> float:
	return fposmod(float(GameClock.minutes) / 60.0, 24.0)


func _is_night() -> bool:
	var hour := _hour()
	return hour < 6.0 or hour >= 18.0
