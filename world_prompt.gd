extends Label

@export var area_path: NodePath
@export var base_text: String = ""
@export var prompt_text: String = "[E]"
@export var zone_id: String = ""
@export var separate_prompt_path: NodePath

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
	var separate_prompt := get_node_or_null(separate_prompt_path) if not separate_prompt_path.is_empty() else null
	if separate_prompt is Label:
		text = tr(base_text)
		separate_prompt.text = prompt if near else ""
	else:
		var title: String = tr(base_text) if not base_text.is_empty() else ""
		text = title + (("\n" if not title.is_empty() else "") + prompt if near else "")
