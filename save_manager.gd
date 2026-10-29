extends Node

signal selected_character_changed
signal player_name_changed
signal dog_fed(pet_id: String)
signal dog_greeted(pet_id: String)
var player_name: String = ""
const CharacterData = preload("res://character_data.gd")
var selected_character_id: String = CharacterData.DEFAULT_ID
var has_existing_game: bool = false
var character_selection_pending: bool = false

func set_selected_character(id: String, persist: bool = true) -> bool:
	var validated := CharacterData.valid_id(id)
	if selected_character_id != validated:
		selected_character_id = validated
		selected_character_changed.emit()
	return save_game() if persist else true

func start_new_game(character_id: String, new_player_name: String) -> bool:
	var clean_name := new_player_name.strip_edges()

	if clean_name.is_empty():
		return false

	if clean_name.length() > 16:
		clean_name = clean_name.left(16)

	if not reset_game():
		return false

	character_selection_pending = false
	has_existing_game = true

	player_name = clean_name
	player_name_changed.emit()

	if not set_selected_character(character_id, false):
		return false

	return save_game()


func reset_for_character_selection() -> bool:
	if not reset_game():
		return false

	character_selection_pending = true
	has_existing_game = false
	player_name = ""
	player_name_changed.emit()

	return save_game()

const FarmData = preload("res://farm_data.gd")
const CropData = preload("res://crop_data.gd")
const Progression = preload("res://progression_data.gd")
const LandData = preload("res://land_data.gd")
const DecorationData = preload("res://decoration_data.gd")
const RockData = preload("res://rock_data.gd")
const FeedData = preload("res://feed_mill_data.gd")
const LoomData = preload("res://loom_data.gd")
const AnimalData = preload("res://animal_data.gd")
const DogData = preload("res://dog_data.gd")
var placed_decorations: Array = []
var next_decoration_id: int = 1
var unlocked_land_zones: Array[String] = ["farm_core"]
const RESOURCE_IDS: Array[String] = [
	"tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "tree_6", "tree_7", "tree_8",
	"rock_1", "rock_2", "rock_3", "rock_4",
	"tree_south_01", "tree_south_02", "tree_south_03", "tree_south_04",
	"tree_south_05", "tree_south_06", "tree_south_07", "tree_south_08",
	"forest_tree_01", "forest_tree_02", "forest_tree_03", "forest_tree_04",
	"forest_tree_05", "forest_tree_06", "forest_tree_07", "forest_tree_08",
	"forest_tree_09", "forest_tree_10", "forest_tree_11", "forest_tree_12",
	"farm_tree_01", "farm_tree_02", "farm_tree_03", "farm_tree_04",
	"rock_south_01", "rock_south_02", "rock_south_03", "rock_south_04", "rock_south_05", "rock_south_06"
]
const STATION_IDS: Array[String] = ["feed_mill", "chicken_coop", "cow_shed", "pig_pen", "sheep_barn"]
const SAVE_PATH: String = "user://save.cfg"
const TEMP_PATH: String = "user://save.cfg.tmp"
const BACKUP_PATH: String = "user://save_backup.cfg"
const BACKUP_TEMP_PATH: String = "user://save_backup.cfg.tmp"
const AUTOSAVE_INTERVAL: float = 30.0
var autosave_timer: Timer
var bakery_queue: Array = []
var dairy_queue: Array = []
var spinning_machine_queue: Array = []
var loom_queue: Array = []
var animal_rosters: Dictionary = {"chicken": [], "cow": [], "pig": [], "sheep": []}
var next_animal_ids: Dictionary = {"chicken": 1, "cow": 1, "pig": 1, "sheep": 1}
# Primitive, save-safe pet profiles. Runtime Dog nodes are reconstructed by Farm.
var pet_dogs: Dictionary = {}
var saved_dig_spots: Array = []
var saved_dig_spots_day_key: int = -1
var hidden_treasure_claimed: bool = false
# Only a catch that has succeeded but could not enter a full Barn is stored
# here. This must never represent a cast, a miss, or a cancelled session.
var pending_fishing_reward: Dictionary = {}
var pending_fishing_reward_claimable: bool = false
# Monotonic nonce for deterministic Coin Pouch / Small Chest openings.
var treasure_open_sequence: int = 0
var _removed_fish_migration_pending: bool = false
var PLOT_IDS: Array[String] = FarmData.plot_ids()
var INVENTORY_DEFAULTS: Dictionary = CropData.inventory_defaults().merged({
	"coins": 500, "chicken_feed": 0, "cow_feed": 0, "pig_feed": 0, "sheep_feed": 0, "dog_food": 0, "egg": 0, "milk": 0, "pork": 0, "wool": 0, "wool_yarn": 0, "cotton_cloth": 0, "wool_cloth": 0, "meat_pie": 0, "wood": 0, "stone": 0,
	"tilapia": 0, "perch": 0, "catfish": 0, "loach": 0, "snakehead": 0, "salmon": 0, "koi_orange": 0, "koi_gold": 0, "moon_fish": 0,
	"old_bottle": 0, "old_boot": 0, "coin_pouch": 0, "small_chest": 0, "lost_lure": 0, "ancient_coin": 0, "map_fragment": 0, "ancient_gem": 0,
	"bread": 0, "corn_bread": 0, "carrot_pie": 0,
	"egg_cake": 0, "milk_cake": 0, "pancake": 0,
	"cream": 0, "butter": 0, "cheese": 0, "cotton_thread": 0
})

