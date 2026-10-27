extends Control

var active_spot: Node = null

@onready var hud: Node = get_parent()

@onready var panel: PanelContainer = $Panel

@onready var info: Label = $Panel/Content/Info

@onready var reaction_bar: ProgressBar = (
	$Panel/Content/ReactionBar
)

@onready var reel_button: Button = (
	$Panel/Content/Reel
)

@onready var fish_button: Button = $Fish

@onready var hint: Label = (
	$Panel/Content/Hint
)

@onready var close_button: Button = (
	$Panel/Content/Close
)

var catch_card: PanelContainer

var catch_icon: Control

var catch_title: Label

var catch_rarity: Label

var catch_detail: Label

var transition_overlay: ColorRect

var transition_busy: bool = false

var last_visual_state: int = -1

var shown_fish_id: String = ""


func _ready() -> void:
	reel_button.pressed.connect(
		_reel
	)

	fish_button.pressed.connect(
		_start
	)

	close_button.pressed.connect(
		close_session
	)

	reaction_bar.custom_minimum_size.y = 18

	reel_button.custom_minimum_size.y = 62

	_build_transition_overlay()

	_build_catch_card()

	clear_session()


# ==================================================
# TRANSITION
# ==================================================

func _build_transition_overlay() -> void:
	transition_overlay = ColorRect.new()

	transition_overlay.name = (
		"FishingTransition"
	)

	transition_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	transition_overlay.color = Color(
		0.06,
		0.07,
		0.08,
		1.0
	)

	transition_overlay.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	transition_overlay.z_index = 200

	transition_overlay.modulate.a = 0.0

	add_child(
		transition_overlay
	)


func _play_transition() -> void:
	if transition_overlay == null:
		return

	if transition_busy:
		return

	transition_busy = true

	transition_overlay.modulate.a = 0.0

	var fade_in := create_tween()

	fade_in.tween_property(
		transition_overlay,
		"modulate:a",
		0.82,
		0.10
	)

	await fade_in.finished

	var fade_out := create_tween()

	fade_out.tween_property(
		transition_overlay,
		"modulate:a",
		0.0,
		0.26
	)

	await fade_out.finished

	transition_busy = false


# ==================================================
# CAMERA
# ==================================================

func _farm_camera() -> Camera2D:
	var player = (
		get_tree()
		.get_first_node_in_group(
			"farm_player"
		)
	)

	if player == null:
		return null

	return (
		player.get_node_or_null(
			"Camera2D"
		)
		as Camera2D
	)


func _enter_fishing_view(
	spot: Node
) -> void:

	var camera := _farm_camera()

	var focus_position: Vector2 = (
		spot.global_position
	)

	if (
		is_instance_valid(spot)
		and spot.has_method(
			"get_camera_focus_position"
		)
	):
		focus_position = (
			spot.get_camera_focus_position()
		)

	if (
		camera != null
		and camera.has_method(
			"enter_fishing_focus"
		)
	):
		camera.enter_fishing_focus(
			focus_position
		)

	_play_transition()


func _exit_fishing_view() -> void:
	var camera := _farm_camera()

	if (
		camera != null
		and camera.has_method(
			"exit_fishing_focus"
		)
	):
		camera.exit_fishing_focus()


# ==================================================
# CATCH CARD
# ==================================================

