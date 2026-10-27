extends Node

const SpotScene = preload("res://dig_spot.tscn")
const WeatherData = preload("res://weather_data.gd")
const Placement = preload("res://building_placement.gd")

var farm: Node2D
var spots: Dictionary = {}
var current_day_key: int = -1

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

func collect_spot(id: String) -> bool:
	if not spots.has(id) or not is_instance_valid(spots[id]):
		return false
	var spot: Node = spots[id]
	if not spot.can_interact():
		return false
	var reward: Dictionary = spot.reward
	if reward.get("type") == "item":
		var item_id := str(reward.get("item", ""))
		var amount := maxi(1, int(reward.get("amount", 1)))
		if not Inventory.can_add_item(item_id, amount):
			Inventory.fail(tr("ERROR_STORAGE"))
			return false
		if not Inventory.add_item(item_id, amount, false):
			return false
	else:
		var amount := maxi(1, int(reward.get("amount", 1)))
		if Inventory.coins > 9223372036854775807 - amount:
			return false
		Inventory.coins += amount
	spots.erase(id)
	spot.queue_free()
	_save_active_spots()
	Inventory.inventory_changed.emit()
	return true

func get_save_data() -> Array:
	var result: Array = []
	for spot in spots.values():
		if is_instance_valid(spot):
			result.append({"id": spot.spot_id, "position": spot.global_position, "reward": spot.reward.duplicate(true), "day_key": WeatherData.day_key()})
	return result

func reset_for_new_game() -> void:
	_clear_spots()
	current_day_key = WeatherData.day_key()
	SaveManager.saved_dig_spots = []
	SaveManager.saved_dig_spots_day_key = current_day_key

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
		var spot: Node2D = SpotScene.instantiate()
		spot.position = point
		spot.spot_id = "dig_%d_%02d" % [day_key, made + 1]
		spot.reward = _roll_reward(rng)
		farm.add_child(spot)
		if not Placement.can_place(spot, spot.global_position):
			spot.queue_free()
			continue
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
			if point.distance_to(Vector2(800, 600)) < 160.0:
				continue
			if not SaveManager.LandData.owns_rect(Rect2(point - Vector2(18, 18), Vector2(36, 36)), SaveManager.unlocked_land_zones):
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
	if roll < 0.42:
		return {"type": "coins", "amount": rng.randi_range(18, 45)}
	if roll < 0.68:
		return {"type": "item", "item": "map_fragment", "amount": 1}
	if roll < 0.84:
		var crops: Array[String] = []
		for crop_id in Inventory.CropData.CROPS:
			if Inventory.is_unlocked(crop_id):
				crops.append(crop_id.to_lower() + "_seed")
		return {"type": "item", "item": crops[rng.randi_range(0, crops.size() - 1)] if not crops.is_empty() else "wheat_seed", "amount": 1}
	return {"type": "item", "item": "old_bottle", "amount": 1}

func _spawn_record(record: Dictionary) -> void:
	var id := str(record.get("id", ""))
	var position: Variant = record.get("position", null)
	var reward: Variant = record.get("reward", {})
	if id.is_empty() or spots.has(id) or not (position is Vector2) or not (reward is Dictionary):
		return
	var spot: Node2D = SpotScene.instantiate()
	spot.name = id
	spot.spot_id = id
	spot.position = position
	spot.reward = reward.duplicate(true)
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

func _on_clock_changed() -> void:
	var key := WeatherData.day_key()
	if key != current_day_key:
		_generate_for_day(key)
