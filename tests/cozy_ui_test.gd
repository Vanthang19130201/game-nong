extends SceneTree

var farm: Node
var hud: Node
var inv: Node
var manager: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: "+message)
		quit(1)
		assert(value,message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	await create_timer(0.03).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event,true)
	await create_timer(0.03).timeout

func wheel(direction: int, ctrl: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(650,350)
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.button_index = direction
	event.position = motion.position
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event,true)
	await create_timer(0.03).timeout

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func controls_unscaled(node: Node) -> void:
	if node is Control:
		check(node.scale == Vector2.ONE,"UI never scales text: "+str(node.get_path()))
	for child in node.get_children():
		controls_unscaled(child)

func capture(file_name: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(not image.is_empty(),"rendered UI screenshot")
	check(image.save_png("res://"+file_name) == OK,"save review screenshot")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	check(manager.reset_game(),"reset test fixture")
	root.size = Vector2i(1152,648)
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 1234
	inv.corn_seed = 4
	inv.carrot_seed = 3
	inv.normalize_exp()
	inv.inventory_changed.emit()
	await create_timer(0.15).timeout
	check(hud.hotbar.slots.size() == 8 and not hud.get_node("Layout/Actions").visible,"minimal HUD and eight slots")
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.hotbar.get_rect()),"hotbar within viewport")
	for i in range(8):
		check(InputMap.action_get_events("hotbar_slot_%d" % (i+1))[0].physical_keycode == KEY_1+i,"numeric shortcut binding")
	await key(KEY_2)
	check(hud.hotbar.selected_slot == 1 and inv.selected_crop == "CORN","2 selects Corn using existing crop selection")
	var camera = farm.get_node("Player/Camera2D")
	var zoom_before: float = camera.target_zoom
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(hud.hotbar.selected_slot == 2 and inv.selected_crop == "CARROT" and camera.target_zoom == zoom_before,"wheel selects slot without zoom")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(hud.hotbar.selected_slot == 1,"wheel reverses selection")
	await wheel(MOUSE_BUTTON_WHEEL_UP,true)
	check(camera.target_zoom > zoom_before and hud.hotbar.selected_slot == 1,"Ctrl+wheel retains camera zoom")
	for i in [6,7,8]:
		await key(KEY_1+i-1)
		check(hud.hotbar.selected_slot == i-1 and inv.selected_crop == "CORN","tool/rod shortcuts never consume inventory or change crop")
	await key(KEY_1)
	check(hud.hotbar.slots[0].theme_type_variation == &"SelectedSlot" and hud.hotbar.slots[1].theme_type_variation == &"ItemSlot","clear unique selected highlight")
	check(hud.hotbar.slots[0].tooltip_text.contains(root.get_node("Localization").display_name("wheat_seed")) and hud.hotbar.slots[0].tooltip_text.contains("10"),"Vietnamese name and quantity tooltip")
	await key(KEY_TAB)
	check(hud.storage_panel.visible and hud.blocks_world_input(),"Tab opens inventory modal")
	check(not hud.hotbar.visible,"opening storage hides equipment bar")
	for index in [1,2,0]:
		await click(hud.storage_panel.tabs.get_global_position()+hud.storage_panel.tabs.get_tab_rect(index).get_center())
		var hovered: Control = root.gui_get_hovered_control()
		check(hud.storage_panel.tabs.current_tab == index and hud.storage_panel.pages.get_child(index).visible,"mouse click switches storage tab %d; hovered: %s" % [index,str(hovered.get_path()) if hovered != null else "none"])
	await click(hud.storage_panel.get_node("Margin/Content/Footer/CloseButton").get_global_rect().get_center())
	check(not hud.storage_panel.visible and hud.hotbar.visible,"real mouse click closes storage and restores hotbar")
	await key(KEY_TAB)
	check(hud.storage_panel.item_cells.size() == inv.SILO_ITEMS.size()+inv.BARN_ITEMS.size()+2,"grid covers all existing inventory categories")
	await click(hud.storage_panel.item_cells["cotton_seed"].get_global_rect().get_center())
	check(inv.selected_crop == "COTTON" and "cotton_seed" in hud.hotbar.items,"all crops remain selectable from inventory")
	var selected: int = hud.hotbar.selected_slot
	await key(KEY_3)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(hud.hotbar.selected_slot == selected and inv.selected_crop == "COTTON","inventory blocks hidden world hotkeys and wheel")
	await key(KEY_P)
	check(hud.shop_build_panel.visible and not hud.storage_panel.visible,"P replaces inventory with Shop/Build")
	check(not hud.hotbar.visible,"Shop keeps equipment bar hidden")
	var seeds_before: int = inv.wheat_seed
	var coins_before: int = inv.coins
	await click(hud.buy_buttons["WHEAT"].get_global_rect().get_center())
	check(inv.wheat_seed == seeds_before+1 and inv.coins == coins_before-5,"same buy button and unchanged economy")
	check(hud.storage_panel.item_cells["wheat_seed"].quantity == inv.wheat_seed,"grid refreshes transactions immediately")
	check(hud.shop_cards["wheat_seed"].stats.text.contains(str(inv.wheat_seed)),"shop card quantity refresh")
	await click(hud.get_node("ShopBuildPanel/Margin/Content/Footer/CloseButton").get_global_rect().get_center())
	check(not hud.shop_build_panel.visible,"mouse closes Shop above the hidden hotbar")
	await key(KEY_P)
	await key(KEY_ESCAPE)
	check(not hud.shop_build_panel.visible,"ESC closes popup")
	await click(hud.get_node("ResetControls/SettingsButton").get_global_rect().get_center())
	check(hud.settings_panel.visible and hud.settings_panel.get_node("Margin/Content/ContentScroll/Body").get_child_count() == 4,"compact menu keeps Shop, Inventory, Orders and Reset accessible")
	await key(KEY_ESCAPE)
	var player = farm.get_node("Player")
	var spot = farm.get_node("FishingSpot")
	player.position = spot.position
	await create_timer(0.15).timeout
	await key(KEY_E)
	check(spot.state == spot.State.WAITING_FOR_BITE,"E still starts fishing")
	selected = hud.hotbar.selected_slot
	await key(KEY_2)
	check(hud.hotbar.selected_slot == selected,"hotbar cannot disrupt fishing session")
	await key(KEY_SPACE)
	check(spot.state == spot.State.FAILED,"SPACE still reels and fails early")
	hud.fishing_ui.close_session()
	controls_unscaled(hud)
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(1.55).timeout
		player.position = Vector2(1000,900)
		camera.focus_player()
		camera.reset_smoothing()
		await capture("cozy_hud.png")
		hud._toggle_storage()
		hud.storage_panel.content_scroll.scroll_vertical = 0
		await capture("cozy_inventory.png")
		hud._toggle_shop()
		await capture("cozy_shop.png")
		hud.open_build()
		await capture("cozy_build.png")
		hud._close_game_panels()
	root.size = Vector2i(360,640)
	await create_timer(0.15).timeout
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.hotbar.get_rect()),"eight slots fit narrow viewport without scaling")
	hud._toggle_storage()
	await create_timer(0.15).timeout
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.storage_panel.get_rect()),"inventory fits narrow viewport")
	for view in [Vector2i(1152,648),Vector2i(800,450),Vector2i(360,640)]:
		hud.close_all_panels()
		root.size = view
		await create_timer(0.1).timeout
		hud._toggle_storage()
		await create_timer(0.1).timeout
		var panel = hud.storage_panel
		var footer: Control = panel.get_node("Margin/Content/Footer")
		var close: Control = footer.get_node("CloseButton")
		check(is_equal_approx(footer.size.y,80),"fixed 80 px footer "+str(view))
		check(panel.content_scroll.get_global_rect().end.y+8 <= footer.get_global_rect().position.y,"content cannot extend into footer")
		check(footer.get_global_rect().encloses(close.get_global_rect()),"Close centered inside footer")
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(panel.get_rect()),"storage layout stays on screen "+str(view))
		for index in range(3):
			panel.tabs.current_tab = index
			await process_frame
			check(panel.pages.get_child(index).visible,"tab switches visible item page")
			panel.content_scroll.scroll_vertical = 10000
			await process_frame
			check(not footer.get_global_rect().intersects(panel.content_scroll.get_global_rect()),"scrolling never overlaps footer")
		await click(close.get_global_rect().get_center())
		check(not panel.visible and hud.hotbar.visible,"Close restores hotbar")
		hud._toggle_storage()
		await key(KEY_ESCAPE)
		check(not panel.visible and hud.hotbar.visible,"ESC restores hotbar")
		hud._toggle_storage()
		await key(KEY_TAB)
		check(not panel.visible and hud.hotbar.visible,"Tab close restores hotbar")
	for view in [Vector2i(1152,648),Vector2i(800,450),Vector2i(360,640)]:
		hud.close_all_panels()
		root.size = view
		await create_timer(0.1).timeout
		hud._toggle_shop()
		await create_timer(0.1).timeout
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.shop_build_panel.get_rect()),"Shop fits viewport "+str(view))
		hud.open_build()
		await create_timer(0.1).timeout
		check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.shop_build_panel.get_rect()),"Build fits viewport "+str(view))
	check(manager.reset_game(),"cleanup")
	check(inv.selected_crop == "WHEAT" and not inv.has_fishing_rod,"reset still restores existing gameplay state")
	check(hud.hotbar.selected_slot == 0,"reset restores seed selection highlight")
	print("PASS: cozy_ui")
	quit()
