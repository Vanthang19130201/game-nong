extends Node2D

func _ready() -> void:
	add_to_group("farm_interactables")
	queue_redraw()

func can_interact() -> bool:
	if not Inventory.has_dog_house:
		return false
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	return is_instance_valid(player) and player.global_position.distance_to(global_position) <= 132.0

func interact(_player: Node2D = null) -> void:
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud):
		hud.open_dog_house(self)


func _draw() -> void:
	# Three small bowls mirror the three stable food markers. They remain
	# runtime decoration only; feeding logic still uses the markers above.
	for bowl in [Vector2(-64, 88), Vector2(0, 92), Vector2(64, 88)]:
		draw_set_transform(bowl, 0.0, Vector2(11, 3.5))
		draw_circle(Vector2.ZERO, 1.0, Color("61372d"))
		draw_set_transform(bowl + Vector2(0, -1), 0.0, Vector2(8, 2.5))
		draw_circle(Vector2.ZERO, 1.0, Color("c7604c"))
		draw_set_transform(bowl + Vector2(0, -2), 0.0, Vector2(5, 1.5))
		draw_circle(Vector2.ZERO, 1.0, Color("e8ba69"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
