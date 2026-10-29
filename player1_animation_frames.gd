extends RefCounted

# Player 1's supplied source strips are fixed six-column animation sheets.
# Build the SpriteFrames once, then CharacterData caches it for every preview
# and in-world Player instance. No regions are created during gameplay frames.
const FRAME_SIZE := Vector2(362, 724)
const FRAME_COUNT: int = 6

const IDLE_DOWN: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_idle_down.png")
const IDLE_UP: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_idle_up.png")
const IDLE_LEFT: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_idle_left.png")
const IDLE_RIGHT: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_idle_right.png")
const WALK_DOWN: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_walk_down.png")
const WALK_UP: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_walk_up.png")
const WALK_LEFT: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_walk_left.png")
const WALK_RIGHT: Texture2D = preload("res://assets/characters/farmer_01/player1/player1_walk_right.png")

static var _frames: SpriteFrames


static func frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	_add_strip(result, &"idle_down", IDLE_DOWN, 3.0)
	_add_strip(result, &"idle_up", IDLE_UP, 3.0)
	# The supplied horizontal *idle* strips are named from the artist's view:
	# `idle_left` depicts a character facing screen-right, and vice versa.
	# Only the standing pose needs this translation; walk strips already match
	# the existing movement controller's world-direction mapping.
	_add_strip(result, &"idle_left", IDLE_RIGHT, 3.0)
	_add_strip(result, &"idle_right", IDLE_LEFT, 3.0)
	_add_strip(result, &"walk_down", WALK_DOWN, 8.0)
	_add_strip(result, &"walk_up", WALK_UP, 8.0)
	_add_strip(result, &"walk_left", WALK_LEFT, 8.0)
	_add_strip(result, &"walk_right", WALK_RIGHT, 8.0)
	_frames = result
	return _frames


static func _add_strip(result: SpriteFrames, animation_name: StringName, texture: Texture2D, fps: float) -> void:
	result.add_animation(animation_name)
	result.set_animation_loop(animation_name, true)
	result.set_animation_speed(animation_name, fps)
	for frame_index in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * int(FRAME_SIZE.x), 0), FRAME_SIZE)
		result.add_frame(animation_name, atlas)
