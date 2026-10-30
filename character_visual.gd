extends AnimatedSprite2D

const Player1Frames = preload("res://player1_animation_frames.gd")
var current_action: StringName = &""
var action_locked: bool = false
var locomotion_scale: Vector2 = Vector2.ONE
var locomotion_offset: Vector2 = Vector2.ZERO

@export var fallback_paths: Array[NodePath] = []

@export var presentation_enabled: bool = true

@export var use_selected_character: bool = false

@export_range(
	1.0,
	256.0,
	1.0,
	"or_greater"
)
var target_character_height: float = 72.0

var facing: String = "down"

var forced_facing: String = ""

var facing_before_force: String = "down"

var base_offset: Vector2 = Vector2.ZERO
var walk_phase: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(_on_tool_action_finished)
	frame_changed.connect(_apply_tool_action_pose)
	if use_selected_character:
		SaveManager.selected_character_changed.connect(
			refresh_character
		)

		refresh_character()


func refresh_character() -> void:
	cancel_tool_action()
	sprite_frames = preload(
		"res://character_data.gd"
	).frames_for(
		SaveManager.selected_character_id
	)

	refresh_character_size()

	play(
		"idle_" + facing
	)


func refresh_character_size() -> void:
	if sprite_frames == null:
		return

	if not sprite_frames.has_animation(
		"idle_down"
	):
		return

	if (
		not is_finite(
			target_character_height
		)
		or target_character_height <= 0.0
	):
		return

	var texture: Texture2D = null

	for index in range(
		sprite_frames.get_frame_count(
			"idle_down"
		)
	):
		texture = (
			sprite_frames
			.get_frame_texture(
				"idle_down",
				index
			)
		)

		if (
			texture != null
			and texture.get_height() > 0
		):
			break

	if texture == null:
		return

	if texture.get_height() <= 0:
		return

	var source_height: float = float(
		texture.get_height()
	)

	var ground_y: float = 0.0

	var collision := (
		get_parent()
		.get_node_or_null(
			"CollisionShape2D"
		)
	)

	if collision is CollisionShape2D:
		ground_y = (
			collision.position.y
		)

	var bottom: float = (
		source_height
	)

	var frame_image: Image = (
		texture.get_image()
	)

	if frame_image != null:
		var used: Rect2i = (
			frame_image.get_used_rect()
		)

		if used.has_area():
			bottom = float(
				used.end.y
			)

	# The supplied Player 1 sheets retain generous transparent canvas space.
	# Fit its visible character, not that padding, to the existing target height;
	# other character options retain their established scaling behaviour.
	var scale_height: float = source_height
	if SaveManager.selected_character_id == "farmer_01" and frame_image != null:
		var visible: Rect2i = frame_image.get_used_rect()
		if visible.has_area():
			scale_height = float(visible.size.y)
	var factor: float = target_character_height / scale_height
	scale = Vector2(factor, factor)

	offset = Vector2(
		0,
		source_height * 0.5
		- bottom
		+ (
			ground_y - position.y
		) / factor
	)
	base_offset = offset
	locomotion_scale = scale
	locomotion_offset = offset
	if action_locked:
		_apply_tool_action_pose()