var saved_plots: Dictionary = {}
var plots: Dictionary = {}
var resetting: bool = false
var stations: Dictionary = {}
var saved_stations: Dictionary = {}
var resources: Dictionary = {}
var saved_resources: Dictionary = {}
var buildings: Dictionary = {}
var building_positions: Dictionary = {}

func animal_records(animal_type: String) -> Array:
	return animal_rosters.get(animal_type, [])

func dog_profiles() -> Dictionary:
	return pet_dogs.duplicate(true)

func dog_profile(pet_id: String) -> Dictionary:
	return pet_dogs.get(pet_id, {}).duplicate(true)

func dog_hunger(pet_id: String) -> float:
	return clampf(float(pet_dogs.get(pet_id, {}).get("hunger", 100.0)), 0.0, 100.0)

func adopt_dog(variant_id: String) -> bool:
	if not DogData.is_variant_enabled(variant_id):
		return false
	var pet_id := DogData.pet_id_for_variant(variant_id)
	if pet_id.is_empty() or pet_dogs.has(pet_id) or not Inventory.has_dog_house:
		return false
	var data: Dictionary = DogData.DOG_VARIANTS[variant_id]
	if Inventory.player_level < int(data.get("unlock_level", 1)):
		return false
	var price: int = int(data["price"])
	if Inventory.coins < price:
		return false
	var previous_coins: int = Inventory.coins
	Inventory.coins -= price
	pet_dogs[pet_id] = DogData.default_profile(variant_id)
	Inventory.has_dog = true # legacy compatibility mirrors pet ownership.
	if not save_game():
		pet_dogs.erase(pet_id)
		Inventory.coins = previous_coins
		Inventory.has_dog = not pet_dogs.is_empty()
		return false
	Inventory.inventory_changed.emit()
	return true

func rename_dog(pet_id: String, requested_name: String) -> bool:
	if not pet_dogs.has(pet_id):
		return false
	var profile: Dictionary = pet_dogs[pet_id]
	var fallback := str(DogData.variant_for_pet(pet_id).get("default_name", "Dog"))
	var name := DogData.normalized_name(requested_name, "")
	if name.is_empty():
		return false
	var previous := str(profile.get("name", fallback))
	profile["name"] = name
	pet_dogs[pet_id] = profile
	if not save_game():
		profile["name"] = previous
		pet_dogs[pet_id] = profile
		return false
	Inventory.inventory_changed.emit()
	return true

func buy_dog_food(amount: int = 1) -> bool:
	# Keep the two panel purchases atomic: no partial Buy 5 when Barn space is low.
	if amount not in [1, 5]:
		return false
	var total_price := DogData.DOG_FOOD_PRICE * amount
	if Inventory.coins < total_price or not Inventory.can_add_item("dog_food", amount):
		return false
	var old_coins := Inventory.coins
	Inventory.coins -= total_price
	Inventory.dog_food += amount
	if not save_game():
		Inventory.coins = old_coins
		Inventory.dog_food -= amount
		return false
	Inventory.inventory_changed.emit()
	return true

func feed_dog(pet_id: String) -> bool:
	if not pet_dogs.has(pet_id) or Inventory.dog_food <= 0:
		return false
	var profile: Dictionary = pet_dogs[pet_id]
	if float(profile.get("hunger", 100.0)) >= 99.9:
		return false
	var old_food := Inventory.dog_food
	var old_hunger: float = float(profile.get("hunger", 100.0))
	Inventory.dog_food -= 1
	profile["hunger"] = minf(100.0, old_hunger + 70.0)
	profile["last_hunger_update_at"] = Time.get_unix_time_from_system()
	pet_dogs[pet_id] = profile
	if not save_game():
		Inventory.dog_food = old_food
		profile["hunger"] = old_hunger
		pet_dogs[pet_id] = profile
		return false
	Inventory.inventory_changed.emit()
	get_tree().call_group("farm_pets", "begin_eating", pet_id)
	dog_fed.emit(pet_id)
	return true

func tick_dog_hunger(pet_id: String, delta: float) -> void:
	if not pet_dogs.has(pet_id) or delta <= 0.0:
		return
	var profile: Dictionary = pet_dogs[pet_id]
	profile["hunger"] = maxf(0.0, float(profile.get("hunger", 100.0)) - DogData.HUNGER_PER_SECOND * delta)
	profile["last_hunger_update_at"] = Time.get_unix_time_from_system()
	pet_dogs[pet_id] = profile


func get_pending_fishing_reward() -> Dictionary:
	return pending_fishing_reward.duplicate(true) if has_pending_fishing_reward() else {}


func has_pending_fishing_reward() -> bool:
	return pending_fishing_reward_claimable and not pending_fishing_reward.is_empty()


func set_pending_fishing_reward(value: Dictionary) -> bool:
	var normalized := _normalize_pending_fishing_reward(value)
	if normalized.is_empty():
		return false
	pending_fishing_reward = normalized
	pending_fishing_reward_claimable = true
	return true


func clear_pending_fishing_reward() -> void:
	pending_fishing_reward.clear()
	pending_fishing_reward_claimable = false

