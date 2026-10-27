extends Node

const Placement = preload("res://building_placement.gd")
var active: bool = false
var selected: Node2D
var selected_id: String = ""
var selected_color: Color
var hovered: Node2D
var hovered_color: Color
var hover_highlighted: bool = false
var preview: Node2D
var proposed_position: Vector2
var valid_position: bool = false
var info: Label
var menu: PanelContainer
var placing_decoration: String = ""
var placing_building: String = ""
var delete_button: Button
var delete_confirmation: ConfirmationDialog
@onready var hud: Node = get_parent()

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(16,150)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_color_override("font_color",Color("fff4d7"))
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 4)
	hud.add_child(info)
	menu = PanelContainer.new()
	menu.z_index = 80
	hud.add_child(menu)
	var buttons := VBoxContainer.new()
	menu.add_child(buttons)
	var move := Button.new()
	move.text = tr("EDIT_MOVE")
	move.focus_mode = Control.FOCUS_NONE
	move.pressed.connect(begin_move)
	buttons.add_child(move)
	delete_button = Button.new()
	delete_button.text = tr("DECOR_DELETE")
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.pressed.connect(_ask_delete)
	buttons.add_child(delete_button)
	delete_button.hide()
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = tr("DECOR_DELETE")
	delete_confirmation.dialog_text = tr("DECOR_DELETE_CONFIRM")
	delete_confirmation.ok_button_text = tr("DECOR_DELETE")
	delete_confirmation.cancel_button_text = tr("UI_CANCEL")
	delete_confirmation.exclusive = true
	delete_confirmation.confirmed.connect(_delete_selected)
	delete_confirmation.canceled.connect(func(): menu.show() if active and is_instance_valid(selected) else menu.hide())
	hud.add_child(delete_confirmation)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(cancel_selection)
	buttons.add_child(cancel)
	info.hide()
	menu.hide()
	Inventory.inventory_changed.connect(_inventory_changed)

func enter_mode() -> void:
	if active:
		return
	hud._close_game_panels()
	get_tree().get_first_node_in_group("farm_player").mouse_interaction.clear_hover()
	active = true
	info.show()
	_update_info()
	hud._on_main_panel_visibility_changed()

func exit_mode() -> void:
	cancel_selection()
	_clear_hover()
	active = false
	info.hide()
	hud._on_main_panel_visibility_changed()

func cancel_or_exit() -> void:
	if delete_confirmation.visible:
		delete_confirmation.hide()
		menu.show()
	elif not placing_decoration.is_empty() or not placing_building.is_empty():
		exit_mode()
	elif is_instance_valid(preview):
		cancel_selection()
	else:
		exit_mode()

func _process(_delta: float) -> void:
	if not active:
		return
	var player = get_tree().get_first_node_in_group("farm_player")
	var point: Vector2 = player.get_global_mouse_position()
	if is_instance_valid(preview):
		update_preview(point)
		return
	update_hover(point)

func update_hover(point: Vector2) -> void:
	var target: Node2D = null
	if get_viewport().gui_get_hovered_control() == null:
		target = target_at(point)
	if target != hovered:
		_clear_hover()
		hovered = target
		if hovered != null and hovered != selected:
			hovered_color = hovered.modulate
			hover_highlighted = true
			hovered.modulate *= Color(1.15,1.15,1.05)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func movable_buildings() -> Dictionary:
	var result: Dictionary = {}
	for id in SaveManager.buildings:
		var building = SaveManager.buildings[id]
		var data: Dictionary = hud.FarmData.BUILDINGS[id]
		var owned: bool = data.get("always_owned", false) or (Inventory.has_dog_house if id == "dog_house" else Inventory.owns_building(id))
		var movable: bool = data.get("movable", Inventory.Progression.BUILDINGS.has(id))
		if owned and movable and is_instance_valid(building) and building.is_visible_in_tree():
			result[id] = building
	for id in SaveManager.plots:
		var plot = SaveManager.plots[id]
		if is_instance_valid(plot) and plot.is_unlocked() and plot.is_visible_in_tree():
			result[id] = plot
	var manager = hud.get_parent().get("decoration_manager")
	if is_instance_valid(manager):
		for id in manager.instances:
			result[id] = manager.instances[id]
	return result