func _build_catch_card() -> void:
	catch_card = PanelContainer.new()

	catch_card.name = "CatchCard"

	catch_card.custom_minimum_size = (
		Vector2(300, 188)
	)

	catch_card.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	catch_card.add_theme_stylebox_override(
		"panel",
		_catch_panel_style()
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		16
	)

	margin.add_theme_constant_override(
		"margin_right",
		16
	)

	margin.add_theme_constant_override(
		"margin_top",
		12
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		12
	)

	catch_card.add_child(
		margin
	)

	var content := VBoxContainer.new()

	content.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)

	content.add_theme_constant_override(
		"separation",
		5
	)

	margin.add_child(
		content
	)

	var heading := Label.new()

	heading.text = (
		"BẠN ĐÃ CÂU ĐƯỢC"
	)

	heading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	heading.add_theme_font_size_override(
		"font_size",
		13
	)

	heading.add_theme_color_override(
		"font_color",
		Color("6b4a2e")
	)

	content.add_child(
		heading
	)

	catch_title = Label.new()

	catch_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	catch_title.add_theme_font_size_override(
		"font_size",
		20
	)

	catch_title.add_theme_color_override(
		"font_color",
		Color("4f3828")
	)

	content.add_child(
		catch_title
	)

	var icon_holder := CenterContainer.new()

	icon_holder.custom_minimum_size.y = 62

	content.add_child(
		icon_holder
	)

	catch_icon = Control.new()

	catch_icon.custom_minimum_size = (
		Vector2(58, 58)
	)

	catch_icon.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	catch_icon.set_script(
		preload(
			"res://item_icon.gd"
		)
	)

	icon_holder.add_child(
		catch_icon
	)

	catch_rarity = Label.new()

	catch_rarity.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	catch_rarity.add_theme_font_size_override(
		"font_size",
		14
	)

	content.add_child(
		catch_rarity
	)

	catch_detail = Label.new()

	catch_detail.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	catch_detail.add_theme_font_size_override(
		"font_size",
		13
	)

	catch_detail.add_theme_color_override(
		"font_color",
		Color("765b43")
	)

	content.add_child(
		catch_detail
	)

	$Panel/Content.add_child(
		catch_card
	)

	$Panel/Content.move_child(
		catch_card,
		0
	)

	catch_card.hide()


# ==================================================
# SESSION
# ==================================================

func show_session(
	spot: Node
) -> void:

	active_spot = spot

	last_visual_state = -1

	shown_fish_id = ""

	_enter_fishing_view(
		spot
	)

	panel.show()

	fish_button.hide()

	_set_panel_layout(
		"waiting"
	)

	_show_fishing_controls()


func clear_session() -> void:
	_exit_fishing_view()

	active_spot = null

	last_visual_state = -1

	shown_fish_id = ""

	panel.hide()

	catch_card.hide()

	reaction_bar.value = 0

	info.text = ""


func close_session() -> void:
	if is_instance_valid(
		active_spot
	):
		active_spot.cancel_session()

	clear_session()


# ==================================================
# INPUT
# ==================================================

func handle_interact() -> bool:
	if not is_instance_valid(
		active_spot
	):
		return false

	active_spot.reel()

	return true


func _unhandled_input(
	event: InputEvent
) -> void:

	if (
		event.is_action_pressed(
			"fishing_reel"
		)
		and not event.is_echo()
	):
		if is_instance_valid(
			active_spot
		):
			handle_interact()

			get_viewport().set_input_as_handled()


func _reel() -> void:
	handle_interact()


func _start() -> void:
	var player := get_tree().get_first_node_in_group(
		"farm_player"
	)
	if player == null or not player.has_method("request_fishing_cast"):
		return

	if hud.blocks_world_input():
		return

	player.request_fishing_cast()


# ==================================================
# FREE CAST AVAILABILITY
# ==================================================

func _nearby_spot() -> Node:
	var player = (
		get_tree()
		.get_first_node_in_group(
			"farm_player"
		)
	)

	if player == null:
		return null

	if (
		player.has_method("can_start_free_fishing")
		and player.can_start_free_fishing()
	):
		return player

	return null


# ==================================================
# PROCESS
# ==================================================

func _process(
	_delta: float
) -> void:

	fish_button.visible = (
		not is_instance_valid(
			active_spot
		)
		and not hud.blocks_world_input()
		and _nearby_spot() != null
	)

	var remaining: int = (
		Inventory
		.fishing_attempts_remaining()
	)

	fish_button.text = (
		tr("FISHING_ATTEMPTS")
		% [
			remaining,
			Inventory.FishingData
			.ATTEMPTS_PER_CYCLE
		]
	)

	if remaining == 0:
		var seconds: int = (
			Inventory
			.fishing_cycle_seconds_left()
		)

		fish_button.text = (
			tr(
				"FISHING_ATTEMPTS_WAIT"
			)
			% [
				int(seconds / 3600),
				int(seconds / 60) % 60
			]
		)

	if not is_instance_valid(
		active_spot
	):
		panel.hide()
		return

	panel.show()

	var current_state: int = (
		active_spot.state
	)

	if (
		current_state
		!= last_visual_state
	):
		last_visual_state = current_state

		_apply_visual_state()

	# ==============================
	# CATCH RESULT
	# ==============================

	if (
		current_state
		== active_spot.State.SUCCESS
	):
		_show_catch(
			active_spot.last_caught_fish
		)

		return

	if (
		current_state
		== active_spot.State.COOLDOWN
		and not active_spot
		.last_caught_fish
		.is_empty()
	):
		_show_catch(
			active_spot.last_caught_fish
		)

		return

	# ==============================
	# FAIL
	# ==============================

	if (
		current_state
		== active_spot.State.FAILED
	):
		catch_card.hide()

		info.show()

		info.text = (
			active_spot.feedback
		)

		hint.show()

		hint.text = (
			"Buổi câu sẽ kết thúc..."
		)

		reaction_bar.hide()

		reel_button.hide()

		close_button.show()

		return

	# ==============================
	# WAIT / BITE
	# ==============================

	_show_fishing_controls()

	info.text = (
		active_spot.feedback
	)

	var reacting: bool = (
		current_state
		== active_spot.State.BITE_WINDOW
	)

	reaction_bar.visible = reacting

	if reacting:
		reaction_bar.max_value = (
			active_spot.bite_window
		)

		reaction_bar.value = maxf(
			0.0,
			active_spot.deadline
			- active_spot.now()
		)

	else:
		reaction_bar.value = 0.0


