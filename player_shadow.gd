extends Node2D

var body: CharacterBody2D
var phase: float = 0.0


func _ready() -> void:
	body = get_parent() as CharacterBody2D
	position = Vector2(0, 24)
	z_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	if body == null:
		return
	phase += delta * (3.0 if body.velocity.length_squared() > 32.0 else 0.6)
	queue_redraw()


func _draw() -> void:
	var moving := body != null and body.velocity.length_squared() > 32.0
	var squash := 0.92 + (0.08 * sin(phase) if moving else 0.0)
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(Vector2(cos(angle) * 15.0 * squash, sin(angle) * 4.2))
	draw_colored_polygon(points, Color("243728", 0.28))
