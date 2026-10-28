extends Node

signal inventory_changed
signal action_failed(message: String)
signal level_up(level: int, unlocks: Array, reward: Dictionary)
signal level_up_events_cleared
signal treasure_opened(source_item: String, reward: Dictionary)

const FarmData = preload("res://farm_data.gd")
const ToolData = preload("res://tool_data.gd")
const CropData = preload("res://crop_data.gd")
const FishingData = preload("res://fishing_data.gd")
const BakeryData = preload("res://bakery_data.gd")
const DairyData = preload("res://dairy_data.gd")
const SpinningData = preload("res://spinning_machine_data.gd")
const LoomData = preload("res://loom_data.gd")
const AnimalData = preload("res://animal_data.gd")
const TreasureData = preload("res://treasure_data.gd")
const DOG_PRICE: int = 300
const EGG_PRICE: int = 18
const MILK_PRICE: int = 30
const Progression = preload("res://progression_data.gd")
var SILO_ITEMS: Array[String] = CropData.silo_items()
const BARN_ITEMS: Array[String] = ["chicken_feed", "cow_feed", "pig_feed", "sheep_feed", "egg", "milk", "pork", "wool", "wool_yarn", "cotton_cloth", "wool_cloth", "meat_pie", "small_fish", "river_fish", "golden_fish", "moon_fish", "bread", "corn_bread", "carrot_pie", "egg_cake", "milk_cake", "pancake", "cream", "butter", "cheese", "cotton_thread", "old_bottle", "old_boot", "coin_pouch", "small_chest", "lost_lure", "ancient_coin", "map_fragment", "ancient_gem"]
var owns_spinning_machine: bool = false
var owns_loom: bool = false
var cotton_thread: int = 0
var cotton_cloth: int = 0
var wool_cloth: int = 0
var wool_yarn: int = 0
var pig_feed: int = 0
var sheep_feed: int = 0
var pork: int = 0
var wool: int = 0
var meat_pie: int = 0
var old_bottle: int = 0
var old_boot: int = 0
var coin_pouch: int = 0
var small_chest: int = 0
var lost_lure: int = 0
var ancient_coin: int = 0
var map_fragment: int = 0
var ancient_gem: int = 0
var moon_fish: int = 0
var owns_dairy: bool = false
var cream: int = 0
var butter: int = 0
var cheese: int = 0
var owns_bakery: bool = false
var bread: int = 0
var corn_bread: int = 0
var carrot_pie: int = 0
var egg_cake: int = 0
var milk_cake: int = 0
var pancake: int = 0

var small_fish: int = 0
var river_fish: int = 0
var golden_fish: int = 0
var has_fishing_rod: bool = false
var fishing_rod_level: int = 0
var fishing_attempts_used: int = 0
var fishing_cycle_started_at: float = 0.0
# Transient: an active fishing session reserves one slot, never saved.
var reserved_barn_slots: int = 0
var selling_item: bool = false
var last_treasure_reward: Dictionary = {}

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
var mystery_seed: int = 0
var golden_wheat: int = 0
var golden_corn: int = 0
var giant_carrot: int = 0
var coins: int = 500
var player_exp: int = 0
var player_level: int = 1
var last_rewarded_level: int = 1
var selected_crop: String = "WHEAT"
var chicken_feed: int = 0
var egg: int = 0
var has_dog: bool = false
var cow_feed: int = 0
var milk: int = 0
var silo_capacity: int = 30
var barn_capacity: int = 40
var owns_feed_mill: bool = false
var owns_chicken_coop: bool = false
var owns_cow_shed: bool = false
var owns_pig_pen: bool = false
var owns_sheep_barn: bool = false
var chicken_count: int = 0
var cow_count: int = 0
var pig_count: int = 0
var sheep_count: int = 0
var wood: int = 0
var stone: int = 0
var chicken_coop_level: int = 1
var cow_shed_level: int = 1
var pig_pen_level: int = 1
var sheep_barn_level: int = 1
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
	AudioManager.play_sfx("ui_success")
	return true


func sell_egg() -> bool:
	if egg <= 0:
		return false
	egg -= 1
	coins += EGG_PRICE
	inventory_changed.emit()
	return true

