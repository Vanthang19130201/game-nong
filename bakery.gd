extends Area2D

signal state_changed
const Data = preload("res://bakery_data.gd")
@onready var production_timer: Timer = $ProductionTimer

func _ready() -> void:
	add_to_group("farm_interactables")
	production_timer.timeout.connect(_finish_production)
	Inventory.inventory_changed.connect(refresh)
	refresh()

func can_interact() -> bool:
	if not Inventory.owns_bakery:
		return false
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			return true
	return false

func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if can_interact() and hud != null and not hud.blocks_world_input():
		hud.open_bakery(self)

func enqueue(item: String) -> bool:
	if not Inventory.owns_bakery or not Data.RECIPES.has(item) or SaveManager.bakery_queue.size() >= Data.QUEUE_LIMIT:
		return Inventory.fail(tr("BAKERY_QUEUE_FULL"))
	var recipe: Dictionary = Data.RECIPES[item]
	if Inventory.player_level < recipe["level"]:
		return Inventory.fail(tr("ERROR_LEVEL") % recipe["level"])
	for ingredient in recipe["requirements"]:
		if Inventory.get(ingredient) < recipe["requirements"][ingredient]:
			return Inventory.fail(tr("ERROR_ITEMS"))
	for ingredient in recipe["requirements"]:
		Inventory.set(ingredient, Inventory.get(ingredient) - recipe["requirements"][ingredient])
	var start: float = Time.get_unix_time_from_system()
	if not SaveManager.bakery_queue.is_empty():
		start = maxf(start, SaveManager.bakery_queue.back()["ready_at"])
	SaveManager.bakery_queue.append({"item": item, "state": "QUEUED", "started_at": start, "ready_at": start + recipe["time"]})
	refresh()
	Inventory.inventory_changed.emit()
	return true

func collect() -> bool:
	refresh()
	if not Inventory.owns_bakery or SaveManager.bakery_queue.is_empty() or SaveManager.bakery_queue[0]["state"] != "READY":
		return false
	var item: String = SaveManager.bakery_queue[0]["item"]
	if not Inventory.can_add_item(item, 1):
		return Inventory.fail(tr("ERROR_BARN_BATCH"))
	SaveManager.bakery_queue.pop_front()
	Inventory.set(item, Inventory.get(item) + 1)
	refresh()
	Inventory.inventory_changed.emit()
	get_tree().call_group("farm_hud", "show_transaction_feedback", tr("TRADE_ITEM") % [1, Localization.display_name(item)])
	return true

func refresh() -> void:
	production_timer.stop()
	visible = Inventory.owns_bakery
	var now: float = Time.get_unix_time_from_system()
	var next_ready: float = INF
	for entry in SaveManager.bakery_queue:
		entry["state"] = "READY" if now >= entry["ready_at"] else ("PRODUCING" if now >= entry["started_at"] else "QUEUED")
		if entry["ready_at"] > now:
			next_ready = minf(next_ready, entry["ready_at"])
	if visible and is_finite(next_ready):
		production_timer.start(maxf(0.01, next_ready - now))
	$StatusLabel.text = tr("BAKERY_WORLD") % SaveManager.bakery_queue.size()
	state_changed.emit()

func _finish_production() -> void:
	refresh()
	SaveManager.save_game()
