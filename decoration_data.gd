extends RefCounted

const TYPES: Dictionary = {
	"wood_fence": {"name_key": "DECOR_WOOD_FENCE", "grid_size": Vector2i.ONE, "coins": 50, "wood": 1, "stone": 0, "rotatable": true, "solid": true},
	"stone_path": {"name_key": "DECOR_STONE_PATH", "grid_size": Vector2i.ONE, "coins": 30, "wood": 0, "stone": 1, "rotatable": false, "solid": false},
	"wood_gate": {"name_key": "DECOR_WOOD_GATE", "grid_size": Vector2i.ONE, "coins": 100, "wood": 2, "stone": 0, "rotatable": true, "solid": true},
	"farm_lamp": {"name_key": "DECOR_FARM_LAMP", "grid_size": Vector2i.ONE, "coins": 150, "wood": 1, "stone": 1, "rotatable": true, "solid": true},
	"fishing_sign": {"name_key": "DECOR_FISHING_SIGN", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": true, "solid": false, "hidden": true},
	"golden_flower_pot": {"name_key": "DECOR_GOLDEN_FLOWER_POT", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": false, "solid": false, "hidden": true},
	"treasure_chest": {"name_key": "DECOR_TREASURE_CHEST", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": true, "solid": false, "hidden": true},
	"golden_scarecrow": {"name_key": "DECOR_GOLDEN_SCARECROW", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": true, "solid": false, "hidden": true},
	"ancient_statue": {"name_key": "DECOR_ANCIENT_STATUE", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": true, "solid": false, "hidden": true},
	"river_lantern": {"name_key": "DECOR_RIVER_LANTERN", "grid_size": Vector2i.ONE, "coins": 0, "wood": 0, "stone": 0, "rotatable": true, "solid": false, "hidden": true}
}

static func can_afford(id: String) -> bool:
	if not TYPES.has(id):
		return false
	var cost: Dictionary = TYPES[id]
	return Inventory.coins >= cost["coins"] and Inventory.wood >= cost["wood"] and Inventory.stone >= cost["stone"]

static func restore(value: Variant) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if not value is Array:
		return result
	for entry in value:
		if not entry is Dictionary or not TYPES.has(entry.get("decoration_id", "")):
			continue
		var id = entry.get("instance_id", "")
		var x = entry.get("position_x")
		var y = entry.get("position_y")
		var angle = entry.get("rotation", 0)
		if not id is String or not id.begins_with("decor_") or not id.trim_prefix("decor_").is_valid_int() or seen.has(id):
			continue
		if not _number(x) or not _number(y) or not _number(angle):
			continue
		if not preload("res://farm_data.gd").valid_building_position(Vector2(x,y)):
			continue
		seen[id] = true
		result.append({"instance_id": id, "decoration_id": entry["decoration_id"], "position_x": float(x), "position_y": float(y), "rotation": normalized_rotation(entry["decoration_id"],angle)})
	return result

static func normalized_rotation(id: String, angle: float) -> float:
	return fposmod(snappedf(angle,90),360) if TYPES[id]["rotatable"] else 0.0

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
