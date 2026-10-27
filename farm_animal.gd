extends Area2D

# Each animal uses the existing central interaction dispatcher. Production and
# saved counts remain entirely in Inventory and the station.
const APPEARANCE: Dictionary = {
	"chicken": {"frames": preload("res://assets/animals/chicken/chicken_frames.tres"), "height": 40.0, "speed": 28.0, "radius": 8.0},
	"cow": {"frames": preload("res://assets/animals/cow/cow_frames.tres"), "height": 64.0, "speed": 20.0, "radius": 12.0}
}

var herd: Node2D
var animal_type: String
var sale_pending: bool = false
var target: Vector2
var walking: bool = false
var speed: float
var body_radius: float
var spacing: float
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_timer: Timer = $IdleTimer
@onready var player: Node2D = get_tree().get_first_node_in_group("farm_player")

func _ready() -> void:
	add_to_group("farm_animals")
	add_to_group("farm_interactables")
	idle_timer.timeout.connect(choose_target)

func configure(kind: String, group: Node2D) -> void:
	herd = group
	animal_type = kind
	var data: Dictionary = APPEARANCE[kind]
	speed = data["speed"]
	body_radius = data["radius"]
	spacing = data["height"] * 0.8
	sprite.sprite_frames = data["frames"]
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture("idle_down", 0)
	sprite.scale = Vector2.ONE * data["height"] / frame.get_height()
	sprite.offset.y = -frame.get_height() / 2.0
	var shape := RectangleShape2D.new()
	shape.size = frame.get_size() * sprite.scale
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position.y = -data["height"] / 2.0
	rest()

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
	if not Inventory.sell_animal(animal_type):
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
	sprite.animation = "idle_down"
	sprite.stop()
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
	sprite.play("walk_down")

func _physics_process(delta: float) -> void:
	if not walking or herd.editing:
		return
	var next: Vector2 = position.move_toward(target, speed * delta)
	if not herd.is_position_valid(next, body_radius):
		rest()
		return
	if absf(next.x - position.x) > 0.01:
		sprite.flip_h = next.x < position.x
	position = next
	# Animals behind their home render behind its artwork, without changing
	# the building's placement footprint or collision layers.
	z_index = -2 if position.y < herd.ground_y else 0
	if position.distance_to(target) < 1.0:
		rest()
