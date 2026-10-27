extends Node2D

# Static environment artwork is batched on this single node. It has no collision,
# interaction, resource state, timers, or per-frame processing.
const TREE_TEXTURE: Texture2D = preload("res://assets/environment/tree/Tree.png")
const TREE_REGION := Rect2(0, 2, 1248, 1230)
const PATH_EDGE := Color("8f805b")
const PATH_DIRT := Color("b9a77d")
const PATH_LIGHT := Color("c8b88c", 0.52)
const FENCE_DARK := Color("65452f")
const FENCE_WOOD := Color("a47b4e")


func _draw() -> void:
	_draw_grass_patches()
	_draw_paths()
	_draw_field_edge()
	_draw_fences()
	_draw_farmyard_props()
	_draw_edge_nature()
	_draw_small_ground_details()
	_draw_final_decoration_pass()


func _draw_grass_patches() -> void:
	# Very soft color variation stays outside the core planting and building areas.
	for patch in [
		[Vector2(280, 365), Vector2(170, 58), Color("8caf62", 0.19)],
		[Vector2(1040, 336), Vector2(190, 55), Color("a5ad69", 0.12)],
		[Vector2(1510, 360), Vector2(152, 74), Color("8caf62", 0.16)],
		[Vector2(290, 735), Vector2(155, 75), Color("a5ad69", 0.13)],
		[Vector2(1020, 775), Vector2(150, 38), Color("b69a69", 0.2)],
		[Vector2(1672, 570), Vector2(76, 150), Color("a5ad69", 0.15)],
		[Vector2(320, 1510), Vector2(205, 64), Color("8caf62", 0.17)],
		[Vector2(710, 1510), Vector2(175, 58), Color("a5ad69", 0.12)],
		[Vector2(1590, 1518), Vector2(200, 66), Color("8caf62", 0.17)],
		[Vector2(80, 340), Vector2(100, 230), Color("99a864", 0.15)],
		[Vector2(85, 850), Vector2(100, 250), Color("99a864", 0.15)],
		[Vector2(95, 1600), Vector2(105, 200), Color("99a864", 0.15)],
		[Vector2(380, 2290), Vector2(290, 120), Color("8caf62", 0.17)],
		[Vector2(975, 2280), Vector2(250, 118), Color("a5ad69", 0.13)],
		[Vector2(1650, 2280), Vector2(270, 118), Color("8caf62", 0.16)],
		[Vector2(2280, 2200), Vector2(165, 260), Color("99a864", 0.11)]
	]:
		_draw_ellipse(patch[0], patch[1], patch[2])

	# Small shaded lawn islands add depth without becoming a noisy texture.
	for patch in [
		[Vector2(355, 385), Vector2(82, 24)],
		[Vector2(1035, 330), Vector2(96, 21)],
		[Vector2(1530, 375), Vector2(88, 26)],
		[Vector2(315, 1518), Vector2(115, 24)],
		[Vector2(1590, 1510), Vector2(128, 26)],
		[Vector2(1010, 2285), Vector2(130, 26)]
	]:
		_draw_ellipse(patch[0], patch[1], Color("6f914d", 0.12))

	# Gentle, irregular lawn color breaks up the large open southern plots.
	for patch in [
		[Vector2(540, 1840), Vector2(145, 42), Color("a5ad69", 0.10)],
		[Vector2(1080, 1935), Vector2(180, 48), Color("8caf62", 0.11)],
		[Vector2(1545, 2055), Vector2(145, 43), Color("a5ad69", 0.10)],
		[Vector2(970, 2260), Vector2(190, 52), Color("8caf62", 0.10)],
		[Vector2(380, 2220), Vector2(130, 40), Color("a5ad69", 0.09)],
		[Vector2(1780, 2210), Vector2(145, 44), Color("8caf62", 0.10)],
		[Vector2(360, 970), Vector2(120, 34), Color("a5ad69", 0.09)],
		[Vector2(1630, 920), Vector2(94, 35), Color("8caf62", 0.10)]
	]:
		_draw_ellipse(patch[0], patch[1], patch[2])


