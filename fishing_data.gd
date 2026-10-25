extends RefCounted

const MIN_BITE_DELAY: float = 1.0
const MAX_BITE_DELAY: float = 5.0
const RESULT_TIME: float = 0.8
const COOLDOWN_TIME: float = 1.5
const SESSION_DISTANCE: float = 125.0
const ROD_LEVELS: Dictionary = {
	1: {"cost": 0, "bite_window": 1.00},
	2: {"cost": 800, "bite_window": 1.10},
	3: {"cost": 2000, "bite_window": 1.20},
	4: {"cost": 5000, "bite_window": 1.30}
}
# Future per-fish bite_window can override the rod window; v1 uses one mechanic.
const FISH: Dictionary = {
	"small_fish": {"name": "Small Fish", "weight": 60, "rarity": "common", "difficulty": "easy"},
	"river_fish": {"name": "River Fish", "weight": 30, "rarity": "uncommon", "difficulty": "medium"},
	"golden_fish": {"name": "Golden Fish", "weight": 10, "rarity": "rare", "difficulty": "hard"}
}
