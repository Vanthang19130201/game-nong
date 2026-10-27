extends Node2D

# Draw-only treatment attached to a building so it follows edit-mode moves.
# It deliberately has no collision, input, interaction, or per-frame work.
@export_enum(
	"house",
	"warehouse",
	"feed_mill",
	"chicken_coop",
	"cow_shed",
	"bakery",
	"dairy",
	"spinning_machine",
	"market_stall",
	"order_board",
	"dog_house"
) var building_kind: String = "warehouse"

const DARK := Color("51402e", 0.14)
const EARTH := Color("987047", 0.10)
const WOOD := Color("805638")
const WOOD_LIGHT := Color("b18a56")
const STONE := Color("b3aa8e", 0.82)


func _draw() -> void:
	var center := Vector2(0, 28)
	var radius := Vector2(84, 38)

	if building_kind == "house":
		center = Vector2(0, 58)
		radius = Vector2(138, 54)
	elif building_kind in ["chicken_coop", "cow_shed"]:
		# Their animal pens already provide ground detail around the buildings.
		center = Vector2(0, 24)
		radius = Vector2(70, 30) if building_kind == "chicken_coop" else Vector2(88, 34)
	elif building_kind in ["bakery", "dairy", "spinning_machine"]:
		radius = Vector2(86, 38)
	elif building_kind == "warehouse":
		radius = Vector2(94, 42)
	elif building_kind == "market_stall":
		radius = Vector2(88, 40)
	elif building_kind == "dog_house":
		radius = Vector2(54, 28)
	elif building_kind == "order_board":
		radius = Vector2(58, 28)

	# A compact soft shadow gives the building contact with the ground without
	# adding clutter at the entrance or animal walking space.
	_draw_oval(center + Vector2(0, 7), radius * Vector2(1.0, 0.34), DARK)
	_draw_rough_patch(center, radius * Vector2(0.88, 0.24), EARTH)


func create_visual_preview() -> Node2D:
	var preview := Node2D.new()
	preview.name = "GroundTreatmentPreview"
	preview.set_script(load("res://building_ground_visual.gd"))
	preview.set("building_kind", building_kind)
	preview.z_index = z_index
	return preview


func _draw_rough_patch(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var variation: float = 0.92 + 0.055 * sin(float(index) * 2.3)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * variation)
	draw_colored_polygon(points, color)


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw_approach_stones(center: Vector2, radius: Vector2, size: float) -> void:
	var start_y: float = center.y + radius.y * 0.68
	_draw_stone(Vector2(-9, start_y), size * 0.72)
	_draw_stone(Vector2(12, start_y + 8), size * 0.62)


func _draw_identity_props(center: Vector2, radius: Vector2, size: float) -> void:
	match building_kind:
		"house":
			# The front door remains open; garden props are kept to the sides.
			_draw_mailbox(Vector2(-radius.x * 0.86, center.y - 18), size * 0.68)
			_draw_flower_bed(Vector2(-radius.x * 0.94, center.y + 48), size * 0.62)
			_draw_bench(Vector2(radius.x * 0.94, center.y + 35), size * 0.66)
			_draw_lamp(Vector2(-radius.x * 1.12, center.y + 82), size * 0.62)
			_draw_barrel(Vector2(radius.x * 1.08, center.y + 3), size * 0.54)
			_draw_short_fence(Vector2(radius.x * 1.22, center.y + 96), size * 0.7)
		"warehouse":
			_draw_crate(Vector2(-radius.x * 0.98, center.y - 2), size * 0.58)
			_draw_barrel(Vector2(radius.x * 1.02, center.y + 2), size * 0.56)
			_draw_sack(Vector2(radius.x * 1.05, center.y + 30), size * 0.52)
		"feed_mill":
			_draw_hay(Vector2(-radius.x * 1.02, center.y + 2), size * 0.52)
			_draw_sack(Vector2(radius.x * 1.02, center.y + 8), size * 0.52)
		"chicken_coop":
			pass
		"cow_shed":
			pass
		"bakery":
			_draw_sack(Vector2(-radius.x * 1.04, center.y + 2), size * 0.56)
			_draw_crate(Vector2(radius.x * 1.04, center.y + 6), size * 0.54)
		"dairy":
			_draw_milk_can(Vector2(-radius.x * 1.02, center.y + 3), size * 0.56)
			_draw_bucket(Vector2(radius.x * 1.02, center.y + 5), size * 0.54)
		"spinning_machine":
			_draw_basket(Vector2(-radius.x * 1.02, center.y + 3), size * 0.56)
			_draw_fiber_bundle(Vector2(radius.x * 1.02, center.y + 5), size * 0.54)
		"market_stall":
			_draw_crate(Vector2(-radius.x * 1.02, center.y + 2), size * 0.54)
			_draw_basket(Vector2(radius.x * 1.02, center.y + 5), size * 0.54)
		"order_board":
			_draw_crate(Vector2(radius.x * 1.02, center.y + 5), size * 0.48)
		"dog_house":
			_draw_bowl(Vector2(-radius.x * 1.02, center.y + 3), size * 0.56)
			_draw_flower_bed(Vector2(radius.x * 1.06, center.y + 7), size * 0.5)


