extends Node

signal discovery_found(category_id: String, item_id: String)
signal cosmetic_unlocked(decoration_id: String)

const DiscoveryData = preload("res://discovery_data.gd")
const DecorationData = preload("res://decoration_data.gd")
const MILESTONES: Array[Dictionary] = [
	{"id":"fish_4", "category":"fish", "count":4, "decoration":"fishing_sign"},
	{"id":"rare_crop_3", "category":"rare_finds", "count":3, "decoration":"golden_flower_pot"},
	{"id":"treasure_5", "category":"treasures", "count":5, "decoration":"treasure_chest"}
]
var discovered: Dictionary = {}
var collection_rewards_claimed: Array[String] = []
var unlocked_cosmetics: Array[String] = []

func discover(category_id: String, item_id: String) -> bool:
	if category_id not in DiscoveryData.ITEMS or item_id not in DiscoveryData.ITEMS[category_id]:
		return false
	if not discovered.has(category_id):
		discovered[category_id] = []
	if item_id in discovered[category_id]:
		return false
	discovered[category_id].append(item_id)
	discovery_found.emit(category_id, item_id)
	_check_milestones(true)
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()
	return true

func discover_item(item_id: String) -> bool:
	var category_id := DiscoveryData.category_for_item(item_id)
	return discover(category_id, item_id) if not category_id.is_empty() else false

func has_discovered(category_id: String, item_id: String) -> bool:
	return item_id in discovered.get(category_id, [])

func get_progress(category_id: String) -> Vector2i:
	var values: Variant = discovered.get(category_id, [])
	return Vector2i(values.size() if values is Array else 0, DiscoveryData.ITEMS.get(category_id, []).size())

func get_save_data() -> Dictionary:
	return {"discovered": discovered.duplicate(true), "collection_rewards_claimed": collection_rewards_claimed.duplicate(), "unlocked_cosmetics": unlocked_cosmetics.duplicate()}

func restore(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var source: Variant = data.get("discovered", {})
	if source is Dictionary:
		for category_id in DiscoveryData.ITEMS:
			var values: Variant = source.get(category_id, [])
			if values is Array:
				for item_id in values:
					if item_id is String and item_id in DiscoveryData.ITEMS[category_id] and item_id not in discovered[category_id]:
						discovered[category_id].append(item_id)
	var rewards: Variant = data.get("collection_rewards_claimed", [])
	if rewards is Array:
		for reward in rewards:
			if reward is String and reward not in collection_rewards_claimed:
				collection_rewards_claimed.append(reward)
	var cosmetics: Variant = data.get("unlocked_cosmetics", [])
	if cosmetics is Array:
		for decoration_id in cosmetics:
			if decoration_id is String and DecorationData.TYPES.has(decoration_id) and DecorationData.TYPES[decoration_id].get("hidden", false) and decoration_id not in unlocked_cosmetics:
				unlocked_cosmetics.append(decoration_id)
	_check_milestones(false)

func unlock_cosmetic(decoration_id: String, notify: bool = true) -> bool:
	if not DecorationData.TYPES.has(decoration_id) or not DecorationData.TYPES[decoration_id].get("hidden", false) or decoration_id in unlocked_cosmetics:
		return false
	unlocked_cosmetics.append(decoration_id)
	if notify:
		cosmetic_unlocked.emit(decoration_id)
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()
	return true

func reset() -> void:
	discovered.clear()
	for category in DiscoveryData.ITEMS:
		discovered[category] = []
	collection_rewards_claimed.clear()
	unlocked_cosmetics.clear()

func _check_milestones(notify: bool) -> void:
	for milestone in MILESTONES:
		var id: String = milestone["id"]
		var decoration_id: String = milestone["decoration"]
		if get_progress(milestone["category"]).x < int(milestone["count"]) or id in collection_rewards_claimed:
			continue
		collection_rewards_claimed.append(id)
		if decoration_id not in unlocked_cosmetics:
			unlocked_cosmetics.append(decoration_id)
			if notify:
				cosmetic_unlocked.emit(decoration_id)
