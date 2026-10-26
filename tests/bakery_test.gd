extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var orders: Node

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
		"bakery_core":
			check(manager.reset_game(), "reset fixture")
			inv.player_level = 11
			inv.coins = 10000
			check(not inv.buy_building("bakery") and inv.coins == 10000, "level 11 locked")
			check(not orders.item_available("bread"), "unowned orders locked")
			var bakery = setup_owned(12)
			check(inv.coins == 7000 and inv.owns_bakery and bakery.visible, "exact price and instant spawn")
			check(bakery.position == Vector2(1250,1320), "mainland spawn")
			check(not inv.buy_building("bakery") and inv.coins == 7000, "no duplicate purchase")
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
			for level in [13,14]:
				inv.player_level = level
				check(orders.item_available("corn_bread"), "corn bread level 13 order")
				check(orders.item_available("carrot_pie") == (level == 14), "pie level 14 order")
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
			for item in inv.BakeryData.RECIPES:
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
	print("PASS: " + stage)
	quit()
