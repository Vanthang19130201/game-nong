extends Sprite2D

@export var fallback_paths: Array[NodePath] = []

func _ready() -> void:
	texture_changed.connect(_refresh_fallback)
	visibility_changed.connect(_refresh_fallback)
	_refresh_fallback()


func _refresh_fallback() -> void:
	for path in fallback_paths:
		var fallback = get_node_or_null(path)
		if fallback is CanvasItem:
			fallback.visible = texture == null or not visible
