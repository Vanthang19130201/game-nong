extends Node2D

func _ready() -> void:
	add_to_group("farm_interactables")
	queue_redraw()

func can_interact() -> bool:
	if not Inventory.has_dog_house:
		return false
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	return is_instance_valid(player) and player.global_position.distance_to(global_position) <= 86.0

func interact(_player: Node2D = null) -> void:
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud):
		hud.open_dog_house(self)


func _draw() -> void:
	# One small procedural bowl keeps the house readable without another asset.
	# It stays below the pets and uses the markers as the authoritative slots.
	draw_set_transform(Vector2(0, 50), 0.0, Vector2(13, 4))
	draw_circle(Vector2.ZERO, 1.0, Color("61372d"))
	draw_set_transform(Vector2(0, 49), 0.0, Vector2(10, 3))
	draw_circle(Vector2.ZERO, 1.0, Color("c7604c"))
	draw_set_transform(Vector2(0, 48), 0.0, Vector2(7, 2))
	draw_circle(Vector2.ZERO, 1.0, Color("e8ba69"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
