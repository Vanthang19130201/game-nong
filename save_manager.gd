extends Node

const FarmData = preload("res://farm_data.gd")
const CropData = preload("res://crop_data.gd")
const Progression = preload("res://progression_data.gd")
const RESOURCE_IDS: Array[String] = ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "rock_1", "rock_2", "rock_3"]
const STATION_IDS: Array[String] = ["feed_mill", "chicken_coop", "cow_shed"]
const SAVE_PATH: String = "user://save.cfg"
const TEMP_PATH: String = "user://save.cfg.tmp"
const BACKUP_PATH: String = "user://save_backup.cfg"
const BACKUP_TEMP_PATH: String = "user://save_backup.cfg.tmp"
var PLOT_IDS: Array[String] = FarmData.plot_ids()
const INVENTORY_DEFAULTS: Dictionary = {
	"wheat_seed": 10, "wheat": 0, "corn_seed": 0, "corn": 0,
	"carrot_seed": 0, "carrot": 0, "coins": 100, "chicken_feed": 0, "cow_feed": 0, "egg": 0, "milk": 0, "wood": 0, "stone": 0
}

var saved_plots: Dictionary = {}
var plots: Dictionary = {}
var resetting: bool = false
var stations: Dictionary = {}
var saved_stations: Dictionary = {}
var resources: Dictionary = {}
var saved_resources: Dictionary = {}
var buildings: Dictionary = {}
var building_positions: Dictionary = {}


func register_building(id: String, building: Node2D) -> bool:
	if not FarmData.BUILDINGS.has(id):
		push_error("Unknown building ID: " + id)
		return false
	if buildings.has(id) and is_instance_valid(buildings[id]):
		if buildings[id] != building:
			push_error("Duplicate building ID: " + id)
			return false
		return true
	buildings[id] = building
	building.position = building_positions.get(id, FarmData.BUILDINGS[id]["position"])
	return true


func default_station(id: String) -> Dictionary:
	var data: Dictionary = {
		"state": "IDLE" if id == "feed_mill" else "HUNGRY",
		"production_type": "", "started_at": 0.0, "ready_at": 0.0
	}
	if id == "chicken_coop":
		data["chicken_count"] = Inventory.chicken_count
	elif id == "cow_shed":
		data["cow_count"] = Inventory.cow_count
	return data


func register_station(station: Node) -> bool:
	var id: String = station.station_id
	if id not in STATION_IDS:
		push_error("Unknown station ID: " + id)
		return false
	if stations.has(id) and is_instance_valid(stations[id]):
		push_error("Duplicate station ID: " + id)
		return false
	stations[id] = station
	station.restore_save_data(saved_stations[id])
	return true


func _ready() -> void:
	_load_game()
	Inventory.inventory_changed.connect(save_game)
	get_tree().auto_accept_quit = false


func register_plot(plot: Node) -> bool:
	if plot.plot_id not in PLOT_IDS:
		push_error("Unknown SoilPlot ID: %s" % plot.plot_id)
		return false
	if plots.has(plot.plot_id) and is_instance_valid(plots[plot.plot_id]):
		push_error("Duplicate SoilPlot ID: %s" % plot.plot_id)
		return false
	plots[plot.plot_id] = plot
	plot.restore_save_data(saved_plots[plot.plot_id])
	return true


func empty_plot(id: String) -> Dictionary:
	return {
		"plot_id": id, "unlocked": FarmData.plot_number(id) <= Inventory.unlocked_plot_count, "state": "EMPTY", "crop_type": "",
		"planted_at": 0.0, "ready_at": 0.0
	}