func _draw_paths() -> void:
	# Main paths connect the house, storage, fields, animal yard, bridge, decks and market.
	_path(PackedVector2Array([Vector2(700, 480), Vector2(700, 535), Vector2(710, 690), Vector2(700, 840), Vector2(700, 1140)]), 42.0)
	_path(PackedVector2Array([Vector2(700, 520), Vector2(820, 520), Vector2(838, 475), Vector2(838, 365), Vector2(920, 335)]), 30.0)
	_path(PackedVector2Array([Vector2(838, 480), Vector2(920, 480)]), 26.0)
	_path(PackedVector2Array([Vector2(700, 650), Vector2(790, 650), Vector2(920, 650)]), 30.0)
	_path(PackedVector2Array([Vector2(700, 730), Vector2(635, 748), Vector2(550, 750)]), 25.0)
	_path(PackedVector2Array([Vector2(700, 1140), Vector2(880, 1140), Vector2(1165, 1140), Vector2(1450, 1140), Vector2(1570, 1140), Vector2(1750, 1140)]), 36.0)
	_path(PackedVector2Array([Vector2(1750, 1140), Vector2(1750, 850)]), 30.0)
	_path(PackedVector2Array([Vector2(700, 960), Vector2(650, 960)]), 24.0)
	_path(PackedVector2Array([Vector2(700, 1140), Vector2(560, 1140)]), 30.0)
	# Short branches enter the two pens through their open south gates.
	_path(PackedVector2Array([Vector2(897, 1140), Vector2(897, 1090)]), 22.0)
	_path(PackedVector2Array([Vector2(1453, 1140), Vector2(1453, 1095)]), 22.0)
	_path(PackedVector2Array([Vector2(1165, 1140), Vector2(1165, 1018)]), 22.0)
	for x in [1250.0, 1450.0]:
		_path(PackedVector2Array([Vector2(x, 1140), Vector2(x, 1250)]), 24.0)
	# A north-side spur reaches the field through its west gate, clear of both pens.
	_path(PackedVector2Array([Vector2(820, 520), Vector2(900, 535), Vector2(1000, 585), Vector2(1040, 600)]), 20.0)
	# The east bank route reaches both decks and the fish market.
	_path(PackedVector2Array([Vector2(1975, 850), Vector2(2010, 885), Vector2(2040, 930), Vector2(2040, 1800)]), 28.0)
	_path(PackedVector2Array([Vector2(2040, 930), Vector2(2040, 600), Vector2(2110, 550), Vector2(2160, 500), Vector2(2240, 410)]), 28.0)
	_path(PackedVector2Array([Vector2(2040, 1020), Vector2(1980, 1020)]), 22.0)

	# A few stones sit within the broad trail, leaving the walking lanes open.
	for point in [Vector2(752, 831), Vector2(778, 834), Vector2(804, 837), Vector2(2011, 898), Vector2(2062, 580), Vector2(2140, 519)]:
		_draw_stepping_stone(point, 0.72)


func _draw_field_edge() -> void:
	# Accents frame the field without covering any of the 32 plot footprints.
	var field := Rect2(1050, 460, 620, 302)
	draw_rect(field, Color("775532", 0.48), false, 5.0)
	draw_rect(field.grow(-6), Color("d5b47d", 0.24), false, 2.0)
	# Small soil/grass shoulders sit beyond the plot rows and away from the center paths.
	for point in [Vector2(1073, 482), Vector2(1647, 483), Vector2(1074, 735), Vector2(1645, 736)]:
		_draw_ellipse(point, Vector2(24, 8), Color("a67a4e", 0.3))
	# Open fence fragments give the field an edge while preserving approach from the south.
	_fence_segment(Vector2(1090, 474), Vector2(1210, 474), 4)
	_fence_segment(Vector2(1510, 474), Vector2(1630, 474), 4)
	_fence_segment(Vector2(1058, 520), Vector2(1058, 560), 3)
	_fence_segment(Vector2(1058, 640), Vector2(1058, 665), 2)
	_fence_segment(Vector2(1662, 520), Vector2(1662, 665), 4)
	_fence_segment(Vector2(1090, 747), Vector2(1210, 747), 4)
	_fence_segment(Vector2(1510, 747), Vector2(1630, 747), 4)


func _draw_fences() -> void:
	# Short rustic rails decorate the house yard and map corners without enclosing them.
	_fence_segment(Vector2(465, 790), Vector2(525, 790), 4)
	_fence_segment(Vector2(560, 815), Vector2(630, 815), 4)
	_fence_segment(Vector2(1470, 1570), Vector2(1595, 1570), 5)
	_fence_segment(Vector2(120, 1770), Vector2(270, 1770), 5)