func target_at(point: Vector2) -> Node2D:
	var result: Node2D
	var distance: float = INF
	for building in movable_buildings().values():
		if Placement.bounds(building).has_point(point):
			var candidate_distance: float = building.global_position.distance_squared_to(point)
			if candidate_distance < distance:
				result = building
				distance = candidate_distance
	return result

func click_world(screen_position: Vector2) -> void:
	if not active or delete_confirmation.visible:
		return
	var player = get_tree().get_first_node_in_group("farm_player")
	var point: Vector2 = player.get_canvas_transform().affine_inverse() * screen_position
	if is_instance_valid(preview):
		update_preview(point)
		place_move()
	else:
		select_building(target_at(point))

func select_building(building: Node2D) -> void:
	if not active or delete_confirmation.visible:
		return
	cancel_selection()
	_clear_hover()
	if building == null or building not in movable_buildings().values():
		return
	selected = building
	selected_id = building.instance_id if building.get("decoration_id") != null else str(SaveManager.buildings.find_key(building))
	if building.get("plot_id") != null:
		selected_id = building.plot_id
	delete_button.visible = building.get("decoration_id") != null
	selected_color = building.modulate
	building.modulate *= Color(1.1,1.1,0.9)
	menu.reset_size()
	menu.position = (get_viewport().get_mouse_position()+Vector2(16,16)).clamp(Vector2.ZERO, (get_viewport().get_visible_rect().size-menu.size).max(Vector2.ZERO))
	menu.show()

func begin_move() -> void:
	if not active or delete_confirmation.visible or is_instance_valid(preview) or not is_instance_valid(selected):
		return
	menu.hide()
	_clear_hover()
	preview = Placement.create_preview(selected)
	selected.get_parent().add_child(preview)
	selected.modulate = selected_color * Color(1,1,1,0.35)
	update_preview(selected.global_position)
	_update_info()

func update_preview(point: Vector2) -> void:
	var source: Node2D = preview if not placing_decoration.is_empty() or not placing_building.is_empty() else selected
	if not is_instance_valid(preview) or not is_instance_valid(source):
		return
	proposed_position = Placement.snap_position(point)
	valid_position = Placement.can_place(source, proposed_position)
	if not placing_decoration.is_empty():
		valid_position = valid_position and SaveManager.DecorationData.can_afford(placing_decoration)
	if not placing_building.is_empty():
		var data: Dictionary = Inventory.Progression.BUILDINGS[placing_building]
		valid_position = valid_position and not Inventory.owns_building(placing_building) and Inventory.player_level >= data["level"] and Inventory.coins >= data["price"]
	preview.global_position = proposed_position
	preview.modulate = Color(0.45,1,0.55,0.8) if valid_position else Color(1,0.35,0.3,0.8)

func place_move() -> bool:
	if not placing_building.is_empty():
		if not is_instance_valid(preview):
			return false
		if hud._trade(Inventory.buy_building.bind(placing_building,preview,proposed_position),placing_building,1):
			exit_mode()
			return true
		return false
	if not placing_decoration.is_empty():
		if hud.get_parent().decoration_manager.place(preview,proposed_position,preview.rotation_degrees):
			exit_mode()
			return true
		return false
	if not is_instance_valid(preview) or not is_instance_valid(selected) or not Placement.can_place(selected, proposed_position):
		return false
	if selected.get("decoration_id") != null:
		if hud.get_parent().decoration_manager.move(selected,proposed_position,preview.rotation_degrees):
			cancel_selection()
			return true
		return false
	var previous: Vector2 = selected.position
	selected.global_position = proposed_position
	var is_plot: bool = selected.get("plot_id") != null
	if not is_plot:
		SaveManager.building_positions[selected_id] = selected.position
	if not SaveManager.save_game():
		selected.position = previous
		if not is_plot:
			SaveManager.building_positions[selected_id] = previous
		Inventory.fail(tr("EDIT_SAVE_FAILED"))
		return false
	# The dog's home_point already references the same DogHouse node.
	# Moving that node must not restart the dog's current walk or idle timer.
	cancel_selection()
	return true

