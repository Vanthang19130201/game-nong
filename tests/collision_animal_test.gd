extends SceneTree

const MOVED_STALL := Vector2(768, 1216)
var farm: Node2D
var inv: Node
var manager: Node
var hud: Node
var player: CharacterBody2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok, message)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func prepare() -> void:
	check(manager.reset_game(), "isolated reset")
	inv.player_level = 20
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.normalize_exp()
	for id in ["feed_mill", "bakery", "chicken_coop", "cow_shed"]:
		check(inv.buy_building(id), "purchase fixture " + id)
	inv.owns_dairy = true
	inv.owns_spinning_machine = true
	inv.inventory_changed.emit()
	await settle()

func hit_body(object: Node2D, shape_path: String = "Body/CollisionShape2D", blocked: bool = true) -> void:
	var shape: CollisionShape2D = object.get_node(shape_path)
	var bounds: Rect2 = shape.global_transform * shape.shape.get_rect()
	player.global_position = Vector2(bounds.get_center().x, bounds.end.y + 48)
	await settle()
	var hit := player.move_and_collide(Vector2(0, -(bounds.size.y + 96)))
	if blocked:
		check(hit != null and hit.get_collider() == object.get_node("Body"), "player is blocked by lower body " + object.name)
		check(player.global_position.y > bounds.end.y, "player cannot cross footprint " + object.name)
	else:
		check(hit == null or hit.get_collider() != object.get_node("Body"), "depleted/hidden object has no invisible wall " + object.name)

func collision_checks() -> void:
	await prepare()
	player.set_physics_process(false)
	for id in ["house", "warehouse", "feed_mill", "bakery", "dairy", "spinning_machine", "chicken_coop", "cow_shed", "market_stall", "order_board", "dog_house"]:
		var building: Node2D = manager.buildings[id]
		check(building.find_children("Body", "StaticBody2D", true, false).size() == 1, "one physical body " + id)
		await hit_body(building)
	await hit_body(farm.get_node("FishMarket"))
	for id in ["tree_1", "rock_1"]:
		var resource: Node2D = manager.resources[id]
		var shape_path := "Body/CollisionShape2D" if id == "tree_1" else "Body/RockCollisionShape2D"
		await hit_body(resource, shape_path)
		var shape: CollisionShape2D = resource.get_node(shape_path)
		var rect: Rect2 = shape.global_transform * shape.shape.get_rect()
		player.global_position = Vector2(rect.get_center().x, rect.end.y + 14)
		await settle()
		await create_timer(0.08).timeout
		check(resource.harvest(), "start existing harvest " + id)
		resource.harvest_timer.stop()
		resource._finish_harvest()
		await settle()
		check(resource.state == "DEPLETED" and shape.disabled, "depletion disables body " + id)
		await hit_body(resource, shape_path, false)
		player.position = Vector2(800, 600)
		resource.respawn_at = Time.get_unix_time_from_system() - 1
		resource._respawn()
		await settle()
		await hit_body(resource, shape_path)
		resource.zone_id = "unavailable_test_zone"
		resource._update_zone(true)
		await settle()
		check(shape.disabled, "locked resource body disabled " + id)
		resource.zone_id = "main"
		resource._update_zone(true)
	for id in ["dairy", "spinning_machine"]:
		var preview = load(manager.FarmData.BUILDINGS[id]["scene"]).instantiate()
		preview.is_preview = true
		farm.add_child(preview)
		await settle()
		check(preview.get_node("Body/CollisionShape2D").disabled, "purchase preview cannot block " + id)
		preview.free()
	var mill: Node2D = manager.buildings["feed_mill"]
	mill.hide()
	await settle()
	check(mill.get_node("Body/CollisionShape2D").disabled, "hidden building cannot block")
	mill.show()
	await settle()
	check(not mill.get_node("Body/CollisionShape2D").disabled, "shown building blocks again")
	# Sweep across the river outside the bridge, then across the unlocked bridge.
	player.position = Vector2(1740, 720)
	await settle()
	var water_hit := player.move_and_collide(Vector2(300, 0))
	check(water_hit != null and water_hit.get_collider() == farm.get_node("RiverWalls"), "river blocks outside bridge")
	player.position = Vector2(1740, 850)
	await settle()
	check(player.move_and_collide(Vector2(300, 0)) == null and player.position.x > 1940, "unlocked bridge remains passable")
	player.set_physics_process(true)
	await move_checks()
	check(manager.reset_game(), "collision cleanup")

