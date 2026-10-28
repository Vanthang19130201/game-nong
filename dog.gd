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
var rng := RandomNumberGenerator.new()

@onready var decision_timer: Timer = $DecisionTimer
@onready var dog_visual: Node2D = $DogVisual

func _ready() -> void:
	rng.randomize()
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

func set_home_point(point: Node2D) -> void:
	home_point = point
	if is_instance_valid(home_point) and global_position.distance_to(home_slot_position()) > wander_radius * 2.0:
		global_position = home_slot_position()
		walking = false
		velocity = Vector2.ZERO

func home_slot_position() -> Vector2:
	var data: Dictionary = DogData.DOG_VARIANTS.get(variant_id, DogData.DOG_VARIANTS["shiba"])
	return home_point.global_position + Vector2(data["home_slot"]) if is_instance_valid(home_point) else global_position

func entrance_position() -> Vector2:
	if is_instance_valid(home_point):
		var entrance := home_point.get_node_or_null("DogEntrance") as Marker2D
		if is_instance_valid(entrance):
			return entrance.global_position
	return home_point.global_position + Vector2(0, 38) if is_instance_valid(home_point) else home_slot_position()

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
		dog_visual.happy()
		greet_cooldown = rng.randf_range(15.0, 25.0)
		_set_state(State.IDLE, 1.5)
	elif current_state == State.EATING:
		walking = false
		velocity = Vector2.ZERO
		decision_timer.start(rng.randf_range(1.2, 1.8))
	else:
		_set_state(State.IDLE, rng.randf_range(2.0, 5.0))

func _decide_next() -> void:
	if current_state == State.INSIDE_HOUSE:
		dog_visual.set_inside(false)
		global_position = entrance_position()
		_set_state(State.EXIT_HOUSE, 0.35)
		return
	if current_state == State.EXIT_HOUSE:
		_set_state(State.IDLE, rng.randf_range(1.0, 2.0))
		return
	if current_state == State.EATING:
		dog_visual.happy()
		_set_state(State.IDLE, 2.0)
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
		_move_to(entrance_position(), State.GO_INSIDE)

func _wander() -> void:
	for _attempt in range(8):
		var point := home_slot_position() + Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * wander_radius
		if _safe_destination(point):
			_move_to(point, State.WANDER)
			return
	_set_state(State.IDLE, 2.0)

func _safe_destination(point: Vector2) -> bool:
	if not point.is_finite() or not wander_bounds.has_point(point) or point.x >= FarmData.RIVER_LEFT - 42.0:
		return false
	var manager := _save_manager()
	return is_instance_valid(manager) and LandData.owns_rect(Rect2(point - Vector2(12, 8), Vector2(24, 16)), manager.unlocked_land_zones)


func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _move_to(destination: Vector2, next_state: State) -> void:
	target = destination
	walking = true
	_set_state(next_state, 0.0)

func _set_state(next_state: State, wait_seconds: float) -> void:
	current_state = next_state
	walking = next_state in [State.WANDER, State.RETURN_HOME, State.GO_INSIDE, State.GREET_PLAYER]
	if is_instance_valid(dog_visual):
		dog_visual.set_state(State.keys()[next_state])
	if wait_seconds > 0.0:
		decision_timer.start(wait_seconds)
	else:
		decision_timer.stop()

func _check_player_greeting() -> void:
	if greet_check_cooldown > 0.0 or greet_cooldown > 0.0 or current_state not in [State.IDLE, State.LIE_DOWN, State.SLEEP, State.INSIDE_HOUSE]:
		return
	greet_check_cooldown = 1.0
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player) or not is_instance_valid(home_point) or player.global_position.distance_to(home_point.global_position) > 145.0:
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
	decision_timer.stop()
	if is_instance_valid(dog_visual):
		dog_visual.set_state("EATING")

func interact(_player: Node2D = null) -> void:
	if is_instance_valid(dog_visual):
		dog_visual.show_name()
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud) and not hud.blocks_world_input():
		hud.show_transaction_feedback(tr("DOG_HUNGRY") if is_hungry() else tr("DOG_HAPPY") % custom_name)

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	return current_state != State.INSIDE_HOUSE and is_instance_valid(player) and player.global_position.distance_to(global_position) <= 70.0

func _update_depth() -> void:
	z_as_relative = false
	z_index = clampi(floori(global_position.y / 8.0), 1, 600)