func _draw_stone(point: Vector2, size: float) -> void:
	_draw_oval(point + Vector2(1, 3) * size, Vector2(11, 5) * size, DARK)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-10, 0) * size,
		point + Vector2(-6, -5) * size,
		point + Vector2(6, -4) * size,
		point + Vector2(11, 0) * size,
		point + Vector2(5, 5) * size,
		point + Vector2(-7, 4) * size
	]), STONE)
	draw_line(point + Vector2(-5, -3) * size, point + Vector2(5, -3) * size, Color("ded2b4", 0.75), 1.3 * size, true)


func _draw_crate(point: Vector2, size: float) -> void:
	var body := Rect2(point + Vector2(-11, -10) * size, Vector2(22, 20) * size)
	draw_rect(body.grow(1.5 * size), Color("60442e"), true)
	draw_rect(body, WOOD_LIGHT, true)
	draw_rect(body, Color("5f432e"), false, 1.7 * size)
	draw_line(point + Vector2(-8, -7) * size, point + Vector2(8, 7) * size, Color("d0a774"), 1.5 * size, true)
	draw_line(point + Vector2(8, -7) * size, point + Vector2(-8, 7) * size, Color("d0a774"), 1.5 * size, true)


func _draw_barrel(point: Vector2, size: float) -> void:
	var body := Rect2(point + Vector2(-7, -12) * size, Vector2(14, 24) * size)
	draw_rect(body, Color("8b6040"), true)
	draw_rect(body, Color("60452f"), false, 1.8 * size)
	for y in [-7.0, 5.0]:
		draw_line(point + Vector2(-7, y) * size, point + Vector2(7, y) * size, Color("c09a68"), 1.5 * size, true)


func _draw_sack(point: Vector2, size: float) -> void:
	var body := PackedVector2Array([
		point + Vector2(-8, -11) * size, point + Vector2(-6, -16) * size,
		point + Vector2(6, -16) * size, point + Vector2(9, -10) * size,
		point + Vector2(7, 9) * size, point + Vector2(-7, 9) * size
	])
	draw_colored_polygon(body, Color("c7ad78"))
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[0]]), Color("856744"), 1.5 * size, true)
	draw_line(point + Vector2(-5, -13) * size, point + Vector2(5, -13) * size, Color("e6d3a5"), 1.7 * size, true)


func _draw_hay(point: Vector2, size: float) -> void:
	draw_circle(point + Vector2(-6, 0) * size, 8.0 * size, Color("c9a35e"))
	draw_circle(point + Vector2(4, -2) * size, 10.0 * size, Color("ddbd74"))
	draw_circle(point + Vector2(12, 2) * size, 7.0 * size, Color("c9a35e"))
	for x in [-7.0, 0.0, 7.0]:
		draw_line(point + Vector2(x, -6) * size, point + Vector2(x + 2, 6) * size, Color("9d7a45", 0.72), 1.2 * size, true)


func _draw_milk_can(point: Vector2, size: float) -> void:
	draw_rect(Rect2(point + Vector2(-7, -10) * size, Vector2(14, 20) * size), Color("aaa084"), true)
	draw_rect(Rect2(point + Vector2(-7, -10) * size, Vector2(14, 20) * size), Color("66533e"), false, 1.5 * size)
	draw_rect(Rect2(point + Vector2(-4, -15) * size, Vector2(8, 5) * size), Color("c3b697"), true)
	draw_line(point + Vector2(-6, -1) * size, point + Vector2(6, -1) * size, Color("e5d6b2"), 1.4 * size, true)


func _draw_bucket(point: Vector2, size: float) -> void:
	var shape := PackedVector2Array([
		point + Vector2(-8, -8) * size, point + Vector2(8, -8) * size,
		point + Vector2(6, 9) * size, point + Vector2(-6, 9) * size
	])
	draw_colored_polygon(shape, Color("a77a4e"))
	draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[0]]), Color("5e432e"), 1.5 * size, true)
	draw_arc(point + Vector2(0, -7) * size, 8.0 * size, PI, TAU, 12, Color("775636"), 1.3 * size, true)


