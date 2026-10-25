extends RefCounted

const STARTING_PLOTS: int = 8
const MAX_PLOTS: int = 32
const GRID_ORIGIN: Vector2 = Vector2(1100, 520)
const GRID_STEP: Vector2 = Vector2(74, 58)
const FISHING_LEVEL: int = 10
const RIVER_LEFT: float = 1800.0
const SAFE_MAIN_SIDE: Vector2 = Vector2(1740, 850)
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
