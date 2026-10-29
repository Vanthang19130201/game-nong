extends Node

signal changed(event_id: String)
signal merchant_changed

const EventData = preload("res://farm_event_data.gd")
const WeatherData = preload("res://weather_data.gd")
const SafePlacement = preload("res://safe_world_placement.gd")
const TreasureData = preload("res://treasure_data.gd")
const DecorationData = preload("res://decoration_data.gd")

# The merchant is a daily chance encounter: exactly one chance in three.
const MERCHANT_APPEAR_CHANCE: float = 1.0 / 3.0

# Limited, deterministic merchant exchanges. They reuse the daily stock and
# existing transaction path instead of introducing a second shop system.
const MERCHANT_EXCHANGES: Dictionary = {
	"lost_lure_loach": {
		"display_item": "lost_lure",
		"requirements": {"lost_lure": 1},
		"reward": {"type": "item", "item": "loach", "amount": 1}
	},
	"river_relic_bundle": {
		"display_item": "old_bottle",
		"requirements": {"old_bottle": 1, "old_boot": 1},
		"reward": {"type": "coins", "amount": 90}
	},
	"ancient_coin_treasure": {
		"display_item": "ancient_coin",
		"requirements": {"ancient_coin": 3},
		# Receiving any Ancient Coin already unlocks its display cosmetic. Trading
		# three therefore yields an existing chest instead of a permanently
		# disabled duplicate-cosmetic offer.
		"reward": {"type": "item", "item": "small_chest", "amount": 1}
	}
}
var current_event_id: String = ""
var current_day_key: int = 0
var event_position: Vector2 = Vector2.ZERO
var event_collected: bool = false
var event_reward: Dictionary = {}
var last_collected_reward: Dictionary = {}
var _farm: Node2D
var merchant_active := false
var merchant_day_key: int = -1
var merchant_position: Vector2 = Vector2.ZERO
var merchant_stock: Array = []
var merchant_busy := false
var last_merchant_exchange: Dictionary = {}

func _ready() -> void:
	current_day_key = WeatherData.day_key()
	GameClock.changed.connect(_on_clock_changed)

func setup(farm_root: Node2D) -> void:
	_farm = farm_root
	if not current_event_id.is_empty() and (event_position == Vector2.ZERO or not SafePlacement.is_clear(_farm, event_position, Vector2(52, 40), 58.0)):
		event_position = _choose_position(current_day_key)
		SaveManager.save_game.call_deferred()
	# Keep a rolled daily absence stable. A day is only rolled again when it is
	# new, or when a saved active merchant lacks its stock/meeting point.
	var merchant_today: int = WeatherData.day_key()
	if merchant_day_key != merchant_today or merchant_active and (merchant_stock.is_empty() or merchant_position == Vector2.ZERO):
		_roll_merchant_for_day(merchant_today)
	if merchant_active:
		# Keep the merchant beside the Order Board instead of the market stall.
		# Re-evaluate once during setup so an already-saved daily merchant moves
		# to the new meeting point immediately.
		var merchant_meeting_point: Vector2 = _choose_merchant_position()
		if merchant_meeting_point != Vector2.ZERO and merchant_position != merchant_meeting_point:
			merchant_position = merchant_meeting_point
			SaveManager.save_game.call_deferred()
	changed.emit(current_event_id)
	merchant_changed.emit()


func detach_farm() -> void:
	# Farm is scene-owned; never keep an old world through a menu transition.
	_farm = null

func is_active(event_id: String) -> bool:
	return current_event_id == event_id

func get_save_data() -> Dictionary:
	return {"event_id": current_event_id, "day_key": current_day_key, "position": event_position, "collected": event_collected, "event_reward":event_reward.duplicate(true), "merchant_active":merchant_active, "merchant_day_key":merchant_day_key, "merchant_position":merchant_position, "merchant_stock":merchant_stock.duplicate(true)}

