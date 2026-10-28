extends CharacterBody2D

const DogData = preload("res://dog_data.gd")
const FarmData = preload("res://farm_data.gd")
const LandData = preload("res://land_data.gd")

enum State { IDLE, WANDER, RETURN_HOME, WAIT_FOOD, LIE_DOWN, SLEEP, GO_INSIDE, INSIDE_HOUSE, EXIT_HOUSE, GREET_PLAYER, EATING }

var pet_id: String = ""
var variant_id: String = ""
var custom_name: String = ""
var personality: String = ""
var home_slot_index: int = 0
var home_point: Node2D
var wander_bounds: Rect2 = Rect2(-600, 0, 3000, 3400)
var target: Vector2
var walking: bool = false
var speed: float = 60.0
var wander_radius: float = 110.0
var current_state: State = State.IDLE
var greet_cooldown: float = 0.0
var greet_check_cooldown: float = 0.0
var vocal_cooldown: float = 0.0
var hungry_whine_cooldown: float = 0.0
var eating_sound_elapsed: float = 0.0
var eating_sound_count: int = 0
var interaction_lock: float = 0.0
var rng := RandomNumberGenerator.new()

@onready var decision_timer: Timer = $DecisionTimer
@onready var dog_visual: Node2D = $DogVisual

func _ready() -> void:
	rng.randomize()
	hungry_whine_cooldown = rng.randf_range(20.0, 42.0)
	decision_timer.timeout.connect(_decide_next)
	add_to_group("farm_pets")
	add_to_group("farm_interactables")
	_set_state(State.IDLE, 2.0)

func configure(profile_id: String, profile: Dictionary, home: Node2D, slot_index: int) -> void:
	pet_id = profile_id
	variant_id = str(profile.get("variant", "shiba"))
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	custom_name = DogData.normalized_name(profile.get("name", ""), str(data["default_name"]))
	personality = str(data["personality"])
	home_slot_index = slot_index
	speed = float(data["speed"])
	wander_radius = float(data["wander_radius"])
	set_home_point(home)
	if is_instance_valid(dog_visual):
		dog_visual.configure(variant_id, custom_name)


func refresh_profile(profile: Dictionary) -> void:
	# Farm refreshes an existing runtime after a rename. Do not recreate the dog
	# or touch its position/state: only its presentation data is refreshed.
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	var next_name := DogData.normalized_name(profile.get("name", ""), str(data["default_name"]))
	if next_name == custom_name:
		return
	custom_name = next_name
	if is_instance_valid(dog_visual):
		dog_visual.configure(variant_id, custom_name)

func set_home_point(point: Node2D) -> void:
	home_point = point

func home_slot_position() -> Vector2:
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	return home_point.global_position + Vector2(data["home_slot"]) if is_instance_valid(home_point) else global_position

func entrance_position() -> Vector2:
	if is_instance_valid(home_point):
		var entrance := home_point.get_node_or_null("DogEntrance") as Marker2D
		if is_instance_valid(entrance):
			return entrance.global_position
	return home_point.global_position + Vector2(0, 38) if is_instance_valid(home_point) else home_slot_position()

func rest_position() -> Vector2:
	# Pets always load into the open yard. The entrance remains reserved for a
	# real exit/return animation, so a normal load never makes a healthy dog
	# appear to be inside the lodge.
	if is_instance_valid(home_point):
		var marker_name := "DogRestShiba" if variant_id == "shiba" else "DogRestCream" if variant_id == "cream" else "DogRestBlackTan"
		var rest_marker := home_point.get_node_or_null(marker_name) as Marker2D
		if is_instance_valid(rest_marker):
			return rest_marker.global_position
	return home_slot_position()


func restored_position() -> Vector2:
	# A companion keeps its last valid place on the farm across save/load. New
	# dogs still receive a separated yard point, but returning players do not
	# find every dog stacked in front of the Dog House.
	var manager := _save_manager()
	var profile: Dictionary = manager.dog_profile(pet_id) if is_instance_valid(manager) else {}
	var saved: Variant = profile.get("last_position", Vector2.INF)
	if saved is Vector2 and saved.is_finite() and _safe_destination(saved):
		return saved
	return rest_position()