func sell_price(item: String) -> int:
	if CropData.CROPS.has(item.to_upper()):
		return CropData.CROPS[item.to_upper()]["sell_price"]
	if CropData.RARE_VARIANTS.has(item):
		return int(CropData.RARE_VARIANTS[item]["sell_price"])
	if item == "egg":
		return EGG_PRICE
	if item == "milk":
		return MILK_PRICE
	if AnimalData.PRODUCT_PRICES.has(item):
		return int(AnimalData.PRODUCT_PRICES[item])
	if FishingData.FISH.has(item):
		return FishingData.FISH[item]["sell_price"]
	if TreasureData.ITEMS.has(item):
		return int(TreasureData.ITEMS[item].get("sell_price", 0))
	for recipes in [BakeryData.RECIPES,DairyData.RECIPES,SpinningData.RECIPES,LoomData.RECIPES]:
		if recipes.has(item):
			# An order valuation alone does not establish a direct sale price.
			return int(recipes[item].get("price",0))
	return 0

func sellable_items() -> Array[String]:
	var items: Array[String] = []
	for crop in CropData.CROPS:
		if is_unlocked(crop):
			items.append(crop.to_lower())
	for rare_id in CropData.RARE_VARIANTS:
		items.append(rare_id)
	items.append_array(["egg","milk"])
	if is_zone_unlocked("fishing"):
		for fish in FishingData.FISH:
			items.append(fish)
	# Treasure can be found through Dig Spots and events before Fishing unlocks.
	# Let the existing Market Stall clear any sellable treasure at any point.
	for treasure in TreasureData.ITEMS:
		if int(TreasureData.ITEMS[treasure].get("sell_price", 0)) > 0:
			items.append(treasure)
	items.append_array(["pork","wool"])
	for recipes in [BakeryData.RECIPES,DairyData.RECIPES,SpinningData.RECIPES,LoomData.RECIPES]:
		for item in recipes:
			if sell_price(item) > 0 and item not in items:
				items.append(item)
	return items.filter(func(item): return sell_price(item) > 0)

func sell_item(item: String, amount: int = 1) -> bool:
	if selling_item or amount < 1 or item not in sellable_items():
		return false
	var owned: int = get(item)
	var price: int = sell_price(item)
	if amount > owned:
		return false
	# Reject integer overflow before changing either side of the transaction.
	@warning_ignore("integer_division")
	var max_amount: int = (9223372036854775807-coins)/price
	if amount > max_amount:
		return false
	selling_item = true
	set(item,owned-amount)
	coins += amount*price
	inventory_changed.emit()
	selling_item = false
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
	if crop == "MYSTERY":
		return true
	return CropData.CROPS.has(crop) and player_level >= CropData.CROPS[crop]["unlock_level"]


func seed_count(crop: String) -> int:
	if crop == "MYSTERY":
		return mystery_seed
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower() + "_seed")


func crop_count(crop: String) -> int:
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower())


func select_crop(crop: String) -> bool:
	if crop == "MYSTERY":
		if selected_crop != crop:
			selected_crop = crop
			inventory_changed.emit()
		return true
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
	if crop == "MYSTERY":
		return mystery_seed > 0
	return is_unlocked(crop) and seed_count(crop) > 0


func use_seed(crop: String) -> bool:
	if not can_plant(crop):
		return false
	if crop == "MYSTERY":
		mystery_seed -= 1
		inventory_changed.emit()
		return true
	set(crop.to_lower() + "_seed", seed_count(crop) - 1)
	inventory_changed.emit()
	return true


func collect_crop(crop: String, output_item: String = "", amount: int = 1) -> bool:
	if not CropData.CROPS.has(crop):
		return false
	var output := crop.to_lower() if output_item.is_empty() else output_item
	if amount <= 0 or not can_add_item(output, amount):
		return fail(tr("ERROR_SILO_CROP"))
	if not can_add_exp(CropData.CROPS[crop]["harvest_exp"]):
		return false
	set(output, get(output) + amount)
	add_exp(CropData.CROPS[crop]["harvest_exp"], false)
	DiscoveryManager.discover_item(output)
	inventory_changed.emit()
	return true