func move_checks() -> void:
	var editor = hud.edit_farm
	editor.enter_mode()
	for id in ["warehouse", "feed_mill", "market_stall"]:
		var building: Node2D = manager.buildings[id]
		check(editor.movable_buildings().get(id) == building, "registered movable " + id)
		editor.click_world(building.get_global_transform_with_canvas().origin)
		check(editor.selected == building and editor.menu.visible, "click selects and opens Move menu " + id)
		editor.begin_move()
		check(editor.preview != null and editor.preview.find_children("*", "CollisionObject2D", true, false).is_empty(), "move preview is graphics only " + id)
		check(not building.get_node("Body/CollisionShape2D").disabled, "real building retains its own body " + id)
		if id == "market_stall":
			for invalid in [manager.buildings["warehouse"].position, manager.plots["soil_01"].global_position, manager.resources["tree_1"].global_position, Vector2(1870,850), Vector2(0,0)]:
				editor.update_preview(invalid)
				check(not editor.valid_position, "stall rejects occupied/water/outside position")
			editor.update_preview(MOVED_STALL + Vector2(5, 4))
			check(editor.proposed_position == MOVED_STALL and editor.valid_position, "stall snaps to valid grid position")
			check(editor.place_move() and building.position == MOVED_STALL, "stall moves via existing placement")
			check(manager.building_positions[id] == MOVED_STALL, "stall uses existing save-position dictionary")
		else:
			editor.cancel_selection()
	editor.exit_mode()

func bubbles(group: Node, expected_state: String, expected_item: String) -> void:
	for animal in group.animals():
		var bubble = animal.get_node("StatusBubble")
		check(bubble.state == expected_state and bubble.item_id == expected_item, "animal derives current state " + group.animal_type + expected_state)
		check(bubble.visible == (expected_state != "PRODUCING"), "bubble visibility follows state")
		check(animal.find_children("StatusBubble", "Node2D", true, false).size() == 1, "one reusable bubble per animal")
		check((bubble.bob != null) == (expected_state == "READY" and animal.is_visible_in_tree()), "only visible READY bubbles animate")

func capture_animals(station: Node2D, name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var camera = player.get_node("Camera2D")
	camera.target_zoom = 1.0
	camera.zoom = Vector2.ONE
	camera.begin_pan()
	camera.end_pan()
	camera.pan_center = station.global_position + Vector2(0, 30)
	hud.floating_feedback.clear()
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(1152, 648), "animal render uses current game resolution")
	check(image.save_png("res://animal-" + name + ".png") == OK, "capture animal status " + name)