func _draw_farmyard_props() -> void:
	# Moveable building props live in each building's GroundTreatment child.
	_lamp_post(Vector2(980, 748), 0.85)
	_lamp_post(Vector2(1715, 820), 0.9)
	_wood_sign(Vector2(1010, 435), 0.75)


func _draw_edge_nature() -> void:
	# Decorative trees frame the farm with the same artwork used by harvestable trees.
	# These are background-only; resource nodes remain the only trees with collision.
	for entry in [
		[Vector2(30, 330), 0.85], [Vector2(45, 735), 0.72], [Vector2(36, 1035), 0.82],
		[Vector2(48, 1585), 0.76], [Vector2(330, 2355), 0.9], [Vector2(740, 2360), 0.72],
		[Vector2(1180, 2360), 0.82], [Vector2(1650, 2355), 0.76], [Vector2(1930, 2250), 0.72],
		[Vector2(2370, 2150), 0.8], [Vector2(2365, 1820), 0.68], [Vector2(1720, 340), 0.6],
		[Vector2(95, 1900), 0.68], [Vector2(95, 2200), 0.82], [Vector2(2250, 2320), 0.86],
		[Vector2(2150, 2050), 0.68], [Vector2(2250, 1650), 0.74], [Vector2(1870, 2360), 0.72]
	]:
		_tree(entry[0], entry[1])
	for entry in [
		[Vector2(120, 610), 0.74], [Vector2(115, 1285), 0.68], [Vector2(245, 2290), 0.8],
		[Vector2(620, 2310), 0.65], [Vector2(1430, 2315), 0.72], [Vector2(2295, 2250), 0.66]
	]:
		_bush_cluster(entry[0], entry[1])
	for entry in [
		[Vector2(1770, 360), 0.68], [Vector2(1762, 635), 0.72], [Vector2(1760, 1190), 0.7],
		[Vector2(1768, 1510), 0.72], [Vector2(1965, 520), 0.62], [Vector2(1970, 1330), 0.62],
		[Vector2(1980, 1760), 0.6], [Vector2(2065, 745), 0.58], [Vector2(2055, 1685), 0.62]
	]:
		_reeds(entry[0], entry[1])
	for entry in [
		[Vector2(1758, 480), 0.7], [Vector2(1760, 1010), 0.82], [Vector2(1760, 1430), 0.68],
		[Vector2(1965, 645), 0.72], [Vector2(1965, 1575), 0.68], [Vector2(2072, 1885), 0.62]
	]:
		_stone_cluster(entry[0], entry[1])
	for entry in [
		[Vector2(270, 1810), 0.72], [Vector2(410, 1930), 0.62], [Vector2(730, 1850), 0.68],
		[Vector2(1010, 2010), 0.72], [Vector2(1260, 1880), 0.62], [Vector2(1490, 2180), 0.74],
		[Vector2(1800, 2030), 0.68], [Vector2(2080, 2180), 0.72], [Vector2(2250, 1930), 0.62],
		[Vector2(300, 2180), 0.66], [Vector2(845, 2310), 0.62], [Vector2(1580, 1880), 0.68]
	]:
		_stone_cluster(entry[0], entry[1])


func _draw_small_ground_details() -> void:
	for entry in [
		[Vector2(365, 500), 0.62], [Vector2(590, 835), 0.62], [Vector2(990, 300), 0.68],
		[Vector2(1682, 690), 0.58], [Vector2(370, 1560), 0.7],
		[Vector2(1660, 1510), 0.68], [Vector2(540, 2250), 0.65], [Vector2(1850, 2140), 0.62],
		[Vector2(250, 1780), 0.62], [Vector2(440, 1875), 0.58], [Vector2(675, 1980), 0.68],
		[Vector2(880, 1815), 0.6], [Vector2(1135, 2075), 0.65], [Vector2(1380, 1935), 0.58],
		[Vector2(1610, 2110), 0.65], [Vector2(1860, 1965), 0.58], [Vector2(2110, 2290), 0.68],
		[Vector2(150, 2080), 0.6], [Vector2(560, 2140), 0.58], [Vector2(920, 2320), 0.62],
		[Vector2(1230, 2200), 0.58], [Vector2(1730, 2280), 0.62], [Vector2(2300, 1800), 0.58]
	]:
		_tuft(entry[0], entry[1])
	for entry in [
		[Vector2(350, 760), 0.55], [Vector2(1658, 780), 0.55],
		[Vector2(1010, 365), 0.5], [Vector2(1610, 360), 0.54], [Vector2(1660, 1480), 0.55],
		[Vector2(780, 2220), 0.6], [Vector2(1280, 2290), 0.58],
		[Vector2(320, 1880), 0.48], [Vector2(760, 2115), 0.5], [Vector2(1060, 1840), 0.48],
		[Vector2(1450, 2020), 0.5], [Vector2(1890, 2300), 0.48]
	]:
		_flower_cluster(entry[0], entry[1], Color("f0dfb5"))


