extends SceneTree

var inv: Node
var manager: Node
var orders: Node
var farm: Node
var hud: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "read isolated save")
	return data

func balances() -> Array:
	return [inv.coins, inv.wood, inv.stone]

func make_adults(animal: String) -> void:
	var roster: Array = manager.animal_rosters[animal]
	for record in roster:
		record["born_at"] = inv.AnimalData.adult_born_at(animal)
	manager.animal_rosters[animal] = roster
	if farm.animal_groups.has(animal):
		farm.animal_groups[animal].sync_count()

func crop_inventory_total() -> int:
	var total: int = 0
	for crop in inv.CropData.CROPS:
		total += inv.get(crop.to_lower())
	for item in inv.CropData.RARE_VARIANTS:
		total += inv.get(item)
	return total

func run_checks() -> void:
	await process_frame
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "test must never touch real save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"audit_core": await audit_core()
		"animal_output": animal_output()
		"audit_write": audit_write()
		"audit_read": audit_read(false)
		"audit_again": audit_read(true)
		"audit_close":
			inv.coins = 90876
			manager._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			check(disk().get_value("inventory","coins") == 90876, "save on window close")
	print("PASS: ", stage)
	quit()

func audit_core() -> void:
	check(manager.reset_game(), "reset fixture")
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.wheat = 1
	inv.corn = 2
	inv.carrot = 1
	inv.chicken_feed = 1
	inv.cow_feed = 1
	for level in range(1,11):
		inv.player_level = level
		inv.normalize_exp()
		inv.inventory_changed.emit()
		for crop in inv.CropData.CROPS:
			var available: bool = level >= inv.CropData.CROPS[crop]["unlock_level"]
			check(inv.is_unlocked(crop) == available and inv.select_crop(crop) == available, "crop unlock at level " + str(level))
		for id in inv.Progression.BUILDINGS:
			var required: int = inv.Progression.BUILDINGS[id]["level"]
			if level < required:
				var before: int = inv.coins
				check(not inv.buy_building(id) and inv.coins == before, "building level gate")
			elif level == required:
				check(inv.buy_building(id), "building unlock purchase")
				var before: int = inv.coins
				check(not inv.buy_building(id) and inv.coins == before, "building duplicate purchase blocked")
		for animal in inv.Progression.ANIMALS:
			var required: int = inv.Progression.ANIMALS[animal]["level"]
			if level < required:
				check(not inv.buy_animal(animal), "animal level gate")
			elif level == required:
				check(inv.buy_animal(animal), "animal unlock purchase")
				make_adults(animal)
		check(inv.can_use_tool("axe") == (level >= 6) and inv.can_use_tool("hammer") == (level >= 6), "tool level gate")
		check(inv.is_zone_unlocked("fishing") == (level >= 10) and inv.has_fishing_rod == (level >= 10), "fishing level gate")
		check(orders.item_available("egg") == (level >= 6), "egg orders unlock when egg production becomes possible")
		check(orders.item_available("milk") == (level >= 10), "milk order gate")
		check(orders.item_available("golden_fish") == (level >= 10), "fish order gate")
		for recipe in inv.Progression.RECIPES:
			check(farm.get_node("FeedMill").can_produce(recipe) == (level >= inv.Progression.RECIPES[recipe]["level"]), "feed recipe unlock")
		check(farm.get_node("ChickenCoop").can_produce() == (level >= 6 and not manager.adult_animal_ids("chicken").is_empty()), "egg production unlock requires adults")
		check(farm.get_node("CowShed").can_produce() == (level >= 10 and not manager.adult_animal_ids("cow").is_empty()), "milk production unlock requires adults")
		for order in orders.orders:
			for item in order["requirements"]:
				check(orders.item_available(item), "orders only request producible items")
	# Both axes/hammers: exact payment and max-level behavior.
	for id in inv.ToolData.TOOLS:
		for level in [2,3,4]:
			var price: int = inv.ToolData.TOOLS[id]["levels"][level]["cost"]
			inv.coins = price-1
			check(not inv.upgrade_tool(id) and inv.coins == price-1, "insufficient tool funds")
			inv.coins = price
			check(inv.upgrade_tool(id) and inv.coins == 0 and inv.get(id+"_level") == level, "tool exact payment")
		check(not inv.upgrade_tool(id), "tool max level")
	for node_name in ["tree1","rock1"]:
		var resource = farm.get_node(node_name)
		farm.get_node("Player").position = resource.position
		await create_timer(0.1).timeout
		var before: int = inv.get(resource.resource_type)
		check(resource.harvest(), "gather resource with unlocked tool")
		await create_timer(resource.harvest_timer.time_left + 0.1).timeout
		var earned: int = inv.get(resource.resource_type)-before
		var reward: Dictionary = resource.RockData.TYPES[resource.rock_type] if resource.resource_type == "stone" else {"min_stone":2,"max_stone":3}
		check(earned >= reward["min_stone"] and earned <= reward["max_stone"], "resource reward amount matches resource type")
		resource._finish_harvest()
		resource._respawn()
		check(resource.state == "DEPLETED" and inv.get(resource.resource_type) == before+earned, "gather reward once and respawn deadline enforced")
		check(disk().get_value("inventory",resource.resource_type) == before+earned, "gather autosaved")
	# Missing any one resource must leave the entire balance and level unchanged.
	for id in inv.Progression.UPGRADES:
		if id in inv.Progression.BUILDINGS and not inv.owns_building(id):
			inv.set("owns_" + id, true)
		while not inv.next_upgrade(id).is_empty():
			var cost: Dictionary = inv.next_upgrade(id)
			var before_level: int = inv.get(id+"_level")
			for missing in ["coins","wood","stone"]:
				for item in ["coins","wood","stone"]:
					inv.set(item,cost[item])
				inv.set(missing,inv.get(missing)-1)
				var before: Array = balances()
				check(not inv.upgrade_structure(id) and balances() == before and inv.get(id+"_level") == before_level, "upgrade cannot partially charge")
			for item in ["coins","wood","stone"]:
				inv.set(item,cost[item])
			check(inv.upgrade_structure(id) and balances() == [0,0,0], "exact structure upgrade cost")
		check(not inv.upgrade_structure(id), "structure max level")
	inv.coins = 100000
	inv.player_level = 18
	for building in ["chicken_coop", "cow_shed"]:
		if not inv.owns_building(building):
			inv.set("owns_" + building, true)
	for animal in ["chicken", "cow"]:
		while inv.get(animal+"_count") < inv.animal_capacity(animal):
			check(inv.buy_animal(animal), "buy within animal capacity")
		make_adults(animal)
		var before: int = inv.coins
		check(not inv.buy_animal(animal) and inv.coins == before, "animal capacity limit")
	for id in ["chicken_coop","cow_shed"]:
		var station = manager.stations[id]
		var product: Dictionary = inv.Progression.PRODUCTS[id]
		var animal: String = product["animal"]
		var count: int = inv.get(animal+"_count")
		check(station.produce(), "full herd production starts")
		check(not inv.sell_animal(animal) and inv.get(animal+"_count") == count, "no animal trade mid-production")
		station.ready_at = Time.get_unix_time_from_system()-1.0
		station._finish_production()
		check(not inv.sell_animal(animal), "no animal trade before collection")
		check(station.collect() and inv.get(product["item"]) == count and not station.collect(), "one output per adult chicken/cow, no duplicate collection")
	# Storage rejects new items and keeps full-bin crops/products READY.
	for item in inv.SILO_ITEMS:
		inv.set(item,0)
	inv.wheat = inv.silo_capacity
	var before: int = inv.coins
	check(not inv.buy_seed("WHEAT") and inv.coins == before, "Silo full buy rejected")
	var plot = manager.plots["soil_01"]
	plot.restore_save_data({"state":"READY","crop_type":"WHEAT","planted_at":1.0,"ready_at":2.0})
	plot.harvest()
	check(plot.state == 2 and inv.wheat == inv.silo_capacity, "full Silo preserves crop")
	check(inv.sell_wheat() and inv.sell_wheat(), "free two Silo slots")
	plot.harvest()
	plot.harvest()
	check(plot.state == 0 and inv.storage_used("silo") == inv.silo_capacity, "x2 crop fills the two freed Silo slots")
	inv.wheat = 1
	inv.corn = 1
	for item in inv.BARN_ITEMS:
		inv.set(item,0)
	inv.milk = inv.barn_capacity
	var mill = farm.get_node("FeedMill")
	check(mill.produce("chicken_feed"), "craft consumes correct ingredients")
	check(inv.wheat == 0 and inv.corn == 0 and not mill.produce(), "busy mill cannot charge again")
	mill.ready_at = Time.get_unix_time_from_system()-1.0
	mill._finish_production()
	check(not mill.collect() and mill.state == "READY", "full Barn preserves batch")
	check(inv.sell_milk() and mill.collect() and not mill.collect(), "batch rewards once after freeing slot")
	check(inv.storage_used("barn") == inv.barn_capacity, "Barn capacity respected")
	# Malformed/unavailable saved orders cannot reward or deduct inventory.
	var invalid: Dictionary = {"order_id":"order_900000","requirements":{"golden_fish":4},"coin_reward":500,"exp_reward":5}
	orders.orders[0] = invalid
	check(not orders._is_valid_order(invalid), "old excessive rare-fish order invalid")
	var before_balances: Array = balances()
	check(not orders.complete_order("order_900000") and balances() == before_balances, "invalid order cannot pay out")
	orders.ensure_available_orders()
	check(orders._is_valid_order(orders.orders[0]), "invalid old order replaced")
	check(not orders._is_valid_order({"order_id":"order_900001","requirements":{"wheat":inv.silo_capacity+1},"coin_reward":100,"exp_reward":5}), "order must fit available Silo capacity")
	inv.chicken_count = 0
	inv.cow_count = 0
	inv.inventory_changed.emit()
	check(not orders.item_available("egg") and not orders.item_available("milk"), "no animals means no product orders")
	for order in orders.orders:
		for item in order["requirements"]:
			check(orders.item_available(item), "unavailable animal orders removed")
	# Autosave must be event/timer driven, not a per-frame write.
	inv.coins = 34567
	inv.inventory_changed.emit()
	inv.coins = 34568
	await create_timer(0.15).timeout
	check(disk().get_value("inventory","coins") == 34567, "no save every frame")
	check(manager.autosave_timer.wait_time == 30.0, "30-second autosave interval")
	manager.autosave_timer.start(0.05)
	await create_timer(0.12).timeout
	check(disk().get_value("inventory","coins") == 34568, "periodic autosave writes current snapshot")
	manager.autosave_timer.start(30.0)
	for item in manager.INVENTORY_DEFAULTS:
		check(inv.get(item) >= 0, "nonnegative inventory and Coins")

