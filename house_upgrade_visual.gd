extends Node2D

# A draw-only, local House embellishment. It follows the House automatically,
# has no collision, and gives each existing upgrade level a visible identity.
var house_level: int = 1:
	set(value):
		house_level = clampi(value, 1, 4)
		queue_redraw()

const OUTLINE := Color("5b402d")
const WOOD := Color("9a6845")
const CREAM := Color("fff0cc")
const LEAF := Color("6f8f4a")
const FLOWER := Color("e8b34f")


func _draw() -> void:
	if house_level >= 2:
		_draw_flower_box(Vector2(-29, 15))
		_draw_flower_box(Vector2(29, 15))
		# A compact porch mat makes the upgraded entrance easier to read without
		# covering the actual door/collision footprint.
		draw_rect(Rect2(-13, 39, 26, 5), Color("6c563b", 0.42), true)
	if house_level >= 3:
		# Small canvas awning and chimney cap: additive artwork only.
		draw_colored_polygon(PackedVector2Array([Vector2(-33, -11), Vector2(33, -11), Vector2(27, -2), Vector2(-27, -2)]), CREAM)
		draw_polyline(PackedVector2Array([Vector2(-33, -11), Vector2(33, -11), Vector2(27, -2), Vector2(-27, -2), Vector2(-33, -11)]), OUTLINE, 1.4, true)
		draw_rect(Rect2(22, -41, 9, 18), WOOD, true)
		draw_rect(Rect2(20, -44, 13, 4), OUTLINE, true)
		draw_line(Vector2(24, -35), Vector2(29, -35), CREAM, 1.2, true)
	if house_level >= 4:
		# Final level adds two warm window lamps and a tiny roof pennant.
		for point in [Vector2(-37, 2), Vector2(37, 2)]:
			draw_circle(point, 4.0, Color("e8b34f", 0.34))
			draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), FLOWER, true)
		draw_line(Vector2(-2, -48), Vector2(-2, -63), OUTLINE, 1.6, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-1, -62), Vector2(11, -58), Vector2(-1, -54)]), LEAF)


func _draw_flower_box(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(9, 2), Vector2(18, 7)), WOOD, true)
	draw_rect(Rect2(center - Vector2(9, 2), Vector2(18, 7)), OUTLINE, false, 1.1)
	for offset in [-5.0, 0.0, 5.0]:
		draw_line(center + Vector2(offset, -1), center + Vector2(offset, -7), LEAF, 1.4, true)
		draw_circle(center + Vector2(offset, -8), 2.0, FLOWER)
