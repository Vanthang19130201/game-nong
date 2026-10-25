extends Area2D

func _ready() -> void:
	add_to_group("farm_interactables")
	body_exited.connect(_on_body_exited)
	Inventory.inventory_changed.connect(_update_access)
	_update_access()


func can_interact() -> bool:
	if not Inventory.is_zone_unlocked("fishing"):
		return false
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false


func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null and can_interact():
		hud.open_fish_market(self)


func _update_access() -> void:
	var unlocked: bool = Inventory.is_zone_unlocked("fishing")
	$Visuals.refresh()
	if not unlocked:
		_close_panel()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("farm_player"):
		_close_panel()


func _close_panel() -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null and hud.fish_market_panel.active_market == self:
		hud.fish_market_panel.close()
