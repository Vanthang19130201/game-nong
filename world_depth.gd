extends Node

# Centralised Y-depth assignment for world actors.  Background art keeps its
# authored negative z layers; only interactive world objects are sorted here.
# This makes edit-mode building moves update depth too, without affecting
# collision, placement validation, or any saved position.

const DEPTH_STEP: float = 8.0
const REFRESH_INTERVAL: float = 0.12

var refresh_elapsed: float = 0.0


func _ready() -> void:
	_refresh_all()


func _process(delta: float) -> void:
	# The player needs continuous depth while walking.  Everything else is
	# refreshed at a small fixed interval, which is enough for edit-mode moves.
	var player := get_tree().get_first_node_in_group("farm_player")
	if player is Node2D:
		_apply_depth(player as Node2D)
	refresh_elapsed += delta
	if refresh_elapsed < REFRESH_INTERVAL:
		return
	refresh_elapsed = 0.0
	_refresh_all()


func _refresh_all() -> void:
	var seen: Dictionary = {}
	for node in get_tree().get_nodes_in_group("farm_interactables"):
		if node is Node2D and not node.is_in_group("farm_animals"):
			seen[node.get_instance_id()] = node
	for node in get_tree().get_nodes_in_group("farm_animal_groups"):
		if node is Node2D:
			seen[node.get_instance_id()] = node
	for node in seen.values():
		var target := node as Node2D
		if target != null:
			_apply_depth(target)


func _apply_depth(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	node.z_as_relative = false
	node.z_index = _depth_for_y(_foot_y(node))


func _foot_y(node: Node2D) -> float:
	if node.is_in_group("farm_animal_groups"):
		return node.global_position.y + float(node.get("ground_y"))
	var collision := node.get_node_or_null("Body/CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is RectangleShape2D:
		var shape := collision.shape as RectangleShape2D
		return collision.global_position.y + shape.size.y * 0.5 * absf(collision.global_scale.y)
	return node.global_position.y


func _depth_for_y(world_y: float) -> int:
	return clampi(floori(world_y / DEPTH_STEP), 1, 600)
