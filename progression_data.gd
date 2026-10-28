extends RefCounted

const FarmData = preload("res://farm_data.gd")
const CropData = preload("res://crop_data.gd")
const ToolData = preload("res://tool_data.gd")
const BakeryData = preload("res://bakery_data.gd")
const DairyData = preload("res://dairy_data.gd")
const SpinningData = preload("res://spinning_machine_data.gd")
const AnimalData = preload("res://animal_data.gd")

static var FEATURES: Dictionary = _features()

static func _features() -> Dictionary:
	var result: Dictionary = {
	"Feed Mill": 4,
	"Chicken Coop": 5, "Chicken / Axe / Hammer": 6, "Egg Orders": 7,
	"Cow Shed": 8, "Cow": 9, "Milk": 10, "Bakery": 3, "Dairy": 15, "Spinning Machine": 17
	}
	for crop in preload("res://crop_data.gd").CROPS.values():
		result[crop["name"]] = crop["unlock_level"]
	return result


static func unlocks_for_level(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for crop_id in CropData.CROPS:
		var crop: Dictionary = CropData.CROPS[crop_id]
		if int(crop["unlock_level"]) == level:
			_add_unlock(result, crop_id.to_lower(), crop["name"], "crop")
	for id in BUILDINGS:
		var building: Dictionary = BUILDINGS[id]
		if int(building["level"]) == level:
			_add_unlock(result, id, building["name"], "building")
	for id in ANIMALS:
		var animal: Dictionary = ANIMALS[id]
		if int(animal["level"]) == level:
			_add_unlock(result, id, animal["name"], "animal")
	for id in ToolData.TOOLS:
		if ToolData.UNLOCK_LEVEL == level:
			_add_unlock(result, id, ToolData.TOOLS[id]["name"], "tool")
	for id in RECIPES:
		if int(RECIPES[id]["level"]) == level:
			_add_unlock(result, id, RECIPES[id]["name"], "recipe")
	for recipes in [BakeryData.RECIPES, DairyData.RECIPES, SpinningData.RECIPES]:
		for id in recipes:
			if int(recipes[id]["level"]) == level:
				_add_unlock(result, id, recipes[id]["name"], "recipe")
	for id in PRODUCTS:
		var product: Dictionary = PRODUCTS[id]
		if int(product["level"]) == level and product["item"] == "milk":
			_add_unlock(result, product["item"], "Milk", "product")
	if FarmData.FISHING_LEVEL == level:
		_add_unlock(result, "fishing_area", "Fishing Area", "zone")
		_add_unlock(result, "fishing_rod", "Fishing Rod", "tool")
	# This legacy progression entry is the source of truth for the order feature.
	if FEATURES.get("Egg Orders", -1) == level:
		_add_unlock(result, "egg_orders", "Egg Orders", "feature")
	return result


static func _add_unlock(result: Array[Dictionary], id: String, name: String, type: String) -> void:
	for existing in result:
		if existing["id"] == id:
			return
	result.append({"id": id, "name": name, "type": type})


static func reward_for_level(level: int) -> Dictionary:
	var coins: int = 50 + level * 25
	if level > 0 and level % 5 == 0:
		coins += 100
	return {"coins": coins}
const BUILDINGS: Dictionary = {
	"feed_mill": {"name": "Feed Mill", "level": 4, "price": 500},
	"chicken_coop": {"name": "Chicken Coop", "level": 5, "price": 800},
	"cow_shed": {"name": "Cow Shed", "level": 8, "price": 1500},
	"pig_pen": {"name": "Pig Pen", "level": 11, "price": 2500, "placement_required": true},
	"sheep_barn": {"name": "Sheep Barn", "level": 13, "price": 2100, "placement_required": true},
	"bakery": {"name": "Bakery", "level": 3, "price": 400},
	"dairy": {"name": "Dairy", "level": 15, "price": 4500, "placement_required": true},
	"spinning_machine": {"name":"Spinning Machine","level":17,"price":5000,"placement_required":true},
	"loom": {"name":"Loom","level":18,"price":6000,"placement_required":true}
}
const ANIMALS: Dictionary = {
	"chicken": {"name": "Chicken", "building": "chicken_coop", "level": 6, "capacity": 3, "buy": 150, "sell": 100},
	"cow": {"name": "Cow", "building": "cow_shed", "level": 9, "capacity": 3, "buy": 300, "sell": 200},
	"pig": {"name":"Pig","building":"pig_pen","level":12,"capacity":3,"buy":575,"sell":350},
	"sheep": {"name":"Sheep","building":"sheep_barn","level":14,"capacity":3,"buy":450,"sell":300}
}
const RECIPES: Dictionary = {
	"chicken_feed": {"name": "Chicken Feed", "level": 4, "time": 10.0, "requirements": {"wheat": 1, "corn": 1}},
	"cow_feed": {"name": "Cow Feed", "level": 8, "time": 15.0, "requirements": {"corn": 2, "carrot": 1}},
	"pig_feed": {"name":"Pig Feed","level":11,"time":25.0,"requirements":{"corn":2,"soybean":2}},
	"sheep_feed": {"name":"Sheep Feed","level":13,"time":30.0,"requirements":{"wheat":1,"soybean":2}}
}
const PRODUCTS: Dictionary = {
	"chicken_coop": {"animal": "chicken", "feed": "chicken_feed", "item": "egg", "level": 6, "time": 600.0, "exp": 5},
	"cow_shed": {"animal": "cow", "feed": "cow_feed", "item": "milk", "level": 10, "time": 900.0, "exp": 10},
	"pig_pen": {"animal":"pig","feed":"pig_feed","item":"pork","level":12,"time":600.0,"exp":18,"harvest_animal":true},
	"sheep_barn": {"animal":"sheep","feed":"sheep_feed","item":"wool","level":14,"time":1200.0,"exp":14}
}
# Costs are for the NEXT level. First production-building purchase stays Coins-only.
const UPGRADES: Dictionary = {
	"chicken_coop": {
		2: {"wood": 20, "stone": 10, "coins": 500, "capacity": 5},
		3: {"wood": 40, "stone": 20, "coins": 1000, "capacity": 8}
	},
	"pig_pen": {
		2: {"wood":50,"stone":25,"coins":1400,"capacity":5},
		3: {"wood":90,"stone":45,"coins":2600,"capacity":8}
	},
	"sheep_barn": {
		2: {"wood":45,"stone":20,"coins":1200,"capacity":5},
		3: {"wood":80,"stone":40,"coins":2200,"capacity":8}
	},
	"cow_shed": {
		2: {"wood": 30, "stone": 15, "coins": 800, "capacity": 5},
		3: {"wood": 60, "stone": 30, "coins": 1600, "capacity": 8}
	},
	"house": {
		2: {"wood": 30, "stone": 15, "coins": 500},
		3: {"wood": 60, "stone": 30, "coins": 1500},
		4: {"wood": 100, "stone": 50, "coins": 3500}
	},
	"silo": {
		2: {"wood": 10, "stone": 5, "coins": 200, "capacity": 50},
		3: {"wood": 20, "stone": 10, "coins": 200, "capacity": 80}
	},
	"barn": {
		2: {"wood": 8, "stone": 8, "coins": 250, "capacity": 35},
		3: {"wood": 20, "stone": 10, "coins": 200, "capacity": 60}
	}
}
const DOG_HOUSE_COST: Dictionary = {"wood": 5, "stone": 0, "coins": 0}
# Future hooks only: these features are not implemented yet.
const HOUSE_FUTURE_FEATURES: Dictionary = {
	2: ["wardrobe", "basic_furniture"],
	3: ["extra_room", "more_decorations"],
	4: ["couple_marriage_room"]
}
const RESOURCE_RESPAWN: Dictionary = {"wood": 60.0, "stone": 90.0}
