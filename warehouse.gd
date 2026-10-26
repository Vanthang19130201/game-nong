extends Area2D

func _ready() -> void:
	add_to_group("farm_interactables")

func can_interact() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false

func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if can_interact() and hud != null and not hud.blocks_world_input():
		hud.open_warehouse(self)
