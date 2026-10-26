extends SceneTree

const DESTINATIONS: Dictionary = {"soil_01": Vector2(512,1152), "soil_05": Vector2(576,1152), "soil_03": Vector2(640,1152)}
var inv: Node
var manager: Node
var farm: Node
var hud: Node
var editor: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var result := ConfigFile.new()
	check(result.load(manager.SAVE_PATH) == OK, "isolated save readable")
	return result

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event,true)
	await process_frame

func click(point: Vector2) -> void:
	var screen: Vector2 = player.get_canvas_transform()*point
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = screen
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = player.get_canvas_transform()*point
	root.push_input(event,true)
	await process_frame
	await process_frame
	# Headless input does not move the OS pointer used by get_mouse_position().
	editor.update_hover(point)

func prepare() -> void:
	check(manager.reset_game(), "reset fixture")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.wood = 20
	inv.stone = 10
	for id in inv.Progression.BUILDINGS:
		if inv.Progression.BUILDINGS[id].get("placement_required",false):
			continue
		check(inv.buy_building(id), "owned obstacle " + id)
	check(inv.build_dog_house(), "owned DogHouse obstacle")
	inv.corn_seed = 2
	check(inv.select_crop("CORN"), "corn selection")
	manager.plots["soil_05"].try_plant()
	check(manager.plots["soil_05"].state == 1, "soil_05 growing corn fixture")
	var now: float = Time.get_unix_time_from_system()
	manager.plots["soil_03"].restore_save_data({"state":"READY", "crop_type":"CARROT", "planted_at":now-241, "ready_at":now-1})
	check(manager.save_game(), "save crop fixtures")

