extends VBoxContainer

const RecipeCard = preload("res://production_recipe_card.gd")
const QueueView = preload("res://feed_queue_view.gd")
var machine_kind: String
var recipe_data: Dictionary
var machine: Node
var queue_view: VBoxContainer
var cards: Dictionary = {}
var recipe_grid: GridContainer
var recipe_column: VBoxContainer
var status_column: VBoxContainer
var columns: BoxContainer
var recipe_scroll: ScrollContainer
var collect_button: Button
var clock: Timer
var busy: bool = false

func _ready() -> void:
	add_theme_constant_override("separation",8)
	columns = BoxContainer.new()
	columns.add_theme_constant_override("separation",12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	recipe_column = VBoxContainer.new()
	recipe_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(recipe_column)
	var heading := Label.new()
	heading.text = tr("PRODUCTION_RECIPES")
	heading.theme_type_variation = &"SectionTitle"
	recipe_column.add_child(heading)
	recipe_scroll = ScrollContainer.new()
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.custom_minimum_size.y = 340
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_column.add_child(recipe_scroll)
	recipe_grid = GridContainer.new()
	recipe_grid.columns = 2
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation",8)
	recipe_grid.add_theme_constant_override("v_separation",8)
	recipe_scroll.add_child(recipe_grid)
	for item in recipe_data:
		var card := PanelContainer.new()
		card.set_script(RecipeCard)
		card.item_id = item
		card.recipe = recipe_data[item]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_grid.add_child(card)
		card.enqueue_requested.connect(enqueue)
		cards[item] = card
	status_column = VBoxContainer.new()
	status_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_column.custom_minimum_size.x = 300
	status_column.add_theme_constant_override("separation",8)
	columns.add_child(status_column)
	if queue_view == null:
		queue_view = VBoxContainer.new()
		queue_view.set_script(QueueView)
		status_column.add_child(queue_view)
	else:
		queue_view.reparent(status_column,false)
	collect_button = Button.new()
	collect_button.text = tr("FEED_COLLECT_ALL") if machine_kind == "feed_mill" else tr("UI_COLLECT")
	collect_button.focus_mode = Control.FOCUS_NONE
	collect_button.pressed.connect(collect)
	collect_button.theme_type_variation = &"PrimaryButton"
	status_column.add_child(collect_button)
	clock = Timer.new()
	clock.wait_time = 0.25
	clock.timeout.connect(_tick)
	add_child(clock)
	visibility_changed.connect(_sync_clock)
	resized.connect(_fit_columns)
	recipe_column.resized.connect(_fit_columns)
	_fit_columns.call_deferred()

func _fit_columns() -> void:
	columns.vertical = size.x < 680
	# The queue uses about 300 px beside the recipes. Choose two cards only
	# when each card still has enough room for its ingredient labels.
	var available_recipe_width: float = recipe_column.size.x
	recipe_grid.columns = 2 if available_recipe_width >= 640.0 else 1
	recipe_scroll.custom_minimum_size.y = 220 if columns.vertical else 340

func bind_machine(value: Node) -> void:
	machine = value
	refresh()
	_sync_clock()

func _sync_clock() -> void:
	if is_visible_in_tree() and is_instance_valid(machine):
		if clock.is_stopped():
			clock.start()
	else:
		clock.stop()

func get_queue() -> Array:
	if not is_instance_valid(machine):
		return []
	if machine_kind == "feed_mill":
		return machine.queue
	return SaveManager.get(machine_kind+"_queue")

func ready_outputs() -> Array:
	if not is_instance_valid(machine):
		return []
	if machine_kind == "feed_mill":
		return machine.outputs
	return get_queue().filter(func(entry): return entry["ready_at"] <= Time.get_unix_time_from_system())

func refresh() -> void:
	if not is_instance_valid(machine):
		return
	var allowed: bool = not busy and machine.can_interact() and get_queue().size() < 3
	if machine_kind == "feed_mill":
		allowed = allowed and not machine.collecting
	for card in cards.values():
		card.refresh(allowed)
	_tick()

func _tick() -> void:
	if not is_visible_in_tree() or not is_instance_valid(machine):
		clock.stop()
		return
	queue_view.refresh_entries(get_queue(),ready_outputs(),machine,machine_kind == "feed_mill")
	collect_button.disabled = busy or ready_outputs().is_empty() or not machine.can_interact()
	if machine_kind == "feed_mill":
		collect_button.disabled = collect_button.disabled or machine.collecting

func enqueue(item: String) -> void:
	if busy or not is_visible_in_tree() or not is_instance_valid(machine) or not machine.can_interact():
		return
	busy = true
	if machine_kind == "feed_mill":
		machine.produce(item)
	else:
		machine.enqueue(item)
	busy = false
	refresh()

func collect() -> void:
	if busy or not is_visible_in_tree() or not is_instance_valid(machine) or not machine.can_interact():
		return
	var outputs: Array = ready_outputs()
	if outputs.is_empty():
		return
	# Presentation-only check; the backend remains authoritative and unchanged.
	if not Inventory.can_add_item(outputs[0]["item"],1):
		get_tree().call_group("farm_hud","show_floating_feedback",tr("FEED_STORAGE_FULL"))
		return
	busy = true
	refresh()
	machine.collect()
	busy = false
	refresh()