func _draw_basket(point: Vector2, size: float) -> void:
	draw_rect(Rect2(point + Vector2(-10, -5) * size, Vector2(20, 12) * size), Color("ae8150"), true)
	draw_rect(Rect2(point + Vector2(-10, -5) * size, Vector2(20, 12) * size), Color("63472e"), false, 1.6 * size)
	for x in [-5.0, 0.0, 5.0]:
		draw_line(point + Vector2(x, -3) * size, point + Vector2(x - 1, 5) * size, Color("d2aa70"), 1.0 * size, true)
	draw_arc(point + Vector2(0, -5) * size, 9.0 * size, PI, TAU, 12, Color("694b31"), 1.5 * size, true)


func _draw_fiber_bundle(point: Vector2, size: float) -> void:
	_draw_oval(point + Vector2(0, 7) * size, Vector2(13, 4) * size, DARK)
	for index in range(5):
		var x: float = (float(index) - 2.0) * 3.0 * size
		draw_line(point + Vector2(x, 7) * size, point + Vector2(x + 3, -10 - float(index % 2) * 3) * size, Color("d6c78d"), 2.1 * size, true)
	draw_line(point + Vector2(-8, 2) * size, point + Vector2(8, 2) * size, Color("9a6845"), 2.0 * size, true)


func _draw_bowl(point: Vector2, size: float) -> void:
	draw_arc(point + Vector2(0, -1) * size, 9.0 * size, 0.05, PI - 0.05, 16, Color("69452f"), 2.2 * size, true)
	draw_line(point + Vector2(-9, 0) * size, point + Vector2(9, 0) * size, Color("b68254"), 3.0 * size, true)
	draw_arc(point + Vector2(0, -4) * size, 7.0 * size, PI, TAU, 12, Color("caa776"), 1.4 * size, true)


func _draw_mailbox(point: Vector2, size: float) -> void:
	draw_line(point + Vector2(0, 12) * size, point + Vector2(0, -6) * size, Color("60452f"), 3.0 * size, true)
	draw_rect(Rect2(point + Vector2(-10, -17) * size, Vector2(20, 13) * size), Color("73905a"), true)
	draw_rect(Rect2(point + Vector2(-10, -17) * size, Vector2(20, 13) * size), Color("506b3e"), false, 1.4 * size)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-12, -17) * size, point + Vector2(0, -24) * size, point + Vector2(12, -17) * size]), Color("9a6845"))
	draw_rect(Rect2(point + Vector2(3, -14) * size, Vector2(3, 5) * size), Color("e8b34f"), true)


func _draw_bench(point: Vector2, size: float) -> void:
	for x in [-14.0, 12.0]:
		draw_rect(Rect2(point + Vector2(x, 1) * size, Vector2(4, 12) * size), WOOD, true)
	draw_rect(Rect2(point + Vector2(-24, -5) * size, Vector2(48, 8) * size), WOOD_LIGHT, true)
	draw_rect(Rect2(point + Vector2(-24, -5) * size, Vector2(48, 8) * size), Color("60432f"), false, 1.5 * size)
	draw_rect(Rect2(point + Vector2(-22, -13) * size, Vector2(44, 6) * size), Color("bd9866"), true)


func _draw_lamp(point: Vector2, size: float) -> void:
	draw_line(point + Vector2(0, 15) * size, point + Vector2(0, -22) * size, Color("5b432d"), 4.0 * size, true)
	draw_rect(Rect2(point + Vector2(-6, -34) * size, Vector2(12, 12) * size), Color("805a38"), true)
	draw_rect(Rect2(point + Vector2(-4, -32) * size, Vector2(8, 8) * size), Color("f2d68e", 0.9), true)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-8, -34) * size, point + Vector2(0, -40) * size, point + Vector2(8, -34) * size]), Color("5b432d"))


func _draw_short_fence(point: Vector2, size: float) -> void:
	var start := point + Vector2(-25, 0) * size
	var finish := point + Vector2(25, 0) * size
	draw_line(start + Vector2(0, -5) * size, finish + Vector2(0, -5) * size, WOOD, 3.0 * size, true)
	draw_line(start + Vector2(0, 3) * size, finish + Vector2(0, 3) * size, WOOD_LIGHT, 3.0 * size, true)
	for post in [start, finish]:
		draw_rect(Rect2(post + Vector2(-2, -11) * size, Vector2(5, 21) * size), WOOD, true)


func _draw_flower_bed(point: Vector2, size: float) -> void:
	_draw_oval(point + Vector2(0, 5) * size, Vector2(21, 10) * size, Color("6c563b", 0.26))
	for offset in [Vector2(-11, 1), Vector2(0, -5), Vector2(11, 2)]:
		var flower: Vector2 = point + offset * size
		draw_line(flower + Vector2(0, 9) * size, flower, Color("567346"), 1.6 * size, true)
		draw_circle(flower, 3.4 * size, Color("ecd79b"))
		draw_circle(flower, 1.2 * size, Color("d4a64d"))