func _draw_final_decoration_pass() -> void:
	# A few intentional clusters make the farm feel lived-in while keeping
	# paths, entrances, crop footprints, and fishing cast areas open.
	_draw_field_and_path_details()
	_draw_production_yard_details()
	_draw_market_and_waterfront_details()
	_draw_south_farm_details()


func _draw_field_and_path_details() -> void:
	# Tools and a small flower cluster are parked beside the field, not on its
	# plots or the west entrance path.
	_wheelbarrow(Vector2(984, 804), 0.82)
	_flower_cluster(Vector2(1017, 775), 0.7, Color("e6c980"))
	_stone_cluster(Vector2(1675, 792), 0.72)
	_fence_segment(Vector2(480, 875), Vector2(550, 875), 3)
	_lamp_post(Vector2(620, 872), 0.76)
	_draw_sign_mark(Vector2(1010, 435), Color("93ad5b"))


func _draw_production_yard_details() -> void:
	# Building supplies are attached to their movable owners in scene files.
	# Keep only detached yard seating and lighting here.
	_bench(Vector2(1650, 1375), 0.78)
	_flower_cluster(Vector2(1602, 1408), 0.65, Color("f3e1b1"))
	_lamp_post(Vector2(815, 1215), 0.72)


func _draw_market_and_waterfront_details() -> void:
	# Fish-market stock is tucked to the east of the stall. Nothing is placed
	# on the river rest deck, pond deck, or the usual casting lanes.
	_barrel(Vector2(2360, 330), 0.72)
	_crate(Vector2(2370, 390), 0.72)
	_wood_sign(Vector2(2168, 382), 0.66)
	_draw_sign_mark(Vector2(2168, 382), Color("78aeb0"))
	_lamp_post(Vector2(2370, 455), 0.68)
	_bucket(Vector2(1974, 1785), 0.68)
	_flower_cluster(Vector2(1985, 1848), 0.58, Color("e9c97a"))
	_bench(Vector2(1985, 1902), 0.78)
	_reeds(Vector2(1958, 1872), 0.72)


func _draw_south_farm_details() -> void:
	# Small, spaced clusters add interest to future expansion land without
	# filling its buildable center.
	_sack_cluster(Vector2(455, 1685), 0.78)
	_barrel(Vector2(492, 1710), 0.68)
	_decorative_rock_cluster(Vector2(1765, 1695), 0.9)
	_decorative_rock_cluster(Vector2(330, 2110), 0.75)
	_bush_cluster(Vector2(780, 2030), 0.82)
	_flower_cluster(Vector2(814, 2050), 0.68, Color("e7bca0"))
	_wheelbarrow(Vector2(1040, 2180), 0.82)
	_lamp_post(Vector2(1550, 1900), 0.82)
	_wood_sign(Vector2(1505, 1858), 0.7)
	_draw_sign_mark(Vector2(1505, 1858), Color("c29a61"))
	_fence_segment(Vector2(1300, 2240), Vector2(1425, 2240), 4)
	_flower_cluster(Vector2(1465, 2265), 0.76, Color("f0dfb5"))


func _draw_sign_mark(point: Vector2, mark_color: Color) -> void:
	# Tiny pictograms keep signs readable as decoration without large world text.
	draw_circle(point + Vector2(0, -18), 4.2, mark_color)
	draw_line(point + Vector2(-5, -18), point + Vector2(5, -18), Color("f2dfb9"), 1.2, true)


