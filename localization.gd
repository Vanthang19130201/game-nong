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
	"dairy": "BUILDING_DAIRY",
	"spinning machine": "BUILDING_SPINNING_MACHINE",
	"loom": "BUILDING_LOOM",
	"cotton thread": "ITEM_COTTON_THREAD",
	"cotton cloth": "ITEM_COTTON_CLOTH",
	"wool yarn": "ITEM_WOOL_YARN",
	"wool cloth": "ITEM_WOOL_CLOTH",
	"cream": "ITEM_CREAM",
	"butter": "ITEM_BUTTER",
	"cheese": "ITEM_CHEESE",
	"bread": "ITEM_BREAD",
	"corn bread": "ITEM_CORN_BREAD",
	"carrot pie": "ITEM_CARROT_PIE",
	"egg cake": "ITEM_EGG_CAKE",
	"milk cake": "ITEM_MILK_CAKE",
	"pancake": "ITEM_PANCAKE",
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
	"pig feed": "ITEM_PIG_FEED",
	"sheep feed": "ITEM_SHEEP_FEED",
	"egg": "ITEM_EGG",
	"milk": "ITEM_MILK",
	"pork": "ITEM_PORK",
	"wool": "ITEM_WOOL",
	"wood": "ITEM_WOOD",
	"stone": "ITEM_STONE",
	"small fish": "ITEM_SMALL_FISH",
	"river fish": "ITEM_RIVER_FISH",
	"golden fish": "ITEM_GOLDEN_FISH",
	"chicken": "ITEM_CHICKEN",
	"cow": "ITEM_COW",
	"pig": "ITEM_PIG",
	"sheep": "ITEM_SHEEP",
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
	"pig pen": "BUILDING_PIG_PEN",
	"sheep barn": "BUILDING_SHEEP_BARN",
	"dog house": "BUILDING_DOG_HOUSE",
	"fish market": "WORLD_FISH_MARKET",
	"fishing area": "WORLD_FISHING_AREA",
	"order board": "WORLD_ORDER_BOARD",
	"chicken / axe / hammer": "FEATURE_TOOLS",
	"egg orders": "FEATURE_EGG_ORDERS",
	"bakery (future)": "FEATURE_BAKERY",
	"dairy (future)": "FEATURE_DAIRY",
	"player exp": "UI_EXP",
	"golden wheat": "ITEM_GOLDEN_WHEAT",
	"golden corn": "ITEM_GOLDEN_CORN",
	"giant carrot": "ITEM_GIANT_CARROT",
	"moon fish": "ITEM_MOON_FISH",
	"old bottle": "ITEM_OLD_BOTTLE",
	"old boot": "ITEM_OLD_BOOT",
	"coin pouch": "ITEM_COIN_POUCH",
	"small chest": "ITEM_SMALL_CHEST",
	"lost lure": "ITEM_LOST_LURE",
	"ancient coin": "ITEM_ANCIENT_COIN",
	"ancient gem": "ITEM_ANCIENT_GEM",
	"gem pedestal": "ITEM_GEM_PEDESTAL",
	"ancient coin display": "ITEM_ANCIENT_COIN_DISPLAY",
	"map fragment": "ITEM_MAP_FRAGMENT",
	"mushroom": "ITEM_MUSHROOM",
	"mystery seed": "ITEM_MYSTERY_SEED",
	"bird": "ITEM_BIRD",
	"farm bird": "ITEM_BIRD",
	"rabbit": "ITEM_RABBIT",
	"wild rabbit": "ITEM_RABBIT",
	"butterfly": "ITEM_BUTTERFLY",
	"firefly": "ITEM_FIREFLY",
	"butterfly day": "EVENT_BUTTERFLY",
	"fishing day": "EVENT_FISHING",
	"fallen branch": "EVENT_BRANCH",
	"mushroom growth": "EVENT_MUSHROOM",
	"lost crate": "EVENT_CRATE",
	"firefly night": "EVENT_FIREFLY",
	"old well": "ITEM_OLD_WELL",
	"ancient tree": "ITEM_ANCIENT_TREE"
}

func _enter_tree() -> void:
	for locale in CATALOGS:
		var translation := Translation.new()
		translation.locale = locale
		var messages: Dictionary = CATALOGS[locale].MESSAGES
		for key in messages:
			translation.add_message(key, messages[key])
		# English copy is still being expanded.  A complete Vietnamese fallback is
		# preferable to exposing an untranslated raw key in a live UI.
		if locale == "en":
			var vietnamese: Dictionary = CATALOGS["vi"].MESSAGES
			for key in vietnamese:
				if not messages.has(key):
					translation.add_message(key, vietnamese[key])
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale("vi")


func display_name(value: String) -> String:
	if value.is_empty():
		return ""
	return tr(NAME_KEYS.get(value.to_lower().replace("_", " "), value))


func state(value: String) -> String:
	return "" if value.is_empty() else tr("STATE_" + value)