func adult_animal_ids(animal_type: String, now: float = -1.0) -> Array[String]:
	var ids: Array[String] = []
	for record in animal_records(animal_type):
		if AnimalData.stage_for(animal_type, float(record.get("born_at", 0.0)), now) >= 3:
			ids.append(str(record.get("id", "")))
	return ids

func create_animal_record(animal_type: String, born_at: float = -1.0) -> Dictionary:
	if not animal_rosters.has(animal_type):
		return {}
	var serial: int = int(next_animal_ids.get(animal_type, 1))
	var animal_id: String = "%s_%04d" % [animal_type, serial]
	next_animal_ids[animal_type] = serial + 1
	var seed_value: int = AnimalData.stable_seed(animal_id)
	var record := {"id":animal_id,"type":animal_type,"born_at":Time.get_unix_time_from_system() if born_at < 0.0 else born_at,"lucky_seed":seed_value,"lucky":AnimalData.lucky_pig(animal_id) if animal_type == "pig" else false}
	var roster: Array = animal_rosters[animal_type]
	roster.append(record)
	animal_rosters[animal_type] = roster
	return record

func remove_animal_record(animal_type: String, animal_id: String) -> Dictionary:
	var roster: Array = animal_rosters.get(animal_type, [])
	for index in range(roster.size()):
		if str(roster[index].get("id", "")) != animal_id:
			continue
		var removed: Dictionary = roster[index].duplicate(true)
		roster.remove_at(index)
		animal_rosters[animal_type] = roster
		for station_id in STATION_IDS:
			var station_data: Dictionary = saved_stations.get(station_id, {})
			if stations.has(station_id) and is_instance_valid(stations[station_id]):
				stations[station_id].remove_participant(animal_id)
			elif station_data.has("participant_animal_ids"):
				station_data["participant_animal_ids"].erase(animal_id)
				saved_stations[station_id] = station_data
		return removed
	return {}


func purchase_land(id: String) -> bool:
	if not LandData.ZONES.has(id) or id in unlocked_land_zones:
		return false
	if not LandData.is_adjacent(id, unlocked_land_zones):
		return Inventory.fail(tr("LAND_NEEDS_NEIGHBOR"))
	var cost: Dictionary = LandData.ZONES[id]
	if Inventory.coins < cost["cost_coins"] or Inventory.wood < cost["cost_wood"] or Inventory.stone < cost["cost_stone"]:
		return Inventory.fail(tr("ERROR_MATERIALS"))
	Inventory.coins -= cost["cost_coins"]
	Inventory.wood -= cost["cost_wood"]
	Inventory.stone -= cost["cost_stone"]
	unlocked_land_zones.append(id)
	# Ownership and all costs are complete before the existing autosave signal.
	Inventory.inventory_changed.emit()
	return true


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
		"production_type": "", "started_at": 0.0, "ready_at": 0.0, "participant_animal_ids": []
	}
	if id == "chicken_coop":
		data["chicken_count"] = Inventory.chicken_count
	elif id == "cow_shed":
		data["cow_count"] = Inventory.cow_count
	elif id == "pig_pen":
		data["pig_count"] = Inventory.pig_count
	elif id == "sheep_barn":
		data["sheep_count"] = Inventory.sheep_count
	elif id == "feed_mill":
		data["queue"] = []
		data["outputs"] = []
	return data


func _restore_animal_rosters(data: ConfigFile) -> void:
	var raw_rosters: Variant = data.get_value("animals", "roster", {})
	var raw_next: Variant = data.get_value("animals", "next_ids", {})
	var now: float = Time.get_unix_time_from_system()
	for animal_type in Progression.ANIMALS:
		var target_count: int = Inventory.get(animal_type + "_count")
		var restored: Array = []
		var seen: Dictionary = {}
		var raw: Variant = raw_rosters.get(animal_type, []) if raw_rosters is Dictionary else []
		if raw is Array:
			for value in raw:
				if restored.size() >= target_count:
					break
				if not value is Dictionary or str(value.get("type", animal_type)) != animal_type:
					continue
				var animal_id: String = str(value.get("id", ""))
				if animal_id.is_empty() or seen.has(animal_id):
					continue
				var born_at: float = _read_time_value(value.get("born_at", -1.0), -1.0)
				if born_at < 0.0:
					continue
				if born_at > now + 86400.0:
					born_at = now
				var seed_value: int = _read_int_value(value.get("lucky_seed", AnimalData.stable_seed(animal_id)), AnimalData.stable_seed(animal_id), 1)
				var lucky_value: Variant = value.get("lucky", AnimalData.lucky_pig(animal_id))
				var record := {"id":animal_id,"type":animal_type,"born_at":born_at,"lucky_seed":seed_value,"lucky":lucky_value == true if animal_type == "pig" else false}
				restored.append(record)
				seen[animal_id] = true
		var saved_next: int = 1
		if raw_next is Dictionary:
			saved_next = _read_int_value(raw_next.get(animal_type, 1), 1, 1)
		for index in range(restored.size(), target_count):
			var serial: int = maxi(saved_next, index + 1)
			var animal_id: String = "%s_%04d" % [animal_type, serial]
			while seen.has(animal_id):
				serial += 1
				animal_id = "%s_%04d" % [animal_type, serial]
			saved_next = serial + 1
			var born: float = now - 86400.0 if not raw_rosters is Dictionary or not raw_rosters.has(animal_type) else AnimalData.adult_born_at(animal_type, now)
			var record := {"id":animal_id,"type":animal_type,"born_at":born,"lucky_seed":AnimalData.stable_seed(animal_id),"lucky":AnimalData.lucky_pig(animal_id) if animal_type == "pig" else false}
			restored.append(record)
			seen[animal_id] = true
		animal_rosters[animal_type] = restored
		for record in restored:
			var suffix: String = str(record["id"]).get_slice("_", 1)
			if suffix.is_valid_int():
				saved_next = maxi(saved_next, suffix.to_int() + 1)
		next_animal_ids[animal_type] = maxi(saved_next, 1)


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
	if _removed_fish_migration_pending:
		save_game.call_deferred()
	get_tree().auto_accept_quit = false
	autosave_timer = Timer.new()
	autosave_timer.name = "AutosaveTimer"
	autosave_timer.wait_time = AUTOSAVE_INTERVAL
	autosave_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	autosave_timer.timeout.connect(save_game)
	add_child(autosave_timer)
	autosave_timer.start()


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
		"planted_at": 0.0, "ready_at": 0.0,
		"position": FarmData.plot_position(FarmData.plot_number(id))
	}


