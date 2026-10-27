extends Area2D

func _ready() -> void:
	add_to_group("farm_interactables")
	body_entered.connect(_update_prompt)
	body_exited.connect(_on_body_exited)
	_update_prompt()

func can_interact() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false

func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if can_interact() and hud != null and not hud.blocks_world_input():
		hud.open_market_stall(self)

func _update_prompt(_body: Node2D = null) -> void:
	$Visuals/Prompt.text = tr("STALL_PROMPT") if can_interact() else tr("BUILDING_MARKET_STALL")

func _on_body_exited(body: Node2D) -> void:
	_update_prompt()
	if body.is_in_group("farm_player"):
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.market_stall_panel.active_stall == self:
			hud.market_stall_panel.close()
