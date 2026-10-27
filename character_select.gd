extends Control

signal confirmed(character_id: String)
signal cancelled
const Data = preload("res://character_data.gd")
var selected_id: String = Data.DEFAULT_ID
var cards: Dictionary = {}
var preview: AnimatedSprite2D
var selected_name: Label
var confirm_button: Button
var error_label: Label
var columns: HBoxContainer

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("526e4a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.set_offset(SIDE_LEFT, 24)
	scroll.set_offset(SIDE_TOP, 20)
	scroll.set_offset(SIDE_RIGHT, -24)
	scroll.set_offset(SIDE_BOTTOM, -20)
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var title := Label.new()
	title.text = tr("CHARACTER_SELECT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("fff0cd"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("CHARACTER_COSMETIC_ONLY")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("e5d9b6"))
	content.add_child(subtitle)
	columns = HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	columns.add_child(grid)
	for id in Data.CHARACTERS:
		var card := Button.new()
		card.name = id
		card.custom_minimum_size = Vector2(148, 148)
		card.toggle_mode = true
		card.pressed.connect(select_character.bind(id))
		for state in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(state, _card_style(state in ["pressed", "focus"]))
		grid.add_child(card)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)
		var picture := TextureRect.new()
		picture.texture = Data.frames_for(id).get_frame_texture("idle_down", 0)
		picture.custom_minimum_size = Vector2(90, 100)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(picture)
		var name_label := Label.new()
		name_label.text = Data.CHARACTERS[id]["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_color_override("font_color", Color("59402f"))
		inner.add_child(name_label)
		cards[id] = card
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 210
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(detail)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(200, 220)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(portrait)
	preview = AnimatedSprite2D.new()
	preview.position = Vector2(100, 110)
	portrait.add_child(preview)
	selected_name = Label.new()
	selected_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_name.add_theme_font_size_override("font_size", 22)
	selected_name.add_theme_color_override("font_color", Color("fff0cd"))
	detail.add_child(selected_name)
	var note := Label.new()
	note.text = tr("CHARACTER_NEW_GAME_NOTE")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("e5d9b6"))
	content.add_child(note)
	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color("ffcfab"))
	content.add_child(error_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var back := Button.new()
	back.text = tr("UI_CANCEL")
	back.custom_minimum_size = Vector2(130, 44)
	back.pressed.connect(func(): cancelled.emit())
	actions.add_child(back)
	confirm_button = Button.new()
	confirm_button.text = tr("CHARACTER_CONFIRM")
	confirm_button.custom_minimum_size = Vector2(210, 44)
	confirm_button.pressed.connect(func(): confirmed.emit(selected_id))
	actions.add_child(confirm_button)
	select_character(Data.DEFAULT_ID)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

func select_character(id: String) -> void:
	selected_id = Data.valid_id(id)
	for key in cards:
		cards[key].set_pressed_no_signal(key == selected_id)
		cards[key].tooltip_text = tr("CHARACTER_SELECTED") if key == selected_id else Data.CHARACTERS[key]["name"]
	var frames := Data.frames_for(selected_id)
	preview.sprite_frames = frames
	var texture := frames.get_frame_texture("idle_down", 0)
	preview.scale = Vector2.ONE * 170.0 / texture.get_height()
	preview.play("idle_down")
	selected_name.text = Data.CHARACTERS[selected_id]["name"]

func _fit_layout() -> void:
	# Small windows retain the four cards and scroll vertically.
	columns.get_child(1).visible = get_viewport_rect().size.x >= 620

func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5e7c7") if selected else Color("ddcfaa")
	style.border_color = Color("f0be66") if selected else Color("826346")
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(12)
	return style
