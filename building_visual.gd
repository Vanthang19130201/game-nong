extends Node2D

@export_enum("house", "feed_mill", "chicken_coop", "cow_shed", "fish_market") var building_kind: String = "house"

func refresh() -> void:
	var building = get_parent()
	match building_kind:
		"house":
			_refresh_prompt()
		"feed_mill":
			building.get_node("StatusLabel").text = "Feed Mill\n%s\n%s" % [building.production_type.capitalize(), building.state]
		"chicken_coop":
			building.get_node("StatusLabel").text = "CHICKENS: %d / %d\n%s" % [Inventory.chicken_count, Inventory.animal_capacity("chicken"), "EGGS READY" if building.state == "READY" else building.state]
		"cow_shed":
			building.get_node("StatusLabel").text = "COW SHED\nCows: %d / %d\n%s" % [Inventory.cow_count, Inventory.animal_capacity("cow"), "MILK READY" if building.state == "READY" else building.state]
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
		label.text = "[E] House" if near else ""
		label.visible = near
	else:
		building.get_node("Label").text = "Fish Market\n[E] Sell Fish" if near else "Fish Market"
