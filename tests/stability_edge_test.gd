extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "isolated save readable")
	return data

func prepare() -> void:
	check(manager.reset_game(), "reset isolated fixture")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.wood = 10
	inv.stone = 10
	inv.inventory_changed.emit()

func place_decoration(type: String, point: Vector2) -> Node2D:
	var preview = load("res://decoration.tscn").instantiate()
	preview.decoration_id = type
	preview.is_preview = true
	farm.add_child(preview)
	check(farm.decoration_manager.place(preview,point,0), "decoration fixture")
	preview.free()
	return farm.decoration_manager.instances.values().back()

func push_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event,true)

func push_click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event,true)

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "never use the player's real save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	var orders = root.get_node("OrderManager")
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"edge_input":
			prepare()
			var gate = place_decoration("wood_gate",Vector2(512,1088))
			player.position = gate.position+Vector2(0,32)
			player.get_node("Camera2D").reset_smoothing()
			await create_timer(0.1).timeout
			push_key(KEY_E,true)
			push_click(player.get_canvas_transform()*gate.position,true)
			check(gate.is_open, "E and click in one frame open gate only once")
			push_key(KEY_E,false)
			push_click(player.get_canvas_transform()*gate.position,false)
			await process_frame
			push_click(player.get_canvas_transform()*gate.position,true)
			push_click(player.get_canvas_transform()*gate.position,false)
			check(not gate.is_open, "next frame still allows normal interaction")
			var plot = manager.plots["soil_01"]
			var now: float = Time.get_unix_time_from_system()
			plot.restore_save_data({"state":"READY", "crop_type":"WHEAT", "planted_at":now-61, "ready_at":now-1, "position":Vector2(512,1216)})
			player.position = plot.position+Vector2(0,32)
			player.get_node("Camera2D").reset_smoothing()
			await create_timer(0.1).timeout
			var seeds: int = inv.wheat_seed
			push_key(KEY_E,true)
			push_click(player.get_canvas_transform()*plot.position,true)
			check(inv.wheat == 1 and plot.state == 0 and inv.wheat_seed == seeds, "harvest cannot also plant via simultaneous E/click")
			push_key(KEY_E,false)
			push_click(player.get_canvas_transform()*plot.position,false)
			await process_frame
			hud._toggle_shop()
			await create_timer(0.1).timeout
			push_click(player.get_canvas_transform()*plot.position,true)
			push_click(player.get_canvas_transform()*plot.position,false)
			check(plot.state == 0 and inv.wheat_seed == seeds, "modal blocks world click")
			var close_button = hud.get_node("ShopBuildPanel/Margin/Content/Footer/CloseButton")
			var ui_point: Vector2 = close_button.get_global_rect().get_center()
			plot.position = player.get_canvas_transform().affine_inverse()*ui_point
			await process_frame
			push_click(ui_point,true)
			push_click(ui_point,false)
			check(not hud.shop_build_panel.visible and plot.state == 0 and inv.wheat_seed == seeds, "closing UI cannot click through to plot")
			check(manager.reset_game(), "input cleanup")
		"edge_move":
			prepare()
			var gate = place_decoration("wood_gate",Vector2(512,1088))
			var editor = hud.edit_farm
			editor.enter_mode()
			editor.select_building(farm.get_node("House"))
			var count: int = farm.get_child_count()
			editor.begin_move()
			var first_preview = editor.preview
			editor.begin_move()
			check(editor.preview == first_preview and farm.get_child_count() == count+1, "repeated move command cannot leak previews")
			editor.cancel_or_exit()
			await process_frame
			check(editor.active and editor.preview == null and farm.get_child_count() == count, "cancel frees the only preview")
			editor.select_building(gate)
			editor._ask_delete()
			editor.click_world(player.get_canvas_transform()*farm.get_node("House").position)
			editor.begin_move()
			check(editor.delete_confirmation.visible and editor.selected == gate and editor.preview == null, "delete dialog blocks edit actions behind it")
			editor.cancel_or_exit()
			check(editor.active and editor.selected == gate and editor.menu.visible and not editor.delete_confirmation.visible, "ESC closes only deletion confirmation")
			editor.cancel_selection()
			editor.exit_mode()
			check(manager.reset_game(), "move cleanup")
		"edge_orders":
			prepare()
			inv.owns_bakery = true
			inv.bread = 1
			var order: Dictionary = {"order_id":"order_900000", "requirements":{"bread":1}, "coin_reward":40, "exp_reward":0}
			check(orders._is_valid_order(order), "existing zero-EXP Bakery order is valid")
			for requirements in [{1:1},{"unknown_item":1},{"bread":-1}]:
				var bad: Dictionary = order.duplicate(true)
				bad["requirements"] = requirements
				check(not orders._is_valid_order(bad), "malformed saved order rejected without runtime error")
			var incomplete: Dictionary = order.duplicate(true)
			incomplete.erase("exp_reward")
			check(not orders._is_valid_order(incomplete), "missing reward field uses safe order fallback")
			orders.restore_orders([order])
			inv.inventory_changed.emit()
			check(orders.orders[0]["order_id"] == "order_900000", "unrelated transaction does not replace valid Bakery order")
			check(manager.save_game(), "persist order fixture")
		"edge_orders_read":
			check(orders.orders[0]["order_id"] == "order_900000", "zero-EXP order survives reload")
			check(orders.complete_order("order_900000") and not orders.complete_order("order_900000"), "order rewards exactly once")
			check(inv.coins == 10040 and inv.bread == 0 and inv.player_exp == 0, "unchanged order economy and inventory")
		"edge_orders_again":
			check(inv.coins == 10040 and inv.bread == 0 and not orders.complete_order("order_900000"), "reload does not duplicate completed order reward")
			check(manager.reset_game(), "order cleanup")
		"edge_decoration":
			prepare()
			var gate = place_decoration("wood_gate",Vector2(512,1088))
			var fence = place_decoration("wood_fence",Vector2(864,1216))
			var decorations = farm.decoration_manager
			var records: Array = manager.placed_decorations.duplicate(true)
			manager.resetting = true # Simulate a rejected save without touching real files.
			var deleted: bool = decorations.remove(gate.instance_id)
			manager.resetting = false
			check(not deleted and is_instance_valid(gate) and gate.is_inside_tree() and manager.placed_decorations == records and decorations.instances.size() == 2, "rejected save rolls back decoration deletion")
			manager.resetting = true
			var moved: bool = decorations.move(gate,Vector2(704,1216),90)
			manager.resetting = false
			check(not moved and gate.position == Vector2(512,1088) and manager.placed_decorations == records, "rejected save keeps previous decoration transform")
			check(decorations.move(gate,Vector2(704,1216),90), "decoration move saved")
			var id: String = fence.instance_id
			check(decorations.remove(id) and not decorations.remove(id), "delete commits only once")
			check(inv.coins == 9850 and inv.wood == 7 and manager.placed_decorations.size() == 1 and decorations.instances.size() == 1, "deletion never refunds or duplicates inventory")
			check(disk().get_value("decorations","placed").size() == 1, "deletion persisted")
		"edge_decoration_read":
			check(manager.placed_decorations.size() == 1 and farm.decoration_manager.instances.size() == 1, "one saved decoration restored")
			var gate = farm.decoration_manager.instances["decor_0001"]
			check(gate.position == Vector2(704,1216) and is_equal_approx(gate.rotation_degrees,90), "decoration transform restored")
			check(manager.reset_game() and manager.placed_decorations.is_empty() and farm.decoration_manager.instances.is_empty(), "reset clears all decorations")
	print("PASS: " + stage)
	quit()
