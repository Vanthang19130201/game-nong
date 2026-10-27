extends RefCounted

const EVENTS: Dictionary = {
	"butterfly_day": {"name_key": "EVENT_BUTTERFLY", "weight": 22},
	"fishing_day": {"name_key": "EVENT_FISHING", "weight": 18},
	"fallen_branch": {"name_key": "EVENT_BRANCH", "weight": 18},
	"mushroom_growth": {"name_key": "EVENT_MUSHROOM", "weight": 16},
	"lost_crate": {"name_key": "EVENT_CRATE", "weight": 12},
	"firefly_night": {"name_key": "EVENT_FIREFLY", "weight": 14}
}
const EVENT_CHANCE: float = 0.22
