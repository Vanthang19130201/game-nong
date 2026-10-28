extends Node2D

var body: CharacterBody2D
var phase: float = 0.0


func _ready() -> void:
	body = get_parent() as CharacterBody2D

	# Bóng nằm NGAY dưới chân Player.
	position = Vector2(0, 3)

	z_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	if body == null:
		return

	var moving := body.velocity.length_squared() > 32.0

	if moving:
		phase += delta * 5.0

	queue_redraw()


func _draw() -> void:
	var moving := body != null and body.velocity.length_squared() > 32.0

	# Chỉ co giãn rất nhẹ khi đi.
	var squash := 1.0
	if moving:
		squash = 0.96 + sin(phase) * 0.04

	var points := PackedVector2Array()

	for index in range(24):
		var angle := TAU * float(index) / 24.0

		points.append(
			Vector2(
				cos(angle) * 13.0 * squash,
				sin(angle) * 3.2
			)
		)

	# Shadow mềm, nhỏ và sát chân hơn.
	draw_colored_polygon(
		points,
		Color(0.01, 0.04, 0.01, 0.01)
	)
