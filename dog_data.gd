extends RefCounted

# Pet definitions are deliberately data-only. Runtime Dogs mirror profiles
# from SaveManager; this keeps pricing, visual identity and behaviour in one
# place and makes save migration independent from scene nodes.
const DOG_VARIANTS: Dictionary = {
	"shiba": {
		"id": "shiba", "pet_id": "dog_shiba", "display_name": "Shiba",
		"default_name": "Mochi", "texture_path": "res://assets/animals/dogs/shiba.png",
		"sheet_path": "res://assets/animals/dogs/shiba/shiba_poses.png",
		"price": 350, "unlock_level": 3, "speed": 68.0, "wander_radius": 130.0,
		"greet_chance": 0.78, "sleep_weight": 0.13, "lie_weight": 0.25, "wander_weight": 0.62,
		"personality": "energetic", "home_slot": Vector2(-42, 28), "food_slot": Vector2(-30, 50)
	},
	"cream": {
		"id": "cream", "pet_id": "dog_cream", "display_name": "Cream Dog",
		"default_name": "Sunny", "texture_path": "res://assets/animals/dogs/cream.png",
		"sheet_path": "res://assets/animals/dogs/cream/cream_poses.png",
		"price": 450, "unlock_level": 6, "speed": 54.0, "wander_radius": 100.0,
		"greet_chance": 0.42, "sleep_weight": 0.42, "lie_weight": 0.48, "wander_weight": 0.30,
		"personality": "calm", "home_slot": Vector2(0, 38), "food_slot": Vector2(0, 52)
	},
	"blacktan": {
		"id": "blacktan", "pet_id": "dog_blacktan", "display_name": "Black Tan Dog",
		"default_name": "Bear", "texture_path": "res://assets/animals/dogs/blacktan.png",
		"sheet_path": "res://assets/animals/dogs/blacktan/blacktan_poses.png",
		"price": 550, "unlock_level": 10, "speed": 64.0, "wander_radius": 125.0,
		"greet_chance": 0.66, "sleep_weight": 0.22, "lie_weight": 0.30, "wander_weight": 0.58,
		"personality": "playful", "home_slot": Vector2(42, 28), "food_slot": Vector2(30, 50)
	}
}

const DOG_IDS: Array[String] = ["dog_shiba", "dog_cream", "dog_blacktan"]
const DOG_FOOD_PRICE: int = 20
const MAX_DOGS: int = 3
const HUNGRY_THRESHOLD: float = 35.0
const HUNGER_PER_SECOND: float = 1.0 / 60.0
const MAX_OFFLINE_HUNGER_LOSS: float = 20.0
const SHEET_GRID: int = 4
const SHEET_FRAME_SIZE: float = 313.5
# Generated artwork has a common 4x4 cell grid. Keeping the origin at this
# baseline prevents feet from jumping while AnimatedSprite2D changes frames.
const SHEET_GROUND_Y: float = 282.0
const TARGET_BODY_HEIGHT: float = 64.0

static var visual_frames_cache: Dictionary = {}

static func variant_for_pet(pet_id: String) -> Dictionary:
	for variant in DOG_VARIANTS.values():
		if variant["pet_id"] == pet_id:
			return variant
	return {}

static func pet_id_for_variant(variant_id: String) -> String:
	return str(DOG_VARIANTS.get(variant_id, {}).get("pet_id", ""))

static func texture_for_variant(variant_id: String) -> Texture2D:
	var path := str(DOG_VARIANTS.get(variant_id, {}).get("texture_path", ""))
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


static func visual_sheet_for_variant(variant_id: String) -> Texture2D:
	var path := str(DOG_VARIANTS.get(variant_id, {}).get("sheet_path", ""))
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


static func visual_frames_for_variant(variant_id: String) -> SpriteFrames:
	if visual_frames_cache.has(variant_id):
		return visual_frames_cache[variant_id]
	var sheet := visual_sheet_for_variant(variant_id)
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# The generated 4x4 boards share this exact pose order: idle, blink, four
	# walk poses, four run poses, sit, lie, sleep, eat, happy, alert.  Do not
	# remap bottom-row cells as rest poses: that was the source of Black Tan
	# briefly showing the wrong art while running/resting.
	_add_animation(frames, &"idle", [0, 0, 0, 0], 6.0, true, sheet)
	_add_animation(frames, &"idle_blink", [0, 1, 1, 0], 8.0, false, sheet)
	_add_animation(frames, &"walk", [2, 3, 4, 5, 4, 3, 2, 0], 9.0, true, sheet)
	_add_animation(frames, &"run", [6, 7, 8, 9, 8, 7, 6, 9], 12.0, true, sheet)
	_add_animation(frames, &"sit", [10, 10, 10, 10], 7.0, false, sheet)
	_add_animation(frames, &"sit_idle", [10, 10, 10, 10], 5.0, true, sheet)
	_add_animation(frames, &"lie_down", [10, 11, 11, 11], 8.0, false, sheet)
	_add_animation(frames, &"lie_idle", [11, 11, 11, 11], 5.0, true, sheet)
	_add_animation(frames, &"sleep", [12, 12, 12, 12, 12, 12], 5.0, true, sheet)
	_add_animation(frames, &"wake_up", [12, 11, 10, 0], 8.0, false, sheet)
	_add_animation(frames, &"eat", [13, 13, 13, 13, 13, 13], 8.0, true, sheet)
	_add_animation(frames, &"happy", [14, 14, 14, 0], 10.0, false, sheet)
	# Reuse the genuine nose-down and sit poses for the small optional beats;
	# this is safer than trying to read a pose from an empty/misaligned cell.
	_add_animation(frames, &"sniff", [13, 13, 13, 0], 7.0, false, sheet)
	_add_animation(frames, &"scratch", [10, 10, 10, 0], 8.0, false, sheet)
	_add_animation(frames, &"shake", [0, 2, 0, 3, 0, 2, 0, 0], 12.0, false, sheet)
	_add_animation(frames, &"alert", [15, 15, 15, 0], 7.0, false, sheet)
	visual_frames_cache[variant_id] = frames
	return frames


static func _add_animation(frames: SpriteFrames, animation_name: StringName, indexes: Array, fps: float, loop: bool, sheet: Texture2D) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for index in indexes:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(int(index) % SHEET_GRID) * SHEET_FRAME_SIZE,
			float(int(index) / SHEET_GRID) * SHEET_FRAME_SIZE,
			SHEET_FRAME_SIZE,
			SHEET_FRAME_SIZE
		)
		frames.add_frame(animation_name, atlas)

static func normalized_name(value: Variant, fallback: String) -> String:
	if not value is String:
		return fallback
	var clean: String = String(value).strip_edges()
	clean = clean.replace("\n", "").replace("\r", "").replace("\t", "")
	return clean.left(16) if not clean.is_empty() else fallback

static func default_profile(variant_id: String, now: float = -1.0) -> Dictionary:
	var data: Dictionary = DOG_VARIANTS.get(variant_id, {})
	if data.is_empty():
		return {}
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return {
		"variant": variant_id,
		"name": data["default_name"],
		"owned": true,
		"hunger": 100.0,
		"last_hunger_update_at": now
	}