func save_game() -> bool:
	if resetting:
		return false
	var data := ConfigFile.new()
	data.set_value("game", "version", 9)
	for id in FarmData.BUILDINGS:
		var position: Vector2 = building_positions.get(id, FarmData.BUILDINGS[id]["position"])
		if buildings.has(id) and is_instance_valid(buildings[id]):
			position = buildings[id].position
		if not FarmData.valid_building_position(position):
			push_warning("Invalid building position, using default: " + id)
			position = FarmData.BUILDINGS[id]["position"]
			if buildings.has(id) and is_instance_valid(buildings[id]):
				buildings[id].position = position
		building_positions[id] = position
		data.set_value("building_positions", id, position)
	data.set_value("farm", "unlocked_plot_count", Inventory.unlocked_plot_count)
	data.set_value("zones", "fishing_unlocked", Inventory.fishing_unlocked)
	data.set_value("orders", "active", OrderManager.orders)
	data.set_value("orders", "next_id", OrderManager.next_order_id)
	for key in INVENTORY_DEFAULTS:
		data.set_value("inventory", key, Inventory.get(key))
	data.set_value("player", "player_exp", Inventory.player_exp)
	data.set_value("player", "player_level", Inventory.player_level)
	data.set_value("player", "selected_crop", Inventory.selected_crop)
	data.set_value("player", "has_dog", Inventory.has_dog)
	for id in Inventory.ToolData.TOOLS:
		data.set_value("tools", "has_" + id, Inventory.get("has_" + id))
		data.set_value("tools", id + "_level", Inventory.get(id + "_level"))
	data.set_value("tools", "unlock_notified", Inventory.tools_unlock_notified)
	data.set_value("buildings", "has_dog_house", Inventory.has_dog_house)
	for id in Progression.UPGRADES:
		data.set_value("upgrades", id + "_level", Inventory.get(id + "_level"))
	var resource_snapshot: Dictionary = {}
	for id in RESOURCE_IDS:
		var resource_data: Dictionary = saved_resources.get(id, {"state": "AVAILABLE", "respawn_at": 0.0})
		if resources.has(id) and is_instance_valid(resources[id]):
			resource_data = resources[id].get_save_data()
		resource_snapshot[id] = resource_data
		data.set_value("resources", id, resource_data)
	data.set_value("storage", "silo_capacity", Inventory.silo_capacity)
	data.set_value("storage", "barn_capacity", Inventory.barn_capacity)
	for id in STATION_IDS:
		data.set_value("buildings", "owns_" + id, Inventory.owns_building(id))
	data.set_value("animals", "chicken_count", Inventory.chicken_count)
	data.set_value("animals", "cow_count", Inventory.cow_count)
	for id in STATION_IDS:
		var station_data: Dictionary = saved_stations.get(id, default_station(id))
		if stations.has(id) and is_instance_valid(stations[id]):
			station_data = stations[id].get_save_data()
		for key in station_data:
			data.set_value(id, key, station_data[key])
	var snapshot: Dictionary = {}
	for id in PLOT_IDS:
		# Preserve unloaded plots too, including during scene initialization.
		var plot_data: Dictionary = saved_plots.get(id, empty_plot(id))
		if plots.has(id) and is_instance_valid(plots[id]):
			plot_data = plots[id].get_save_data()
		snapshot[id] = plot_data
		for key in plot_data:
			data.set_value(id, key, plot_data[key])

	# Replace the old file only after the complete new snapshot is written.
	var error := data.save(TEMP_PATH)
	# Rotate only a parseable main save. Never overwrite a good backup with corrupt text.
	if error == OK and FileAccess.file_exists(SAVE_PATH):
		var previous := ConfigFile.new()
		if previous.load(SAVE_PATH) == OK:
			error = previous.save(BACKUP_TEMP_PATH)
			if error == OK:
				error = DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_TEMP_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	if error == OK:
		error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(TEMP_PATH),
			ProjectSettings.globalize_path(SAVE_PATH)
		)
	if error != OK:
		push_warning("Could not save game. Error: %s" % error)
		return false
	saved_plots = snapshot
	saved_resources = resource_snapshot
	for id in STATION_IDS:
		saved_stations[id] = _read_station(data, id)
	return true


