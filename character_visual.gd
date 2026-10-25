@tool
extends AnimatedSprite2D

@export var fallback_paths: Array[NodePath] = []
@export var presentation_enabled: bool = true
var facing: String = "down"

func _process(_delta: float) -> void:
	var moving: bool = false
	var body = get_parent()
	if not Engine.is_editor_hint() and body is CharacterBody2D:
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