func save_game() -> bool:
	_capture_pet_positions()
	if resetting:
		return false
	var data := ConfigFile.new()
	var calendar: Dictionary = GameClock.get_save_data()
	for key in calendar:
		data.set_value("calendar", key, calendar[key])
	data.set_value("decorations", "placed", placed_decorations)
	data.set_value("decorations", "next_id", next_decoration_id)
	data.set_value("land", "unlocked_land_zones", unlocked_land_zones)
	data.set_value("buildings", "owns_bakery", Inventory.owns_bakery)
	data.set_value("bakery", "bakery_queue", bakery_queue)
	data.set_value("buildings", "owns_dairy", Inventory.owns_dairy)
	data.set_value("dairy", "dairy_queue", dairy_queue)
	data.set_value("buildings","owns_spinning_machine",Inventory.owns_spinning_machine)
	data.set_value("spinning_machine","spinning_machine_queue",spinning_machine_queue)
	data.set_value("buildings","owns_loom",Inventory.owns_loom)
	data.set_value("loom","queue",loom_queue)
	data.set_value("game", "version", 18)
	data.set_value("migrations", "removed_fish_v1", true)
	data.set_value("daily_missions", "state", DailyMissionManager.get_save_data())
	data.set_value("discovery", "state", DiscoveryManager.get_save_data())
	data.set_value("weather", "state", WeatherManager.get_save_data())
	data.set_value("farm_event", "state", FarmEventManager.get_save_data())
	data.set_value("dig_spots", "active", saved_dig_spots)
	data.set_value("dig_spots", "day_key", saved_dig_spots_day_key)
	data.set_value("dig_spots", "hidden_treasure_claimed", hidden_treasure_claimed)
	data.set_value("game", "character_selection_pending", character_selection_pending)
	data.set_value("player", "selected_character_id", selected_character_id)
	data.set_value("player", "player_name", player_name)
	data.set_value("fishing", "fishing_attempts_used", Inventory.fishing_attempts_used)
	data.set_value("fishing", "fishing_cycle_started_at", Inventory.fishing_cycle_started_at)
	data.set_value("fishing", "has_fishing_rod", Inventory.has_fishing_rod)
	data.set_value("fishing", "fishing_rod_level", Inventory.fishing_rod_level)
	data.set_value("fishing", "pending_reward", pending_fishing_reward.duplicate(true))
	data.set_value("fishing", "pending_reward_claimable", pending_fishing_reward_claimable)
	data.set_value("treasure", "open_sequence", treasure_open_sequence)
	for id in FarmData.BUILDINGS:
		var position: Vector2 = building_positions.get(id, FarmData.BUILDINGS[id]["position"])
		if buildings.has(id) and is_instance_valid(buildings[id]):
			position = buildings[id].position
		if not FarmData.valid_saved_building_position(id, position):
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
	data.set_value("player", "last_rewarded_level", Inventory.last_rewarded_level)
	data.set_value("player", "selected_crop", Inventory.selected_crop)
	data.set_value("player", "has_dog", Inventory.has_dog)
	data.set_value("pets", "dogs", pet_dogs.duplicate(true))
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
	data.set_value("animals", "pig_count", Inventory.pig_count)
	data.set_value("animals", "sheep_count", Inventory.sheep_count)
	data.set_value("animals", "roster", animal_rosters)
	data.set_value("animals", "next_ids", next_animal_ids)
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

	if not _write_snapshot(data):
		return false
	saved_plots = snapshot
	saved_resources = resource_snapshot
	for id in STATION_IDS:
		saved_stations[id] = _read_station(data, id)
	return true


func _capture_pet_positions() -> void:
	# Runtime pets are recreated on load, so keep their latest valid world point
	# in the existing pet profile rather than introducing another save system.
	for pet in get_tree().get_nodes_in_group("farm_pets"):
		if not is_instance_valid(pet):
			continue
		var pet_id := str(pet.get("pet_id"))
		var point: Variant = pet.get("global_position")
		if pet_id.is_empty() or not pet_dogs.has(pet_id) or not point is Vector2 or not point.is_finite():
			continue
		var profile: Dictionary = pet_dogs[pet_id]
		profile["last_position"] = point
		pet_dogs[pet_id] = profile


