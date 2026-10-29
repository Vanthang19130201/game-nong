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
	check(data.load(manager.SAVE_PATH) == OK,"isolated save readable")
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
	check(manager.reset_game(),"reset isolated fixture")
	inv.player_level = 17
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.inventory_changed.emit()

func purchase() -> Node:
	prepare()
	hud.open_build()
	hud.building_buttons["spinning_machine"].pressed.emit()
	check(editor.active and editor.placing_building == "spinning_machine" and inv.coins == 10000 and not inv.owns_spinning_machine,"Build button starts uncharged placement")
	player.position = PURCHASE_POINT+Vector2(0,60)
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	await click(PURCHASE_POINT)
	check(inv.owns_spinning_machine and inv.coins == 5000 and not editor.active,"valid left click purchases for exactly 5000")
	var machine = farm.get_node("SpinningMachine")
	check(machine.position == PURCHASE_POINT and manager.buildings["spinning_machine"] == machine,"one machine at selected position")
	check(disk().get_value("buildings","owns_spinning_machine") and disk().get_value("building_positions","spinning_machine") == PURCHASE_POINT,"ownership and position autosaved")
	check(not inv.buy_building("spinning_machine") and inv.coins == 5000,"no duplicate purchase")
	return machine

func enqueue_all(machine: Node) -> void:
	inv.cotton = 9
	for index in range(3):
		check(machine.enqueue() and inv.cotton == 9-3*(index+1),"exactly three Cotton consumed for each queued item")
		var entry: Dictionary = manager.spinning_machine_queue[index]
		check(entry["item"] == "cotton_thread" and entry["ready_at"]-entry["started_at"] == 45,"correct recipe and 45 second timestamps")
		if index > 0:
			check(entry["started_at"] >= manager.spinning_machine_queue[index-1]["ready_at"],"queue production is sequential")
	check(not machine.enqueue() and manager.spinning_machine_queue.size() == 3 and inv.cotton == 0 and not machine.collect(),"queue limit and no early reward")
	check(disk().get_value("spinning_machine","spinning_machine_queue").size() == 3,"queue autosave")

func move_producing(machine: Node) -> void:
	var queue: Array = manager.spinning_machine_queue.duplicate(true)
	var instance: int = machine.get_instance_id()
	var remaining: float = machine.production_timer.time_left
	editor.enter_mode()
	editor.select_building(machine)
	check(editor.selected == machine,"machine selectable in Edit Mode")
	editor.begin_move()
	editor.update_preview(MOVE_POINT)
	check(editor.valid_position and machine.position == PURCHASE_POINT,"valid move preview leaves actual node untouched")
	await key(KEY_ESCAPE)
	check(editor.active and editor.preview == null and machine.position == PURCHASE_POINT,"ESC cancels move")
	editor.select_building(machine)
	editor.begin_move()
	editor.update_preview(MOVE_POINT)
	check(editor.place_move() and machine.position == MOVE_POINT,"shared placement commits move")
	check(machine.get_instance_id() == instance and manager.spinning_machine_queue == queue and machine.production_timer.time_left <= remaining,"move preserves node, queue and production timer")
	check(disk().get_value("building_positions","spinning_machine") == MOVE_POINT,"new position autosaved")
	editor.exit_mode()

