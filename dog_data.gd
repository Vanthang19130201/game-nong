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
		"personality": "energetic", "home_slot": Vector2(-42, 28), "food_slot": Vector2(-30, 50),
		"sheet_columns": 4, "sheet_rows": 4, "visual_target_height": 62.0, "visual_art_height": 260.0, "ground_y": 312.0
	},
	"cream": {
		"id": "cream", "pet_id": "dog_cream", "display_name": "Cream Dog",
		"default_name": "Sunny", "texture_path": "res://assets/animals/dogs/cream.png",
		"sheet_path": "res://assets/animals/dogs/cream/cream_poses.png",
		"price": 450, "unlock_level": 6, "speed": 54.0, "wander_radius": 100.0,
		"greet_chance": 0.42, "sleep_weight": 0.42, "lie_weight": 0.48, "wander_weight": 0.30,
		"personality": "calm", "home_slot": Vector2(0, 38), "food_slot": Vector2(0, 52),
		"sheet_columns": 4, "sheet_rows": 4, "visual_target_height": 62.0, "visual_art_height": 266.0, "ground_y": 288.0
	},
	"blacktan": {
		"id": "blacktan", "pet_id": "dog_blacktan", "display_name": "Black Tan Dog",
		"default_name": "Bear", "texture_path": "res://assets/animals/dogs/blacktan.png",
		"sheet_path": "res://assets/animals/dogs/blacktan/blacktan_poses.png",
		"price": 550, "unlock_level": 10, "speed": 64.0, "wander_radius": 125.0,
		"greet_chance": 0.66, "sleep_weight": 0.22, "lie_weight": 0.30, "wander_weight": 0.58,
		"personality": "playful", "home_slot": Vector2(42, 28), "food_slot": Vector2(30, 50),
		"sheet_columns": 4, "sheet_rows": 4, "visual_target_height": 60.0, "visual_art_height": 252.0, "ground_y": 294.0
	}
}

const DOG_IDS: Array[String] = ["dog_shiba", "dog_cream", "dog_blacktan"]
const DOG_FOOD_PRICE: int = 20
const MAX_DOGS: int = 3
const HUNGRY_THRESHOLD: float = 35.0
const HUNGER_PER_SECOND: float = 1.0 / 60.0
const MAX_OFFLINE_HUNGER_LOSS: float = 20.0
const ANIMATION_NAMES: Array[StringName] = [&"idle", &"idle_blink", &"walk", &"run", &"sit", &"sit_idle", &"lie_down", &"lie_idle", &"sleep", &"wake_up", &"eat", &"happy", &"sniff", &"scratch", &"shake", &"alert"]

# The source boards are 1254x1254, so a 4x4 grid does *not* have fractional
# runtime cells. _cell_region() rounds the boundaries instead, giving exact
# 314/313 pixel regions and preventing neighbouring poses from bleeding in.
const DEFAULT_POSE_CELLS: Dictionary = {
	"idle": [0], "idle_blink": [0, 1, 1, 0],
	"walk": [2, 3, 4, 5, 4, 3], "run": [6, 7, 6, 7],
	"sit": [8], "sit_idle": [8], "lie_down": [8, 9], "lie_idle": [9],
	"sleep": [10], "wake_up": [10, 9, 8, 0], "eat": [11],
	"happy": [12, 12, 0], "sniff": [13, 13, 0],
	"scratch": [14, 14, 0], "shake": [0, 2, 0, 3, 0], "alert": [15, 15, 0]
}

# Black Tan's board keeps its four running poses in cells 6..9 and its calm
# poses one row lower. The other two boards have sit in cell 8. Keeping this
# in data avoids visual conditionals scattered through DogVisual.
const BLACKTAN_POSE_CELLS: Dictionary = {
	"idle": [0], "idle_blink": [0, 1, 1, 0],
	"walk": [2, 3, 4, 5, 4, 3], "run": [6, 7, 8, 9, 8, 7],
	"sit": [10], "sit_idle": [10], "lie_down": [10, 11], "lie_idle": [11],
	"sleep": [12], "wake_up": [12, 11, 10, 0], "eat": [14, 14, 13],
	"happy": [13, 13, 0], "sniff": [14, 14, 0],
	"scratch": [14, 13, 14, 0], "shake": [0, 2, 0, 3, 0], "alert": [15, 15, 0]
}

# Calibrated per-cell foot anchors in source pixels. Each point is the visual
# centre/contact of that pose, not the texture centre or tail/fur bounds.
# DogVisual converts these to Sprite2D.offset on frame_changed, so neither the
# CharacterBody2D nor its shadow/collision/labels ever move to hide a frame.
const SHIBA_CELL_ANCHORS: Array[Vector2] = [
	Vector2(178, 312), Vector2(178, 312), Vector2(166, 312), Vector2(160, 312),
	Vector2(171, 297), Vector2(156, 297), Vector2(156, 273), Vector2(152, 279),
	Vector2(164, 312), Vector2(154, 270), Vector2(158, 264), Vector2(153, 312),
	Vector2(170, 246), Vector2(166, 258), Vector2(165, 258), Vector2(158, 264)
]
const CREAM_CELL_ANCHORS: Array[Vector2] = [
	Vector2(165, 288), Vector2(156, 288), Vector2(156, 285), Vector2(150, 285),
	Vector2(170, 270), Vector2(154, 273), Vector2(160, 267), Vector2(153, 267),
	Vector2(168, 312), Vector2(156, 234), Vector2(142, 240), Vector2(152, 312),
	Vector2(170, 258), Vector2(156, 255), Vector2(150, 258), Vector2(146, 264)
]
const BLACKTAN_CELL_ANCHORS: Array[Vector2] = [
	Vector2(166, 294), Vector2(172, 294), Vector2(176, 294), Vector2(153, 294),
	Vector2(172, 267), Vector2(156, 264), Vector2(156, 312), Vector2(153, 249),
	Vector2(164, 240), Vector2(156, 312), Vector2(141, 252), Vector2(154, 312),
	Vector2(162, 255), Vector2(156, 258), Vector2(156, 261), Vector2(148, 249)
]

