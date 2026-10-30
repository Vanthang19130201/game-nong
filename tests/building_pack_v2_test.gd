extends SceneTree

const Art = preload("res://building_art_v2.gd")
var placement: GDScript
const IDS: Array[String] = ["house", "feed_mill", "bakery", "spinning_machine", "cow_shed", "chicken_coop", "pig_pen", "sheep_barn", "market_stall"]
const BODIES: Dictionary = {
	"house": Vector2(150,64), "feed_mill": Vector2(88,34), "bakery": Vector2(108,42),
	"spinning_machine": Vector2(96,28), "cow_shed": Vector2(148,48), "chicken_coop": Vector2(98,38),
	"pig_pen": Vector2(132,44), "sheep_barn": Vector2(136,46), "market_stall": Vector2(112,32),
}
var farm: Node2D
var inv: Node
var manager: Node
var hud: Node
var player: CharacterBody2D
var assertions: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)


func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func sprite_for(building: Node2D, id: String) -> Sprite2D:
	return building.get_node("Visuals/HouseSprite" if id == "house" else "Visuals/BuildingSprite") as Sprite2D


func check_art() -> void:
	for id in IDS:
		check(manager.buildings.has(id), "existing saved ID registered: " + id)
		var building: Node2D = manager.buildings[id]
		var sprite := sprite_for(building, id)
		check(building.name == manager.FarmData.BUILDINGS[id]["node"], "node name unchanged: " + id)
		check(building.scale == Vector2.ONE, "root is unscaled: " + id)
		check(sprite.texture == Art.texture_for(id), "world uses uploaded artwork: " + id)
		check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest sampling: " + id)
		check(sprite.scale.x > 0 and is_equal_approx(sprite.scale.x, sprite.scale.y), "uniform visual scale: " + id)
		check(sprite.region_rect == Art.ENTRIES[id]["region"], "no artwork clipped: " + id)
		var rect: Rect2 = sprite.transform * sprite.get_rect()
		check(is_equal_approx(rect.end.y, float(Art.ENTRIES[id]["ground"])), "ground baseline: " + id)
		var target: Vector2 = Art.ENTRIES[id]["size"]
		check(rect.size.x <= target.x + 0.01 and rect.size.y <= target.y + 0.01, "visual fits old world scale: " + id)
		check(building.get_node("Body/CollisionShape2D").shape.size == BODIES[id], "physical collision unchanged: " + id)
		var image: Image = sprite.texture.get_image()
		check(image.get_pixel(0,0).a == 0.0, "exterior backdrop transparent: " + id)
		check(building.find_children("*", "Sprite2D", true, false).size() == 1, "one main sprite: " + id)
		var before: Vector2 = building.position
		var state: Dictionary = building.get_save_data().duplicate(true) if building.has_method("get_save_data") else {}
		var preview: Node2D = placement.create_preview(building)
		farm.add_child(preview)
		var copies: Array = preview.find_children("*", "Sprite2D", true, false)
		check(copies.size() == 1, "edit ghost has one sprite: " + id)
		var copy: Sprite2D = copies[0]
		check(copy.texture == sprite.texture and copy.offset == sprite.offset and copy.region_rect == sprite.region_rect, "edit ghost shares new artwork/baseline: " + id)
		check(copy.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "edit ghost preserves nearest: " + id)
		preview.free()
		check(building.position == before, "visual leaves world position untouched: " + id)
		if building.has_method("get_save_data"):
			check(building.get_save_data() == state, "presentation preserves production state: " + id)
		var icon: Control = load("res://item_icon.gd").new()
		icon.item_id = id
		icon.size = Vector2(64,64)
		root.add_child(icon)
		check(icon._visual_texture == Art.thumbnail_for(id), "shop thumbnail matches world: " + id)
		icon.free()
		print("VISUAL ", id, " scale=", sprite.scale, " position=", sprite.position, " offset=", sprite.offset)
	check(Art.thumbnail_for("loom") != null, "Loom uploaded art prepared for existing icon data")
	if not ResourceLoader.exists("res://loom.tscn"):
		print("SKIP: Loom world interaction/production; original project has no loom.tscn/controller")
	check(farm.get_node("DogHouse/Visuals/BuildingSprite").texture.resource_path.find("/v2/") == -1, "Dog House artwork unchanged")


func interactions() -> void:
	player.set_physics_process(false)
	for id in IDS:
		var building: Node2D = manager.buildings[id]
		hud.close_all_panels()
		var shape: CollisionShape2D = building.get_node("Body/CollisionShape2D")
		var bounds: Rect2 = shape.global_transform * shape.shape.get_rect()
		var depth: Node = farm.get_node("WorldDepth")
		depth._apply_depth(building)
		player.global_position = Vector2(bounds.get_center().x, bounds.position.y - 40.0)
		depth._apply_depth(player)
		check(player.z_index < building.z_index, "player behind building keeps lower depth: " + id)
		player.global_position = Vector2(bounds.get_center().x, bounds.end.y + 36.0)
		depth._apply_depth(player)
		check(player.z_index > building.z_index, "player in front keeps higher depth: " + id)
		await settle()
		var hit := player.move_and_collide(Vector2(0, -bounds.size.y - 100.0))
		check(hit != null and hit.get_collider() == building.get_node("Body"), "player blocked by existing lower body: " + id)
		player.global_position = Vector2(bounds.get_center().x, bounds.end.y + 28.0)
		await settle()
		check(building.can_interact(), "interaction reachable: " + id)
		building.interact(player)
		if id not in ["cow_shed", "chicken_coop", "pig_pen", "sheep_barn"]:
			check(hud.blocks_world_input(), "existing panel opens: " + id)
		hud.close_all_panels()
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)


