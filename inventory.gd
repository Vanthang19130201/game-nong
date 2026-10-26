extends Node

signal inventory_changed
signal action_failed(message: String)

const FarmData = preload("res://farm_data.gd")
const ToolData = preload("res://tool_data.gd")
const CropData = preload("res://crop_data.gd")
const FishingData = preload("res://fishing_data.gd")
const BakeryData = preload("res://bakery_data.gd")
const DOG_PRICE: int = 300
const EGG_PRICE: int = 18
const MILK_PRICE: int = 30
const Progression = preload("res://progression_data.gd")
var SILO_ITEMS: Array[String] = CropData.silo_items()
const BARN_ITEMS: Array[String] = ["chicken_feed", "cow_feed", "egg", "milk", "small_fish", "river_fish", "golden_fish", "bread", "corn_bread", "carrot_pie"]
var owns_bakery: bool = false
var bread: int = 0
var corn_bread: int = 0
var carrot_pie: int = 0

var small_fish: int = 0
var river_fish: int = 0
var golden_fish: int = 0
var has_fishing_rod: bool = false
var fishing_rod_level: int = 0
var fishing_attempts_used: int = 0
var fishing_cycle_started_at: float = 0.0
# Transient: an active fishing session reserves one slot, never saved.
var reserved_barn_slots: int = 0

var wheat_seed: int = 10
var wheat: int = 0
var corn_seed: int = 0
var corn: int = 0
var carrot_seed: int = 0
var carrot: int = 0
var soybean_seed: int = 0
var soybean: int = 0
var sugarcane_seed: int = 0
var sugarcane: int = 0
var cotton_seed: int = 0
var cotton: int = 0
var flax_seed: int = 0
var flax: int = 0
var coins: int = 100
var player_exp: int = 0
var player_level: int = 1
var selected_crop: String = "WHEAT"
var chicken_feed: int = 0
var egg: int = 0
var has_dog: bool = false
var cow_feed: int = 0
var milk: int = 0
var silo_capacity: int = 30
var barn_capacity: int = 20
var owns_feed_mill: bool = false
var owns_chicken_coop: bool = false
var owns_cow_shed: bool = false
var chicken_count: int = 0
var cow_count: int = 0
var wood: int = 0
var stone: int = 0
var chicken_coop_level: int = 1
var cow_shed_level: int = 1
var house_level: int = 1
var silo_level: int = 1
var barn_level: int = 1
var has_dog_house: bool = false
var has_axe: bool = false
var has_hammer: bool = false
var axe_level: int = 0
var hammer_level: int = 0
var tools_unlock_notified: bool = false
var unlocked_plot_count: int = FarmData.STARTING_PLOTS
var fishing_unlocked: bool = false


func buy_dog() -> bool:
	if has_dog or coins < DOG_PRICE:
		return false
	coins -= DOG_PRICE
	has_dog = true
	inventory_changed.emit()
	return true


func sell_egg() -> bool:
	if egg <= 0:
		return false
	egg -= 1
	coins += EGG_PRICE
	inventory_changed.emit()
	return true


func sell_fish(fish: String, sell_all: bool = false) -> bool:
	if not is_zone_unlocked("fishing") or not FishingData.FISH.has(fish):
		return false
	var owned: int = get(fish)
	if owned <= 0:
		return false
	var amount: int = owned if sell_all else 1
	# Update fish and Coins together before HUD/save receive the single signal.
	set(fish, owned - amount)
	coins += amount * FishingData.FISH[fish]["sell_price"]
	inventory_changed.emit()
	return true


func is_unlocked(crop: String) -> bool:
	return CropData.CROPS.has(crop) and player_level >= CropData.CROPS[crop]["unlock_level"]


func seed_count(crop: String) -> int:
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower() + "_seed")


func crop_count(crop: String) -> int:
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower())


func select_crop(crop: String) -> bool:
	if not is_unlocked(crop):
		return false
	if selected_crop != crop:
		selected_crop = crop
		inventory_changed.emit()
	return true


func buy_seed(crop: String) -> bool:
	if not is_unlocked(crop):
		return false
	var price: int = CropData.CROPS[crop]["seed_buy_price"]
	if coins < price:
		return false
	if not can_add_item(crop.to_lower() + "_seed", 1):
		return fail(tr("ERROR_SILO_BUY"))
	coins -= price
	set(crop.to_lower() + "_seed", seed_count(crop) + 1)
	inventory_changed.emit()
	return true