# ==================================================
# VISUAL STATE
# ==================================================

func _apply_visual_state() -> void:
	if not is_instance_valid(
		active_spot
	):
		return

	match active_spot.state:
		active_spot.State.BITE_WINDOW:
			_apply_bite_style()

		active_spot.State.WAITING_FOR_BITE:
			_apply_waiting_style()

		active_spot.State.FAILED:
			_apply_failed_style()

		active_spot.State.SUCCESS:
			pass

		active_spot.State.COOLDOWN:
			pass

		_:
			_apply_waiting_style()


func _show_fishing_controls() -> void:
	catch_card.hide()

	info.show()

	hint.show()

	reel_button.show()

	close_button.show()

	var waiting: bool = (
		is_instance_valid(active_spot)
		and active_spot.state
		== active_spot.State.WAITING_FOR_BITE
	)

	var reacting: bool = (
		is_instance_valid(active_spot)
		and active_spot.state
		== active_spot.State.BITE_WINDOW
	)

	reel_button.disabled = (
		not waiting
		and not reacting
	)


# ==================================================
# SHOW CATCH
# ==================================================

func _show_catch(
	fish_id: String
) -> void:

	if fish_id.is_empty():
		return

	if not Inventory.FishingData.FISH.has(
		fish_id
	):
		return

	info.hide()

	hint.hide()

	reaction_bar.hide()

	reel_button.hide()

	close_button.hide()

	panel.add_theme_stylebox_override(
		"panel",
		_catch_panel_style()
	)

	_set_panel_layout(
		"catch"
	)

	catch_card.show()

	var fish_data: Dictionary = (
		Inventory.FishingData
		.FISH[fish_id]
	)

	catch_icon.set(
		"item_id",
		fish_id
	)

	catch_title.text = (
		Localization.display_name(
			fish_data["name"]
		)
	)

	var rarity := str(
		fish_data.get(
			"rarity",
			"common"
		)
	)

	catch_rarity.text = (
		_rarity_name(
			rarity
		)
	)

	catch_rarity.add_theme_color_override(
		"font_color",
		_rarity_color(
			rarity
		)
	)

	catch_detail.text = (
		"Trong kho: %d    •    Giá bán: %d xu"
		% [
			Inventory.get(
				fish_id
			),
			int(
				fish_data.get(
					"sell_price",
					0
				)
			)
		]
	)

	if shown_fish_id == fish_id:
		return

	shown_fish_id = fish_id

	catch_card.scale = (
		Vector2(0.88, 0.88)
	)

	catch_card.modulate.a = 0.0

	var tween := create_tween()

	tween.set_parallel(true)

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		catch_card,
		"scale",
		Vector2.ONE,
		0.24
	)

	tween.tween_property(
		catch_card,
		"modulate:a",
		1.0,
		0.16
	)


# ==================================================
# STYLES
# ==================================================

func _apply_waiting_style() -> void:
	_set_panel_layout(
		"waiting"
	)

	panel.add_theme_stylebox_override(
		"panel",
		_waiting_panel_style()
	)

	info.add_theme_font_size_override(
		"font_size",
		18
	)

	info.add_theme_color_override(
		"font_color",
		Color("5a432f")
	)

	hint.text = (
		"Chờ cá cắn mồi · ESC để hủy"
	)

	hint.add_theme_font_size_override(
		"font_size",
		14
	)

	hint.add_theme_color_override(
		"font_color",
		Color("7a624b")
	)

	reel_button.text = (
		"SPACE: Giật cần"
	)

	reel_button.add_theme_font_size_override(
		"font_size",
		18
	)

	reel_button.add_theme_stylebox_override(
		"normal",
		_waiting_button_style()
	)

	reel_button.add_theme_stylebox_override(
		"hover",
		_waiting_button_style()
	)

	reel_button.add_theme_stylebox_override(
		"pressed",
		_waiting_button_style()
	)

	reel_button.add_theme_color_override(
		"font_color",
		Color("5b402d")
	)


