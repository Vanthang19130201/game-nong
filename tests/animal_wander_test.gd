extends SceneTree

const DESTINATIONS: Dictionary = {"cow_shed": Vector2(768,1216), "chicken_coop": Vector2(1152,1216)}
var inv: Node
var manager: Node
var farm: Node
var hud: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func group_for(id: String) -> Node:
	return farm.animal_groups["chicken" if id == "chicken_coop" else "cow"]

func verify_groups(count: int) -> void:
	for id in DESTINATIONS:
		var group = group_for(id)
		var home = manager.buildings[id]
		var pen = home.get_node("AnimalPen")
		check(pen.get_parent() == home and pen.global_position == home.global_position, "visual pen is attached to its saved building " + id)
		check(group.global_position == home.global_position, "wander center and pen restore with the saved home " + id)
		check(pen.gate_width >= 48.0 and pen.gate_width <= 72.0, "open gate is wide enough for the player " + id)
		check(pen.find_children("*", "CollisionShape2D", true, false).is_empty(), "pen artwork has no collision " + id)
		check(pen.half_size.x >= group.wander_radius + (12.0 if id == "cow_shed" else 8.0), "pen width contains the current wander radius " + id)
		check(pen.half_size.y >= group.wander_radius + (12.0 if id == "cow_shed" else 8.0), "pen height contains the current wander radius " + id)
		check(group.animals().size() == count, "exact instance count " + id)
		for animal in group.animals():
			check(animal.is_visible_in_tree(), "each owned animal is visible " + id)
			check(group.is_position_valid(animal.position, animal.body_radius), "animal on valid nearby ground " + id)
			check(animal.collision_layer == 0 and animal.collision_mask == 0 and not animal.monitoring, "animals never physically block player")
			check(animal.is_in_group("farm_interactables") and not animal.is_in_group("placement_obstacles"), "animal entities use the central dispatcher")

func prepare() -> void:
	check(manager.reset_game(), "reset isolated fixture")
	inv.player_level = 10
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.inventory_changed.emit()
	for id in DESTINATIONS:
		check(inv.buy_building(id), "buy owned building " + id)
	for kind in ["chicken", "cow"]:
		for n in range(3):
			check(inv.buy_animal(kind), "buy three animals")
	verify_groups(3)

func move_homes() -> void:
	var editor = hud.edit_farm
	editor.enter_mode()
	for id in DESTINATIONS:
		var building = manager.buildings[id]
		var group = group_for(id)
		var data: Dictionary = building.get_save_data().duplicate(true)
		var instance: int = building.get_instance_id()
		var animals_before: Array = group.animals()
		editor.select_building(building)
		editor.begin_move()
		check(editor.preview.get_node_or_null("AnimalPenPreview") != null, "move preview contains the attached pen " + id)
		editor.update_preview(DESTINATIONS[id])
		check(editor.valid_position, "shared placement accepts move " + id)
		check(editor.place_move(), "commit move " + id)
		await process_frame
		await process_frame
		check(building.get_instance_id() == instance and group.animals() == animals_before, "move reuses building and animals " + id)
		check(building.get_save_data() == data, "move keeps animals and production timestamps " + id)
		check(group.global_position == DESTINATIONS[id], "wander center follows moved home " + id)
		check(building.get_node("AnimalPen").global_position == building.global_position, "fence follows the moved home " + id)
		for animal in group.animals():
			check(not animal.walking and animal.target == animal.position, "old walking targets cleared " + id)
		editor.select_building(building)
		editor.begin_move()
		editor.update_preview(Vector2(1024,1280))
		editor.cancel_or_exit()
		check(building.position == DESTINATIONS[id], "cancel leaves home and wander center unchanged " + id)
	editor.exit_mode()
	await process_frame
	await process_frame
	verify_groups(3)

func capture() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var camera = farm.get_node("Player/Camera2D")
	camera.zoom = Vector2.ONE
	camera.target_zoom = 1.0
	camera.begin_pan()
	camera.pan_center = Vector2(1200,1040)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://animal_wander.png") == OK, "capture separate animal visuals")

