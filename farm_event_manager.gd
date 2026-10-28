extends Node

signal changed(event_id: String)
signal merchant_changed

const EventData = preload("res://farm_event_data.gd")
const WeatherData = preload("res://weather_data.gd")
const SafePlacement = preload("res://safe_world_placement.gd")
var current_event_id: String = ""
var current_day_key: int = 0
var event_position: Vector2 = Vector2.ZERO
var event_collected: bool = false
var _farm: Node2D
var merchant_active := false
var merchant_day_key: int = -1
var merchant_position: Vector2 = Vector2.ZERO
var merchant_stock: Array = []
var merchant_busy := false

func _ready() -> void:
	current_day_key = WeatherData.day_key()
	GameClock.changed.connect(_on_clock_changed)

func setup(farm_root: Node2D) -> void:
	_farm = farm_root
	if not current_event_id.is_empty() and (event_position == Vector2.ZERO or not SafePlacement.is_clear(_farm, event_position, Vector2(52, 40), 58.0)):
		event_position = _choose_position(current_day_key)
		SaveManager.save_game.call_deferred()
	if merchant_day_key != WeatherData.day_key() or merchant_stock.is_empty() and merchant_active:
		_roll_merchant_for_day(WeatherData.day_key())
	if merchant_active and (merchant_position == Vector2.ZERO or not SafePlacement.is_clear(_farm, merchant_position, Vector2(38, 54), 36.0)):
		merchant_position = _choose_merchant_position()
	changed.emit(current_event_id)
	merchant_changed.emit()

func is_active(event_id: String) -> bool:
	return current_event_id == event_id

func get_save_data() -> Dictionary:
	return {"event_id": current_event_id, "day_key": current_day_key, "position": event_position, "collected": event_collected, "merchant_active":merchant_active, "merchant_day_key":merchant_day_key, "merchant_position":merchant_position, "merchant_stock":merchant_stock.duplicate(true)}

func restore(data: Variant) -> void:
	var key := WeatherData.day_key()
	if data is Dictionary and int(data.get("day_key", -1)) == key:
		var id := str(data.get("event_id", ""))
		current_event_id = id if id.is_empty() or EventData.EVENTS.has(id) else ""
		current_day_key = key
		var position: Variant = data.get("position", Vector2.ZERO)
		event_position = position if position is Vector2 and position.is_finite() else Vector2.ZERO
		event_collected = data.get("collected", false) == true
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
	current_event_id = ""
	current_day_key = WeatherData.day_key()
	event_position = Vector2.ZERO
	event_collected = false
	merchant_active = false
	merchant_day_key = WeatherData.day_key()
	merchant_position = Vector2.ZERO
	merchant_stock.clear()
	merchant_busy = false
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
	var old_bottle := Inventory.old_bottle
	var old_discovered := DiscoveryManager.get_save_data()
	if current_event_id == "fallen_branch":
		Inventory.wood += 2
	else:
		if not Inventory.add_item("old_bottle", 1, false):
			return false
	event_collected = true
	discover_current_event()
	if not SaveManager.save_game():
		Inventory.wood = old_wood
		Inventory.old_bottle = old_bottle
		event_collected = false
		DiscoveryManager.restore(old_discovered)
		return false
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
	if not current_event_id.is_empty() and is_instance_valid(_farm):
		event_position = _choose_position(key)

func _roll_merchant_for_day(key: int) -> void:
	merchant_day_key = key
	merchant_active = false
	merchant_position = Vector2.ZERO
	merchant_stock.clear()
	merchant_busy = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4D455243 + key * 1877
	if rng.randf() >= 0.16:
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
	var treasure_pool: Array[String] = ["old_bottle", "old_boot", "coin_pouch"]
	var treasure: String = treasure_pool[rng.randi_range(0, treasure_pool.size() - 1)]
	stock.append({"item":treasure, "price":45, "quantity":1})
	return stock

func _choose_merchant_position() -> Vector2:
	if not is_instance_valid(_farm):
		return Vector2.ZERO
	var stall: Node2D = SaveManager.buildings.get("market_stall") as Node2D
	var center: Vector2 = stall.global_position if is_instance_valid(stall) else Vector2(920, 650)
	var offsets: Array[Vector2] = [Vector2(-144, 118), Vector2(144, 118), Vector2(-160, -110), Vector2(160, -110), Vector2(0, 160), Vector2(0, -160)]
	for offset in offsets:
		var point := (center + offset).snapped(Vector2(16, 16))
		if SafePlacement.is_clear(_farm, point, Vector2(38, 54), 36.0):
			return point
	merchant_active = false
	return Vector2.ZERO

func _sanitize_merchant_stock(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if not entry is Dictionary:
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
	Inventory.inventory_changed.emit()
	merchant_changed.emit()
	merchant_busy = false
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
