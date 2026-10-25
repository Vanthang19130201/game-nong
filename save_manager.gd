extends Node

const CropData = preload("res://crop_data.gd")
const SAVE_PATH: String = "user://save.cfg"
const TEMP_PATH: String = "user://save.cfg.tmp"
const PLOT_IDS: Array[String] = ["soil_1", "soil_2", "soil_3", "soil_4", "soil_5", "soil_6"]
const INVENTORY_DEFAULTS: Dictionary = {
	"wheat_seed": 10, "wheat": 0, "corn_seed": 0, "corn": 0,
	"carrot_seed": 0, "carrot": 0, "coins": 1000, "chicken_feed": 0, "egg": 0
}

var saved_plots: Dictionary = {}
var plots: Dictionary = {}
var resetting: bool = false
var stations: Dictionary = {}
var saved_stations: Dictionary = {}


func default_station(id: String) -> Dictionary:
	var data: Dictionary = {
		"state": "IDLE" if id == "feed_mill" else "HUNGRY",
		"production_type": "", "started_at": 0.0, "ready_at": 0.0
	}
	if id == "chicken_coop":
		data["chicken_count"] = 3
	return data


func register_station(station: Node) -> void:
	var id: String = station.station_id
	if id not in ["feed_mill", "chicken_coop"]:
		push_error("Unknown station ID: " + id)
		return
	if stations.has(id) and is_instance_valid(stations[id]):
		push_error("Duplicate station ID: " + id)
		return
	stations[id] = station
	station.restore_save_data(saved_stations[id])


func _ready() -> void:
	_load_game()
	Inventory.inventory_changed.connect(save_game)
	get_tree().auto_accept_quit = false


func register_plot(plot: Node) -> void:
	if plot.plot_id not in PLOT_IDS:
		push_error("Unknown SoilPlot ID: %s" % plot.plot_id)
		return
	if plots.has(plot.plot_id) and is_instance_valid(plots[plot.plot_id]):
		push_error("Duplicate SoilPlot ID: %s" % plot.plot_id)
		return
	plots[plot.plot_id] = plot
	plot.restore_save_data(saved_plots[plot.plot_id])


func empty_plot(id: String) -> Dictionary:
	return {
		"plot_id": id, "state": "EMPTY", "crop_type": "",
		"planted_at": 0.0, "ready_at": 0.0
	}


func save_game() -> bool:
	if resetting:
		return false
	var data := ConfigFile.new()
	data.set_value("game", "version", 3)
	for key in INVENTORY_DEFAULTS:
		data.set_value("inventory", key, Inventory.get(key))
	data.set_value("player", "player_exp", Inventory.player_exp)
	data.set_value("player", "player_level", Inventory.player_level)
	data.set_value("player", "selected_crop", Inventory.selected_crop)
	data.set_value("player", "has_dog", Inventory.has_dog)
	for id in ["feed_mill", "chicken_coop"]:
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
	if error == OK:
		error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(TEMP_PATH),
			ProjectSettings.globalize_path(SAVE_PATH)
		)
	if error != OK:
		push_warning("Could not save game. Error: %s" % error)
		return false
	saved_plots = snapshot
	for id in ["feed_mill", "chicken_coop"]:
		saved_stations[id] = _read_station(data, id)
	return true


func reset_game() -> bool:
	# If deleting the old save fails, leave the current game untouched.
	for path in [TEMP_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_warning("Could not delete save. Error: %s" % error)
				return false

	resetting = true
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, INVENTORY_DEFAULTS[key])
	Inventory.player_level = 1
	Inventory.player_exp = 0
	Inventory.selected_crop = "WHEAT"
	Inventory.has_dog = false
	for id in PLOT_IDS:
		saved_plots[id] = empty_plot(id)
		if plots.has(id) and is_instance_valid(plots[id]):
			# Restore also stops GrowTimer and clears the plant label.
			plots[id].restore_save_data(saved_plots[id])
	for id in ["feed_mill", "chicken_coop"]:
		saved_stations[id] = default_station(id)
		if stations.has(id) and is_instance_valid(stations[id]):
			stations[id].restore_save_data(saved_stations[id])
	# Update HUD once; save only after all inventory and plots are reset.
	Inventory.inventory_changed.emit()
	resetting = false
	return save_game()


func _load_game() -> void:
	var data := ConfigFile.new()
	var loaded: bool = false
	if FileAccess.file_exists(SAVE_PATH):
		loaded = data.load(SAVE_PATH) == OK
		if not loaded:
			push_warning("Invalid save file. Using defaults.")
			data = ConfigFile.new()
	# Missing or invalid fields use defaults; valid legacy values are kept.
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, _read_int(data, "inventory", key, INVENTORY_DEFAULTS[key]))
	Inventory.player_level = _read_int(data, "player", "player_level", 1, 1)
	Inventory.player_exp = _read_int(data, "player", "player_exp", 0)
	Inventory.normalize_exp()
	var selected = data.get_value("player", "selected_crop", "WHEAT")
	Inventory.selected_crop = "WHEAT"
	var owned = data.get_value("player", "has_dog", false)
	Inventory.has_dog = owned if owned is bool else false
	if selected is String and Inventory.is_unlocked(selected):
		Inventory.selected_crop = selected
	for id in PLOT_IDS:
		saved_plots[id] = _read_plot(data, id)
	for id in ["feed_mill", "chicken_coop"]:
		saved_stations[id] = _read_station(data, id)
	Inventory.inventory_changed.emit()
	if loaded:
		# Persist migration and crops that became ready while the game was closed.
		save_game.call_deferred()


func _read_int(data: ConfigFile, section: String, key: String, fallback: int, minimum: int = 0) -> int:
	var value = data.get_value(section, key, fallback)
	if value is int and value >= minimum:
		return value
	return fallback


func _read_station(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = default_station(id)
	if id == "chicken_coop":
		result["chicken_count"] = _read_int(data, id, "chicken_count", 3, 1)
	var state = data.get_value(id, "state", result["state"])
	if state not in ["PRODUCING", "READY"]:
		return result
	result["production_type"] = "CHICKEN_FEED" if id == "feed_mill" else "EGG"
	result["started_at"] = _read_time(data, id, "started_at", 0.0)
	result["ready_at"] = _read_time(data, id, "ready_at", 0.0)
	# Missing timestamps on a paid production become collectable, never lost.
	result["state"] = "READY" if state == "READY" or Time.get_unix_time_from_system() >= result["ready_at"] else "PRODUCING"
	return result


func _read_time(data: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value = data.get_value(section, key, fallback)
	if value is int or value is float:
		if is_finite(float(value)) and value >= 0.0:
			return float(value)
	return fallback


func _read_plot(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = empty_plot(id)
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