func audit_write() -> void:
	check(manager.reset_game(), "reset reload fixture")
	inv.tools_unlock_notified = true
	inv.player_level = 10
	inv.normalize_exp()
	inv.coins = 100000
	check(not inv.buy_plot(20), "cannot skip plot purchase order")
	inv.coins = 49
	check(not inv.buy_plot(9) and inv.coins == 49, "insufficient plot funds unchanged")
	inv.coins = 100000
	for number in range(9,33):
		var price: int = inv.FarmData.plot_price(number)
		var before: int = inv.coins
		check(inv.buy_plot(number) and inv.coins == before-price, "plot exact price")
		check(not inv.buy_plot(number) and inv.coins == before-price, "duplicate plot purchase blocked")
	check(not inv.buy_plot(33) and inv.unlocked_plot_count == 32, "maximum 32 plots")
	inv.wood = 10
	inv.stone = 5
	check(inv.upgrade_structure("silo"), "Silo space for reload harvest")
	var now: float = Time.get_unix_time_from_system()
	var index: int = 0
	for id in manager.PLOT_IDS:
		var crop: String = inv.CropData.CROPS.keys()[index%3]
		check(inv.select_crop(crop) and inv.buy_seed(crop), "buy seeds for all crops")
		var plot = manager.plots[id]
		plot.try_plant()
		check(plot.crop_type == crop and plot.state == 1, "all 32 plots plant independently")
		plot.planted_at = now-60 if index%2 == 0 else now
		plot.ready_at = now-1 if index%2 == 0 else now+120
		index += 1
	for id in ["feed_mill", "chicken_coop", "cow_shed"]:
		check(inv.buy_building(id), "reload fixture building")
	check(inv.buy_animal("chicken") and inv.buy_animal("cow"), "reload fixture animals")
	make_adults("chicken")
	make_adults("cow")
	check(inv.add_item("wheat",1) and inv.add_item("corn",1), "mill ingredients")
	inv.chicken_feed = 1
	inv.cow_feed = 1
	for id in ["feed_mill", "chicken_coop", "cow_shed"]:
		var station = manager.stations[id]
		check(station.produce(), "start station production")
		station.started_at = now-60
		station.ready_at = now-1
	check(manager.save_game(), "persist crops/production before offline completion")

