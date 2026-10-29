extends Node2D

# Occasional decorative fish jumps. The tweens only run during an effect.
const JUMP_POINTS: Array[Vector2] = [
	Vector2(-28, -390),
	Vector2(42, -150),
	Vector2(-24, 120),
	Vector2(35, 390)
]
const FISH_ART_PATHS: Array[String] = [
	"res://assets/fishing/fish/tilapia.png",
	"res://assets/fishing/fish/perch.png",
	"res://assets/fishing/fish/catfish.png",
	"res://assets/fishing/fish/loach.png",
	"res://assets/fishing/fish/snakehead.png",
	"res://assets/fishing/fish/salmon.png",
	"res://assets/fishing/fish/koi_orange.png",
	"res://assets/fishing/fish/koi_gold.png"
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
var jump_fish_art: Texture2D


func _ready() -> void:
	rng.randomize()
	jump_fish_art = load(FISH_ART_PATHS[rng.randi_range(0, FISH_ART_PATHS.size() - 1)]) as Texture2D
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
	jump_fish_art = load(FISH_ART_PATHS[rng.randi_range(0, FISH_ART_PATHS.size() - 1)]) as Texture2D
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
	if jump_fish_art == null:
		return
	var art_size: Vector2 = jump_fish_art.get_size()
	if art_size.x <= 0.0 or art_size.y <= 0.0:
		return
	# The supplied catch artwork is also used for the brief water jump. It is
	# tiny on purpose so it reads as ambient life and never hides a real cast.
	var scale_factor: float = 42.0 / maxf(art_size.x, art_size.y)
	draw_set_transform(fish_position, -0.12, Vector2(scale_factor, scale_factor))
	draw_texture(jump_fish_art, -art_size * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
