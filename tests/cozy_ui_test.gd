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
	check(hud.storage_panel.item_cells.size() == inv.SILO_ITEMS.size()+inv.BARN_ITEMS.size()+2,"grid covers all existing inventory categories")
	hud.storage_panel.item_cells["cotton_seed"].pressed.emit()
	check(inv.selected_crop == "COTTON" and "cotton_seed" in hud.hotbar.items,"all crops remain selectable from inventory")
	var selected: int = hud.hotbar.selected_slot
	await key(KEY_3)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(hud.hotbar.selected_slot == selected and inv.selected_crop == "COTTON","inventory blocks hidden world hotkeys and wheel")
	await key(KEY_P)
	check(hud.shop_build_panel.visible and not hud.storage_panel.visible,"P replaces inventory with Shop/Build")
	var seeds_before: int = inv.wheat_seed
	var coins_before: int = inv.coins
	hud.buy_buttons["WHEAT"].pressed.emit()
	check(inv.wheat_seed == seeds_before+1 and inv.coins == coins_before-5,"same buy button and unchanged economy")
	check(hud.storage_panel.item_cells["wheat_seed"].quantity == inv.wheat_seed,"grid refreshes transactions immediately")
	check(hud.shop_cards["wheat_seed"].stats.text.contains(str(inv.wheat_seed)),"shop card quantity refresh")
	await key(KEY_ESCAPE)
	check(not hud.shop_build_panel.visible,"ESC closes popup")
	hud.get_node("ResetControls/SettingsButton").pressed.emit()
	check(hud.settings_panel.visible and hud.settings_panel.get_node("Margin/Content").get_child_count() == 6,"compact menu keeps Shop, Inventory, Orders and Reset accessible")
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
		player.position = Vector2(1000,900)
		camera.focus_player()
		camera.reset_smoothing()
		await capture("cozy_hud.png")
		hud._toggle_storage()
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
	check(manager.reset_game(),"cleanup")
	check(inv.selected_crop == "WHEAT" and not inv.has_fishing_rod,"reset still restores existing gameplay state")
	print("PASS: cozy_ui")
	quit()
