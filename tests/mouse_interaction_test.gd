extends SceneTree

var player: Node
var hud: Node
var inv: Node
var manager: Node
var farm: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func click_world(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = player.get_canvas_transform() * point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	await create_timer(0.03).timeout
	event = InputEventMouseButton.new()
	event.position = player.get_canvas_transform() * point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)
	await create_timer(0.03).timeout

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.03).timeout
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await create_timer(0.03).timeout

func stand(point: Vector2) -> void:
	player.position = point
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	check(manager.reset_game(), "reset fixture")
	player = farm.get_node("Player")
	hud = farm.get_node("HUD")
	inv.player_level = 18
	inv.fishing_unlocked = true
	inv.has_fishing_rod = true
	inv.fishing_rod_level = 1
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.normalize_exp()
	inv.inventory_changed.emit()
	var warehouse = farm.get_node("Warehouse")
	await stand(warehouse.position + Vector2(0,60))
	await click_world(warehouse.position)
	check(hud.storage_panel.visible, "click Warehouse opens storage")
	await key(KEY_ESCAPE)
	check(not hud.blocks_world_input(), "ESC closes clicked panel")
	var house = farm.get_node("House")
	await stand(house.position + Vector2(0,100))
	await click_world(house.position)
	check(hud.house_panel.visible, "click House")
	await key(KEY_ESCAPE)
	for id in ["feed_mill", "chicken_coop", "cow_shed", "bakery"]:
		check(inv.buy_building(id), "building fixture")
		var building = farm.get_node(inv.FarmData.BUILDINGS[id]["node"])
		await stand(building.position + Vector2(0,50))
		await click_world(building.position)
		check(hud.bakery_panel.visible if id == "bakery" else hud.station_panel.visible, "click production building " + id)
		await key(KEY_ESCAPE)
	var board = farm.get_node("OrderBoard")
	await stand(board.position)
	await click_world(board.position)
	check(hud.order_panel.visible, "click Order Board")
	await key(KEY_ESCAPE)
	var plot = manager.plots["soil_01"]
	await stand(plot.position)
	var seeds: int = inv.wheat_seed
	await click_world(plot.position + Vector2(-250,180))
	check(inv.wheat_seed == seeds and plot.state == 0, "empty click must not fall back to nearest")
	var mouse = player.mouse_interaction
	var original: Color = plot.modulate
	mouse.update_hover(player.get_canvas_transform() * plot.position)
	check(mouse.hovered == plot and plot.modulate != original and mouse.hint.visible, "hover highlight and hint")
	mouse.clear_hover()
	check(plot.modulate == original and not mouse.hint.visible, "hover restores original appearance")
	await click_world(plot.position)
	check(plot.state == 1 and inv.wheat_seed == seeds-1, "mouse uses planting logic")
	await click_world(plot.position)
	check(inv.wheat_seed == seeds-1, "growing plot cannot duplicate planting")
	plot.ready_at = Time.get_unix_time_from_system()-1
	plot._on_grow_timer_timeout()
	await click_world(plot.position)
	check(plot.state == 0 and inv.wheat == 1, "mouse harvest")
	await key(KEY_E)
	check(plot.state == 1 and inv.wheat_seed == seeds-2, "E still uses same dispatcher")
	await key(KEY_P)
	player.interact_at_screen_position(player.get_canvas_transform() * plot.position)
	check(hud.shop_build_panel.visible and inv.wheat == 1, "modal blocks world mouse")
	await key(KEY_TAB)
	check(hud.storage_panel.visible and not hud.shop_build_panel.visible, "Tab modal switch unchanged")
	await key(KEY_ESCAPE)
	await stand(Vector2(300,400))
	await click_world(warehouse.position)
	check(not hud.blocks_world_input(), "click keeps proximity requirement")
	for resource_type in ["wood", "stone"]:
		var resource: Node
		for node in manager.resources.values():
			if node.resource_type == resource_type and node.zone_active:
				resource = node
				break
		await stand(resource.global_position)
		await click_world(resource.global_position)
		check(resource.state == "GATHERING" and player.active_resource == resource, "click gather " + resource_type)
		resource._finish_harvest()
		var amount: int = inv.get(resource_type)
		resource._finish_harvest()
		await click_world(resource.global_position)
		check(inv.get(resource_type) == amount and amount >= 2, "no duplicate gathering reward")
	var spot = farm.get_node("FishingSpot")
	await stand(spot.position)
	player.facing_vector = Vector2.RIGHT
	hud.hotbar.select_slot(7)
	await create_timer(0.1).timeout
	await click_world(spot.position)
	check(spot.state == spot.State.WAITING_FOR_BITE and inv.fishing_attempts_used == 1, "click layer-0 FishingSpot casts")
	await click_world(spot.position + Vector2(-250,-100))
	check(spot.state == spot.State.WAITING_FOR_BITE, "empty click does not reel")
	await click_world(spot.position)
	check(spot.state == spot.State.WAITING_FOR_BITE, "world click cannot reel")
	await key(KEY_SPACE)
	check(spot.state == spot.State.FAILED, "SPACE too early keeps fishing rules")
	hud.fishing_ui.close_session()
	spot.state = spot.State.IDLE
	await click_world(spot.position)
	spot.state = spot.State.BITE_WINDOW
	spot.deadline = spot.now()+1
	await click_world(spot.position)
	check(spot.state == spot.State.BITE_WINDOW, "world click does not catch fish")
	await key(KEY_SPACE)
	check(spot.state == spot.State.SUCCESS and inv.small_fish+inv.river_fish+inv.golden_fish == 1, "SPACE reels fish")
	await click_world(spot.position)
	check(inv.small_fish+inv.river_fish+inv.golden_fish == 1 and inv.fishing_attempts_used == 2, "no duplicate fish or extra attempts")
	hud.fishing_ui.close_session()
	var market = farm.get_node("FishMarket")
	await stand(market.position)
	await click_world(market.position)
	check(hud.fish_market_panel.visible, "click Fish Market")
	await key(KEY_ESCAPE)
	check(not hud.blocks_world_input(), "ESC still restores world input")
	check(manager.reset_game(), "clean mouse test fixture")
	print("PASS: mouse_core")
	quit()
