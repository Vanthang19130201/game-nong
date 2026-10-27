extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var editor: Node
var player: Node2D
var orders: Node
const PURCHASE_POINT := Vector2(512,1152)
const MOVE_POINT := Vector2(768,1152)

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value,message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK,"read isolated save")
	return data

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = player.get_canvas_transform()*point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func prepare() -> void:
	check(manager.reset_game(),"reset fixture")
	inv.player_level = 15
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.inventory_changed.emit()

func purchase() -> Node:
	prepare()
	hud.open_build()
	hud.building_buttons["dairy"].pressed.emit()
	check(editor.placing_building == "dairy" and editor.active,"Build button enters existing placement mode")
	var existing = farm.get_node_or_null("Dairy")
	check(inv.coins == 10000 and not inv.owns_dairy and (existing == null or not existing.visible),"preview does not buy or enable gameplay building")
	player.position = PURCHASE_POINT+Vector2(0,60)
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	await click(PURCHASE_POINT)
	check(inv.coins == 5500 and inv.owns_dairy and not editor.active,"left click charges exactly 4500 on valid placement")
	var dairy = farm.get_node("Dairy")
	check(dairy.position == PURCHASE_POINT and manager.buildings["dairy"] == dairy,"single registered building at player-selected location")
	check(disk().get_value("buildings","owns_dairy") and disk().get_value("building_positions","dairy") == PURCHASE_POINT,"ownership and chosen position autosaved together")
	check(not inv.buy_building("dairy") and inv.coins == 5500,"duplicate purchase denied")
	return dairy

func enqueue_all(dairy: Node) -> void:
	inv.milk = 9
	var amounts: Array = [2,3,4]
	var durations: Array = [30,45,60]
	var index: int = 0
	for item in inv.DairyData.RECIPES:
		var before: int = inv.milk
		check(dairy.enqueue(item) and inv.milk == before-amounts[index],"deduct exact recipe inputs once")
		var entry: Dictionary = manager.dairy_queue[index]
		check(entry["ready_at"]-entry["started_at"] == durations[index],"exact production duration")
		if index > 0:
			check(entry["started_at"] >= manager.dairy_queue[index-1]["ready_at"],"sequential timestamp queue")
		index += 1
	check(manager.dairy_queue.size() == 3 and inv.milk == 0 and not dairy.enqueue("cream") and not dairy.collect(),"queue limit and no early collection")
	check(disk().get_value("dairy","dairy_queue").size() == 3,"queue autosaved")

func move_producing(dairy: Node) -> void:
	var queue: Array = manager.dairy_queue.duplicate(true)
	var instance: int = dairy.get_instance_id()
	var remaining: float = dairy.production_timer.time_left
	editor.enter_mode()
	editor.select_building(dairy)
	check(editor.selected == dairy,"owned Dairy selectable in Edit Mode")
	editor.begin_move()
	editor.update_preview(MOVE_POINT)
	check(editor.valid_position and dairy.position == PURCHASE_POINT,"move preview keeps original building untouched")
	check(manager.save_game() and disk().get_value("building_positions","dairy") == PURCHASE_POINT,"save during preview keeps old position")
	await key(KEY_ESCAPE)
	check(editor.active and editor.preview == null and dairy.position == PURCHASE_POINT,"ESC cancels Dairy move")
	editor.select_building(dairy)
	editor.begin_move()
	editor.update_preview(MOVE_POINT)
	check(editor.place_move() and dairy.position == MOVE_POINT,"Dairy moves through shared placement system")
	check(dairy.get_instance_id() == instance and manager.dairy_queue == queue and dairy.production_timer.time_left <= remaining,"move preserves production and exact queue timestamps")
	check(disk().get_value("building_positions","dairy") == MOVE_POINT,"moved position autosaved")
	editor.exit_mode()

