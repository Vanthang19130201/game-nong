extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
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
	var manager = root.get_node("SaveManager")
	var inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.1).timeout
	check(manager.reset_game(), "reset test")
	var hud = main.get_node("HUD")
	var panel = hud.storage_panel
	var produce = panel.get_node("Margin/Content/Tabs/Produce/Items")
	var goods = panel.get_node("Margin/Content/Tabs/Goods/Items")
	var materials = panel.get_node("Margin/Content/Tabs/Materials/Items")
	check(not hud.storage_label.visible and hud.storage_label.text.is_empty(), "no permanent inventory/storage HUD")
	check(hud.inventory_label.text == tr("HUD_COMPACT") % [100,1], "compact Coins/level")
	check(hud.experience_bar.max_value == 100 and hud.experience_bar.value == 0, "EXP bar")
	check(InputMap.has_action("toggle_inventory"), "Tab action exists")
	var tab_bound: bool = false
	for event in InputMap.action_get_events("toggle_inventory"):
		if event is InputEventKey and event.physical_keycode == KEY_TAB:
			tab_bound = true
	check(tab_bound, "physical Tab binding")
	check(produce.text.contains("Lúa mì: 10") and produce.text.contains("10 / 30"), "existing inventory data")
	check(panel.tabs.get_tab_count() == 3 and panel.tabs.get_tab_title(2) == "NGUYÊN LIỆU", "three Vietnamese tabs")
	await key(KEY_TAB)
	check(panel.visible and hud.blocks_world_input() and hud.crop_selector.disabled, "Tab opens modal")
	await key(KEY_TAB,true)
	check(panel.visible, "Tab echo does not retoggle")
	var player = main.get_node("Player")
	player.position = manager.plots["soil_01"].position
	await create_timer(0.1).timeout
	var before: Vector2 = player.position
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	await key(KEY_E)
	check(player.position == before and inv.wheat_seed == 10 and manager.plots["soil_01"].state == 0, "storage blocks movement/farming")
	await key(KEY_ESCAPE)
	check(not panel.visible and not hud.blocks_world_input(), "ESC closes storage")
	await key(KEY_TAB)
	await key(KEY_TAB)
	check(not panel.visible, "Tab toggles closed")
	hud.get_node("Layout/Actions/StorageButton").pressed.emit()
	check(panel.visible, "touch button opens")
	panel.get_node("Margin/Content/CloseButton").pressed.emit()
	check(not panel.visible, "touch Close button")
	hud._toggle_shop()
	hud._toggle_storage()
	check(panel.visible and not hud.shop_panel.visible, "storage replaces Shop")
	hud.open_build()
	check(not panel.visible and hud.build_panel.visible, "Build replaces storage")
	hud._toggle_storage()
	check(panel.visible and not hud.build_panel.visible, "storage replaces Build")
	hud.get_node("Layout/Actions/OrdersButton").pressed.emit()
	check(hud.order_panel.visible and not panel.visible, "HUD Order button")
	hud._toggle_storage()
	check(panel.visible and not hud.order_panel.visible, "storage replaces Orders")
	hud._show_reset_confirmation()
	await key(KEY_TAB)
	check(hud.reset_confirmation.visible and not panel.visible, "confirmation outranks Tab")
	await key(KEY_ESCAPE)
	check(not hud.reset_confirmation.visible, "ESC cancels confirmation")
	# Real transactions refresh the same read-only panel even when it is closed.
	manager.plots["soil_01"].try_plant()
	check(produce.text.contains("Lúa mì: 9"), "plant refresh")
	var plot = manager.plots["soil_01"]
	plot.ready_at = Time.get_unix_time_from_system()-1
	plot._on_grow_timer_timeout()
	plot.harvest()
	check(produce.text.ends_with("Cà rốt: 0") and produce.text.contains("Nông sản\nLúa mì: 1"), "harvest refresh")
	check(inv.buy_seed("WHEAT") and produce.text.contains("Hạt giống\nLúa mì: 10"), "buy refresh")
	inv.tools_unlock_notified = true
	inv.player_level = 10
	inv.normalize_exp()
	inv.inventory_changed.emit()
	check(inv.add_item("egg",1) and inv.add_item("milk",1) and inv.add_item("small_fish",1), "products fixture")
	check(goods.text.contains("Trứng: 1") and goods.text.contains("Sữa: 1") and goods.text.contains("Cá nhỏ: 1"), "product/fish refresh")
	check(inv.sell_fish("small_fish") and goods.text.contains("Cá nhỏ: 0"), "fish sale refresh")
	inv.wood = 30
	inv.stone = 15
	inv.coins = 500
	inv.inventory_changed.emit()
	check(materials.text == "Gỗ: 30\nĐá: 15", "material refresh")
	check(inv.upgrade_structure("house") and materials.text == "Gỗ: 0\nĐá: 0", "upgrade refresh")
	hud._toggle_storage()
	check(manager.reset_game() and not panel.visible, "reset closes storage")
	check(produce.text.contains("Hạt giống\nLúa mì: 10") and goods.text.contains("0 / 20") and materials.text == "Gỗ: 0\nĐá: 0", "reset data refresh")
	# The panel stays inside a narrow mobile viewport and has touch-sized tabs.
	root.size = Vector2i(360,640)
	await create_timer(0.1).timeout
	panel._fit_viewport()
	check(panel.position.x >= 0 and panel.position.x+panel.size.x <= panel.get_viewport_rect().size.x+1, "mobile width fit")
	check(panel.tabs.get_tab_bar().custom_minimum_size.y >= 48, "touch-sized tabs")
	print("PASS: storage_ui")
	quit()
