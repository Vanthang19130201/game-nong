extends RefCounted

const ZONES: Dictionary = {
	"farm_core": {"name_key": "LAND_CORE", "area": Rect2(0,0,1800,1480), "cost_coins": 0, "cost_wood": 0, "cost_stone": 0, "adjacent_zone_ids": ["land_01","land_02","land_03"]},
	"land_01": {"name_key": "LAND_01", "area": Rect2(0,1480,600,460), "cost_coins": 500, "cost_wood": 10, "cost_stone": 5, "adjacent_zone_ids": ["farm_core","land_02","land_04"]},
	"land_02": {"name_key": "LAND_02", "area": Rect2(600,1480,600,460), "cost_coins": 1000, "cost_wood": 20, "cost_stone": 10, "adjacent_zone_ids": ["farm_core","land_01","land_03","land_05"]},
	"land_03": {"name_key": "LAND_03", "area": Rect2(1200,1480,600,460), "cost_coins": 2000, "cost_wood": 30, "cost_stone": 15, "adjacent_zone_ids": ["farm_core","land_02","land_06"]},
	"land_04": {"name_key": "LAND_04", "area": Rect2(0,1940,600,460), "cost_coins": 3500, "cost_wood": 45, "cost_stone": 25, "adjacent_zone_ids": ["land_01","land_05"]},
	"land_05": {"name_key": "LAND_05", "area": Rect2(600,1940,600,460), "cost_coins": 5500, "cost_wood": 60, "cost_stone": 35, "adjacent_zone_ids": ["land_02","land_04","land_06"]},
	"land_06": {"name_key": "LAND_06", "area": Rect2(1200,1940,600,460), "cost_coins": 8000, "cost_wood": 80, "cost_stone": 50, "adjacent_zone_ids": ["land_03","land_05"]}
}

static func restore_unlocked(value: Variant) -> Array[String]:
	var result: Array[String] = ["farm_core"]
	if value is Array:
		for id in value:
			if id is String and ZONES.has(id) and id not in result:
				result.append(id)
	return result

static func zone_at(position: Vector2) -> String:
	for id in ZONES:
		if ZONES[id]["area"].has_point(position):
			return id
	return ""

static func is_adjacent(id: String, unlocked: Array) -> bool:
	if not ZONES.has(id):
		return false
	for neighbor in ZONES[id]["adjacent_zone_ids"]:
		if neighbor in unlocked:
			return true
	return false

# Sum non-overlapping owned rectangles so a footprint may straddle two owned
# zones, but cannot cover even a small strip of locked or out-of-map land.
static func owns_rect(footprint: Rect2, unlocked: Array) -> bool:
	var covered: float = 0.0
	for id in ZONES:
		if id in unlocked:
			covered += footprint.intersection(ZONES[id]["area"]).get_area()
	return covered + 0.01 >= footprint.get_area()

static func resource_access(position: Vector2, unlocked: Array) -> bool:
	var id: String = zone_at(position)
	# Fishing/other progression zones keep their existing access rules.
	return id.is_empty() or id in unlocked
