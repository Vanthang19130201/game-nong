extends Node2D

# Occasional decorative fish jumps. The tweens only run during an effect.
const JUMP_POINTS: Array[Vector2] = [
	Vector2(-28, -390),
	Vector2(42, -150),
	Vector2(-24, 120),
	Vector2(35, 390)
]

var rng := RandomNumberGenerator.new()
var jump_point: Vector2 = Vector2.ZERO
var jump_progress: float = 0.0:
	set(value):
		jump_progress = value
		queue_redraw()
var ripple_progress: float = 0.0:
	set(value):
		ripple_progress = value
		queue_redraw()
var fish_visible: bool = false
var ripple_visible: bool = false
var jump_timer: Timer


func _ready() -> void:
	rng.randomize()
	z_index = 1
	jump_timer = Timer.new()
	jump_timer.one_shot = true
	jump_timer.timeout.connect(_start_fish_jump)
	add_child(jump_timer)
	_schedule_next_jump()


func _schedule_next_jump() -> void:
	jump_timer.start(rng.randf_range(3.0, 5.5))


func _start_fish_jump() -> void:
	jump_point = JUMP_POINTS[rng.randi_range(0, JUMP_POINTS.size() - 1)]
	jump_progress = 0.0
	fish_visible = true
	var tween := create_tween()
	tween.tween_property(self, "jump_progress", 1.0, 0.72)
	tween.tween_callback(_finish_fish_jump)
	_schedule_next_jump()


func _finish_fish_jump() -> void:
	fish_visible = false
	ripple_progress = 0.0
	ripple_visible = true
	var tween := create_tween()
	tween.tween_property(self, "ripple_progress", 1.0, 0.9)
	tween.tween_callback(func() -> void:
		ripple_visible = false
		queue_redraw()
	)


func _draw() -> void:
	if ripple_visible:
		var radius := lerpf(5.0, 25.0, ripple_progress)
		var alpha := 1.0 - ripple_progress
		draw_arc(jump_point, radius, 0.1, PI - 0.1, 20, Color(0.86, 0.96, 0.86, alpha), 2.0, true)
		draw_arc(jump_point, radius * 0.62, 0.15, PI - 0.15, 16, Color(0.86, 0.96, 0.86, alpha * 0.7), 1.5, true)

	if not fish_visible:
		return

	var progress := jump_progress
	var fish_position := jump_point + Vector2(12.0 * (progress - 0.5), -sin(progress * PI) * 30.0)
	var fish := PackedVector2Array([
		fish_position + Vector2(-11, 0),
		fish_position + Vector2(-5, -5),
		fish_position + Vector2(5, -5),
		fish_position + Vector2(11, 0),
		fish_position + Vector2(5, 5),
		fish_position + Vector2(-5, 5)
	])
	draw_colored_polygon(fish, Color("f1ce82"))
	draw_colored_polygon(PackedVector2Array([
		fish_position + Vector2(9, 0),
		fish_position + Vector2(16, -5),
		fish_position + Vector2(16, 5)
	]), Color("d5a75e"))
	draw_circle(fish_position + Vector2(-6, -1), 1.3, Color("493b2a"))
