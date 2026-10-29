extends SceneTree

const DogData = preload("res://dog_data.gd")
const DOG_SCENE = preload("res://dog.tscn")
const LandData = preload("res://land_data.gd")

var manager: Node
var inventory: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok, message)

func save_data() -> ConfigFile:
	var config := ConfigFile.new()
	check(config.load(manager.SAVE_PATH) == OK, "pet fixture save is readable")
	return config

func set_hunger(pet_id: String, value: float) -> void:
	var profile: Dictionary = manager.pet_dogs[pet_id]
	profile["hunger"] = value
	manager.pet_dogs[pet_id] = profile


func distinct_atlas_regions(frames: SpriteFrames, animation_name: StringName) -> int:
	var regions: Array[Rect2] = []
	for frame_index in range(frames.get_frame_count(animation_name)):
		var frame_texture := frames.get_frame_texture(animation_name, frame_index)
		if not frame_texture is AtlasTexture:
			return 0
		var region := (frame_texture as AtlasTexture).region
		if not regions.has(region):
			regions.append(region)
	return regions.size()


func effective_frame_anchor(sprite: AnimatedSprite2D, variant_id: String) -> Vector2:
	if DogData.uses_strip_system(variant_id):
		var strip_size := DogData.strip_frame_size_for_variant(variant_id)
		var strip_anchor := Vector2(strip_size.x * 0.5, DogData.strip_ground_y_for_variant(variant_id))
		var strip_center := Vector2(strip_size.x * 0.5, strip_size.y * 0.5)
		return sprite.position + (sprite.offset + strip_anchor - strip_center) * sprite.scale
	var sheet := DogData.visual_sheet_for_variant(variant_id)
	var data: Dictionary = DogData.DOG_VARIANTS[variant_id]
	var source_cell := DogData.cell_for_animation_frame(variant_id, sprite.animation, sprite.frame)
	var source_anchor := DogData.cell_anchor_for_variant(variant_id, source_cell)
	var cell_center := Vector2(float(sheet.get_width()) / int(data["sheet_columns"]) * 0.5, float(sheet.get_height()) / int(data["sheet_rows"]) * 0.5)
	return sprite.position + (sprite.offset + source_anchor - cell_center) * sprite.scale