func _mailbox(point: Vector2, scale: float) -> void:
	draw_line(point + Vector2(0, 17) * scale, point + Vector2(0, -2) * scale, Color("60452f"), 4.0 * scale, true)
	draw_rect(Rect2(point + Vector2(-12, -15) * scale, Vector2(24, 15) * scale), Color("73905a"), true)
	draw_rect(Rect2(point + Vector2(-12, -15) * scale, Vector2(24, 15) * scale), Color("506b3e"), false, 1.8 * scale)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-14, -15) * scale,
		point + Vector2(0, -24) * scale,
		point + Vector2(14, -15) * scale
	]), Color("9a6845"))
	draw_rect(Rect2(point + Vector2(5, -13) * scale, Vector2(3, 6) * scale), Color("e8b34f"), true)


func _sack_cluster(point: Vector2, scale: float) -> void:
	_sack(point, scale)
	_sack(point + Vector2(19, 7) * scale, scale * 0.76)


func _sack(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 12) * scale, Vector2(13, 4) * scale, Color("493a2b", 0.2))
	var body := PackedVector2Array([
		point + Vector2(-10, -13) * scale,
		point + Vector2(-7, -19) * scale,
		point + Vector2(7, -19) * scale,
		point + Vector2(11, -12) * scale,
		point + Vector2(9, 10) * scale,
		point + Vector2(-8, 10) * scale
	])
	draw_colored_polygon(body, Color("c7ad78"))
	draw_polyline(PackedVector2Array([
		body[0], body[1], body[2], body[3], body[4], body[5], body[0]
	]), Color("856744"), 1.6 * scale, true)
	draw_line(point + Vector2(-6, -15) * scale, point + Vector2(6, -15) * scale, Color("e6d3a5"), 2.0 * scale, true)


func _wheelbarrow(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 12) * scale, Vector2(26, 6) * scale, Color("463a2c", 0.22))
	draw_line(point + Vector2(10, 1) * scale, point + Vector2(30, 13) * scale, Color("68482f"), 3.0 * scale, true)
	draw_line(point + Vector2(-9, 5) * scale, point + Vector2(-27, 14) * scale, Color("68482f"), 3.0 * scale, true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-20, -6) * scale,
		point + Vector2(13, -6) * scale,
		point + Vector2(7, 8) * scale,
		point + Vector2(-14, 8) * scale
	]), Color("a87949"))
	draw_polyline(PackedVector2Array([
		point + Vector2(-20, -6) * scale,
		point + Vector2(13, -6) * scale,
		point + Vector2(7, 8) * scale,
		point + Vector2(-14, 8) * scale,
		point + Vector2(-20, -6) * scale
	]), Color("60432f"), 2.0 * scale, true)
	draw_circle(point + Vector2(20, 11) * scale, 6.0 * scale, Color("60432f"))
	draw_circle(point + Vector2(20, 11) * scale, 3.0 * scale, Color("b59a6c"))
	for offset in [Vector2(-8, -8), Vector2(0, -12), Vector2(7, -8)]:
		draw_line(point + offset * scale, point + (offset + Vector2(-2, -8)) * scale, Color("7b9650"), 2.0 * scale, true)


func _milk_can(point: Vector2, scale: float) -> void:
	draw_rect(Rect2(point + Vector2(-8, -12) * scale, Vector2(16, 23) * scale), Color("a99b7a"), true)
	draw_rect(Rect2(point + Vector2(-8, -12) * scale, Vector2(16, 23) * scale), Color("66533e"), false, 1.8 * scale)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-5, -12) * scale,
		point + Vector2(-3, -19) * scale,
		point + Vector2(3, -19) * scale,
		point + Vector2(5, -12) * scale
	]), Color("b8aa88"))
	draw_arc(point + Vector2(0, -17) * scale, 8.0 * scale, PI, TAU, 12, Color("6a5540"), 1.7 * scale, true)
	draw_line(point + Vector2(-7, -3) * scale, point + Vector2(7, -3) * scale, Color("e5d6b2"), 2.0 * scale, true)


