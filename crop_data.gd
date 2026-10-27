extends RefCounted

static var crop_time_scale: float = 1.0

# All crop rules live here. Sell prices must exceed seed prices.
const CROPS: Dictionary = {
	"WHEAT": {
		"category": "food_crop",
		"name": "Wheat", "unlock_level": 1, "grow_time": 60.0, "starting_seeds": 10,
		"seed_buy_price": 5, "sell_price": 10, "harvest_exp": 10
	},
	"CORN": {
		"category": "food_crop",
		"name": "Corn", "unlock_level": 2, "grow_time": 120.0,
		"seed_buy_price": 10, "sell_price": 22, "harvest_exp": 20
	},
	"CARROT": {
		"category": "food_crop",
		"name": "Carrot", "unlock_level": 3, "grow_time": 240.0,
		"seed_buy_price": 15, "sell_price": 35, "harvest_exp": 30
	},
	"SOYBEAN": {
		"category": "animal_feed_crop",
		"name": "Soybean", "unlock_level": 6, "grow_time": 360.0,
		"seed_buy_price": 20, "sell_price": 48, "harvest_exp": 40
	},
	"SUGARCANE": {
		"category": "food_crop",
		"name": "Sugarcane", "unlock_level": 8, "grow_time": 600.0,
		"seed_buy_price": 25, "sell_price": 65, "harvest_exp": 50
	},
	"COTTON": {
		"category": "industrial_crop",
		"name": "Cotton", "unlock_level": 12, "grow_time": 900.0,
		"seed_buy_price": 35, "sell_price": 90, "harvest_exp": 60
	},
	"FLAX": {
		"id": "flax", "category": "industrial_crop",
		"name": "Flax", "unlock_level": 18, "grow_time": 2700.0,
		"seed_buy_price": 50, "sell_price": 140, "harvest_exp": 80
	}
}

const RARE_VARIANTS: Dictionary = {
	"golden_wheat": {"base_crop":"WHEAT", "name":"Golden Wheat", "chance":0.015, "sell_price":30, "rarity":"rare"},
	"golden_corn": {"base_crop":"CORN", "name":"Golden Corn", "chance":0.025, "sell_price":66, "rarity":"rare"},
	"giant_carrot": {"base_crop":"CARROT", "name":"Giant Carrot", "chance":0.02, "sell_price":100, "rarity":"rare"}
}

static func grow_seconds(crop: String) -> float:
	var time_scale: float = crop_time_scale if is_finite(crop_time_scale) and crop_time_scale > 0.0 else 1.0
	return CROPS[crop]["grow_time"] * time_scale

static func inventory_defaults() -> Dictionary:
	var result: Dictionary = {}
	for crop in CROPS:
		result[crop.to_lower()] = 0
		result[crop.to_lower() + "_seed"] = CROPS[crop].get("starting_seeds", 0)
	result["mystery_seed"] = 0
	for id in RARE_VARIANTS:
		result[id] = 0
	return result

static func silo_items() -> Array[String]:
	var result: Array[String] = []
	for crop in CROPS:
		result.append(crop.to_lower() + "_seed")
		result.append(crop.to_lower())
	result.append("mystery_seed")
	for id in RARE_VARIANTS:
		result.append(id)
	return result


static func roll_rare_variant(crop: String, stable_key: String) -> String:
	var rng := RandomNumberGenerator.new()
	# FNV-1a over this harvest's stable identity avoids global RNG/save-scum rerolls.
	var seed_value: int = 2166136261
	for byte_value in stable_key.to_utf8_buffer():
		seed_value = int((seed_value ^ int(byte_value)) * 16777619) & 0x7fffffff
	rng.seed = maxi(1, seed_value)
	for id in RARE_VARIANTS:
		var info: Dictionary = RARE_VARIANTS[id]
		if info["base_crop"] == crop and rng.randf() < float(info["chance"]):
			return id
	return ""
