extends Control

var continue_button: Button
var selection: Control
var menu: CenterContainer
var starting: bool = false
var audio_settings_overlay: Control


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("526e4a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	menu = CenterContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 280)
	menu.add_child(panel)

	var margin := MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)

	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var title := Label.new()
	title.text = tr("CHARACTER_GAME_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)

	# =========================
	# CONTINUE
	# =========================

	continue_button = Button.new()
	continue_button.text = tr("CHARACTER_CONTINUE")
	continue_button.custom_minimum_size.y = 48
	continue_button.disabled = not SaveManager.has_existing_game
	continue_button.pressed.connect(continue_game)
	content.add_child(continue_button)

	# =========================
	# NEW GAME
	# =========================

	var new_game := Button.new()
	new_game.text = tr("CHARACTER_NEW_GAME")
	new_game.custom_minimum_size.y = 48
	new_game.pressed.connect(show_character_select)
	content.add_child(new_game)
	var settings_button := Button.new()
	settings_button.text = tr("SETTINGS")
	settings_button.custom_minimum_size.y = 44
	settings_button.pressed.connect(_open_audio_settings)
	content.add_child(settings_button)

	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game.grab_focus()

	# Nếu vừa bấm "Chơi lại từ đầu" trong game,
	# tự động mở màn chọn nhân vật.
	if SaveManager.character_selection_pending:
		show_character_select.call_deferred()


func show_character_select() -> void:
	if starting:
		return

	if selection == null:
		selection = preload("res://character_select.tscn").instantiate()

		selection.confirmed.connect(confirm_character)
		selection.cancelled.connect(_cancel_selection)

		add_child(selection)
	else:
		selection.show()

	menu.hide()


func _cancel_selection() -> void:
	if starting:
		return

	if selection != null:
		selection.hide()

	menu.show()

	# Sau khi reset game thì Continue phải bị khóa.
	continue_button.disabled = not SaveManager.has_existing_game

	if not continue_button.disabled:
		continue_button.grab_focus()


func confirm_character(id: String, player_name: String) -> void:
	if starting:
		return

	var clean_name := player_name.strip_edges()

	if clean_name.is_empty():
		if selection != null:
			selection.error_label.text = "Hãy nhập tên của bạn"
			selection.name_input.grab_focus()
		return

	starting = true

	if selection != null:
		selection.confirm_button.disabled = true
		selection.error_label.text = ""

	# SaveManager giờ nhận:
	# character_id + player_name
	if SaveManager.start_new_game(id, clean_name):
		_enter_farm()
		return

	# Nếu tạo game mới thất bại
	starting = false

	if selection != null:
		selection.confirm_button.disabled = false
		selection.error_label.text = tr("RESET_FAILED")


func continue_game() -> void:
	if starting:
		return

	if not SaveManager.has_existing_game:
		return

	starting = true
	_enter_farm()


func _enter_farm() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func _open_audio_settings() -> void:
	if is_instance_valid(audio_settings_overlay):
		audio_settings_overlay.show()
		return
	audio_settings_overlay = Control.new()
	audio_settings_overlay.name = "AudioSettingsOverlay"
	audio_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio_settings_overlay.z_index = 20
	add_child(audio_settings_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.10, 0.08, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	audio_settings_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio_settings_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 220)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	var title := Label.new()
	title.text = tr("SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var controls := VBoxContainer.new()
	controls.set_script(preload("res://audio_settings_controls.gd"))
	content.add_child(controls)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.custom_minimum_size.y = 40
	close.pressed.connect(audio_settings_overlay.hide)
	content.add_child(close)
