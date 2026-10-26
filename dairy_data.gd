extends RefCounted

const QUEUE_LIMIT: int = 3
const RECIPES: Dictionary = {
	"cream": {"name":"Cream", "level":15, "time":30.0, "price":80, "requirements":{"milk":2}},
	"butter": {"name":"Butter", "level":15, "time":45.0, "price":120, "requirements":{"milk":3}},
	"cheese": {"name":"Cheese", "level":15, "time":60.0, "price":180, "requirements":{"milk":4}}
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
		var start = entry.get("started_at")
		var ready = entry.get("ready_at")
		if not (start is int or start is float) or not (ready is int or ready is float):
			continue
		if not is_finite(start) or not is_finite(ready) or start < 0 or ready < start or ready > 1000000000000.0:
			continue
		result.append({"item":entry["item"], "state":"QUEUED", "started_at":float(start), "ready_at":float(ready)})
	return result
