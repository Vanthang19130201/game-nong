extends Node2D

# Low, non-colliding pen artwork. As a child of its building it follows moves
# and saved positions automatically; animal movement remains managed by AnimalGroup.
@export_enum("chicken", "cow") var pen_type: String = "chicken"

const DARK_WOOD := Color("5d412d")
const WOOD := Color("9b7047")
const WOOD_LIGHT := Color("c19a67")
const GRASS := Color("708d4d")

var half_size: Vector2
var center_offset: Vector2
var gate_width: float


func _ready() -> void:
	z_index = -3
	if pen_type == "cow":
		half_size = Vector2(165, 165)
		center_offset = Vector2(0, 20)
		gate_width = 68.0
	else:
		half_size = Vector2(145, 145)
		center_offset = Vector2.ZERO
		gate_width = 64.0
	queue_redraw()


func create_visual_preview() -> Node2D:
	var copy := Node2D.new()
	copy.name = "AnimalPenPreview"
	copy.set_script(get_script())
	copy.set("pen_type", pen_type)
	copy.z_index = z_index
	return copy


func _draw() -> void:
	var center := center_offset
	# Gentle dirt patches and a small shadow make the paddock read as a yard.
	_draw_ellipse(center + Vector2(0, half_size.y * 0.34), Vector2(half_size.x * 0.74, half_size.y * 0.45), Color("9d8056", 0.15))
	_draw_ellipse(center + Vector2(-half_size.x * 0.28, half_size.y * 0.46), Vector2(38, 18), Color("75583d", 0.16))
	_draw_ellipse(center + Vector2(half_size.x * 0.32, -half_size.y * 0.24), Vector2(34, 14), Color("a59261", 0.14))

	_draw_fence(center)
	_draw_grass_edges(center)
	_draw_props(center)


func _draw_fence(center: Vector2) -> void:
	var left := center.x - half_size.x
	var right := center.x + half_size.x
	var top := center.y - half_size.y
	var bottom := center.y + half_size.y
	var gate_half := gate_width * 0.5

	# Rear rail and both sides. The low profile keeps the animals visible.
	_horizontal_rail(left, right, top, true)
	_vertical_rail(left, top, bottom, true)
	_vertical_rail(right, top, bottom, true)
	# South entrance stays open by 64-68 px for a clear walking route.
	_horizontal_rail(left, center.x - gate_half, bottom, false)
	_horizontal_rail(center.x + gate_half, right, bottom, false)
	_fence_post(Vector2(center.x - gate_half, bottom))
	_fence_post(Vector2(center.x + gate_half, bottom))


func _horizontal_rail(left: float, right: float, y: float, rear: bool) -> void:
	if right - left < 2.0:
		return
	var shade := Color(DARK_WOOD, 0.24)
	draw_line(Vector2(left, y + 6), Vector2(right, y + 6), shade, 8.0, true)
	var rail_width := 6.0 if pen_type == "cow" else 5.0
	for rail_y in [y - 5.0, y + 2.0]:
		draw_line(Vector2(left, rail_y), Vector2(right, rail_y), DARK_WOOD, rail_width, true)
		draw_line(Vector2(left, rail_y - 1.0), Vector2(right, rail_y - 1.0), WOOD_LIGHT, 2.0, true)
	var post_step := 48.0 if pen_type == "chicken" else 56.0
	var x := left
	while x < right:
		_fence_post(Vector2(x, y))
		x += post_step
	_fence_post(Vector2(right, y))
	if rear:
		draw_line(Vector2(left, y + 8), Vector2(right, y + 8), Color("6e8a4c", 0.6), 2.0, true)


func _vertical_rail(x: float, top: float, bottom: float, _rear: bool) -> void:
	draw_line(Vector2(x + 6, top), Vector2(x + 6, bottom), Color(DARK_WOOD, 0.24), 8.0, true)
	var rail_width := 6.0 if pen_type == "cow" else 5.0
	for rail_x in [x - 5.0, x + 2.0]:
		draw_line(Vector2(rail_x, top), Vector2(rail_x, bottom), DARK_WOOD, rail_width, true)
		draw_line(Vector2(rail_x - 1.0, top), Vector2(rail_x - 1.0, bottom), WOOD_LIGHT, 2.0, true)
	var post_step := 48.0 if pen_type == "chicken" else 56.0
	var y := top
	while y < bottom:
		_fence_post(Vector2(x, y))
		y += post_step
	_fence_post(Vector2(x, bottom))


