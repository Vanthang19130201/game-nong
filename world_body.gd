extends StaticBody2D

# Scene-authored blockers follow visibility; placement previews never collide.
func _ready() -> void:
	get_parent().visibility_changed.connect(_refresh_collision)
	_refresh_collision()

func _refresh_collision() -> void:
	var object := get_parent()
	var inactive: bool = not object.is_visible_in_tree() or object.get("is_preview") == true
	$CollisionShape2D.set_deferred("disabled", inactive)
