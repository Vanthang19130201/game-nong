extends CharacterBody2D

var active_resource: Node = null

@export var speed: float = 200.0
@export var farm_bounds: Rect2 = Rect2(50, 50, 2300, 1500)
@onready var hud: Node = get_tree().get_first_node_in_group("farm_hud")


func _ready() -> void:
	add_to_group("farm_player")
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)
	$Camera2D.reset_smoothing()

func _physics_process(_delta):
	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if is_instance_valid(hud) and hud.blocks_world_input():
		direction = Vector2.ZERO

	velocity = direction * speed
	move_and_slide()
	# Leave a 50-pixel margin between the player and each edge of the map.
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if is_instance_valid(hud) and hud.blocks_world_input():
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(active_resource):
		return
	# A single dispatcher chooses one nearby target, regardless of scene order.
	var nearest: Node2D = null
	var best_distance: float = INF
	for candidate in get_tree().get_nodes_in_group("farm_interactables"):
		if candidate.can_interact():
			var distance: float = global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				nearest = candidate
	if nearest != null:
		nearest.interact()