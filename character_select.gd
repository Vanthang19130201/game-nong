extends Control

signal confirmed(character_id: String, player_name: String)
signal cancelled

const Data = preload("res://character_data.gd")

var selected_id: String = Data.DEFAULT_ID
var cards: Dictionary = {}

var preview: AnimatedSprite2D
var selected_name: Label
var selected_model: Label
var confirm_button: Button
var error_label: Label
var columns: HBoxContainer
var name_input: LineEdit


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("526e4a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.set_offset(SIDE_LEFT, 18)
	center.set_offset(SIDE_TOP, 18)
	center.set_offset(SIDE_RIGHT, -18)
	center.set_offset(SIDE_BOTTOM, -18)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	panel.add_theme_stylebox_override("panel", _main_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "Chọn người bạn đồng hành"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("5b402d"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Bốn diện mạo · Cùng một trải nghiệm nông trại"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("80664d"))
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	content.add_child(spacer)

	columns = HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	columns.add_child(grid)

	var index := 1
	for id in Data.CHARACTERS:
		var card := Button.new()
		card.name = id
		card.custom_minimum_size = Vector2(146, 146)
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_ALL
		card.pressed.connect(select_character.bind(id))

		for state in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(
				state,
				_card_style(state in ["pressed", "focus"])
			)

		grid.add_child(card)

		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)

		var picture := TextureRect.new()
		var card_frames := Data.frames_for(id)
		if (
			card_frames != null
			and card_frames.has_animation("idle_down")
			and card_frames.get_frame_count("idle_down") > 0
		):
			picture.texture = card_frames.get_frame_texture("idle_down", 0)

		picture.custom_minimum_size = Vector2(88, 96)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(picture)

		var name_label := Label.new()
		name_label.text = "Mẫu %d" % index
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color("59402f"))
		inner.add_child(name_label)

		cards[id] = card
		index += 1

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(235, 305)
	detail_panel.add_theme_stylebox_override("panel", _preview_panel_style())
	columns.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_top", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 14)
	detail_panel.add_child(detail_margin)

	var detail := VBoxContainer.new()
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_theme_constant_override("separation", 6)
	detail_margin.add_child(detail)

	selected_model = Label.new()
	selected_model.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_model.add_theme_font_size_override("font_size", 14)
	selected_model.add_theme_color_override("font_color", Color("80664d"))
	detail.add_child(selected_model)

	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(200, 205)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(portrait)

	preview = AnimatedSprite2D.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.position = Vector2(100, 108)
	portrait.add_child(preview)

	selected_name = Label.new()
	selected_name.text = "Tên của bạn"
	selected_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_name.add_theme_font_size_override("font_size", 21)
	selected_name.add_theme_color_override("font_color", Color("5b402d"))
	detail.add_child(selected_name)

	var name_title := Label.new()
	name_title.text = "Tên nhân vật"
	name_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_title.add_theme_font_size_override("font_size", 14)
	name_title.add_theme_color_override("font_color", Color("80664d"))
	content.add_child(name_title)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Nhập tên của bạn..."
	name_input.max_length = 16
	name_input.custom_minimum_size = Vector2(320, 44)
	name_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.text_changed.connect(_on_name_changed)
	name_input.text_submitted.connect(_on_name_submitted)
	content.add_child(name_input)

	var note := Label.new()
	note.text = "Xác nhận sẽ bắt đầu nông trại mới và thay thế tiến trình đã lưu."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("80664d"))
	content.add_child(note)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 13)
	error_label.add_theme_color_override("font_color", Color("b75d42"))
	error_label.custom_minimum_size.y = 20
	content.add_child(error_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)

	var back := Button.new()
	back.text = "Hủy"
	back.custom_minimum_size = Vector2(130, 44)
	back.pressed.connect(_cancel)
	actions.add_child(back)

	confirm_button = Button.new()
	confirm_button.text = "Xác nhận & bắt đầu"
	confirm_button.custom_minimum_size = Vector2(210, 44)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_confirm_selection)
	actions.add_child(confirm_button)

	select_character(Data.DEFAULT_ID)

	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

	name_input.grab_focus()


func prepare_for_new_game() -> void:
	# This selector is reused after Back; clear every transient UI field first.
	selected_id = Data.DEFAULT_ID
	if name_input != null:
		name_input.text = ""
	if error_label != null:
		error_label.text = ""
	if confirm_button != null:
		confirm_button.disabled = true
	select_character(selected_id)
	if name_input != null:
		name_input.grab_focus()


func select_character(id: String) -> void:
	selected_id = Data.valid_id(id)

	var index := 1
	for key in cards:
		cards[key].set_pressed_no_signal(key == selected_id)
		cards[key].tooltip_text = "Đang chọn" if key == selected_id else "Chọn mẫu %d" % index
		index += 1

	var frames := Data.frames_for(selected_id)
	preview.sprite_frames = frames

	if (
		frames != null
		and frames.has_animation("idle_down")
		and frames.get_frame_count("idle_down") > 0
	):
		var texture := frames.get_frame_texture("idle_down", 0)
		if texture != null and texture.get_height() > 0:
			preview.scale = Vector2.ONE * 180.0 / float(texture.get_height())
		preview.play("idle_down")

	selected_model.text = "Đang chọn: %s" % _model_name(selected_id)
	_refresh_display_name()


func _on_name_changed(new_text: String) -> void:
	var clean_name := new_text.strip_edges()
	confirm_button.disabled = clean_name.is_empty()
	error_label.text = ""
	_refresh_display_name()


func _on_name_submitted(_text: String) -> void:
	if not confirm_button.disabled:
		_confirm_selection()


func _refresh_display_name() -> void:
	if name_input == null or selected_name == null:
		return

	var clean_name := name_input.text.strip_edges()
	selected_name.text = clean_name if not clean_name.is_empty() else "Tên của bạn"


func _confirm_selection() -> void:
	var clean_name := name_input.text.strip_edges()

	if clean_name.is_empty():
		error_label.text = "Hãy nhập tên của bạn"
		name_input.grab_focus()
		return

	if clean_name.length() > 16:
		clean_name = clean_name.left(16)

	error_label.text = ""
	confirm_button.disabled = true
	confirmed.emit(selected_id, clean_name)


func _cancel() -> void:
	cancelled.emit()


func _fit_layout() -> void:
	if columns == null or columns.get_child_count() < 2:
		return

	var wide := get_viewport_rect().size.x >= 700
	columns.get_child(1).visible = wide


func _model_name(id: String) -> String:
	var keys := Data.CHARACTERS.keys()
	var found := keys.find(id)
	return "Mẫu %d" % (found + 1 if found >= 0 else 1)


func _main_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f3e6c7")
	style.border_color = Color("9b6b47")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	return style


func _preview_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead8af")
	style.border_color = Color("b78658")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7e9c9") if selected else Color("dfcfaa")
	style.border_color = Color("e8ad51") if selected else Color("9b7150")
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(12)
	return style
