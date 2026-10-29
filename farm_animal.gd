extends Area2D

signal growth_stage_changed(previous_stage: int, next_stage: int)

# Each animal uses the existing central interaction dispatcher. Production and
# saved counts remain entirely in Inventory and the station.
const APPEARANCE: Dictionary = {
	"chicken": {"adult_frames": preload("res://assets/animals/chicken/chicken_frames.tres"), "adult_size":40.0, "speed":28.0, "radius":8.0},
	"cow": {"adult_frames": preload("res://assets/animals/cow/cow_frames.tres"), "adult_size":64.0, "speed":20.0, "radius":12.0},
	"pig": {"adult_size":56.0, "speed":22.0, "radius":11.0},
	"sheep": {"adult_size":58.0, "speed":20.0, "radius":11.0}
}
const AnimalData = preload("res://animal_data.gd")
const STAGE_TEXTURES: Dictionary = {
	# Use project-owned adult art as a safe visual fallback for early growth
	# stages until separate chick/calf art exists.
	"chicken": {1:"res://assets/animals/chicken/chicken.png", 2:"res://assets/animals/chicken/chicken.png"},
	"cow": {1:"res://assets/animals/cow/cow.png", 2:"res://assets/animals/cow/cow.png"},
	"pig": {1:"res://assets/animals/pig/pig.png", 2:"res://assets/animals/pig/pig.png", 3:"res://assets/animals/pig/pig.png"},
	"sheep": {1:"res://assets/animals/sheep/sheep.png", 2:"res://assets/animals/sheep/sheep.png", 3:"res://assets/animals/sheep/sheep.png"}
}
const ANIMATIONS: Array[String] = ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]

var herd: Node2D
var animal_type: String
var animal_id: String = ""
var born_at: float = 0.0
var growth_stage: int = 3
var lucky: bool = false
var sale_pending: bool = false
var target: Vector2
var walking: bool = false
var speed: float
var body_radius: float
var spacing: float
var status_bubble: Node2D
var feedback: Node2D
var facing: String = "down"
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var life_phase: float = 0.0
var nibble_time: float = 0.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer
@onready var player: Node2D = get_tree().get_first_node_in_group("farm_player")

func _ready() -> void:
	add_to_group("farm_animals")
	add_to_group("farm_interactables")
	idle_timer.timeout.connect(choose_target)

func configure(kind: String, group: Node2D, record: Dictionary) -> void:
	herd = group
	animal_type = kind
	update_record(record)
	var data: Dictionary = APPEARANCE[kind]
	speed = data["speed"]
	apply_appearance()
	if not is_instance_valid(status_bubble):
		status_bubble = preload("res://animal_status_bubble.gd").new()
		status_bubble.name = "StatusBubble"
		add_child(status_bubble)
	if not is_instance_valid(feedback):
		feedback = preload("res://animal_feedback.gd").new()
		feedback.name = "AnimalFeedback"
		add_child(feedback)
	status_bubble.configure(data["adult_size"] * AnimalData.scale_for(kind,growth_stage))
	refresh_status()
	rest()

func update_record(record: Dictionary) -> void:
	if record.is_empty():
		return
	var previous_stage: int = growth_stage
	animal_id = str(record.get("id", ""))
	born_at = float(record.get("born_at", Time.get_unix_time_from_system()))
	lucky = record.get("lucky", AnimalData.lucky_pig(animal_id)) == true
	growth_stage = AnimalData.stage_for(animal_type,born_at)
	if previous_stage != growth_stage and is_inside_tree():
		apply_appearance()
		if is_instance_valid(status_bubble):
			status_bubble.configure(APPEARANCE[animal_type]["adult_size"] * AnimalData.scale_for(animal_type,growth_stage))

func update_growth() -> void:
	var new_stage: int = AnimalData.stage_for(animal_type,born_at)
	if new_stage == growth_stage:
		return
	var previous_stage: int = growth_stage
	growth_stage = new_stage
	apply_appearance()
	if is_instance_valid(status_bubble):
		status_bubble.configure(APPEARANCE[animal_type]["adult_size"] * AnimalData.scale_for(animal_type,growth_stage))
	refresh_status()
	if is_instance_valid(feedback):
		feedback.play("grown")
	growth_stage_changed.emit(previous_stage, growth_stage)


func play_feed_feedback() -> void:
	if is_instance_valid(feedback):
		feedback.play("feed")

