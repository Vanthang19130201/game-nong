extends RefCounted

const QUEUE_LIMIT: int = 3
const RECIPES: Dictionary = {
	"bread": {"name": "Bánh mì", "level": 12, "time": 20.0, "price": 32, "requirements": {"wheat": 2}},
	"corn_bread": {"name": "Bánh mì bắp", "level": 13, "time": 30.0, "price": 48, "requirements": {"wheat": 1, "corn": 1}},
	"carrot_pie": {"name": "Bánh cà rốt", "level": 14, "time": 45.0, "price": 80, "requirements": {"wheat": 2, "carrot": 1}}
}

static func restore_queue(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if result.size() == QUEUE_LIMIT:
			break
		if not entry is Dictionary or not RECIPES.has(entry.get("item", "")):
			continue
		var started = entry.get("started_at")
		var ready = entry.get("ready_at")
		if not (started is float or started is int) or not (ready is float or ready is int):
			continue
		if not is_finite(started) or not is_finite(ready) or started < 0 or ready < started or ready > 1000000000000.0:
			continue
		result.append({"item": entry["item"], "state": "QUEUED", "started_at": float(started), "ready_at": float(ready)})
	return result
