extends RefCounted

const CATEGORIES: Array[Dictionary] = [
	{"id":"crops", "title_key":"COLLECTION_CROPS"},
	{"id":"fish", "title_key":"COLLECTION_FISH"},
	{"id":"animal_products", "title_key":"COLLECTION_ANIMAL_PRODUCTS"},
	{"id":"production_items", "title_key":"COLLECTION_PRODUCTION"},
	{"id":"rare_finds", "title_key":"COLLECTION_RARE"},
	{"id":"treasures", "title_key":"COLLECTION_TREASURES"},
	{"id":"nature", "title_key":"COLLECTION_NATURE"},
	{"id":"special_events", "title_key":"COLLECTION_EVENTS"}
]

const ITEMS: Dictionary = {
	"crops": ["wheat","corn","carrot","soybean","sugarcane","cotton","flax"],
	"fish": ["small_fish","river_fish","golden_fish","moon_fish"],
	"animal_products": ["egg","milk","chicken_feed","cow_feed"],
	"production_items": ["bread","corn_bread","carrot_pie","egg_cake","milk_cake","pancake","cream","butter","cheese","cotton_thread"],
	"rare_finds": ["golden_wheat","giant_carrot","golden_corn"],
	"treasures": ["old_bottle","old_boot","coin_pouch","small_chest","lost_lure","ancient_coin","map_fragment"],
	# Only entries with a real discovery path are listed here.
	"nature": ["mushroom", "bird", "rabbit", "butterfly", "firefly"],
	"special_events": ["butterfly_day","fishing_day","fallen_branch","mushroom_growth","lost_crate","firefly_night"]
}

const ITEM_CATEGORIES: Dictionary = {
	"wheat":"crops", "corn":"crops", "carrot":"crops", "soybean":"crops", "sugarcane":"crops", "cotton":"crops", "flax":"crops",
	"small_fish":"fish", "river_fish":"fish", "golden_fish":"fish", "moon_fish":"fish",
	"egg":"animal_products", "milk":"animal_products", "chicken_feed":"animal_products", "cow_feed":"animal_products",
	"golden_wheat":"rare_finds", "giant_carrot":"rare_finds", "golden_corn":"rare_finds",
	"old_bottle":"treasures", "old_boot":"treasures", "coin_pouch":"treasures", "small_chest":"treasures", "lost_lure":"treasures", "ancient_coin":"treasures", "map_fragment":"treasures",
	"mushroom":"nature", "bird":"nature", "rabbit":"nature", "butterfly":"nature", "firefly":"nature"
}

const DESCRIPTIONS: Dictionary = {
	"old_bottle": "COLLECTION_DESC_OLD_BOTTLE",
	"coin_pouch": "COLLECTION_DESC_COIN_POUCH",
	"small_chest": "COLLECTION_DESC_SMALL_CHEST",
	"map_fragment": "COLLECTION_DESC_MAP_FRAGMENT",
	"golden_wheat": "COLLECTION_DESC_RARE_CROP",
	"golden_corn": "COLLECTION_DESC_RARE_CROP",
	"giant_carrot": "COLLECTION_DESC_RARE_CROP",
	"mushroom": "COLLECTION_DESC_MUSHROOM",
	"bird": "COLLECTION_DESC_BIRD",
	"rabbit": "COLLECTION_DESC_RABBIT",
	"butterfly": "COLLECTION_DESC_BUTTERFLY",
	"firefly": "COLLECTION_DESC_FIREFLY"
}

static func category_for_item(item_id: String) -> String:
	if ITEM_CATEGORIES.has(item_id):
		return ITEM_CATEGORIES[item_id]
	if item_id in ITEMS["production_items"]:
		return "production_items"
	return ""
