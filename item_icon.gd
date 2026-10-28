extends Control

# Crop artwork with project-owned vector fallbacks for other items and seeds.
var _crop_texture: Texture2D
var _visual_texture: Texture2D

@export var item_id: String = "":
	set(value):
		item_id = value
		_crop_texture = _get_crop_texture()
		_visual_texture = _get_visual_texture()
		queue_redraw()

const CROP_TEXTURE_PATHS: Dictionary = {
	"wheat": "res://assets/crops/wheat/stage_3.png",
	"corn": "res://assets/crops/corn/stage_3.png",
	"carrot": "res://assets/crops/carrot/stage_3.png",
}
static var _texture_cache: Dictionary = {}
static var _visual_texture_cache: Dictionary = {}
const VISUAL_TEXTURE_PATHS: Dictionary = {
	"chicken": "res://assets/animals/chicken/chicken.png",
	"cow": "res://assets/animals/cow/cow.png",
	"pig": "res://assets/animals/pig/pig.png",
	"sheep": "res://assets/animals/sheep/sheep.png",
	"house": "res://assets/buildings/house/house_cozy_v2.png",
	"warehouse": "res://assets/buildings/warehouse/warehouse.svg",
	"feed_mill": "res://assets/buildings/feed_mill/feed_mill.svg",
	"chicken_coop": "res://assets/buildings/chicken_coop/chicken_coop.png",
	"cow_shed": "res://assets/buildings/cow_shed/cow_shed.png",
	"pig_pen": "res://assets/buildings/pig_pen/pig_pen.png",
	"sheep_barn": "res://assets/buildings/sheep_barn/sheep_barn.png",
	"bakery": "res://assets/buildings/bakery/bakery.svg",
	"dairy": "res://assets/buildings/dairy/dairy.svg",
	"spinning_machine": "res://assets/buildings/spinning_machine/spinning_machine.svg",
	"dog_house": "res://assets/buildings/dog_house/dog_house.svg",
	"market_stall": "res://assets/buildings/market_stall/market_stall.svg",
	"order_board": "res://assets/buildings/order_board/order_board.svg",
	"fish_market": "res://assets/buildings/fish_market/fish_market.svg",
	"fishing_bridge": "res://assets/buildings/fishing_bridge/fishing_bridge.svg"
}