func move_plot(id: String, destination: Vector2) -> void:
	var plot = manager.plots[id]
	var before: Dictionary = plot.get_save_data()
	before.erase("position")
	var timer_id: int = plot.grow_timer.get_instance_id()
	var remaining: float = plot.grow_timer.time_left
	editor.select_building(plot)
	check(editor.selected == plot and editor.selected_id == id and not editor.delete_button.visible, "plot selected without delete " + id)
	editor.begin_move()
	editor.update_preview(destination)
	check(editor.valid_position and editor.preview.modulate.g > editor.preview.modulate.r, "valid green preview " + id)
	check(editor.place_move(), "plot movement commits " + id)
	var after: Dictionary = plot.get_save_data()
	after.erase("position")
	check(after == before and plot.grow_timer.get_instance_id() == timer_id and plot.grow_timer.time_left <= remaining+0.01, "move keeps crop and original timer " + id)
	check(plot.position == destination and disk().get_value(id,"position") == destination, "position autosaved " + id)
	check(not manager.building_positions.has(id) and manager.plots.size() == 32, "plot uses its own stable save section without duplicates")

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "test must never use player save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	editor = hud.edit_farm
	player = farm.get_node("Player")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage in ["soil_edit_core","soil_edit_write","soil_edit_legacy_write","soil_edit_invalid_write"]:
		prepare()
		editor.enter_mode()
		var growing = manager.plots["soil_05"]
		if stage == "soil_edit_core":
			var locked = manager.plots["soil_09"]
			player.position = growing.position+Vector2(0,96)
			player.get_node("Camera2D").reset_smoothing()
			await create_timer(0.1).timeout
			await hover(locked.position)
			check(editor.target_at(locked.position) == null and locked.modulate == Color.WHITE, "locked plot has no movable highlight")
			await click(locked.position)
			check(editor.selected == null and not editor.menu.visible and not editor.Placement.can_place(locked,Vector2(256,1152)), "locked plot cannot select or move")
			await hover(growing.position)
			check(editor.hovered == growing and growing.modulate != Color.WHITE, "growing plot highlights on hover")
			var seeds: int = inv.corn_seed
			await click(growing.position)
			check(editor.selected == growing and editor.menu.visible and inv.corn_seed == seeds and growing.state == 1, "edit click selects without planting or harvesting")
			var original_position: Vector2 = growing.position
			var old_deadline: float = growing.ready_at
			var old_remaining: float = growing.grow_timer.time_left
			editor.begin_move()
			editor.update_preview(Vector2(571,1147))
			check(editor.proposed_position == Vector2(576,1152) and editor.valid_position and growing.position == original_position, "snap preview leaves saved object at old position")
			manager.autosave_timer.timeout.emit()
			check(disk().get_value("soil_05","position") == original_position and disk().get_value("soil_05","ready_at") == old_deadline, "autosave during move keeps old position and crop")
			await key(KEY_E)
			await key(KEY_ESCAPE)
			check(editor.active and editor.preview == null and growing.position == original_position and growing.ready_at == old_deadline and growing.grow_timer.time_left < old_remaining and growing.grow_timer.time_left > old_remaining-2, "ESC cancels without restarting growth timer")
			for obstacle in [manager.plots["soil_01"],manager.plots["soil_32"],farm.get_node("House"),farm.get_node("Warehouse"),farm.get_node("OrderBoard"),farm.get_node("DogHouse"),manager.buildings["feed_mill"],manager.buildings["chicken_coop"],manager.buildings["cow_shed"],manager.resources["tree_1"],manager.resources["rock_1"],farm.get_node("River"),farm.get_node("Bridge"),farm.get_node("FishingSpot")]:
				check(not editor.Placement.can_place(growing,obstacle.global_position), "plot cannot cover " + str(obstacle.name))
			for point in [Vector2(0,0),Vector2(2400,1000),Vector2(512,1664),Vector2(1024,1472)]:
				check(not editor.Placement.can_place(growing,point), "reject outside/locked land including partial footprints")
			check(editor.Placement.can_place(growing,growing.position), "self ignored inside original field reserve")
			for index in range(4):
				var type: String = ["wood_fence","wood_gate","farm_lamp","stone_path"][index]
				var point := Vector2(832+64*index,1216)
				var decoration = load("res://decoration.tscn").instantiate()
				decoration.decoration_id = type
				decoration.is_preview = true
				farm.add_child(decoration)
				check(farm.decoration_manager.place(decoration,point,0), "decoration fixture " + type)
				decoration.free()
				check(editor.Placement.can_place(growing,point) == (type == "stone_path"), "only solid decorations block plots " + type)
			editor.select_building(growing)
			editor.begin_move()
			editor.update_preview(Vector2(512,1664))
			check(not editor.valid_position and editor.preview.modulate.r > editor.preview.modulate.g and not editor.place_move(), "invalid red preview cannot commit")
			editor.cancel_selection()
		for id in DESTINATIONS:
			move_plot(id,DESTINATIONS[id])
		editor.exit_mode()
		farm._create_farm_grid()
		for id in DESTINATIONS:
			check(manager.plots[id].position == DESTINATIONS[id], "grid refresh preserves moved plot")
		if stage == "soil_edit_core":
			await check_normal_interaction()
			await check_all_plots()
			check(manager.reset_game(), "reset moved plots")
			check_defaults()
		elif stage == "soil_edit_legacy_write":
			var data := disk()
			for id in manager.PLOT_IDS:
				data.erase_section_key(id,"position")
			check(data.save(manager.SAVE_PATH) == OK, "legacy fixture omits plot positions")
		elif stage == "soil_edit_invalid_write":
			var data := disk()
			var bad: Array = ["bad",Vector2(NAN,NAN),Vector2(3000,3000),Vector2(512,1664),Vector2(1024,1472)]
			for index in range(bad.size()):
				data.set_value(manager.PLOT_IDS[index],"position",bad[index])
			check(data.save(manager.SAVE_PATH) == OK, "invalid plot positions fixture")
	elif stage in ["soil_edit_read","soil_edit_offline_read"]:
		for id in DESTINATIONS:
			check(manager.plots[id].position == DESTINATIONS[id] and manager.plots[id].plot_id == id, "reload restores stable ID and position " + id)
		var growing = manager.plots["soil_05"]
		check(growing.crop_type == "CORN" and growing.planted_at == disk().get_value("soil_05","planted_at") and growing.ready_at == disk().get_value("soil_05","ready_at"), "reload keeps corn timestamps")
		check(growing.state == (1 if stage == "soil_edit_read" else 2), "reload resumes growth or completes offline")
		if stage == "soil_edit_read":
			check(growing.grow_timer.time_left > 60 and growing.grow_timer.time_left <= growing.ready_at-Time.get_unix_time_from_system()+0.2, "reload resumes remaining time")
		check(manager.plots["soil_03"].state == 2 and manager.plots["soil_03"].crop_type == "CARROT" and inv.corn == 0 and inv.carrot == 0, "ready crop restored without duplicate reward")
		check(manager.plots.size() == 32, "reload creates exactly 32 plots")
		if stage == "soil_edit_offline_read":
			check(manager.reset_game(), "reset fixture")
	elif stage == "soil_edit_offline_write":
		var data := disk()
		var now: float = Time.get_unix_time_from_system()
		data.set_value("soil_05","planted_at",now-121)
		data.set_value("soil_05","ready_at",now-1)
		check(data.save(manager.SAVE_PATH) == OK, "offline completion fixture")
	elif stage == "soil_edit_legacy_read":
		for id in manager.PLOT_IDS:
			check(manager.plots[id].position == inv.FarmData.plot_position(inv.FarmData.plot_number(id)), "legacy default position " + id)
		check(manager.plots["soil_05"].crop_type == "CORN" and manager.plots["soil_05"].state == 1 and manager.plots["soil_03"].state == 2, "legacy migration keeps crops")
		check(manager.reset_game(), "legacy cleanup")
	elif stage == "soil_edit_invalid_read":
		for id in manager.PLOT_IDS.slice(0,5):
			check(manager.plots[id].position == inv.FarmData.plot_position(inv.FarmData.plot_number(id)), "invalid position uses default " + id)
		check(manager.plots["soil_05"].crop_type == "CORN" and manager.plots["soil_05"].state == 1, "invalid position does not delete crop")
		check(manager.reset_game(), "invalid cleanup")
	elif stage == "soil_edit_reset_read":
		check_defaults()
	print("PASS: " + stage)
	quit()

