extends SceneTree

# Run only through run_core_stability.ps1 so SaveManager writes to test-save.cfg.
const TreasureData = preload("res://treasure_data.gd")
const Progression = preload("res://progression_data.gd")
const BakeryData = preload("res://bakery_data.gd")
const DairyData = preload("res://dairy_data.gd")
const SpinningData = preload("res://spinning_machine_data.gd")

var inv: Node
var manager: Node
var discovery: Node


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)


func storage_state(storage: String) -> Array:
	return [inv.wood, inv.stone, inv.coins, inv.get(storage + "_level"), inv.get(storage + "_capacity")]


func set_exact_cost(cost: Dictionary) -> void:
	inv.wood = int(cost.get("wood", 0))
	inv.stone = int(cost.get("stone", 0))
	inv.coins = int(cost.get("coins", 0))


func rare_container_for_seed(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return TreasureData.roll_rare_container(rng)


func find_rare_container_seed(expect_gem: bool) -> int:
	# Pick a deterministic seed from the engine RNG instead of relying on a
	# statistical sample. This directly exercises each side of the 1% branch.
	for seed_value in range(1, 20000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if (rng.randf() < TreasureData.ANCIENT_GEM_CHANCE) == expect_gem:
			return seed_value
	return -1


func run_checks() -> void:
	await process_frame
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	discovery = root.get_node("DiscoveryManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	var stage := str(OS.get_cmdline_user_args()[0])
	match stage:
		"upgrade_treasure_core":
			check_upgrade_and_treasure_core()
		"upgrade_treasure_legacy_write":
			write_legacy_fixture()
		"upgrade_treasure_legacy_read":
			check_legacy_migration()
		_:
			check(false, "unknown upgrade/treasure stage")
	print("PASS: ", stage)
	quit()


func check_upgrade_and_treasure_core() -> void:
	check(manager.reset_game(), "reset upgrade/treasure fixture")
	check_storage_upgrade_atomicity("silo")
	check_storage_upgrade_atomicity("barn")
	check_house_storage_bonus()
	check_production_queue_upgrades()
	check_treasure_data_and_transactions()


func check_storage_upgrade_atomicity(storage: String) -> void:
	var first_cost: Dictionary = inv.next_upgrade(storage)
	check(not first_cost.is_empty(), storage + " has a first upgrade")
	var base_capacity: int = inv.base_storage_capacity(storage, 1)
	check(int(inv.get(storage + "_capacity")) == base_capacity, storage + " starts at base capacity")
	for missing in ["wood", "stone", "coins"]:
		set_exact_cost(first_cost)
		inv.set(missing, int(inv.get(missing)) - 1)
		var before: Array = storage_state(storage)
		check(not inv.upgrade_structure(storage), storage + " rejects a missing " + missing)
		check(storage_state(storage) == before, storage + " never partially charges for a missing " + missing)
	# Save failure is also transactional: the cost, level, and capacity roll back.
	set_exact_cost(first_cost)
	var save_failure_before: Array = storage_state(storage)
	manager.resetting = true
	check(not inv.upgrade_structure(storage), storage + " rolls back when saving fails")
	manager.resetting = false
	check(storage_state(storage) == save_failure_before, storage + " save failure keeps all state unchanged")
	set_exact_cost(first_cost)
	check(inv.upgrade_structure(storage), storage + " accepts its exact cost")
	check(inv.get(storage + "_level") == 2, storage + " increases one level")
	check(inv.get(storage + "_capacity") == inv.storage_capacity_target(storage), storage + " reaches its capacity target")
	check(inv.get(storage + "_capacity") == int(first_cost["capacity"]), storage + " uses the configured first capacity")
	check(inv.wood == 0 and inv.stone == 0 and inv.coins == 0, storage + " exact upgrade consumes each resource exactly once")


func check_house_storage_bonus() -> void:
	for level_variant in Progression.HOUSE_STORAGE_BONUSES:
		var level: int = int(level_variant)
		var bonus: int = Progression.house_storage_bonus(level)
		check(inv.house_storage_bonus(level) == bonus, "house bonus uses progression data at level " + str(level))
		for storage in ["silo", "barn"]:
			var base: int = inv.base_storage_capacity(storage, 1)
			check(inv.storage_capacity_target(storage, 1, level) == base + bonus, "house bonus applies once to " + storage + " at level " + str(level))
	var silo_before: int = inv.silo_capacity
	var barn_before: int = inv.barn_capacity
	var house_before: int = inv.house_level
	var house_cost: Dictionary = inv.next_upgrade("house")
	set_exact_cost(house_cost)
	check(inv.upgrade_structure("house"), "house upgrade succeeds at exact cost")
	var gained_bonus: int = inv.house_storage_bonus(inv.house_level) - inv.house_storage_bonus(house_before)
	check(inv.silo_capacity == silo_before + gained_bonus, "house upgrade adds the same bonus to Silo")
	check(inv.barn_capacity == barn_before + gained_bonus, "house upgrade adds the same bonus to Barn")
	# A later storage upgrade keeps the existing House bonus rather than replacing it.
	for storage in ["silo", "barn"]:
		var cost: Dictionary = inv.next_upgrade(storage)
		set_exact_cost(cost)
		check(inv.upgrade_structure(storage), storage + " upgrades after House")
		check(inv.get(storage + "_capacity") == inv.storage_capacity_target(storage), storage + " preserves the House bonus after its own upgrade")


func valid_queue(item: String, count: int) -> Array:
	var start := Time.get_unix_time_from_system()
	var result: Array = []
	for index in range(count):
		result.append({"item": item, "state": "QUEUED", "started_at": start + index, "ready_at": start + 60.0 + index})
	return result


func check_production_queue_upgrades() -> void:
	check(manager.reset_game(), "reset production-upgrade fixture")
	var specs: Array[Dictionary] = [
		{"id": "bakery", "queue": "bakery_queue", "item": "bread"},
		{"id": "dairy", "queue": "dairy_queue", "item": "cream"},
		{"id": "spinning_machine", "queue": "spinning_machine_queue", "item": "cotton_thread"}
	]
	for spec in specs:
		var id := str(spec["id"])
		inv.set("owns_" + id, true)
		var cost: Dictionary = inv.next_upgrade(id)
		check(not cost.is_empty() and int(cost.get("queue_capacity", 0)) == 4, id + " has its first queue upgrade")
		set_exact_cost(cost)
		check(inv.upgrade_structure(id), id + " upgrades with its exact material cost")
		check(inv.production_queue_capacity(id) == 4, id + " gains a fourth production slot")
		var jobs := valid_queue(str(spec["item"]), 4)
		var legacy_jobs: Array = []
		var upgraded_jobs: Array = []
		match id:
			"bakery":
				legacy_jobs = BakeryData.restore_queue(jobs, 3)
				upgraded_jobs = BakeryData.restore_queue(jobs, inv.production_queue_capacity(id))
			"dairy":
				legacy_jobs = DairyData.restore_queue(jobs, 3)
				upgraded_jobs = DairyData.restore_queue(jobs, inv.production_queue_capacity(id))
			"spinning_machine":
				legacy_jobs = SpinningData.restore_queue(jobs, 3)
				upgraded_jobs = SpinningData.restore_queue(jobs, inv.production_queue_capacity(id))
		check(legacy_jobs.size() == 3, id + " keeps the legacy three-slot guard")
		check(upgraded_jobs.size() == 4, id + " accepts its upgraded fourth slot")
		manager.set(str(spec["queue"]), jobs)
		check(manager.save_game(), id + " upgraded queue saves")
		manager._load_game()
		check(inv.get(id + "_level") == 2 and inv.production_queue_capacity(id) == 4, id + " queue level survives reload")
		var reloaded_jobs: Array = manager.get(str(spec["queue"]))
		check(reloaded_jobs.size() == 4, id + " fourth queued job survives reload")
		var second_cost: Dictionary = inv.next_upgrade(id)
		set_exact_cost(second_cost)
		check(inv.upgrade_structure(id) and inv.production_queue_capacity(id) == 5, id + " gains its fifth production slot")


func check_treasure_data_and_transactions() -> void:
	check(manager.reset_game(), "reset treasure fixture")
	check(is_equal_approx(TreasureData.ANCIENT_GEM_CHANCE, 0.01), "Ancient Gem rare-container chance is one percent")
	check(TreasureData.rarity_of("ancient_gem") == TreasureData.RARITY_ULTRA_RARE, "Ancient Gem has Ultra Rare rarity")
	check(int(TreasureData.ITEMS["ancient_gem"]["weight"]) == 0, "Ancient Gem is not in the ordinary weighted table")
	var gem_seed := find_rare_container_seed(true)
	var ordinary_seed := find_rare_container_seed(false)
	check(gem_seed > 0 and ordinary_seed > 0, "deterministic seeds cover both rare-container outcomes")
	check(rare_container_for_seed(gem_seed) == "ancient_gem", "rare container deterministically yields Ancient Gem below its threshold")
	var ordinary_result := rare_container_for_seed(ordinary_seed)
	check(ordinary_result in TreasureData.RARE_CONTAINER_ITEMS, "rare container otherwise yields a configured rare reward")
	check(rare_container_for_seed(ordinary_seed) == ordinary_result, "rare-container roll is repeatable for its seed")
	var chest_a: Dictionary = TreasureData.small_chest_reward(19, ["wheat_seed", "corn_seed"])
	var chest_b: Dictionary = TreasureData.small_chest_reward(19, ["wheat_seed", "corn_seed"])
	check(chest_a == chest_b and not chest_a.is_empty(), "small chest reward is deterministic for its nonce")
	check(TreasureData.coin_pouch_coins(19) == TreasureData.coin_pouch_coins(19), "coin pouch reward is deterministic for its nonce")
	check(TreasureData.coin_pouch_coins(19) >= 55 and TreasureData.coin_pouch_coins(19) <= 95, "coin pouch reward stays in its configured range")
	var roll_a := RandomNumberGenerator.new()
	var roll_b := RandomNumberGenerator.new()
	roll_a.seed = 90210
	roll_b.seed = 90210
	check(TreasureData.roll(roll_a) == TreasureData.roll(roll_b), "seeded fishing treasure roll is repeatable")

	check(inv.treasure_action("coin_pouch") == "use" and inv.treasure_action("small_chest") == "open", "usable treasures expose actions")
	check(inv.treasure_action("old_bottle").is_empty(), "ordinary treasure has no use action")
	var pouch_nonce: int = manager.treasure_open_sequence + 1
	var pouch_reward: int = TreasureData.coin_pouch_coins(pouch_nonce)
	var pouch_coins_before: int = inv.coins
	inv.coin_pouch = 1
	check(inv.use_treasure("coin_pouch"), "coin pouch uses successfully")
	check(inv.coin_pouch == 0 and inv.coins == pouch_coins_before + pouch_reward, "coin pouch consumes once and grants its deterministic coins")
	check(manager.treasure_open_sequence == pouch_nonce and inv.last_treasure_reward == {"type": "coins", "amount": pouch_reward}, "coin pouch persists its nonce and reward")

	var chest_nonce: int = manager.treasure_open_sequence + 1
	var chest_reward: Dictionary = TreasureData.small_chest_reward(chest_nonce, inv._available_chest_seeds())
	var chest_coins_before: int = inv.coins
	var chest_item := str(chest_reward.get("item", ""))
	var chest_item_before: int = int(inv.get(chest_item)) if not chest_item.is_empty() else 0
	inv.small_chest = 1
	check(inv.use_treasure("small_chest"), "small chest opens successfully")
	check(inv.small_chest == 0 and manager.treasure_open_sequence == chest_nonce, "small chest consumes once and advances its nonce")
	if chest_reward.get("type", "") == "coins":
		check(inv.coins == chest_coins_before + int(chest_reward["amount"]), "small chest coin reward is granted once")
	else:
		check(inv.get(chest_item) == chest_item_before + int(chest_reward["amount"]), "small chest item reward is granted once")
		check(discovery.has_discovered("treasures", chest_item) or chest_item.ends_with("_seed"), "small chest item reward is discoverable")

	var bottle_price: int = inv.sell_price("old_bottle")
	var sale_coins_before: int = inv.coins
	inv.old_bottle = 1
	check(inv.sell_item("old_bottle"), "sellable treasure can use the normal sell path")
	check(inv.old_bottle == 0 and inv.coins == sale_coins_before + bottle_price, "treasure sale is atomic")
	var gem_price: int = inv.sell_price("ancient_gem")
	sale_coins_before = inv.coins
	inv.ancient_gem = 1
	check(inv.sell_item("ancient_gem"), "Ancient Gem is sellable")
	check(inv.ancient_gem == 0 and inv.coins == sale_coins_before + gem_price, "Ancient Gem sale uses its catalog price")
	inv.map_fragment = 1
	var fragment_coins_before: int = inv.coins
	check(not inv.sell_item("map_fragment") and not inv.use_treasure("map_fragment"), "quest fragment cannot be sold or used as a container")
	check(inv.map_fragment == 1 and inv.coins == fragment_coins_before, "failed treasure actions leave inventory unchanged")


func write_legacy_fixture() -> void:
	# Intentionally omit every upgrade/treasure field introduced by this work.
	var data := ConfigFile.new()
	data.set_value("game", "version", 17)
	data.set_value("inventory", "coins", 987)
	data.set_value("inventory", "wheat", 40)
	data.set_value("upgrades", "house_level", 2)
	data.set_value("upgrades", "silo_level", 2)
	data.set_value("upgrades", "barn_level", 3)
	# Preserve a legitimate large legacy capacity while Barn must be reconstructed.
	data.set_value("storage", "silo_capacity", 90)
	check(data.save(manager.SAVE_PATH) == OK, "write old-save fixture")


func check_legacy_migration() -> void:
	check(inv.coins == 987 and inv.wheat == 40, "legacy inventory values survive migration")
	for item_id in ["old_bottle", "old_boot", "coin_pouch", "small_chest", "lost_lure", "ancient_coin", "map_fragment", "ancient_gem"]:
		check(inv.get(item_id) == 0, "missing legacy " + item_id + " defaults to zero")
	check(manager.pending_fishing_reward.is_empty() and manager.treasure_open_sequence == 0 and not manager.hidden_treasure_claimed, "missing treasure save fields use safe defaults")
	check(inv.silo_capacity == 90, "larger legacy Silo capacity never shrinks")
	check(inv.barn_capacity == inv.storage_capacity_target("barn") and inv.barn_capacity == 95, "missing Barn capacity migrates from its level plus House bonus")
	check(inv.storage_capacity_target("silo") == 75, "migrated House bonus remains additive to storage targets")
	check(manager.save_game(), "migrated save persists")
	var persisted := ConfigFile.new()
	check(persisted.load(manager.SAVE_PATH) == OK, "read migrated save")
	check(persisted.get_value("treasure", "open_sequence", -1) == 0, "migrated treasure sequence is saved")
	check(persisted.get_value("storage", "barn_capacity", -1) == 95, "migrated Barn capacity is saved")
