extends VBoxContainer

const Icon = preload("res://item_icon.gd")
var station: Node
var slots: Array[Dictionary] = []
var output_slots: Array[Dictionary] = []
var output_title: Label
var elapsed: float = 0.0

func _ready() -> void:
	add_theme_constant_override("separation",6)
	var title := Label.new()
	title.text = tr("FEED_QUEUE_TITLE")
	title.add_theme_font_size_override("font_size",14)
	add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	add_child(row)
	for index in range(3):
		slots.append(_make_slot(row,tr("FEED_SLOT_TITLE") % (index+1)))
		var cancel: Button = slots[index]["cancel"]
		cancel.pressed.connect(_cancel_slot.bind(index))
	output_title = Label.new()
	output_title.add_theme_font_size_override("font_size",14)
	add_child(output_title)
	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation",6)
	add_child(output_row)
	for index in range(3):
		output_slots.append(_make_slot(output_row,""))
	set_process(false)

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
	return {"card":card,"icon":icon,"name":name_label,"title":title,"status":status,"progress":progress,"cancel":cancel,"job":{}}

func _cancel_slot(index: int) -> void:
	if not is_instance_valid(station) or not station.player_near or station.collecting:
		return
	var job: Dictionary = slots[index]["job"]
	station.cancel_job(job)
	refresh(station)

func refresh(value: Node) -> void:
	station = value
	visible = is_instance_valid(station) and station.station_id == "feed_mill"
	set_process(visible and station.state == "PRODUCING")
	if not visible:
		return
	for index in range(3):
		_display(slots[index],station.queue[index] if index < station.queue.size() else {})
		_display(output_slots[index],station.outputs[index] if index < station.outputs.size() else {})
	output_title.text = tr("FEED_OUTPUT_TITLE") % station.outputs.size()

func _display(view: Dictionary, entry: Dictionary) -> void:
	view["job"] = entry
	var cancel: Button = view["cancel"]
	if cancel != null:
		cancel.visible = not entry.is_empty() and entry.get("state","") in ["PRODUCING","QUEUED"]
		cancel.disabled = station.collecting or not station.player_near
	view["icon"].modulate.a = 0.0 if entry.is_empty() else 1.0
	view["progress"].visible = entry.get("state","") == "PRODUCING"
	if entry.is_empty():
		view["name"].text = view["title"]
		view["status"].text = tr("FEED_EMPTY")
		view["card"].tooltip_text = ""
		return
	view["icon"].item_id = entry["item"]
	var kind: String = tr("ITEM_CHICKEN") if entry["item"] == "chicken_feed" else tr("ITEM_COW")
	view["name"].text = kind if view["title"].is_empty() else view["title"] + " · " + kind
	view["card"].tooltip_text = Localization.display_name(entry["item"])
	var state: String = entry["state"]
	var keys: Dictionary = {"PRODUCING":"FEED_WORKING","QUEUED":"STATE_QUEUED","READY":"FEED_FINISHED"}
	view["status"].text = tr(keys.get(state,"FEED_EMPTY"))
	if state == "PRODUCING":
		var remaining: float = maxf(0.0,entry["ready_at"]-Time.get_unix_time_from_system())
		var seconds: int = ceili(remaining)
		view["status"].text += "\n%d:%02d" % [floori(seconds/60.0),seconds%60]
		view["progress"].value = clampf(1.0-remaining/maxf(0.001,entry["ready_at"]-entry["started_at"]),0.0,1.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(station):
		set_process(false)
		return
	elapsed += delta
	if elapsed >= 0.2:
		elapsed = 0.0
		refresh(station)