func check_gate_access() -> void:
	var player: Node2D = farm.get_node("Player")
	var original := player.global_position
	for id in DESTINATIONS:
		var home = manager.buildings[id]
		var pen = home.get_node("AnimalPen")
		var gate_y: float = pen.center_offset.y + pen.half_size.y
		player.global_position = home.global_position + Vector2(0, gate_y + 48.0)
		Input.action_press("move_up")
		await create_timer(0.45).timeout
		Input.action_release("move_up")
		check(player.global_position.y < home.global_position.y + gate_y, "player can enter through the open visual gate " + id)
	player.global_position = original

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
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "animals_reset_read":
		verify_groups(0)
		check(inv.chicken_count == 0 and inv.cow_count == 0, "reset stays clear after restart")
	elif stage in ["animals_read", "animals_again"]:
		verify_groups(3)
		var saved := ConfigFile.new()
		check(saved.load(manager.SAVE_PATH) == OK, "read same existing save format")
		for id in DESTINATIONS:
			check(manager.buildings[id].position == DESTINATIONS[id], "moved home restored " + id)
			check(manager.stations[id].ready_at == saved.get_value(id,"ready_at"), "production timestamp restored " + id)
			check(not saved.has_section("animal_positions"), "no individual animal position save")
		for n in range(5):
			inv.inventory_changed.emit()
		verify_groups(3)
		if stage == "animals_again":
			check(manager.reset_game(), "reset animals and ownership")
			verify_groups(0)
	else:
		prepare()
		if stage == "animals_core":
			await check_gate_access()
			for kind in ["chicken", "cow"]:
				check(inv.sell_animal(kind), "existing animal sale")
				check(group_for("chicken_coop" if kind == "chicken" else "cow_shed").animals().size() == 2, "sale removes exactly one visual immediately")
				check(inv.buy_animal(kind), "buy restores third visual immediately")
			verify_groups(3)
			var coins: int = inv.coins
			var before: Dictionary = {}
			var positions: Dictionary = {}
			for id in DESTINATIONS:
				var group = group_for(id)
				before[id] = manager.stations[id].get_save_data().duplicate(true)
				check(not group.is_position_valid(Vector2.ZERO,8), "animals avoid own building")
				check(not group.path_is_clear(Vector2(0,120),Vector2(0,-120),8), "walk cannot cross own building")
				for obstacle in group.obstacles:
					check(not group.is_position_valid(group.to_local(obstacle.get_center()),8), "resources, plots and buildings block animal feet")
				for animal in group.animals():
					positions[animal] = animal.position
					for attempt in range(8):
						animal.choose_target()
						if animal.walking:
							break
				check(group.animals().any(func(animal): return animal.walking), "some animals begin a valid random walk " + id)
			await create_timer(1.0).timeout
			check(positions.keys().any(func(animal): return animal.position.distance_to(positions[animal]) > 1), "visuals move slowly over time")
			verify_groups(3)
			for id in DESTINATIONS:
				check(manager.stations[id].get_save_data() == before[id], "wander never changes production state")
			check(inv.coins == coins and inv.egg == 0 and inv.milk == 0, "wander never grants items or changes coins")
			if "--capture" in OS.get_cmdline_user_args():
				await capture()
		inv.chicken_feed = 1
		inv.cow_feed = 1
		for id in DESTINATIONS:
			check(manager.stations[id].produce(), "original production starts")
		await move_homes()
		# Move a home next to the locked southern border: no animal may enter it.
		var group = group_for("chicken_coop")
		var original: Vector2 = manager.buildings["chicken_coop"].position
		manager.buildings["chicken_coop"].position = Vector2(1500,1400)
		await process_frame
		await process_frame
		check(not group.is_position_valid(Vector2(0,120),8), "locked land blocks wandering")
		verify_groups(3)
		manager.buildings["chicken_coop"].position = original
		await process_frame
		await process_frame
		if stage == "animals_core":
			for id in DESTINATIONS:
				var station = manager.stations[id]
				station.ready_at = Time.get_unix_time_from_system() - 1
				station._finish_production()
				check(station.collect() and not station.collect(), "existing production collect pays once")
			check(inv.egg == 3 and inv.milk == 3, "three animals still yield exactly three products")
			check(manager.reset_game(), "cleanup")
			verify_groups(0)
		else:
			check(manager.save_game(), "save counts, moved homes and production")
	print("PASS: " + stage)
	quit()
