extends AnimatedSprite2D

@export var fallback_paths: Array[NodePath] = []
@export var presentation_enabled: bool = true
@export var use_selected_character: bool = false
@export var character_height: float = 48.0
var facing: String = "down"

func _ready() -> void:
	if use_selected_character:
		SaveManager.selected_character_changed.connect(refresh_character)
		refresh_character()

func refresh_character() -> void:
	sprite_frames = preload("res://character_data.gd").frames_for(SaveManager.selected_character_id)
	if sprite_frames != null and sprite_frames.has_animation("idle_down") and sprite_frames.get_frame_count("idle_down") > 0:
		var texture := sprite_frames.get_frame_texture("idle_down", 0)
		if texture != null and texture.get_height() > 0:
			scale = Vector2.ONE * character_height / texture.get_height()
			offset = Vector2(0, -texture.get_height() * 0.5 + 12.0 / scale.y)
	play("idle_" + facing)

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
