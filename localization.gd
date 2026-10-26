extends Node

const CATALOGS: Dictionary = {
	"vi": preload("res://localization/vi.gd"),
	"en": preload("res://localization/en.gd")
}
const NAME_KEYS: Dictionary = {
	"flax": "ITEM_FLAX",
	"flax seed": "ITEM_FLAX_SEED",
	"soybean": "ITEM_SOYBEAN",
	"sugarcane": "ITEM_SUGARCANE",
	"cotton": "ITEM_COTTON",
	"soybean seed": "ITEM_SOYBEAN_SEED",
	"sugarcane seed": "ITEM_SUGARCANE_SEED",
	"cotton seed": "ITEM_COTTON_SEED",
	"bakery": "BUILDING_BAKERY",
	"bread": "ITEM_BREAD",
	"corn bread": "ITEM_CORN_BREAD",
	"carrot pie": "ITEM_CARROT_PIE",
	"level": "UI_LEVEL",
	"coins": "UI_COINS",
	"exp": "UI_EXP",
	"wheat": "ITEM_WHEAT",
	"corn": "ITEM_CORN",
	"carrot": "ITEM_CARROT",
	"wheat seed": "ITEM_WHEAT_SEED",
	"corn seed": "ITEM_CORN_SEED",
	"carrot seed": "ITEM_CARROT_SEED",
	"chicken feed": "ITEM_CHICKEN_FEED",
	"cow feed": "ITEM_COW_FEED",
	"egg": "ITEM_EGG",
	"milk": "ITEM_MILK",
	"wood": "ITEM_WOOD",
	"stone": "ITEM_STONE",
	"small fish": "ITEM_SMALL_FISH",
	"river fish": "ITEM_RIVER_FISH",
	"golden fish": "ITEM_GOLDEN_FISH",
	"chicken": "ITEM_CHICKEN",
	"cow": "ITEM_COW",
	"dog": "ITEM_DOG",
	"axe": "ITEM_AXE",
	"hammer": "ITEM_HAMMER",
	"fishing rod": "ITEM_FISHING_ROD",
	"house": "BUILDING_HOUSE",
	"warehouse": "BUILDING_BARN",
	"silo": "BUILDING_SILO",
	"barn": "BUILDING_BARN",
	"feed mill": "BUILDING_FEED_MILL",
	"chicken coop": "BUILDING_CHICKEN_COOP",
	"cow shed": "BUILDING_COW_SHED",
	"dog house": "BUILDING_DOG_HOUSE",
	"fish market": "WORLD_FISH_MARKET",
	"fishing area": "WORLD_FISHING_AREA",
	"order board": "WORLD_ORDER_BOARD",
	"chicken / axe / hammer": "FEATURE_TOOLS",
	"egg orders": "FEATURE_EGG_ORDERS",
	"bakery (future)": "FEATURE_BAKERY",
	"dairy (future)": "FEATURE_DAIRY",
	"player exp": "UI_EXP"
}

func _enter_tree() -> void:
	for locale in CATALOGS:
		var translation := Translation.new()
		translation.locale = locale
		for key in CATALOGS[locale].MESSAGES:
			translation.add_message(key, CATALOGS[locale].MESSAGES[key])
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale("vi")


func display_name(value: String) -> String:
	if value.is_empty():
		return ""
	return tr(NAME_KEYS.get(value.to_lower().replace("_", " "), value))


func state(value: String) -> String:
	return "" if value.is_empty() else tr("STATE_" + value)
