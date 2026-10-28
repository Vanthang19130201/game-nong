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
	for marker_data in [["DogEntrance", Vector2(0, 38)], ["DogRestShiba", Vector2(-42, 74)], ["DogRestCream", Vector2(0, 78)], ["DogRestBlackTan", Vector2(42, 74)], ["FoodSpotShiba", Vector2(-30, 50)], ["FoodSpotCream", Vector2(0, 52)], ["FoodSpotBlackTan", Vector2(30, 50)]]:
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
	var shiba_sprite: AnimatedSprite2D = dog.get_node("DogVisual/Sprite")
	check(shiba_sprite.sprite_frames == DogData.visual_frames_for_variant("shiba"), "runtime dog uses cached Shiba animation frames")
	for runtime in runtime_dogs:
		var sprite: AnimatedSprite2D = runtime.get_node("DogVisual/Sprite")
		var required_animations: Array[StringName] = [&"idle", &"idle_blink", &"walk", &"run", &"sit", &"sit_idle", &"lie_down", &"lie_idle", &"sleep", &"wake_up", &"eat", &"happy", &"sniff", &"scratch", &"shake", &"alert"]
		check(sprite.sprite_frames != null and required_animations.all(func(animation_name: StringName) -> bool: return sprite.sprite_frames.has_animation(animation_name)), "runtime dog has the complete animation set")
		for animation_name in required_animations:
			check(sprite.sprite_frames.get_frame_count(animation_name) > 0, "every dog animation has frames: " + animation_name)
			for frame_index in range(sprite.sprite_frames.get_frame_count(animation_name)):
				check(sprite.sprite_frames.get_frame_texture(animation_name, frame_index) != null, "every dog animation frame is a valid texture: %s/%d" % [animation_name, frame_index])
		check(is_equal_approx(240.0 * sprite.scale.y, 64.0), "runtime dog art is constrained to a 64px display height")
	var visual: Node = dog.get_node("DogVisual")
	for mapping in [["IDLE", &"idle"], ["WANDER", &"walk"], ["RETURN_HOME", &"run"], ["WAIT_FOOD", &"sit_idle"], ["LIE_DOWN", &"lie_down"], ["SLEEP", &"sleep"], ["GO_INSIDE", &"walk"], ["EXIT_HOUSE", &"walk"], ["GREET_PLAYER", &"run"], ["EATING", &"eat"]]:
		visual.set_state(mapping[0])
		check(shiba_sprite.animation == mapping[1], "state %s maps to animation %s" % [mapping[0], mapping[1]])
	visual.happy()
	check(shiba_sprite.animation == &"happy", "pet interaction starts a happy animation")
	visual.set_interaction_hint(true, "MÃ­t")
	check(visual.get_node("InteractLabel").visible and "[E]" in visual.get_node("InteractLabel").text, "nearby dog shows an E interaction prompt")
	check(not visual.get_node("NameLabel").visible, "nearby dog uses one prompt instead of duplicating its name")
	visual.set_interaction_hint(false, "MÃ­t")
	check(dog.rest_position() == home.get_node("DogRestShiba").global_position and dog.rest_position() != dog.entrance_position(), "dog loads in the open Dog House yard rather than at the entrance")
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
	set_hunger("dog_shiba", 10.0)
	dog._decide_next()
	check(dog.current_state == dog.State.RETURN_HOME and dog.target == dog.food_wait_position(), "only a hungry dog returns to the Dog House food spot")
	for runtime in runtime_dogs:
		runtime.queue_free()
	home.queue_free()
	check(manager.save_game(), "save multi-dog profile")
	manager.pet_dogs.clear()
	manager._load_game()
	check(manager.pet_dogs.size() == 3 and manager.dog_profile("dog_shiba").get("name") == "Mít", "save/load preserves names and all profiles")
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