func reset_game() -> bool:
	# If deleting the old save fails, leave the current game untouched.
	for path in [TEMP_PATH, BACKUP_TEMP_PATH, BACKUP_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_warning("Could not delete save. Error: %s" % error)
				return false

	resetting = true
	player_name = ""
	player_name_changed.emit()
	set_selected_character(CharacterData.DEFAULT_ID, false)
	GameClock.restore({})
	saved_dig_spots.clear()
	saved_dig_spots_day_key = -1
	hidden_treasure_claimed = false
	DiscoveryManager.reset()
	WeatherManager.reset()
	FarmEventManager.reset()
	var dig_manager := get_tree().get_first_node_in_group("dig_spot_manager")
	if is_instance_valid(dig_manager):
		dig_manager.reset_for_new_game()
	placed_decorations.clear()
	next_decoration_id = 1
	unlocked_land_zones = ["farm_core"]
	Inventory.owns_bakery = false
	bakery_queue.clear()
	Inventory.owns_dairy = false
	dairy_queue.clear()
	Inventory.owns_spinning_machine = false
	spinning_machine_queue.clear()
	Inventory.owns_loom = false
	loom_queue.clear()
	for station_id in STATION_IDS:
		Inventory.set("owns_" + station_id, false)
	for animal_type in ["chicken", "cow", "pig", "sheep"]:
		animal_rosters[animal_type] = []
		next_animal_ids[animal_type] = 1
	pet_dogs.clear()
	Inventory.has_fishing_rod = false
	Inventory.fishing_rod_level = 0
	Inventory.fishing_attempts_used = 0
	Inventory.fishing_cycle_started_at = 0.0
	Inventory.reserved_barn_slots = 0
	clear_pending_fishing_reward()
	treasure_open_sequence = 0
	building_positions.clear()
	for id in FarmData.BUILDINGS:
		building_positions[id] = FarmData.BUILDINGS[id]["position"]
		if buildings.has(id) and is_instance_valid(buildings[id]):
			buildings[id].position = building_positions[id]
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, INVENTORY_DEFAULTS[key])
	Inventory.player_level = 1
	Inventory.last_rewarded_level = 1
	Inventory.level_up_events_cleared.emit()
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
	Inventory.pig_count = 0
	Inventory.sheep_count = 0
	for id in STATION_IDS:
		Inventory.set("owns_" + id, false)
	OrderManager.reset_orders()
	DailyMissionManager.reset_for_new_game()
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
	FarmEventManager.refresh_for_new_game()
	resetting = false
	return save_game()