func sell_crop(crop: String) -> bool:
	if crop_count(crop) <= 0:
		return false
	set(crop.to_lower(), crop_count(crop) - 1)
	coins += CropData.CROPS[crop]["sell_price"]
	inventory_changed.emit()
	return true


func can_plant(crop: String) -> bool:
	return is_unlocked(crop) and seed_count(crop) > 0


func use_seed(crop: String) -> bool:
	if not can_plant(crop):
		return false
	set(crop.to_lower() + "_seed", seed_count(crop) - 1)
	inventory_changed.emit()
	return true


func collect_crop(crop: String) -> bool:
	if not CropData.CROPS.has(crop):
		return false
	if not can_add_item(crop.to_lower(), 1):
		return fail(tr("ERROR_SILO_CROP"))
	set(crop.to_lower(), crop_count(crop) + 1)
	player_exp += CropData.CROPS[crop]["harvest_exp"]
	normalize_exp()
	inventory_changed.emit()
	return true

func exp_to_next_level() -> int:
	return player_level * 100


func normalize_exp() -> void:
	while player_exp >= exp_to_next_level():
		player_exp -= exp_to_next_level()
		player_level += 1
	ensure_tools_for_level()
	if player_level >= FarmData.FISHING_LEVEL:
		fishing_unlocked = true
		if not has_fishing_rod:
			has_fishing_rod = true
			fishing_rod_level = 1


func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	player_exp += amount
	normalize_exp()
	inventory_changed.emit()


# Keep the original Wheat methods available for existing callers.
func buy_wheat_seed() -> bool:
	return buy_seed("WHEAT")


func sell_wheat() -> bool:
	return sell_crop("WHEAT")


func use_wheat_seed() -> bool:
	return use_seed("WHEAT")


func add_wheat(amount: int = 1) -> void:
	if amount <= 0:
		return
	if not can_add_item("wheat", amount):
		fail(tr("ERROR_SILO_FULL"))
		return
	wheat += amount
	inventory_changed.emit()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	inventory_changed.emit()


func remove_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	inventory_changed.emit()
	return true

func fail(message: String) -> bool:
	action_failed.emit(message)
	return false


func storage_used(storage: String) -> int:
	var total: int = 0
	var items: Array[String] = SILO_ITEMS if storage == "silo" else BARN_ITEMS
	for item in items:
		total += get(item)
	return total


