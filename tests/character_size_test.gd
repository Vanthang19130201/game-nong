extends SceneTree

const Data = preload("res://character_data.gd")
var manager: Node
var farm: Node2D
var player: CharacterBody2D
var sprite: AnimatedSprite2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok, message)

func settle() -> void:
	await process_frame
	await process_frame

func bind_farm() -> void:
	farm = current_scene
	player = farm.get_node("Player")
	sprite = player.get_node("AnimatedSprite2D")

func assert_height(height: float) -> void:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture("idle_down", 0)
	check(is_equal_approx(texture.get_height() * sprite.scale.y, height), "display height matches target " + str(height))
	check(is_equal_approx(sprite.scale.x, sprite.scale.y), "aspect ratio preserved")
	check(player.scale == Vector2.ONE, "player root stays unscaled")
	var used := texture.get_image().get_used_rect()
	var visible_bottom: float = sprite.position.y + (sprite.offset.y + used.end.y - texture.get_height() * 0.5) * sprite.scale.y
	check(is_equal_approx(visible_bottom, player.get_node("CollisionShape2D").position.y), "visible feet/shadow anchored to unchanged collision center")

func wait_farm() -> void:
	for index in range(40):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.name == "Main":
			bind_farm()
			return
	check(false, "transition to farm")

func capture(height: float) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var camera = player.get_node("Camera2D")
	camera.target_zoom = 1.0
	camera.zoom = Vector2.ONE
	camera.begin_pan()
	camera.end_pan()
	camera.pan_center = player.global_position
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(1152, 648), "size preview uses game resolution")
	check(image.save_png("res://player-height-" + str(int(height)) + ".png") == OK, "capture size " + str(height))

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "size_core":
		check(manager.reset_game(), "new-game fixture")
		var menu: Control = load("res://start_menu.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		menu.show_character_select()
		menu.selection.select_character("farmer_03")
		menu.selection.confirm_button.pressed.emit()
		await wait_farm()
		check(sprite.target_character_height == 88.0, "New Game uses default Target Character Height 88")
		assert_height(88.0)
		var collision: CollisionShape2D = player.get_node("CollisionShape2D")
		var original_transform := collision.transform
		var original_shape := collision.shape
		var original_size: Vector2 = collision.shape.size
		var camera: Camera2D = player.get_node("Camera2D")
		var camera_zoom := camera.zoom
		var original_speed: float = player.speed
		player.position = Vector2(800, 800)
		player.set_physics_process(false)
		var first: Dictionary = {}
		for height in [48.0, 72.0, 100.0]:
			sprite.target_character_height = height
			sprite.refresh_character_size()
			for id in Data.CHARACTERS:
				check(manager.set_selected_character(id, false), "wardrobe refresh " + id)
				assert_height(height)
				var fitted := sprite.scale
				for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.ZERO]:
					player.velocity = direction * player.speed
					sprite._process(0.0)
					check(sprite.scale == fitted, "animation process never resets fitted scale")
				check(collision.transform == original_transform and collision.shape == original_shape and collision.shape.size == original_size, "collision unchanged for every skin and height")
				check(player.speed == original_speed and camera.zoom == camera_zoom, "speed and camera unchanged")
				first[str(height)] = sprite.sprite_frames.get_frame_texture("idle_down", 0).get_height() * sprite.scale.y
			check(manager.set_selected_character("farmer_01", false), "capture Farmer 1 consistently")
			player.velocity = Vector2.ZERO
			sprite.facing = "down"
			sprite._process(0.0)
			await capture(height)
		check(float(first["100.0"]) / float(first["48.0"]) > 2.0, "height 100 is visibly over twice height 48")
		# Manual scale is deliberately replaced by target height at a skin refresh.
		sprite.scale = Vector2(99, 11)
		sprite.refresh_character()
		assert_height(100.0)
		# Safely ignore missing, empty and null frame resources.
		var real_frames := sprite.sprite_frames
		var fitted := sprite.scale
		sprite.sprite_frames = null
		sprite.refresh_character_size()
		check(sprite.scale == fitted, "null frames safe")
		var empty := SpriteFrames.new()
		empty.remove_animation("default")
		empty.add_animation("idle_down")
		sprite.sprite_frames = empty
		sprite.refresh_character_size()
		check(sprite.scale == fitted, "empty idle safe")
		empty.add_frame("idle_down", null)
		empty.add_frame("idle_down", real_frames.get_frame_texture("idle_down", 0))
		sprite.target_character_height = 72.0
		sprite.refresh_character_size()
		check(is_equal_approx(sprite.scale.y * empty.get_frame_texture("idle_down", 1).get_height(), 72.0), "uses first valid idle frame")
		sprite.sprite_frames = real_frames
		sprite.refresh_character_size()
		# A higher resolution replacement still fits the same world height.
		var image := real_frames.get_frame_texture("idle_down", 0).get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var high_resolution := SpriteFrames.new()
		high_resolution.add_animation("idle_down")
		high_resolution.add_frame("idle_down", ImageTexture.create_from_image(image))
		sprite.sprite_frames = high_resolution
		sprite.refresh_character_size()
		assert_height(72.0)
		sprite.sprite_frames = real_frames
		sprite.refresh_character_size()
		check(manager.reset_game(), "size fixture reset")
		check(sprite.target_character_height == 88.0, "reset does not change scene presentation setting")
	elif stage == "size_write":
		check(manager.start_new_game("farmer_04"), "save skin for Continue")
		# Change scene configuration only in the isolated project, not in save data.
		var path := "res://main.tscn"
		var text := FileAccess.get_file_as_string(path)
		var backup := FileAccess.open("res://size-scene-backup.txt", FileAccess.WRITE)
		check(backup != null, "backup isolated scene configuration")
		backup.store_string(text)
		backup.close()
		text = text.replace("use_selected_character = true", "use_selected_character = true\ntarget_character_height = 100.0")
		var file := FileAccess.open(path, FileAccess.WRITE)
		check(file != null, "open isolated scene configuration")
		file.store_string(text)
		file.close()
		check(manager.save_game(), "save selected id")
		var data := ConfigFile.new()
		check(data.load(manager.SAVE_PATH) == OK and not data.encode_to_text().contains("target_character_height"), "display height is not saved")
	elif stage == "size_read":
		check(manager.selected_character_id == "farmer_04", "saved character restored")
		var menu: Control = load("res://start_menu.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		menu.continue_button.pressed.emit()
		await wait_farm()
		check(sprite.target_character_height == 100.0, "Continue retains configured scene height instead of resetting to a saved value")
		assert_height(100.0)
		check(manager.set_selected_character("farmer_01"), "switch selected appearance after Continue")
		assert_height(100.0)
		check(manager.reset_game(), "read cleanup")
		assert_height(100.0)
		var scene_file := FileAccess.open("res://main.tscn", FileAccess.WRITE)
		check(scene_file != null, "restore isolated scene configuration")
		scene_file.store_string(FileAccess.get_file_as_string("res://size-scene-backup.txt"))
		scene_file.close()
	print("PASS: " + stage)
	quit()