const INK := Color("68462f")
const GREEN := Color("67974e")
const COLORS: Dictionary = {
	"wheat":Color("e9b84d"), "corn":Color("efc64e"), "carrot":Color("e68b45"),
	"soybean":Color("91ad55"), "sugarcane":Color("88b36b"), "cotton":Color("f8f1dc"),
	"flax":Color("8b97cb"), "golden_fish":Color("e4b746"), "river_fish":Color("779bba"),
	"golden_wheat":Color("e6bd45"), "golden_corn":Color("f1c839"), "giant_carrot":Color("e77c38"),
	"old_bottle":Color("73a29a"), "old_boot":Color("78624f"), "coin_pouch":Color("d2a344"),
	"small_chest":Color("b7793d"), "lost_lure":Color("b95f4c"), "ancient_coin":Color("e5be52"),
	"map_fragment":Color("d8c59b"), "ancient_gem":Color("58c8ba"), "moon_fish":Color("8e83b1"),
	"mystery":Color("b887c8"), "small_fish":Color("7aaec3"), "egg":Color("f2d8a2"),
	"milk":Color("dcecf0"), "cream":Color("fff0cc"), "butter":Color("f0cc5e"), "cheese":Color("f3b95e"),
	"pork":Color("d88378"), "wool":Color("efe7d5"), "wool_yarn":Color("d9c4ad"),
	"cotton_thread":Color("f5f2e9"), "cotton_cloth":Color("d6e4df"), "wool_cloth":Color("d5b993"),
	"chicken_feed":Color("dfb24b"), "cow_feed":Color("79a95e"), "pig_feed":Color("d98477"), "sheep_feed":Color("b99bdb"),
	"bread":Color("dc9f4c"), "corn_bread":Color("e8bc48"), "carrot_pie":Color("de7e45"),
	"egg_cake":Color("f1c86c"), "milk_cake":Color("f3dfbb"), "pancake":Color("d99c57"), "meat_pie":Color("a85e49")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crop_texture = _get_crop_texture()
	_visual_texture = _get_visual_texture()
	resized.connect(queue_redraw)

func _draw() -> void:
	if _crop_texture != null:
		var texture_size := Vector2(_crop_texture.get_size())
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var fit_size := texture_size * minf(size.x / texture_size.x, size.y / texture_size.y)
			draw_texture_rect(_crop_texture, Rect2((size - fit_size) * 0.5, fit_size), false)
			return
	if _visual_texture != null:
		var visual_size := Vector2(_visual_texture.get_size())
		if visual_size.x > 0.0 and visual_size.y > 0.0:
			var fit_size := visual_size * minf(size.x * 0.9 / visual_size.x, size.y * 0.9 / visual_size.y)
			draw_texture_rect(_visual_texture, Rect2((size - fit_size) * 0.5, fit_size), false)
			return
	var side: float = minf(size.x,size.y)
	draw_set_transform((size-Vector2.ONE*side)/2,0,Vector2.ONE*side/64)
	var id: String = item_id.trim_suffix("_seed")
	var color: Color = COLORS.get(id,Color("bd9567"))
	if item_id.ends_with("_seed"):
		# Seeds share a recognizable paper packet silhouette, but each packet has
		# its own crop mark so the Storage grid can be read at a glance.
		_poly([Vector2(18,18),Vector2(46,18),Vector2(51,53),Vector2(13,53)],Color("c89a63"))
		draw_rect(Rect2(19,12,26,8),Color("8c633f"))
		draw_style_box(_rounded(Color("f7e8c6")),Rect2(20,25,24,20))
		match id:
			"wheat":
				draw_line(Vector2(32,42),Vector2(32,29),GREEN,2,true)
				for y in [31,35,39]:
					draw_circle(Vector2(28,y),2.5,color)
					draw_circle(Vector2(36,y - 2),2.5,color)
			"corn":
				draw_style_box(_rounded(color),Rect2(27,28,10,14))
				for y in [31,35,39]:
					draw_line(Vector2(29,y),Vector2(35,y),Color("b88d31"),1,true)
			"carrot":
				_poly([Vector2(31,31),Vector2(38,33),Vector2(32,42)],color)
				draw_line(Vector2(33,32),Vector2(28,27),GREEN,2,true)
				draw_line(Vector2(34,32),Vector2(39,27),GREEN,2,true)
			"soybean":
				for point in [Vector2(27,34),Vector2(34,31),Vector2(38,38)]:
					draw_circle(point,3,color)
			"sugarcane":
				for x in [27,32,37]:
					draw_line(Vector2(x,42),Vector2(x - 1,28),color,3,true)
			"cotton":
				for point in [Vector2(27,36),Vector2(34,32),Vector2(38,38)]:
					draw_circle(point,4,Color("fffaf0"))
			"flax":
				draw_line(Vector2(32,42),Vector2(32,29),GREEN,2,true)
				for point in [Vector2(27,34),Vector2(37,31),Vector2(34,38)]:
					draw_circle(point,3,color)
			_:
				draw_circle(Vector2(32,36),6,color)
				for offset in [Vector2(-8,-5),Vector2(8,-5),Vector2(-8,5),Vector2(8,5)]:
					draw_line(Vector2(32,36),Vector2(32,36) + offset,Color("fff5ce"),1.5,true)
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
	elif id in ["golden_wheat", "golden_corn", "giant_carrot"]:
		var crop_color: Color = COLORS[id]
		if id == "giant_carrot":
			_poly([Vector2(12,20),Vector2(52,27),Vector2(22,61)],crop_color)
			for dx in [-13,0,13]:
				draw_line(Vector2(31,24),Vector2(31+dx,5),GREEN,6,true)
		else:
			draw_line(Vector2(31,56),Vector2(34,12),GREEN,4,true)
			for p in [Vector2(22,23),Vector2(40,18),Vector2(28,36),Vector2(42,32)]:
				draw_circle(p,6,crop_color)
		draw_circle(Vector2(50,13),3,Color("fff2c4"))
		draw_line(Vector2(47,13),Vector2(53,13),Color("fff2c4"),1.5,true)
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
		# All fish use the same readable silhouette, with markings that make
		# river, golden and moon catches immediately distinguishable.
		_poly([Vector2(42,30),Vector2(57,17),Vector2(57,47),Vector2(42,37)],color)
		draw_style_box(_rounded(color),Rect2(7,20,39,26))
		draw_circle(Vector2(17,29),3,INK)
		draw_line(Vector2(29,21),Vector2(34,17),color.lightened(0.22),3,true)
		if id == "golden_fish":
			for point in [Vector2(27,28),Vector2(35,34),Vector2(42,27)]:
				draw_circle(point,2,Color("fff2b0"))
		elif id == "river_fish":
			for y in [25,31,37]:
				draw_line(Vector2(27,y),Vector2(41,y + 2),Color("d3eced"),1.5,true)
		elif id == "moon_fish":
			draw_arc(Vector2(33,32),9,PI * 0.45,PI * 1.55,10,Color("e8e1ff"),3,true)
			draw_circle(Vector2(45,18),2,Color("fff6bd"))
		else:
			draw_line(Vector2(27,28),Vector2(40,34),Color("c5e7e9"),2,true)
	elif id == "egg":
		_poly([Vector2(32,11),Vector2(43,25),Vector2(41,45),Vector2(32,54),Vector2(23,45),Vector2(21,25)],Color("f1d6a0"))
		draw_circle(Vector2(28,23),4,Color("fff6d5"))
	elif id == "milk":
		draw_style_box(_rounded(Color("f5f0d8")),Rect2(19,22,27,33))
		draw_rect(Rect2(24,12,17,12),Color("f5f0d8"))
		draw_rect(Rect2(23,10,19,6),Color("8caaba"))
		draw_rect(Rect2(22,32,21,12),Color("9eb5be"))
		draw_line(Vector2(26,38),Vector2(39,38),Color("effaf5"),2,true)
	elif id == "cream":
		draw_style_box(_rounded(Color("f7e6b9")),Rect2(17,25,30,28))
		draw_rect(Rect2(21,17,22,10),Color("f9efd5"))
		draw_arc(Vector2(32,33),10,PI,TAU,12,Color("fff9e8"),5,true)
		draw_circle(Vector2(32,29),3,Color("fffdf3"))
	elif id == "butter":
		draw_style_box(_rounded(Color("efc85b")),Rect2(10,24,44,25))
		draw_rect(Rect2(14,19,36,8),Color("fff4cb"))
		draw_line(Vector2(17,39),Vector2(47,39),Color("d5a644"),2,true)
	elif id == "cheese":
		_poly([Vector2(13,47),Vector2(46,47),Vector2(53,30),Vector2(29,20)],Color("f2bb5e"))
		for point in [Vector2(31,38),Vector2(42,41),Vector2(38,31)]:
			draw_circle(point,3,Color("d89643"))
	elif id == "pork":
		_poly([Vector2(12,34),Vector2(27,19),Vector2(49,26),Vector2(52,43),Vector2(37,52),Vector2(18,48)],Color("d98579"))
		draw_arc(Vector2(34,35),8,0,TAU,12,Color("f3b3a5"),3,true)
		draw_circle(Vector2(40,28),2,INK)
	elif id == "wool":
		for point in [Vector2(24,33),Vector2(32,24),Vector2(41,31),Vector2(35,41),Vector2(25,42)]:
			draw_circle(point,10,Color("f3ead8"))
		draw_circle(Vector2(28,29),2,Color("fffaf1"))
	elif id in ["wool_yarn", "cotton_thread"]:
		var thread_color: Color = COLORS[id]
		draw_style_box(_rounded(Color("a87954")),Rect2(14,19,36,30))
		for y in [24,29,34,39,44]:
			draw_line(Vector2(18,y),Vector2(46,y),thread_color,3,true)
		draw_circle(Vector2(31,34),5,Color("b98a63"))
	elif id in ["cotton_cloth", "wool_cloth"]:
		var cloth_color: Color = COLORS[id]
		draw_style_box(_rounded(cloth_color),Rect2(12,16,40,39))
		for x in [19,28,37,46]:
			draw_line(Vector2(x,20),Vector2(x,51),cloth_color.darkened(0.18),1.5,true)
		for y in [25,34,43]:
			draw_line(Vector2(16,y),Vector2(48,y),Color("fff6e5",0.65),1.2,true)
	elif id in ["bread", "corn_bread", "carrot_pie", "egg_cake", "milk_cake", "pancake", "meat_pie"]:
		_draw_food_icon(id)
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
	elif id in ["old_bottle", "old_boot", "coin_pouch", "small_chest", "lost_lure", "ancient_coin", "map_fragment", "ancient_gem"]:
		if id == "old_bottle":
			draw_style_box(_rounded(Color("71a49c")), Rect2(24, 20, 17, 35))
			draw_rect(Rect2(28, 13, 9, 9), Color("9b7146"))
			draw_rect(Rect2(27, 32, 11, 4), Color("d7ead0"))
		elif id == "old_boot":
			_poly([Vector2(22,13),Vector2(37,13),Vector2(37,38),Vector2(51,43),Vector2(51,51),Vector2(17,51),Vector2(14,43),Vector2(22,38)],Color("79624e"))
		elif id == "coin_pouch":
			draw_circle(Vector2(32,38),18,Color("c28c49"))
			draw_arc(Vector2(32,22),10,0,PI,12,INK,3,true)
			draw_circle(Vector2(32,40),6,Color("e6c45b"))
		elif id == "small_chest":
			draw_style_box(_rounded(Color("a46b3c")),Rect2(10,22,44,31))
			draw_rect(Rect2(10,29,44,4),Color("e0b76b"))
			draw_rect(Rect2(29,31,7,11),Color("efcf75"))
		elif id == "lost_lure":
			draw_circle(Vector2(31,29),9,Color("d56e54"))
			draw_line(Vector2(31,38),Vector2(36,47),INK,2,true)
			draw_arc(Vector2(37,48),5,0,PI,12,INK,2,true)
		elif id == "ancient_coin":
			draw_circle(Vector2(32,32),22,Color("d5ad49"))
			draw_circle(Vector2(32,32),15,Color("f0d47b"))
			draw_arc(Vector2(32,32),10,0,TAU,20,Color("a98238"),2,true)
		elif id == "ancient_gem":
			_poly([Vector2(32,8),Vector2(51,25),Vector2(42,53),Vector2(22,53),Vector2(13,25)],Color("3aa99e"))
			_poly([Vector2(32,8),Vector2(42,25),Vector2(32,48),Vector2(22,25)],Color("8cf5de"))
			draw_line(Vector2(24,19),Vector2(33,12),Color("effff5"),3,true)
		else:
			_poly([Vector2(13,12),Vector2(43,12),Vector2(52,22),Vector2(52,52),Vector2(13,52)],Color("e1d0a7"))
			draw_line(Vector2(21,25),Vector2(43,25),Color("897454"),2,true)
			draw_line(Vector2(21,33),Vector2(39,33),Color("897454"),2,true)
	elif id == "loom":
		# A small woven-frame mark keeps the Loom card recognizable before a
		# dedicated production-building illustration is added.
		draw_rect(Rect2(15,12,7,44),Color("9b7047"),true)
		draw_rect(Rect2(42,12,7,44),Color("9b7047"),true)
		draw_rect(Rect2(18,15,28,5),Color("c49a62"),true)
		draw_rect(Rect2(18,47,28,5),Color("c49a62"),true)
		for x in range(22,45,5):
			draw_line(Vector2(x,21),Vector2(x-2,46),Color("efe0bd"),2,true)
	elif id in ["chicken_feed", "cow_feed", "pig_feed", "sheep_feed"]:
		# Feed bags have a unique animal badge instead of the same blank sack.
		var feed_color: Color = COLORS[id]
		draw_style_box(_rounded(Color("b98758")),Rect2(15,17,34,39))
		draw_rect(Rect2(18,14,28,7),Color("805638"))
		draw_style_box(_rounded(Color("f5e5bc")),Rect2(21,28,22,18))
		if id == "chicken_feed":
			draw_circle(Vector2(29,36),5,feed_color)
			draw_circle(Vector2(36,34),5,feed_color)
			draw_line(Vector2(39,37),Vector2(45,39),Color("d77b3f"),2,true)
		elif id == "cow_feed":
			draw_arc(Vector2(32,38),8,PI,TAU,12,feed_color,5,true)
			draw_circle(Vector2(27,34),2,INK)
			draw_circle(Vector2(37,34),2,INK)
		elif id == "pig_feed":
			draw_circle(Vector2(32,37),8,feed_color)
			draw_circle(Vector2(29,37),1.5,INK)
			draw_circle(Vector2(35,37),1.5,INK)
		else:
			for point in [Vector2(27,36),Vector2(34,33),Vector2(38,39)]:
				draw_circle(point,5,feed_color)
	else:
		draw_style_box(_rounded(color),Rect2(12,15,40,38))
		draw_line(Vector2(16,25),Vector2(48,25),INK,3,true)
		draw_line(Vector2(32,18),Vector2(32,49),Color("f2d5a1"),5,true)


func _draw_food_icon(food_id: String) -> void:
	match food_id:
		"bread":
			draw_style_box(_rounded(Color("d99a4f")),Rect2(10,25,44,24))
			for x in [21,32,43]:
				draw_line(Vector2(x,29),Vector2(x - 4,40),Color("fff0c4"),2.5,true)
		"corn_bread":
			draw_style_box(_rounded(Color("e7bd4d")),Rect2(10,24,44,25))
			for point in [Vector2(21,32),Vector2(31,30),Vector2(40,34),Vector2(27,41),Vector2(39,42)]:
				draw_circle(point,2.3,Color("b9842f"))
		"carrot_pie":
			_poly([Vector2(10,48),Vector2(53,48),Vector2(35,17)],Color("db813f"))
			draw_line(Vector2(14,47),Vector2(51,47),Color("f4d277"),3,true)
			for point in [Vector2(34,34),Vector2(39,41),Vector2(27,42)]:
				draw_circle(point,2.5,Color("80a64f"))
		"egg_cake":
			draw_style_box(_rounded(Color("edc76f")),Rect2(12,25,40,25))
			draw_arc(Vector2(32,29),16,PI,TAU,16,Color("fff5cf"),6,true)
			draw_circle(Vector2(32,33),4,Color("f6b347"))
		"milk_cake":
			draw_style_box(_rounded(Color("e7c690")),Rect2(13,25,38,25))
			draw_style_box(_rounded(Color("fff5dc")),Rect2(13,18,38,15))
			for x in [22,32,42]:
				draw_circle(Vector2(x,25),2,Color("eccf91"))
		"pancake":
			for y in [43,36,29]:
				_draw_ellipse(Vector2(32,y),Vector2(20,6),Color("dfa25a"))
			draw_circle(Vector2(32,27),5,Color("f4d371"))
			draw_line(Vector2(32,21),Vector2(32,15),Color("b77736"),2,true)
		"meat_pie":
			draw_arc(Vector2(32,42),19,PI,TAU,18,Color("ae6047"),10,true)
			draw_line(Vector2(13,42),Vector2(51,42),Color("f0c16d"),3,true)
			for x in [20,29,38,47]:
				draw_line(Vector2(x,38),Vector2(x - 4,32),Color("7c4837"),2,true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	# A simple polygon keeps procedural icons crisp at every UI scale.
	var points: Array[Vector2] = []
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	_poly(points, color)

func _get_crop_texture() -> Texture2D:
	var path: String = CROP_TEXTURE_PATHS.get(item_id, "")
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		var cached: Variant = _texture_cache[path]
		return cached if cached is Texture2D else null
	var loaded: Resource = load(path) if ResourceLoader.exists(path) else null
	_texture_cache[path] = loaded
	return loaded if loaded is Texture2D else null

func _get_visual_texture() -> Texture2D:
	var path: String = VISUAL_TEXTURE_PATHS.get(item_id, "")
	if path.is_empty():
		return null
	if _visual_texture_cache.has(path):
		var cached: Variant = _visual_texture_cache[path]
		return cached if cached is Texture2D else null
	var loaded: Resource = load(path) if ResourceLoader.exists(path) else null
	_visual_texture_cache[path] = loaded
	return loaded if loaded is Texture2D else null

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
