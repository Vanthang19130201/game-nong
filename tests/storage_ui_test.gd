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
	var cells: Dictionary = panel.item_cells
	check(not hud.storage_label.visible and hud.storage_label.text.is_empty(), "no permanent inventory/storage HUD")
	check(hud.inventory_label.text == tr("HUD_COMPACT") % [100,1], "compact Coins/level")
	check(hud.experience_bar.max_value == 100 and hud.experience_bar.value == 0, "EXP bar")
	check(InputMap.has_action("toggle_inventory"), "Tab action exists")
	var tab_bound: bool = false
	for event in InputMap.action_get_events("toggle_inventory"):
		if event is InputEventKey and event.physical_keycode == KEY_TAB:
			tab_bound = true
	check(tab_bound, "physical Tab binding")
	check(cells["wheat_seed"].quantity == 10 and panel.capacity_labels["silo"].text.contains("10 / 30"), "existing inventory grid data")
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
	panel.get_node("Margin/Content/Footer/CloseButton").pressed.emit()
	check(not panel.visible, "touch Close button")
	hud._toggle_shop()
	hud._toggle_storage()
	check(panel.visible and not hud.shop_panel.is_visible_in_tree(), "storage replaces Shop")
	hud.open_build()
	check(not panel.visible and hud.build_panel.is_visible_in_tree(), "Build replaces storage")
	hud._toggle_storage()
	check(panel.visible and not hud.build_panel.is_visible_in_tree(), "storage replaces Build")
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
	check(cells["wheat_seed"].quantity == 9, "plant refresh")
	var plot = manager.plots["soil_01"]
	plot.ready_at = Time.get_unix_time_from_system()-1
	plot._on_grow_timer_timeout()
	plot.harvest()
	check(cells["carrot"].quantity == 0 and cells["wheat"].quantity == 2, "harvest refresh")
	check(not hud.transaction_feedback.visible and hud.transaction_feedback.get_child_count() == 0 and hud.transaction_feedback.text == "+2 Lúa mì\n+10 Kinh nghiệm", "harvest never creates a large notification panel")
	var toast_count: int = hud.transaction_feedback.get_child_count()
	plot.harvest()
	check(hud.transaction_feedback.get_child_count() == toast_count and inv.wheat == 2, "empty plot gives no reward or feedback")
	check(inv.buy_seed("WHEAT") and cells["wheat_seed"].quantity == 10, "buy refresh")
	inv.tools_unlock_notified = true
	inv.player_level = 10
	inv.normalize_exp()
	inv.inventory_changed.emit()
	check(inv.add_item("egg",1) and inv.add_item("milk",1) and inv.add_item("small_fish",1), "products fixture")
	check(cells["egg"].quantity == 1 and cells["milk"].quantity == 1 and cells["small_fish"].quantity == 1, "product/fish refresh")
	check(inv.sell_fish("small_fish") and cells["small_fish"].quantity == 0, "fish sale refresh")
	inv.wood = 30
	inv.stone = 15
	inv.coins = 500
	inv.inventory_changed.emit()
	check(cells["wood"].quantity == 30 and cells["stone"].quantity == 15, "material refresh")
	check(inv.upgrade_structure("house") and cells["wood"].quantity == 0 and cells["stone"].quantity == 0, "upgrade refresh")
	hud._toggle_storage()
	check(manager.reset_game() and not panel.visible, "reset closes storage")
	check(cells["wheat_seed"].quantity == 10 and panel.capacity_labels["barn"].text.contains("0 / 20") and cells["wood"].quantity == 0 and cells["stone"].quantity == 0, "reset data refresh")
	# P uses the same modal as the HUD button, for both tabs.
	check(InputMap.action_get_events("toggle_shop_build")[0].physical_keycode == KEY_P, "physical P binding")
	hud._toggle_storage()
	await key(KEY_P)
	check(hud.shop_build_panel.visible and not panel.visible and hud.blocks_world_input(), "P replaces storage")
	check(hud.shop_build_tabs.get_tab_count() == 3, "shop/build/decoration tabs")
	hud.shop_build_tabs.current_tab = 1
	await process_frame
	check(hud.build_panel.is_visible_in_tree() and not hud.shop_panel.is_visible_in_tree(), "build tab")
	await key(KEY_P, true)
	check(hud.shop_build_panel.visible, "P echo ignored")
	await key(KEY_P)
	check(not hud.shop_build_panel.visible, "P closes build tab")
	await key(KEY_P)
	check(hud.shop_panel.is_visible_in_tree(), "P opens shop tab")
	check(hud.crop_selector.disabled, "shop blocks crop dropdown")
	hud._buy_seed("WHEAT")
	check(inv.wheat_seed == 11 and inv.coins == 95, "UI buy unchanged")
	check(hud.transaction_feedback.text.contains("+1 " + tr("ITEM_WHEAT_SEED")) and hud.transaction_feedback.text.contains("-5 Xu"), "successful buy feedback")
	inv.coins = 0
	hud._buy_seed("WHEAT")
	check(inv.wheat_seed == 11 and hud.transaction_feedback.text == "Không đủ xu", "failed buy no fake reward")
	hud._sell_crop("WHEAT")
	check(hud.transaction_feedback.text == "Không có vật phẩm để bán", "failed sell feedback")
	inv.wheat = 1
	hud._sell_crop("WHEAT")
	check(inv.wheat == 0 and inv.coins == 10 and hud.transaction_feedback.text.contains("-1 Lúa mì") and hud.transaction_feedback.text.contains("+10 Xu"), "sell feedback")
	await create_timer(1.5).timeout
	check(not hud.transaction_feedback.visible, "feedback disappears")
	await key(KEY_ESCAPE)
	check(not hud.shop_build_panel.visible and not hud.blocks_world_input(), "ESC closes combined modal")
	check(not hud.crop_selector.disabled, "closing modal restores crop dropdown")
	hud.get_node("ResetControls/SettingsButton").pressed.emit()
	check(hud.settings_panel.visible and hud.crop_selector.disabled, "settings blocks crop dropdown")
	hud.reset_button.pressed.emit()
	check(hud.reset_confirmation.visible and hud.crop_selector.disabled, "confirmation blocks crop dropdown")
	await key(KEY_ESCAPE)
	check(not hud.crop_selector.disabled and not hud.reset_confirmation.visible, "cancel restores input")
	hud.open_orders()
	check(hud.order_panel.visible and hud.crop_selector.disabled, "orders blocks crop dropdown")
	await key(KEY_P)
	check(not hud.order_panel.visible and hud.shop_build_panel.visible, "P replaces orders")
	await key(KEY_TAB)
	check(not hud.shop_build_panel.visible and panel.visible, "Tab replaces shop")
	await key(KEY_ESCAPE)
	# Legacy notifications never create large panels. Real inventory changes
	# use the shared small floating feedback instead.
	for i in range(8):
		hud.show_transaction_feedback("-1 Lúa mì\n+10 Xu")
	await process_frame
	await process_frame
	var feedback = hud.transaction_feedback
	check(feedback.get_child_count() == 0 and not feedback.visible, "legacy feedback cannot create a toast burst")
	await create_timer(1.55).timeout
	check(not feedback.visible and feedback.get_child_count() == 0, "burst cleans up without stale callbacks")
	# The panel stays inside a narrow mobile viewport and has touch-sized tabs.
	root.size = Vector2i(360,640)
	await create_timer(0.1).timeout
	panel._fit_viewport()
	check(panel.position.x >= 0 and panel.position.x+panel.size.x <= panel.get_viewport_rect().size.x+1, "mobile width fit")
	check(panel.tabs.custom_minimum_size.y >= 48, "touch-sized tabs")
	# Order cards may scroll, while the panel and Close button stay on screen.
	for viewport_size in [Vector2i(1152,648), Vector2i(800,450), Vector2i(360,640)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await create_timer(0.1).timeout
		hud.open_orders()
		await process_frame
		await process_frame
		hud._fit_order_panel()
		var screen_rect := Rect2(Vector2.ZERO, hud.order_panel.get_viewport_rect().size)
		check(screen_rect.encloses(hud.order_panel.get_rect()), "Order panel fits viewport " + str(viewport_size))
		check(screen_rect.encloses(hud.get_node("OrderPanel/Margin/Content/Footer/CloseButton").get_global_rect()), "Order Close button stays on screen")
		if viewport_size.x == 360:
			check(hud.order_cards.get_parent().get_h_scroll_bar().visible, "narrow Order panel scrolls cards")
		await key(KEY_ESCAPE)
		check(not hud.order_panel.visible, "ESC closes resized Order panel")
	print("PASS: storage_ui")
	quit()
