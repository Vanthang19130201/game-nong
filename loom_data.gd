extends RefCounted

const QUEUE_LIMIT: int = 3
const RECIPES: Dictionary = {
	"cotton_cloth": {"name":"Cotton Cloth","level":18,"time":90.0,"price":600,"order_price":720,"requirements":{"cotton_thread":2}},
	"wool_cloth": {"name":"Wool Cloth","level":18,"time":120.0,"price":1500,"order_price":1800,"requirements":{"wool_yarn":2}}
}

static func restore_queue(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if result.size() >= QUEUE_LIMIT:
			break
		if not entry is Dictionary or not RECIPES.has(entry.get("item", "")):
			continue
		var started = entry.get("started_at")
		var ready = entry.get("ready_at")
		if not (started is int or started is float) or not (ready is int or ready is float):
			continue
		if not is_finite(started) or not is_finite(ready) or started < 0 or ready < started or ready > 1000000000000.0:
			continue
		result.append({"item":entry["item"],"state":"QUEUED","started_at":float(started),"ready_at":float(ready)})
	return result
