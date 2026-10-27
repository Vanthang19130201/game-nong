extends Node

signal orders_changed
signal order_completed(coins: int, experience: int)

const CropData = preload("res://crop_data.gd")
const ORDER_COUNT: int = 3
const Data = preload("res://order_data.gd")

var orders: Array = []
var next_order_id: int = 1
var rng := RandomNumberGenerator.new()
var busy: bool = false
var cooldown_timer: Timer


func _ready() -> void:
	rng.randomize()
	Inventory.inventory_changed.connect(ensure_available_orders)
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = 1.0
	cooldown_timer.timeout.connect(_check_cooldowns)
	add_child(cooldown_timer)

func _recipe_sources() -> Dictionary:
	return {"bakery":Inventory.BakeryData.RECIPES,"dairy":Inventory.DairyData.RECIPES,"spinning_machine":Inventory.SpinningData.RECIPES}


func item_info() -> Dictionary:
	var items: Dictionary = {}
	for recipes in _recipe_sources().values():
		for item in recipes:
			var recipe: Dictionary = recipes[item]
			items[item] = {"name":recipe["name"],"level":recipe["level"],"price":maxi(Inventory.sell_price(item),recipe.get("order_price",recipe.get("price",0))),"exp":0,"category":"product"}
	for crop in CropData.CROPS:
		var info: Dictionary = CropData.CROPS[crop]
		items[crop.to_lower()] = {
			"name": info["name"], "level": info["unlock_level"],
			"price": info["sell_price"], "exp": info["harvest_exp"], "category":"crop"
		}
	items["egg"] = {"name":"Egg","level":Inventory.Progression.PRODUCTS["chicken_coop"]["level"],"price":Inventory.EGG_PRICE,"exp":5,"category":"animal"}
	items["milk"] = {"name":"Milk","level":Inventory.Progression.PRODUCTS["cow_shed"]["level"],"price":Inventory.MILK_PRICE,"exp":10,"category":"animal"}
	for fish in Inventory.FishingData.FISH:
		var info: Dictionary = Inventory.FishingData.FISH[fish]
		items[fish] = {"name":info["name"],"level":Inventory.FarmData.FISHING_LEVEL,"price":info["sell_price"],"exp":info["order_exp"],"category":"fish"}
	return items


func item_available(item: String) -> bool:
	return _item_available(item,item_info(),[])

func _item_available(item: String, items: Dictionary, visiting: Array) -> bool:
	if not items.has(item) or Inventory.player_level < items[item]["level"] or item in visiting:
		return false
	if (item not in Inventory.SILO_ITEMS and item not in Inventory.BARN_ITEMS) or items[item]["price"] <= 0:
		return false
	if Inventory.FishingData.FISH.has(item):
		return Inventory.is_zone_unlocked("fishing") and Inventory.has_fishing_rod
	var sources: Dictionary = _recipe_sources()
	for building in sources:
		if not sources[building].has(item):
			continue
		if not Inventory.owns_building(building) or Inventory.player_level < Inventory.Progression.BUILDINGS[building]["level"]:
			return false
		var path: Array = visiting.duplicate()
		path.append(item)
		for ingredient in sources[building][item]["requirements"]:
			if not _item_available(ingredient,items,path):
				return false
		return true
	if item == "egg":
		return Inventory.owns_feed_mill and Inventory.owns_chicken_coop and Inventory.chicken_count > 0
	if item == "milk":
		return Inventory.owns_feed_mill and Inventory.owns_cow_shed and Inventory.cow_count > 0
	return true


func ensure_available_orders() -> bool:
	if busy:
		return false
	var changed: bool = false
	for index in range(orders.size()):
		var order = orders[index]
		if is_waiting(order) and cooldown_remaining(order) > 0:
			continue
		if is_waiting(order) or not _is_valid_order(order):
			orders[index] = _generate_order()
			changed = true
	_sync_cooldown_timer()
	if changed:
		orders_changed.emit()
	return changed

func is_waiting(value: Variant) -> bool:
	if not value is Dictionary or value.get("state") != "WAITING":
		return false
	var id = value.get("order_id","")
	var deadline = value.get("cooldown_until")
	return id is String and id.begins_with("order_") and id.trim_prefix("order_").is_valid_int() and (deadline is int or deadline is float) and is_finite(deadline) and deadline > 0 and deadline <= 1000000000000.0

func cooldown_remaining(order: Dictionary) -> int:
	return maxi(0,ceili(order.get("cooldown_until",0.0)-Time.get_unix_time_from_system()))

func _sync_cooldown_timer() -> void:
	if not is_instance_valid(cooldown_timer):
		return
	if orders.any(is_waiting):
		if cooldown_timer.is_stopped():
			cooldown_timer.start()
	else:
		cooldown_timer.stop()

func _check_cooldowns() -> void:
	if busy:
		return
	if ensure_available_orders():
		SaveManager.save_game()
	else:
		# Cards update their countdown only; existing item/button nodes are reused.
		orders_changed.emit()

