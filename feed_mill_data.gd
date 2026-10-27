extends RefCounted

const Progression = preload("res://progression_data.gd")
const QUEUE_LIMIT: int = 3
const OUTPUT_LIMIT: int = 3

static func _time(value: Variant) -> float:
	return float(value) if (value is int or value is float) and is_finite(value) and value >= 0 and value <= 1000000000000.0 else 0.0

static func _entries(value: Variant, output: bool) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry in value:
		if result.size() >= (OUTPUT_LIMIT if output else QUEUE_LIMIT):
			break
		if not entry is Dictionary or not entry.get("item") is String or not Progression.RECIPES.has(entry["item"]):
			continue
		var start: float = _time(entry.get("started_at", 0.0))
		var ready: float = _time(entry.get("ready_at", 0.0))
		if output:
			start = minf(start, ready)
		elif start <= 0.0 or ready < start:
			start = 0.0
			ready = 0.0
		result.append({"item":entry["item"], "state":"READY" if output else ("PRODUCING" if start > 0 else "QUEUED"), "started_at":start, "ready_at":ready})
	return result

static func restore(data: Dictionary) -> Dictionary:
	if data.has("queue") or data.has("outputs"):
		var restored_queue: Array = _entries(data.get("queue",[]),false)
		var restored_outputs: Array = _entries(data.get("outputs",[]),true)
		if not restored_queue.is_empty() or not restored_outputs.is_empty() or data.get("state") not in ["PRODUCING","READY"]:
			return {"queue":restored_queue, "outputs":restored_outputs}
	# A legacy one-batch station already paid its ingredients. Migrate the job
	# or finished output without charging it again or awarding anything on load.
	var queue: Array = []
	var outputs: Array = []
	var kind = data.get("production_type", "CHICKEN_FEED")
	var item: String = kind.to_lower() if kind is String else "chicken_feed"
	if not Progression.RECIPES.has(item):
		item = "chicken_feed"
	var entry: Dictionary = {"item":item, "started_at":data.get("started_at",0.0), "ready_at":data.get("ready_at",0.0)}
	if data.get("state") == "READY":
		outputs = _entries([entry],true)
	elif data.get("state") == "PRODUCING":
		queue = _entries([entry],false)
	return {"queue":queue, "outputs":outputs}
