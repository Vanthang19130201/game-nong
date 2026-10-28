extends RefCounted

const ITEMS: Dictionary = {
	"old_bottle": {"name": "Old Bottle", "rarity": "common", "sell_price": 8, "description": "An old bottle polished smooth by the river.", "weight": 30},
	"old_boot": {"name": "Old Boot", "rarity": "common", "sell_price": 4, "description": "A boot with a story nobody remembers.", "weight": 26},
	"coin_pouch": {"name": "Coin Pouch", "rarity": "uncommon", "sell_price": 45, "description": "A small pouch with a few old coins.", "weight": 20},
	"small_chest": {"name": "Small Chest", "rarity": "rare", "sell_price": 100, "description": "A tiny chest with a warm golden glint.", "weight": 9},
	"lost_lure": {"name": "Lost Lure", "rarity": "uncommon", "sell_price": 55, "description": "A useful old lure that anglers will still pay for.", "weight": 10},
	"ancient_coin": {"name": "Ancient Coin", "rarity": "rare", "sell_price": 700, "description": "A valuable coin from a time before the farm.", "weight": 4},
	"map_fragment": {"name": "Map Fragment", "rarity": "rare", "sell_price": 0, "description": "Collect 3 fragments to reveal a hidden treasure.", "weight": 1},
	"ancient_gem": {"name": "Ancient Gem", "rarity": "ultra_rare", "sell_price": 10000, "description": "A priceless relic that can also unlock a Gem Pedestal.", "weight": 0}
}

const BASE_CATCH_CHANCE: float = 0.07
const ANCIENT_GEM_CHANCE: float = 0.01
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_ULTRA_RARE := "ultra_rare"

# These are rare *containers*, not separate 1% rolls for every ordinary pickup.
# Each source has to reach its existing rare-reward branch before using this table.
const RARE_CONTAINER_ITEMS: Array[String] = ["ancient_coin", "small_chest", "coin_pouch"]


static func rarity_of(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("rarity", RARITY_COMMON))


static func is_rare_or_better(item_id: String) -> bool:
	return rarity_of(item_id) in [RARITY_RARE, RARITY_ULTRA_RARE]


static func roll_rare_container(rng: RandomNumberGenerator) -> String:
	# The sole configured Ultra Rare roll: one percent after a caller reaches a
	# persisted rare-reward container. This keeps the global gem frequency low.
	if rng.randf() < ANCIENT_GEM_CHANCE:
		return "ancient_gem"
	return RARE_CONTAINER_ITEMS[rng.randi_range(0, RARE_CONTAINER_ITEMS.size() - 1)]


static func coin_pouch_coins(nonce: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x43504F554348 + maxi(1, nonce) * 7919
	return rng.randi_range(55, 95)


static func small_chest_reward(nonce: int, available_seeds: Array[String]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x534D4348455354 + maxi(1, nonce) * 104729
	var roll := rng.randf()
	if roll < 0.45:
		return {"type": "coins", "amount": rng.randi_range(90, 180)}
	if roll < 0.75 and not available_seeds.is_empty():
		return {"type": "item", "item": available_seeds[rng.randi_range(0, available_seeds.size() - 1)], "amount": rng.randi_range(1, 2)}
	if roll < 0.94:
		return {"type": "item", "item": "coin_pouch" if rng.randf() < 0.5 else "old_bottle", "amount": 1}
	# Chest rare rewards remain a bounded, useful treasure result. Ancient Gem
	# stays exclusive to the world rare-container table below.
	return {"type": "item", "item": "ancient_coin", "amount": 1}

static func roll(rng: RandomNumberGenerator, rain_bonus: float = 0.0, event_bonus: float = 0.0) -> String:
	if rng.randf() >= minf(0.12, BASE_CATCH_CHANCE + rain_bonus + event_bonus):
		return ""
	# A fishing treasure first reaches the existing treasure gate, then has a
	# small rare-container branch. Gem determination is delegated to the same
	# 1% table used by other persisted containers.
	if rng.randf() < 0.12:
		return roll_rare_container(rng)
	var total: int = 0
	for info in ITEMS.values():
		total += int(info.get("weight", 0))
	var value := rng.randi_range(1, total)
	for id in ITEMS:
		value -= int(ITEMS[id].get("weight", 0))
		if value <= 0:
			return id
	return "old_bottle"
