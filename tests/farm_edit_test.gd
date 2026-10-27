extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var editor: Node
var player: Node
const DESTINATIONS: Dictionary = {"house": Vector2(320,1792), "warehouse": Vector2(768,1984), "order_board": Vector2(1088,1984), "feed_mill": Vector2(512,1664), "chicken_coop": Vector2(832,1664), "cow_shed": Vector2(1152,1664), "dog_house": Vector2(1472,1664), "bakery": Vector2(512,1984)}

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "save readable")
	return data

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.03).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.03).timeout

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = player.get_canvas_transform()*point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = player.get_canvas_transform()*point
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)
	await process_frame

func prepare() -> void:
	check(manager.reset_game(), "reset fixture")
	# Edit-only fixtures own the destination land; land purchasing has its own tests.
	manager.unlocked_land_zones.assign(manager.LandData.ZONES.keys())
	inv.player_level = 18
	inv.coins = 10000
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	for id in inv.Progression.BUILDINGS:
		if inv.Progression.BUILDINGS[id].get("placement_required",false):
			continue # Placement-purchased buildings have their own integration tests.
		check(inv.buy_building(id), "owned building fixture")
	inv.wood = 15
	inv.stone = 5
	check(inv.build_dog_house() and inv.buy_dog(), "dog house fixture")
	check(inv.buy_animal("chicken") and inv.buy_animal("cow"), "animals fixture")
	inv.wheat = 5
	inv.corn = 5
	inv.carrot = 5
	inv.chicken_feed = 1
	inv.cow_feed = 1
	for station in manager.stations.values():
		check(station.produce(), "production fixture")
	check(farm.get_node("Bakery").enqueue("bread"), "bakery queue fixture")
	inv.house_level = 2
	inv.silo_level = 2
	inv.silo_capacity = 50
	inv.wood = 10
	inv.stone = 10
	var decoration = load("res://decoration.tscn").instantiate()
	decoration.decoration_id = "wood_gate"
	decoration.is_preview = true
	farm.add_child(decoration)
	check(farm.decoration_manager.place(decoration, Vector2(256,1152), 0), "decoration fixture")
	decoration.free()

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	editor = hud.edit_farm
	player = farm.get_node("Player")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "edit_legacy_write":
		check(manager.reset_game(), "legacy fixture")
		var data := disk()
		for id in ["house","warehouse","order_board"]:
			data.erase_section_key("building_positions",id)
		check(data.save(manager.SAVE_PATH) == OK, "write missing landmark positions")
	elif stage == "edit_legacy_read":
		for id in ["house","warehouse","order_board"]:
			check(manager.buildings[id].position == inv.FarmData.BUILDINGS[id]["position"], "missing position keeps scene default " + id)
		check(farm.get_node("Warehouse").scale == Vector2(0.8,0.8), "existing Warehouse scale preserved")
		check(manager.reset_game(), "legacy cleanup")
	elif stage == "edit_read":
		check(not editor.active and inv.has_dog_house and inv.chicken_count == 1 and inv.cow_count == 1, "ownership and animals restore")
		for id in DESTINATIONS:
			check(manager.buildings[id].position == DESTINATIONS[id], "moved position restored " + id)
			check(farm.get_node(inv.FarmData.BUILDINGS[id]["node"]) == manager.buildings[id], "single building instance " + id)
		for station in manager.stations.values():
			check(station.ready_at == disk().get_value(station.station_id,"ready_at"), "production timestamp restored")
		check(manager.bakery_queue.size() == 1 and manager.bakery_queue[0]["item"] == "bread", "bakery queue restored")
		check(inv.house_level == 2 and inv.silo_level == 2 and inv.silo_capacity == 50, "moved landmarks keep progression")
		check(farm.decoration_manager.instances["decor_0001"].position == Vector2(1408,1984) and is_equal_approx(farm.decoration_manager.instances["decor_0001"].rotation_degrees, 90), "decoration move/rotation restored")
		check(manager.reset_game(), "cleanup")
	else:
		prepare()
		hud.open_build()
		hud.build_rows.get_node("EditFarmButton").pressed.emit()
		check(editor.active and not hud.shop_build_panel.visible and hud.blocks_world_input(), "Build menu enters edit mode")
		check(editor.movable_buildings().size() == 10 + inv.unlocked_plot_count, "owned landmarks/buildings including Market Stall, decoration and unlocked plots")
		for node_name in ["River","RiverWalls","Bridge","FishingSpot","FishMarket","Ground","FarmYard","farm_core","land_01"]:
			var fixed = farm.get_node(node_name)
			var color: Color = fixed.modulate
			if fixed is Node2D:
				editor.select_building(fixed)
			else:
				check(fixed not in editor.movable_buildings().values(), "terrain excluded from selection " + node_name)
			check(editor.selected == null, "fixed landmark cannot move " + node_name)
			check(fixed.modulate == color, "fixed object not highlighted " + node_name)
		for node_name in ["River","Bridge","FishingSpot"]:
			check(editor.target_at(farm.get_node(node_name).global_position) == null, "fixed world object excluded from hover targets " + node_name)
		for id in ["house","warehouse","order_board"]:
			var landmark = manager.buildings[id]
			check(editor.target_at(landmark.global_position) == landmark, "landmark available to hover " + id)
			check(editor.Placement.can_place(landmark,landmark.global_position), "landmark ignores its own footprint " + id)
			player.position = landmark.position + Vector2(0,96)
			player.get_node("Camera2D").reset_smoothing()
			await create_timer(0.1).timeout
			await click(landmark.global_position)
			check(editor.selected == landmark and editor.menu.visible and landmark.modulate != Color.WHITE, "click selects and highlights " + id)
			var original_position: Vector2 = landmark.position
			editor.begin_move()
			editor.update_preview(DESTINATIONS[id])
			check(editor.valid_position, "landmark shares grid and collision validation " + id)
			await key(KEY_ESCAPE)
			check(editor.active and editor.preview == null and landmark.position == original_position and landmark.modulate == Color.WHITE, "landmark cancel restores position and highlight " + id)
		var mill = manager.buildings["feed_mill"]
		check(editor.Placement.can_place(mill,mill.global_position), "validation ignores source building")
		for obstacle in [farm.get_node("House"), farm.get_node("Warehouse"), manager.plots["soil_32"], manager.resources["tree_1"], manager.resources["rock_3"], manager.buildings["chicken_coop"], farm.get_node("Bridge")]:
			check(not editor.Placement.can_place(mill, obstacle.global_position), "obstacle rejected " + str(obstacle.name))
		check(not editor.Placement.can_place(mill,Vector2(10,10)) and not editor.Placement.can_place(mill,Vector2(2100,1800)), "out of owned land and locked river side")
		player.position = mill.position+Vector2(0,60)
		player.get_node("Camera2D").reset_smoothing()
		await create_timer(0.1).timeout
		await click(mill.global_position)
		check(editor.selected == mill and editor.menu.visible and not hud.station_panel.visible, "edit click selects without production panel")
		var original: Vector2 = mill.position
		var deadline: float = mill.ready_at
		editor.begin_move()
		editor.update_preview(Vector2(501,1658))
		check(editor.proposed_position == Vector2(512,1664) and editor.valid_position, "grid snap and valid preview")
		check(mill.position == original and mill.ready_at == deadline, "preview leaves real building and timer untouched")
		check(manager.save_game() and disk().get_value("building_positions","feed_mill") == original, "autosave never saves preview")
		for code in [KEY_P,KEY_TAB,KEY_E]:
			await key(code)
			check(editor.active and is_instance_valid(editor.preview) and not hud.shop_build_panel.visible and not hud.storage_panel.visible and not hud.station_panel.visible, "move blocks other interaction keys")
		await key(KEY_ESCAPE)
		check(editor.active and editor.preview == null and mill.position == original and mill.modulate == Color.WHITE, "first ESC cancels move")
		await key(KEY_ESCAPE)
		check(not editor.active and not hud.blocks_world_input(), "second ESC exits edit mode")
		editor.enter_mode()
		editor.select_building(mill)
		editor.begin_move()
		player.position = DESTINATIONS["feed_mill"]+Vector2(0,128)
		player.get_node("Camera2D").reset_smoothing()
		await create_timer(0.1).timeout
		await click(DESTINATIONS["feed_mill"])
		check(editor.preview == null and mill.position == DESTINATIONS["feed_mill"], "left click commits placement without world interaction")
		var bakery_before: Array = manager.bakery_queue.duplicate(true)
		var orders_before: Array = root.get_node("OrderManager").orders.duplicate(true)
		var inventory_before: Dictionary = {}
		for item in manager.INVENTORY_DEFAULTS:
			inventory_before[item] = inv.get(item)
		farm.dog.set_physics_process(false)
		farm.dog.idle_timer.stop()
		farm.dog.walking = true
		farm.dog.target = farm.dog.position + Vector2(10,0)
		var dog_target: Vector2 = farm.dog.target
		for id in DESTINATIONS:
			var building = manager.buildings[id]
			var before: Dictionary = building.get_save_data() if building.has_method("get_save_data") else {}
			editor.select_building(building)
			editor.begin_move()
			editor.update_preview(DESTINATIONS[id])
			check(editor.valid_position and editor.place_move(), "place valid building " + id)
			check(building.position == DESTINATIONS[id] and disk().get_value("building_positions",id) == DESTINATIONS[id], "immediate position autosave")
			if not before.is_empty():
				check(building.get_save_data() == before, "moving preserves production and animals")
			check(not editor.delete_button.visible, "building never offers decoration delete")
		var decoration = farm.decoration_manager.instances["decor_0001"]
		editor.select_building(decoration)
		check(editor.selected == decoration and editor.delete_button.visible, "decoration selectable")
		editor.begin_move()
		editor.rotate_preview()
		editor.update_preview(Vector2(1408,1984))
		check(editor.valid_position and editor.place_move(), "decoration uses shared move validation")
		check(root.get_node("OrderManager").orders == orders_before and inv.house_level == 2 and inv.silo_capacity == 50, "landmarks keep levels, storage and order data")
		for item in inventory_before:
			check(inv.get(item) == inventory_before[item], "moving does not change inventory " + item)
		check(farm.dog.walking and farm.dog.target == dog_target and farm.dog.idle_timer.is_stopped(), "DogHouse move preserves dog state")
		check(manager.bakery_queue == bakery_before and inv.chicken_count == 1 and inv.cow_count == 1, "queue and animals unchanged")
		check(farm.dog.home_point == manager.buildings["dog_house"] and farm.dog.wander_bounds == player.farm_bounds, "dog uses moved home")
		if stage == "edit_core":
			editor.select_building(mill)
			editor.begin_move()
			editor.update_preview(Vector2(2100,1800))
			check(not editor.valid_position and not editor.place_move(), "invalid placement cannot commit")
			check(manager.reset_game() and not editor.active and editor.preview == null, "reset cancels edit safely")
			check(mill.position == inv.FarmData.BUILDINGS["feed_mill"]["position"], "cancel does not undo reset defaults")
		else:
			editor.exit_mode()
			check(manager.save_game(), "persist move fixture")
	print("PASS: " + stage)
	quit()