func food_wait_position() -> Vector2:
	if is_instance_valid(home_point):
		var marker_name := "FoodSpotShiba" if variant_id == "shiba" else "FoodSpotCream" if variant_id == "cream" else "FoodSpotBlackTan"
		var food_marker := home_point.get_node_or_null(marker_name) as Marker2D
		if is_instance_valid(food_marker):
			return food_marker.global_position
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	return home_point.global_position + Vector2(data["food_slot"]) if is_instance_valid(home_point) else home_slot_position()

func hunger() -> float:
	var manager := _save_manager()
	return manager.dog_hunger(pet_id) if is_instance_valid(manager) else 100.0

func is_hungry() -> bool:
	return hunger() <= DogData.HUNGRY_THRESHOLD

func _physics_process(delta: float) -> void:
	greet_cooldown = maxf(0.0, greet_cooldown - delta)
	greet_check_cooldown = maxf(0.0, greet_check_cooldown - delta)
	vocal_cooldown = maxf(0.0, vocal_cooldown - delta)
	hungry_whine_cooldown = maxf(0.0, hungry_whine_cooldown - delta)
	interaction_lock = maxf(0.0, interaction_lock - delta)
	if current_state != State.INSIDE_HOUSE:
		var manager := _save_manager()
		if is_instance_valid(manager):
			manager.tick_dog_hunger(pet_id, delta)
		_check_player_greeting()
	if current_state == State.WAIT_FOOD and not is_hungry():
		_set_state(State.EATING, 1.0)
	if is_hungry() and current_state not in [State.RETURN_HOME, State.WAIT_FOOD, State.EATING, State.INSIDE_HOUSE]:
		_move_to(food_wait_position(), State.RETURN_HOME)
	if walking:
		_move_toward_target(delta)
	_update_eating_audio(delta)
	_update_interaction_hint()
	_update_depth()

func _move_toward_target(delta: float) -> void:
	var offset := target - global_position
	if offset.length() <= speed * delta:
		global_position = target
		walking = false
		velocity = Vector2.ZERO
		_arrive()
		return
	velocity = offset.normalized() * speed
	if is_instance_valid(dog_visual):
		dog_visual.set_facing(velocity.x >= 0.0)
	move_and_slide()

func _arrive() -> void:
	if current_state == State.RETURN_HOME:
		_set_state(State.WAIT_FOOD, 0.8)
	elif current_state == State.GO_INSIDE:
		dog_visual.set_inside(true)
		_set_state(State.INSIDE_HOUSE, rng.randf_range(5.0, 12.0))
	elif current_state == State.GREET_PLAYER:
		greet_cooldown = rng.randf_range(15.0, 25.0)
		_set_state(State.IDLE, 1.5)
		# Play the visual reward after state flow returns to idle, so the idle
		# mapper cannot immediately replace the happy animation.
		dog_visual.happy()
	elif current_state == State.EATING:
		walking = false
		velocity = Vector2.ZERO
		decision_timer.start(rng.randf_range(1.2, 1.8))
	else:
		_set_state(State.IDLE, rng.randf_range(2.0, 5.0))

func _decide_next() -> void:
	if interaction_lock > 0.0:
		decision_timer.start(interaction_lock)
		return
	if current_state == State.INSIDE_HOUSE:
		dog_visual.set_inside(false)
		global_position = entrance_position()
		_set_state(State.EXIT_HOUSE, 0.35)
		return
	if current_state == State.EXIT_HOUSE:
		_set_state(State.IDLE, rng.randf_range(1.0, 2.0))
		return
	if current_state == State.EATING:
		_set_state(State.IDLE, 2.0)
		dog_visual.happy()
		return
	if is_hungry():
		_move_to(food_wait_position(), State.RETURN_HOME)
		return
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	var roll := rng.randf()
	if roll < float(data["wander_weight"]):
		_wander()
	elif roll < float(data["wander_weight"]) + float(data["lie_weight"]):
		_set_state(State.LIE_DOWN, rng.randf_range(2.5, 5.0))
	elif roll < 0.94:
		_set_state(State.SLEEP, rng.randf_range(3.0, 7.0))
	else:
		# Home is a real destination for hunger only. Healthy pets rest and
		# wander across the player's owned farm instead of being pulled back to
		# the Dog House by a random idle roll.
		_set_state(State.IDLE, rng.randf_range(2.0, 4.0))

