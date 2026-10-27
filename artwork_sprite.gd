extends Sprite2D

@export var artwork_id: String = ""
# Zero preserves the authored scale of existing, manually textured sprites.
@export var target_size: Vector2 = Vector2.ZERO
@export var texture_paths: Array[String] = []
@export var fallback_paths: Array[NodePath] = []

static var _texture_cache: Dictionary = {}

func _ready() -> void:
	if texture == null:
		texture = _find_artwork_texture()
	if texture != null and target_size.x > 0.0 and target_size.y > 0.0:
		var texture_size := Vector2(texture.get_size())
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var fit_scale := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
			scale = Vector2.ONE * fit_scale
	texture_changed.connect(_refresh_fallback)
	visibility_changed.connect(_refresh_fallback)
	_refresh_fallback()


func _find_artwork_texture() -> Texture2D:
	var candidates: Array[String] = []
	if not artwork_id.is_empty():
		candidates.append_array([
			"res://assets/buildings/%s/%s.png" % [artwork_id, artwork_id],
			"res://assets/buildings/%s/%s.svg" % [artwork_id, artwork_id],
			"res://assets/buildings/%s.png" % artwork_id,
			"res://assets/buildings/%s.svg" % artwork_id,
			"res://assets/environment/%s/%s.png" % [artwork_id, artwork_id],
			"res://assets/environment/%s.png" % artwork_id,
		])
	candidates.append_array(texture_paths)
	for path in candidates:
		if _texture_cache.has(path):
			var cached: Variant = _texture_cache[path]
			if cached is Texture2D:
				return cached
			continue
		var loaded: Resource = load(path) if ResourceLoader.exists(path) else null
		_texture_cache[path] = loaded
		if loaded is Texture2D:
			return loaded
	return null


func _refresh_fallback() -> void:
	for path in fallback_paths:
		var fallback := get_node_or_null(path)
		if fallback is CanvasItem:
			fallback.visible = texture == null or not visible