func audit_read(already_collected: bool) -> void:
	check(inv.unlocked_plot_count == 32 and manager.plots.size() == 32, "all plot unlocks restored")
	var total_before: int = crop_inventory_total()
	check(total_before == (32 if already_collected else 0), "reload must not grant crops automatically; each ready plot yields two")
	var index: int = 0
	var positions: Array = []
	for id in manager.PLOT_IDS:
		var plot = manager.plots[id]
		check(plot.position not in positions, "32 unique grid positions")
		positions.append(plot.position)
		check(plot.get_node("CollisionShape2D").shape.size == Vector2(68,52), "plot collision preserved")
		if index%2 == 0:
			check(plot.state == (0 if already_collected else 2), "offline Ready or collected Empty")
			plot.harvest()
			plot.harvest()
		else:
			check(plot.state == 1 and plot.grow_timer.time_left > 30, "future crops resume remaining time")
		index += 1
	check(crop_inventory_total() == 32, "offline crops yield two each without duplication across reload")
	for id in manager.STATION_IDS:
		var station = manager.stations[id]
		check(station.state == (manager.default_station(id)["state"] if already_collected else "READY"), "production state restored")
		if not already_collected:
			check(station.collect(), "collect offline batch")
		check(not station.collect(), "cannot recollect batch")
	check(inv.chicken_feed == 1 and inv.egg == 1 and inv.milk == 1 and inv.cow_feed == 0, "product rewards exactly once after reload")
	check(inv.storage_used("silo") <= inv.silo_capacity and inv.storage_used("barn") <= inv.barn_capacity, "storage limits after reload")