func cancel_selection() -> void:
	_clear_hover()
	if is_instance_valid(selected):
		selected.modulate = selected_color
	selected = null
	selected_id = ""
	placing_decoration = ""
	placing_building = ""
	delete_confirmation.hide()
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	menu.hide()
	_update_info()

func _clear_hover() -> void:
	if is_instance_valid(hovered) and hover_highlighted:
		hovered.modulate = hovered_color
	hovered = null
	hover_highlighted = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _update_info() -> void:
	info.text = tr("EDIT_MODE_HINT")
	if is_instance_valid(preview):
		if not placing_building.is_empty():
			info.text = tr("BUILDING_PLACING_HINT") % Localization.display_name(placing_building)
		elif not placing_decoration.is_empty():
			info.text = tr("DECOR_PLACING_HINT") % tr(SaveManager.DecorationData.TYPES[placing_decoration]["name_key"])
		elif is_instance_valid(selected) and selected.get("decoration_id") != null:
			info.text = tr("EDIT_MOVING_HINT") % tr(SaveManager.DecorationData.TYPES[selected.decoration_id]["name_key"]) + tr("DECOR_ROTATE_HINT")
		elif is_instance_valid(selected) and selected.get("plot_id") != null:
			info.text = tr("EDIT_MOVING_HINT") % tr("MOUSE_SOIL_PLOT")
		else:
			info.text = tr("EDIT_MOVING_HINT") % Localization.display_name(selected_id)

func begin_decoration(id: String) -> void:
	if active or not SaveManager.DecorationData.TYPES.has(id):
		return
	enter_mode()
	placing_decoration = id
	preview = preload("res://decoration.tscn").instantiate()
	preview.decoration_id = id
	preview.is_preview = true
	hud.get_parent().add_child(preview)
	update_preview(get_tree().get_first_node_in_group("farm_player").get_global_mouse_position())
	_update_info()

func rotate_preview() -> void:
	if not is_instance_valid(preview) or not placing_building.is_empty():
		return
	var id: String = placing_decoration if not placing_decoration.is_empty() else str(selected.get("decoration_id"))
	if not SaveManager.DecorationData.TYPES.has(id) or not SaveManager.DecorationData.TYPES[id]["rotatable"]:
		return
	preview.rotation_degrees = SaveManager.DecorationData.normalized_rotation(id,preview.rotation_degrees+90)
	update_preview(proposed_position)

func begin_building_placement(id: String) -> void:
	if active or hud._native_dialog_open() or not Inventory.Progression.BUILDINGS.has(id):
		return
	var data: Dictionary = Inventory.Progression.BUILDINGS[id]
	if not data.get("placement_required",false) or Inventory.owns_building(id):
		return
	if Inventory.player_level < data["level"]:
		Inventory.fail(tr("ERROR_LEVEL") % data["level"])
		return
	if Inventory.coins < data["price"]:
		Inventory.fail(tr("ERROR_COINS"))
		return
	enter_mode()
	placing_building = id
	preview = load(hud.FarmData.BUILDINGS[id]["scene"]).instantiate()
	preview.name = "BuildingPreview"
	preview.is_preview = true
	preview.set_meta("placement_building_id",id)
	preview.z_index = 100
	hud.get_parent().add_child(preview)
	update_preview(get_tree().get_first_node_in_group("farm_player").get_global_mouse_position())
	_update_info()

func _ask_delete() -> void:
	if not active or delete_confirmation.visible or is_instance_valid(preview) or not is_instance_valid(selected) or selected.get("decoration_id") == null:
		return
	menu.hide()
	delete_confirmation.popup_centered()
	delete_confirmation.get_cancel_button().grab_focus()

func _delete_selected() -> void:
	if not active or not is_instance_valid(selected) or selected.get("decoration_id") == null:
		return
	if hud.get_parent().decoration_manager.remove(selected_id):
		cancel_selection()
	else:
		menu.show()
		Inventory.fail(tr("EDIT_SAVE_FAILED"))

func _inventory_changed() -> void:
	if active and SaveManager.resetting:
		exit_mode()

func _exit_tree() -> void:
	_clear_hover()
	if is_instance_valid(preview):
		preview.queue_free()
	if is_instance_valid(selected):
		selected.modulate = selected_color