func animal_checks() -> void:
	await prepare()
	for kind in ["chicken", "cow"]:
		for index in range(3):
			check(inv.buy_animal(kind), "buy animal fixture")
	await settle()
	for group in farm.animal_groups.values():
		for animal in group.animals():
			check(group.is_position_valid(animal.position, animal.body_radius), "animal spawns outside building footprints")
	inv.wood = 5
	check(inv.build_dog_house() and inv.buy_dog(), "dog fixture")
	var dog_shape: CollisionShape2D = farm.dog.get_node("CollisionShape2D")
	var house_shape: CollisionShape2D = farm.get_node("DogHouse/Body/CollisionShape2D")
	check(not (dog_shape.global_transform * dog_shape.shape.get_rect()).intersects(house_shape.global_transform * house_shape.shape.get_rect()), "dog spawns in front of its physical house")
	for kind in ["chicken", "cow"]:
		var station = manager.stations["chicken_coop" if kind == "chicken" else "cow_shed"]
		var group = farm.animal_groups[kind]
		var product: Dictionary = station.Progression.PRODUCTS[station.station_id]
		for index in range(group.animals().size()):
			var animal = group.animals()[index]
			animal.rest()
			animal.idle_timer.stop()
			animal.position = Vector2(-120 + index * 120, 120)
		player.position = station.position + Vector2(0, -30)
		await create_timer(0.25).timeout
		bubbles(group, "HUNGRY", product["feed"])
		await capture_animals(station, kind + "-hungry")
		check(station.get_node("Visuals/InteractionPrompt").text == tr("ANIMAL_FEED_PROMPT"), "nearby feed prompt")
		check(player._nearest_interactable() == station, "E targets station independently of animal sales")
		await key(KEY_E)
		check(station.state == "HUNGRY" and not hud.station_panel.visible, "missing feed does not open modal")
		var need_text: String = tr("ANIMAL_NEED_CHICKEN_FEED" if kind == "chicken" else "ANIMAL_NEED_COW_FEED")
		check(hud.floating_feedback.get_children().any(func(label): return label.text == need_text), "missing feed has contextual floating feedback")
		inv.set(product["feed"], 1)
		inv.inventory_changed.emit()
		await key(KEY_E)
		check(station.state == "PRODUCING" and inv.get(product["feed"]) == 0 and not hud.station_panel.visible, "E consumes exactly one feed via existing backend")
		var feed_feedback = hud.floating_feedback.get_child(hud.floating_feedback.get_child_count() - 1)
		check(feed_feedback.get_children().any(func(icon): return icon.get("item_id") == product["feed"]), "feed feedback includes the existing item icon")
		check(is_equal_approx(station.ready_at - station.started_at, product["time"]), "production duration unchanged")
		bubbles(group, "PRODUCING", product["feed"])
		await capture_animals(station, kind + "-producing")
		var saved_deadline: float = station.ready_at
		await key(KEY_E)
		check(station.ready_at == saved_deadline, "E does not restart active production")
		station.ready_at = Time.get_unix_time_from_system() - 1
		station._finish_production()
		bubbles(group, "READY", product["item"])
		await capture_animals(station, kind + "-ready")
		inv.bread = inv.barn_capacity
		var item_before: int = inv.get(product["item"])
		await key(KEY_E)
		check(station.state == "READY" and inv.get(product["item"]) == item_before, "full barn retains ready product")
		check(hud.floating_feedback.get_children().any(func(label): return label.text == tr("FEED_STORAGE_FULL")), "full barn displays compact feedback")
		bubbles(group, "READY", product["item"])
		inv.bread = 0
		var exp_before: int = inv.player_exp
		await key(KEY_E)
		check(inv.get(product["item"]) == item_before + 3 and station.state == "HUNGRY", "E collects existing batch of three products")
		var gain_feedback = hud.floating_feedback.get_child(hud.floating_feedback.get_child_count() - 1)
		check(gain_feedback.get_children().any(func(icon): return icon.get("item_id") == product["item"]), "harvest feedback includes Egg/Milk item icon")
		check(inv.player_exp == exp_before + product["exp"] * 3, "batch EXP unchanged")
		bubbles(group, "HUNGRY", product["feed"])
		var animal = group.animals()[0]
		player.position = animal.get_interaction_position()
		await settle()
		animal.interact(player)
		check(hud.animal_sale_confirmation.visible and hud.pending_sale_animal == animal, "individual animal still opens existing sale confirmation")
		hud.animal_sale_confirmation.hide()
		await settle()
	check(manager.reset_game(), "animal cleanup")

func write_fixture() -> void:
	await prepare()
	await move_checks()
	for kind in ["chicken", "cow"]:
		check(inv.buy_animal(kind), "persistent animal fixture")
		var station = manager.stations["chicken_coop" if kind == "chicken" else "cow_shed"]
		inv.set(kind + "_feed", 1)
		check(station.produce(), "persistent production fixture")
		if kind == "chicken":
			station.ready_at = Time.get_unix_time_from_system() - 1
			station._finish_production()
	check(manager.save_game(), "save market placement and animal states")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	await settle()
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"collision_core": await collision_checks()
		"animal_context": await animal_checks()
		"fixes_write": await write_fixture()
		"fixes_read":
			check(manager.buildings["market_stall"].position == MOVED_STALL and manager.building_positions["market_stall"] == MOVED_STALL, "stall position survives process restart")
			bubbles(farm.animal_groups["chicken"], "READY", "egg")
			bubbles(farm.animal_groups["cow"], "PRODUCING", "cow_feed")
			check(manager.stations["chicken_coop"].collect(), "collect reloaded ready batch")
			check(manager.save_game(), "save derived hungry state")
		"fixes_hungry_read":
			bubbles(farm.animal_groups["chicken"], "HUNGRY", "chicken_feed")
			check(manager.buildings["market_stall"].position == MOVED_STALL, "stall remains moved on another reload")
			check(manager.reset_game(), "read cleanup")
	print("PASS: " + stage)
	quit()
