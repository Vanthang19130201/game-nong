extends Node2D

@export var water_id: String = "river"

@export_enum("rect", "ellipse")
var shape_mode: String = "rect"

@export var zone_size: Vector2 = Vector2(140, 900)

@export var draw_visual: bool = false
@export var block_player: bool = false

@export var water_color: Color = Color("66aeb4")
@export var deep_water_color: Color = Color("4f929d")
@export var bank_color: Color = Color("b8a56f")

const ELLIPSE_POINTS: int = 48


func _ready() -> void:
	add_to_group("fishing_water_zones")

	z_index = -7

	if block_player:
		_create_water_collision()

	queue_redraw()


func contains_world_point(world_point: Vector2) -> bool:
	var local_point := to_local(world_point)
	var half := zone_size * 0.5

	if shape_mode == "rect":
		return (
			absf(local_point.x) <= half.x
			and absf(local_point.y) <= half.y
		)

	if half.x <= 0.0 or half.y <= 0.0:
		return false

	var normalized := Vector2(
		local_point.x / half.x,
		local_point.y / half.y
	)

	return normalized.length_squared() <= 1.0


func _create_water_collision() -> void:
	var body := StaticBody2D.new()

	body.name = "WaterBody"
	body.collision_layer = 1
	body.collision_mask = 0

	add_child(body)

	if shape_mode == "rect":
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()

		shape.size = zone_size * 0.88
		collision.shape = shape

		body.add_child(collision)
		return

	var polygon_collision := CollisionPolygon2D.new()

	polygon_collision.polygon = _ellipse_points(
		zone_size * 0.88
	)

	body.add_child(polygon_collision)


func _draw() -> void:
	if not draw_visual:
		return

	if shape_mode == "ellipse":
		_draw_pond()
	else:
		_draw_rectangle_water()


func _draw_rectangle_water() -> void:
	var rect := Rect2(
		-zone_size * 0.5,
		zone_size
	)

	draw_rect(
		rect,
		water_color,
		true
	)


func _draw_pond() -> void:
	var bank := _ellipse_points(
		zone_size
	)

	draw_colored_polygon(
		bank,
		bank_color
	)

	var inner_size := zone_size - Vector2(28, 22)

	var water := _ellipse_points(
		inner_size
	)

	draw_colored_polygon(
		water,
		water_color
	)

	var deep := _ellipse_points(
		inner_size * 0.72
	)

	draw_colored_polygon(
		deep,
		Color(
			deep_water_color,
			0.25
		)
	)

	draw_polyline(
		_close_polygon(water),
		Color(
			0.83,
			0.92,
			0.80,
			0.75
		),
		2.0,
		true
	)

	_draw_pond_details()


func _draw_pond_details() -> void:
	var half := zone_size * 0.5

	draw_circle(
		Vector2(
			-half.x * 0.62,
			half.y * 0.62
		),
		8,
		Color("82735d")
	)

	draw_circle(
		Vector2(
			half.x * 0.58,
			-half.y * 0.55
		),
		6,
		Color("887965")
	)

	var reed_base := Vector2(
		-half.x * 0.78,
		-half.y * 0.15
	)

	for offset in [-8.0, 0.0, 8.0]:
		draw_line(
			reed_base + Vector2(offset, 12),
			reed_base + Vector2(offset + 2, -10),
			Color("617a45"),
			2.0,
			true
		)

		draw_circle(
			reed_base + Vector2(offset + 2, -12),
			2.5,
			Color("8b6843")
		)

	var right_reed := Vector2(
		half.x * 0.74,
		half.y * 0.1
	)

	for offset in [-6.0, 2.0, 10.0]:
		draw_line(
			right_reed + Vector2(offset, 12),
			right_reed + Vector2(offset - 2, -8),
			Color("617a45"),
			2.0,
			true
		)


func _ellipse_points(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := size * 0.5

	for index in range(ELLIPSE_POINTS):
		var angle := (
			TAU
			* float(index)
			/ float(ELLIPSE_POINTS)
		)

		points.append(
			Vector2(
				cos(angle) * radius.x,
				sin(angle) * radius.y
			)
		)

	return points


func _close_polygon(
	points: PackedVector2Array
) -> PackedVector2Array:

	var result := PackedVector2Array()

	for point in points:
		result.append(point)

	if points.size() > 0:
		result.append(points[0])

	return result
