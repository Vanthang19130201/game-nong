extends Node

const Data = preload("res://decoration_data.gd")
const Placement = preload("res://building_placement.gd")
const SCENE = preload("res://decoration.tscn")
var instances: Dictionary = {}

func _ready() -> void:
	for record in SaveManager.placed_decorations:
		_spawn(record)
	Inventory.inventory_changed.connect(_inventory_changed)

func _spawn(record: Dictionary) -> Node2D:
	var decoration = SCENE.instantiate()
	decoration.name = record["instance_id"]
	decoration.instance_id = record["instance_id"]
	decoration.decoration_id = record["decoration_id"]
	decoration.position = Vector2(record["position_x"],record["position_y"])
	decoration.rotation_degrees = record["rotation"]
	get_parent().add_child(decoration)
	instances[decoration.instance_id] = decoration
	return decoration

func place(source: Node2D, point: Vector2, angle: float) -> bool:
	var id: String = source.decoration_id
	if not Data.TYPES.has(id) or not Placement.can_place(source,point):
		return false
	if not Data.can_afford(id):
		return Inventory.fail(tr("ERROR_MATERIALS"))
	var cost: Dictionary = Data.TYPES[id]
	var instance_id: String = "decor_%04d" % SaveManager.next_decoration_id
	SaveManager.next_decoration_id += 1
	var record: Dictionary = {"instance_id": instance_id, "decoration_id": id, "position_x": point.x, "position_y": point.y, "rotation": Data.normalized_rotation(id,angle)}
	Inventory.coins -= cost["coins"]
	Inventory.wood -= cost["wood"]
	Inventory.stone -= cost["stone"]
	SaveManager.placed_decorations.append(record)
	_spawn(record)
	Inventory.inventory_changed.emit()
	return true

func move(decoration: Node2D, point: Vector2, angle: float) -> bool:
	if not Placement.can_place(decoration,point):
		return false
	var record: Dictionary = _record(decoration.instance_id)
	if record.is_empty():
		return false
	var previous: Dictionary = record.duplicate()
	var old_position: Vector2 = decoration.position
	var old_angle: float = decoration.rotation_degrees
	decoration.position = point
	decoration.rotation_degrees = Data.normalized_rotation(decoration.decoration_id,angle)
	record["position_x"] = point.x
	record["position_y"] = point.y
	record["rotation"] = decoration.rotation_degrees
	if SaveManager.save_game():
		return true
	record.merge(previous,true)
	decoration.position = old_position
	decoration.rotation_degrees = old_angle
	return false

func remove(instance_id: String) -> bool:
	var record: Dictionary = _record(instance_id)
	if record.is_empty() or not instances.has(instance_id):
		return false
	var index: int = SaveManager.placed_decorations.find(record)
	SaveManager.placed_decorations.remove_at(index)
	if not SaveManager.save_game():
		SaveManager.placed_decorations.insert(index,record)
		return false
	var decoration = instances[instance_id]
	instances.erase(instance_id)
	get_parent().remove_child(decoration)
	decoration.queue_free()
	return true

func _record(instance_id: String) -> Dictionary:
	for record in SaveManager.placed_decorations:
		if record["instance_id"] == instance_id:
			return record
	return {}

func _inventory_changed() -> void:
	if SaveManager.resetting:
		for decoration in instances.values():
			get_parent().remove_child(decoration)
			decoration.queue_free()
		instances.clear()
