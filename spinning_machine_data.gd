extends RefCounted

const QUEUE_LIMIT: int = 3
const RECIPES: Dictionary = {
	"cotton_thread": {"name":"Cotton Thread", "level":17, "time":90.0, "price":360, "order_price":432, "requirements":{"cotton":3}},
	"wool_yarn": {"name":"Wool Yarn", "level":17, "time":120.0, "price":650, "order_price":780, "requirements":{"wool":3}}
}

static func restore_queue(value: Variant, limit: int = QUEUE_LIMIT) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if result.size() >= maxi(0, limit):
			break
		if not entry is Dictionary or not RECIPES.has(entry.get("item", "")):
			continue
		var start = entry.get("started_at")
		var ready = entry.get("ready_at")
		if not (start is int or start is float) or not (ready is int or ready is float):
			continue
		if not is_finite(start) or not is_finite(ready) or start < 0 or ready < start or ready > 1000000000000.0:
			continue
		result.append({"item":entry["item"],"state":"QUEUED","started_at":float(start),"ready_at":float(ready)})
	return result
