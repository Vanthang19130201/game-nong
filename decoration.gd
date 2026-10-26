extends Node2D

const Data = preload("res://decoration_data.gd")
@export var decoration_id: String = "wood_fence"
@export var instance_id: String = ""
@export var is_preview: bool = false
var is_open: bool = false

func _ready() -> void:
	z_index = 100 if is_preview else (-5 if decoration_id == "stone_path" else 2)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14,14) if decoration_id == "farm_lamp" else Vector2(58,10)
	$Body/CollisionShape2D.shape = shape
	$Body/CollisionShape2D.disabled = is_preview or not Data.TYPES[decoration_id]["solid"]
	$InteractionArea.monitoring = not is_preview and decoration_id == "wood_gate"
	if not is_preview:
		add_to_group("farm_decorations")
		add_to_group("placement_obstacles")
		if decoration_id == "wood_gate":
			add_to_group("farm_interactables")
	$Visuals.queue_redraw()

func get_placement_rect() -> Rect2:
	var size_in_pixels: Vector2 = Vector2(Data.TYPES[decoration_id]["grid_size"])*64
	if int(round(rotation_degrees/90)) % 2 != 0:
		size_in_pixels = Vector2(size_in_pixels.y,size_in_pixels.x)
	return Rect2(global_position-size_in_pixels/2,size_in_pixels)

func create_placement_preview() -> Node2D:
	var copy = load("res://decoration.tscn").instantiate()
	copy.decoration_id = decoration_id
	copy.is_preview = true
	copy.rotation_degrees = rotation_degrees
	return copy

func can_interact() -> bool:
	if is_preview or decoration_id != "wood_gate":
		return false
	for body in $InteractionArea.get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false

func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if not can_interact() or (hud != null and hud.blocks_world_input()):
		return
	is_open = not is_open
	$Body/CollisionShape2D.set_deferred("disabled",is_open)
	$Visuals.queue_redraw()
