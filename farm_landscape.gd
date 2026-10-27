extends Node2D

# Static terrain accents only: no collision, resource spawning, timers or polling.
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(205, 939), Vector2(354, 913), Vector2(548, 990),
		Vector2(555, 1250), Vector2(513, 1402), Vector2(344, 1408),
		Vector2(188, 1328), Vector2(172, 1110),
	]), Color("7f805c"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(218, 966), Vector2(350, 944), Vector2(520, 1009),
		Vector2(527, 1245), Vector2(494, 1374), Vector2(348, 1380),
		Vector2(214, 1310), Vector2(201, 1114),
	]), Color("a39a72"))
	_path(PackedVector2Array([Vector2(700, 480), Vector2(700, 840), Vector2(1750, 850)]), 42.0)
	_path(PackedVector2Array([Vector2(700, 520), Vector2(838, 520), Vector2(838, 335), Vector2(920, 335)]), 30.0)
	_path(PackedVector2Array([Vector2(838, 480), Vector2(920, 480)]), 26.0)
	_path(PackedVector2Array([Vector2(700, 650), Vector2(920, 650)]), 30.0)
	_path(PackedVector2Array([Vector2(700, 730), Vector2(630, 750), Vector2(550, 750)]), 25.0)
	_path(PackedVector2Array([Vector2(700, 840), Vector2(700, 1140), Vector2(1570, 1140)]), 36.0)
	_path(PackedVector2Array([Vector2(700, 960), Vector2(640, 960)]), 24.0)
	_path(PackedVector2Array([Vector2(700, 1140), Vector2(560, 1140)]), 30.0)
	for x in [900.0, 1160.0, 1500.0]:
		_path(PackedVector2Array([Vector2(x, 1080), Vector2(x, 1140)]), 24.0)
	for x in [1250.0, 1450.0]:
		_path(PackedVector2Array([Vector2(x, 1140), Vector2(x, 1250)]), 24.0)
	_path(PackedVector2Array([Vector2(1980, 850), Vector2(2190, 850), Vector2(2190, 1040)]), 32.0)
	_path(PackedVector2Array([Vector2(2020, 850), Vector2(2020, 1040)]), 24.0)
	for point in [Vector2(2010, 1110), Vector2(2080, 1175), Vector2(2250, 1095), Vector2(2290, 790), Vector2(1965, 730), Vector2(2010, 680)]:
		_tuft(point, Color("a1b486"))
	for point in [Vector2(209, 983), Vector2(526, 1080), Vector2(226, 1353), Vector2(535, 1335), Vector2(592, 790), Vector2(1035, 289)]:
		_tuft(point, Color("9da26d"))
	for point in [Vector2(237, 1054), Vector2(380, 1025), Vector2(414, 1230), Vector2(229, 1302), Vector2(536, 1361)]:
		draw_circle(point + Vector2(0, 3), 6, Color("7f7c60"))
		draw_circle(point, 5, Color("c1b797"))

func _path(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, Color("8f8d62"), width + 8.0, true)
	draw_polyline(points, Color("b4a47b"), width, true)
	for point in points:
		draw_circle(point, width * 0.5, Color("b4a47b"))

func _tuft(point: Vector2, color: Color) -> void:
	draw_line(point, point + Vector2(-8, -13), color, 3.0, true)
	draw_line(point, point + Vector2(0, -18), color, 3.0, true)
	draw_line(point, point + Vector2(8, -11), color, 3.0, true)
