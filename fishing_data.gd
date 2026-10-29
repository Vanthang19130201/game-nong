extends RefCounted

const MIN_BITE_DELAY: float = 1.0
const MAX_BITE_DELAY: float = 5.0
const RESULT_TIME: float = 0.8
const COOLDOWN_TIME: float = 1.5
const SESSION_DISTANCE: float = 125.0
const ATTEMPTS_PER_CYCLE: int = 15
const CYCLE_SECONDS: int = 43200
const ROD_LEVELS: Dictionary = {
	1: {"cost": 0, "bite_window": 0.5},
	2: {"cost": 800, "bite_window": 0.6},
	3: {"cost": 2000, "bite_window": 0.7},
	4: {"cost": 5000, "bite_window": 0.8}
}

# Only these IDs are rolled for a new catch. Their weights total 100.
const CATCHABLE_FISH_IDS: Array[String] = [
	"tilapia", "perch", "catfish", "loach", "snakehead", "salmon", "koi_orange", "koi_gold", "moon_fish"
]

const FISH: Dictionary = {
	"tilapia": {"name": "tilapia", "weight": 21, "rarity": "common", "difficulty": "easy", "sell_price": 30, "order_exp": 5, "order_max": 3, "asset_path": "res://assets/fishing/fish/tilapia.png"},
	"perch": {"name": "perch", "weight": 17, "rarity": "common", "difficulty": "easy", "sell_price": 35, "order_exp": 5, "order_max": 3, "asset_path": "res://assets/fishing/fish/perch.png"},
	"catfish": {"name": "catfish", "weight": 15, "rarity": "common", "difficulty": "medium", "sell_price": 45, "order_exp": 5, "order_max": 2, "asset_path": "res://assets/fishing/fish/catfish.png"},
	"loach": {"name": "loach", "weight": 13, "rarity": "uncommon", "difficulty": "medium", "sell_price": 50, "order_exp": 6, "order_max": 2, "asset_path": "res://assets/fishing/fish/loach.png"},
	"snakehead": {"name": "snakehead", "weight": 11, "rarity": "uncommon", "difficulty": "medium", "sell_price": 60, "order_exp": 6, "order_max": 2, "asset_path": "res://assets/fishing/fish/snakehead.png"},
	"salmon": {"name": "salmon", "weight": 8, "rarity": "rare", "difficulty": "hard", "sell_price": 85, "order_exp": 8, "order_max": 1, "asset_path": "res://assets/fishing/fish/salmon.png"},
	"koi_orange": {"name": "koi_orange", "weight": 7, "rarity": "rare", "difficulty": "hard", "sell_price": 120, "order_exp": 8, "order_max": 1, "asset_path": "res://assets/fishing/fish/koi_orange.png"},
	"koi_gold": {"name": "koi_gold", "weight": 3, "rarity": "legendary", "difficulty": "hard", "sell_price": 250, "order_exp": 12, "order_max": 1, "asset_path": "res://assets/fishing/fish/koi_gold.png"},
	"moon_fish": {"name": "moon_fish", "weight": 5, "rarity": "rare", "difficulty": "hard", "sell_price": 140, "order_exp": 10, "order_max": 1, "asset_path": "res://assets/fishing/fish/moon_fish.png"}
}