func _load_game() -> void:
	var data: ConfigFile = _read_snapshot()
	character_selection_pending = not data.has_section("inventory") or data.get_value("game", "character_selection_pending", false) == true
	has_existing_game = data.has_section("inventory") and not character_selection_pending
	set_selected_character(CharacterData.valid_id(data.get_value("player", "selected_character_id", CharacterData.DEFAULT_ID)), false)
	var saved_player_name = data.get_value("player", "player_name", "")
	player_name = saved_player_name.strip_edges().left(16) if saved_player_name is String else ""
	if player_name.is_empty() and has_existing_game:
		# Legacy saves created before player names existed still load safely.
		player_name = "Farmer"
	GameClock.restore({"day":data.get_value("calendar","day",1), "minutes":data.get_value("calendar","minutes",360.0), "season":data.get_value("calendar","season","spring"), "absolute_day":data.get_value("calendar","absolute_day",-1)})
	DiscoveryManager.restore(data.get_value("discovery", "state", {}))
	WeatherManager.restore(data.get_value("weather", "state", {}))
	FarmEventManager.restore(data.get_value("farm_event", "state", {}))
	var dig_data: Variant = data.get_value("dig_spots", "active", [])
	saved_dig_spots = dig_data.duplicate(true) if dig_data is Array else []
	var dig_day: Variant = data.get_value("dig_spots", "day_key", -1)
	saved_dig_spots_day_key = int(dig_day) if dig_day is int else -1
	hidden_treasure_claimed = data.get_value("dig_spots", "hidden_treasure_claimed", false) == true
	placed_decorations = DecorationData.restore(data.get_value("decorations","placed",[]))
	next_decoration_id = _read_int(data,"decorations","next_id",1,1)
	for record in placed_decorations:
		next_decoration_id = maxi(next_decoration_id, record["instance_id"].trim_prefix("decor_").to_int()+1)
	unlocked_land_zones = LandData.restore_unlocked(data.get_value("land", "unlocked_land_zones", []))
	var bakery_owned = data.get_value("buildings", "owns_bakery", false)
	Inventory.owns_bakery = bakery_owned if bakery_owned is bool else false
	# Retain every valid job until structure upgrades have been restored below.
	# Legacy saves use three slots; upgraded saves may legally contain up to five.
	bakery_queue = Inventory.BakeryData.restore_queue(data.get_value("bakery", "bakery_queue", []), 5) if Inventory.owns_bakery else []
	var dairy_owned = data.get_value("buildings", "owns_dairy", false)
	Inventory.owns_dairy = dairy_owned if dairy_owned is bool else false
	dairy_queue = Inventory.DairyData.restore_queue(data.get_value("dairy","dairy_queue",[]), 5) if Inventory.owns_dairy else []
	var spinning_owned = data.get_value("buildings","owns_spinning_machine",false)
	Inventory.owns_spinning_machine = spinning_owned if spinning_owned is bool else false
	spinning_machine_queue = Inventory.SpinningData.restore_queue(data.get_value("spinning_machine","spinning_machine_queue",[]), 5) if Inventory.owns_spinning_machine else []
	var loom_owned = data.get_value("buildings","owns_loom",false)
	Inventory.owns_loom = loom_owned if loom_owned is bool else false
	loom_queue = LoomData.restore_queue(data.get_value("loom","queue",[])) if Inventory.owns_loom else []
	for id in FarmData.BUILDINGS:
		var position = data.get_value("building_positions", id, FarmData.BUILDINGS[id]["position"])
		if not FarmData.valid_saved_building_position(id, position):
			push_warning("Invalid saved building position: " + id)
			position = FarmData.BUILDINGS[id]["position"]
		building_positions[id] = position
	# Missing or invalid fields use defaults; valid legacy values are kept.
	for key in INVENTORY_DEFAULTS:
		Inventory.set(key, _read_int(data, "inventory", key, INVENTORY_DEFAULTS[key]))
	_migrate_removed_fish(data)
	# Legacy saves gain newly catalogued treasure at zero; owning a migrated Coin
	# or Gem still grants its cosmetic exactly once without granting any item.
	Inventory.reconcile_treasure_cosmetics()
	Inventory.player_level = _read_int(data, "player", "player_level", 1, 1)
	Inventory.player_exp = _read_int(data, "player", "player_exp", 0)
	Inventory.unlocked_plot_count = clampi(_read_int(data, "farm", "unlocked_plot_count", FarmData.STARTING_PLOTS), FarmData.STARTING_PLOTS, FarmData.MAX_PLOTS)
	var fishing = data.get_value("zones", "fishing_unlocked", false)
	Inventory.fishing_unlocked = fishing if fishing is bool and Inventory.player_level >= FarmData.FISHING_LEVEL else false
	for id in Inventory.ToolData.TOOLS:
		var owned_tool = data.get_value("tools", "has_" + id, false)
		Inventory.set("has_" + id, owned_tool if owned_tool is bool else false)
		Inventory.set(id + "_level", mini(Inventory.ToolData.TOOLS[id]["levels"].size(), _read_int(data, "tools", id + "_level", 0)))
		if Inventory.get("has_" + id):
			Inventory.set(id + "_level", maxi(1, Inventory.get(id + "_level")))
		else:
			Inventory.set(id + "_level", 0)
	var notified = data.get_value("tools", "unlock_notified", false)
	Inventory.tools_unlock_notified = notified if notified is bool else false
	var rod_owned = data.get_value("fishing", "has_fishing_rod", false)
	Inventory.fishing_attempts_used = mini(Inventory.FishingData.ATTEMPTS_PER_CYCLE, _read_int(data, "fishing", "fishing_attempts_used", 0))
	Inventory.fishing_cycle_started_at = _read_time(data, "fishing", "fishing_cycle_started_at", 0.0)
	Inventory.refresh_fishing_cycle()
	Inventory.has_fishing_rod = rod_owned if rod_owned is bool else false
	Inventory.fishing_rod_level = mini(Inventory.FishingData.ROD_LEVELS.size(), _read_int(data, "fishing", "fishing_rod_level", 0))
	Inventory.fishing_rod_level = maxi(1, Inventory.fishing_rod_level) if Inventory.has_fishing_rod else 0
	# Pending rewards written by the former pre-cast staging implementation had
	# no completion marker. Treat those legacy values as transient/cancelled so
	# loading cannot grant a reward that was never successfully caught.
	var pending_claimable: Variant = data.get_value("fishing", "pending_reward_claimable", false)
	if pending_claimable is bool and pending_claimable:
		pending_fishing_reward = _normalize_pending_fishing_reward(data.get_value("fishing", "pending_reward", {}))
		pending_fishing_reward_claimable = not pending_fishing_reward.is_empty()
	else:
		clear_pending_fishing_reward()
	treasure_open_sequence = _read_int(data, "treasure", "open_sequence", 0)
	# Loading normalizes malformed/legacy XP quietly; it must not create level-up rewards.
	Inventory.normalize_exp(false)
	if data.has_section_key("player", "last_rewarded_level"):
		Inventory.last_rewarded_level = mini(
			Inventory.player_level,
			_read_int(data, "player", "last_rewarded_level", Inventory.player_level, 1)
		)
	else:
		# A pre-reward save starts reward tracking at its current level; no retroactive grants.
		Inventory.last_rewarded_level = Inventory.player_level
	for id in Progression.UPGRADES:
		var max_level: int = Progression.UPGRADES[id].size() + 1
		Inventory.set(id + "_level", mini(max_level, _read_int(data, "upgrades", id + "_level", 1, 1)))
	# Now that levels are authoritative, apply the corresponding queue limit. This
	# both preserves upgraded queues and safely trims malformed legacy data.
	bakery_queue = Inventory.BakeryData.restore_queue(bakery_queue, Inventory.production_queue_capacity("bakery"))
	dairy_queue = Inventory.DairyData.restore_queue(dairy_queue, Inventory.production_queue_capacity("dairy"))
	spinning_machine_queue = Inventory.SpinningData.restore_queue(spinning_machine_queue, Inventory.production_queue_capacity("spinning_machine"))
	var dog_house = data.get_value("buildings", "has_dog_house", false)
	Inventory.has_dog_house = dog_house if dog_house is bool else false
	for id in RESOURCE_IDS:
		saved_resources[id] = _read_resource(data.get_value("resources", id, 0.0))
	Inventory.silo_capacity = maxi(30, _read_int(data, "storage", "silo_capacity", 30, 1))
	Inventory.barn_capacity = maxi(
	20,
	_read_int(
		data,
		"storage",
		"barn_capacity",
		20,
		1
	)
)
	for storage in ["silo", "barn"]:
		var level: int = Inventory.get(storage + "_level")
		if level > 1:
			var capacity: int = Progression.UPGRADES[storage][level]["capacity"]
			Inventory.set(storage + "_capacity", maxi(Inventory.get(storage + "_capacity"), capacity))
	# House storage space was added after existing saves. Reconcile upward only so
	# no valid legacy capacity or stored item can ever be lost during migration.
	Inventory.reconcile_storage_capacities()
	var legacy: bool = _read_int(data, "game", "version", 0) < 5
	for id in STATION_IDS:
		# Previously these buildings were free. Keep them on existing farms.
		var owned_default: bool = legacy and data.has_section(id) and id != "cow_shed"
		var owned_building = data.get_value("buildings", "owns_" + id, owned_default)
		Inventory.set("owns_" + id, owned_building if owned_building is bool else false)
	var old_chickens: int = _read_int(data, "chicken_coop", "chicken_count", 0)
	Inventory.chicken_count = clampi(_read_int(data, "animals", "chicken_count", old_chickens), 0, Inventory.animal_capacity("chicken"))
	Inventory.cow_count = clampi(_read_int(data, "animals", "cow_count", 0), 0, Inventory.animal_capacity("cow"))
	Inventory.pig_count = clampi(_read_int(data, "animals", "pig_count", 0), 0, Inventory.animal_capacity("pig"))
	Inventory.sheep_count = clampi(_read_int(data, "animals", "sheep_count", 0), 0, Inventory.animal_capacity("sheep"))
	for animal_type in Progression.ANIMALS:
		if not Inventory.owns_building(Progression.ANIMALS[animal_type]["building"]):
			Inventory.set(animal_type + "_count", 0)
	_restore_animal_rosters(data)
	var selected = data.get_value("player", "selected_crop", "WHEAT")
	Inventory.selected_crop = "WHEAT"
	# Pet profiles supersede the former single bool. Migrate one existing dog
	# once, for free, so old farms retain their companion without duplication.
	pet_dogs = _restore_pet_dogs(data.get_value("pets", "dogs", {}))
	var legacy_dog = data.get_value("player", "has_dog", false)
	if pet_dogs.is_empty() and legacy_dog is bool and legacy_dog:
		var migrated_dog: Dictionary = DogData.default_profile("shiba")
		migrated_dog["name"] = "Cún"
		pet_dogs["dog_shiba"] = migrated_dog
	Inventory.has_dog = not pet_dogs.is_empty()
	if selected == "MYSTERY" or (selected is String and Inventory.is_unlocked(selected)):
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
	DailyMissionManager.restore(data.get_value("daily_missions", "state", {}))
	Inventory.inventory_changed.emit()
	# Also persist newly generated orders for old saves and brand-new games.
	save_game.call_deferred()