func _fence_post(point: Vector2) -> void:
	var post_size := Vector2(11, 22) if pen_type == "cow" else Vector2(9, 19)
	draw_rect(Rect2(point - post_size * 0.5 + Vector2(1, 2), post_size), DARK_WOOD, true)
	draw_rect(Rect2(point - post_size * 0.5, post_size - Vector2(2, 3)), WOOD, true)
	draw_rect(Rect2(point - post_size * 0.5, Vector2(post_size.x - 2, 4)), WOOD_LIGHT, true)


func _draw_props(center: Vector2) -> void:
	if pen_type == "chicken":
		_trough(center + Vector2(-78, 22), 0.82, false)
		_trough(center + Vector2(83, 26), 0.58, true)
		_hay(center + Vector2(-76, 83), 0.68)
		_barrel(center + Vector2(94, 86), 0.62)
		for offset in [Vector2(-45, 38), Vector2(-59, 42), Vector2(-30, 46), Vector2(28, 58)]:
			draw_circle(center + offset, 2.0, Color("d8bd79"))
	else:
		_trough(center + Vector2(-112, 57), 1.2, false)
		_trough(center + Vector2(111, 74), 0.72, true)
		_hay(center + Vector2(-117, 106), 0.78)
		_barrel(center + Vector2(112, -90), 0.72)
		_draw_ellipse(center + Vector2(-30, 83), Vector2(35, 18), Color("72563e", 0.21))
		_draw_ellipse(center + Vector2(-27, 80), Vector2(23, 10), Color("977849", 0.18))


func _draw_grass_edges(center: Vector2) -> void:
	var left := center.x - half_size.x + 16
	var right := center.x + half_size.x - 16
	var top := center.y - half_size.y + 17
	var bottom := center.y + half_size.y - 18
	for point in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
		_tuft(point)
	if pen_type == "cow":
		_tuft(Vector2(center.x - 138, center.y - 55))
		_tuft(Vector2(center.x + 138, center.y - 18))
	else:
		_tuft(Vector2(center.x - 118, center.y + 8))
		_tuft(Vector2(center.x + 118, center.y - 18))
		_tuft(Vector2(center.x - 92, center.y + 112))
		_tuft(Vector2(center.x + 96, center.y + 108))


func _trough(point: Vector2, scale: float, water: bool) -> void:
	var wood := Color("7d5b3d")
	draw_rect(Rect2(point + Vector2(-25, -7) * scale, Vector2(50, 16) * scale), DARK_WOOD, true)
	draw_rect(Rect2(point + Vector2(-21, -5) * scale, Vector2(42, 10) * scale), Color("9b7047"), true)
	draw_rect(Rect2(point + Vector2(-18, -3) * scale, Vector2(36, 5) * scale), Color("83a49a") if water else Color("cba96b"), true)
	draw_line(point + Vector2(-23, 9) * scale, point + Vector2(-19, 16) * scale, wood, 3.0 * scale, true)
	draw_line(point + Vector2(23, 9) * scale, point + Vector2(19, 16) * scale, wood, 3.0 * scale, true)


func _hay(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 6) * scale, Vector2(25, 8) * scale, Color("58462f", 0.22))
	draw_circle(point + Vector2(-9, 1) * scale, 10.0 * scale, Color("c8a45f"))
	draw_circle(point + Vector2(3, -3) * scale, 13.0 * scale, Color("dfbd73"))
	draw_circle(point + Vector2(14, 2) * scale, 8.0 * scale, Color("c8a45f"))
	for offset in [-8.0, 0.0, 8.0]:
		draw_line(point + Vector2(offset, -6) * scale, point + Vector2(offset + 3, 7) * scale, Color("9d7a45"), 1.4 * scale, true)


func _barrel(point: Vector2, scale: float) -> void:
	var rect := Rect2(point + Vector2(-8, -13) * scale, Vector2(16, 26) * scale)
	draw_rect(rect, Color("765137"), true)
	draw_rect(rect, DARK_WOOD, false, 2.0 * scale)
	for y in [-8.0, 5.0]:
		draw_line(point + Vector2(-8, y) * scale, point + Vector2(8, y) * scale, WOOD_LIGHT, 2.0 * scale, true)


func _tuft(point: Vector2) -> void:
	draw_line(point, point + Vector2(-6, -12), GRASS, 2.2, true)
	draw_line(point, point + Vector2(0, -17), Color("a4b56b"), 2.4, true)
	draw_line(point, point + Vector2(7, -11), GRASS, 2.0, true)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