func apply_appearance() -> void:
	var data: Dictionary = APPEARANCE[animal_type]
	body_radius = data["radius"]
	spacing = data["adult_size"] * AnimalData.scale_for(animal_type,growth_stage) * 0.8
	if growth_stage >= 3 and data.has("adult_frames"):
		sprite.sprite_frames = data["adult_frames"]
	else:
		sprite.sprite_frames = _create_stage_frames(STAGE_TEXTURES[animal_type][growth_stage])
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture("idle_down", 0)
	var display_size: float = float(data["adult_size"]) * AnimalData.scale_for(animal_type,growth_stage)
	sprite.scale = Vector2.ONE * display_size / frame.get_height()
	sprite.offset.y = -frame.get_height() / 2.0
	base_sprite_scale = sprite.scale
	base_sprite_position = sprite.position
	var shape := RectangleShape2D.new()
	shape.size = frame.get_size() * sprite.scale
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position.y = -display_size / 2.0

func _create_stage_frames(path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var texture: Texture2D = load(path)
	for animation_name in ANIMATIONS:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name,true)
		frames.add_frame(animation_name,texture)
	return frames

func refresh_status() -> void:
	if not is_instance_valid(status_bubble) or not is_instance_valid(herd):
		return
	var station = herd.home
	var product: Dictionary = station.Progression.PRODUCTS[station.station_id]
	status_bubble.refresh(station.state, product["item"] if station.state == "READY" else product["feed"])

func get_interaction_position() -> Vector2:
	return $CollisionShape2D.global_position

func can_interact() -> bool:
	return not sale_pending and is_visible_in_tree() and is_instance_valid(player) and player.global_position.distance_to(get_interaction_position()) <= 64.0

func interact(_player: Node2D = null) -> void:
	if not can_interact() or (is_instance_valid(player.hud) and player.hud.blocks_world_input()):
		return
	if is_instance_valid(player.hud):
		player.hud.open_animal_sale(self)

func sell_confirmed() -> bool:
	if not can_interact() or not is_instance_valid(player.hud):
		return false
	if player.hud.pending_sale_animal != self or not player.hud.animal_sale_confirmation.visible:
		return false
	# inventory_changed is synchronous: count reconciliation must remove THIS
	# instance, rather than the last animal in the group.
	sale_pending = true
	var previous_coins: int = Inventory.coins
	if not Inventory.sell_animal(animal_type,animal_id):
		sale_pending = false
		return false
	if is_instance_valid(player.hud):
		player.hud.show_transaction_feedback(tr("TRADE_ITEM") % [-1, Localization.display_name(animal_type)] + "\n" + tr("TRADE_COINS") % (Inventory.coins - previous_coins))
	return true

func retire() -> void:
	sale_pending = true
	remove_from_group("farm_interactables")
	remove_from_group("farm_animals")
	idle_timer.stop()
	set_physics_process(false)
	hide()

func rest() -> void:
	walking = false
	target = position
	if randf() < 0.24:
		facing = ["down", "left", "right", "up"][randi() % 4]
	_play_animation("idle_" + facing)
	nibble_time = randf_range(0.7, 1.35) if randf() < 0.36 else 0.0
	idle_timer.start(randf_range(2.0, 5.0))

func choose_target() -> void:
	if not visible or herd.editing:
		rest()
		return
	var point: Vector2 = herd.find_position(self, true)
	if not point.is_finite() or position.distance_to(point) < 12.0:
		rest()
		return
	target = point
	walking = true
	idle_timer.stop()
	facing = _facing_for(point - position)
	_play_animation("walk_" + facing)

func _physics_process(delta: float) -> void:
	if not walking or herd.editing:
		return
	var next: Vector2 = position.move_toward(target, speed * delta)
	if not herd.is_position_valid(next, body_radius):
		rest()
		return
	var direction := next - position
	if direction.length_squared() > 0.01:
		facing = _facing_for(direction)
		_play_animation("walk_" + facing)
	position = next
	# Animals behind their home render behind its artwork, without changing
	# the building's placement footprint or collision layers.
	z_index = clampi(roundi(position.y / 8.0), -24, 24)
	if position.distance_to(target) < 1.0:
		rest()


func _process(delta: float) -> void:
	life_phase += delta
	if not is_instance_valid(sprite):
		return
	if walking:
		sprite.position = base_sprite_position + Vector2(0, sin(life_phase * 10.0) * 0.55)
		sprite.scale = base_sprite_scale
		sprite.rotation = 0.0
		return
	nibble_time = maxf(0.0, nibble_time - delta)
	var rest_bob := sin(life_phase * 2.25 + float(animal_id.hash() % 7)) * 0.45
	sprite.position = base_sprite_position + Vector2(0, rest_bob)
	if nibble_time > 0.0:
		sprite.rotation = sin(life_phase * 9.0) * 0.035
		sprite.scale = base_sprite_scale * Vector2(1.025, 0.975)
	else:
		sprite.rotation = 0.0
		sprite.scale = base_sprite_scale


func _facing_for(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func _play_animation(name: String) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(name):
		return
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)
