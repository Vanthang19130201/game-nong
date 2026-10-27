extends Node2D

# Presentation only: no inventory, production timers, physics bodies or save data.
const APPEARANCE: Dictionary = {
	"chicken": {"frames": preload("res://assets/animals/chicken/chicken_frames.tres"), "height": 40.0, "speed": 28.0, "radius": 8.0},
	"cow": {"frames": preload("res://assets/animals/cow/cow_frames.tres"), "height": 64.0, "speed": 20.0, "radius": 12.0}
}

var herd: Node2D
var target: Vector2
var walking: bool = false
var speed: float
var body_radius: float
var spacing: float
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer

func _ready() -> void:
	idle_timer.timeout.connect(choose_target)

func configure(kind: String, group: Node2D) -> void:
	herd = group
	var data: Dictionary = APPEARANCE[kind]
	speed = data["speed"]
	body_radius = data["radius"]
	spacing = data["height"] * 0.8
	sprite.sprite_frames = data["frames"]
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture("idle_down", 0)
	sprite.scale = Vector2.ONE * data["height"] / frame.get_height()
	sprite.offset.y = -frame.get_height() / 2.0
	rest()

func rest() -> void:
	walking = false
	target = position
	sprite.animation = "idle_down"
	sprite.stop()
	idle_timer.start(randf_range(2.0, 5.0))

func choose_target() -> void:
	if not visible or herd.editing:
		rest()
		return
	var point: Vector2 = herd.find_position(self, true)
	if not point.is_finite() or position.distance_to(point) < 12.0:
		rest()
		return
	target = point
	walking = true
	idle_timer.stop()
	sprite.play("walk_down")

func _physics_process(delta: float) -> void:
	if not walking or herd.editing:
		return
	var next: Vector2 = position.move_toward(target, speed * delta)
	if not herd.is_position_valid(next, body_radius):
		rest()
		return
	if absf(next.x - position.x) > 0.01:
		sprite.flip_h = next.x < position.x
	position = next
	# Animals behind their home render behind its artwork, without changing
	# the building's placement footprint or collision layers.
	z_index = -2 if position.y < herd.ground_y else 0
	if position.distance_to(target) < 1.0:
		rest()