func _bucket(point: Vector2, scale: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-9, -10) * scale,
		point + Vector2(9, -10) * scale,
		point + Vector2(7, 9) * scale,
		point + Vector2(-7, 9) * scale
	]), Color("a77a4e"))
	draw_polyline(PackedVector2Array([
		point + Vector2(-9, -10) * scale,
		point + Vector2(9, -10) * scale,
		point + Vector2(7, 9) * scale,
		point + Vector2(-7, 9) * scale,
		point + Vector2(-9, -10) * scale
	]), Color("5e432e"), 1.8 * scale, true)
	draw_arc(point + Vector2(0, -8) * scale, 10.0 * scale, PI, TAU, 12, Color("775636"), 1.6 * scale, true)
	draw_line(point + Vector2(-7, 0) * scale, point + Vector2(7, 0) * scale, Color("d0a774"), 1.4 * scale, true)


func _decorative_rock_cluster(point: Vector2, scale: float) -> void:
	# Flat pebbles have no collision or interaction and are deliberately smaller
	# and duller than the mineable ResourceNode artwork.
	_draw_ellipse(point + Vector2(1, 5) * scale, Vector2(26, 7) * scale, Color("474639", 0.16))
	for entry in [[Vector2(-12, 1), Vector2(11, 7)], [Vector2(0, -1), Vector2(15, 9)], [Vector2(14, 2), Vector2(9, 6)]]:
		var center: Vector2 = point + entry[0] * scale
		var pebble_size: Vector2 = entry[1] * scale
		_draw_ellipse(center + Vector2(1, 2) * scale, pebble_size, Color("686958", 0.78))
		_draw_ellipse(center + Vector2(-1, -1) * scale, pebble_size * 0.8, Color("9a9b84", 0.84))
		draw_line(center + Vector2(-4, -2) * scale, center + Vector2(3, -3) * scale, Color("c7c2a7", 0.6), 1.0 * scale, true)


func _path(points: PackedVector2Array, width: float) -> void:
	var path := _soft_path(points)
	if path.size() < 2:
		return
	draw_polyline(path, Color("6e5c45", 0.22), width + 12.0, true)
	draw_polyline(path, PATH_EDGE, width + 6.0, true)
	draw_polyline(path, PATH_DIRT, width, true)
	draw_polyline(path, PATH_LIGHT, maxf(2.0, width * 0.17), true)
	for index in range(1, path.size() - 1, 7):
		var point := path[index]
		_draw_ellipse(point + Vector2(0, width * 0.12), Vector2(width * 0.28, 2.0), Color("77654b", 0.12))


func _soft_path(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var curve := Curve2D.new()
	curve.bake_interval = 10.0
	for index in range(points.size()):
		var point := points[index]
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		curve.add_point(point, (previous - point) * 0.12, (following - point) * 0.12)
	return curve.get_baked_points()


func _fence_segment(start: Vector2, finish: Vector2, post_count: int) -> void:
	var direction := (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x) * 4.0
	draw_line(start + Vector2(0, 5), finish + Vector2(0, 5), Color("4f3d2d", 0.22), 8.0, true)
	for offset in [-8.0, 1.0]:
		draw_line(start + normal + Vector2(0, offset), finish + normal + Vector2(0, offset), FENCE_DARK, 5.0, true)
		draw_line(start + normal + Vector2(0, offset - 1.0), finish + normal + Vector2(0, offset - 1.0), FENCE_WOOD, 3.0, true)
	for index in range(post_count):
		var ratio := float(index) / float(maxi(1, post_count - 1))
		var post := start.lerp(finish, ratio) + normal
		draw_rect(Rect2(post - Vector2(3, 7), Vector2(7, 17)), FENCE_DARK, true)
		draw_rect(Rect2(post - Vector2(2, 6), Vector2(5, 13)), FENCE_WOOD, true)


func _tree(point: Vector2, scale: float) -> void:
	var size := Vector2(132, 130) * scale
	_draw_ellipse(point + Vector2(3, 2) * scale, Vector2(size.x * 0.34, 7.0) * scale, Color("3e4e34", 0.2))
	var destination := Rect2(point - Vector2(size.x * 0.5, size.y), size)
	draw_texture_rect_region(TREE_TEXTURE, destination, TREE_REGION, Color.WHITE)


func _bush_cluster(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 10) * scale, Vector2(32, 9) * scale, Color("42553a", 0.22))
	for entry in [[Vector2(-15, 1), 13.0], [Vector2(0, -6), 16.0], [Vector2(16, 0), 12.0], [Vector2(4, 5), 14.0]]:
		var center: Vector2 = point + entry[0] * scale
		draw_circle(center + Vector2(1, 2) * scale, float(entry[1]) * scale, Color("46663c"))
		draw_circle(center, float(entry[1]) * scale * 0.84, Color("78984f"))
		draw_circle(center + Vector2(-4, -4) * scale, 3.0 * scale, Color("a6b66b", 0.72))


