extends VBoxContainer

const Icon = preload("res://item_icon.gd")
var station: Node
var slots: Array[Dictionary] = []
var output_slots: Array[Dictionary] = []
var output_title: Label
var elapsed: float = 0.0
var queue_empty: Label
var output_empty: Label
var output_hint: Label
var is_feed: bool = true
var machine_kind: String = "feed_mill"
var queue_row: HBoxContainer
var output_row: GridContainer
var slot_capacity: int = 3

func _ready() -> void:
	add_theme_constant_override("separation",6)
	var title := Label.new()
	title.text = tr("FEED_QUEUE_TITLE")
	title.add_theme_font_size_override("font_size",14)
	add_child(title)
	queue_empty = Label.new()
	queue_empty.text = tr("PRODUCTION_QUEUE_EMPTY")
	queue_empty.add_theme_font_size_override("font_size",13)
	queue_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(queue_empty)
	queue_row = HBoxContainer.new()
	queue_row.add_theme_constant_override("separation",6)
	add_child(queue_row)
	output_title = Label.new()
	output_title.add_theme_font_size_override("font_size",14)
	add_child(output_title)
	output_empty = Label.new()
	output_empty.text = tr("PRODUCTION_OUTPUT_EMPTY")
	output_empty.add_theme_font_size_override("font_size",13)
	output_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output_empty)
	output_row = GridContainer.new()
	output_row.columns = 3
	output_row.add_theme_constant_override("h_separation",6)
	output_row.add_theme_constant_override("v_separation",6)
	add_child(output_row)
	output_hint = Label.new()
	output_hint.text = tr("PRODUCTION_READY_IN_QUEUE")
	output_hint.add_theme_font_size_override("font_size",12)
	output_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(output_hint)
	_ensure_slot_capacity(_queue_capacity())
	set_process(false)

func _queue_capacity() -> int:
	return Inventory.production_queue_capacity(machine_kind)

func _ensure_slot_capacity(capacity: int) -> void:
	capacity = clampi(capacity, 3, 5)
	while slots.size() < capacity:
		var index := slots.size()
		slots.append(_make_slot(queue_row, tr("FEED_SLOT_TITLE") % (index + 1)))
		var cancel: Button = slots[index]["cancel"]
		cancel.pressed.connect(_cancel_slot.bind(index))
	while output_slots.size() < capacity:
		output_slots.append(_make_slot(output_row, ""))
	slot_capacity = capacity

func _make_slot(parent: Control, title: String) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 80
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",2)
	card.add_child(content)
	var name_label: Label
	var cancel: Button
	if not title.is_empty():
		var heading_row := HBoxContainer.new()
		heading_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(heading_row)
		var heading := Label.new()
		heading.text = title
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_theme_font_size_override("font_size",12)
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading_row.add_child(heading)
		name_label = heading
		cancel = Button.new()
		cancel.text = tr("UI_CANCEL")
		cancel.tooltip_text = tr("FEED_CANCEL_HINT")
		cancel.add_theme_font_size_override("font_size",12)
		heading_row.add_child(cancel)
		for button_state in ["normal","hover","pressed","disabled"]:
			var style: StyleBox = cancel.get_theme_stylebox(button_state).duplicate()
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			cancel.add_theme_stylebox_override(button_state,style)
		cancel.hide()
	var icon := Control.new()
	icon.set_script(Icon)
	icon.custom_minimum_size = Vector2(24,24)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	if name_label == null:
		name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size",12)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(name_label)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",12)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 6
	progress.max_value = 1
	progress.step = 0.001
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress)
	var amount := Label.new()
	amount.text = "×1"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size",12)
	amount.visible = title.is_empty()
	content.add_child(amount)
	return {"card":card,"icon":icon,"name":name_label,"title":title,"status":status,"progress":progress,"cancel":cancel,"job":{},"amount":amount}

func _cancel_slot(index: int) -> void:
	if not is_instance_valid(station):
		return
	if station.has_method("cancel_job_at"):
		station.cancel_job_at(index)
	elif station.has_method("cancel_job"):
		var job: Dictionary = slots[index]["job"]
		station.cancel_job(job)
	refresh(station)

func refresh(value: Node) -> void:
	if not is_instance_valid(value) or value.get("station_id") != "feed_mill":
		hide()
		return
	refresh_entries(value.queue,value.outputs,value,true)

func refresh_entries(queue: Array, outputs: Array, value: Node, feed: bool) -> void:
	station = value
	is_feed = feed
	_ensure_slot_capacity(_queue_capacity() if not feed else 3)
	show()
	queue_empty.visible = queue.is_empty()
	output_empty.visible = outputs.is_empty()
	output_hint.visible = not feed and not outputs.is_empty()
	for index in range(slot_capacity):
		_display(slots[index],queue[index] if index < queue.size() else {})
		_display(output_slots[index],outputs[index] if index < outputs.size() else {})
		slots[index]["card"].visible = true
		output_slots[index]["card"].visible = index < outputs.size()
	for index in range(slot_capacity, slots.size()):
		slots[index]["card"].hide()
		output_slots[index]["card"].hide()
	output_title.text = tr("PRODUCTION_OUTPUT") % outputs.size()

func _display(view: Dictionary, entry: Dictionary) -> void:
	view["job"] = entry
	var cancel: Button = view["cancel"]
	if cancel != null:
		var is_cancellable: bool = not entry.is_empty() and entry.get("state", "") in ["PRODUCING", "QUEUED"]
		cancel.visible = is_cancellable
		cancel.disabled = not is_cancellable or not _can_cancel_jobs()
	view["icon"].modulate.a = 0.25 if entry.is_empty() else 1.0
	view["progress"].hide()
	if entry.is_empty():
		if view["icon"].item_id != "":
			view["icon"].item_id = ""
		view["name"].text = view["title"]
		view["status"].text = tr("FEED_EMPTY")
		view["card"].tooltip_text = ""
		return
	if view["icon"].item_id != entry["item"]:
		view["icon"].item_id = entry["item"]
	var kind: String = Localization.display_name(entry["item"])
	view["name"].text = kind if view["title"].is_empty() else view["title"] + " · " + kind
	view["name"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view["card"].tooltip_text = Localization.display_name(entry["item"])
	var state: String = entry["state"]
	if not is_feed:
		var now: float = Time.get_unix_time_from_system()
		state = "READY" if now >= entry["ready_at"] else ("PRODUCING" if now >= entry["started_at"] else "QUEUED")
	view["progress"].visible = state == "PRODUCING"
	var keys: Dictionary = {"PRODUCING":"FEED_WORKING","QUEUED":"STATE_QUEUED","READY":"FEED_FINISHED"}
	view["status"].text = tr(keys.get(state,"FEED_EMPTY"))
	if state == "PRODUCING":
		var remaining: float = maxf(0.0,entry["ready_at"]-Time.get_unix_time_from_system())
		var seconds: int = ceili(remaining)
		view["status"].text += "\n%d:%02d" % [floori(seconds/60.0),seconds%60]
		view["progress"].value = clampf(1.0-remaining/maxf(0.001,entry["ready_at"]-entry["started_at"]),0.0,1.0)


func _can_cancel_jobs() -> bool:
	if not is_instance_valid(station):
		return false
	if is_feed:
		return station.player_near and not station.collecting
	return station.has_method("can_interact") and station.can_interact()