func _process(
	delta: float
) -> void:
	if action_locked:
		speed_scale = 1.0
		visible = presentation_enabled
		return

	var moving: bool = false

	var body = get_parent()

	if body is CharacterBody2D:
		var direction: Vector2 = (
			body.velocity
		)

		if not forced_facing.is_empty():
			facing = forced_facing

			moving = false

		else:
			moving = (
				direction.length_squared()
				> 0.01
			)

			if moving:
				if (
					absf(direction.x)
					> absf(direction.y)
				):
					facing = (
						"right"
						if direction.x > 0
						else "left"
					)

				else:
					facing = (
						"down"
						if direction.y > 0
						else "up"
					)

	var requested: String = (
		("walk_" if moving else "idle_")
		+ facing
	)

	var has_art: bool = (
		sprite_frames != null
		and sprite_frames.has_animation(
			requested
		)
		and sprite_frames.get_frame_count(
			requested
		) > 0
	)

	if has_art:
		has_art = (
			sprite_frames.get_frame_texture(
				requested,
				0
			)
			!= null
		)

	if (
		has_art
		and animation != requested
	):
		play(requested)

	elif (
		has_art
		and not is_playing()
	):
		play(requested)

	var speed_ratio := 0.0
	if body is CharacterBody2D:
		var speed_value: Variant = body.get("speed")
		var player_speed: float = float(speed_value) if speed_value is int or speed_value is float else 0.0
		if player_speed > 0.0:
			speed_ratio = clampf(body.velocity.length() / player_speed, 0.0, 1.0)
	if moving:
		walk_phase += delta * lerpf(6.0, 10.0, speed_ratio)
		speed_scale = lerpf(0.82, 1.3, speed_ratio)
		# A restrained bob keeps the feet grounded without fighting the action
		# tween, which animates the sprite's position separately.
		offset = base_offset + Vector2(0, sin(walk_phase) * 1.0)
	else:
		speed_scale = 1.0
		offset = offset.lerp(base_offset, clampf(delta * 10.0, 0.0, 1.0))

	visible = (
		has_art
		and presentation_enabled
	)

	for path in fallback_paths:
		var fallback = (
			get_node_or_null(path)
		)

		if fallback is CanvasItem:
			fallback.visible = (
				not visible
			)


func force_facing(
	direction: String
) -> void:
	cancel_tool_action()

	if direction not in [
		"left",
		"right",
		"up",
		"down"
	]:
		return

	if forced_facing.is_empty():
		facing_before_force = facing

	forced_facing = direction

	facing = direction

	play(
		"idle_" + facing
	)


func clear_forced_facing() -> void:
	if forced_facing.is_empty():
		return

	forced_facing = ""

	facing = facing_before_force


func play_tool_action(tool: String, direction: String) -> bool:
	var requested := StringName(tool + "_swing_" + direction)
	if action_locked or not forced_facing.is_empty() or sprite_frames == null:
		return false
	if not Player1Frames.TOOL_ACTION_FIT.has(str(requested)) or not sprite_frames.has_animation(requested):
		return false
	current_action = requested
	action_locked = true
	facing = direction
	speed_scale = 1.0
	play(requested)
	_apply_tool_action_pose()
	visible = presentation_enabled
	return true


func _apply_tool_action_pose() -> void:
	if not action_locked or not Player1Frames.TOOL_ACTION_FIT.has(str(current_action)):
		return
	var fit: Array = Player1Frames.TOOL_ACTION_FIT[str(current_action)]
	var anchor: Vector2 = fit[1][clampi(frame, 0, 5)]
	var factor: float = target_character_height / float(fit[0])
	var ground_y: float = 0.0
	var collision := get_parent().get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		ground_y = collision.position.y
	scale = Vector2.ONE * factor
	offset = Player1Frames.TOOL_FRAME_SIZE * 0.5 - anchor + Vector2(0, (ground_y - position.y) / factor)
	var tool := get_parent().get_node_or_null("ToolVisual")
	if tool != null and tool.has_method("sync_body_pose"):
		var grip: Vector2 = Player1Frames.TOOL_GRIPS[str(current_action)][clampi(frame,0,5)]
		var angle: float = Player1Frames.TOOL_ANGLES[facing][clampi(frame,0,5)]
		tool.sync_body_pose(position + (offset + grip - Player1Frames.TOOL_FRAME_SIZE * 0.5) * scale, angle)


func _on_tool_action_finished() -> void:
	if action_locked and animation == current_action:
		cancel_tool_action()


func cancel_tool_action() -> void:
	if not action_locked:
		return
	action_locked = false
	current_action = &""
	scale = locomotion_scale
	offset = locomotion_offset
	base_offset = locomotion_offset
	speed_scale = 1.0
	if sprite_frames != null and sprite_frames.has_animation("idle_" + facing):
		play("idle_" + facing)