func finish_all(machine: Node) -> void:
	var start: float = Time.get_unix_time_from_system()-200
	for entry in manager.spinning_machine_queue:
		entry["started_at"] = start
		entry["ready_at"] = start+45
		start += 45
	machine._finish_production()

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
		"spinning_core":
			prepare()
			inv.player_level = 16
			hud._buy_building("spinning_machine")
			check(not editor.active and not inv.owns_spinning_machine and inv.coins == 10000,"level 16 locked")
			inv.player_level = 17
			check(not orders.item_available("cotton_thread"),"Cotton Thread orders require ownership")
			inv.coins = 4999
			hud._buy_building("spinning_machine")
			check(not editor.active and inv.coins == 4999,"insufficient coins do not start purchase")
			inv.coins = 10000
			check(not inv.buy_building("spinning_machine") and inv.coins == 10000,"placement cannot be bypassed")
			hud._buy_building("spinning_machine")
			for point in [farm.get_node("House").position,manager.plots["soil_01"].position,Vector2(512,1664),Vector2(1870,850)]:
				editor.update_preview(point)
				check(not editor.valid_position and not editor.place_move() and inv.coins == 10000,"invalid/locked/occupied placement costs nothing")
			check(editor.preview.is_preview and not editor.preview.is_in_group("farm_interactables"),"preview has no gameplay interaction")
			await key(KEY_ESCAPE)
			check(not editor.active and not inv.owns_spinning_machine and inv.coins == 10000,"ESC cancels purchase without cost")
			var machine = await purchase()
			await create_timer(0.1).timeout
			await key(KEY_E)
			check(hud.spinning_machine_panel.visible and hud.blocks_world_input(),"E opens panel and blocks world")
			await key(KEY_ESCAPE)
			check(not hud.spinning_machine_panel.visible and not hud.blocks_world_input(),"ESC closes panel")
			await click(machine.position)
			check(hud.spinning_machine_panel.visible,"click opens machine")
			await key(KEY_TAB)
			check(hud.storage_panel.visible and not hud.spinning_machine_panel.visible,"Tab replaces machine with one modal")
			await key(KEY_ESCAPE)
			check(not machine.state_changed.is_connected(hud.spinning_machine_panel.refresh),"panel disconnects signal on close")
			inv.cotton = 2
			check(not machine.enqueue() and inv.cotton == 2 and manager.spinning_machine_queue.is_empty(),"insufficient Cotton is never consumed")
			enqueue_all(machine)
			check(machine.cancel_job_at(2) and inv.cotton == 3 and manager.spinning_machine_queue.size() == 2,"Spinning cancel refunds one queued recipe")
			check(machine.enqueue() and inv.cotton == 0 and manager.spinning_machine_queue.size() == 3,"Spinning refills the cancelled queue slot")
			await move_producing(machine)
			finish_all(machine)
			var ready: Array = manager.spinning_machine_queue.duplicate(true)
			inv.egg = inv.barn_capacity
			inv.inventory_changed.emit()
			check(not machine.collect() and inv.cotton_thread == 0 and manager.spinning_machine_queue == ready,"full Barn retains ready output")
			inv.egg = 0
			for index in range(3):
				check(machine.collect() and inv.cotton_thread == index+1,"each queue item collected exactly once")
			check(not machine.collect() and inv.storage_used("barn") == 3,"empty queue grants no duplicate and Barn usage correct")
			check(orders.item_available("cotton_thread") and orders.item_info()["cotton_thread"]["price"] == 270,"owned recipe order uses chosen 270 base value")
			orders.restore_orders([{"order_id":"order_900000","requirements":{"cotton_thread":1},"coin_reward":338,"exp_reward":0}])
			check(orders.complete_order("order_900000") and not orders.complete_order("order_900000") and inv.cotton_thread == 2 and inv.coins == 5338,"Cotton Thread order consumes and rewards once")
			check(not inv.owns_dairy and manager.dairy_queue.is_empty() and inv.milk == 0,"Dairy untouched by spinning production")
			check(inv.SpinningData.restore_queue([null,{"item":"unknown"},{"item":"cotton_thread","started_at":"bad","ready_at":5}]).is_empty(),"malformed queue fallback")
			check(manager.reset_game() and not inv.owns_spinning_machine and inv.cotton_thread == 0 and manager.spinning_machine_queue.is_empty() and machine.production_timer.is_stopped(),"reset clears spinning data")
			var same_machine = await purchase()
			check(same_machine == machine and machine.position == PURCHASE_POINT,"repurchase after runtime reset reuses one node at chosen location")
			check(manager.reset_game(),"cleanup")
		"spinning_write":
			var machine = await purchase()
			enqueue_all(machine)
			var start: float = Time.get_unix_time_from_system()-46
			for entry in manager.spinning_machine_queue:
				entry["started_at"] = start
				entry["ready_at"] = start+45
				start += 45
			machine.refresh()
			await move_producing(machine)
			check(manager.save_game(),"persist offline queue")
		"spinning_read":
			var machine = farm.get_node("SpinningMachine")
			check(inv.owns_spinning_machine and machine.position == MOVE_POINT and manager.spinning_machine_queue.size() == 3,"restore ownership, chosen position and queue")
			check(manager.spinning_machine_queue[0]["state"] == "READY" and manager.spinning_machine_queue[1]["state"] == "PRODUCING" and manager.spinning_machine_queue[2]["state"] == "QUEUED","offline queue states correct")
			check(machine.production_timer.time_left > 10 and machine.production_timer.time_left < 45,"resume remaining production time")
			check(machine.collect() and inv.cotton_thread == 1 and not machine.collect(),"offline collect only once")
		"spinning_again":
			var machine = farm.get_node("SpinningMachine")
			check(inv.cotton_thread == 1 and manager.spinning_machine_queue.size() == 2 and not machine.collect(),"reload preserves output without duplicate")
			finish_all(machine)
			check(machine.collect() and machine.collect() and inv.cotton_thread == 3,"remaining products preserved")
			check(manager.reset_game(),"reset fixture")
		"spinning_reset_read":
			check(not inv.owns_spinning_machine and inv.cotton_thread == 0 and manager.spinning_machine_queue.is_empty() and farm.get_node_or_null("SpinningMachine") == null,"reset remains clean after reload")
		"spinning_legacy_write":
			check(manager.reset_game(),"legacy fixture")
			var data := disk()
			data.erase_section_key("buildings","owns_spinning_machine")
			data.erase_section("spinning_machine")
			data.erase_section_key("building_positions","spinning_machine")
			data.erase_section_key("inventory","cotton_thread")
			data.set_value("inventory","coins",777)
			data.set_value("inventory","cotton",6)
			check(data.save(manager.SAVE_PATH) == OK,"old save fixture omits new fields")
		"spinning_legacy_read":
			check(inv.coins == 777 and inv.cotton == 6 and inv.cotton_thread == 0 and not inv.owns_spinning_machine and manager.spinning_machine_queue.is_empty(),"old save preserves balances and defaults new fields")
			check(manager.reset_game(),"legacy cleanup")
	print("PASS: " + stage)
	quit()
