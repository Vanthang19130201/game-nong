extends SceneTree

var inv: Node
var manager: Node
var farm: Node2D
var player: Node2D
var hud: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func check_art(sprite: Sprite2D, id: String) -> void:
	check(sprite.texture != null and sprite.texture.resource_path.ends_with("/" + id + ".svg"), "world SVG loaded " + id)
	check(is_equal_approx(sprite.scale.x, sprite.scale.y), "uniform artwork scale " + id)
	for path in sprite.fallback_paths:
		var fallback := sprite.get_node_or_null(path)
		check(fallback is CanvasItem and not fallback.visible, "old placeholder exists and is hidden " + id)
	var image := sprite.texture.get_image()
	check(image.get_pixel(0, 0).a == 0.0, "SVG has a transparent background " + id)

func check_label(sprite: Sprite2D, label: Label, name: String) -> void:
	var image := sprite.texture.get_image()
	var used := image.get_used_rect()
	var visible_art := Rect2(Vector2(used.position) - Vector2(image.get_size()) * 0.5, Vector2(used.size))
	visible_art = sprite.transform * visible_art
	var gap := visible_art.position.y - label.get_rect().end.y
	check(gap >= 8.0 and gap <= 16.0, "local label sits 8-16 px above visible artwork " + name + " gap=" + str(gap))
	check(absf(label.get_rect().get_center().x - visible_art.get_center().x) <= 3.0, "label is centered on artwork " + name)
	check(label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "label stays attached without blocking interaction " + name)