func _restore_pet_dogs(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary:
		return result
	var now := Time.get_unix_time_from_system()
	for pet_id in DogData.DOG_IDS:
		var source: Variant = raw.get(pet_id, {})
		if not source is Dictionary:
			continue
		var variant: Dictionary = DogData.variant_for_pet(pet_id)
		if variant.is_empty() or str(source.get("variant", "")) != str(variant["id"]):
			continue
		var profile := DogData.default_profile(str(variant["id"]), now)
		profile["name"] = DogData.normalized_name(source.get("name", ""), str(variant["default_name"]))
		var hunger := clampf(float(source.get("hunger", 100.0)), 0.0, 100.0)
		var last: float = float(source.get("last_hunger_update_at", now))
		var elapsed := clampf(now - last, 0.0, DogData.MAX_OFFLINE_HUNGER_LOSS / DogData.HUNGER_PER_SECOND)
		profile["hunger"] = maxf(0.0, hunger - minf(DogData.MAX_OFFLINE_HUNGER_LOSS, elapsed * DogData.HUNGER_PER_SECOND))
		profile["last_hunger_update_at"] = now
		result[pet_id] = profile
	return result

func _migrate_removed_fish(data: ConfigFile) -> void:
	if data.get_value("migrations", "removed_fish_v1", false) == true:
		return
	# The three retired fish are no longer stored or sold. Preserve their value
	# exactly once for existing farms instead of silently deleting earned loot.
	var compensation: int = 0
	compensation += _read_int(data, "inventory", "small_fish", 0) * 25
	compensation += _read_int(data, "inventory", "river_fish", 0) * 40
	compensation += _read_int(data, "inventory", "golden_fish", 0) * 100
	Inventory.coins += compensation
	_removed_fish_migration_pending = true


func _read_int(data: ConfigFile, section: String, key: String, fallback: int, minimum: int = 0) -> int:
	var value = data.get_value(section, key, fallback)
	if value is int and value >= minimum:
		return mini(value, 2147483647)
	if data.has_section_key(section, key):
		push_warning("Invalid save field: [%s] %s. Using default." % [section, key])
	return fallback


func _normalize_pending_fishing_reward(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var item: Variant = value.get("item", "")
	var amount: Variant = value.get("amount", 0)
	var token: Variant = value.get("token", 0)
	if not item is String or item not in Inventory.BARN_ITEMS:
		return {}
	if not amount is int or amount != 1:
		return {}
	if not token is int or token < 1 or token > 2147483647:
		return {}
	return {"item": item, "amount": amount, "token": token}


func _read_station(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = default_station(id)
	if not Inventory.owns_building(id):
		return result
	if id == "feed_mill":
		result["state"] = data.get_value(id,"state","IDLE")
		result["production_type"] = data.get_value(id,"production_type","")
		result["started_at"] = _read_time(data,id,"started_at",0.0)
		result["ready_at"] = _read_time(data,id,"ready_at",0.0)
		if data.has_section_key(id,"queue") or data.has_section_key(id,"outputs"):
			result["queue"] = data.get_value(id,"queue",[])
			result["outputs"] = data.get_value(id,"outputs",[])
		else:
			result.erase("queue")
			result.erase("outputs")
		result.merge(FeedData.restore(result),true)
		return result
	var state = data.get_value(id, "state", result["state"])
	if state not in ["PRODUCING", "READY"]:
		return result
	var product: Dictionary = Progression.PRODUCTS.get(id, {})
	var production = data.get_value(id, "production_type", product.get("item", "CHICKEN_FEED"))
	result["production_type"] = str(production).to_upper() if not product.is_empty() else "CHICKEN_FEED"
	if not product.is_empty():
		var animal_type: String = product["animal"]
		var participants: Array[String] = []
		# Use an empty array rather than null as ConfigFile's fallback. Passing null
		# is treated as "no default" and logs an error for valid pre-snapshot saves.
		var participants_raw: Variant = data.get_value(id, "participant_animal_ids", [])
		if data.has_section_key(id, "participant_animal_ids") and participants_raw is Array:
			for animal_id in participants_raw:
				if animal_id is String and _roster_has_id(animal_type, animal_id) and animal_id not in participants:
					participants.append(animal_id)
		else:
			# Preserve the animal set from an active pre-snapshot batch. New cycles
			# only use adults, but an old save must not lose a paid in-flight batch.
			for record in animal_records(animal_type):
				var legacy_id: String = str(record.get("id", ""))
				if not legacy_id.is_empty() and legacy_id not in participants:
					participants.append(legacy_id)
		result["participant_animal_ids"] = participants
		if participants.is_empty():
			return default_station(id)
	result["started_at"] = _read_time(data, id, "started_at", 0.0)
	result["ready_at"] = _read_time(data, id, "ready_at", 0.0)
	if state == "PRODUCING" and (result["ready_at"] <= 0.0 or result["ready_at"] < result["started_at"]):
		push_warning("Invalid production timestamps: " + id)
		return default_station(id)
	result["state"] = "READY" if state == "READY" or Time.get_unix_time_from_system() >= result["ready_at"] else "PRODUCING"
	return result

func _roster_has_id(animal_type: String, animal_id: String) -> bool:
	for record in animal_records(animal_type):
		if str(record.get("id", "")) == animal_id:
			return true
	return false

func _read_time(data: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value = data.get_value(section, key, fallback)
	if value is int or value is float:
		if is_finite(float(value)) and value >= 0.0 and value <= 1000000000000.0:
			return float(value)
	return fallback

func _read_time_value(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1000000000000.0:
		return float(value)
	return fallback

func _read_int_value(value: Variant, fallback: int, minimum: int = 0) -> int:
	if value is int and value >= minimum:
		return mini(value, 2147483647)
	return fallback


func _read_plot(data: ConfigFile, id: String) -> Dictionary:
	var result: Dictionary = empty_plot(id)
	var legacy_id: String = "soil_%d" % FarmData.plot_number(id)
	if not data.has_section(id) and data.has_section(legacy_id):
		id = legacy_id
	var position = data.get_value(id, "position", result["position"])
	if position is Vector2 and position.is_finite():
		var footprint := Rect2(position - FarmData.PLOT_SIZE / 2.0, FarmData.PLOT_SIZE)
		if FarmData.BUILDABLE_LAND.encloses(footprint) and LandData.owns_rect(footprint, unlocked_land_zones):
			result["position"] = position
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
	var duration: float = CropData.grow_seconds(crop)
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
	if not is_finite(float(timestamp)) or timestamp < 0.0 or timestamp > 1000000000000.0:
		timestamp = 0.0
	var zone = value.get("zone_id", "main") if value is Dictionary else "main"
	var result: Dictionary = {"state": "DEPLETED" if timestamp > 0.0 else "AVAILABLE", "respawn_at": float(timestamp), "zone_id": zone if zone is String else "main"}
	if value is Dictionary and RockData.TYPES.has(value.get("rock_type","")):
		result["rock_type"] = value["rock_type"]
	return result


# Storage boundary: gameplay keeps calling save_game() when a backend replaces local I/O.
func _write_snapshot(data: ConfigFile) -> bool:
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
	return true


func _read_snapshot() -> ConfigFile:
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
	return data
