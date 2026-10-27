extends Node2D

# Decorative dock only: no collision, input, fishing state, or per-frame work.
func _draw() -> void:
	var deck := Rect2(-32, -52, 64, 104)
	draw_rect(deck.grow(5), Color("604832"), true)
	draw_rect(deck, Color("b58a58"), true)
	draw_rect(deck, Color("68482f"), false, 3.0)

	for index in range(5):
		var y := deck.position.y + 10 + index * 20
		draw_line(Vector2(-29, y), Vector2(29, y), Color("8d6744"), 2.0, true)

	# Four short corner posts frame the planks without blocking the walking area.
	for post in [Vector2(-27, -46), Vector2(27, -46), Vector2(-27, 46), Vector2(27, 46)]:
		draw_rect(Rect2(post - Vector2(3, 3), Vector2(7, 7)), Color("62452f"), true)
		draw_rect(Rect2(post - Vector2(2, 2), Vector2(5, 5)), Color("c19a61"), true)

	# A bucket and one small lantern are purely visual props.
	draw_rect(Rect2(-20, -20, 12, 14), Color("8d6545"), true)
	draw_rect(Rect2(-20, -20, 12, 14), Color("503a2b"), false, 2.0)
	draw_rect(Rect2(11, 18, 8, 10), Color("68482f"), true)
	draw_rect(Rect2(9, 14, 12, 7), Color("a77443"), true)
	draw_circle(Vector2(15, 18), 4.0, Color("f5d98a", 0.9))
