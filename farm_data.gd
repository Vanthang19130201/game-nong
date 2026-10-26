extends RefCounted

const STARTING_PLOTS: int = 8
const MAX_PLOTS: int = 32
const GRID_ORIGIN: Vector2 = Vector2(1100, 520)
const GRID_STEP: Vector2 = Vector2(74, 58)
const PLOT_SIZE: Vector2 = Vector2(64, 48)
const FISHING_LEVEL: int = 10
const RIVER_LEFT: float = 1800.0
const SAFE_MAIN_SIDE: Vector2 = Vector2(1740, 850)
const BUILDABLE_LAND := Rect2(120, 100, 1560, 2180)
const FIELD_RESERVE := Rect2(950, 360, 820, 540)
# Stable world IDs, scene references and default positions.
const BUILDINGS: Dictionary = {
	"house": {"movable": true, "always_owned": true, "node": "House", "position": Vector2(700, 400), "scene": ""},
	"warehouse": {"movable": true, "always_owned": true, "preserve_scale": true, "node": "Warehouse", "position": Vector2(1136, 375), "scene": "res://warehouse.tscn"},
	"order_board": {"movable": true, "always_owned": true, "node": "OrderBoard", "position": Vector2(920, 420), "scene": "res://order_board.tscn"},
	"feed_mill": {"movable": true, "node": "FeedMill", "position": Vector2(1160, 1020), "scene": "res://feed_mill.tscn"},
	"chicken_coop": {"movable": true, "node": "ChickenCoop", "position": Vector2(1500, 1020), "scene": "res://chicken_coop.tscn"},
	"cow_shed": {"movable": true, "node": "CowShed", "position": Vector2(900, 1020), "scene": "res://cow_shed.tscn"},
	"dog_house": {"movable": true, "node": "DogHouse", "position": Vector2(550, 700), "scene": "res://dog_house.tscn"},
	"bakery": {"movable": true, "node": "Bakery", "position": Vector2(1250, 1320), "scene": "res://bakery.tscn"},
	"dairy": {"movable": true, "node": "Dairy", "position": Vector2(1450,1320), "scene": "res://dairy.tscn"},
	"spinning_machine": {"movable":true,"node":"SpinningMachine","position":Vector2(640,960),"scene":"res://spinning_machine.tscn"}
}

static func valid_building_position(value: Variant) -> bool:
	if not (value is Vector2) or not value.is_finite():
		return false
	# Keep the full placeholder inside the accessible mainland and out of fields.
	return BUILDABLE_LAND.has_point(value) and not FIELD_RESERVE.has_point(value)

static func valid_saved_building_position(id: String, value: Variant) -> bool:
	# Existing scene landmarks may sit at the edge of the reserved field area.
	return valid_building_position(value) or (value is Vector2 and value == BUILDINGS[id]["position"])

const PRICE_TIERS: Array[Dictionary] = [
	{"last": 8, "price": 0}, {"last": 12, "price": 100},
	{"last": 16, "price": 200}, {"last": 20, "price": 350},
	{"last": 24, "price": 500}, {"last": 28, "price": 750},
	{"last": 32, "price": 1000}
]

static func plot_id(number: int) -> String:
	return "soil_%02d" % number

static func plot_number(id: String) -> int:
	if not id.begins_with("soil_"):
		return 0
	var suffix: String = id.trim_prefix("soil_")
	return suffix.to_int() if suffix.is_valid_int() else 0

static func plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for number in range(1, MAX_PLOTS + 1):
		ids.append(plot_id(number))
	return ids

static func plot_price(number: int) -> int:
	for tier in PRICE_TIERS:
		if number >= 1 and number <= tier["last"]:
			return tier["price"]
	return -1

static func plot_position(number: int) -> Vector2:
	# Fill 4x2 blocks: first eight form 4x2; all 32 form 8x4.
	var index: int = number - 1
	var column: int = index % 4 + 4 * int((index % 16) / 8)
	var row: int = int((index % 8) / 4) + 2 * int(index / 16)
	return GRID_ORIGIN + Vector2(column * GRID_STEP.x, row * GRID_STEP.y)