func check_normal_interaction() -> void:
	var plot = manager.plots["soil_01"]
	player.position = plot.position+Vector2(0,32)
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	var seeds: int = inv.corn_seed
	await click(plot.position)
	check(plot.state == 1 and inv.corn_seed == seeds-1 and plot.crop_type == "CORN", "normal click plants moved plot")
	plot.planted_at = Time.get_unix_time_from_system()-121
	plot.ready_at = Time.get_unix_time_from_system()-1
	plot._on_grow_timer_timeout()
	await click(plot.position)
	check(plot.state == 0 and inv.corn == 1 and plot.position == DESTINATIONS["soil_01"], "normal click harvests moved plot")
	await key(KEY_E)
	check(inv.corn == 1, "no duplicate crop reward")

func check_all_plots() -> void:
	while inv.unlocked_plot_count < 32:
		check(inv.buy_plot(inv.unlocked_plot_count+1), "purchase remaining plots normally")
	editor.enter_mode()
	for index in range(32):
		var id: String = manager.PLOT_IDS[index]
		move_plot(id,Vector2(256+64*(index%8),1088+64*(index/8)))
	editor.exit_mode()
	check(manager.plots.size() == 32, "all 32 plots move without duplication")

func check_defaults() -> void:
	check(inv.unlocked_plot_count == 8 and manager.plots.size() == 32, "reset restores plot ownership")
	for id in manager.PLOT_IDS:
		var plot = manager.plots[id]
		check(plot.position == inv.FarmData.plot_position(inv.FarmData.plot_number(id)) and plot.state == 0 and plot.grow_timer.is_stopped(), "reset restores default position and empty state " + id)
