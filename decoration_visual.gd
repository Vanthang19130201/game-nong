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
		"fishing_sign":
			draw_rect(Rect2(-3,-2,6,31),Color("704b34"))
			draw_rect(Rect2(-26,-25,52,28),Color("b98a58"))
			draw_rect(Rect2(-22,-21,44,20),Color("f0dfb8"))
			draw_arc(Vector2(0,-11),9,PI,TAU,16,Color("739eb0"),3,true)
		"golden_flower_pot":
			draw_colored_polygon(PackedVector2Array([Vector2(-20,-4),Vector2(20,-4),Vector2(15,23),Vector2(-15,23)]),Color("c88c54"))
			for point in [Vector2(-11,-13),Vector2(0,-20),Vector2(11,-12)]:
				draw_line(Vector2(0,0),point,Color("668a47"),3,true)
				draw_circle(point,5,Color("e9b84d"))
		"treasure_chest":
			draw_rect(Rect2(-25,-12,50,30),Color("89562f"))
			draw_arc(Vector2(0,-12),25,PI,TAU,18,Color("b98445"),8,true)
			draw_rect(Rect2(-3,-6,6,13),Color("e6c266"))
		"golden_scarecrow":
			draw_line(Vector2(0,-27),Vector2(0,25),Color("704b34"),6,true)
			draw_line(Vector2(-21,-9),Vector2(21,-9),Color("704b34"),5,true)
			draw_circle(Vector2(0,-19),9,Color("e4b852"))
			draw_colored_polygon(PackedVector2Array([Vector2(-13,-9),Vector2(13,-9),Vector2(17,17),Vector2(-17,17)]),Color("7e9a58"))
		"ancient_statue":
			draw_rect(Rect2(-20,7,40,19),Color("77786c"))
			draw_rect(Rect2(-15,-22,30,30),Color("969487"))
			draw_circle(Vector2(0,-26),12,Color("a6a08e"))
			draw_rect(Rect2(-5,-32,3,3),Color("554d43"))
		"river_lantern":
			draw_rect(Rect2(-3,-2,6,32),Color("704b34"))
			draw_rect(Rect2(-11,-26,22,19),Color("9a6845"))
			draw_rect(Rect2(-6,-21,12,10),Color("f0c56a",0.85))