func edit_check() -> void:
	var building: Node2D = manager.buildings["spinning_machine"]
	var destination := Vector2.ZERO
	for y in range(256, 2100, 64):
		for x in range(128, 1700, 64):
			var point := Vector2(x,y)
			if placement.can_place(building, point):
				destination = point
				break
		if destination != Vector2.ZERO:
			break
	check(destination != Vector2.ZERO, "existing footprint has a valid move destination")
	var editor: Node = hud.edit_farm
	editor.enter_mode()
	editor.select_building(building)
	editor.begin_move()
	editor.update_preview(destination)
	check(editor.valid_position and editor.place_move(), "real edit-mode move commits with existing footprint")
	check(building.global_position == destination, "new visual follows committed move")
	editor.exit_mode()


func production_checks() -> void:
	inv.wheat = 12
	inv.corn = 12
	var mill: Node = manager.buildings["feed_mill"]
	var before: int = inv.chicken_feed
	check(mill.produce("chicken_feed"), "Feed Mill accepts existing recipe")
	mill.ready_at = Time.get_unix_time_from_system() - 1.0
	mill._finish_production()
	check(mill.collect_all() and inv.chicken_feed == before + 1, "Feed Mill delivers exactly one output")
	var spinner: Node = manager.buildings["spinning_machine"]
	inv.cotton = 6
	before = inv.cotton_thread
	check(spinner.enqueue("cotton_thread"), "Spinning Machine accepts existing recipe")
	for job in manager.spinning_machine_queue:
		job["ready_at"] = Time.get_unix_time_from_system() - 1.0
	spinner.refresh()
	check(spinner.collect() and inv.cotton_thread == before + 1, "Spinning Machine output unchanged")


func capture_buildings() -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var camera = player.get_node("Camera2D")
	camera.target_zoom = 1.0
	camera.zoom = Vector2.ONE
	camera.begin_pan()
	for id in IDS:
		camera.pan_center = manager.buildings[id].global_position
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://building-v2-" + id + ".png") == OK, "rendered screenshot: " + id)


func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	placement = load("res://building_placement.gd")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "v2_legacy_prepare":
		var legacy := ConfigFile.new()
		check(legacy.load(manager.SAVE_PATH) == OK, "read isolated legacy fixture")
		legacy.set_value("game", "version", 17)
		check(legacy.save(manager.SAVE_PATH) == OK, "save version-17 fixture for a fresh process")
		print("PASS: v2_legacy_prepare")
		quit(0)
		return
	if stage == "v2_write":
		check(manager.reset_game(), "reset isolated fixture")
		inv.player_level = 20
		inv.last_rewarded_level = 20
		inv.tools_unlock_notified = true
		inv.coins = 100000
		manager.unlocked_land_zones.assign(manager.LandData.ZONES.keys())
		for id in IDS:
			if id not in ["house", "market_stall"]:
				inv.set("owns_" + id, true)
		# Deliberately old-style saved data: no artwork fields or new save version.
		check(manager.save_game(), "save pre-visual-upgrade fixture")
	elif stage == "v2_read":
		check(inv.player_level == 20 and inv.coins == 100000, "saved progress restored before scene load")
		check(not manager.bakery_queue.is_empty() and manager.bakery_queue[0]["item"] == "bread", "production queue survives process restart")
	var saved_positions: Dictionary = manager.building_positions.duplicate()
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	await settle()
	for id in IDS:
		check(manager.buildings[id].position == saved_positions[id], "saved world anchor preserved on load: " + id)
	check_art()
	await interactions()
	edit_check()
	production_checks()
	var merchant: Node = root.get_node("FarmEventManager")
	var point: Vector2 = merchant._choose_merchant_position()
	check(point != Vector2.ZERO and point.distance_to(farm.get_node("OrderBoard").global_position) < 240.0, "merchant retains existing Order Board anchor")
	var bakery: Node2D = manager.buildings["bakery"]
	inv.wheat = 8
	check(bakery.enqueue("bread"), "Bakery production still starts")
	var queued: Array = manager.bakery_queue.duplicate(true)
	check(manager.save_game(), "save active production with new artwork")
	check(manager.bakery_queue == queued, "saving preserves active production")
	await capture_buildings()
	print("PASS: ", stage, " (", assertions, " checks; 9 world buildings + 10 icon mappings; Loom world scene absent before patch)")
	current_scene = null
	farm.queue_free()
	await process_frame
	await process_frame
	quit(0)
