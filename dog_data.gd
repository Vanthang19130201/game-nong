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
# The original one-dog artwork is deliberately used at runtime. The large
# generated pose boards remain source/preview material only: their detailed
# cells read too large and busy beside the farm's compact characters.
const TARGET_BODY_HEIGHT: float = 52.0

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
	var texture := texture_for_variant(variant_id)
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# Keep the existing state names so behaviour remains untouched, but render a
	# clean, compact master sprite in every state instead of a mismatched pose
	# board. Gentle bob/heart/ZZZ effects in dog_visual.gd still provide life.
	for animation_name in [&"idle", &"idle_blink", &"walk", &"run", &"sit", &"sit_idle", &"lie_down", &"lie_idle", &"sleep", &"wake_up", &"eat", &"happy", &"sniff", &"scratch", &"shake", &"alert"]:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 6.0)
		frames.set_animation_loop(animation_name, animation_name in [&"idle", &"walk", &"run", &"sit_idle", &"lie_idle", &"sleep", &"eat"])
		frames.add_frame(animation_name, texture)
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
