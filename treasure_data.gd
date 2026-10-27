extends RefCounted

const ITEMS: Dictionary = {
	"old_bottle": {"name": "Old Bottle", "rarity": "common", "sell_price": 8, "description": "An old bottle polished smooth by the river.", "weight": 30},
	"old_boot": {"name": "Old Boot", "rarity": "common", "sell_price": 4, "description": "A boot with a story nobody remembers.", "weight": 26},
	"coin_pouch": {"name": "Coin Pouch", "rarity": "uncommon", "sell_price": 45, "description": "A small pouch with a few old coins.", "weight": 20},
	"small_chest": {"name": "Small Chest", "rarity": "rare", "sell_price": 100, "description": "A tiny chest with a warm golden glint.", "weight": 9},
	"lost_lure": {"name": "Lost Lure", "rarity": "uncommon", "sell_price": 0, "description": "A useful old lure, still in good shape.", "weight": 10},
	"ancient_coin": {"name": "Ancient Coin", "rarity": "rare", "sell_price": 70, "description": "A coin from a time before the farm.", "weight": 4},
	"map_fragment": {"name": "Map Fragment", "rarity": "rare", "sell_price": 0, "description": "A piece of a map with no clear destination.", "weight": 1}
}

const BASE_CATCH_CHANCE: float = 0.07

static func roll(rng: RandomNumberGenerator, rain_bonus: float = 0.0, event_bonus: float = 0.0) -> String:
	if rng.randf() >= minf(0.12, BASE_CATCH_CHANCE + rain_bonus + event_bonus):
		return ""
	var total: int = 0
	for info in ITEMS.values():
		total += int(info["weight"])
	var value := rng.randi_range(1, total)
	for id in ITEMS:
		value -= int(ITEMS[id]["weight"])
		if value <= 0:
			return id
	return "old_bottle"
