extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.05).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.05).timeout

func run_checks() -> void:
	await process_frame
	await process_frame
	var inv = root.get_node("Inventory")
	var manager = root.get_node("SaveManager")
	var orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	var farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	var hud = farm.get_node("HUD")
	var panel = hud.fish_market_panel
	var market = farm.get_node("FishMarket")
	var player = farm.get_node("Player")
	var spot = farm.get_node("FishingSpot")
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "market_read":
		check(inv.coins == 123456 and inv.small_fish == 0 and inv.river_fish == 1 and inv.golden_fish == 0, "sale result restored")
		check(inv.player_level == 10 and market.visible, "market fixed on load")
		check(inv.storage_used("barn") == 1, "Barn restored after selling")
	else:
		check(manager.reset_game(), "reset test save")
		inv.player_level = 9
		inv.tools_unlock_notified = true
		player.position = market.position
		await create_timer(0.1).timeout
		await key(KEY_E)
		check(market.visible and market.position.x > 1940 and not market.can_interact() and not panel.visible, "level 9 visible but locked")
		check(not orders.item_available("river_fish") and not inv.sell_fish("river_fish"), "fish orders/sales level gated")
		inv.add_exp(900)
		await create_timer(0.1).timeout
		check(market.can_interact() and inv.has_fishing_rod and orders.item_available("river_fish"), "level 10 market/rod/order access")
		inv.coins = 1000
		check(inv.add_item("small_fish",3) and inv.add_item("river_fish",2) and inv.add_item("golden_fish",1), "stock test fish")
		await key(KEY_E)
		check(panel.visible and spot.state == spot.State.IDLE and hud.blocks_world_input(), "E opens market only")
		check(panel.rows["small_fish"]["label"].text.contains("Owned: 3") and panel.rows["river_fish"]["label"].text.contains("40 Coins"), "market data labels")
		panel.rows["small_fish"]["one"].pressed.emit()
		check(inv.small_fish == 2 and inv.coins == 1025 and inv.storage_used("barn") == 5, "sell one atomic")
		panel.rows["small_fish"]["all"].pressed.emit()
		check(inv.small_fish == 0 and inv.coins == 1075 and inv.storage_used("barn") == 3, "sell all one species")
		panel.rows["small_fish"]["all"].pressed.emit()
		check(inv.coins == 1075 and panel.rows["small_fish"]["one"].disabled, "repeat sale cannot duplicate reward")
		panel.rows["river_fish"]["one"].pressed.emit()
		panel.rows["golden_fish"]["all"].pressed.emit()
		check(inv.coins == 1215 and inv.river_fish == 1 and inv.storage_used("barn") == 1, "all fish prices/Barn")
		check(not inv.sell_fish("coins",true) and not inv.sell_fish("unknown"), "reject invalid item")
		await key(KEY_E)
		check(panel.visible and spot.state == spot.State.IDLE, "E under market is blocked")
		check(hud.storage_label.text.contains("Barn: 1 / 20"), "HUD refreshed")
		var saved := ConfigFile.new()
		check(saved.load(manager.SAVE_PATH) == OK and saved.get_value("inventory","coins") == 1215 and saved.get_value("inventory","river_fish") == 1, "sale auto saved")
		await key(KEY_ESCAPE)
		check(not panel.visible and not hud.blocks_world_input(), "ESC closes market")
		# Both areas overlap here: only the closer Market receives E.
		player.position = Vector2(2110,980)
		await create_timer(0.1).timeout
		check(spot.can_interact() and market.can_interact(), "overlap test setup")
		await key(KEY_E)
		check(panel.visible and spot.state == spot.State.IDLE, "nearest target wins overlap")
		hud.open_build()
		check(hud.build_panel.visible and not panel.visible, "switching panels never stacks")
		hud.close_all_panels()
		player.position = spot.position
		await create_timer(0.1).timeout
		await key(KEY_E)
		check(spot.state == spot.State.WAITING_FOR_BITE and not panel.visible, "fishing still starts normally")
		hud.close_all_panels()
		# Fish orders use the centralized direct price with existing reward multiplier.
		orders.rng.seed = 42
		var saw_fish: bool = false
		var items: Dictionary = orders.item_info()
		for index in range(200):
			var order: Dictionary = orders._generate_order()
			var total: int = 0
			for item in order["requirements"]:
				total += items[item]["price"] * order["requirements"][item]
				if inv.FishingData.FISH.has(item):
					saw_fish = true
			check(order["coin_reward"] >= ceili(total*1.25) and order["coin_reward"] <= floori(total*1.5) and order["exp_reward"] > 0, "order premium/EXP")
		check(saw_fish, "fish appear in level 10 orders")
		orders.orders[0] = {"order_id":"order_999999", "requirements":{"river_fish":1}, "coin_reward":50,"exp_reward":5}
		check(orders.complete_order("order_999999") and inv.river_fish == 0 and inv.coins == 1265, "fish order consumes fish")
		check(not orders.complete_order("order_999999"), "order cannot be rewarded twice")
		check(inv.add_item("river_fish",1), "persist remaining fish")
		inv.coins = 123456
		inv.inventory_changed.emit()
	print("PASS: ", stage)
	quit()
