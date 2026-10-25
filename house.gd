extends Node2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var house_label: Label = $HouseLabel


func _ready() -> void:
	add_to_group("farm_interactables")
	interaction_area.body_exited.connect(_on_body_exited)
	Inventory.inventory_changed.connect(_update_visual)
	_update_visual()


func can_interact() -> bool:
	for body in interaction_area.get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false


func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	var player = get_tree().get_first_node_in_group("farm_player")
	if not can_interact() or hud == null or hud.blocks_world_input():
		return
	if player != null and is_instance_valid(player.active_resource):
		return
	hud.open_house(self)


func _update_visual() -> void:
	$Visuals.refresh()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("farm_player"):
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.active_house == self:
			hud.close_house()
