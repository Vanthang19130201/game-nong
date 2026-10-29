extends "res://production_station.gd"

const Data = preload("res://feed_mill_data.gd")
var queue: Array = []
var outputs: Array = []
var collecting: bool = false

func get_save_data() -> Dictionary:
	_copy_active_timestamps()
	var data: Dictionary = super.get_save_data()
	data["queue"] = queue.duplicate(true)
	data["outputs"] = outputs.duplicate(true)
	return data

func restore_save_data(data: Dictionary) -> void:
	var restored: Dictionary = Data.restore(data)
	queue = restored["queue"]
	outputs = restored["outputs"]
	collecting = false
	_reconcile()
	_update_display()

func can_produce(recipe: String = "chicken_feed") -> bool:
	if collecting or not Inventory.owns_feed_mill or queue.size() >= Data.QUEUE_LIMIT or not Progression.RECIPES.has(recipe):
		return false
	var info: Dictionary = Progression.RECIPES[recipe]
	if Inventory.player_level < info["level"]:
		return false
	for ingredient in info["requirements"]:
		if Inventory.get(ingredient) < info["requirements"][ingredient]:
			return false
	return true

func produce(recipe: String = "chicken_feed") -> bool:
	if not can_produce(recipe):
		return Inventory.fail(tr("ERROR_STATION_PRODUCE"))
	for ingredient in Progression.RECIPES[recipe]["requirements"]:
		Inventory.set(ingredient, Inventory.get(ingredient)-Progression.RECIPES[recipe]["requirements"][ingredient])
	queue.append({"item":recipe, "state":"QUEUED", "started_at":0.0, "ready_at":0.0})
	_reconcile()
	_update_display()
	Inventory.inventory_changed.emit()
	AudioManager.play_sfx("production_start", global_position)
	return true

func collect() -> bool:
	return collect_all()

func cancel_job(job: Dictionary) -> bool:
	if collecting or not Inventory.owns_feed_mill:
		return false
	collecting = true
	_copy_active_timestamps()
	var completed: bool = _reconcile()
	var job_index: int = -1
	for index in range(queue.size()):
		# Compare the actual job, not its contents: two waiting recipes can match.
		if is_same(queue[index],job):
			job_index = index
			break
	var cancelled: bool = false
	if job_index >= 0:
		var ingredients: Dictionary = Progression.RECIPES[job["item"]]["requirements"]
		if _can_refund(ingredients):
			# Commit the full refund and removal before notifying HUD/autosave.
			for item in ingredients:
				Inventory.set(item,Inventory.get(item)+ingredients[item])
			queue.remove_at(job_index)
			_reconcile()
			cancelled = true
		else:
			get_tree().call_group("farm_hud","show_floating_feedback",tr("FEED_REFUND_FULL"))
	_update_display()
	if cancelled:
		Inventory.inventory_changed.emit()
		AudioManager.play_sfx("product_collect", global_position)
	elif completed:
		SaveManager.save_game()
	collecting = false
	_update_display()
	return cancelled


func cancel_job_at(index: int) -> bool:
	if index < 0 or index >= queue.size():
		return false
	return cancel_job(queue[index])

func _can_refund(ingredients: Dictionary) -> bool:
	var silo_amount: int = 0
	var barn_amount: int = 0
	for item in ingredients:
		if item in Inventory.SILO_ITEMS:
			silo_amount += ingredients[item]
		elif item in Inventory.BARN_ITEMS:
			barn_amount += ingredients[item]
		else:
			return false
	if silo_amount > 0 and Inventory.storage_used("silo")+silo_amount > Inventory.silo_capacity:
		return false
	if barn_amount > 0 and Inventory.storage_used("barn")+Inventory.reserved_barn_slots+barn_amount > Inventory.barn_capacity:
		return false
	return true

func collect_all() -> bool:
	if collecting or not Inventory.owns_feed_mill:
		return false
	collecting = true
	var completed: bool = _reconcile()
	var collected: int = 0
	var full: bool = false
	while not outputs.is_empty():
		var item: String = outputs[0]["item"]
		if not Inventory.can_add_item(item,1):
			full = true
			break
		# Suppress only this helper's notification until output + Inventory commit
		# together. A save between add and removal would duplicate the reward.
		if not Inventory.add_item(item,1,false):
			full = true
			break
		outputs.pop_front()
		collected += 1
	_reconcile()
	_update_display()
	if collected > 0:
		Inventory.inventory_changed.emit()
		AudioManager.play_sfx("product_collect", global_position)
	elif completed:
		SaveManager.save_game()
	if full:
		get_tree().call_group("farm_hud","show_floating_feedback",tr("FEED_STORAGE_FULL"))
	collecting = false
	_update_display()
	return collected > 0

func _finish_production() -> void:
	_copy_active_timestamps()
	var completed := _reconcile()
	if completed:
		AudioManager.play_sfx("production_ready", global_position)
	_update_display()
	SaveManager.save_game()

func _copy_active_timestamps() -> void:
	# Keep the existing station API consistent with the active queue job.
	if not queue.is_empty() and queue[0]["state"] == "PRODUCING" and state == "PRODUCING":
		queue[0]["started_at"] = started_at
		queue[0]["ready_at"] = ready_at

func _reconcile() -> bool:
	production_timer.stop()
	var now: float = Time.get_unix_time_from_system()
	var cursor: float = now
	var completed: bool = false
	while not queue.is_empty() and outputs.size() < Data.OUTPUT_LIMIT:
		var entry: Dictionary = queue[0]
		if entry["started_at"] <= 0.0:
			entry["started_at"] = cursor
			entry["ready_at"] = cursor + Progression.RECIPES[entry["item"]]["time"]
		entry["state"] = "PRODUCING"
		if entry["ready_at"] > now:
			production_timer.start(maxf(0.01,entry["ready_at"]-now))
			break
		cursor = entry["ready_at"]
		entry["state"] = "READY"
		outputs.append(queue.pop_front())
		completed = true
	# Full output pauses waiting jobs. Their clocks start only after collection
	# creates room, including after long offline periods.
	var active: Dictionary = {}
	if not queue.is_empty() and queue[0]["state"] == "PRODUCING":
		active = queue[0]
		state = "PRODUCING"
	elif not outputs.is_empty():
		active = outputs[0]
		state = "READY"
	else:
		state = "IDLE"
	production_type = str(active.get("item","")).to_upper()
	started_at = active.get("started_at",0.0)
	ready_at = active.get("ready_at",0.0)
	return completed
