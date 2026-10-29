extends Area2D

signal state_changed

const Data = preload(
	"res://bakery_data.gd"
)

@export var is_preview: bool = false

@onready var production_timer: Timer = (
	$ProductionTimer
)


func _ready() -> void:

	# ==============================================
	# PLACEMENT PREVIEW
	# ==============================================

	if is_preview:

		collision_layer = 0
		collision_mask = 0

		monitoring = false
		monitorable = false

		for shape in find_children(
			"*",
			"CollisionShape2D",
			true,
			false
		):
			shape.disabled = true

		$StatusLabel.hide()

		var prompt := get_node_or_null(
			"InteractionPrompt"
		)

		if prompt is CanvasItem:
			prompt.hide()

		return

	# ==============================================
	# REAL BUILDING
	# ==============================================

	add_to_group(
		"farm_interactables"
	)

	production_timer.timeout.connect(
		_finish_production
	)

	Inventory.inventory_changed.connect(
		refresh
	)

	refresh()


func can_interact() -> bool:

	if is_preview:
		return false

	if not Inventory.owns_bakery:
		return false

	for body in get_overlapping_bodies():

		if body.is_in_group(
			"farm_player"
		):
			return true

	return false


func interact(
	_player: Node2D = null
) -> void:

	if is_preview:
		return

	var hud = (
		get_tree()
		.get_first_node_in_group(
			"farm_hud"
		)
	)

	if (
		can_interact()
		and hud != null
		and not hud.blocks_world_input()
	):
		hud.open_bakery(self)


func enqueue(
	item: String
) -> bool:

	if is_preview:
		return false

	if (
		not Inventory.owns_bakery
		or not Data.RECIPES.has(item)
		or SaveManager.bakery_queue.size()
		>= Inventory.production_queue_capacity("bakery")
	):
		return Inventory.fail(
			tr("BAKERY_QUEUE_FULL")
		)

	var recipe: Dictionary = (
		Data.RECIPES[item]
	)

	if (
		Inventory.player_level
		< recipe["level"]
	):
		return Inventory.fail(
			tr("ERROR_LEVEL")
			% recipe["level"]
		)

	for ingredient in recipe[
		"requirements"
	]:

		if (
			Inventory.get(ingredient)
			< recipe[
				"requirements"
			][ingredient]
		):
			return Inventory.fail(
				tr("ERROR_ITEMS")
			)

	# ==============================================
	# CONSUME INGREDIENTS
	# ==============================================

	for ingredient in recipe[
		"requirements"
	]:

		Inventory.set(
			ingredient,
			Inventory.get(ingredient)
			- recipe[
				"requirements"
			][ingredient]
		)

	# ==============================================
	# CREATE JOB
	# ==============================================

	var start: float = (
		Time.get_unix_time_from_system()
	)

	if not SaveManager.bakery_queue.is_empty():

		start = maxf(
			start,
			float(
				SaveManager
				.bakery_queue
				.back()[
					"ready_at"
				]
			)
		)

	SaveManager.bakery_queue.append(
		{
			"item": item,
			"state": "QUEUED",
			"started_at": start,
			"ready_at":
				start
				+ float(
					recipe["time"]
				)
		}
	)

	refresh()

	Inventory.inventory_changed.emit()

	AudioManager.play_sfx(
		"production_start",
		global_position
	)

	return true


func cancel_job_at(index: int) -> bool:
	if (
		is_preview
		or not Inventory.owns_bakery
		or index < 0
		or index >= SaveManager.bakery_queue.size()
	):
		return false
	refresh()
	var job: Dictionary = SaveManager.bakery_queue[index]
	if str(job.get("state", "")) not in ["QUEUED", "PRODUCING"]:
		return false
	var recipe: Dictionary = Data.RECIPES.get(str(job.get("item", "")), {})
	var requirements: Dictionary = recipe.get("requirements", {})
	if requirements.is_empty() or not _can_refund(requirements):
		get_tree().call_group("farm_hud", "show_floating_feedback", tr("FEED_REFUND_FULL"))
		return false
	for ingredient in requirements:
		Inventory.set(ingredient, Inventory.get(ingredient) + int(requirements[ingredient]))
	SaveManager.bakery_queue.remove_at(index)
	_reflow_queue()
	refresh()
	Inventory.inventory_changed.emit()
	AudioManager.play_sfx("product_collect", global_position)
	return true


