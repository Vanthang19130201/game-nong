extends CharacterBody2D

const UI_THEME: Theme = preload(
	"res://assets/ui/ui_theme.tres"
)

const FISH_CAST_DISTANCES: Array[float] = [
	40.0,
	55.0,
	70.0,
	85.0,
	100.0,
	115.0,
	130.0,
	145.0
]

var active_resource: Node = null
var mouse_interaction: Node
var last_interaction_frame: int = -1

var facing_vector: Vector2 = Vector2.DOWN

var fishing_prompt: Label

var fishing_input_locked: bool = false
var fishing_target_available: bool = false

@export var speed: float = 200.0

@export var farm_bounds: Rect2 = Rect2(
	50,
	50,
	2300,
	2300
)

@onready var hud: Node = (
	get_tree()
	.get_first_node_in_group(
		"farm_hud"
	)
)


func _ready() -> void:
	add_to_group("farm_player")

	mouse_interaction = Node.new()

	mouse_interaction.name = "WorldMouseInteraction"

	mouse_interaction.set_script(
		preload(
			"res://world_mouse_interaction.gd"
		)
	)

	add_child(mouse_interaction)

	_setup_fishing_prompt()

	global_position = global_position.clamp(
		farm_bounds.position,
		farm_bounds.end
	)

	$Camera2D.reset_smoothing()


func _physics_process(
	_delta: float
) -> void:

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var fishing_active := _fishing_active()

	if (
		not fishing_active
		and direction.length_squared() > 0.01
	):
		facing_vector = _cardinal_direction(
			direction
		)

	# ==================================================
	# CÂU CÁ - BẮT E TRỰC TIẾP
	# ==================================================

	if fishing_active:
		direction = Vector2.ZERO

	elif (
		is_instance_valid(hud)
		and hud.blocks_world_input()
		and not hud.edit_farm.active
	):
		direction = Vector2.ZERO

	velocity = direction * speed

	move_and_slide()

	global_position = global_position.clamp(
		farm_bounds.position,
		farm_bounds.end
	)

	_update_fishing_prompt()


func _unlock_fishing_input() -> void:
	fishing_input_locked = false


func _fishing_active() -> bool:
	return (
		is_instance_valid(hud)
		and is_instance_valid(
			hud.fishing_ui
		)
		and is_instance_valid(
			hud.fishing_ui.active_spot
		)
	)


# ==================================================
# INPUT THƯỜNG
# ==================================================

