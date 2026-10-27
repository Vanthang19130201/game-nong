extends Node2D

# One lightweight draw node per SoilPlot. Redraws only when its crop stage changes.
var crop_stage: int = 0
var is_ready: bool = false


func set_crop_visual(stage: int, ready: bool) -> void:
	if crop_stage == stage and is_ready == ready:
		return
	crop_stage = stage
	is_ready = ready
	queue_redraw()


func _draw() -> void:
	if crop_stage <= 0:
		return

	var size_factor: float = [0.62, 0.82, 1.0][clampi(crop_stage - 1, 0, 2)]
	_draw_ellipse(Vector2(0, 14), Vector2(11, 4) * size_factor, Color("443026", 0.24))
	_draw_ellipse(Vector2(0, 13), Vector2(7, 2) * size_factor, Color("d6bd8c", 0.16))

	if not is_ready:
		return

	# A restrained warm halo sits behind the mature crop, never over the whole tile.
	_draw_ellipse(Vector2(0, -8), Vector2(25, 16), Color("e8b34f", 0.11))
	_draw_sparkle(Vector2(-17, -23), 0.68)
	_draw_sparkle(Vector2(18, -17), 0.52)


func _draw_sparkle(point: Vector2, size: float) -> void:
	var color := Color("f2d58d", 0.72)
	draw_line(point + Vector2(-3, 0) * size, point + Vector2(3, 0) * size, color, 1.2, true)
	draw_line(point + Vector2(0, -3) * size, point + Vector2(0, 3) * size, color, 1.2, true)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