func _wander() -> void:
	var manager := _save_manager()
	if not is_instance_valid(manager):
		_set_state(State.IDLE, 2.0)
		return
	var owned_zones: Array = manager.get("unlocked_land_zones")
	for _attempt in range(16):
		if owned_zones.is_empty():
			break
		var zone_id: String = str(owned_zones[rng.randi_range(0, owned_zones.size() - 1)])
		var zone: Dictionary = LandData.ZONES.get(zone_id, {})
		var area: Rect2 = zone.get("area", Rect2())
		if area.size.x < 64.0 or area.size.y < 64.0:
			continue
		# An inset keeps paws away from the map edge while allowing any owned
		# land, including west/south expansion zones, to be explored.
		var point := Vector2(
			rng.randf_range(area.position.x + 28.0, area.end.x - 28.0),
			rng.randf_range(area.position.y + 28.0, area.end.y - 28.0)
		)
		if _safe_destination(point):
			_move_to(point, State.WANDER)
			return
	_set_state(State.IDLE, 2.0)

func _safe_destination(point: Vector2) -> bool:
	if not point.is_finite() or not wander_bounds.has_point(point) or point.x >= FarmData.RIVER_LEFT - 42.0:
		return false
	var manager := _save_manager()
	return is_instance_valid(manager) and LandData.owns_rect(Rect2(point - Vector2(12, 8), Vector2(24, 16)), manager.get("unlocked_land_zones"))


func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _move_to(destination: Vector2, next_state: State) -> void:
	target = destination
	walking = true
	_set_state(next_state, 0.0)

func _set_state(next_state: State, wait_seconds: float) -> void:
	var state_changed := current_state != next_state
	current_state = next_state
	walking = next_state in [State.WANDER, State.RETURN_HOME, State.GO_INSIDE, State.GREET_PLAYER]
	if is_instance_valid(dog_visual):
		dog_visual.set_state(State.keys()[next_state])
	if state_changed:
		_play_state_sound(next_state)
	if wait_seconds > 0.0:
		decision_timer.start(wait_seconds)
	else:
		decision_timer.stop()

func _check_player_greeting() -> void:
	if interaction_lock > 0.0 or greet_check_cooldown > 0.0 or greet_cooldown > 0.0 or current_state not in [State.IDLE, State.LIE_DOWN, State.SLEEP, State.INSIDE_HOUSE]:
		return
	greet_check_cooldown = 1.0
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player) or player.global_position.distance_to(global_position) > 145.0:
		return
	var chance: float = float(DogData.DOG_VARIANTS[variant_id]["greet_chance"])
	if rng.randf() > chance * 0.24:
		return
	if current_state == State.INSIDE_HOUSE:
		dog_visual.set_inside(false)
		global_position = entrance_position()
	var stop := player.global_position - (player.global_position - global_position).normalized() * 38.0
	if _safe_destination(stop):
		_move_to(stop, State.GREET_PLAYER)


func begin_eating(fed_pet_id: String) -> void:
	if fed_pet_id != pet_id:
		return
	if current_state == State.INSIDE_HOUSE:
		dog_visual.set_inside(false)
		global_position = entrance_position()
	target = food_wait_position()
	current_state = State.EATING
	walking = true
	eating_sound_elapsed = 0.10
	eating_sound_count = 0
	decision_timer.stop()
	if is_instance_valid(dog_visual):
		dog_visual.set_state("EATING")