func _unhandled_input(
	event: InputEvent
) -> void:

	if (
		event is InputEventMouseButton
		and event.button_index
		== MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if (
			is_instance_valid(hud)
			and hud.edit_farm.active
		):
			hud.edit_farm.click_world(
				event.position
			)

		else:
			interact_at_screen_position(
				event.position
			)

		get_viewport().set_input_as_handled()

		return

	if (
		not event.is_action_pressed(
			"interact"
		)
		or event.is_echo()
	):
		return

	# Route E directly into casting when a valid water target is ahead.
	if not _fishing_active():
		var target := _find_fishing_target()
		if not target.is_empty():
			request_fishing_cast(target)
			get_viewport().set_input_as_handled()
			return

	get_viewport().set_input_as_handled()

	try_interact()


# ==================================================
# FISHING PROMPT
# ==================================================

func _setup_fishing_prompt() -> void:
	fishing_prompt = Label.new()

	fishing_prompt.name = "FishingPrompt"

	fishing_prompt.text = "[E] Câu cá"

	fishing_prompt.theme = UI_THEME

	fishing_prompt.position = Vector2(
		-60,
		-88
	)

	fishing_prompt.custom_minimum_size = Vector2(
		120,
		28
	)

	fishing_prompt.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	fishing_prompt.add_theme_font_size_override(
		"font_size",
		14
	)

	fishing_prompt.add_theme_color_override(
		"font_color",
		Color("fff3cf")
	)

	fishing_prompt.add_theme_color_override(
		"font_outline_color",
		Color("493321")
	)

	fishing_prompt.add_theme_constant_override(
		"outline_size",
		4
	)

	fishing_prompt.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	fishing_prompt.z_index = 30

	fishing_prompt.hide()

	add_child(fishing_prompt)


func _update_fishing_prompt() -> void:
	if not is_instance_valid(
		fishing_prompt
	):
		return

	if not _can_prepare_fishing():
		fishing_target_available = false
		fishing_prompt.hide()
		return

	var target := _find_fishing_target()
	fishing_target_available = not target.is_empty()

	fishing_prompt.visible = (
		fishing_target_available
	)


func can_start_free_fishing() -> bool:
	if fishing_input_locked or _fishing_active():
		return false
	return not _find_fishing_target().is_empty()


func request_fishing_cast(
	target: Dictionary = {}
) -> bool:
	if fishing_input_locked or _fishing_active():
		return false

	if target.is_empty():
		target = _find_fishing_target()
	if target.is_empty():
		return false

	fishing_input_locked = true
	var started := _start_free_fishing(target)
	get_tree().create_timer(0.15).timeout.connect(
		_unlock_fishing_input
	)
	return started


# ==================================================
# KIỂM TRA CÓ ĐƯỢC CÂU KHÔNG
# ==================================================

func _can_prepare_fishing() -> bool:
	if not is_instance_valid(hud):
		return false

	if _fishing_active():
		return false

	if is_instance_valid(
		active_resource
	):
		return false

	if hud.blocks_world_input():
		return false

	if not Inventory.is_zone_unlocked(
		"fishing"
	):
		return false

	if not Inventory.has_fishing_rod:
		return false

	if not is_instance_valid(
		hud.hotbar
	):
		return false

	if not hud.hotbar.has_method(
		"is_equipped"
	):
		return false

	return hud.hotbar.is_equipped(
		"fishing_rod"
	)


# ==================================================
# TÌM NƯỚC PHÍA TRƯỚC
# ==================================================

func _find_fishing_target() -> Dictionary:
	if not _can_prepare_fishing():
		return {}

	var zones := (
		get_tree()
		.get_nodes_in_group(
			"fishing_water_zones"
		)
	)

	for distance in FISH_CAST_DISTANCES:
		var probe := (
			global_position
			+ facing_vector
			* distance
		)

		for zone in zones:
			if not is_instance_valid(zone):
				continue

			if not zone.has_method(
				"contains_world_point"
			):
				continue

			# Player phải đứng ngoài nước.
			if zone.contains_world_point(
				global_position
			):
				continue

			# Điểm phía trước phải nằm trong nước.
			if zone.contains_world_point(
				probe
			):
				return {
					"zone": zone,
					"water_id": zone.water_id,
					"point": probe
				}

	return {}


# ==================================================
# BẮT ĐẦU CÂU
# ==================================================

func _start_free_fishing(
	target: Dictionary
) -> bool:

	if target.is_empty():
		return false

	var manager: Node = null

	# Cách 1:
	# tìm manager bằng group mới.
	manager = (
		get_tree()
		.get_first_node_in_group(
			"fishing_session_manager"
		)
	)

	# Cách 2:
	# fallback qua group fishing_spots cũ.
	if not is_instance_valid(manager):
		for candidate in (
			get_tree()
			.get_nodes_in_group(
				"fishing_spots"
			)
		):
			if (
				is_instance_valid(candidate)
				and candidate.has_method(
					"start_free_session"
				)
			):
				manager = candidate
				break

	# Cách 3:
	# fallback tìm FishingSpot trực tiếp trong scene.
	if not is_instance_valid(manager):
		var scene := get_tree().current_scene

		if scene != null:
			var candidate := (
				scene.get_node_or_null(
					"FishingSpot"
				)
			)

			if (
				is_instance_valid(candidate)
				and candidate.has_method(
					"start_free_session"
				)
			):
				manager = candidate

	if not is_instance_valid(manager):
		_show_fishing_error(
			"Không tìm thấy FishingSpot."
		)

		return false

	if not manager.has_method(
		"start_free_session"
	):
		_show_fishing_error(
			"FishingSpot chưa có start_free_session()."
		)

		return false

	var started: bool = (
		manager.start_free_session(
			self,
			target["point"],
			target["water_id"]
		)
	)

	return started


func _show_fishing_error(
	message: String
) -> void:

	if (
		is_instance_valid(hud)
		and hud.has_method(
			"show_transaction_feedback"
		)
	):
		hud.show_transaction_feedback(
			message
		)

	else:
		Inventory.fail(message)


# ==================================================
# TƯ THẾ NHÂN VẬT
# ==================================================

func begin_fishing_pose() -> void:
	if is_instance_valid(
		fishing_prompt
	):
		fishing_prompt.hide()

	var visual = get_node_or_null(
		"AnimatedSprite2D"
	)

	if (
		is_instance_valid(visual)
		and visual.has_method(
			"force_facing"
		)
	):
		visual.force_facing(
			_facing_name()
		)


func end_fishing_pose() -> void:
	var visual = get_node_or_null(
		"AnimatedSprite2D"
	)

	if (
		is_instance_valid(visual)
		and visual.has_method(
			"clear_forced_facing"
		)
	):
		visual.clear_forced_facing()


func _facing_name() -> String:
	if (
		absf(facing_vector.x)
		> absf(facing_vector.y)
	):
		return (
			"right"
			if facing_vector.x > 0
			else "left"
		)

	return (
		"down"
		if facing_vector.y > 0
		else "up"
	)


func _cardinal_direction(
	direction: Vector2
) -> Vector2:

	if (
		absf(direction.x)
		> absf(direction.y)
	):
		return (
			Vector2.RIGHT
			if direction.x > 0
			else Vector2.LEFT
		)

	return (
		Vector2.DOWN
		if direction.y > 0
		else Vector2.UP
	)


# ==================================================
# NORMAL MOUSE INTERACTION
# ==================================================

func interact_at_screen_position(
	screen_position: Vector2
) -> void:

	if (
		is_instance_valid(hud)
		and hud.blocks_world_input()
	):
		return

	if is_instance_valid(
		active_resource
	):
		return

	if _fishing_active():
		return

	var world_position: Vector2 = (
		get_canvas_transform()
		.affine_inverse()
		* screen_position
	)

	var target: Node2D = (
		mouse_interaction.target_at(
			world_position
		)
	)

	if target != null:
		try_interact(target)

	else:
		var zone = (
			mouse_interaction.land_at(
				world_position
			)
		)

		if zone != null:
			hud.open_land_purchase(
				zone.zone_id
			)

	mouse_interaction.clear_hover()


func can_interact_with(
	target: Node
) -> bool:

	if not is_instance_valid(target):
		return false

	if not target.is_in_group(
		"farm_interactables"
	):
		return false

	if not target.is_visible_in_tree():
		return false

	if (
		is_instance_valid(hud)
		and hud.blocks_world_input()
	):
		return false

	if is_instance_valid(
		active_resource
	):
		return false

	if _fishing_active():
		return false

	return target.can_interact()


func try_interact(
	target: Node = null
) -> void:

	if (
		is_instance_valid(hud)
		and hud.blocks_world_input()
	):
		return

	var frame: int = (
		Engine.get_process_frames()
	)

	if last_interaction_frame == frame:
		return

	if is_instance_valid(
		active_resource
	):
		return

	if target == null:
		target = _nearest_interactable()

	if not can_interact_with(target):
		return

	last_interaction_frame = frame

	target.interact(self)


func _nearest_interactable() -> Node2D:
	var nearest: Node2D = null

	var best_distance: float = INF

	for candidate in (
		get_tree()
		.get_nodes_in_group(
			"farm_interactables"
		)
	):
		if not can_interact_with(
			candidate
		):
			continue

		var target_position: Vector2 = (
			candidate.get_interaction_position()
			if candidate.has_method(
				"get_interaction_position"
			)
			else candidate.global_position
		)

		var distance: float = (
			global_position
			.distance_squared_to(
				target_position
			)
		)

		if distance < best_distance:
			best_distance = distance
			nearest = candidate

	return nearest