func finish_all(dairy: Node) -> void:
	var start: float = Time.get_unix_time_from_system()-200
	for entry in manager.dairy_queue:
		entry["started_at"] = start
		entry["ready_at"] = start+inv.DairyData.RECIPES[entry["item"]]["time"]
		start = entry["ready_at"]
	dairy._finish_production()

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","never use player save")
	root.size = Vector2i(1152,648)
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	editor = hud.edit_farm
	player = farm.get_node("Player")
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"dairy_core":
			prepare()
			check(not inv.owns_dairy and manager.dairy_queue.is_empty(),"new game defaults")
			inv.player_level = 14
			hud._buy_building("dairy")
			check(not editor.active and not inv.owns_dairy and inv.coins == 10000,"level 14 locked")
			for item in inv.DairyData.RECIPES:
				check(not orders.item_available(item),"unowned Dairy recipes excluded from orders")
			inv.player_level = 15
			inv.coins = 4499
			hud._buy_building("dairy")
			check(not editor.active and inv.coins == 4499,"insufficient coins")
			inv.coins = 10000
			check(not inv.buy_building("dairy") and inv.coins == 10000,"Dairy cannot bypass placement")
			hud._buy_building("dairy")
			for point in [farm.get_node("House").position,manager.plots["soil_01"].position,Vector2(512,1664),Vector2(1870,850)]:
				editor.update_preview(point)
				check(not editor.valid_position and not editor.place_move() and inv.coins == 10000,"occupied/locked/outside location does not charge")
			check(editor.preview.is_preview and not editor.preview.is_in_group("farm_interactables") and editor.preview.production_timer.is_stopped(),"preview has no gameplay or production")
			await key(KEY_ESCAPE)
			check(not editor.active and not inv.owns_dairy and inv.coins == 10000,"cancel preview has no cost")
			var dairy = await purchase()
			await create_timer(0.1).timeout
			await key(KEY_E)
			check(hud.dairy_panel.visible and hud.blocks_world_input(),"E opens Dairy and blocks world interaction")
			await key(KEY_ESCAPE)
			check(not hud.dairy_panel.visible and not hud.blocks_world_input(),"ESC closes Dairy")
			await click(dairy.position)
			check(hud.dairy_panel.visible,"click opens Dairy")
			await key(KEY_P)
			check(not hud.dairy_panel.visible and hud.shop_build_panel.visible,"P replaces Dairy with one modal")
			await key(KEY_ESCAPE)
			check(not dairy.state_changed.is_connected(hud.dairy_panel.refresh),"panel signal disconnected after close")
			check(not dairy.enqueue("cream") and manager.dairy_queue.is_empty(),"missing milk never enqueues")
			enqueue_all(dairy)
			check(not orders.item_available("cream"),"Dairy orders also require a renewable milk source")
			inv.owns_feed_mill = true
			inv.owns_cow_shed = true
			inv.cow_count = 1
			for item in inv.DairyData.RECIPES:
				check(orders.item_available(item),"owned unlocked Dairy recipe available to orders")
			await move_producing(dairy)
			finish_all(dairy)
			var ready: Array = manager.dairy_queue.duplicate(true)
			inv.egg = inv.barn_capacity
			inv.inventory_changed.emit()
			check(not dairy.collect() and manager.dairy_queue == ready and inv.cream == 0,"full Barn preserves ready goods")
			inv.egg = 0
			for item in inv.DairyData.RECIPES:
				check(dairy.collect() and inv.get(item) == 1,"collect one produced item")
			check(not dairy.collect() and inv.storage_used("barn") == 3,"no duplicate rewards and correct Barn usage")
			for item in inv.DairyData.RECIPES:
				hud._sell_dairy_item(item)
			check(inv.coins == 5880 and inv.storage_used("barn") == 0 and not inv.sell_dairy_item("cream"),"exact 80/120/180 sale prices and no negative goods")
			check(inv.DairyData.restore_queue([null,{"item":"unknown"},{"item":"cream","started_at":"bad","ready_at":10}]).is_empty(),"malformed queue safe fallback")
			check(manager.reset_game() and not inv.owns_dairy and manager.dairy_queue.is_empty() and dairy.production_timer.is_stopped(),"clean Dairy reset")
			var purchased_again = await purchase()
			check(purchased_again == dairy and dairy.position == PURCHASE_POINT,"runtime reset/repurchase reuses one building at new chosen position")
			check(manager.reset_game(),"repurchase cleanup")
		"dairy_write":
			var dairy = await purchase()
			enqueue_all(dairy)
			var start: float = Time.get_unix_time_from_system()-31
			for entry in manager.dairy_queue:
				entry["started_at"] = start
				entry["ready_at"] = start+inv.DairyData.RECIPES[entry["item"]]["time"]
				start = entry["ready_at"]
			dairy.refresh()
			await move_producing(dairy)
			check(manager.save_game(),"persist offline queue fixture")
		"dairy_read":
			var dairy = farm.get_node("Dairy")
			check(inv.owns_dairy and dairy.position == MOVE_POINT and manager.dairy_queue.size() == 3,"ownership, chosen position and queue restored")
			check(manager.dairy_queue[0]["state"] == "READY" and manager.dairy_queue[1]["state"] == "PRODUCING" and manager.dairy_queue[2]["state"] == "QUEUED","offline queue states restored")
			check(dairy.production_timer.time_left > 10 and dairy.production_timer.time_left < 45,"remaining timer resumes without reset")
			check(dairy.collect() and inv.cream == 1 and not dairy.collect() and manager.dairy_queue.size() == 2,"offline collection exactly once")
		"dairy_again":
			var dairy = farm.get_node("Dairy")
			check(inv.cream == 1 and manager.dairy_queue.size() == 2 and not dairy.collect(),"second reload cannot duplicate reward")
			finish_all(dairy)
			check(dairy.collect() and dairy.collect() and inv.butter == 1 and inv.cheese == 1,"remaining offline products preserved")
			check(manager.reset_game() and inv.cream == 0 and inv.butter == 0 and inv.cheese == 0,"reset clears Dairy goods")
		"dairy_reset_read":
			check(not inv.owns_dairy and manager.dairy_queue.is_empty() and farm.get_node_or_null("Dairy") == null,"reset remains clean after reload")
		"dairy_legacy_write":
			check(manager.reset_game(),"legacy fixture")
			var data := disk()
			data.erase_section_key("buildings","owns_dairy")
			data.erase_section("dairy")
			data.erase_section_key("building_positions","dairy")
			for item in inv.DairyData.RECIPES:
				data.erase_section_key("inventory",item)
			data.set_value("inventory","coins",777)
			check(data.save(manager.SAVE_PATH) == OK,"write old save missing all Dairy fields")
		"dairy_legacy_read":
			check(inv.coins == 777 and not inv.owns_dairy and inv.cream == 0 and inv.butter == 0 and inv.cheese == 0 and manager.dairy_queue.is_empty(),"old save migration keeps existing values and safe defaults")
			check(manager.reset_game(),"legacy cleanup")
	print("PASS: " + stage)
	quit()