func cancel_order(order_id: String) -> bool:
	if busy:
		return false
	for index in range(orders.size()):
		var order: Dictionary = orders[index]
		if order.get("order_id") != order_id or not _is_valid_order(order):
			continue
		busy = true
		orders[index] = {"order_id":order_id,"state":"WAITING","difficulty":order.get("difficulty","EASY"),"cooldown_until":Time.get_unix_time_from_system()+Data.CANCEL_COOLDOWN}
		_sync_cooldown_timer()
		SaveManager.save_game()
		busy = false
		orders_changed.emit()
		return true
	return false


func restore_orders(saved: Variant, saved_next_id: int = 1) -> void:
	busy = false
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
			if _is_valid_order(saved[index]) or (is_waiting(saved[index]) and cooldown_remaining(saved[index]) > 0):
				if saved[index]["order_id"] not in used_ids:
					order = saved[index].duplicate(true)
					# Legacy active orders keep their exact requirements/rewards.
					if not order.has("difficulty"):
						order["difficulty"] = "EASY"
		if order.is_empty():
			order = _generate_order()
		orders.append(order)
		used_ids.append(order["order_id"])
	_sync_cooldown_timer()
	orders_changed.emit()


func reset_orders() -> void:
	next_order_id = 1
	restore_orders([])


func _pick_weighted(choices: Dictionary) -> String:
	var total: int = 0
	for weight in choices.values():
		total += weight
	var roll: int = rng.randi_range(1,total)
	for choice in choices:
		roll -= choices[choice]
		if roll <= 0:
			return choice
	return ""

func _pick_difficulty() -> String:
	var choices: Dictionary = {}
	for tier in Data.TIERS:
		if Inventory.player_level >= Data.TIERS[tier]["level"]:
			choices[tier] = Data.TIERS[tier]["weight"]
	return _pick_weighted(choices)

func _generate_order(difficulty: String = "") -> Dictionary:
	if not Data.TIERS.has(difficulty) or Inventory.player_level < Data.TIERS[difficulty]["level"]:
		difficulty = _pick_difficulty()
	var tier: Dictionary = Data.TIERS[difficulty]
	var items: Dictionary = item_info()
	var available: Dictionary = {}
	for item in items:
		if _item_available(item,items,[]):
			var category: String = items[item]["category"]
			available[item] = 8 if category == "crop" and Inventory.player_level < 6 else (5 if category == "crop" else (1 if category == "fish" else 3))
	var requirements: Dictionary = {}
	var total_price: int = 0
	var total_exp: int = 0
	var capacities: Dictionary = {"silo":Inventory.silo_capacity,"barn":Inventory.barn_capacity}
	var item_types: int = mini(available.size(),rng.randi_range(tier["types_min"],tier["types_max"]))
	for index in range(item_types):
		for candidate in available.keys():
			if capacities["silo" if candidate in Inventory.SILO_ITEMS else "barn"] < 1:
				available.erase(candidate)
		if available.is_empty():
			break
		var item: String = _pick_weighted(available)
		available.erase(item)
		var crop: bool = items[item]["category"] == "crop"
		var storage: String = "silo" if crop else "barn"
		var maximum: int = mini(capacities[storage],tier["crop_max"] if crop else tier["product_max"])
		if Inventory.FishingData.FISH.has(item):
			maximum = mini(maximum,Inventory.FishingData.FISH[item]["order_max"])
		var minimum: int = mini(maximum,tier["crop_min"] if crop else tier["product_min"])
		var amount: int = rng.randi_range(minimum,maximum)
		requirements[item] = amount
		capacities[storage] -= amount
		total_price += items[item]["price"] * amount
		total_exp += maxi(3,items[item]["exp"]+ceili(items[item]["price"]*0.1))*amount
	var order: Dictionary = {
		"order_id": "order_%d" % next_order_id,
		"requirements": requirements,
		"difficulty": difficulty,
		"coin_reward": ceili(total_price*tier["coins"]),
		"exp_reward": maxi(1,ceili(total_exp*tier["exp"]))
	}
	next_order_id += 1
	return order


func complete_order(order_id: String) -> bool:
	if busy:
		return false
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
		if Inventory.coins > 9223372036854775807-order["coin_reward"] or Inventory.player_exp > 9223372036854775807-order["exp_reward"]:
			return false
		busy = true
		for item in order["requirements"]:
			Inventory.set(item, Inventory.get(item) - order["requirements"][item])
		Inventory.coins += order["coin_reward"]
		Inventory.player_exp += order["exp_reward"]
		Inventory.normalize_exp()
		# Replace first, then one signal saves items, rewards and new order together.
		orders[index] = _generate_order()
		Inventory.inventory_changed.emit()
		busy = false
		orders_changed.emit()
		order_completed.emit(order["coin_reward"],order["exp_reward"])
		return true
	return false

func can_complete_order(order_id: String) -> bool:
	if busy:
		return false
	for order in orders:
		if order.get("order_id") == order_id and _is_valid_order(order):
			for item in order["requirements"]:
				if Inventory.get(item) < order["requirements"][item]:
					return false
			return true
	return false


func _is_valid_order(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	if value.get("state","ACTIVE") != "ACTIVE" or value.get("difficulty","EASY") not in Data.TIERS:
		return false
	if Inventory.player_level < Data.TIERS[value.get("difficulty","EASY")]["level"]:
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