func interact(_player: Node2D = null) -> void:
	if current_state == State.EATING or interaction_lock > 0.0:
		return
	var player := _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("farm_player") as Node2D
	if is_instance_valid(player) and is_instance_valid(dog_visual):
		dog_visual.set_facing(player.global_position.x >= global_position.x)
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if not is_instance_valid(hud) or hud.blocks_world_input():
		return
	if is_hungry():
		var manager := _save_manager()
		if is_instance_valid(manager) and manager.feed_dog(pet_id):
			hud.show_transaction_feedback(tr("DOG_FEED_SUCCESS"))
		else:
			hud.show_transaction_feedback(tr("DOG_FOOD_NONE"))
		return
	if current_state == State.SLEEP:
		interaction_lock = 0.72 if variant_id == "cream" else 0.62
		_set_state(State.IDLE, interaction_lock)
		if is_instance_valid(dog_visual):
			dog_visual.wake()
		hud.show_transaction_feedback(tr("DOG_HAPPY") % custom_name)
		return
	interaction_lock = _pet_reaction_duration()
	decision_timer.start(interaction_lock)
	if is_instance_valid(dog_visual):
		dog_visual.happy()
	if rng.randf() <= _happy_sound_chance():
		_play_dog_sound(_happy_sound_id(), true, 5.0)
	hud.show_transaction_feedback(tr("DOG_HAPPY") % custom_name)


func _update_interaction_hint() -> void:
	if not is_instance_valid(dog_visual):
		return
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	var nearby := is_instance_valid(player) and can_interact() and _is_closest_prompt_dog(player)
	dog_visual.set_interaction_hint(nearby, interaction_prompt())

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	return interaction_lock <= 0.0 and current_state not in [State.INSIDE_HOUSE, State.EATING] and is_instance_valid(player) and player.global_position.distance_to(global_position) <= 70.0


func interaction_prompt() -> String:
	if current_state == State.EATING:
		return tr("DOG_INTERACT_EATING") % custom_name
	if is_hungry():
		return tr("DOG_INTERACT_FEED") % custom_name
	if current_state == State.SLEEP:
		return tr("DOG_INTERACT_WAKE") % custom_name
	return tr("DOG_INTERACT_PET") % custom_name


func _is_closest_prompt_dog(player: Node2D) -> bool:
	var best: Node2D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("farm_pets"):
		var candidate_dog := candidate as Node2D
		if not is_instance_valid(candidate_dog) or not candidate_dog.has_method("can_interact"):
			continue
		if not bool(candidate_dog.call("can_interact")):
			continue
		var distance := player.global_position.distance_squared_to(candidate_dog.global_position)
		if distance < best_distance:
			best = candidate_dog
			best_distance = distance
	return best == self


func _pet_reaction_duration() -> float:
	return 0.8 if variant_id == "shiba" else 1.0 if variant_id == "cream" else 0.85


func _happy_sound_chance() -> float:
	return 0.50 if variant_id == "shiba" else 0.20 if variant_id == "cream" else 0.36

func _update_depth() -> void:
	z_as_relative = false
	z_index = clampi(floori(global_position.y / 8.0), 1, 600)


func _play_state_sound(next_state: State) -> void:
	if next_state == State.GREET_PLAYER:
		# One friendly greeting on state entry, never once per movement frame.
		_play_dog_sound(_bark_sound_id(), true, 8.0)
	elif next_state == State.RETURN_HOME and hungry_whine_cooldown <= 0.0 and rng.randf() <= 0.28:
		# Hunger is communicated sparingly so it is informative, never nagging.
		_play_dog_sound("dog_whine_soft", true, 28.0)
		hungry_whine_cooldown = rng.randf_range(25.0, 45.0)


func _update_eating_audio(delta: float) -> void:
	if current_state != State.EATING:
		eating_sound_elapsed = 0.0
		eating_sound_count = 0
		return
	if walking or eating_sound_count >= 3:
		return
	eating_sound_elapsed += delta
	if eating_sound_elapsed < 0.34:
		return
	eating_sound_elapsed = 0.0
	eating_sound_count += 1
	_play_dog_sound("dog_lick" if eating_sound_count == 3 else "dog_eat", false)


func _bark_sound_id() -> String:
	return "dog_%s_bark" % variant_id


func _happy_sound_id() -> String:
	return "dog_%s_happy" % variant_id


func _play_dog_sound(sound_id: String, vocal: bool = false, minimum_gap: float = 0.0) -> void:
	if vocal and vocal_cooldown > 0.0:
		return
	var audio := get_node_or_null("/root/AudioManager")
	if is_instance_valid(audio):
		audio.play_random_sfx(sound_id, global_position)
	if vocal:
		vocal_cooldown = maxf(minimum_gap, 1.5)
