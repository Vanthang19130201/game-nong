extends Label

@export var area_path: NodePath
@export var base_text: String = ""
@export var prompt_text: String = "[E]"
@export var zone_id: String = ""

func _process(_delta: float) -> void:
	var area: Area2D = get_node(area_path)
	var near: bool = false
	if area.monitoring:
		for body in area.get_overlapping_bodies():
			if body.is_in_group("farm_player"):
				near = true
	var prompt: String = tr(prompt_text)
	if zone_id != "" and not Inventory.is_zone_unlocked(zone_id):
		prompt = tr("WORLD_GATE_LOCKED")
	text = tr(base_text) + ("\n" + prompt if near else "")
