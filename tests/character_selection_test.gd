extends SceneTree

const Data = preload("res://character_data.gd")
var manager: Node
var inv: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok, message)

func disk() -> ConfigFile:
	var result := ConfigFile.new()
	check(result.load(manager.SAVE_PATH) == OK, "isolated save readable")
	return result

func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(1152, 648), "capture resolution")
	check(image.save_png("res://character-" + name + ".png") == OK, "capture " + name)

func wait_scene(name: String) -> void:
	for index in range(30):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == name:
			return
	check(false, "scene transition to " + name)

func menu() -> Control:
	var node: Control = load("res://start_menu.tscn").instantiate()
	root.add_child(node)
	current_scene = node
	await process_frame
	return node

func check_characters() -> void:
	check(Data.CHARACTERS.size() == 4, "four cosmetic choices")
	for id in Data.CHARACTERS:
		var frames := Data.frames_for(id)
		check(Data.complete(frames), "complete directional frames " + id)
		check(frames == Data.frames_for(id), "frames are cached " + id)
		for name in Data.ANIMATIONS:
			var expected_count: int = 6 if id == "farmer_01" else (4 if name.begins_with("walk") else 1)
			check(frames.get_frame_count(name) == expected_count, "idle/walk frame counts " + id + name)
		var first := frames.get_frame_texture("idle_down", 0)
		var png_path: String = "res://assets/characters/" + id + "/character.png"
		var expected_path: String = "res://assets/characters/farmer_01/player1/player1_idle_down.png" if id == "farmer_01" else (png_path if ResourceLoader.exists(png_path) else "res://assets/characters/" + id + "/character.svg")
		check(first is AtlasTexture and first.atlas.resource_path == expected_path, "distinct character artwork " + id)
		check(first.atlas.get_image().get_pixel(0, 0).a == 0.0, "transparent sheet " + id)
		if id == "farmer_01":
			check(first.region == Rect2(0, 0, 362, 724), "Player 1 uses the fixed first 362x724 cell")
			for name in Data.ANIMATIONS:
				check(is_equal_approx(frames.get_animation_speed(name), 8.0 if name.begins_with("walk") else 3.0), "Player 1 animation FPS " + name)
				for frame_index in range(6):
					var frame: AtlasTexture = frames.get_frame_texture(name, frame_index) as AtlasTexture
					check(frame != null and frame.region == Rect2(frame_index * 362, 0, 362, 724), "Player 1 fixed grid cell " + name + str(frame_index))
	check(Data.valid_id(42) == "farmer_01" and Data.valid_id("bad_id") == "farmer_01", "invalid ids use default")
	check(Data.complete(Data.fallback_frames()), "neutral fallback supports every direction")
	check(Data._read_frames("res://__missing_character_frames__.tres") == null, "missing frame resource is rejected safely")
	check(Data._read_frames("res://assets/characters/directional_frames.tres") == null, "empty legacy resource is rejected safely")

func visual_checks(farm: Node) -> void:
	var player: CharacterBody2D = farm.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var speed: float = player.speed
	var size: Vector2 = shape.shape.size
	var position: Vector2 = shape.position
	var mask: int = player.collision_mask
	var camera: Camera2D = player.get_node("Camera2D")
	inv.has_dog_house = true
	inv.coins = 500
	check(inv.buy_dog(), "dog visual fixture")
	var dog_sprite: Sprite2D = farm.dog.get_node("DogVisual/Sprite")
	var dog_texture := dog_sprite.texture
	player.set_physics_process(false)
	for id in Data.CHARACTERS:
		check(manager.set_selected_character(id, false), "apply selected visual " + id)
		check(sprite.sprite_frames == Data.frames_for(id), "visual refreshes from selected character signal " + id)
		for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			var facing: String = "down" if direction == Vector2.DOWN else ("up" if direction == Vector2.UP else ("left" if direction == Vector2.LEFT else "right"))
			player.velocity = direction * speed
			sprite._process(0.0)
			check(sprite.animation == "walk_" + facing and sprite.is_playing() and sprite.visible, "walk animation " + id + facing)
			player.velocity = Vector2.ZERO
			sprite._process(0.0)
			check(sprite.animation == "idle_" + facing and sprite.is_playing(), "idle keeps last facing " + id + facing)
		check(player.speed == speed and shape.shape.size == size and shape.position == position and player.collision_mask == mask, "appearance preserves speed and collision " + id)
		check(camera.get_parent() == player, "same player camera " + id)
		check(dog_sprite.texture == dog_texture and dog_sprite.texture != Data.frames_for(id).get_frame_texture("idle_down", 0), "dog never inherits the selected farmer " + id)
	check(not player.get_node("Icon").visible, "legacy placeholder hidden")
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)