func restore(data: Variant) -> void:
	var key := WeatherData.day_key()
	if data is Dictionary and int(data.get("day_key", -1)) == key:
		var id := str(data.get("event_id", ""))
		current_event_id = id if id.is_empty() or EventData.EVENTS.has(id) else ""
		current_day_key = key
		var position: Variant = data.get("position", Vector2.ZERO)
		event_position = position if position is Vector2 and position.is_finite() else Vector2.ZERO
		event_collected = data.get("collected", false) == true
		var saved_reward: Variant = data.get("event_reward", {})
		event_reward = _sanitize_event_reward(saved_reward) if current_event_id == "lost_crate" else {}
		# Legacy saves used a fixed bottle. Derive once from the same saved day so
		# loading cannot reroll a crate reward.
		if current_event_id == "lost_crate" and event_reward.is_empty():
			event_reward = _roll_lost_crate_reward(current_day_key)
		merchant_day_key = int(data.get("merchant_day_key", -1))
		merchant_active = data.get("merchant_active", false) == true and merchant_day_key == key
		var merchant_pos: Variant = data.get("merchant_position", Vector2.ZERO)
		merchant_position = merchant_pos if merchant_pos is Vector2 and merchant_pos.is_finite() else Vector2.ZERO
		merchant_stock = _sanitize_merchant_stock(data.get("merchant_stock", []))
	else:
		_roll_for_day(key)
		merchant_day_key = -1
		merchant_stock.clear()
	changed.emit(current_event_id)

func reset() -> void:
	_farm = null
	current_event_id = ""
	current_day_key = WeatherData.day_key()
	event_position = Vector2.ZERO
	event_collected = false
	event_reward.clear()
	last_collected_reward.clear()
	merchant_active = false
	merchant_day_key = WeatherData.day_key()
	merchant_position = Vector2.ZERO
	merchant_stock.clear()
	merchant_busy = false
	last_merchant_exchange.clear()
	changed.emit(current_event_id)
	merchant_changed.emit()

func refresh_for_new_game() -> void:
	_roll_for_day(WeatherData.day_key())
	changed.emit(current_event_id)
	merchant_changed.emit()

func discover_current_event() -> void:
	if not current_event_id.is_empty():
		DiscoveryManager.discover("special_events", current_event_id)
		if current_event_id == "mushroom_growth":
			DiscoveryManager.discover("nature", "mushroom")
		elif current_event_id == "butterfly_day":
			DiscoveryManager.discover("nature", "butterfly")
		elif current_event_id == "firefly_night":
			DiscoveryManager.discover("nature", "firefly")

func collect_current_event() -> bool:
	if event_collected or current_event_id not in ["fallen_branch", "lost_crate"]:
		return false
	var old_wood := Inventory.wood
	var old_coins := Inventory.coins
	var reward: Dictionary = {"type":"item", "item":"old_bottle", "amount":1} if current_event_id == "lost_crate" else {"type":"wood", "amount":2}
	if current_event_id == "lost_crate" and not event_reward.is_empty():
		reward = event_reward.duplicate(true)
	var reward_type := str(reward.get("type", ""))
	var reward_item := str(reward.get("item", ""))
	var reward_amount := maxi(1, int(reward.get("amount", 1)))
	var old_item_count: int = Inventory.get(reward_item) if reward_type == "item" else 0
	var old_discovered := DiscoveryManager.get_save_data()
	if current_event_id == "fallen_branch":
		Inventory.wood += reward_amount
	elif reward_type == "coins":
		if Inventory.coins > 9223372036854775807 - reward_amount:
			return false
		Inventory.coins += reward_amount
	else:
		if reward_type != "item" or not Inventory.add_item(reward_item, reward_amount, false):
			return false
	event_collected = true
	discover_current_event()
	if not SaveManager.save_game():
		Inventory.wood = old_wood
		Inventory.coins = old_coins
		if reward_type == "item":
			Inventory.set(reward_item, old_item_count)
		event_collected = false
		DiscoveryManager.restore(old_discovered)
		return false
	last_collected_reward = reward.duplicate(true)
	Inventory.inventory_changed.emit()
	return true

func _on_clock_changed() -> void:
	var key := WeatherData.day_key()
	if key == current_day_key:
		return
	_roll_for_day(key)
	changed.emit(current_event_id)
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()

func _roll_for_day(key: int) -> void:
	current_day_key = key
	current_event_id = ""
	event_position = Vector2.ZERO
	event_collected = false
	event_reward.clear()
	last_collected_reward.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x45564E54 + key * 3571
	_roll_merchant_for_day(key)
	if rng.randf() >= EventData.EVENT_CHANCE:
		return
	var total := 0
	for data in EventData.EVENTS.values():
		total += int(data["weight"])
	var roll := rng.randi_range(1, total)
	for id in EventData.EVENTS:
		roll -= int(EventData.EVENTS[id]["weight"])
		if roll <= 0:
			current_event_id = id
			break
	if current_event_id == "lost_crate":
		event_reward = _roll_lost_crate_reward(key)
	if not current_event_id.is_empty() and is_instance_valid(_farm):
		event_position = _choose_position(key)


