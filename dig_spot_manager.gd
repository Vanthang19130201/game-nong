extends Node

const SpotScene = preload("res://dig_spot.tscn")
const WeatherData = preload("res://weather_data.gd")
const SafePlacement = preload("res://safe_world_placement.gd")
const DecorationData = preload("res://decoration_data.gd")
const TreasureData = preload("res://treasure_data.gd")

var farm: Node2D
var spots: Dictionary = {}
var current_day_key: int = -1
var _checking_treasure_hunt := false

func setup(farm_root: Node2D) -> void:
	add_to_group("dig_spot_manager")
	farm = farm_root
	var saved: Array = SaveManager.saved_dig_spots
	var key := WeatherData.day_key()
	current_day_key = SaveManager.saved_dig_spots_day_key
	var valid_saved := current_day_key == key
	for record in saved:
		if not record is Dictionary or int(record.get("day_key", -1)) != key or not (record.get("position", Vector2.ZERO) is Vector2):
			valid_saved = false
			break
	if valid_saved:
		for record in saved:
			_spawn_record(record)
	else:
		_generate_for_day(key)
	GameClock.changed.connect(_on_clock_changed)
	if not Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.connect(_on_inventory_changed)
	_check_treasure_hunt()

func collect_spot(id: String) -> bool:
	if not spots.has(id) or not is_instance_valid(spots[id]):
		return false
	var spot: Node = spots[id]
	if not spot.can_interact():
		return false
	var reward: Dictionary = spot.reward
	var old_discovery_state := DiscoveryManager.get_save_data()
	var old_coins: int = Inventory.coins
	var old_cosmetics: Array[String] = DiscoveryManager.unlocked_cosmetics.duplicate()
	var old_treasure_claimed: bool = SaveManager.hidden_treasure_claimed
	var old_saved_spots: Array = SaveManager.saved_dig_spots.duplicate(true)
	var old_saved_day: int = SaveManager.saved_dig_spots_day_key
	var item_id := str(reward.get("item", ""))
	var old_item_count: int = Inventory.get(item_id) if reward.get("type") == "item" else 0
	if spot.is_hidden_treasure:
		SaveManager.hidden_treasure_claimed = true
	if reward.get("type") == "item":
		var amount := maxi(1, int(reward.get("amount", 1)))
		if not Inventory.can_add_item(item_id, amount):
			Inventory.fail(tr("ERROR_STORAGE"))
			return false
		if not Inventory.add_item(item_id, amount, false):
			return false
	elif reward.get("type") == "hidden_cosmetic":
		var decoration_id := str(reward.get("decoration", ""))
		if not DiscoveryManager.unlock_cosmetic(decoration_id, false):
			return false
	else:
		var amount := maxi(1, int(reward.get("amount", 1)))
		if Inventory.coins > 9223372036854775807 - amount:
			return false
		Inventory.coins += amount
	spots.erase(id)
	_save_active_spots()
	if not SaveManager.save_game():
		SaveManager.hidden_treasure_claimed = old_treasure_claimed
		if reward.get("type") == "coins":
			Inventory.coins = old_coins
		elif reward.get("type") == "item":
			Inventory.set(item_id, old_item_count)
			DiscoveryManager.restore(old_discovery_state)
		elif reward.get("type") == "hidden_cosmetic":
			DiscoveryManager.restore(old_discovery_state)
			DiscoveryManager.unlocked_cosmetics = old_cosmetics
		spots[id] = spot
		SaveManager.saved_dig_spots = old_saved_spots
		SaveManager.saved_dig_spots_day_key = old_saved_day
		return false
	spot.queue_free()
	if reward.get("type") == "hidden_cosmetic":
		DiscoveryManager.cosmetic_unlocked.emit(str(reward.get("decoration", "")))
	Inventory.inventory_changed.emit()
	return true

func get_save_data() -> Array:
	var result: Array = []
	for spot in spots.values():
		if is_instance_valid(spot):
			result.append({"id": spot.spot_id, "position": spot.global_position, "reward": spot.reward.duplicate(true), "day_key": WeatherData.day_key(), "is_hidden_treasure": spot.is_hidden_treasure})
	return result

func reset_for_new_game() -> void:
	_clear_spots()
	current_day_key = WeatherData.day_key()
	SaveManager.saved_dig_spots = []
	SaveManager.saved_dig_spots_day_key = current_day_key
	SaveManager.hidden_treasure_claimed = false

func _generate_for_day(day_key: int) -> void:
	_clear_spots()
	current_day_key = day_key
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xD165907 + day_key * 1297
	var count := rng.randi_range(0, 2)
	var candidates := _candidate_points(rng)
	var made := 0
	for point in candidates:
		if made >= count:
			break
		if not SafePlacement.is_clear(farm, point, Vector2(48, 36), 54.0):
			continue
		var spot: Node2D = SpotScene.instantiate()
		spot.position = point
		spot.spot_id = "dig_%d_%02d" % [day_key, made + 1]
		spot.reward = _roll_reward(rng)
		farm.add_child(spot)
		spots[spot.spot_id] = spot
		made += 1
	_save_active_spots()
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()