func can_add_item(item: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if item in SILO_ITEMS:
		return storage_used("silo") + amount <= silo_capacity
	if item in BARN_ITEMS:
		return storage_used("barn") + reserved_barn_slots + amount <= barn_capacity
	return false


func add_item(item: String, amount: int = 1) -> bool:
	if not can_add_item(item, amount):
		return fail(tr("ERROR_STORAGE"))
	set(item, get(item) + amount)
	inventory_changed.emit()
	return true


func reserve_fishing_slot() -> bool:
	if reserved_barn_slots != 0 or not can_add_item("small_fish", 1):
		return false
	reserved_barn_slots = 1
	return true


func refresh_fishing_cycle() -> void:
	if fishing_cycle_started_at <= 0.0 or Time.get_unix_time_from_system() >= fishing_cycle_started_at + FishingData.CYCLE_SECONDS:
		fishing_attempts_used = 0
		fishing_cycle_started_at = 0.0


func fishing_attempts_remaining() -> int:
	if fishing_cycle_started_at <= 0.0 or Time.get_unix_time_from_system() >= fishing_cycle_started_at + FishingData.CYCLE_SECONDS:
		return FishingData.ATTEMPTS_PER_CYCLE
	return maxi(0, FishingData.ATTEMPTS_PER_CYCLE - fishing_attempts_used)


func fishing_cycle_seconds_left() -> int:
	if fishing_attempts_remaining() == FishingData.ATTEMPTS_PER_CYCLE:
		return 0
	return maxi(0, ceili(fishing_cycle_started_at + FishingData.CYCLE_SECONDS - Time.get_unix_time_from_system()))


func consume_fishing_attempt() -> bool:
	if not is_zone_unlocked("fishing") or not has_fishing_rod:
		return false
	if fishing_attempts_remaining() <= 0:
		return fail(tr("ERROR_FISH_ATTEMPTS"))
	var old_used: int = fishing_attempts_used
	var old_start: float = fishing_cycle_started_at
	refresh_fishing_cycle()
	if fishing_cycle_started_at <= 0.0:
		fishing_cycle_started_at = Time.get_unix_time_from_system()
	fishing_attempts_used += 1
	# Persist the charge before starting: cancel, failure and closing cannot refund it.
	if not SaveManager.save_game():
		fishing_attempts_used = old_used
		fishing_cycle_started_at = old_start
		return fail(tr("ERROR_FISH_SAVE"))
	return true


func release_fishing_slot() -> void:
	reserved_barn_slots = 0


func upgrade_fishing_rod() -> bool:
	if not has_fishing_rod or not is_zone_unlocked("fishing"):
		return fail(tr("FISHING_UNLOCK_LEVEL_10"))
	var next_level: int = fishing_rod_level + 1
	if not FishingData.ROD_LEVELS.has(next_level):
		return fail(tr("ROD_MAX"))
	var cost: int = FishingData.ROD_LEVELS[next_level]["cost"]
	if coins < cost:
		return fail(tr("ERROR_COINS"))
	coins -= cost
	fishing_rod_level = next_level
	inventory_changed.emit()
	return true


func sell_milk() -> bool:
	if milk <= 0:
		return fail(tr("MSG_NO_MILK"))
	milk -= 1
	coins += MILK_PRICE
	inventory_changed.emit()
	return true


func discard_feed(item: String) -> bool:
	if item not in ["chicken_feed", "cow_feed"] or get(item) <= 0:
		return fail(tr("MSG_NO_FEED"))
	set(item, get(item) - 1)
	inventory_changed.emit()
	return true


func owns_building(id: String) -> bool:
	return Progression.BUILDINGS.has(id) and get("owns_" + id)


func buy_building(id: String) -> bool:
	if not Progression.BUILDINGS.has(id):
		return false
	var info: Dictionary = Progression.BUILDINGS[id]
	if owns_building(id):
		return fail(tr("ERROR_BUILDING_OWNED"))
	if player_level < info["level"]:
		return fail(tr("ERROR_LEVEL") % info["level"])
	if coins < info["price"]:
		return fail(tr("ERROR_COINS"))
	coins -= info["price"]
	set("owns_" + id, true)
	inventory_changed.emit()
	return true


func animal_trade_busy(animal: String) -> bool:
	var id: String = Progression.ANIMALS[animal]["building"]
	var state: String = SaveManager.saved_stations.get(id, {}).get("state", "HUNGRY")
	if SaveManager.stations.has(id) and is_instance_valid(SaveManager.stations[id]):
		state = SaveManager.stations[id].state
	return state in ["PRODUCING", "READY"]


func buy_animal(animal: String) -> bool:
	if not Progression.ANIMALS.has(animal):
		return false
	var info: Dictionary = Progression.ANIMALS[animal]
	if not owns_building(info["building"]) or player_level < info["level"]:
		return fail(tr("ERROR_BUY_BUILDING_LEVEL") % info["level"])
	if animal_trade_busy(animal):
		return fail(tr("ERROR_BUSY_ANIMALS"))
	if get(animal + "_count") >= animal_capacity(animal):
		return fail(tr("ERROR_ANIMAL_CAPACITY"))
	if coins < info["buy"]:
		return fail(tr("ERROR_COINS"))
	coins -= info["buy"]
	set(animal + "_count", get(animal + "_count") + 1)
	inventory_changed.emit()
	return true


func sell_animal(animal: String) -> bool:
	if not Progression.ANIMALS.has(animal):
		return false
	if get(animal + "_count") <= 0:
		return fail(tr("ERROR_NO_ANIMALS"))
	if animal_trade_busy(animal):
		return fail(tr("ERROR_BUSY_ANIMALS"))
	var info: Dictionary = Progression.ANIMALS[animal]
	set(animal + "_count", get(animal + "_count") - 1)
	coins += info["sell"]
	inventory_changed.emit()
	return true

func animal_capacity(animal: String) -> int:
	if not Progression.ANIMALS.has(animal):
		return 0
	var building: String = Progression.ANIMALS[animal]["building"]
	var level: int = clampi(get(building + "_level"), 1, Progression.UPGRADES[building].size() + 1)
	if level <= 1:
		return Progression.ANIMALS[animal]["capacity"]
	return Progression.UPGRADES[building][level]["capacity"]


func next_upgrade(id: String) -> Dictionary:
	if not Progression.UPGRADES.has(id):
		return {}
	return Progression.UPGRADES[id].get(get(id + "_level") + 1, {})


func can_pay_material_cost(cost: Dictionary) -> bool:
	return wood >= cost.get("wood", 0) and stone >= cost.get("stone", 0) and coins >= cost.get("coins", 0)


func _pay_material_cost(cost: Dictionary) -> void:
	wood -= cost.get("wood", 0)
	stone -= cost.get("stone", 0)
	coins -= cost.get("coins", 0)


func upgrade_structure(id: String) -> bool:
	if not Progression.UPGRADES.has(id):
		return false
	if id in Progression.BUILDINGS and not owns_building(id):
		return fail(tr("ERROR_BUILDING_FIRST"))
	var cost: Dictionary = next_upgrade(id)
	if cost.is_empty():
		return fail(tr("ERROR_MAX_LEVEL"))
	if not can_pay_material_cost(cost):
		return fail(tr("ERROR_RESOURCES") if id == "house" else tr("ERROR_MATERIALS"))
	_pay_material_cost(cost)
	set(id + "_level", get(id + "_level") + 1)
	if id in ["silo", "barn"]:
		# Never shrink a larger capacity carried over from an older save.
		set(id + "_capacity", maxi(get(id + "_capacity"), cost["capacity"]))
	inventory_changed.emit()
	return true


func build_dog_house() -> bool:
	if has_dog_house:
		return fail(tr("ERROR_DOG_HOUSE_OWNED"))
	if not can_pay_material_cost(Progression.DOG_HOUSE_COST):
		return fail(tr("ERROR_DOG_HOUSE_COST") % [Progression.DOG_HOUSE_COST["wood"], Progression.DOG_HOUSE_COST["stone"]])
	_pay_material_cost(Progression.DOG_HOUSE_COST)
	has_dog_house = true
	inventory_changed.emit()
	return true

func ensure_tools_for_level() -> void:
	if player_level < ToolData.UNLOCK_LEVEL:
		return
	# No signal here: the caller saves the entire completed transaction once.
	for id in ToolData.TOOLS:
		set("has_" + id, true)
		set(id + "_level", maxi(1, get(id + "_level")))


func can_use_tool(id: String) -> bool:
	return ToolData.TOOLS.has(id) and player_level >= ToolData.UNLOCK_LEVEL and get("has_" + id) and get(id + "_level") > 0


func tool_duration(id: String) -> float:
	if not can_use_tool(id):
		return 0.0
	var level: int = clampi(get(id + "_level"), 1, ToolData.TOOLS[id]["levels"].size())
	return ToolData.TOOLS[id]["levels"][level]["time"]


func upgrade_tool(id: String) -> bool:
	if not can_use_tool(id):
		return fail(tr("ERROR_TOOLS_LOCKED"))
	var next: int = get(id + "_level") + 1
	var levels: Dictionary = ToolData.TOOLS[id]["levels"]
	if not levels.has(next):
		return fail(tr("UI_MAX_LEVEL"))
	var price: int = levels[next]["cost"]
	if coins < price:
		return fail(tr("ERROR_COINS"))
	coins -= price
	set(id + "_level", next)
	inventory_changed.emit()
	return true
func is_zone_unlocked(id: String) -> bool:
	match id:
		"main", "forest":
			return true
		"fishing":
			return fishing_unlocked and player_level >= FarmData.FISHING_LEVEL
		_:
			# Future/unknown zones stay inactive until explicitly supported.
			return false


func buy_plot(number: int) -> bool:
	if unlocked_plot_count >= FarmData.MAX_PLOTS:
		return fail(tr("ERROR_PLOTS_MAX"))
	if number != unlocked_plot_count + 1:
		return fail(tr("PLOT_FIRST") % (unlocked_plot_count + 1))
	var price: int = FarmData.plot_price(number)
	if price < 0 or coins < price:
		return fail(tr("ERROR_COINS"))
	coins -= price
	unlocked_plot_count = number
	inventory_changed.emit()
	return true


func sell_bakery_item(item: String) -> bool:
	if not BakeryData.RECIPES.has(item) or get(item) <= 0:
		return false
	set(item, get(item) - 1)
	coins += BakeryData.RECIPES[item]["price"]
	inventory_changed.emit()
	return true