func _can_refund(requirements: Dictionary) -> bool:
	var silo_amount: int = 0
	var barn_amount: int = 0
	for item in requirements:
		if item in Inventory.SILO_ITEMS:
			silo_amount += int(requirements[item])
		elif item in Inventory.BARN_ITEMS:
			barn_amount += int(requirements[item])
		else:
			return false
	return (
		Inventory.storage_used("silo") + silo_amount <= Inventory.silo_capacity
		and Inventory.storage_used("barn") + Inventory.reserved_barn_slots + barn_amount <= Inventory.barn_capacity
	)


func _reflow_queue() -> void:
	# Keep the active job's progress, then close any gap left by a cancelled job.
	var next_start: float = Time.get_unix_time_from_system()
	for index in range(SaveManager.bakery_queue.size()):
		var entry: Dictionary = SaveManager.bakery_queue[index]
		if index == 0 and str(entry.get("state", "")) == "PRODUCING":
			next_start = maxf(next_start, float(entry.get("ready_at", next_start)))
			continue
		var recipe: Dictionary = Data.RECIPES.get(str(entry.get("item", "")), {})
		var duration: float = float(recipe.get("time", 0.0))
		entry["started_at"] = next_start
		entry["ready_at"] = next_start + duration
		entry["state"] = "QUEUED"
		next_start = float(entry["ready_at"])


func collect() -> bool:

	if is_preview:
		return false

	refresh()

	if (
		not Inventory.owns_bakery
		or SaveManager.bakery_queue.is_empty()
		or SaveManager.bakery_queue[0][
			"state"
		] != "READY"
	):
		return false

	var item: String = str(
		SaveManager.bakery_queue[0][
			"item"
		]
	)

	if not Inventory.can_add_item(
		item,
		1
	):
		return Inventory.fail(
			tr("ERROR_BARN_BATCH")
		)

	SaveManager.bakery_queue.pop_front()

	Inventory.set(
		item,
		Inventory.get(item) + 1
	)

	refresh()

	Inventory.inventory_changed.emit()

	AudioManager.play_sfx(
		"product_collect",
		global_position
	)

	get_tree().call_group(
		"farm_hud",
		"show_transaction_feedback",
		tr("TRADE_ITEM")
			% [
				1,
				Localization.display_name(
					item
				)
			]
	)

	return true


func refresh() -> void:

	if is_preview:
		return

	production_timer.stop()

	var owned: bool = (
		Inventory.owns_bakery
	)

	visible = owned

	# Không cho building chưa mua
	# tham gia interaction.
	set_deferred(
		"monitoring",
		owned
	)

	$CollisionShape2D.set_deferred(
		"disabled",
		not owned
	)

	var now: float = (
		Time.get_unix_time_from_system()
	)

	var next_ready: float = INF

	for entry in (
		SaveManager.bakery_queue
	):

		entry["state"] = (
			"READY"
			if now >= entry["ready_at"]
			else (
				"PRODUCING"
				if now
				>= entry["started_at"]
				else "QUEUED"
			)
		)

		if entry["ready_at"] > now:

			next_ready = minf(
				next_ready,
				entry["ready_at"]
			)

	if (
		owned
		and is_finite(next_ready)
	):

		production_timer.start(
			maxf(
				0.01,
				next_ready - now
			)
		)

	$StatusLabel.text = (
		tr("BAKERY_WORLD")
		% [SaveManager.bakery_queue.size(), Inventory.production_queue_capacity("bakery")]
	)

	state_changed.emit()


func _finish_production() -> void:

	if is_preview:
		return

	refresh()

	AudioManager.play_sfx(
		"production_ready",
		global_position
	)

	SaveManager.save_game()
