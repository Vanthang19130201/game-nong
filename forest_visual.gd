extends Node2D

# Static forest-floor illustration. Harvestable trees are separate ResourceNodes.
func _draw() -> void:
	var floor_shape := PackedVector2Array([
		Vector2(130, 180), Vector2(150, 112), Vector2(255, 77),
		Vector2(402, 91), Vector2(530, 72), Vector2(677, 97),
		Vector2(828, 74), Vector2(1015, 86), Vector2(1165, 70),
		Vector2(1328, 95), Vector2(1480, 76), Vector2(1664, 105),
		Vector2(1735, 167), Vector2(1708, 251), Vector2(1605, 282),
		Vector2(1460, 267), Vector2(1318, 299), Vector2(1162, 275),
		Vector2(1012, 302), Vector2(846, 276), Vector2(690, 300),
		Vector2(523, 274), Vector2(364, 300), Vector2(220, 275), Vector2(132, 238)
	])
	draw_colored_polygon(floor_shape, Color("294d32"))
	draw_polyline(floor_shape, Color("607a45", 0.68), 8.0, true)

	for patch in [
		[Vector2(340, 176), Vector2(160, 48), Color("4d7040", 0.28)],
		[Vector2(750, 235), Vector2(190, 36), Color("68834a", 0.18)],
		[Vector2(1250, 165), Vector2(200, 44), Color("466b3c", 0.32)],
		[Vector2(1570, 235), Vector2(140, 32), Color("789052", 0.16)]
	]:
		_draw_ellipse(patch[0], patch[1], patch[2])

	for patch in [
		[Vector2(248, 230), Vector2(70, 13)], [Vector2(612, 253), Vector2(54, 11)],
		[Vector2(942, 230), Vector2(78, 15)], [Vector2(1380, 248), Vector2(68, 13)]
	]:
		_draw_ellipse(patch[0], patch[1], Color("172f25", 0.3))

	for entry in [
		[Vector2(195, 254), Color("f1dfb1")], [Vector2(276, 279), Color("d6a6b5")],
		[Vector2(395, 248), Color("f0c66f")], [Vector2(585, 276), Color("e8b7c2")],
		[Vector2(744, 254), Color("f1dfb1")], [Vector2(914, 283), Color("d6a6b5")],
		[Vector2(1060, 252), Color("f0c66f")], [Vector2(1235, 281), Color("f1dfb1")],
		[Vector2(1450, 254), Color("e8b7c2")], [Vector2(1634, 276), Color("f0c66f")]
	]:
		_flower_cluster(entry[0], entry[1])

	for entry in [
		[Vector2(170, 289), 0.8], [Vector2(480, 285), 0.7],
		[Vector2(816, 291), 0.72], [Vector2(1126, 291), 0.78],
		[Vector2(1535, 288), 0.72], [Vector2(1696, 248), 0.64]
	]:
		_bush(entry[0], entry[1])


func _flower_cluster(center: Vector2, petal_color: Color) -> void:
	for offset in [Vector2(-8, 0), Vector2(0, -6), Vector2(8, 1)]:
		var bloom: Vector2 = center + offset
		draw_line(bloom + Vector2(0, 9), bloom, Color("6c8b4d"), 1.6, true)
		draw_line(bloom, bloom + Vector2(-3, 4), Color("82a05a"), 1.2, true)
		draw_circle(bloom, 3.5, petal_color)
		draw_circle(bloom + Vector2(0, 1), 1.25, Color("e1b85e"))


func _bush(center: Vector2, scale: float) -> void:
	for clump in [
		[Vector2(-12, 1), 10.0], [Vector2(0, -5), 13.0],
		[Vector2(13, 1), 9.0], [Vector2(5, 5), 11.0]
	]:
		var point: Vector2 = center + clump[0] * scale
		draw_circle(point + Vector2(1, 2), float(clump[1]) * scale, Color("31533a"))
		draw_circle(point, float(clump[1]) * scale * 0.82, Color("729350"))
		draw_circle(point + Vector2(-3, -3), 2.0 * scale, Color("a6b46a", 0.75))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
