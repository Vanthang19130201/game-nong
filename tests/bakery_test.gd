extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var orders: Node
const CAKES: Array[String] = ["egg_cake","milk_cake","pancake"]

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "save readable")
	return data

func setup_owned(level: int) -> Node:
	inv.player_level = level
	inv.coins = 10000
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	check(inv.buy_building("bakery"), "purchase")
	return farm.get_node("Bakery")

func cake_checks() -> void:
	check(manager.reset_game(),"new recipes fixture")
	var bakery: Node = setup_owned(11)
	var hud: Node = farm.get_node("HUD")
	var item_data = load("res://item_ui_data.gd")
	for item in CAKES:
		var recipe: Dictionary = inv.BakeryData.RECIPES[item]
		var raw_price: int = 0
		for ingredient in recipe["requirements"]:
			raw_price += item_data.sell_price(ingredient)*recipe["requirements"][ingredient]
		check(recipe["price"] > raw_price,"processing profits over raw ingredients: "+item)
		check(hud.storage_panel.item_cells.has(item) and hud.product_sell_buttons.has(item),"existing Barn grid and Shop include "+item)
		check(root.get_node("Localization").display_name(item) == recipe["name"],"localized recipe and item label: "+item)
	check(not orders.item_available("egg_cake") and not orders.item_available("milk_cake") and not orders.item_available("pancake"),"no cake orders before ingredient production is owned")
	inv.owns_feed_mill = true
	inv.owns_chicken_coop = true
	inv.chicken_count = 1
	check(orders.item_available("egg_cake") and not orders.item_available("pancake"),"egg cake orders require egg production, pancake also needs milk")
	inv.owns_cow_shed = true
	inv.cow_count = 1
	check(orders.item_available("milk_cake") and orders.item_available("pancake"),"milk recipes available with milk production")
	inv.wheat = 3
	inv.egg = 2
	inv.milk = 2
	inv.player_level = 6
	check(not bakery.enqueue("egg_cake") and inv.wheat == 3 and inv.egg == 2,"egg cake level lock never charges")
	inv.player_level = 9
	check(not orders.item_available("milk_cake") and not bakery.enqueue("milk_cake") and inv.milk == 2,"milk cake stays locked before level 10")
	inv.player_level = 10
	check(orders.item_available("milk_cake") and not orders.item_available("pancake") and not bakery.enqueue("pancake"),"pancake unlocks at level 11")
	inv.player_level = 11
	inv.egg = 0
	check(not bakery.enqueue("pancake") and inv.wheat == 3 and inv.milk == 2 and manager.bakery_queue.is_empty(),"missing one ingredient never partially deducts")
	inv.egg = 2
	for item in CAKES:
		check(bakery.enqueue(item),"enqueue new recipe: "+item)
		var entry: Dictionary = manager.bakery_queue.back()
		check(is_equal_approx(entry["ready_at"]-entry["started_at"],inv.BakeryData.RECIPES[item]["time"]),"new recipe duration: "+item)
	check(inv.wheat == 0 and inv.egg == 0 and inv.milk == 0 and manager.bakery_queue.size() == 3,"three mixed cakes charge all ingredients exactly once")
	check(not bakery.enqueue("egg_cake") and manager.bakery_queue.size() == 3,"fourth recipe cannot enter queue")
	for entry in manager.bakery_queue:
		entry["started_at"] = Time.get_unix_time_from_system()-200
		entry["ready_at"] = Time.get_unix_time_from_system()-1
	bakery._finish_production()
	inv.chicken_feed = inv.barn_capacity
	var before: Array = manager.bakery_queue.duplicate(true)
	check(not bakery.collect() and manager.bakery_queue == before and inv.egg_cake == 0,"full Barn preserves every finished cake")
	inv.chicken_feed -= 1
	check(bakery.collect() and inv.egg_cake == 1 and manager.bakery_queue.size() == 2,"one free slot collects exactly one cake")
	check(not bakery.collect() and manager.bakery_queue.size() == 2 and inv.milk_cake == 0,"spam while full never loses or duplicates remaining cake")
	inv.chicken_feed = 0
	check(bakery.collect() and bakery.collect() and not bakery.collect(),"remaining cakes collect once in FIFO order")
	check(inv.egg_cake == 1 and inv.milk_cake == 1 and inv.pancake == 1,"all new products stored in existing Barn")
	check(disk().get_value("inventory","pancake") == 1 and disk().get_value("bakery","bakery_queue").is_empty(),"product and output removal autosave together")
	for item in CAKES:
		var before_coins: int = inv.coins
		var used: int = inv.storage_used("barn")
		check(inv.sell_bakery_item(item) and inv.coins == before_coins+inv.BakeryData.RECIPES[item]["price"] and inv.storage_used("barn") == used-1,"sale uses central price and frees Barn: "+item)
		check(not inv.sell_bakery_item(item) and inv.get(item) == 0,"empty product cannot sell twice: "+item)
	farm.get_node("Player").position = bakery.position
	await create_timer(0.1).timeout
	hud.open_bakery(bakery)
	for item in CAKES:
		check(hud.bakery_panel.view.cards.has(item),"recipe in existing Bakery cards")
		hud.bakery_panel.refresh()
		check(hud.bakery_panel.view.cards[item].content.modulate.a == 1.0,"unlocked recipe card is readable")
	check(manager.reset_game() and not inv.owns_bakery and manager.bakery_queue.is_empty(),"reset clears ownership and queue")
	for item in CAKES:
		check(inv.get(item) == 0,"reset clears new item: "+item)

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"bakery_cakes":
			await cake_checks()
		"bakery_cakes_write":
			check(manager.reset_game(),"cake save fixture")
			var bakery: Node = setup_owned(11)
			inv.wheat = 3
			inv.egg = 2
			inv.milk = 2
			inv.egg_cake = 1
			inv.milk_cake = 2
			inv.pancake = 3
			for item in CAKES:
				check(bakery.enqueue(item),"save mixed cake queue")
			var now: float = Time.get_unix_time_from_system()
			for i in range(3):
				manager.bakery_queue[i]["started_at"] = now-60 if i == 0 else now-1+120*(i-1)
				manager.bakery_queue[i]["ready_at"] = now-5 if i == 0 else now+120*i
			check(manager.save_game(),"save new product counts and queue timestamps")
		"bakery_cakes_read":
			var bakery: Node = farm.get_node("Bakery")
			check(inv.owns_bakery and inv.egg_cake == 1 and inv.milk_cake == 2 and inv.pancake == 3,"new items restore with existing ownership")
			check(manager.bakery_queue.size() == 3 and manager.bakery_queue.map(func(entry): return entry["item"]) == CAKES,"mixed new recipes restore without duplication")
			check(manager.bakery_queue[0]["state"] == "READY" and manager.bakery_queue[1]["state"] == "PRODUCING" and manager.bakery_queue[2]["state"] == "QUEUED","new recipes resume offline production states")
			check(manager.bakery_queue[1]["ready_at"] == disk().get_value("bakery","bakery_queue")[1]["ready_at"],"production deadline unchanged after load")
			check(bakery.collect() and inv.egg_cake == 2 and not bakery.collect(),"offline-ready cake collects once")
		"bakery_cakes_again":
			var bakery: Node = farm.get_node("Bakery")
			check(inv.egg_cake == 2 and inv.milk_cake == 2 and inv.pancake == 3 and manager.bakery_queue.size() == 2 and not bakery.collect(),"reload never duplicates collected cake")
			for entry in manager.bakery_queue:
				entry["started_at"] = Time.get_unix_time_from_system()-200
				entry["ready_at"] = Time.get_unix_time_from_system()-1
			bakery._finish_production()
			check(bakery.collect() and bakery.collect() and inv.milk_cake == 3 and inv.pancake == 4,"remaining new products preserved")
			check(manager.reset_game(),"cake save cleanup")
		"bakery_legacy_write":
			check(manager.reset_game(),"legacy Bakery fixture")
			var bakery: Node = setup_owned(12)
			inv.bread = 2
			inv.wheat = 2
			check(bakery.enqueue("bread"),"legacy recipe remains valid")
			manager.bakery_queue[0]["ready_at"] = Time.get_unix_time_from_system()+120
			check(manager.save_game(),"legacy base save")
			var old_save := disk()
			for item in CAKES:
				old_save.erase_section_key("inventory",item)
			check(old_save.save(manager.SAVE_PATH) == OK,"old save without new inventory fields")
		"bakery_legacy_read":
			check(inv.owns_bakery and inv.bread == 2 and farm.get_node_or_null("Bakery") != null,"old purchased Bakery and inventory remain intact")
			check(manager.bakery_queue.size() == 1 and manager.bakery_queue[0]["item"] == "bread" and manager.bakery_queue[0]["ready_at"] == disk().get_value("bakery","bakery_queue")[0]["ready_at"],"old queue and timestamps remain unchanged")
			for item in CAKES:
				check(inv.get(item) == 0,"missing old-save field defaults to zero: "+item)
			check(manager.reset_game(),"legacy cleanup")
		"bakery_core":
			check(manager.reset_game(), "reset fixture")
			inv.player_level = 2
			inv.coins = 10000
			check(not inv.buy_building("bakery") and inv.coins == 10000, "level 2 locked")
			check(not orders.item_available("bread"), "unowned orders locked")
			check(inv.Progression.FEATURES["Bakery"] == 3 and inv.Progression.BUILDINGS["bakery"]["level"] == 3,"feature and purchase unlock both level 3")
			inv.player_level = 3
			inv.coins = 399
			check(not inv.buy_building("bakery") and inv.coins == 399,"early price still checks sufficient Coins")
			var bakery = setup_owned(3)
			check(inv.coins == 9600 and inv.owns_bakery and bakery.visible, "400 Coins and instant existing Bakery spawn")
			check(bakery.position == Vector2(1250,1320), "mainland spawn")
			check(not inv.buy_building("bakery") and inv.coins == 9600, "no duplicate purchase")
			check(disk().get_value("buildings", "owns_bakery") == true, "ownership autosave")
			check(orders.item_available("bread") and not orders.item_available("corn_bread"), "recipe order gate")
			check(not bakery.enqueue("bread") and manager.bakery_queue.is_empty(), "missing ingredients")
			inv.wheat = 6
			check(not bakery.enqueue("corn_bread"), "recipe level lock")
			for i in range(3):
				check(bakery.enqueue("bread"), "queue recipe")
				var entry: Dictionary = manager.bakery_queue[i]
				check(is_equal_approx(entry["ready_at"] - entry["started_at"], 20.0), "Bread duration")
				if i > 0:
					check(entry["started_at"] >= manager.bakery_queue[i-1]["ready_at"], "sequential production timestamps")
			check(inv.wheat == 0 and manager.bakery_queue.size() == 3, "deduct at enqueue")
			check(not bakery.enqueue("bread") and not bakery.collect(), "queue limit and no early collection")
			check(disk().get_value("bakery", "bakery_queue").size() == 3, "queue autosave")
			for entry in manager.bakery_queue:
				entry["started_at"] = Time.get_unix_time_from_system()-100
				entry["ready_at"] = Time.get_unix_time_from_system()-1
			bakery._finish_production()
			inv.egg = inv.barn_capacity
			check(not bakery.collect() and manager.bakery_queue.size() == 3, "full Barn preserves ready output")
			inv.egg = 0
			for i in range(3):
				check(bakery.collect(), "collect ready")
			check(inv.bread == 3 and not bakery.collect(), "no duplicate collection")
			var previous: int = inv.coins
			check(inv.sell_bakery_item("bread") and inv.coins == previous+32 and inv.storage_used("barn") == 2, "price and Barn sale")
			check(not inv.sell_bakery_item("coins"), "invalid sale denied")
			for level in [4,5]:
				inv.player_level = level
				check(orders.item_available("corn_bread"), "corn bread level 4 order")
				check(orders.item_available("carrot_pie") == (level == 5), "pie level 5 order")
			farm.get_node("Player").position = bakery.position
			await create_timer(0.1).timeout
			var event := InputEventKey.new()
			event.physical_keycode = KEY_E
			event.keycode = KEY_E
			event.pressed = true
			Input.parse_input_event(event)
			await process_frame
			var hud = farm.get_node("HUD")
			check(hud.bakery_panel.visible and hud.blocks_world_input(), "central E and modal lock")
			hud.close_current_panel()
			check(not hud.bakery_panel.visible, "ESC close path")
			check(manager.reset_game() and not inv.owns_bakery and manager.bakery_queue.is_empty() and inv.bread == 0 and bakery.production_timer.is_stopped(), "clean bakery reset")
			check(inv.BakeryData.restore_queue([null, {"item":"unknown"}, {"item":"bread", "ready_at":"bad"}]).is_empty(), "malformed queue migration")
		"bakery_write":
			check(manager.reset_game(), "offline fixture")
			var bakery = setup_owned(14)
			inv.wheat = 5
			inv.corn = 1
			inv.carrot = 1
			for item in ["bread","corn_bread","carrot_pie"]:
				check(bakery.enqueue(item), "offline queue")
			check(inv.wheat == 0 and inv.corn == 0 and inv.carrot == 0, "all recipes correct costs")
			var now: float = Time.get_unix_time_from_system()
			for i in range(3):
				manager.bakery_queue[i]["started_at"] = now-25 if i == 0 else now-1+120*(i-1)
				manager.bakery_queue[i]["ready_at"] = now-5 if i == 0 else now+120*i
			check(manager.save_game(), "save offline queue")
		"bakery_read":
			var bakery = farm.get_node("Bakery")
			check(inv.owns_bakery and bakery.visible and manager.bakery_queue.size() == 3, "owned queue restored")
			check(manager.bakery_queue[0]["state"] == "READY" and manager.bakery_queue[1]["state"] == "PRODUCING" and manager.bakery_queue[2]["state"] == "QUEUED", "offline states")
			check(bakery.production_timer.time_left > 30, "remaining timer restored")
			check(bakery.collect() and inv.bread == 1 and not bakery.collect(), "collect once after reload")
		"bakery_again":
			var bakery = farm.get_node("Bakery")
			check(inv.bread == 1 and manager.bakery_queue.size() == 2 and not bakery.collect(), "no reload duplicate")
			for entry in manager.bakery_queue:
				entry["started_at"] = Time.get_unix_time_from_system()-100
				entry["ready_at"] = Time.get_unix_time_from_system()-1
			bakery._finish_production()
			check(bakery.collect() and bakery.collect() and inv.corn_bread == 1 and inv.carrot_pie == 1, "queued outputs preserved")
			var previous: int = inv.coins
			check(inv.sell_bakery_item("corn_bread") and inv.sell_bakery_item("carrot_pie") and inv.coins == previous+128, "remaining sell prices")
			check(manager.reset_game() and not inv.owns_bakery and manager.bakery_queue.is_empty() and inv.bread == 0, "reset persisted")
		"bakery_reset_read":
			check(not inv.owns_bakery and manager.bakery_queue.is_empty() and farm.get_node_or_null("Bakery") == null, "reset reload no bakery")
			check(inv.bread == 0 and inv.corn_bread == 0 and inv.carrot_pie == 0, "reset items")
			for item in CAKES:
				check(inv.get(item) == 0,"new item reset persists: "+item)
	print("PASS: " + stage)
	quit()
