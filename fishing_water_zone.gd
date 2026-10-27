extends Node2D

@export var water_id: String = "river"

@export_enum("rect", "ellipse", "polygon")
var shape_mode: String = "rect"

@export var zone_size: Vector2 = Vector2(140, 900)
@export var zone_polygon: PackedVector2Array = PackedVector2Array()

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

	if shape_mode == "polygon":
		return (
			zone_polygon.size() >= 3
			and Geometry2D.is_point_in_polygon(
				local_point,
				zone_polygon
			)
		)

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
	polygon_collision.polygon = (
		zone_polygon
		if shape_mode == "polygon"
		else _ellipse_points(zone_size * 0.88)
	)

	body.add_child(polygon_collision)


func _draw() -> void:
	if not draw_visual:
		return

	if shape_mode == "polygon":
		_draw_polygon_pond()
	elif shape_mode == "ellipse":
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


func _draw_polygon_pond() -> void:
	if zone_polygon.size() < 3:
		return

	# Keep the sandy lip inside the eastern map edge.
	var bank := _scaled_polygon(zone_polygon, 1.05)
	draw_colored_polygon(bank, bank_color)
	draw_polyline(_close_polygon(bank), Color("786c4b"), 3.0, true)

	draw_colored_polygon(zone_polygon, water_color)
	draw_polyline(_close_polygon(zone_polygon), Color("4f8585"), 3.0, true)

	var deep := _scaled_polygon(zone_polygon, 0.78)
	draw_colored_polygon(deep, Color("4f929d", 0.58))

	# A few quiet shallows and ripples break up the large water surface.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-35, -510), Vector2(50, -535), Vector2(92, -485),
			Vector2(78, -422), Vector2(-24, -410), Vector2(-62, -455)
		]),
		Color("8ac0b0", 0.48)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-48, 335), Vector2(38, 312), Vector2(91, 358),
			Vector2(66, 414), Vector2(-34, 430), Vector2(-75, 388)
		]),
		Color("8ac0b0", 0.38)
	)

	for ripple in [
		Vector2(-24, -250), Vector2(36, 34),
		Vector2(-34, 500), Vector2(64, -85)
	]:
		draw_arc(
			ripple,
			24.0,
			0.18,
			PI - 0.18,
			24,
			Color("d4e8d0", 0.62),
			2.0,
			true
		)

	for reed_base in [
		Vector2(-147, -485), Vector2(-135, -65),
		Vector2(-142, 345), Vector2(129, 255)
	]:
		_draw_reeds(reed_base)

	draw_circle(Vector2(-158, 185), 8.0, Color("82735d"))
	draw_circle(Vector2(-156, 185), 5.0, Color("c1b797"))
	draw_circle(Vector2(145, -305), 7.0, Color("82735d"))
	draw_circle(Vector2(144, -305), 4.0, Color("c1b797"))


func _draw_reeds(base: Vector2) -> void:
	for index in range(3):
		var sway := float(index - 1) * 7.0
		draw_line(
			base + Vector2(sway, 14),
			base + Vector2(sway - 3, -15 - index * 2),
			Color("657c4b"),
			2.5,
			true
		)
		draw_circle(
			base + Vector2(sway - 3, -17 - index * 2),
			2.5,
			Color("90704a")
		)


func _scaled_polygon(
	points: PackedVector2Array,
	factor: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * factor)
	return result


func _close_polygon(
	points: PackedVector2Array
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point)
	if points.size() > 0:
		result.append(points[0])
	return result


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