func _candidate_points(rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var zones: Array[String] = []
	for zone_id in SaveManager.unlocked_land_zones:
		if SaveManager.LandData.ZONES.has(zone_id):
			zones.append(zone_id)
	for zone_id in zones:
		var area: Rect2 = SaveManager.LandData.ZONES[zone_id]["area"]
		for _i in range(12):
			var point := Vector2(rng.randf_range(area.position.x + 80, area.end.x - 80), rng.randf_range(area.position.y + 80, area.end.y - 80)).snapped(Vector2(64, 64))
			if not SafePlacement.is_clear(farm, point, Vector2(48, 36), 54.0):
				continue
			points.append(point)
	for index in range(points.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary := points[index]
		points[index] = points[other]
		points[other] = temporary
	return points

func _roll_reward(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.40:
		return {"type": "coins", "amount": rng.randi_range(18, 45)}
	if roll < 0.60:
		var crops: Array[String] = []
		for crop_id in Inventory.CropData.CROPS:
			if Inventory.is_unlocked(crop_id):
				crops.append(crop_id.to_lower() + "_seed")
		return {"type": "item", "item": crops[rng.randi_range(0, crops.size() - 1)] if not crops.is_empty() else "wheat_seed", "amount": 1}
	if roll < 0.80:
		return {"type": "item", "item": "old_bottle" if rng.randf() < 0.8 else "old_boot", "amount": 1}
	if roll < 0.90:
		return {"type": "item", "item": "map_fragment", "amount": 1}
	if roll < 0.95:
		return {"type": "item", "item": "small_chest", "amount": 1}
	if roll < 0.985:
		return {"type": "item", "item": "mystery_seed", "amount": 1}
	# The exact result is generated with the daily spot and saved in its record,
	# so this rare container can never be rerolled by reloading before a dig.
	return {"type": "item", "item": TreasureData.roll_rare_container(rng), "amount": 1}

func _spawn_record(record: Dictionary) -> void:
	var id := str(record.get("id", ""))
	var position: Variant = record.get("position", null)
	var reward: Variant = record.get("reward", {})
	if id.is_empty() or spots.has(id) or not (position is Vector2) or not (reward is Dictionary):
		return
	if not SafePlacement.is_clear(farm, position, Vector2(48, 36), 54.0):
		return
	var spot: Node2D = SpotScene.instantiate()
	spot.name = id
	spot.spot_id = id
	spot.position = position
	spot.reward = reward.duplicate(true)
	spot.is_hidden_treasure = record.get("is_hidden_treasure", false) == true
	farm.add_child(spot)
	spots[id] = spot

func _clear_spots() -> void:
	for spot in spots.values():
		if is_instance_valid(spot):
			spot.queue_free()
	spots.clear()

func _save_active_spots() -> void:
	SaveManager.saved_dig_spots = get_save_data()
	SaveManager.saved_dig_spots_day_key = current_day_key

func _on_inventory_changed() -> void:
	_check_treasure_hunt()

func _check_treasure_hunt() -> void:
	if _checking_treasure_hunt or not is_instance_valid(farm) or SaveManager.hidden_treasure_claimed or Inventory.map_fragment < 3:
		return
	for spot in spots.values():
		if is_instance_valid(spot) and spot.is_hidden_treasure:
			return
	_checking_treasure_hunt = true
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 0x4D415050 + GameClock.absolute_day * 997
	var candidates := _candidate_points(seed_rng)
	if candidates.is_empty():
		_checking_treasure_hunt = false
		return
	var decoration_ids: Array[String] = []
	for id in DecorationData.TYPES:
		if DecorationData.TYPES[id].get("hidden", false) and id not in DiscoveryManager.unlocked_cosmetics:
			decoration_ids.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4D415046 + GameClock.absolute_day * 271 + Inventory.map_fragment
	var reward: Dictionary = {"type":"coins", "amount":60}
	# A hidden treasure has one persisted rare-container branch. The gem's 1%
	# chance is centralized in TreasureData rather than added as a second roll.
	if rng.randf() < 0.15:
		reward = {"type":"item", "item":TreasureData.roll_rare_container(rng), "amount":1}
	elif not decoration_ids.is_empty():
		reward = {"type":"hidden_cosmetic", "decoration":decoration_ids[rng.randi_range(0, decoration_ids.size()-1)]}
	var point := Vector2.ZERO
	var found_position := false
	for candidate in candidates:
		if SafePlacement.is_clear(farm, candidate, Vector2(56, 42), 58.0):
			point = candidate
			found_position = true
			break
	if not found_position:
		_checking_treasure_hunt = false
		return
	var previous_fragments: int = Inventory.map_fragment
	Inventory.map_fragment -= 3
	var spot: Node2D = SpotScene.instantiate()
	spot.position = point
	spot.spot_id = "treasure_%d" % GameClock.absolute_day
	spot.reward = reward
	spot.is_hidden_treasure = true
	farm.add_child(spot)
	spots[spot.spot_id] = spot
	_save_active_spots()
	if not SaveManager.save_game():
		Inventory.map_fragment = previous_fragments
		spots.erase(spot.spot_id)
		spot.queue_free()
		_save_active_spots()
	else:
		get_tree().call_group("farm_hud", "show_floating_feedback", tr("TREASURE_HUNT_CLUE"))
		Inventory.inventory_changed.emit()
	_checking_treasure_hunt = false


func _on_clock_changed() -> void:
	var key := WeatherData.day_key()
	if key != current_day_key:
		_generate_for_day(key)