func _flower_cluster(point: Vector2, scale: float, petal_color: Color) -> void:
	for offset in [Vector2(-10, 3), Vector2(0, -4), Vector2(11, 4)]:
		var center: Vector2 = point + offset * scale
		draw_line(center + Vector2(0, 11) * scale, center, Color("567346"), 2.0 * scale, true)
		draw_line(center, center + Vector2(-5, 5) * scale, Color("6d8a4b"), 1.6 * scale, true)
		draw_circle(center, 4.0 * scale, petal_color)
		draw_circle(center + Vector2(0, 1) * scale, 1.5 * scale, Color("d4a64d"))


func _tuft(point: Vector2, scale: float) -> void:
	var color := Color("829d55", 0.85)
	draw_line(point, point + Vector2(-7, -13) * scale, color, 2.2 * scale, true)
	draw_line(point, point + Vector2(0, -17) * scale, Color("a1ad62", 0.9), 2.4 * scale, true)
	draw_line(point, point + Vector2(7, -11) * scale, color, 2.0 * scale, true)


func _reeds(point: Vector2, scale: float) -> void:
	for index in range(4):
		var x := (float(index) - 1.5) * 5.0 * scale
		var base := point + Vector2(x, 0)
		draw_line(base, base + Vector2(3.0 * scale, -23.0 * scale), Color("657c4b"), 2.0 * scale, true)
		draw_line(base + Vector2(3.0 * scale, -20.0 * scale), base + Vector2(-5.0 * scale, -30.0 * scale), Color("819452"), 1.8 * scale, true)
		draw_circle(base + Vector2(3.0 * scale, -25.0 * scale), 2.0 * scale, Color("987348"))


func _stone_cluster(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(1, 5) * scale, Vector2(24, 8) * scale, Color("453e32", 0.24))
	for entry in [[Vector2(-10, 0), 8.0], [Vector2(1, -3), 10.0], [Vector2(12, 1), 7.0]]:
		var center: Vector2 = point + entry[0] * scale
		draw_circle(center + Vector2(1, 2) * scale, float(entry[1]) * scale, Color("62685b"))
		draw_circle(center, float(entry[1]) * scale * 0.82, Color("a1a38f"))
		draw_line(center + Vector2(-3, -2) * scale, center + Vector2(3, -3) * scale, Color("d1c9a8", 0.72), 1.4 * scale, true)


func _draw_stepping_stone(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 3), Vector2(13, 5) * scale, Color("574b3a", 0.28))
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-11, 0) * scale, point + Vector2(-6, -5) * scale,
		point + Vector2(7, -4) * scale, point + Vector2(12, 0) * scale,
		point + Vector2(5, 5) * scale, point + Vector2(-8, 4) * scale
	]), Color("939581"))
	draw_polyline(PackedVector2Array([point + Vector2(-6, -4) * scale, point + Vector2(6, -3) * scale, point + Vector2(10, 0) * scale]), Color("c3bfa4", 0.8), 1.4, true)


func _barrel(point: Vector2, scale: float) -> void:
	var rect := Rect2(point + Vector2(-8, -13) * scale, Vector2(16, 26) * scale)
	_draw_ellipse(point + Vector2(0, 14) * scale, Vector2(12, 4) * scale, Color("453526", 0.22))
	draw_rect(rect, Color("8b6040"), true)
	draw_rect(rect, Color("60452f"), false, 2.0 * scale)
	for y in [-8.0, 5.0]:
		draw_line(point + Vector2(-8, y) * scale, point + Vector2(8, y) * scale, Color("c09a68"), 2.0 * scale, true)
	draw_line(point + Vector2(-3, -12) * scale, point + Vector2(-3, 12) * scale, Color("b38656", 0.65), 1.5 * scale, true)


