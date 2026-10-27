extends Control

# Project-owned vector placeholders. Replace this visual with textures later.
@export var item_id: String = "":
	set(value):
		item_id = value
		queue_redraw()

const INK := Color("68462f")
const GREEN := Color("67974e")
const COLORS: Dictionary = {
	"wheat":Color("e9b84d"), "corn":Color("efc64e"), "carrot":Color("e68b45"),
	"soybean":Color("91ad55"), "sugarcane":Color("88b36b"), "cotton":Color("f8f1dc"),
	"flax":Color("8b97cb"), "golden_fish":Color("e4b746"), "river_fish":Color("779bba")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var side: float = minf(size.x,size.y)
	draw_set_transform((size-Vector2.ONE*side)/2,0,Vector2.ONE*side/64)
	var id: String = item_id.trim_suffix("_seed")
	var color: Color = COLORS.get(id,Color("bd9567"))
	if item_id.ends_with("_seed"):
		_poly([Vector2(18,18),Vector2(46,18),Vector2(51,53),Vector2(13,53)],Color("c89a63"))
		draw_rect(Rect2(19,12,26,8),INK)
		draw_circle(Vector2(32,36),12,Color("f5e6be"))
		draw_line(Vector2(32,44),Vector2(32,29),GREEN,3,true)
		draw_circle(Vector2(27,32),4,color)
		draw_circle(Vector2(36,28),4,color)
	elif id in ["wheat","flax"]:
		draw_line(Vector2(25,55),Vector2(37,12),GREEN,4,true)
		for n in range(4):
			var point := Vector2(30+n*2,39-n*7)
			draw_circle(point+Vector2(-5,-2),5,color)
			draw_circle(point+Vector2(5,-5),5,color)
	elif id == "carrot":
		_poly([Vector2(20,23),Vector2(45,29),Vector2(23,57)],color)
		for dx in [-10,0,10]:
			draw_line(Vector2(33,26),Vector2(33+dx,10),GREEN,5,true)
	elif id == "corn":
		draw_style_box(_rounded(color),Rect2(23,10,21,40))
		for y in range(18,45,8):
			draw_line(Vector2(26,y),Vector2(41,y),Color("b88d31"),1,true)
		_poly([Vector2(14,28),Vector2(35,52),Vector2(25,56)],GREEN)
		_poly([Vector2(50,24),Vector2(39,55),Vector2(29,56)],GREEN.lightened(0.15))
	elif id in ["soybean","sugarcane","cotton"]:
		draw_line(Vector2(32,55),Vector2(32,15),GREEN,5,true)
		if id == "sugarcane":
			for x in [24,36,44]:
				draw_line(Vector2(x,54),Vector2(x-3,12),color,6,true)
				for y in [23,36,47]:
					draw_line(Vector2(x-5,y),Vector2(x+2,y),INK,1,true)
		else:
			for p in [Vector2(23,29),Vector2(39,23),Vector2(32,16)]:
				draw_circle(p,10 if id == "cotton" else 7,color)
			draw_line(Vector2(32,46),Vector2(17,39),GREEN,6,true)
	elif id in ["axe","hammer"]:
		draw_line(Vector2(21,54),Vector2(39,14),INK,9,true)
		draw_line(Vector2(21,54),Vector2(39,14),Color("b7824f"),5,true)
		_poly([Vector2(29,13),Vector2(51,13),Vector2(53,30),Vector2(35,27)],Color("a6b8b8"))
		if id == "axe":
			_poly([Vector2(29,13),Vector2(15,13),Vector2(11,29),Vector2(31,25)],Color("d2dbd2"))
	elif id == "fishing_rod":
		draw_line(Vector2(16,54),Vector2(42,10),INK,5,true)
		draw_line(Vector2(42,10),Vector2(51,38),Color("7796a0"),2,true)
		draw_arc(Vector2(47,40),5,0,PI,12,INK,2,true)
	elif id.ends_with("fish"):
		_poly([Vector2(42,30),Vector2(58,18),Vector2(58,47),Vector2(42,37)],color)
		draw_style_box(_rounded(color),Rect2(8,20,39,26))
		draw_circle(Vector2(18,29),3,INK)
	elif id == "egg":
		draw_set_transform((size-Vector2.ONE*side)/2,0,Vector2(side/64,side/64*1.2))
		draw_circle(Vector2(32,28),17,Color("f0d3a0"))
		draw_circle(Vector2(27,22),5,Color("fff2cd"))
	elif id in ["milk","cream"]:
		draw_style_box(_rounded(Color("f5f0d8")),Rect2(19,22,27,33))
		draw_rect(Rect2(24,12,17,12),Color("f5f0d8"))
		draw_rect(Rect2(23,10,19,6),Color("8caaba"))
		draw_rect(Rect2(22,32,21,12),Color("9eb5be"))
	elif id == "coins":
		draw_circle(Vector2(32,33),22,INK)
		draw_circle(Vector2(32,31),19,Color("e9bd57"))
		draw_arc(Vector2(32,31),14,0,TAU,24,Color("b98434"),2,true)
		draw_line(Vector2(35,21),Vector2(27,27),Color("fff0b4"),3,true)
		draw_line(Vector2(27,27),Vector2(36,39),Color("fff0b4"),3,true)
	elif id == "wood":
		_poly([Vector2(10,39),Vector2(41,15),Vector2(56,31),Vector2(25,55)],Color("a97546"))
		draw_circle(Vector2(19,46),12,Color("e0b374"))
		draw_circle(Vector2(19,46),6,Color("b98a56"))
	elif id == "stone":
		_poly([Vector2(9,43),Vector2(18,20),Vector2(39,12),Vector2(55,35),Vector2(47,52),Vector2(21,55)],Color("99a4a0"))
		_poly([Vector2(18,20),Vector2(39,12),Vector2(34,34)],Color("c5ccc0"))
	elif id in ["bread","corn_bread","carrot_pie","butter","cheese"]:
		draw_style_box(_rounded(Color("deb568")),Rect2(10,22,46,30))
		for x in [21,32,43]:
			draw_line(Vector2(x,27),Vector2(x-4,38),Color("b17b42"),3,true)
	elif id in ["chicken_feed","cow_feed","cotton_thread"]:
		draw_style_box(_rounded(Color("b88757")),Rect2(15,19,34,36))
		draw_circle(Vector2(32,36),11,Color("e9cb8d"))
		for x in [26,32,38]:
			draw_line(Vector2(x,29),Vector2(x,43),GREEN if id == "cow_feed" else Color("aa8157"),3,true)
	else:
		draw_style_box(_rounded(color),Rect2(12,15,40,38))
		draw_line(Vector2(16,25),Vector2(48,25),INK,3,true)
		draw_line(Vector2(32,18),Vector2(32,49),Color("f2d5a1"),5,true)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)
	draw_polyline(PackedVector2Array(points+[points[0]]),INK,1.5,true)

func _rounded(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = INK
	return box
