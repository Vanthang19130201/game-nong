extends CharacterBody2D

var active_resource: Node = null
var mouse_interaction: Node

@export var speed: float = 200.0
@export var farm_bounds: Rect2 = Rect2(50, 50, 2300, 2300)
@onready var hud: Node = get_tree().get_first_node_in_group("farm_hud")


func _ready() -> void:
	add_to_group("farm_player")
	mouse_interaction = Node.new()
	mouse_interaction.name = "WorldMouseInteraction"
	mouse_interaction.set_script(preload("res://world_mouse_interaction.gd"))
	add_child(mouse_interaction)
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)
	$Camera2D.reset_smoothing()

func _physics_process(_delta):
	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	if is_instance_valid(hud) and hud.blocks_world_input() and not hud.edit_farm.active:
		direction = Vector2.ZERO

	velocity = direction * speed
	move_and_slide()
	# Leave a 50-pixel margin between the player and each edge of the map.
	global_position = global_position.clamp(farm_bounds.position, farm_bounds.end)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(hud) and hud.edit_farm.active:
			hud.edit_farm.click_world(event.position)
		else:
			interact_at_screen_position(event.position)
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	try_interact()


# Mouse clicks (and future mobile taps) use the same dispatcher as E.
func interact_at_screen_position(screen_position: Vector2) -> void:
	if (is_instance_valid(hud) and hud.blocks_world_input()) or is_instance_valid(active_resource):
		return
	var world_position: Vector2 = get_canvas_transform().affine_inverse() * screen_position
	var target: Node2D = mouse_interaction.target_at(world_position)
	if target != null:
		try_interact(target)
	else:
		var zone = mouse_interaction.land_at(world_position)
		if zone != null:
			hud.open_land_purchase(zone.zone_id)
	mouse_interaction.clear_hover()


func can_interact_with(target: Node) -> bool:
	if not is_instance_valid(target) or not target.is_in_group("farm_interactables") or not target.is_visible_in_tree():
		return false
	if (is_instance_valid(hud) and hud.blocks_world_input()) or is_instance_valid(active_resource):
		return false
	if is_instance_valid(hud) and is_instance_valid(hud.fishing_ui.active_spot):
		return target == hud.fishing_ui.active_spot and target.state in [target.State.WAITING_FOR_BITE, target.State.BITE_WINDOW]
	return target.can_interact()


func try_interact(target: Node = null) -> void:
	if is_instance_valid(hud) and hud.blocks_world_input():
		return
	if target == null and is_instance_valid(hud) and hud.fishing_ui.handle_interact():
		return
	if is_instance_valid(active_resource):
		return
	if target == null:
		target = _nearest_interactable()
	if not can_interact_with(target):
		return
	if is_instance_valid(hud) and hud.fishing_ui.active_spot == target:
		hud.fishing_ui.handle_interact()
	else:
		target.interact(self)


func _nearest_interactable() -> Node2D:
	# A single dispatcher chooses one nearby target, regardless of scene order.
	var nearest: Node2D = null
	var best_distance: float = INF
	for candidate in get_tree().get_nodes_in_group("farm_interactables"):
		if can_interact_with(candidate):
			var target_position: Vector2 = candidate.get_interaction_position() if candidate.has_method("get_interaction_position") else candidate.global_position
			var distance: float = global_position.distance_squared_to(target_position)
			if distance < best_distance:
				best_distance = distance
				nearest = candidate
	return nearest