func reset_game() -> bool:
	# If deleting the old save fails, leave the current game untouched.
	for path in [TEMP_PATH, BACKUP_TEMP_PATH, BACKUP_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_warning("Could not delete save. Error: %s" % error)
				return false

	resetting = true
	building_positions.clear()
	for id in FarmData.BUILDINGS:
		building_positions[id] = FarmData.BUILDINGS[id]["position"]
		if buildings.has(id) and is_instance_valid(buildings[id]):
			buildings[id].position = building_positions[id]
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, INVENTORY_DEFAULTS[key])
	Inventory.player_level = 1
	Inventory.unlocked_plot_count = FarmData.STARTING_PLOTS
	Inventory.fishing_unlocked = false
	Inventory.player_exp = 0
	Inventory.selected_crop = "WHEAT"
	Inventory.has_dog = false
	Inventory.has_dog_house = false
	Inventory.has_axe = false
	Inventory.has_hammer = false
	Inventory.axe_level = 0
	Inventory.hammer_level = 0
	Inventory.tools_unlock_notified = false
	for id in Progression.UPGRADES:
		Inventory.set(id + "_level", 1)
	for id in RESOURCE_IDS:
		saved_resources[id] = {"state": "AVAILABLE", "respawn_at": 0.0}
		if resources.has(id) and is_instance_valid(resources[id]):
			resources[id].restore_save_data(saved_resources[id])
	Inventory.silo_capacity = 30
	Inventory.barn_capacity = 20
	Inventory.chicken_count = 0
	Inventory.cow_count = 0
	for id in STATION_IDS:
		Inventory.set("owns_" + id, false)
	OrderManager.reset_orders()
	for id in PLOT_IDS:
		saved_plots[id] = empty_plot(id)
		if plots.has(id) and is_instance_valid(plots[id]):
			# Restore also stops GrowTimer and clears the plant label.
			plots[id].restore_save_data(saved_plots[id])
	for id in STATION_IDS:
		saved_stations[id] = default_station(id)
		if stations.has(id) and is_instance_valid(stations[id]):
			stations[id].restore_save_data(saved_stations[id])
	# Update HUD once; save only after all inventory and plots are reset.
	Inventory.inventory_changed.emit()
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.close_all_panels()
	resetting = false
	return save_game()


