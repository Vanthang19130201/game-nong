extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.04).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(0.04).timeout

func run_checks() -> void:
	await process_frame
	await process_frame
	var inv = root.get_node("Inventory")
	var manager = root.get_node("SaveManager")
	assert(manager.SAVE_PATH == "res://test-save.cfg", "Run only through isolated test runner")
	var orders = root.get_node("OrderManager")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var hud = main.get_node("HUD")
	var player = main.get_node("Player")
	await create_timer(0.1).timeout
	assert(manager.reset_game())
	assert(get_nodes_in_group("farm_interactables").size() == 53)
	for plot in manager.plots.values():
		if not plot.is_unlocked():
			continue
		player.position = plot.position
		await create_timer(0.1).timeout
		await key(KEY_E)
		assert(plot.state == 1)
	assert(inv.wheat_seed == 2)
	inv.add_exp(4500)
	inv.add_coins(10000)
	await create_timer(0.1).timeout
	assert(inv.player_level == 10 and hud.tools_unlock_popup.visible)
	hud.tools_unlock_popup.get_ok_button().pressed.emit()
	for id in manager.STATION_IDS:
		assert(inv.buy_building(id))
	assert(inv.buy_animal("chicken") and inv.buy_animal("cow"))
	inv.wheat = 1
	inv.corn = 3
	inv.carrot = 1
	inv.inventory_changed.emit()
	var mill = main.get_node("FeedMill")
	var coop = main.get_node("ChickenCoop")
	var cows = main.get_node("CowShed")
	player.position = mill.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	assert(hud.active_station == mill)
	hud.produce_button.pressed.emit()
	assert(mill.state == "PRODUCING" and inv.wheat == 0 and inv.corn == 2)
	mill.ready_at = Time.get_unix_time_from_system()-0.1
	mill.production_timer.start(0.01)
	await create_timer(0.1).timeout
	hud.collect_button.pressed.emit()
	assert(inv.chicken_feed == 1)
	await key(KEY_ESCAPE)
	player.position = coop.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	assert(hud.active_station == coop)
	hud.produce_button.pressed.emit()
	assert(coop.state == "PRODUCING")
	coop.ready_at = Time.get_unix_time_from_system()-0.1
	coop.production_timer.start(0.01)
	await create_timer(0.1).timeout
	hud.collect_button.pressed.emit()
	assert(inv.egg == 1)
	await key(KEY_ESCAPE)
	player.position = mill.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	hud.recipe_selector.select(1)
	hud.recipe_selector.item_selected.emit(1)
	hud.produce_button.pressed.emit()
	assert(mill.state == "PRODUCING" and inv.corn == 0 and inv.carrot == 0)
	mill.ready_at = Time.get_unix_time_from_system()-0.1
	mill.production_timer.start(0.01)
	await create_timer(0.1).timeout
	hud.collect_button.pressed.emit()
	assert(inv.cow_feed == 1)
	await key(KEY_ESCAPE)
	player.position = cows.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	assert(hud.active_station == cows)
	hud.produce_button.pressed.emit()
	assert(cows.state == "PRODUCING")
	cows.ready_at = Time.get_unix_time_from_system()-0.1
	cows.production_timer.start(0.01)
	await create_timer(0.1).timeout
	hud.collect_button.pressed.emit()
	assert(inv.milk == 1)
	await key(KEY_ESCAPE)
	assert(inv.sell_egg() and inv.sell_milk())
	assert(inv.buy_dog() and is_instance_valid(main.dog))
	player.position = main.get_node("OrderBoard").position
	await create_timer(0.1).timeout
	await key(KEY_E)
	assert(hud.order_panel.visible and hud.order_cards.get_child_count() == 3)
	var order: Dictionary = orders.orders[0].duplicate(true)
	for item in order["requirements"]:
		var amount: int = order["requirements"][item]-inv.get(item)
		if amount > 0:
			assert(inv.add_item(item, amount))
	assert(orders.complete_order(order["order_id"]))
	await key(KEY_ESCAPE)
	var reset_position: Vector2 = hud.reset_button.get_global_transform_with_canvas().origin
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	var before: Vector2 = player.position
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	Input.action_release("move_right")
	assert(player.position.x > before.x + 20.0)
	assert(hud.reset_button.get_global_transform_with_canvas().origin == reset_position)
	hud.shop_button.pressed.emit()
	await key(KEY_ESCAPE)
	assert(not hud.shop_panel.is_visible_in_tree())
	hud.get_node("ResetControls/SettingsButton").pressed.emit()
	assert(hud.settings_panel.visible and hud.reset_button.is_visible_in_tree() and inv.has_dog)
	hud.reset_button.pressed.emit()
	assert(hud.reset_confirmation.visible and not hud.settings_panel.visible and inv.has_dog)
	await key(KEY_ESCAPE)
	assert(not hud.reset_confirmation.visible and inv.has_dog)
	hud.get_node("ResetControls/SettingsButton").pressed.emit()
	hud.reset_button.pressed.emit()
	hud.reset_confirmation.get_ok_button().pressed.emit()
	assert(not inv.has_dog and not is_instance_valid(main.dog) and not inv.has_axe)
	assert(inv.chicken_count == 0 and inv.cow_count == 0 and inv.axe_level == 0)
	assert(inv.silo_capacity == 30 and inv.barn_capacity == 20 and orders.orders.size() == 3)
	await create_timer(0.15).timeout
	assert(not is_instance_valid(main) and is_instance_valid(current_scene))
	assert(inv.player_level == 1 and inv.player_exp == 0 and inv.coins == 100)
	assert(inv.unlocked_plot_count == 8 and inv.house_level == 1)
	assert(not current_scene.get_node("HUD").settings_panel.visible)
	var saved := ConfigFile.new()
	assert(saved.load(manager.SAVE_PATH) == OK)
	assert(saved.get_value("inventory", "coins") == 100)
	print("PASS: eight crops, both feed recipes, eggs, milk, orders, dog, movement/camera/HUD, shop, ESC, reset")
	quit()
