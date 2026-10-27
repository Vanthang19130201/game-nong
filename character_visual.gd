extends AnimatedSprite2D

@export var fallback_paths: Array[NodePath] = []
@export var presentation_enabled: bool = true
@export var use_selected_character: bool = false
@export_range(1.0, 256.0, 1.0, "or_greater") var target_character_height: float = 72.0
var facing: String = "down"

func _ready() -> void:
	if use_selected_character:
		SaveManager.selected_character_changed.connect(refresh_character)
		refresh_character()

func refresh_character() -> void:
	sprite_frames = preload("res://character_data.gd").frames_for(SaveManager.selected_character_id)
	refresh_character_size()
	play("idle_" + facing)

func refresh_character_size() -> void:
	# Presentation only: fit once after loading/changing a character, never per frame.
	if sprite_frames == null or not sprite_frames.has_animation("idle_down"):
		return
	if not is_finite(target_character_height) or target_character_height <= 0.0:
		return
	var texture: Texture2D = null
	for index in range(sprite_frames.get_frame_count("idle_down")):
		texture = sprite_frames.get_frame_texture("idle_down", index)
		if texture != null and texture.get_height() > 0:
			break
	if texture == null or texture.get_height() <= 0:
		return
	var source_height: float = float(texture.get_height())
	var factor: float = target_character_height / source_height
	scale = Vector2(factor, factor)
	# Pin the bottom of the visible artwork (including its ground shadow) to
	# the existing collision center. Texture padding must not make feet float.
	var ground_y: float = 0.0
	var collision := get_parent().get_node_or_null("CollisionShape2D")
	if collision is CollisionShape2D:
		ground_y = collision.position.y
	var bottom: float = source_height
	var frame_image: Image = texture.get_image()
	if frame_image != null:
		var used: Rect2i = frame_image.get_used_rect()
		if used.has_area():
			bottom = float(used.end.y)
	offset = Vector2(0, source_height * 0.5 - bottom + (ground_y - position.y) / factor)

func _process(_delta: float) -> void:
	var moving: bool = false
	var body = get_parent()
	if body is CharacterBody2D:
		var direction: Vector2 = body.velocity
		moving = direction.length_squared() > 0.01
		if moving:
			if absf(direction.x) > absf(direction.y):
				facing = "right" if direction.x > 0 else "left"
			else:
				facing = "down" if direction.y > 0 else "up"
	var requested: String = ("walk_" if moving else "idle_") + facing
	var has_art: bool = sprite_frames != null and sprite_frames.has_animation(requested) and sprite_frames.get_frame_count(requested) > 0
	if has_art:
		has_art = sprite_frames.get_frame_texture(requested, 0) != null
	if has_art and animation != requested:
		play(requested)
	elif has_art and not is_playing():
		play(requested)
	visible = has_art and presentation_enabled
	for path in fallback_paths:
		var fallback = get_node_or_null(path)
		if fallback is CanvasItem:
			fallback.visible = not visible