func _load_game() -> void:
	var data := ConfigFile.new()
	var loaded: bool = false
	if FileAccess.file_exists(SAVE_PATH):
		loaded = data.load(SAVE_PATH) == OK
		if not loaded:
			push_warning("Main save is unreadable; trying backup.")
			data = ConfigFile.new()
	if not loaded and FileAccess.file_exists(BACKUP_PATH):
		loaded = data.load(BACKUP_PATH) == OK
		if not loaded:
			push_warning("Backup save is unreadable; using safe defaults.")
			data = ConfigFile.new()
	for id in FarmData.BUILDINGS:
		var position = data.get_value("building_positions", id, FarmData.BUILDINGS[id]["position"])
		if not FarmData.valid_building_position(position):
			push_warning("Invalid saved building position: " + id)
			position = FarmData.BUILDINGS[id]["position"]
		building_positions[id] = position
	# Missing or invalid fields use defaults; valid legacy values are kept.
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, _read_int(data, "inventory", key, INVENTORY_DEFAULTS[key]))
	Inventory.player_level = _read_int(data, "player", "player_level", 1, 1)
	Inventory.player_exp = _read_int(data, "player", "player_exp", 0)
	Inventory.unlocked_plot_count = clampi(_read_int(data, "farm", "unlocked_plot_count", FarmData.STARTING_PLOTS), FarmData.STARTING_PLOTS, FarmData.MAX_PLOTS)
	var fishing = data.get_value("zones", "fishing_unlocked", false)
	Inventory.fishing_unlocked = fishing if fishing is bool and Inventory.player_level >= FarmData.FISHING_LEVEL else false
	for id in Inventory.ToolData.TOOLS:
		var owned_tool = data.get_value("tools", "has_" + id, false)
		Inventory.set("has_" + id, owned_tool if owned_tool is bool else false)
		Inventory.set(id + "_level", mini(4, _read_int(data, "tools", id + "_level", 0)))
		if Inventory.get("has_" + id):
			Inventory.set(id + "_level", maxi(1, Inventory.get(id + "_level")))
		else:
			Inventory.set(id + "_level", 0)
	var notified = data.get_value("tools", "unlock_notified", false)
	Inventory.tools_unlock_notified = notified if notified is bool else false
	Inventory.normalize_exp()
	for id in Progression.UPGRADES:
		var max_level: int = Progression.UPGRADES[id].size() + 1
		Inventory.set(id + "_level", mini(max_level, _read_int(data, "upgrades", id + "_level", 1, 1)))
	var dog_house = data.get_value("buildings", "has_dog_house", false)
	Inventory.has_dog_house = dog_house if dog_house is bool else false
	for id in RESOURCE_IDS:
		saved_resources[id] = _read_resource(data.get_value("resources", id, 0.0))
	Inventory.silo_capacity = _read_int(data, "storage", "silo_capacity", 30, 1)
	Inventory.barn_capacity = _read_int(data, "storage", "barn_capacity", 20, 1)
	for storage in ["silo", "barn"]:
		var level: int = Inventory.get(storage + "_level")
		if level > 1:
			var capacity: int = Progression.UPGRADES[storage][level]["capacity"]
			Inventory.set(storage + "_capacity", maxi(Inventory.get(storage + "_capacity"), capacity))
	var legacy: bool = _read_int(data, "game", "version", 0) < 5
	for id in STATION_IDS:
		# Previously these buildings were free. Keep them on existing farms.
		var owned_default: bool = legacy and data.has_section(id) and id != "cow_shed"
		var owned_building = data.get_value("buildings", "owns_" + id, owned_default)
		Inventory.set("owns_" + id, owned_building if owned_building is bool else false)
	var old_chickens: int = _read_int(data, "chicken_coop", "chicken_count", 0)
	Inventory.chicken_count = clampi(_read_int(data, "animals", "chicken_count", old_chickens), 0, Inventory.animal_capacity("chicken"))
	Inventory.cow_count = clampi(_read_int(data, "animals", "cow_count", 0), 0, Inventory.animal_capacity("cow"))
	if not Inventory.owns_chicken_coop:
		Inventory.chicken_count = 0
	if not Inventory.owns_cow_shed:
		Inventory.cow_count = 0
	var selected = data.get_value("player", "selected_crop", "WHEAT")
	Inventory.selected_crop = "WHEAT"
	var owned = data.get_value("player", "has_dog", false)
	Inventory.has_dog = owned if owned is bool else false
	if selected is String and Inventory.is_unlocked(selected):
		Inventory.selected_crop = selected
	for id in PLOT_IDS:
		saved_plots[id] = _read_plot(data, id)
		# Never lock a saved crop, even if an old save omitted the farm count.
		if saved_plots[id]["state"] != "EMPTY" or saved_plots[id]["unlocked"]:
			Inventory.unlocked_plot_count = maxi(Inventory.unlocked_plot_count, FarmData.plot_number(id))
	for id in PLOT_IDS:
		saved_plots[id]["unlocked"] = FarmData.plot_number(id) <= Inventory.unlocked_plot_count
	for id in STATION_IDS:
		saved_stations[id] = _read_station(data, id)
	OrderManager.restore_orders(
		data.get_value("orders", "active", []),
		_read_int(data, "orders", "next_id", 1, 1)
	)
	Inventory.inventory_changed.emit()
	# Also persist newly generated orders for old saves and brand-new games.
	save_game.call_deferred()


func _read_int(data: ConfigFile, section: String, key: String, fallback: int, minimum: int = 0) -> int:
	var value = data.get_value(section, key, fallback)
	if value is int and value >= minimum:
		return mini(value, 2147483647)
	if data.has_section_key(section, key):
		push_warning("Invalid save field: [%s] %s. Using default." % [section, key])
	return fallback


