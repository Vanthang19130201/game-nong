extends RefCounted

const DEFAULT_ID: String = "farmer_01"
const ANIMATIONS: Array[String] = ["idle_down", "idle_up", "idle_left", "idle_right", "walk_down", "walk_up", "walk_left", "walk_right"]
const Player1AnimationFrames = preload("res://player1_animation_frames.gd")
const CHARACTERS: Dictionary = {
	"farmer_01": {"name": "Farmer 1", "frames": "res://assets/characters/farmer_01/frames.tres"},
	"farmer_02": {"name": "Farmer 2", "frames": "res://assets/characters/farmer_02/frames.tres"},
	"farmer_03": {"name": "Farmer 3", "frames": "res://assets/characters/farmer_03/frames.tres"},
	"farmer_04": {"name": "Farmer 4", "frames": "res://assets/characters/farmer_04/frames.tres"},
}
static var _cache: Dictionary = {}

static func valid_id(value: Variant) -> String:
	return value if value is String and CHARACTERS.has(value) else DEFAULT_ID

static func frames_for(value: String) -> SpriteFrames:
	var id := valid_id(value)
	if _cache.has(id):
		return _cache[id] as SpriteFrames
	var frames: SpriteFrames = Player1AnimationFrames.frames() if id == "farmer_01" else _read_frames(str(CHARACTERS[id]["frames"]))
	if complete(frames) and id != "farmer_01":
		var path: String = str(CHARACTERS[id]["frames"])
		# A matching PNG replaces the SVG atlas, preserving authored animations.
		var png_path := path.get_base_dir().path_join("character.png")
		var png: Texture2D = load(png_path) as Texture2D if ResourceLoader.exists(png_path) else null
		if png != null:
			frames = frames.duplicate(true) as SpriteFrames
			for animation in frames.get_animation_names():
				for index in range(frames.get_frame_count(animation)):
					var texture := frames.get_frame_texture(animation, index)
					if texture is AtlasTexture and texture.atlas != null and texture.atlas.resource_path.get_file() == "character.svg":
						var atlas := texture.duplicate() as AtlasTexture
						var ratio: Vector2 = png.get_size() / texture.atlas.get_size()
						atlas.region = Rect2(texture.region.position * ratio, texture.region.size * ratio)
						atlas.atlas = png
						frames.set_frame(animation, index, atlas, frames.get_frame_duration(animation, index))
	if not complete(frames):
		frames = frames_for(DEFAULT_ID) if id != DEFAULT_ID else fallback_frames()
	_cache[id] = frames
	return frames

static func _read_frames(path: String) -> SpriteFrames:
	var resource: Resource = load(path) if ResourceLoader.exists(path) else null
	var frames := resource as SpriteFrames
	return frames if complete(frames) else null

static func complete(frames: SpriteFrames) -> bool:
	if frames == null:
		return false
	for animation in ANIMATIONS:
		if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
			return false
		for index in range(frames.get_frame_count(animation)):
			if frames.get_frame_texture(animation, index) == null:
				return false
	return true

static func fallback_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var texture: Texture2D = load("res://assets/characters/fallback.svg") as Texture2D
	for animation in ANIMATIONS:
		frames.add_animation(animation)
		frames.add_frame(animation, texture)
	return frames