func _apply_bite_style() -> void:
	_set_panel_layout(
		"bite"
	)

	panel.add_theme_stylebox_override(
		"panel",
		_bite_panel_style()
	)

	info.add_theme_font_size_override(
		"font_size",
		28
	)

	info.add_theme_color_override(
		"font_color",
		Color("fff4c4")
	)

	hint.text = (
		"Nhấn SPACE ngay!"
	)

	hint.add_theme_font_size_override(
		"font_size",
		17
	)

	hint.add_theme_color_override(
		"font_color",
		Color("ffe48a")
	)

	reel_button.text = (
		"SPACE  —  GIẬT CẦN!"
	)

	reel_button.add_theme_font_size_override(
		"font_size",
		24
	)

	var bite_button := (
		_bite_button_style()
	)

	reel_button.add_theme_stylebox_override(
		"normal",
		bite_button
	)

	reel_button.add_theme_stylebox_override(
		"hover",
		bite_button
	)

	reel_button.add_theme_stylebox_override(
		"pressed",
		bite_button
	)

	reel_button.add_theme_color_override(
		"font_color",
		Color("4b321d")
	)

	reaction_bar.add_theme_stylebox_override(
		"background",
		_reaction_background_style()
	)

	reaction_bar.add_theme_stylebox_override(
		"fill",
		_reaction_fill_style()
	)


func _apply_failed_style() -> void:
	_set_panel_layout(
		"waiting"
	)

	panel.add_theme_stylebox_override(
		"panel",
		_waiting_panel_style()
	)

	info.add_theme_font_size_override(
		"font_size",
		20
	)

	info.add_theme_color_override(
		"font_color",
		Color("9b4e3c")
	)


# ==================================================
# PANEL SIZE
# ==================================================

func _set_panel_layout(
	mode: String
) -> void:
	var desired_size := Vector2(420.0, 380.0)
	if mode == "bite":
		desired_size = Vector2(420.0, 360.0)
	elif mode == "catch":
		desired_size = Vector2(330.0, 280.0)

	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(
		minf(desired_size.x, maxf(240.0, viewport_size.x - 24.0)),
		minf(desired_size.y, maxf(220.0, viewport_size.y - 24.0))
	)
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	panel.custom_minimum_size = panel_size
	info.custom_minimum_size.x = maxf(0.0, panel_size.x - 32.0)


# ==================================================
# RARITY
# ==================================================

func _rarity_name(
	rarity: String
) -> String:

	match rarity:
		"rare":
			return "HIẾM"

		"uncommon":
			return "KHÁ HIẾM"

		_:
			return "PHỔ BIẾN"


func _rarity_color(
	rarity: String
) -> Color:

	match rarity:
		"rare":
			return Color("d49a20")

		"uncommon":
			return Color("4d87a6")

		_:
			return Color("60945d")


# ==================================================
# STYLEBOX
# ==================================================

func _waiting_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("f4e7c8")

	style.border_color = Color("a96f43")

	style.set_border_width_all(3)

	style.set_corner_radius_all(14)

	return style


func _bite_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("443323")

	style.border_color = Color("ffc44d")

	style.set_border_width_all(4)

	style.set_corner_radius_all(14)

	return style


func _waiting_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("ead2a0")

	style.border_color = Color("b17b48")

	style.set_border_width_all(2)

	style.set_corner_radius_all(10)

	return style


func _bite_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("ffc44d")

	style.border_color = Color("fff0a8")

	style.set_border_width_all(4)

	style.set_corner_radius_all(12)

	return style


func _reaction_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("705b3d")

	style.set_corner_radius_all(6)

	return style


func _reaction_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("ffd34e")

	style.set_corner_radius_all(6)

	return style


func _catch_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color("f6e8c8")

	style.border_color = Color("bd814b")

	style.set_border_width_all(3)

	style.set_corner_radius_all(14)

	return style
