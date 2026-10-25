extends RefCounted

const UNLOCK_LEVEL: int = 6
const TOOLS: Dictionary = {
	"axe": {"name": "Axe", "resource": "wood", "levels": {
		1: {"time": 3.0, "cost": 0}, 2: {"time": 2.2, "cost": 500},
		3: {"time": 1.5, "cost": 1500}, 4: {"time": 1.0, "cost": 4000}
	}},
	"hammer": {"name": "Hammer", "resource": "stone", "levels": {
		1: {"time": 3.5, "cost": 0}, 2: {"time": 2.6, "cost": 600},
		3: {"time": 1.8, "cost": 1800}, 4: {"time": 1.1, "cost": 4500}
	}}
}