const ANIMATION_FPS: Dictionary = {
	"idle": 6.0, "idle_blink": 8.0, "walk": 9.0, "run": 12.0,
	"sit": 7.0, "sit_idle": 5.0, "lie_down": 8.0, "lie_idle": 5.0,
	"sleep": 5.0, "wake_up": 8.0, "eat": 8.0, "happy": 10.0,
	"sniff": 7.0, "scratch": 9.0, "shake": 12.0, "alert": 7.0
}
const LOOPING_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"run", &"sit_idle", &"lie_idle", &"sleep", &"eat"]

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
	var data: Dictionary = DOG_VARIANTS.get(variant_id, DOG_VARIANTS["shiba"])
	var sheet := visual_sheet_for_variant(variant_id)
	if sheet == null:
		# Static master art is only a recovery path for a damaged/missing sheet.
		# Normal gameplay always builds atlas frames from the real pose board.
		push_warning("Dog pose sheet missing for %s; using static emergency fallback." % variant_id)
		return _static_fallback_frames(variant_id)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var pose_cells := pose_cells_for_variant(variant_id)
	var columns := int(data.get("sheet_columns", 4))
	var rows := int(data.get("sheet_rows", 4))
	for animation_name in ANIMATION_NAMES:
		_add_animation(
			frames,
			animation_name,
			pose_cells.get(String(animation_name), [0]),
			float(ANIMATION_FPS.get(String(animation_name), 6.0)),
			animation_name in LOOPING_ANIMATIONS,
			sheet,
			columns,
			rows
		)
	visual_frames_cache[variant_id] = frames
	return frames


static func _static_fallback_frames(variant_id: String) -> SpriteFrames:
	var texture := texture_for_variant(variant_id)
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name in ANIMATION_NAMES:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(ANIMATION_FPS.get(String(animation_name), 6.0)))
		frames.set_animation_loop(animation_name, animation_name in LOOPING_ANIMATIONS)
		frames.add_frame(animation_name, texture)
	visual_frames_cache[variant_id] = frames
	return frames


static func _add_animation(frames: SpriteFrames, animation_name: StringName, indexes: Array, fps: float, loop: bool, sheet: Texture2D, columns: int, rows: int) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for index in indexes:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = _cell_region(int(index), sheet, columns, rows)
		frames.add_frame(animation_name, atlas)


static func _cell_region(index: int, sheet: Texture2D, columns: int, rows: int) -> Rect2:
	var safe_columns := maxi(columns, 1)
	var safe_rows := maxi(rows, 1)
	var column := posmod(index, safe_columns)
	var row := clampi(index / safe_columns, 0, safe_rows - 1)
	var left := roundi(float(column) * float(sheet.get_width()) / safe_columns)
	var right := roundi(float(column + 1) * float(sheet.get_width()) / safe_columns)
	var top := roundi(float(row) * float(sheet.get_height()) / safe_rows)
	var bottom := roundi(float(row + 1) * float(sheet.get_height()) / safe_rows)
	return Rect2(left, top, right - left, bottom - top)


static func pose_cells_for_variant(variant_id: String) -> Dictionary:
	return BLACKTAN_POSE_CELLS if variant_id == "blacktan" else DEFAULT_POSE_CELLS


static func cell_for_animation_frame(variant_id: String, animation_name: StringName, frame: int) -> int:
	var cells: Array = pose_cells_for_variant(variant_id).get(String(animation_name), [0])
	return int(cells[posmod(frame, cells.size())]) if not cells.is_empty() else 0


static func cell_anchor_for_variant(variant_id: String, cell: int) -> Vector2:
	var anchors: Array[Vector2] = SHIBA_CELL_ANCHORS
	if variant_id == "cream":
		anchors = CREAM_CELL_ANCHORS
	elif variant_id == "blacktan":
		anchors = BLACKTAN_CELL_ANCHORS
	return anchors[clampi(cell, 0, anchors.size() - 1)]


static func target_anchor_for_variant(variant_id: String, sheet: Texture2D) -> Vector2:
	var data: Dictionary = DOG_VARIANTS.get(variant_id, DOG_VARIANTS["shiba"])
	var columns := maxi(int(data.get("sheet_columns", 4)), 1)
	return Vector2(float(sheet.get_width()) / columns * 0.5, float(data.get("ground_y", 280.0)))


static func visual_scale_for_variant(variant_id: String) -> float:
	var data: Dictionary = DOG_VARIANTS.get(variant_id, DOG_VARIANTS["shiba"])
	return float(data.get("visual_target_height", 62.0)) / float(data.get("visual_art_height", 260.0))


static func visual_ground_offset_for_variant(variant_id: String, sheet: Texture2D) -> float:
	var data: Dictionary = DOG_VARIANTS.get(variant_id, DOG_VARIANTS["shiba"])
	var rows := maxi(int(data.get("sheet_rows", 4)), 1)
	var cell_height := float(sheet.get_height()) / rows
	return (cell_height * 0.5 - float(data.get("ground_y", 282.0))) * visual_scale_for_variant(variant_id)

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
