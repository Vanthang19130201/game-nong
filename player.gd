extends CharacterBody2D

@export var speed: float = 200.0
@export var farm_bounds: Rect2 = Rect2(50, 50, 2300, 1500)


func _ready() -> void:
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)
	$Camera2D.reset_smoothing()

func _physics_process(_delta):
	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()
	# Leave a 50-pixel margin between the player and each edge of the map.
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)