func capture_map(name: String, center: Vector2, zoom: float = 1.0) -> void:
	var camera = player.get_node("Camera2D")
	camera.target_zoom = zoom
	camera.zoom = Vector2.ONE * zoom
	camera.begin_pan()
	camera.end_pan()
	camera.pan_center = center
	hud.floating_feedback.clear()
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(1152, 648), "map capture uses current game resolution")
	check(image.save_png("res://map-polish-" + name + ".png") == OK, "save map capture " + name)

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	check(manager.reset_game(), "reset fixture")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	player = farm.get_node("Player")
	hud = farm.get_node("HUD")
	await create_timer(0.15).timeout
	var warehouse: Area2D = farm.get_node("Warehouse")
	check(warehouse.position == Vector2(920, 260), "new farm Warehouse is near the main house")
	check_art(warehouse.get_node("Visuals/BuildingSprite"), "warehouse")
	check_art(farm.get_node("FishMarket/Visuals/BuildingSprite"), "fish_market")
	check(not farm.get_node("FishingSpot/Visuals/FishingSprite").visible, "fishing controller has no fixed rod artwork")
	check_art(farm.get_node("Bridge/Visuals/Sprite2D"), "fishing_bridge")
	check_art(farm.get_node("River/Visuals/RiverSprite"), "river")
	var home: Node2D = farm.get_node("DogHouse")
	check(home.visible and not inv.has_dog_house and not is_instance_valid(farm.dog), "Dog House is visible without unlocking ownership or spawning a dog")
	inv.inventory_changed.emit()
	check(home.visible and not inv.has_dog_house, "inventory refresh does not hide the Dog House or grant it")
	check(home.position == Vector2(550, 700) and home.position.distance_to(farm.get_node("DogHomePoint").position) == 50.0, "dog home marker sits at the end of the path in front of the existing house")
	check_art(home.get_node("Visuals/BuildingSprite"), "dog_house")
	check_label(warehouse.get_node("Visuals/BuildingSprite"), warehouse.get_node("Visuals/NameLabel"), "Warehouse")
	check_label(home.get_node("Visuals/BuildingSprite"), home.get_node("Label"), "Dog House")
	check_label(farm.get_node("Bridge/Visuals/Sprite2D"), farm.get_node("Bridge/Sign"), "Fishing Bridge")
	check(not farm.get_node("FishingSpot/Label").visible, "old dock has no permanent fishing prompt")
	check(farm.get_node("FishingSpot").position == Vector2.ZERO and farm.get_node("FishingSpot/CollisionShape2D").disabled, "single fishing manager is hidden from the world layout")
	check(farm.get_node("RiverRestDeck").position == Vector2(1980, 1020) and farm.get_node("PondRestDeck").position == Vector2(2048, 1450), "two separate decorative decks align with their banks")
	check(not farm.get_node("FishingAreaLabel").visible and farm.get_node("Bridge/Sign").visible, "fishing area uses one heading attached to its bridge")
	check(farm.get_node("Landscape").get_script().resource_path == "res://farm_landscape.gd", "static paths and quarry terrain exist")
	check(manager.resources.size() == 12 and manager.plots.size() == 32, "original resource IDs and crop plots preserved")
	var rocks: int = 0
	for resource in manager.resources.values():
		if resource.resource_type != "stone":
			continue
		rocks += 1
		check(Rect2(180, 900, 400, 540).has_point(resource.global_position), "mineable rock lies in the west quarry " + resource.resource_id)
		check(resource.get_parent() == farm and resource.scale == Vector2.ONE, "rock is full size above terrain " + resource.resource_id)
		check(resource.visible and resource.zone_active and farm.Placement.can_place(resource, resource.global_position, false), "rock avoids crops, buildings, water and locked land " + resource.resource_id)
		check(not farm.Placement.bounds(resource).has_point(player.global_position), "rock avoids player spawn")
		var sprite: Sprite2D = resource.get_node("Visuals/ResourceSprite")
		check(sprite.texture != null and sprite.texture.resource_path.contains("/rocks/"), "rock has dedicated artwork")
		check(not resource.get_node("Visual").visible and is_equal_approx(sprite.scale.x, sprite.scale.y), "rock placeholder hidden without stretching")
	check(rocks == 4, "four existing mineable rocks retained")
	if "--capture" in OS.get_cmdline_user_args():
		await capture_map("warehouse", warehouse.global_position)
		await capture_map("dog-house", home.global_position)
		await capture_map("quarry", Vector2(886, 1100), 0.65)
		await capture_map("fishing-locked", Vector2(2050, 950))
	var storage: Control = hud.storage_panel
	player.global_position = warehouse.global_position + Vector2(0, 90)
	await create_timer(0.12).timeout
	await key(KEY_E)
	check(storage.visible and hud.storage_panel == storage and not hud.house_panel.visible, "E opens the existing Warehouse storage panel")
	await key(KEY_ESCAPE)
	inv.player_level = 9
	inv.inventory_changed.emit()
	player.position = Vector2(1740, 850)
	await create_timer(0.12).timeout
	check(not farm.get_node("Bridge/Blocker/CollisionShape2D").disabled, "existing fishing gate stays locked before level 10")
	Input.action_press("move_right")
	await create_timer(0.7).timeout
	Input.action_release("move_right")
	check(player.position.x < 1800, "locked bridge blocks passage")
	inv.player_level = 10
	inv.fishing_unlocked = true
	inv.has_fishing_rod = true
	inv.fishing_rod_level = 1
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	inv.inventory_changed.emit()
	await create_timer(0.12).timeout
	check(farm.get_node("Bridge/Blocker/CollisionShape2D").disabled and not farm.get_node("Bridge/Gate").visible, "existing unlock removes bridge gate")
	Input.action_press("move_right")
	await create_timer(1.4).timeout
	Input.action_release("move_right")
	check(player.position.x > 1960, "player crosses the wooden bridge without getting stuck")
	var spot: Area2D = farm.get_node("FishingSpot")
	player.global_position = spot.global_position
	player.facing_vector = Vector2.RIGHT
	hud.hotbar.select_slot(7)
	await create_timer(0.15).timeout
	if "--capture" in OS.get_cmdline_user_args():
		await capture_map("fishing-ready", Vector2(2050, 950))
	var fish_before: int = inv.small_fish + inv.river_fish + inv.golden_fish
	await key(KEY_E)
	check(spot.state == spot.State.WAITING_FOR_BITE and hud.fishing_ui.active_spot == spot, "E at the dock starts the existing fishing session")
	spot.deadline = spot.now() - 0.01
	spot._advance_state()
	await key(KEY_SPACE)
	check(spot.state == spot.State.SUCCESS and inv.small_fish + inv.river_fish + inv.golden_fish == fish_before + 1, "existing fishing reaction grants one fish")
	spot.cancel_session()
	var market: Area2D = farm.get_node("FishMarket")
	player.global_position = market.global_position
	await create_timer(0.15).timeout
	await key(KEY_E)
	check(hud.fish_market_panel.visible and hud.fish_market_panel.active_market == market, "E opens existing fish sale panel")
	await key(KEY_ESCAPE)
	if "--capture" in OS.get_cmdline_user_args():
		await capture_map("fishing-open", Vector2(2050, 950))
	var rock: Area2D = manager.resources["rock_1"]
	player.global_position = rock.global_position
	await create_timer(0.15).timeout
	var stone_before: int = inv.stone
	var expected: Dictionary = rock.RockData.TYPES[rock.rock_type]
	await key(KEY_E)
	check(rock.state == "GATHERING", "E starts existing Hammer mining")
	rock.harvest_timer.stop()
	rock._finish_harvest()
	check(inv.stone - stone_before >= expected["min_stone"] and inv.stone - stone_before <= expected["max_stone"], "mining preserves Stone rewards")
	check(rock.state == "DEPLETED" and rock.get_node("Visuals/ResourceSprite").texture.resource_path.ends_with("rock_rubble.svg"), "depleted rock displays rubble")
	inv.wood = 5
	inv.coins = 300
	check(inv.build_dog_house() and inv.buy_dog(), "existing Dog House and Dog purchases work")
	await create_timer(0.12).timeout
	check_art(home.get_node("Visuals/BuildingSprite"), "dog_house")
	check(home.visible and is_instance_valid(farm.dog) and farm.dog.home_point == home, "dog uses the same home object")
	check(farm.find_children("DogHouse", "Node2D", true, false).size() == 1, "exactly one Dog House")
	var relocated: Area2D = manager.resources["rock_2"]
	var old_position := relocated.global_position
	var old_data: Dictionary = relocated.get_save_data().duplicate(true)
	player.global_position = old_position
	farm._place_resources()
	check(relocated.global_position != old_position and farm._resource_position_is_clear(relocated, relocated.global_position), "restored player position is protected from resource overlap")
	check(relocated.get_save_data() == old_data, "safe resource relocation preserves its type and cooldown")
	check(manager.save_game(), "existing save accepts the completed world")
	check(manager.reset_game(), "cleanup isolated fixture")
	check(home.visible and not inv.has_dog_house and not is_instance_valid(farm.dog), "reset keeps the visual house without changing ownership or dog lifecycle")
	print("PASS: world_presence (Warehouse, quarry, fishing, bridge traversal, Fish Market and Dog House)")
	quit()
