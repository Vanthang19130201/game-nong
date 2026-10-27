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
# Future per-fish bite_window can override the rod window; v1 uses one mechanic.
const FISH: Dictionary = {
	"small_fish": {"name": "Small Fish", "weight": 60, "rarity": "common", "difficulty": "easy", "sell_price": 25, "order_exp": 5, "order_max": 3},
	"river_fish": {"name": "River Fish", "weight": 30, "rarity": "uncommon", "difficulty": "medium", "sell_price": 40, "order_exp": 5, "order_max": 2},
	"golden_fish": {"name": "Golden Fish", "weight": 10, "rarity": "rare", "difficulty": "hard", "sell_price": 100, "order_exp": 5, "order_max": 1},
	"moon_fish": {"name": "Moon Fish", "weight": 4, "rarity": "rare", "difficulty": "hard", "sell_price": 140, "order_exp": 8, "order_max": 1, "time_start": 20.0, "time_end": 5.0, "weather": ["cloudy", "rain"]}
}
