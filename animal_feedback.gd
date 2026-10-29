extends Node2D

# Short, local presentation feedback for actions already committed by the
# existing animal/station systems. No reward, timer or save state lives here.
var effect := ""
var elapsed := 0.0
var duration := 0.0


func _ready() -> void:
	z_index = 10
	set_process(false)


func play(next_effect: String) -> void:
	effect = next_effect
	elapsed = 0.0
	duration = 0.75 if effect == "feed" else 1.05
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		set_process(false)
		effect = ""
		queue_redraw()
		return
	queue_redraw()


func _draw() -> void:
	if effect.is_empty():
		return
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var rise := -30.0 - progress * 14.0
	var alpha := minf(1.0, (1.0 - progress) * 1.35)
	if effect == "feed":
		_draw_heart(Vector2(0, rise), Color(1.0, 0.49, 0.53, alpha))
		return
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + elapsed * 1.8
		var point := Vector2(cos(angle), sin(angle) * 0.72) * (8.0 + progress * 10.0) + Vector2(0, rise)
		var color := Color(1.0, 0.88, 0.41, alpha)
		draw_line(point - Vector2(2.2, 0), point + Vector2(2.2, 0), color, 1.25, true)
		draw_line(point - Vector2(0, 2.2), point + Vector2(0, 2.2), color, 1.25, true)


func _draw_heart(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-2.5, -1.5), 3.0, color)
	draw_circle(center + Vector2(2.5, -1.5), 3.0, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-5.4, -1.0), center + Vector2(5.4, -1.0), center + Vector2(0, 6.5)
	]), color)
