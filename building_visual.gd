extends Node2D

@export_enum("house", "feed_mill", "chicken_coop", "cow_shed", "fish_market") var building_kind: String = "house"

func refresh() -> void:
	var building = get_parent()
	match building_kind:
		"house":
			_refresh_prompt()
		"feed_mill":
			building.get_node("StatusLabel").text = (tr("WORLD_MILL_STATUS") % [Localization.state(building.state), Localization.display_name(building.production_type)]).strip_edges()
		"chicken_coop":
			building.get_node("StatusLabel").text = tr("WORLD_CHICKEN_STATUS") % [Inventory.chicken_count, Inventory.animal_capacity("chicken"), tr("WORLD_EGGS_READY") if building.state == "READY" else Localization.state(building.state)]
		"cow_shed":
			building.get_node("StatusLabel").text = tr("WORLD_COW_STATUS") % [Inventory.cow_count, Inventory.animal_capacity("cow"), tr("WORLD_MILK_READY") if building.state == "READY" else Localization.state(building.state)]
		"fish_market":
			_refresh_prompt()


func _process(_delta: float) -> void:
	if building_kind in ["house", "fish_market"]:
		_refresh_prompt()


func _refresh_prompt() -> void:
	var building = get_parent()
	var near: bool = building.can_interact()
	if building_kind == "house":
		var label: Label = building.get_node("HouseLabel")
		label.text = tr("WORLD_HOUSE_PROMPT") if near else ""
		label.visible = near
	else:
		building.get_node("Label").text = tr("TITLE_FISH_MARKET")
		building.get_node("InteractionPrompt").text = tr("PRODUCTION_INTERACT") if near else ""