func exp_to_next_level() -> int:
	return player_level * 100


func normalize_exp(emit_level_events: bool = true) -> void:
	while player_exp >= exp_to_next_level():
		player_exp -= exp_to_next_level()
		player_level += 1
		ensure_tools_for_level()
		if player_level >= FarmData.FISHING_LEVEL:
			fishing_unlocked = true
			if not has_fishing_rod:
				has_fishing_rod = true
				fishing_rod_level = 1
		if emit_level_events:
			if player_level >= ToolData.UNLOCK_LEVEL:
				tools_unlock_notified = true
			level_up.emit(player_level, Progression.unlocks_for_level(player_level), Progression.reward_for_level(player_level))
	ensure_tools_for_level()
	if player_level >= FarmData.FISHING_LEVEL:
		fishing_unlocked = true
		if not has_fishing_rod:
			has_fishing_rod = true
			fishing_rod_level = 1


func can_add_exp(amount: int) -> bool:
	return amount >= 0 and player_exp <= 9223372036854775807 - amount


func add_exp(amount: int, notify: bool = true) -> bool:
	if amount <= 0 or not can_add_exp(amount):
		return false
	player_exp += amount
	normalize_exp()
	if notify:
		inventory_changed.emit()
	return true


func claim_level_reward(level: int) -> bool:
	if level != last_rewarded_level + 1 or level > player_level:
		return false
	var reward: Dictionary = Progression.reward_for_level(level)
	var coin_reward: int = int(reward["coins"])
	if coins > 9223372036854775807 - coin_reward:
		return fail(tr("LEVEL_UP_SAVE_ERROR"))
	var previous_coins: int = coins
	var previous_level: int = last_rewarded_level
	coins += coin_reward
	last_rewarded_level = level
	if not SaveManager.save_game():
		coins = previous_coins
		last_rewarded_level = previous_level
		return fail(tr("LEVEL_UP_SAVE_ERROR"))
	inventory_changed.emit()
	return true


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


func add_item(item: String, amount: int = 1, notify: bool = true) -> bool:
	if not can_add_item(item, amount):
		return fail(tr("ERROR_STORAGE"))
	set(item, get(item) + amount)
	_register_item_gain(item)
	if notify:
		inventory_changed.emit()
	return true


func treasure_action(item_id: String) -> String:
	match item_id:
		"coin_pouch":
			return "use"
		"small_chest":
			return "open"
	return ""


func use_treasure(item_id: String) -> bool:
	var action := treasure_action(item_id)
	if action.is_empty() or get(item_id) <= 0:
		return false
	var nonce: int = SaveManager.treasure_open_sequence + 1
	var reward: Dictionary = {}
	if item_id == "coin_pouch":
		reward = {"type": "coins", "amount": TreasureData.coin_pouch_coins(nonce)}
	else:
		reward = TreasureData.small_chest_reward(nonce, _available_chest_seeds())
	if reward.is_empty():
		return false
	var reward_type := str(reward.get("type", ""))
	var reward_item := str(reward.get("item", ""))
	var reward_amount := maxi(1, int(reward.get("amount", 1)))
	if reward_type == "item":
		# The consumed chest/pouch frees one Barn slot before an item result is
		# inserted, so a full Barn may still safely open into one replacement item.
		if not _can_replace_treasure_with(item_id, reward_item, reward_amount):
			return fail(tr("ERROR_STORAGE"))
	elif reward_type == "coins":
		if coins > 9223372036854775807 - reward_amount:
			return false
	else:
		return false
	var old_source: int = get(item_id)
	var old_coins: int = coins
	var old_reward_count: int = get(reward_item) if reward_type == "item" else 0
	var old_nonce: int = SaveManager.treasure_open_sequence
	var old_discovery: Dictionary = DiscoveryManager.get_save_data()
	var unlocked_decoration := ""
	set(item_id, old_source - 1)
	if reward_type == "coins":
		coins += reward_amount
	else:
		set(reward_item, old_reward_count + reward_amount)
		DiscoveryManager.discover_item(reward_item)
		unlocked_decoration = _unlock_treasure_cosmetic(reward_item, false)
	SaveManager.treasure_open_sequence = nonce
	if not SaveManager.save_game():
		set(item_id, old_source)
		coins = old_coins
		if reward_type == "item":
			set(reward_item, old_reward_count)
		DiscoveryManager.restore(old_discovery)
		SaveManager.treasure_open_sequence = old_nonce
		return fail(tr("ERROR_SAVE_FAILED"))
	last_treasure_reward = reward.duplicate(true)
	if not unlocked_decoration.is_empty():
		DiscoveryManager.cosmetic_unlocked.emit(unlocked_decoration)
	treasure_opened.emit(item_id, last_treasure_reward)
	inventory_changed.emit()
	return true


