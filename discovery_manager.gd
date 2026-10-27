extends Node

signal discovery_found(category_id: String, item_id: String)

const DiscoveryData = preload("res://discovery_data.gd")
var discovered: Dictionary = {}
var collection_rewards_claimed: Array[String] = []

func discover(category_id: String, item_id: String) -> bool:
	if category_id not in DiscoveryData.ITEMS or item_id not in DiscoveryData.ITEMS[category_id]:
		return false
	if not discovered.has(category_id):
		discovered[category_id] = []
	if item_id in discovered[category_id]:
		return false
	discovered[category_id].append(item_id)
	discovery_found.emit(category_id, item_id)
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
	return {"discovered": discovered.duplicate(true), "collection_rewards_claimed": collection_rewards_claimed.duplicate()}

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

func reset() -> void:
	discovered.clear()
	for category in DiscoveryData.ITEMS:
		discovered[category] = []
	collection_rewards_claimed.clear()
