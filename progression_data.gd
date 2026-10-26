extends RefCounted

const FEATURES: Dictionary = {
	"Wheat": 1, "Corn": 2, "Carrot": 3, "Feed Mill": 4,
	"Chicken Coop": 5, "Chicken / Axe / Hammer": 6, "Egg Orders": 7,
	"Cow Shed": 8, "Cow": 9, "Milk": 10, "Bakery": 12, "Dairy (future)": 15
}
const BUILDINGS: Dictionary = {
	"feed_mill": {"name": "Feed Mill", "level": 4, "price": 500},
	"chicken_coop": {"name": "Chicken Coop", "level": 5, "price": 800},
	"cow_shed": {"name": "Cow Shed", "level": 8, "price": 1500},
	"bakery": {"name": "Bakery", "level": 12, "price": 3000}
}
const ANIMALS: Dictionary = {
	"chicken": {"name": "Chicken", "building": "chicken_coop", "level": 6, "capacity": 3, "buy": 150, "sell": 100},
	"cow": {"name": "Cow", "building": "cow_shed", "level": 9, "capacity": 3, "buy": 300, "sell": 200}
}
const RECIPES: Dictionary = {
	"chicken_feed": {"name": "Chicken Feed", "level": 4, "time": 10.0, "requirements": {"wheat": 1, "corn": 1}},
	"cow_feed": {"name": "Cow Feed", "level": 8, "time": 15.0, "requirements": {"corn": 2, "carrot": 1}}
}
const PRODUCTS: Dictionary = {
	"chicken_coop": {"animal": "chicken", "feed": "chicken_feed", "item": "egg", "level": 6, "time": 20.0, "exp": 5},
	"cow_shed": {"animal": "cow", "feed": "cow_feed", "item": "milk", "level": 10, "time": 30.0, "exp": 10}
}
# Costs are for the NEXT level. First production-building purchase stays Coins-only.
const UPGRADES: Dictionary = {
	"chicken_coop": {
		2: {"wood": 20, "stone": 10, "coins": 500, "capacity": 5},
		3: {"wood": 40, "stone": 20, "coins": 1000, "capacity": 8}
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
const DOG_HOUSE_COST: Dictionary = {"wood": 15, "stone": 5, "coins": 0}
# Future hooks only: these features are not implemented yet.
const HOUSE_FUTURE_FEATURES: Dictionary = {
	2: ["wardrobe", "basic_furniture"],
	3: ["extra_room", "more_decorations"],
	4: ["couple_marriage_room"]
}
const RESOURCE_RESPAWN: Dictionary = {"wood": 60.0, "stone": 90.0}