func _crate(point: Vector2, scale: float) -> void:
	var rect := Rect2(point + Vector2(-12, -10) * scale, Vector2(24, 20) * scale)
	draw_rect(rect.grow(2 * scale), Color("60442e"), true)
	draw_rect(rect, Color("a5794b"), true)
	draw_rect(rect, Color("5f432e"), false, 2.0 * scale)
	draw_line(point + Vector2(-9, -7) * scale, point + Vector2(9, 7) * scale, Color("d0a774"), 2.0 * scale, true)
	draw_line(point + Vector2(9, -7) * scale, point + Vector2(-9, 7) * scale, Color("d0a774"), 2.0 * scale, true)


func _bench(point: Vector2, scale: float) -> void:
	for offset in [-10.0, 8.0]:
		draw_rect(Rect2(point + Vector2(offset - 2, 2) * scale, Vector2(4, 15) * scale), Color("68482f"), true)
	draw_rect(Rect2(point + Vector2(-22, -5) * scale, Vector2(44, 8) * scale), Color("9a6845"), true)
	draw_rect(Rect2(point + Vector2(-22, -5) * scale, Vector2(44, 8) * scale), Color("60432f"), false, 2.0 * scale)
	draw_rect(Rect2(point + Vector2(-22, -13) * scale, Vector2(44, 7) * scale), Color("ad8456"), true)


func _lamp_post(point: Vector2, scale: float) -> void:
	draw_line(point + Vector2(0, 18) * scale, point + Vector2(0, -26) * scale, Color("5b432d"), 5.0 * scale, true)
	draw_line(point + Vector2(-8, -24) * scale, point + Vector2(8, -24) * scale, Color("795637"), 4.0 * scale, true)
	draw_rect(Rect2(point + Vector2(-7, -38) * scale, Vector2(14, 13) * scale), Color("805a38"), true)
	draw_rect(Rect2(point + Vector2(-5, -36) * scale, Vector2(10, 9) * scale), Color("f2d68e", 0.92), true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-9, -38) * scale, point + Vector2(0, -44) * scale,
		point + Vector2(9, -38) * scale
	]), Color("5b432d"))
	_draw_ellipse(point + Vector2(0, 18) * scale, Vector2(9, 3) * scale, Color("493a2b", 0.24))


func _wood_sign(point: Vector2, scale: float) -> void:
	draw_line(point + Vector2(0, 12) * scale, point + Vector2(0, -14) * scale, Color("65452f"), 5.0 * scale, true)
	draw_rect(Rect2(point + Vector2(-20, -24) * scale, Vector2(40, 18) * scale), Color("9a6845"), true)
	draw_rect(Rect2(point + Vector2(-20, -24) * scale, Vector2(40, 18) * scale), Color("60432f"), false, 2.0 * scale)
	draw_line(point + Vector2(-14, -19) * scale, point + Vector2(14, -19) * scale, Color("d2ad77", 0.75), 2.0 * scale, true)


func _hay_pile(point: Vector2, scale: float) -> void:
	_draw_ellipse(point + Vector2(0, 7) * scale, Vector2(23, 9) * scale, Color("59462e", 0.22))
	draw_circle(point + Vector2(-8, 0) * scale, 10.0 * scale, Color("c9a35e"))
	draw_circle(point + Vector2(4, -3) * scale, 13.0 * scale, Color("ddbd74"))
	draw_circle(point + Vector2(13, 2) * scale, 8.0 * scale, Color("c9a35e"))
	for offset in [-8.0, 0.0, 8.0]:
		draw_line(point + Vector2(offset, -6) * scale, point + Vector2(offset + 3, 7) * scale, Color("9d7a45", 0.7), 1.5 * scale, true)


func _trough(point: Vector2, scale: float) -> void:
	draw_rect(Rect2(point + Vector2(-22, -6) * scale, Vector2(44, 14) * scale), Color("73543b"), true)
	draw_rect(Rect2(point + Vector2(-19, -5) * scale, Vector2(38, 8) * scale), Color("899b86"), true)
	draw_line(point + Vector2(-22, 8) * scale, point + Vector2(22, 8) * scale, Color("503b2b"), 3.0 * scale, true)
	draw_line(point + Vector2(-16, 8) * scale, point + Vector2(-14, 15) * scale, Color("60442f"), 3.0 * scale, true)
	draw_line(point + Vector2(16, 8) * scale, point + Vector2(14, 15) * scale, Color("60442f"), 3.0 * scale, true)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