func check_strip_safe(variant_id: String, path: String, animation_name: String, frame_count: int) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	check(file != null, "%s strip source opens for border validation: %s" % [variant_id.capitalize(), animation_name])
	if file == null:
		return
	var image := Image.new()
	check(image.load_png_from_buffer(file.get_buffer(file.get_length())) == OK and not image.is_empty(), "%s strip source loads for border validation: %s" % [variant_id.capitalize(), animation_name])
	if image.is_empty():
		return
	var size := DogData.strip_frame_size_for_variant(variant_id)
	var margin := DogData.CREAM_STRIP_SAFE_MARGIN if variant_id == "cream" else DogData.SHIBA_STRIP_SAFE_MARGIN
	for frame_index in range(frame_count):
		var min_x := size.x
		var min_y := size.y
		var max_x := -1
		var max_y := -1
		for y in range(size.y):
			for x in range(size.x):
				if image.get_pixel(frame_index * size.x + x, y).a > 0.10:
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
		check(max_x >= 0 and min_x >= margin and min_y >= margin and max_x < size.x - margin and max_y < size.y - margin, "%s animation frame is cropped: %s/%d" % [variant_id.capitalize(), animation_name, frame_index])

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inventory = root.get_node("Inventory")
	check(manager.reset_game(), "pet reset fixture")
	inventory.coins = 100_000
	check(not manager.adopt_dog("shiba"), "cannot adopt without Dog House")
	inventory.has_dog_house = true
	check(not manager.adopt_dog("shiba") and not manager.adopt_dog("cream") and not manager.adopt_dog("blacktan"), "level 1 cannot bypass dog unlocks even with coins")
	inventory.player_level = 3
	inventory.coins = 349
	check(not manager.adopt_dog("shiba") and inventory.coins == 349, "Shiba rejects 349 coins")
	inventory.coins = 350
	check(manager.adopt_dog("shiba") and inventory.coins == 0, "Shiba costs exactly 350 at level 3")
	check(not manager.adopt_dog("shiba") and inventory.coins == 0 and manager.pet_dogs.size() == 1, "double adoption charges once and creates one profile")
	check(not manager.adopt_dog("cream"), "Cream remains level locked at level 3")
	inventory.player_level = 6
	inventory.coins = 450
	check(manager.adopt_dog("cream") and inventory.coins == 0, "Cream costs exactly 450 at level 6")
	inventory.player_level = 10
	inventory.coins = 550
	check(manager.adopt_dog("blacktan") and inventory.coins == 0, "Black Tan costs exactly 550 at level 10")
	check(manager.pet_dogs.size() == 3 and inventory.has_dog, "three independent owned pet profiles")
	check(not manager.adopt_dog("shiba"), "duplicate variant rejected")
	check(manager.dog_profile("dog_shiba").get("variant") == "shiba", "Shiba identity persists")
	check(manager.dog_profile("dog_cream").get("variant") == "cream", "Cream identity persists")
	check(manager.dog_profile("dog_blacktan").get("variant") == "blacktan", "Black Tan identity persists")
	check(manager.rename_dog("dog_shiba", "  Mít  "), "rename accepts Vietnamese")
	check(manager.dog_profile("dog_shiba").get("name") == "Mít", "name is trimmed")
	check(not manager.rename_dog("dog_cream", "  \n\t "), "empty name rejected")
	check(ResourceLoader.exists("res://assets/animals/dogs/shiba.png"), "Shiba asset found")
	check(ResourceLoader.exists("res://assets/animals/dogs/cream.png"), "Cream asset found")
	check(ResourceLoader.exists("res://assets/animals/dogs/blacktan.png"), "Black Tan asset found")
	check(DogData.texture_for_variant("shiba") != null and DogData.texture_for_variant("cream") != null and DogData.texture_for_variant("blacktan") != null, "all dog textures load safely")
	set_hunger("dog_shiba", 20.0)
	var original_barn_capacity: int = inventory.barn_capacity
	inventory.barn_capacity = inventory.storage_used("barn")
	var coins_before_full_barn: int = inventory.coins
	check(not manager.buy_dog_food() and inventory.coins == coins_before_full_barn, "full Barn rejects Dog Food without charging coins")
	inventory.barn_capacity = original_barn_capacity
	inventory.coins = 100
	inventory.barn_capacity = inventory.storage_used("barn") + 4
	check(not manager.buy_dog_food(5) and inventory.coins == 100 and inventory.dog_food == 0, "Buy 5 rejects atomically with only four Barn slots")
	inventory.barn_capacity = original_barn_capacity
	var coins_before_food: int = inventory.coins
	check(manager.buy_dog_food(), "buy Dog Food with free Barn space")
	check(inventory.coins == coins_before_food - DogData.DOG_FOOD_PRICE and inventory.dog_food == 1, "Dog Food charges exactly once")
	check(manager.feed_dog("dog_shiba"), "feed hungry Shiba")
	check(inventory.dog_food == 0 and is_equal_approx(manager.dog_hunger("dog_shiba"), 90.0), "feeding restores 70 hunger only to selected pet")
	check(is_equal_approx(manager.dog_hunger("dog_cream"), 100.0), "feeding does not alter another dog")
	inventory.coins = 100
	check(manager.buy_dog_food(5) and inventory.coins == 0 and inventory.dog_food == 5, "Buy 5 charges exactly 100 and grants exactly five")
	set_hunger("dog_shiba", 20.0)
	set_hunger("dog_cream", 20.0)
	set_hunger("dog_blacktan", 20.0)
	check(manager.feed_dog("dog_shiba") and is_equal_approx(manager.dog_hunger("dog_shiba"), 90.0) and is_equal_approx(manager.dog_hunger("dog_cream"), 20.0) and is_equal_approx(manager.dog_hunger("dog_blacktan"), 20.0), "feeding one of three hungry dogs changes only that profile")
	var home := Node2D.new()
	home.name = "DogHouseFixture"
	root.add_child(home)
	for marker_data in [["DogEntrance", Vector2(0, 38)], ["DogRestShiba", Vector2(-112, 124)], ["DogRestCream", Vector2(0, 136)], ["DogRestBlackTan", Vector2(112, 124)], ["FoodSpotShiba", Vector2(-30, 50)], ["FoodSpotCream", Vector2(0, 52)], ["FoodSpotBlackTan", Vector2(30, 50)]]:
		var marker := Marker2D.new()
		marker.name = marker_data[0]
		marker.position = marker_data[1]
		home.add_child(marker)
	var runtime_dogs: Array[CharacterBody2D] = []
	for index in range(DogData.DOG_IDS.size()):
		var pet_id: String = DogData.DOG_IDS[index]
		var runtime: CharacterBody2D = DOG_SCENE.instantiate()
		root.add_child(runtime)
		runtime.configure(pet_id, manager.dog_profile(pet_id), home, index)
		runtime_dogs.append(runtime)
	await process_frame
	var dog: CharacterBody2D = runtime_dogs[0]
	var shiba_sprite: AnimatedSprite2D = dog.get_node("DogVisual/MotionRoot/Sprite")
	check(shiba_sprite.sprite_frames == DogData.visual_frames_for_variant("shiba"), "runtime dog uses cached Shiba animation frames")
	for strip_variant in ["shiba", "cream"]:
		check(DogData.uses_strip_system(strip_variant), "%s uses its dedicated strip runtime instead of the legacy pose board" % strip_variant.capitalize())
		var strip_size := DogData.strip_frame_size_for_variant(strip_variant)
		for animation_name in DogData.strip_animations_for_variant(strip_variant):
			var strip_path := DogData.strip_path_for_variant(strip_variant, str(animation_name))
			var strip: Texture2D = load(strip_path)
			var expected_frames := int(DogData.strip_animations_for_variant(strip_variant)[animation_name]["frames"])
			check(strip != null and strip.get_width() == strip_size.x * expected_frames and strip.get_height() == strip_size.y, "%s strip dimensions use its configured full-body cells: %s" % [strip_variant.capitalize(), animation_name])
			check_strip_safe(strip_variant, strip_path, str(animation_name), expected_frames)
	check(ResourceLoader.exists("res://assets/animals/dogs/shiba/from_uploaded/source_run_10.png"), "Shiba run source archive contains the uploaded 10-frame board")
	check(shiba_sprite.sprite_frames.get_frame_count(&"run") == 10 and distinct_atlas_regions(shiba_sprite.sprite_frames, &"run") == 10, "Shiba run uses all ten uploaded full-body stride frames")
	for animation_name in [&"idle", &"idle_blink", &"walk", &"sit", &"sit_idle", &"lie_down", &"lie_idle"]:
		var configured_frames := int(DogData.SHIBA_STRIP_ANIMATIONS[String(animation_name)]["frames"])
		check(shiba_sprite.sprite_frames.get_frame_count(animation_name) == configured_frames and distinct_atlas_regions(shiba_sprite.sprite_frames, animation_name) >= 2, "Shiba %s uses every extracted full-body source frame" % animation_name)
	for runtime in runtime_dogs:
		var sprite: AnimatedSprite2D = runtime.get_node("DogVisual/MotionRoot/Sprite")
		var visual: Node = runtime.get_node("DogVisual")
		var required_animations: Array[StringName] = [&"idle", &"idle_blink", &"walk", &"run", &"sit", &"sit_idle", &"lie_down", &"lie_idle", &"sleep", &"wake_up", &"eat", &"happy", &"sniff", &"scratch", &"shake", &"alert"]
		check(sprite.sprite_frames != null and required_animations.all(func(animation_name: StringName) -> bool: return sprite.sprite_frames.has_animation(animation_name)), "runtime dog has the complete animation set")
		for animation_name in required_animations:
			check(sprite.sprite_frames.get_frame_count(animation_name) > 0, "every dog animation has frames: " + animation_name)
			for frame_index in range(sprite.sprite_frames.get_frame_count(animation_name)):
				var frame_texture := sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
				check(frame_texture != null and frame_texture is AtlasTexture, "every normal dog frame is an atlas pose: %s/%d" % [animation_name, frame_index])
				if runtime.variant_id in ["shiba", "cream"]:
					var expected_strip_source := "assets/animals/dogs/%s/animations/" % runtime.variant_id
					check(expected_strip_source in str((frame_texture as AtlasTexture).atlas.resource_path), "%s runtime frame uses dedicated strips, never the legacy pose board" % runtime.variant_id.capitalize())
		if runtime.variant_id == "shiba":
			check(sprite.sprite_frames.get_frame_count(&"run") == 10 and distinct_atlas_regions(sprite.sprite_frames, &"run") == 10, "Shiba run retains ten distinct full-body stride frames")
		else:
			check(distinct_atlas_regions(sprite.sprite_frames, &"walk") >= 4, "legacy/cream walk has multiple verified source regions")
			check(distinct_atlas_regions(sprite.sprite_frames, &"run") >= 2, "legacy/cream run uses multiple real source regions")
			check(distinct_atlas_regions(sprite.sprite_frames, &"wake_up") >= 3, "legacy/cream wake-up has a real pose transition")
		if runtime.variant_id == "shiba":
			check(sprite.scale.y > 0.36 and sprite.scale.y < 0.44, "Shiba uses the calibrated padded 256px strip scale")
		elif runtime.variant_id == "cream":
			check(sprite.scale.y > 0.40 and sprite.scale.y < 0.52, "Cream uses its separate full-body 160px strip scale")
		else:
			check(sprite.scale.y > 0.15 and sprite.scale.y < 0.30, "legacy dog art uses the compact calibrated pose-sheet scale")
		for animation_name in required_animations:
			sprite.play(animation_name)
			for frame_index in range(sprite.sprite_frames.get_frame_count(animation_name)):
				sprite.frame = frame_index
				visual._apply_frame_anchor()
				check(effective_frame_anchor(sprite, runtime.variant_id).length() <= 0.05, "every pose frame shares the stable ground anchor: %s/%s/%d" % [runtime.variant_id, animation_name, frame_index])
		check(sprite.get_parent().name == "MotionRoot" and visual.get_node("InteractLabel").get_parent() == visual, "only artwork receives visual motion; labels remain anchored to DogVisual")
	var visual: Node = dog.get_node("DogVisual")
	for mapping in [["IDLE", &"idle"], ["WANDER", &"walk"], ["RETURN_HOME", &"run"], ["WAIT_FOOD", &"sit_idle"], ["LIE_DOWN", &"lie_down"], ["SLEEP", &"sleep"], ["GO_INSIDE", &"walk"], ["EXIT_HOUSE", &"walk"], ["GREET_PLAYER", &"run"], ["EATING", &"eat"]]:
		visual.set_state(mapping[0])
		check(shiba_sprite.animation == mapping[1], "state %s maps to animation %s" % [mapping[0], mapping[1]])
	visual.happy()
	check(shiba_sprite.animation == &"happy", "pet interaction starts a happy animation")
	visual.set_interaction_hint(true, "[E] Pet TestDog")
	check(visual.get_node("InteractLabel").visible, "nearby dog shows an E interaction prompt")
	check(not visual.get_node("NameLabel").visible, "nearby dog uses one prompt instead of duplicating its name")
	visual.set_interaction_hint(false, "")
	check(dog.rest_position() == home.get_node("DogRestShiba").global_position and dog.rest_position() != dog.entrance_position(), "dog loads in the open Dog House yard rather than at the entrance")
	check(not visual.get_node("NameLabel").visible, "dog name never lingers after the nearby prompt closes")
	visual.set_interaction_hint(false, "")
	visual.set_state("WAIT_FOOD")
	var hungry_badge: Label = visual.get_node("ThoughtLabel")
	check(hungry_badge.visible and hungry_badge.text == tr("DOG_HUNGRY_BADGE"), "waiting dog shows the localized hungry badge instead of a placeholder")
	visual.set_interaction_hint(true, "Pet")
	check(not hungry_badge.visible, "hungry badge hides while the nearby interaction prompt is shown")
	visual.set_interaction_hint(false, "Pet")
	check(hungry_badge.visible and hungry_badge.text == tr("DOG_HUNGRY_BADGE"), "hungry badge returns after the prompt closes")
	var test_player := Node2D.new()
	test_player.add_to_group("farm_player")
	root.add_child(test_player)
	test_player.global_position = Vector2(0, 0)
	runtime_dogs[0].global_position = Vector2(22, 0)
	runtime_dogs[1].global_position = Vector2(48, 0)
	runtime_dogs[2].global_position = Vector2(120, 0)
	for runtime in runtime_dogs:
		runtime._set_state(runtime.State.IDLE, 0.0)
	set_hunger("dog_shiba", 100.0)
	set_hunger("dog_cream", 20.0)
	set_hunger("dog_blacktan", 100.0)
	check(runtime_dogs[0]._is_closest_prompt_dog(test_player), "only the closest eligible dog owns the nearby prompt")
	check(not runtime_dogs[1]._is_closest_prompt_dog(test_player), "second dog does not duplicate the nearby prompt")
	runtime_dogs[0]._update_interaction_hint()
	runtime_dogs[1]._update_interaction_hint()
	check(runtime_dogs[0].get_node("DogVisual/InteractLabel").visible and not runtime_dogs[1].get_node("DogVisual/InteractLabel").visible, "three dogs never stack E prompts")
	check("[E]" in runtime_dogs[0].interaction_prompt() and not "Bear" in runtime_dogs[0].interaction_prompt(), "healthy prompt is localized and does not hardcode another dog's name")
	check("[E]" in runtime_dogs[1].interaction_prompt() and runtime_dogs[1].is_hungry(), "hungry dog exposes its own direct-feed prompt")
	manager.rename_dog("dog_shiba", "Dau")
	runtime_dogs[0].refresh_profile(manager.dog_profile("dog_shiba"))
	check("Dau" in runtime_dogs[0].interaction_prompt(), "renamed pet prompt refreshes from its saved custom name")
	runtime_dogs[0]._set_state(runtime_dogs[0].State.SLEEP, 0.0)
	check("[E]" in runtime_dogs[0].interaction_prompt(), "sleeping dog exposes the wake interaction")
	for runtime in runtime_dogs:
		runtime.get_node("DogVisual").set_interaction_hint(false, "")
	test_player.queue_free()
	check(runtime_dogs[0].rest_position().distance_to(runtime_dogs[1].rest_position()) >= 70.0 and runtime_dogs[1].rest_position().distance_to(runtime_dogs[2].rest_position()) >= 70.0, "new dogs use separated Dog House yard positions")
	check(dog.food_wait_position() == home.get_node("FoodSpotShiba").global_position, "dog uses Dog House food slot")
	check(runtime_dogs[0].food_wait_position() != runtime_dogs[1].food_wait_position() and runtime_dogs[1].food_wait_position() != runtime_dogs[2].food_wait_position(), "three hungry dogs use separate food slots")
	dog.begin_eating("dog_shiba")
	check(dog.current_state == dog.State.EATING and dog.walking, "feed triggers visual eating routine")
	manager.set("unlocked_land_zones", ["farm_core", "land_01"])
	dog.wander_bounds = Rect2(-600, 0, 3000, 3400)
	dog.global_position = Vector2(800, 700)
	dog._wander()
	check(dog.current_state == dog.State.WANDER and LandData.owns_rect(Rect2(dog.target - Vector2(12, 8), Vector2(24, 16)), manager.get("unlocked_land_zones")), "healthy dog wanders to any owned map zone")
	dog.global_position = Vector2(1200, 1000)
	home.global_position = Vector2(500, 360)
	for runtime in runtime_dogs:
		runtime.set_home_point(home)
	check(dog.entrance_position() == home.get_node("DogEntrance").global_position and dog.global_position == Vector2(1200, 1000), "moving Dog House updates home without teleporting an exploring dog")
	manager.set("unlocked_land_zones", ["farm_core"])
	dog.global_position = Vector2(800, 700)
	check(manager.save_game(), "save exploring dog position")
	check(manager.dog_profile("dog_shiba").get("last_position") == Vector2(800, 700), "pet save stores its current world position")
	check(dog.restored_position() == Vector2(800, 700), "pet resumes its saved safe world position")
	set_hunger("dog_shiba", 10.0)
	dog._decide_next()
	check(dog.current_state == dog.State.RETURN_HOME and dog.target == dog.food_wait_position(), "only a hungry dog returns to the Dog House food spot")
	dog.global_position = dog.food_wait_position()
	dog._move_toward_target(0.1)
	check(dog.current_state == dog.State.WAIT_FOOD and hungry_badge.visible, "hungry dog arrives at its own food spot with a clear badge")
	check(dog.decision_timer.is_stopped(), "hungry dog waits at its bowl without a repeating return-home timer")
	var waiting_frame := shiba_sprite.frame
	dog._decide_next()
	check(dog.current_state == dog.State.WAIT_FOOD and shiba_sprite.animation == &"sit_idle" and shiba_sprite.frame == waiting_frame, "hungry dog keeps its stable wait animation instead of restarting run and sit")
	set_hunger("dog_shiba", 100.0)
	dog.begin_eating("dog_shiba")
	dog.global_position = dog.food_wait_position()
	dog._move_toward_target(0.1)
	dog._decide_next()
	check(dog.current_state == dog.State.IDLE and not hungry_badge.visible, "feeding clears the hungry badge as the dog returns to idle")
	for runtime in runtime_dogs:
		runtime.queue_free()
	home.queue_free()
	check(manager.save_game(), "save multi-dog profile")
	manager.pet_dogs.clear()
	manager._load_game()
	check(manager.pet_dogs.size() == 3 and manager.dog_profile("dog_shiba").get("name") == "Dau", "save/load preserves names and all profiles")
	var config := save_data()
	config.erase_section("pets")
	config.set_value("player", "has_dog", true)
	check(config.save(manager.SAVE_PATH) == OK, "write legacy single-dog fixture")
	manager.pet_dogs.clear()
	manager._load_game()
	check(manager.pet_dogs.size() == 1 and manager.dog_profile("dog_shiba").get("name") == "Cún", "legacy has_dog migrates once to free Cún Shiba")
	check(manager.reset_game() and manager.pet_dogs.is_empty() and inventory.dog_food == 0, "reset clears pet data and Dog Food")
	print("PASS: dog_pet")
	quit()
