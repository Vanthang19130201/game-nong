extends CharacterBody2D

@export var speed: float = 60.0
@export var wander_radius: float = 180.0
@export var home_point: Node2D
@export var wander_bounds: Rect2 = Rect2(50, 50, 2300, 1500)

var target: Vector2
var walking: bool = false
var fallback_center: Vector2
var rng := RandomNumberGenerator.new()

@onready var idle_timer: Timer = $IdleTimer
@onready var visual: Label = $Visual


func _ready() -> void:
	rng.randomize()
	fallback_center = global_position
	idle_timer.timeout.connect(_choose_target)
	_start_idle()


func _physics_process(delta: float) -> void:
	if not walking:
		return
	var offset: Vector2 = target - global_position
	if offset.length() <= speed * delta:
		global_position = target
		_start_idle()
		return
	velocity = offset.normalized() * speed
	move_and_slide()


func _choose_target() -> void:
	var center: Vector2 = home_point.global_position if is_instance_valid(home_point) else fallback_center
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = sqrt(rng.randf()) * wander_radius
	target = center + Vector2.from_angle(angle) * distance
	target = target.clamp(wander_bounds.position, wander_bounds.end)
	walking = true
	_update_visual()


func _start_idle() -> void:
	walking = false
	velocity = Vector2.ZERO
	idle_timer.start(rng.randf_range(2.0, 5.0))
	_update_visual()


func set_home_point(point: Node2D) -> void:
	home_point = point
	# Stop walking toward an old target when a Dog House is built.
	if global_position.distance_to(point.global_position) > wander_radius:
		global_position = point.global_position
	_start_idle()


func _update_visual() -> void:
	# Replace this Label with AnimatedSprite2D animations later.
	visual.text = "DOG >" if walking else "DOG"
