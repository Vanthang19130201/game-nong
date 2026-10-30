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

const TOOL_ACTION_FPS: float = 8.0
const TOOL_FRAME_SIZE := Vector2(512, 512)
const TOOL_ACTION_ROOT: String = "res://assets/characters/farmer_01/player1/player1_"
# Explicit reference heights and foot anchors inside each fixed 512px cell.
# Per-frame offset corrects source-canvas drift without moving Player/collision.
# Plant/harvest strips are intentionally NOT registered or loaded.
const TOOL_ACTION_FIT: Dictionary = {
	"axe_swing_down": [389.0, [Vector2(305.5,480),Vector2(264.5,481),Vector2(256,491),Vector2(300,445),Vector2(256,450),Vector2(245,450)]],
	"axe_swing_up": [376.0, [Vector2(266,487),Vector2(257,488),Vector2(253,488),Vector2(268,455),Vector2(264,455),Vector2(246.5,455)]],
	"axe_swing_left": [401.0, [Vector2(293.5,478),Vector2(281.5,478),Vector2(282.5,478),Vector2(310,440),Vector2(288,441),Vector2(280,440)]],
	"axe_swing_right": [370.0, [Vector2(257.5,470),Vector2(252.5,470),Vector2(255,470),Vector2(262,445),Vector2(264,444),Vector2(273,447)]],
	"hammer_swing_down": [380.0, [Vector2(271.5,496),Vector2(257,498),Vector2(230.5,498),Vector2(271,452),Vector2(255.5,452),Vector2(242,452)]],
	"hammer_swing_up": [364.0, [Vector2(286,470),Vector2(256.5,471),Vector2(236.5,475),Vector2(302.5,441),Vector2(270,436),Vector2(223.5,442)]],
	"hammer_swing_left": [382.0, [Vector2(325,492),Vector2(284.5,492),Vector2(280,492),Vector2(320,447),Vector2(288,447),Vector2(275,448)]],
	"hammer_swing_right": [386.0, [Vector2(261.5,496),Vector2(258,496),Vector2(241,496),Vector2(281,448),Vector2(255,447),Vector2(241,453)]],
}
# Grip positions in the same original cells. The existing ToolVisual attaches
# here, rather than remaining at the old standing character's hand position.
const TOOL_GRIPS: Dictionary = {
	"axe_swing_down": [Vector2(310,390),Vector2(256,95),Vector2(176,332),Vector2(268,354),Vector2(252,390),Vector2(313,284)],
	"axe_swing_up": [Vector2(338,384),Vector2(354,200),Vector2(255,100),Vector2(346,306),Vector2(186,333),Vector2(318,350)],
	"axe_swing_left": [Vector2(342,356),Vector2(365,164),Vector2(360,160),Vector2(207,322),Vector2(188,338),Vector2(267,343)],
	"axe_swing_right": [Vector2(299,340),Vector2(169,215),Vector2(175,187),Vector2(353,319),Vector2(380,290),Vector2(322,322)],
	"hammer_swing_down": [Vector2(256,410),Vector2(207,130),Vector2(270,406),Vector2(277,398),Vector2(253,401),Vector2(226,368)],
	"hammer_swing_up": [Vector2(344,375),Vector2(260,133),Vector2(267,110),Vector2(288,354),Vector2(225,300),Vector2(292,350)],
	"hammer_swing_left": [Vector2(270,387),Vector2(357,168),Vector2(134,225),Vector2(197,352),Vector2(210,327),Vector2(249,345)],
	"hammer_swing_right": [Vector2(344,368),Vector2(126,220),Vector2(184,110),Vector2(347,335),Vector2(350,373),Vector2(300,335)],
}
const TOOL_ANGLES: Dictionary = {
	"down": [PI*0.9,0.0,-0.6,PI*0.95,PI,PI*0.7],
	"up": [0.0,0.0,0.4,-0.2,0.0,0.0],
	"left": [-PI*0.5,0.35,-0.55,-PI*0.65,-PI*0.5,-PI*0.32],
	"right": [PI*0.5,-0.35,0.55,PI*0.65,PI*0.5,PI*0.32],
}

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
	for action_name in TOOL_ACTION_FIT:
		var texture: Texture2D = load(TOOL_ACTION_ROOT + str(action_name) + ".png") as Texture2D
		_add_strip(result, StringName(action_name), texture, TOOL_ACTION_FPS, TOOL_FRAME_SIZE, false)
	_frames = result
	return _frames


static func _add_strip(result: SpriteFrames, animation_name: StringName, texture: Texture2D, fps: float, cell_size: Vector2 = FRAME_SIZE, looping: bool = true) -> void:
	result.add_animation(animation_name)
	result.set_animation_loop(animation_name, looping)
	result.set_animation_speed(animation_name, fps)
	for frame_index in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(frame_index * int(cell_size.x), 0), cell_size)
		result.add_frame(animation_name, atlas)