func _roll_lost_crate_reward(day_key: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4C4F535443524154 + day_key * 4099
	var roll := rng.randf()
	if roll < 0.35:
		return {"type":"coins", "amount":rng.randi_range(45, 110)}
	if roll < 0.57:
		var seeds: Array[String] = []
		for crop_id in Inventory.CropData.CROPS:
			if Inventory.is_unlocked(crop_id):
				seeds.append(crop_id.to_lower() + "_seed")
		return {"type":"item", "item":seeds[rng.randi_range(0, seeds.size() - 1)] if not seeds.is_empty() else "wheat_seed", "amount":1}
	if roll < 0.85:
		var common: Array[String] = ["old_bottle", "coin_pouch", "lost_lure"]
		return {"type":"item", "item":common[rng.randi_range(0, common.size() - 1)], "amount":1}
	if roll < 0.97:
		return {"type":"item", "item":"small_chest", "amount":1}
	# The crate has reached its rare reward lane. The centralized table performs
	# the only 1% Ultra Rare gem check and this chosen result is saved with the day.
	return {"type":"item", "item":TreasureData.roll_rare_container(rng), "amount":1}


func _sanitize_event_reward(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var reward_type := str(value.get("type", ""))
	var amount := int(value.get("amount", 0))
	if amount < 1 or amount > 10000:
		return {}
	if reward_type == "coins":
		return {"type":"coins", "amount":amount}
	if reward_type == "item":
		var item := str(value.get("item", ""))
		if item in Inventory.SILO_ITEMS or item in Inventory.BARN_ITEMS:
			return {"type":"item", "item":item, "amount":amount}
	return {}

func _roll_merchant_for_day(key: int) -> void:
	merchant_day_key = key
	merchant_active = false
	merchant_position = Vector2.ZERO
	merchant_stock.clear()
	merchant_busy = false
	last_merchant_exchange.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4D455243 + key * 1877
	if rng.randf() >= MERCHANT_APPEAR_CHANCE:
		merchant_changed.emit()
		return
	merchant_active = true
	merchant_stock = _make_merchant_stock(rng)
	merchant_position = _choose_merchant_position()
	merchant_changed.emit()

func _make_merchant_stock(rng: RandomNumberGenerator) -> Array:
	var stock: Array = [{"item":"mystery_seed", "price":35, "quantity":2}]
	var crops: Array[String] = []
	for crop in Inventory.CropData.CROPS:
		if Inventory.is_unlocked(crop):
			crops.append(crop)
	if not crops.is_empty():
		var crop_id: String = crops[rng.randi_range(0, crops.size() - 1)].to_lower()
		var crop_price: int = int(Inventory.CropData.CROPS[crop_id.to_upper()]["seed_buy_price"])
		stock.append({"item":crop_id + "_seed", "price":crop_price, "quantity":rng.randi_range(2, 4)})
	# Three fixed exchange offers keep the daily merchant compact, readable and
	# save-stable while connecting treasure to Fishing, Coins and other treasure.
	for exchange_id in ["lost_lure_loach", "river_relic_bundle", "ancient_coin_treasure"]:
		stock.append(_exchange_entry(exchange_id, 1))
	return stock

func _choose_merchant_position() -> Vector2:
	if not is_instance_valid(_farm):
		return Vector2.ZERO
	var order_board: Node2D = _farm.get_node_or_null("OrderBoard") as Node2D
	var center: Vector2 = order_board.global_position if is_instance_valid(order_board) else Vector2(920, 420)
	# Place the trader beside the Order Board, where every player regularly
	# visits. Safe points are preferred so the character does not cover another
	# interactable; the final point remains deliberate and visible even on a
	# crowded/legacy farm where placement probes reject every candidate.
	var offsets: Array[Vector2] = [Vector2(128, 96), Vector2(-128, 96), Vector2(112, -96), Vector2(-112, -96), Vector2(160, 32), Vector2(-160, 32)]
	for offset in offsets:
		var point: Vector2 = (center + offset).snapped(Vector2(16, 16))
		if SafePlacement.is_clear(_farm, point, Vector2(38, 54), 36.0):
			return point
	return (center + Vector2(128, 96)).snapped(Vector2(16, 16))

func _sanitize_merchant_stock(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if not entry is Dictionary:
			continue
		if str(entry.get("kind", "buy")) == "exchange":
			var exchange_id := str(entry.get("exchange_id", ""))
			var exchange_quantity := int(entry.get("quantity", -1))
			if MERCHANT_EXCHANGES.has(exchange_id) and exchange_quantity >= 0 and exchange_quantity <= 1:
				result.append(_exchange_entry(exchange_id, exchange_quantity))
			continue
		var item: String = str(entry.get("item", ""))
		var price: int = int(entry.get("price", 0))
		var quantity: int = int(entry.get("quantity", -1))
		if item not in Inventory.SILO_ITEMS and item not in Inventory.BARN_ITEMS:
			continue
		if price <= 0 or quantity < 0 or quantity > 20:
			continue
		result.append({"item":item, "price":price, "quantity":quantity})
	return result.slice(0, 5)


func _exchange_entry(exchange_id: String, quantity: int) -> Dictionary:
	var data: Dictionary = MERCHANT_EXCHANGES[exchange_id]
	return {
		"kind": "exchange",
		"exchange_id": exchange_id,
		"display_item": data["display_item"],
		"quantity": clampi(quantity, 0, 1)
	}


func merchant_entry_text(entry: Dictionary) -> String:
	if str(entry.get("kind", "buy")) != "exchange":
		return tr("MERCHANT_STOCK_ROW") % [Localization.display_name(str(entry.get("item", ""))), int(entry.get("price", 0)), int(entry.get("quantity", 0))]
	var exchange_id := str(entry.get("exchange_id", ""))
	if not MERCHANT_EXCHANGES.has(exchange_id):
		return ""
	var data: Dictionary = MERCHANT_EXCHANGES[exchange_id]
	return tr("MERCHANT_EXCHANGE_ROW") % [_format_requirements(data["requirements"]), _format_exchange_reward(data["reward"]), int(entry.get("quantity", 0))]


func _format_requirements(requirements: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item in requirements:
		parts.append("%s ×%d" % [Localization.display_name(str(item)), int(requirements[item])])
	return " + ".join(parts)


func _format_exchange_reward(reward: Dictionary) -> String:
	match str(reward.get("type", "")):
		"coins":
			return tr("UI_PRICE_COINS") % int(reward.get("amount", 0))
		"item":
			return "%s ×%d" % [Localization.display_name(str(reward.get("item", ""))), int(reward.get("amount", 1))]
		"cosmetic":
			var decoration: Dictionary = DecorationData.TYPES.get(str(reward.get("decoration", "")), {})
			return tr(str(decoration.get("name_key", "")))
	return ""


func can_exchange_stock(index: int) -> bool:
	if merchant_busy or not merchant_active or index < 0 or index >= merchant_stock.size():
		return false
	var entry: Dictionary = merchant_stock[index]
	if str(entry.get("kind", "buy")) != "exchange" or int(entry.get("quantity", 0)) <= 0:
		return false
	var exchange_id := str(entry.get("exchange_id", ""))
	if not MERCHANT_EXCHANGES.has(exchange_id):
		return false
	var data: Dictionary = MERCHANT_EXCHANGES[exchange_id]
	for item in data["requirements"]:
		if Inventory.get(item) < int(data["requirements"][item]):
			return false
	var reward: Dictionary = data["reward"]
	match str(reward.get("type", "")):
		"coins":
			return Inventory.coins <= 9223372036854775807 - int(reward.get("amount", 0))
		"item":
			return _can_receive_exchange_item(str(reward.get("item", "")), int(reward.get("amount", 0)), data["requirements"])
		"cosmetic":
			var decoration_id := str(reward.get("decoration", ""))
			return DecorationData.TYPES.has(decoration_id) and decoration_id not in DiscoveryManager.unlocked_cosmetics
	return false


func _can_receive_exchange_item(item: String, amount: int, requirements: Dictionary) -> bool:
	if amount <= 0:
		return false
	if item in Inventory.SILO_ITEMS:
		var released_silo := 0
		for source in requirements:
			if source in Inventory.SILO_ITEMS:
				released_silo += int(requirements[source])
		return Inventory.storage_used("silo") - released_silo + amount <= Inventory.silo_capacity
	if item in Inventory.BARN_ITEMS:
		var released_barn := 0
		for source in requirements:
			if source in Inventory.BARN_ITEMS:
				released_barn += int(requirements[source])
		return Inventory.storage_used("barn") - released_barn + Inventory.reserved_barn_slots + amount <= Inventory.barn_capacity
	return false


func exchange_merchant_stock(index: int) -> bool:
	if not can_exchange_stock(index):
		return false
	merchant_busy = true
	var entry: Dictionary = merchant_stock[index]
	var exchange_id := str(entry["exchange_id"])
	var data: Dictionary = MERCHANT_EXCHANGES[exchange_id]
	var requirements: Dictionary = data["requirements"]
	var reward: Dictionary = data["reward"]
	var old_counts: Dictionary = {}
	for item in requirements:
		old_counts[item] = Inventory.get(item)
	var reward_item := str(reward.get("item", ""))
	if str(reward.get("type", "")) == "item" and not old_counts.has(reward_item):
		old_counts[reward_item] = Inventory.get(reward_item)
	var old_coins := Inventory.coins
	var old_discovery := DiscoveryManager.get_save_data()
	var old_stock: Array = merchant_stock.duplicate(true)
	for item in requirements:
		Inventory.set(item, Inventory.get(item) - int(requirements[item]))
	var cosmetic_unlocked := ""
	match str(reward.get("type", "")):
		"coins":
			Inventory.coins += int(reward["amount"])
		"item":
			if not Inventory.add_item(reward_item, int(reward["amount"]), false):
				for item in old_counts:
					Inventory.set(item, old_counts[item])
				merchant_busy = false
				return false
		"cosmetic":
			cosmetic_unlocked = str(reward.get("decoration", ""))
			if not DiscoveryManager.unlock_cosmetic(cosmetic_unlocked, false):
				for item in old_counts:
					Inventory.set(item, old_counts[item])
				merchant_busy = false
				return false
	merchant_stock[index]["quantity"] -= 1
	if not SaveManager.save_game():
		for item in old_counts:
			Inventory.set(item, old_counts[item])
		Inventory.coins = old_coins
		DiscoveryManager.restore(old_discovery)
		merchant_stock = old_stock
		merchant_busy = false
		return Inventory.fail(tr("ERROR_SAVE_FAILED"))
	last_merchant_exchange = {"requirements": requirements.duplicate(true), "reward": reward.duplicate(true)}
	merchant_busy = false
	if not cosmetic_unlocked.is_empty():
		DiscoveryManager.cosmetic_unlocked.emit(cosmetic_unlocked)
	Inventory.inventory_changed.emit()
	merchant_changed.emit()
	return true

func buy_merchant_stock(index: int) -> bool:
	if merchant_busy or not merchant_active or index < 0 or index >= merchant_stock.size():
		return false
	var stock: Dictionary = merchant_stock[index]
	var item: String = stock["item"]
	var price: int = int(stock["price"])
	if stock["quantity"] <= 0:
		return false
	if Inventory.coins < price:
		return Inventory.fail(tr("TRADE_NO_COINS"))
	if not Inventory.can_add_item(item, 1):
		return Inventory.fail(tr("ERROR_STORAGE"))
	merchant_busy = true
	var old_coins: int = Inventory.coins
	var old_item_count: int = Inventory.get(item)
	var old_discovery: Dictionary = DiscoveryManager.get_save_data()
	var old_stock: Array = merchant_stock.duplicate(true)
	Inventory.coins -= price
	if not Inventory.add_item(item, 1, false):
		Inventory.coins = old_coins
		merchant_busy = false
		return false
	merchant_stock[index]["quantity"] -= 1
	if not SaveManager.save_game():
		Inventory.coins = old_coins
		Inventory.set(item, old_item_count)
		DiscoveryManager.restore(old_discovery)
		merchant_stock = old_stock
		merchant_busy = false
		return false
	merchant_busy = false
	Inventory.inventory_changed.emit()
	merchant_changed.emit()
	return true

func _choose_position(key: int) -> Vector2:
	if not is_instance_valid(_farm):
		return Vector2.ZERO
	var candidates: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4556504F + key * 733
	for zone_id in SaveManager.unlocked_land_zones:
		if not SaveManager.LandData.ZONES.has(zone_id):
			continue
		var area: Rect2 = SaveManager.LandData.ZONES[zone_id]["area"]
		for _sample in range(16):
			var point := Vector2(
				rng.randf_range(area.position.x + 96.0, area.end.x - 96.0),
				rng.randf_range(area.position.y + 96.0, area.end.y - 96.0)
			).snapped(Vector2(16, 16))
			if SafePlacement.is_clear(_farm, point, Vector2(52, 40), 58.0):
				candidates.append(point)
	if candidates.is_empty():
		return Vector2.ZERO
	return candidates[rng.randi_range(0, candidates.size() - 1)]
