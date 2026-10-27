extends Control

var continue_button: Button
var selection: Control
var menu: CenterContainer
var starting: bool = false

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
	continue_button = Button.new()
	continue_button.text = tr("CHARACTER_CONTINUE")
	continue_button.custom_minimum_size.y = 48
	continue_button.disabled = not SaveManager.has_existing_game
	continue_button.pressed.connect(continue_game)
	content.add_child(continue_button)
	var new_game := Button.new()
	new_game.text = tr("CHARACTER_NEW_GAME")
	new_game.custom_minimum_size.y = 48
	new_game.pressed.connect(show_character_select)
	content.add_child(new_game)
	(continue_button if not continue_button.disabled else new_game).grab_focus()

func show_character_select() -> void:
	if selection == null:
		selection = preload("res://character_select.tscn").instantiate()
		selection.confirmed.connect(confirm_character)
		selection.cancelled.connect(_cancel_selection)
		add_child(selection)
	else:
		selection.show()
	menu.hide()

func _cancel_selection() -> void:
	selection.hide()
	menu.show()

func confirm_character(id: String) -> void:
	if starting:
		return
	starting = true
	selection.confirm_button.disabled = true
	if SaveManager.start_new_game(id):
		_enter_farm()
	else:
		starting = false
		selection.confirm_button.disabled = false
		selection.error_label.text = tr("RESET_FAILED")

func continue_game() -> void:
	if not starting and SaveManager.has_existing_game:
		starting = true
		_enter_farm()

func _enter_farm() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
