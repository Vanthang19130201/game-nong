extends Node

signal orders_changed

const CropData = preload("res://crop_data.gd")
const ORDER_COUNT: int = 3

var orders: Array = []
var next_order_id: int = 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	Inventory.inventory_changed.connect(ensure_available_orders)


func item_info() -> Dictionary:
	var items: Dictionary = {}
	for item in Inventory.BakeryData.RECIPES:
		var recipe: Dictionary = Inventory.BakeryData.RECIPES[item]
		items[item] = {"name": recipe["name"], "level": recipe["level"], "price": recipe["price"], "exp": 0}
	for crop in CropData.CROPS:
		var info: Dictionary = CropData.CROPS[crop]
		items[crop.to_lower()] = {
			"name": info["name"], "level": info["unlock_level"],
			"price": info["sell_price"], "exp": info["harvest_exp"]
		}
	items["egg"] = {"name": "Egg", "level": 7, "price": Inventory.EGG_PRICE, "exp": 5}
	items["milk"] = {"name": "Milk", "level": 10, "price": Inventory.MILK_PRICE, "exp": 10}
	for fish in Inventory.FishingData.FISH:
		var info: Dictionary = Inventory.FishingData.FISH[fish]
		items[fish] = {"name": info["name"], "level": Inventory.FarmData.FISHING_LEVEL, "price": info["sell_price"], "exp": info["order_exp"]}
	return items


func item_available(item: String) -> bool:
	var items: Dictionary = item_info()
	if not items.has(item) or Inventory.player_level < items[item]["level"]:
		return false
	if Inventory.FishingData.FISH.has(item):
		return Inventory.is_zone_unlocked("fishing") and Inventory.has_fishing_rod
	if Inventory.BakeryData.RECIPES.has(item):
		return Inventory.owns_bakery
	if item == "egg":
		return Inventory.owns_feed_mill and Inventory.owns_chicken_coop and Inventory.chicken_count > 0
	if item == "milk":
		return Inventory.owns_feed_mill and Inventory.owns_cow_shed and Inventory.cow_count > 0
	return true


func ensure_available_orders() -> void:
	var changed: bool = false
	for index in range(orders.size()):
		if not _is_valid_order(orders[index]):
			orders[index] = _generate_order()
			changed = true
	if changed:
		orders_changed.emit()


func restore_orders(saved: Variant, saved_next_id: int = 1) -> void:
	orders.clear()
	next_order_id = maxi(next_order_id, saved_next_id)
	var used_ids: Array = []
	if saved is Array:
		# Find the largest saved ID before generating any replacements.
		for entry in saved:
			if entry is Dictionary and entry.get("order_id", "") is String:
				var suffix: String = entry.get("order_id", "").trim_prefix("order_")
				if suffix.is_valid_int():
					next_order_id = maxi(next_order_id, suffix.to_int() + 1)
	for index in range(ORDER_COUNT):
		var order: Dictionary = {}
		if saved is Array and index < saved.size():
			if _is_valid_order(saved[index]):
				if saved[index]["order_id"] not in used_ids:
					order = saved[index].duplicate(true)
		if order.is_empty():
			order = _generate_order()
		orders.append(order)
		used_ids.append(order["order_id"])
	orders_changed.emit()


func reset_orders() -> void:
	next_order_id = 1
	restore_orders([])


func _generate_order() -> Dictionary:
	var items: Dictionary = item_info()
	var available: Array = []
	for item in items:
		if item_available(item):
			available.append(item)
	var requirements: Dictionary = {}
	var total_price: int = 0
	var total_exp: int = 0
	var item_types: int = rng.randi_range(1, mini(2, available.size()))
	for index in range(item_types):
		var choice: int = rng.randi_range(0, available.size() - 1)
		var item: String = available.pop_at(choice)
		var amount: int = rng.randi_range(1, 3 if item == "egg" else 4)
		if Inventory.FishingData.FISH.has(item):
			amount = rng.randi_range(1, Inventory.FishingData.FISH[item]["order_max"])
		requirements[item] = amount
		total_price += items[item]["price"] * amount
		total_exp += items[item]["exp"] * amount
	var order: Dictionary = {
		"order_id": "order_%d" % next_order_id,
		"requirements": requirements,
		"coin_reward": rng.randi_range(ceili(total_price * 1.25), floori(total_price * 1.5)),
		"exp_reward": ceili(total_exp * rng.randf_range(1.1, 1.25))
	}
	next_order_id += 1
	return order


func complete_order(order_id: String) -> bool:
	for index in range(orders.size()):
		var order: Dictionary = orders[index]
		if order["order_id"] != order_id:
			continue
		if not _is_valid_order(order):
			return false
		# Check every requirement first; a failed order changes nothing.
		for item in order["requirements"]:
			if Inventory.get(item) < order["requirements"][item]:
				return false
		for item in order["requirements"]:
			Inventory.set(item, Inventory.get(item) - order["requirements"][item])
		Inventory.coins += order["coin_reward"]
		Inventory.player_exp += order["exp_reward"]
		Inventory.normalize_exp()
		# Replace first, then one signal saves items, rewards and new order together.
		orders[index] = _generate_order()
		Inventory.inventory_changed.emit()
		orders_changed.emit()
		return true
	return false


func _is_valid_order(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var id = value.get("order_id", "")
	if not (id is String) or not id.begins_with("order_") or not id.trim_prefix("order_").is_valid_int():
		return false
	var requirements = value.get("requirements", {})
	if not (requirements is Dictionary) or requirements.is_empty():
		return false
	var silo_required: int = 0
	var barn_required: int = 0
	for item in requirements:
		if not item is String or not item_available(item):
			return false
		if not (requirements[item] is int) or requirements[item] <= 0:
			return false
		if Inventory.FishingData.FISH.has(item) and requirements[item] > Inventory.FishingData.FISH[item]["order_max"]:
			return false
		if item in Inventory.SILO_ITEMS:
			if requirements[item] > Inventory.silo_capacity:
				return false
			silo_required += requirements[item]
		elif item in Inventory.BARN_ITEMS:
			if requirements[item] > Inventory.barn_capacity:
				return false
			barn_required += requirements[item]
	if silo_required > Inventory.silo_capacity or barn_required > Inventory.barn_capacity:
		return false
	for key in ["coin_reward", "exp_reward"]:
		var reward = value.get(key, -1)
		# Some existing processed goods grant zero EXP; those orders remain valid.
		if not (reward is int) or reward < (1 if key == "coin_reward" else 0):
			return false
	return true
