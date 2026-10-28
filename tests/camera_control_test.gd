extends SceneTree

var farm: Node
var hud: Node
var player: Node2D
var camera: Camera2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func button(index: int, point: Vector2, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.factor = 1.0
	event.ctrl_pressed = index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE if camera.dragging else 0
	root.push_input(event, true)
	await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	root.push_input(event, true)
	await process_frame

func check_view() -> void:
	camera.force_update_scroll()
	var half_view: Vector2 = root.get_visible_rect().size / camera.zoom / 2.0
	var center: Vector2 = camera.get_screen_center_position()
	check(center.x-half_view.x >= camera.limit_left-0.1 and center.y-half_view.y >= camera.limit_top-0.1 and center.x+half_view.x <= camera.limit_right+0.1 and center.y+half_view.y <= camera.limit_bottom+0.1, "visible camera footprint stays inside map")

func run_checks() -> void:
	await process_frame
	var manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	root.size = Vector2i(1152,648)
	check(manager.reset_game(), "reset isolated fixture")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	camera = player.get_node("Camera2D")
	player.position = Vector2(1100,1100)
	camera.reset_smoothing()
	await create_timer(0.1).timeout
	check(InputMap.action_has_event("focus_camera", _focus_event()), "physical F binding")
	var world_mouse := Vector2(900,500)
	await motion(world_mouse)
	await button(MOUSE_BUTTON_WHEEL_UP, world_mouse)
	check(is_equal_approx(camera.target_zoom,1.1) and camera.zoom.x > 1.0 and camera.zoom.x < 1.1, "wheel up starts smooth zoom")
	await create_timer(0.5).timeout
	check(absf(camera.zoom.x-1.1) < 0.005, "zoom converges")
	await button(MOUSE_BUTTON_WHEEL_DOWN, world_mouse)
	check(is_equal_approx(camera.target_zoom,1.0), "wheel down zooms out")
	camera.request_zoom(-100)
	await create_timer(0.7).timeout
	check(is_equal_approx(camera.target_zoom,camera._minimum_zoom()) and camera.zoom.x >= camera._minimum_zoom(), "minimum zoom fits the expanded overview")
	camera.target_zoom = 0.65
	camera.zoom = Vector2.ONE * 0.65
	await process_frame
	var player_before: Vector2 = player.position
	await button(MOUSE_BUTTON_MIDDLE, world_mouse)
	var center_before: Vector2 = camera.get_screen_center_position()
	await motion(world_mouse-Vector2(80,40), Vector2(-80,-40))
	check(camera.dragging and not camera.following_player and camera.get_screen_center_position().x > center_before.x+100, "middle drag pans in zoom-adjusted world units")
	check(player.position == player_before, "pan never moves player")
	await button(MOUSE_BUTTON_MIDDLE, world_mouse, false)
	check(not camera.dragging, "release stops pan")
	center_before = camera.get_screen_center_position()
	player.position += Vector2(120,0)
	await create_timer(0.1).timeout
	check(camera.get_screen_center_position().is_equal_approx(center_before), "detached camera holds still as player moves")
	await key(KEY_F)
	check(camera.following_player and not camera.dragging and camera.position == Vector2.ZERO, "F restores follow")
	await create_timer(1.0).timeout
	check(camera.get_screen_center_position().distance_to(player.position) < 5, "focus returns view to player")
	for zoom_value in [0.65,1.0,1.5]:
		camera.target_zoom = zoom_value
		camera.zoom = Vector2.ONE*zoom_value
		camera.begin_pan()
		for delta in [Vector2(100000,100000),Vector2(-100000,-100000),Vector2(100000,0),Vector2(0,100000)]:
			camera.pan_by(delta)
			check_view()
		camera.end_pan()
	camera.begin_pan()
	camera.pan_by(Vector2(0,-100000))
	check_view()
	check(camera.get_screen_center_position().y > 2400.0, "camera reaches expanded south")
	camera.pan_by(Vector2(100000,0))
	check_view()
	check(camera.get_screen_center_position().x < 0.0, "camera reaches western expansion")
	camera.pan_by(Vector2(0,100000))
	check_view()
	# The current world starts at y=0, so the center itself must remain at
	# least half a viewport inside the map. check_view() above verifies the
	# actual northern edge; this checks the corresponding clamped center.
	var north_center_limit: float = root.get_visible_rect().size.y / camera.zoom.y / 2.0
	check(camera.get_screen_center_position().y <= north_center_limit + 0.1, "camera reaches northern map edge")
	camera.end_pan()
	camera.request_zoom(100)
	check(is_equal_approx(camera.target_zoom,1.5), "maximum zoom 1.5")
	# HUD buttons block camera even while no modal is open.
	var ui_point: Vector2 = hud.get_node("ResetControls/SettingsButton").get_global_rect().get_center()
	await motion(ui_point)
	var zoom_before: float = camera.target_zoom
	await button(MOUSE_BUTTON_WHEEL_DOWN, ui_point)
	await button(MOUSE_BUTTON_MIDDLE, ui_point)
	check(camera.target_zoom == zoom_before and not camera.dragging, "HUD consumes wheel and middle press")
	await button(MOUSE_BUTTON_MIDDLE, ui_point, false)
	# Main popups block camera everywhere, including outside their rectangles.
	for open_panel in [hud._toggle_shop,hud._toggle_storage,hud.open_orders,hud._toggle_settings]:
		hud._close_game_panels()
		open_panel.call()
		await motion(world_mouse)
		await button(MOUSE_BUTTON_WHEEL_DOWN,world_mouse)
		await button(MOUSE_BUTTON_MIDDLE,world_mouse)
		check(camera.target_zoom == zoom_before and not camera.dragging, "modal blocks camera world input")
		await button(MOUSE_BUTTON_MIDDLE,world_mouse,false)
	hud._close_game_panels()
	await motion(world_mouse)
	await button(MOUSE_BUTTON_MIDDLE,world_mouse)
	await motion(ui_point,Vector2(-80,-40))
	check(not camera.dragging, "drag stops over UI")
	await button(MOUSE_BUTTON_MIDDLE,ui_point,false)
	await motion(world_mouse)
	await key(KEY_F)
	# Edit/placement state survives camera controls and can still complete a move.
	hud.edit_farm.enter_mode()
	hud.edit_farm.select_building(farm.get_node("House"))
	hud.edit_farm.begin_move()
	await button(MOUSE_BUTTON_WHEEL_DOWN,world_mouse)
	await button(MOUSE_BUTTON_MIDDLE,world_mouse)
	await motion(world_mouse-Vector2(40,0),Vector2(-40,0))
	await button(MOUSE_BUTTON_MIDDLE,world_mouse,false)
	check(hud.edit_farm.active and is_instance_valid(hud.edit_farm.preview) and not camera.following_player, "camera works while moving building")
	await key(KEY_F)
	check(camera.following_player and is_instance_valid(hud.edit_farm.preview), "F keeps placement active")
	await create_timer(0.7).timeout
	var destination := Vector2(900,1100)
	hud.edit_farm.update_preview(destination)
	check(hud.edit_farm.valid_position, "valid test destination")
	check(hud.edit_farm.place_move(), "placement completes after camera controls")
	check(farm.get_node("House").position == destination.snapped(Vector2(64,64)) and hud.edit_farm.preview == null, "camera leaves building move state usable")
	hud.edit_farm.exit_mode()
	hud.edit_farm.begin_decoration("stone_path")
	await motion(world_mouse)
	await button(MOUSE_BUTTON_WHEEL_DOWN,world_mouse)
	await button(MOUSE_BUTTON_MIDDLE,world_mouse)
	check(camera.dragging and hud.edit_farm.placing_decoration == "stone_path", "camera works during decoration placement")
	await button(MOUSE_BUTTON_MIDDLE,world_mouse,false)
	await key(KEY_ESCAPE)
	check(not hud.edit_farm.active and manager.placed_decorations.is_empty(), "ESC cancels preview without placing decoration")
	# Resize at a map edge: the zoom floor adapts to large windows.
	root.size = Vector2i(1920,1080)
	await process_frame
	camera.request_zoom(-100)
	await create_timer(0.7).timeout
	camera.begin_pan()
	camera.pan_by(Vector2(100000,100000))
	check_view()
	camera.pan_by(Vector2(-100000,-100000))
	check_view()
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not camera.dragging, "focus loss cannot leave pan stuck")
	check(manager.reset_game(), "cleanup")
	print("PASS: camera_core")
	quit()

func _focus_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	return event