func animal_output() -> void:
	check(manager.reset_game(), "reset animal output fixture")
	inv.player_level = 18
	inv.coins = 100000
	for animal in ["chicken", "cow", "pig", "sheep"]:
		var building: String = inv.Progression.ANIMALS[animal]["building"]
		inv.set("owns_" + building, true)
		check(inv.buy_animal(animal) and inv.buy_animal(animal), "buy two animal fixtures: " + animal)
		if animal == "chicken":
			inv.chicken_feed = 1
			check(not manager.stations["chicken_coop"].can_produce(), "baby animals cannot produce before adulthood")
			var legacy_batch := ConfigFile.new()
			var now: float = Time.get_unix_time_from_system()
			legacy_batch.set_value("chicken_coop", "state", "PRODUCING")
			legacy_batch.set_value("chicken_coop", "production_type", "EGG")
			legacy_batch.set_value("chicken_coop", "started_at", now)
			legacy_batch.set_value("chicken_coop", "ready_at", now + 10.0)
			var migrated_batch: Dictionary = manager._read_station(legacy_batch, "chicken_coop")
			check(migrated_batch["state"] == "PRODUCING" and migrated_batch["participant_animal_ids"].size() == 2, "legacy active batch keeps its paid animal snapshot during migration")
		make_adults(animal)
	var pigs: Array = manager.animal_rosters["pig"]
	pigs[0]["lucky"] = false
	pigs[1]["lucky"] = true
	manager.animal_rosters["pig"] = pigs
	check(manager.save_game(), "save lucky pig identities")
	var lucky_save := ConfigFile.new()
	check(lucky_save.load(manager.SAVE_PATH) == OK, "read lucky pig identities")
	manager._restore_animal_rosters(lucky_save)
	check(manager.animal_rosters["pig"][0]["lucky"] == false and manager.animal_rosters["pig"][1]["lucky"] == true, "Lucky Pig status does not reroll on load")
	for station_id in ["chicken_coop", "cow_shed", "sheep_barn", "pig_pen"]:
		var station = manager.stations[station_id]
		var product: Dictionary = inv.Progression.PRODUCTS[station_id]
		inv.set(product["feed"], 1)
		check(station.can_produce() and station.produce(), "adult livestock production starts: " + station_id)
		var expected: int = 5 if station_id == "pig_pen" else 2
		check(station.output_data()["amount"] == expected, "animal output follows per-species data: " + station_id)
		station.ready_at = Time.get_unix_time_from_system() - 1.0
		station._finish_production()
		if station_id == "pig_pen":
			inv.pork = inv.barn_capacity - 4
			check(not station.collect() and station.state == "READY" and inv.pig_count == 2, "full Barn keeps pork output and pigs safely")
			inv.pork = 0
		check(station.collect() and not station.collect(), "livestock batch collected exactly once: " + station_id)
		check(inv.get(product["item"]) == expected, "animal output is not doubled: " + station_id)
		if station_id == "pig_pen":
			check(inv.pig_count == 0 and manager.animal_records("pig").is_empty(), "slaughter removes each pig from roster/count")