func _read_station(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = default_station(id)
	if not Inventory.owns_building(id):
		return result
	var state = data.get_value(id, "state", result["state"])
	if state not in ["PRODUCING", "READY"]:
		return result
	var production = data.get_value(id, "production_type", "CHICKEN_FEED" if id == "feed_mill" else "EGG")
	if id == "feed_mill":
		result["production_type"] = production if production in ["CHICKEN_FEED", "COW_FEED"] else "CHICKEN_FEED"
	else:
		result["production_type"] = "EGG" if id == "chicken_coop" else "MILK"
		var count: int = Inventory.chicken_count if id == "chicken_coop" else Inventory.cow_count
		if count <= 0:
			return default_station(id)
	result["started_at"] = _read_time(data, id, "started_at", 0.0)
	result["ready_at"] = _read_time(data, id, "ready_at", 0.0)
	if state == "PRODUCING" and (result["ready_at"] <= 0.0 or result["ready_at"] < result["started_at"]):
		push_warning("Invalid production timestamps: " + id)
		return default_station(id)
	result["state"] = "READY" if state == "READY" or Time.get_unix_time_from_system() >= result["ready_at"] else "PRODUCING"
	return result

func _read_time(data: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value = data.get_value(section, key, fallback)
	if value is int or value is float:
		if is_finite(float(value)) and value >= 0.0 and value <= 1000000000000.0:
			return float(value)
	return fallback


func _read_plot(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = empty_plot(id)
	var legacy_id: String = "soil_%d" % FarmData.plot_number(id)
	if not data.has_section(id) and data.has_section(legacy_id):
		id = legacy_id
	var unlocked = data.get_value(id, "unlocked", result["unlocked"])
	result["unlocked"] = unlocked if unlocked is bool else result["unlocked"]
	var saved_state = data.get_value(id, "state", "EMPTY")
	if saved_state not in ["GROWING", "READY"]:
		return result
	# Older saves only contained Wheat and may have no crop_type.
	var crop = data.get_value(id, "crop_type", "WHEAT")
	if not (crop is String) or not CropData.CROPS.has(crop):
		crop = "WHEAT"
	var now: float = Time.get_unix_time_from_system()
	var duration: float = CropData.CROPS[crop]["grow_time"]
	var planted: float = _read_time(data, id, "planted_at", -1.0)
	var ready: float = _read_time(data, id, "ready_at", -1.0)
	if planted < 0.0 or ready < planted:
		# One-time migration of the old timer-based save; new saves use timestamps.
		var old_remaining: float = _read_time(data, id, "time_left", 0.0)
		ready = now + minf(old_remaining, duration) if saved_state == "GROWING" else now
		planted = ready - duration
	result["crop_type"] = crop
	result["planted_at"] = planted
	result["ready_at"] = ready
	result["state"] = "READY" if saved_state == "READY" or now >= ready else "GROWING"
	return result


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func register_resource(resource: Node) -> bool:
	var id: String = resource.resource_id
	if id not in RESOURCE_IDS:
		push_error("Unknown resource ID: " + id)
		return false
	if resources.has(id) and is_instance_valid(resources[id]):
		push_error("Duplicate resource ID: " + id)
		return false
	resources[id] = resource
	resource.restore_save_data(saved_resources.get(id, {"state": "AVAILABLE", "respawn_at": 0.0}))
	return true
func _read_resource(value: Variant) -> Dictionary:
	# Version 6 stored a timestamp directly. Version 7 stores state + respawn_at.
	var timestamp = value.get("respawn_at", 0.0) if value is Dictionary else value
	if not (timestamp is float or timestamp is int):
		timestamp = 0.0
	if not is_finite(float(timestamp)) or timestamp < 0.0:
		timestamp = 0.0
	var zone = value.get("zone_id", "main") if value is Dictionary else "main"
	return {"state": "DEPLETED" if timestamp > 0.0 else "AVAILABLE", "respawn_at": float(timestamp), "zone_id": zone if zone is String else "main"}
