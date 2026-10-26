extends Node2D

@export var texture: Texture2D

func _draw() -> void:
	var decoration = get_parent()
	if texture != null:
		draw_texture_rect(texture,Rect2(-32,-32,64,64),false)
		return
	match decoration.decoration_id:
		"stone_path":
			draw_rect(Rect2(-31,-31,62,62),Color(0.5,0.52,0.49))
			draw_rect(Rect2(-27,-27,54,54),Color(0.63,0.65,0.59),false,2)
		"wood_fence", "wood_gate":
			var wood := Color(0.58,0.36,0.17)
			draw_rect(Rect2(-30,-12,8,24),wood)
			draw_rect(Rect2(22,-12,8,24),wood)
			if decoration.decoration_id == "wood_gate" and decoration.is_open:
				draw_rect(Rect2(-26,-30,7,34),wood.lightened(0.2))
			else:
				draw_rect(Rect2(-27,-7,54,14),wood.lightened(0.2))
		"farm_lamp":
			draw_rect(Rect2(-4,-8,8,38),Color(0.28,0.26,0.2))
			draw_circle(Vector2(0,-18),12,Color(1,0.85,0.36))