func _available_chest_seeds() -> Array[String]:
	var seeds: Array[String] = []
	for crop_id in CropData.CROPS:
		if is_unlocked(crop_id):
			seeds.append(crop_id.to_lower() + "_seed")
	return seeds if not seeds.is_empty() else ["wheat_seed"]


func _can_replace_treasure_with(source_item: String, result_item: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if result_item in SILO_ITEMS:
		return can_add_item(result_item, amount)
	if result_item in BARN_ITEMS:
		var released: int = 1 if source_item in BARN_ITEMS else 0
		return storage_used("barn") - released + reserved_barn_slots + amount <= barn_capacity
	return false


func _register_item_gain(item_id: String) -> void:
	DiscoveryManager.discover_item(item_id)
	_unlock_treasure_cosmetic(item_id)


func _unlock_treasure_cosmetic(item_id: String, notify: bool = true) -> String:
	var decoration_id := ""
	match item_id:
		"ancient_coin":
			decoration_id = "ancient_coin_display"
		"ancient_gem":
			decoration_id = "gem_pedestal"
	if not decoration_id.is_empty() and DiscoveryManager.unlock_cosmetic(decoration_id, notify):
		return decoration_id
	return ""


func reconcile_treasure_cosmetics() -> void:
	for item_id in ["ancient_coin", "ancient_gem"]:
		if get(item_id) > 0:
			_unlock_treasure_cosmetic(item_id, false)


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


func buy_building(
	id: String,
	placement_source: Node2D = null,
	position: Vector2 = Vector2.ZERO
) -> bool:

	if not Progression.BUILDINGS.has(id):
		return false

	if not FarmData.BUILDINGS.has(id):
		return false

	var info: Dictionary = Progression.BUILDINGS[id]

	if owns_building(id):
		return fail(
			tr("ERROR_BUILDING_OWNED")
		)

	if player_level < int(info["level"]):
		return fail(
			tr("ERROR_LEVEL") % int(info["level"])
		)

	var price: int = int(info["price"])

	if coins < price:
		return fail(
			tr("ERROR_COINS")
		)

	var placement_required: bool = bool(
		info.get(
			"placement_required",
			false
		)
	)

	# ==============================================
	# VALIDATE PLACEMENT
	# ==============================================

	if placement_required:

		if not is_instance_valid(
			placement_source
		):
			return fail(
				tr("ERROR_PLACEMENT")
			)

		if (
			placement_source.get_meta(
				"placement_building_id",
				""
			)
			!= id
		):
			return fail(
				tr("ERROR_PLACEMENT")
			)

		if not preload(
			"res://building_placement.gd"
		).can_place(
			placement_source,
			position
		):
			return fail(
				tr("ERROR_PLACEMENT")
			)

	# ==============================================
	# BACKUP TRƯỚC KHI COMMIT
	# ==============================================

	var previous_coins: int = coins

	var previous_owned: bool = bool(
		get(
			"owns_" + id
		)
	)

	var previous_position: Vector2 = (
		SaveManager.building_positions.get(
			id,
			FarmData.BUILDINGS[id]["position"]
		)
	)

	var building: Node2D = (
		SaveManager.buildings.get(id)
		as Node2D
	)

	# ==============================================
	# COMMIT PURCHASE
	# ==============================================

	coins -= price

	set(
		"owns_" + id,
		true
	)

	if placement_required:

		SaveManager.building_positions[id] = (
			position
		)

		if is_instance_valid(building):
			building.global_position = position

	# ==============================================
	# SAVE
	# ==============================================

	if not SaveManager.save_game():

		# Rollback Coins
		coins = previous_coins

		# Rollback ownership
		set(
			"owns_" + id,
			previous_owned
		)

		# Rollback position
		SaveManager.building_positions[id] = (
			previous_position
		)

		if is_instance_valid(building):
			building.position = (
				previous_position
			)

		return fail(
			tr("ERROR_SAVE_FAILED")
		)

	# ==============================================
	# SUCCESS
	# ==============================================

	inventory_changed.emit()

	return true


func animal_trade_busy(animal: String) -> bool:
	var id: String = Progression.ANIMALS[animal]["building"]
	var state: String = SaveManager.saved_stations.get(id, {}).get("state", "HUNGRY")
	if SaveManager.stations.has(id) and is_instance_valid(SaveManager.stations[id]):
		state = SaveManager.stations[id].state
	# A production batch owns its animal snapshot through completion. This keeps
	# output stable and prevents selling the animals that are being processed.
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
	var old_roster: Array = SaveManager.animal_records(animal).duplicate(true)
	var old_next_id: int = int(SaveManager.next_animal_ids.get(animal, 1))
	var old_coins: int = coins
	var old_count: int = get(animal + "_count")
	coins -= info["buy"]
	set(animal + "_count", get(animal + "_count") + 1)
	SaveManager.create_animal_record(animal)
	if not SaveManager.save_game():
		coins = old_coins
		set(animal + "_count", old_count)
		SaveManager.animal_rosters[animal] = old_roster
		SaveManager.next_animal_ids[animal] = old_next_id
		return fail(tr("ERROR_SAVE_FAILED"))
	inventory_changed.emit()
	AudioManager.play_sfx("ui_success")
	return true


func sell_animal(animal: String, animal_id: String = "") -> bool:
	if not Progression.ANIMALS.has(animal):
		return false
	if get(animal + "_count") <= 0:
		return fail(tr("ERROR_NO_ANIMALS"))
	if animal_trade_busy(animal):
		return fail(tr("ERROR_BUSY_ANIMALS"))
	var info: Dictionary = Progression.ANIMALS[animal]
	var selected_record: Dictionary = {}
	for record in SaveManager.animal_records(animal):
		if animal_id.is_empty() or record.get("id", "") == animal_id:
			selected_record = record.duplicate(true)
			animal_id = str(record.get("id", ""))
			break
	if selected_record.is_empty():
		return false
	var old_roster: Array = SaveManager.animal_records(animal).duplicate(true)
	var old_count: int = get(animal + "_count")
	var old_coins: int = coins
	var participants_before: Dictionary = {}
	for station_id in SaveManager.STATION_IDS:
		if SaveManager.stations.has(station_id) and is_instance_valid(SaveManager.stations[station_id]):
			participants_before[station_id] = SaveManager.stations[station_id].participant_animal_ids.duplicate()
	set(animal + "_count", get(animal + "_count") - 1)
	coins += info["sell"]
	SaveManager.remove_animal_record(animal, animal_id)
	if not SaveManager.save_game():
		set(animal + "_count", old_count)
		coins = old_coins
		SaveManager.animal_rosters[animal] = old_roster
		for station_id in participants_before:
			SaveManager.stations[station_id].participant_animal_ids = participants_before[station_id]
		return fail(tr("ERROR_SAVE_FAILED"))
	inventory_changed.emit()
	AudioManager.play_sfx("ui_success")
	return true

func animal_capacity(animal: String) -> int:
	if not Progression.ANIMALS.has(animal):
		return 0
	var building: String = Progression.ANIMALS[animal]["building"]
	var level: int = clampi(get(building + "_level"), 1, Progression.UPGRADES[building].size() + 1)
	if level <= 1:
		return Progression.ANIMALS[animal]["capacity"]
	return Progression.UPGRADES[building][level]["capacity"]


func structure_capacity(id: String) -> int:
	if id in ["silo", "barn"]:
		return int(get(id + "_capacity"))
	for animal in Progression.ANIMALS:
		if str(Progression.ANIMALS[animal].get("building", "")) == id:
			return animal_capacity(animal)
	return 0


func next_upgrade(id: String) -> Dictionary:
	if not Progression.UPGRADES.has(id):
		return {}
	return Progression.UPGRADES[id].get(get(id + "_level") + 1, {})


func house_storage_bonus(level: int = house_level) -> int:
	return Progression.house_storage_bonus(level)


func base_storage_capacity(storage: String, level: int = -1) -> int:
	if storage not in ["silo", "barn"]:
		return 0

	var resolved_level: int = (
		get(storage + "_level")
		if level < 0
		else level
	)

	if resolved_level <= 1:
		return 30 if storage == "silo" else 40

	var upgrades: Dictionary = Progression.UPGRADES[storage]
	var data: Dictionary = upgrades.get(resolved_level, {})

	return int(
		data.get(
			"capacity",
			30 if storage == "silo" else 40
		)
	)


func storage_capacity_target(storage: String, level: int = -1, for_house_level: int = -1) -> int:
	var house_target: int = house_level if for_house_level < 0 else for_house_level
	return base_storage_capacity(storage, level) + house_storage_bonus(house_target)


func next_storage_capacity(storage: String) -> int:
	var upgrade: Dictionary = next_upgrade(storage)
	return storage_capacity_target(storage, get(storage + "_level") + 1) if not upgrade.is_empty() else get(storage + "_capacity")


func reconcile_storage_capacities() -> void:
	for storage in ["silo", "barn"]:
		set(storage + "_capacity", maxi(get(storage + "_capacity"), storage_capacity_target(storage)))


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
	var old_wood: int = wood
	var old_stone: int = stone
	var old_coins: int = coins
	var old_level: int = get(id + "_level")
	var old_silo_capacity: int = silo_capacity
	var old_barn_capacity: int = barn_capacity
	_pay_material_cost(cost)
	set(id + "_level", old_level + 1)
	if id in ["silo", "barn"]:
		# Never shrink a larger capacity carried over from an older save, and keep
		# the small House storage bonus when a storage building upgrades later.
		set(id + "_capacity", maxi(get(id + "_capacity"), storage_capacity_target(id)))
	elif id == "house":
		# House upgrades are a modest, non-output benefit: both existing storage
		# buildings gain a few slots while the local house visual becomes cozier.
		reconcile_storage_capacities()
	if not SaveManager.save_game():
		wood = old_wood
		stone = old_stone
		coins = old_coins
		set(id + "_level", old_level)
		silo_capacity = old_silo_capacity
		barn_capacity = old_barn_capacity
		return fail(tr("ERROR_SAVE_FAILED"))
	inventory_changed.emit()
	AudioManager.play_sfx("upgrade_success")
	return true


func build_dog_house() -> bool:
	if has_dog_house:
		return fail(tr("ERROR_DOG_HOUSE_OWNED"))
	if not can_pay_material_cost(Progression.DOG_HOUSE_COST):
		return fail(tr("ERROR_DOG_HOUSE_COST") % Progression.DOG_HOUSE_COST["wood"])
	_pay_material_cost(Progression.DOG_HOUSE_COST)
	has_dog_house = true
	inventory_changed.emit()
	AudioManager.play_sfx("building_place")
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
	AudioManager.play_sfx("upgrade_success")
	return true
func is_zone_unlocked(id: String) -> bool:
	match id:
		"main", "forest":
			return true
		"fishing":
			return fishing_unlocked and player_level >= FarmData.FISHING_LEVEL
		_:
			# Land zones follow the saved ownership list; unknown zones stay locked.
			if SaveManager.LandData.ZONES.has(id):
				return id in SaveManager.unlocked_land_zones
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

func sell_dairy_item(item: String) -> bool:
	if not DairyData.RECIPES.has(item) or get(item) <= 0:
		return false
	set(item,get(item)-1)
	coins += DairyData.RECIPES[item]["price"]
	inventory_changed.emit()
	return true