func movement_checks(farm: Node) -> void:
	var player: CharacterBody2D = farm.get_node("Player")
	var hud: Node = farm.get_node("HUD")
	var board: Node2D = farm.get_node("OrderBoard")
	for id in Data.CHARACTERS:
		check(manager.set_selected_character(id, false), "apply cosmetic for movement " + id)
		player.position = Vector2(800, 800)
		await physics_frame
		var before := player.position
		Input.action_press("move_right")
		await create_timer(0.12).timeout
		Input.action_release("move_right")
		check(player.position.x > before.x + 12 and player.position.x < before.x + 40, "same controller moves each character at existing speed " + id)
		player.position = board.position + Vector2(0, 56)
		await create_timer(0.1).timeout
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = true
		root.push_input(event, true)
		await process_frame
		event = InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		root.push_input(event, true)
		await process_frame
		check(hud.order_panel.visible, "E interaction works for each appearance " + id)
		hud.close_all_panels()

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "never use real user save")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"character_core":
			check(manager.reset_game(), "new-game fixture")
			check_characters()
			var start: Control = await menu()
			var before := disk().encode_to_text()
			start.show_character_select()
			check(current_scene == start and get_first_node_in_group("farm_player") == null, "New Game stays in selection before farm exists")
			check(start.selection.cards.size() == 4, "four selectable cards")
			start.selection.select_character("farmer_03")
			check(start.selection.cards["farmer_03"].button_pressed and start.selection.preview.sprite_frames == Data.frames_for("farmer_03"), "selected card and live preview use same frames")
			check(disk().encode_to_text() == before, "preview selection does not reset/save progress")
			await capture("select-farmer-03")
			start.selection.cancelled.emit()
			check(start.menu.visible and not start.selection.visible, "cancel returns without altering save")
			start.show_character_select()
			start.selection.select_character("farmer_03")
			start.selection.name_input.text = "Test Farmer"
			start.selection.confirm_button.pressed.emit()
			await wait_scene("Main")
			check(manager.selected_character_id == "farmer_03" and not manager.character_selection_pending, "confirmed Farmer 3 starts farm")
			check(disk().get_value("player", "selected_character_id") == "farmer_03", "saved character field")
			var farm: Node = current_scene
			await create_timer(0.1).timeout
			await capture("farm-farmer-03")
			visual_checks(farm)
			await movement_checks(farm)
			check(manager.set_selected_character("bad-id", false) and manager.selected_character_id == "farmer_01", "wardrobe setter validates id")
			check(manager.reset_game() and manager.selected_character_id == "farmer_01", "reset restores Farmer 1")
			check(farm.get_node("Player/AnimatedSprite2D").sprite_frames == Data.frames_for("farmer_01"), "reset refreshes player immediately")
		"character_write":
			check(manager.start_new_game("farmer_03"), "create Farmer 3 save")
			inv.coins = 4321
			check(manager.save_game(), "save chosen character and existing inventory")
		"character_read":
			check(manager.selected_character_id == "farmer_03" and inv.coins == 4321, "character and inventory survive process restart")
			var start: Control = await menu()
			check(not start.continue_button.disabled and start.selection == null, "Continue available without selection")
			start.continue_button.pressed.emit()
			await wait_scene("Main")
			check(current_scene.get_node("Player/AnimatedSprite2D").sprite_frames == Data.frames_for("farmer_03"), "Continue directly restores saved frames")
			check(manager.reset_game(), "read cleanup")
		"character_legacy_write", "character_invalid_write":
			check(manager.start_new_game("farmer_03"), "migration fixture")
			inv.coins = 765
			check(manager.save_game(), "migration save")
			manager.autosave_timer.stop()
			inv.inventory_changed.disconnect(manager.save_game)
			var data := disk()
			if stage == "character_legacy_write":
				data.erase_section_key("player", "selected_character_id")
			else:
				data.set_value("player", "selected_character_id", {"invalid": true})
			check(data.save(manager.SAVE_PATH) == OK, "write missing/invalid character fixture")
		"character_legacy_read", "character_invalid_read":
			check(manager.selected_character_id == "farmer_01" and inv.coins == 765, "missing/invalid selection defaults without losing progress")
			check(manager.has_existing_game, "legacy progress still offers Continue")
			check(manager.reset_game(), "migration cleanup")
		"character_fresh":
			check(manager.character_selection_pending and not manager.has_existing_game, "fresh/abandoned launch requires selection")
			var start: Control = await menu()
			check(start.continue_button.disabled, "fresh game cannot bypass selection through Continue")
		"character_png_prepare":
			var atlas: AtlasTexture = Data.frames_for("farmer_02").get_frame_texture("idle_down", 0)
			var image := atlas.atlas.get_image()
			image.resize(288, 512, Image.INTERPOLATE_NEAREST)
			check(image.save_png("res://assets/characters/farmer_02/character.png") == OK, "prepare replacement PNG in isolated copy")
		"character_png":
			var frames := Data.frames_for("farmer_02")
			check(Data.complete(frames), "PNG retains all animations")
			for animation in Data.ANIMATIONS:
				var atlas: AtlasTexture = frames.get_frame_texture(animation, 0)
				check(atlas.atlas.resource_path.ends_with("farmer_02/character.png") and atlas.region.size == Vector2(96,128), "PNG replaces SVG with normalized atlas coordinates")
		"character_missing":
			for id in ["farmer_04"]:
				var path: String = Data.CHARACTERS[id]["frames"]
				var backup := path + ".testbackup"
				check(DirAccess.rename_absolute(path, backup) == OK, "temporarily remove frames in isolated project")
				Data._cache.clear()
				var frames := Data.frames_for(id)
				var restored := DirAccess.rename_absolute(backup, path)
				check(restored == OK and Data.complete(frames), "missing character frames resolve to complete fallback " + id)
			Data._cache.erase("farmer_01")
			var player_one_frames := Data.frames_for("farmer_01")
			check(Data.complete(player_one_frames) and player_one_frames.get_frame_count("walk_down") == 6, "Player 1 supplied strips remain complete after cache refresh")
			Data._cache.clear()
	print("PASS: " + stage)
	quit()
