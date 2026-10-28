extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAILED: " + message)
		quit(1)
		return

func _run() -> void:
	await process_frame
	var inventory: Node = root.get_node("Inventory")
	var save_manager: Node = root.get_node("SaveManager")
	_check(save_manager.SAVE_PATH == "res://test-save.cfg", "isolated test save")
	var farm: Node2D = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await process_frame
	_check(save_manager.reset_game(), "reset test fixture")
	save_manager.unlocked_land_zones.assign(save_manager.LandData.ZONES.keys())
	inventory.player_level = 18
	inventory.coins = 10000
	var editor: Node = farm.get_node("HUD").edit_farm

	for id in ["pig_pen", "sheep_barn"]:
		var before_coins: int = inventory.coins
		var cost: int = inventory.Progression.BUILDINGS[id]["price"]
		editor.begin_building_placement(id)
		_check(is_instance_valid(editor.preview), id + " preview created")
		var target := Vector2.ZERO
		var found := false
		for y in range(128, 2176, 64):
			for x in range(128, 1664, 64):
				var candidate := Vector2(x, y)
				if editor.Placement.can_place(editor.preview, candidate):
					target = candidate
					found = true
					break
			if found:
				break
		_check(found, id + " has a valid placement")
		editor.update_preview(target)
		_check(editor.valid_position, id + " preview accepted")
		var placed_position: Vector2 = editor.proposed_position
		_check(editor.place_move(), id + " purchase/place succeeds")
		_check(inventory.owns_building(id), id + " ownership is set")
		_check(is_instance_valid(save_manager.buildings[id]), id + " real building spawned")
		_check(save_manager.buildings[id].visible, id + " real building is visible")
		_check(save_manager.buildings[id].position == placed_position, id + " real building uses placed position")
		_check(inventory.coins == before_coins - cost, id + " charges exactly once")
		_check(save_manager.save_game(), id + " save succeeds")
		var data := ConfigFile.new()
		_check(data.load(save_manager.SAVE_PATH) == OK, id + " save can be read")
		_check(data.get_value("buildings", "owns_" + id, false) == true, id + " ownership persists")
		_check(data.get_value("building_positions", id, Vector2.ZERO) == placed_position, id + " position persists")

	_check(save_manager.reset_game(), "cleanup test fixture")
	current_scene = null
	farm.queue_free()
	await process_frame
	await process_frame
	print("PASS: pig_sheep_placement")
	quit(0)
