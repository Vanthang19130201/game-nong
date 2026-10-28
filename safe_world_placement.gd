extends RefCounted

const Placement = preload("res://building_placement.gd")
const FarmData = preload("res://farm_data.gd")

# Centerlines mirror the static main routes drawn by FarmLandscape.
static var MAIN_ROUTES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(700,480),Vector2(700,535),Vector2(710,690),Vector2(700,840),Vector2(700,1140)]),
	PackedVector2Array([Vector2(700,520),Vector2(820,520),Vector2(838,475),Vector2(838,365),Vector2(920,335)]),
	PackedVector2Array([Vector2(700,650),Vector2(790,650),Vector2(920,650)]),
	PackedVector2Array([Vector2(700,730),Vector2(635,748),Vector2(550,750)]),
	PackedVector2Array([Vector2(700,1140),Vector2(880,1140),Vector2(1165,1140),Vector2(1450,1140),Vector2(1750,1140)]),
	PackedVector2Array([Vector2(1750,1140),Vector2(1750,850)]),
	PackedVector2Array([Vector2(700,960),Vector2(650,960)]),
	PackedVector2Array([Vector2(700,1140),Vector2(560,1140)]),
	PackedVector2Array([Vector2(897,1140),Vector2(897,1090)]),
	PackedVector2Array([Vector2(1453,1140),Vector2(1453,1095)]),
	PackedVector2Array([Vector2(1165,1140),Vector2(1165,1018)]),
	PackedVector2Array([Vector2(1975,850),Vector2(2040,930),Vector2(2040,1800)]),
	PackedVector2Array([Vector2(2040,930),Vector2(2040,600),Vector2(2240,410)]),
	PackedVector2Array([Vector2(2040,1020),Vector2(1980,1020)]),
	PackedVector2Array([Vector2(700,1140),Vector2(715,1480),Vector2(790,1770),Vector2(820,2050),Vector2(790,2290),Vector2(790,2460),Vector2(840,2650),Vector2(815,2860),Vector2(880,3060)]),
	PackedVector2Array([Vector2(790,2460),Vector2(590,2505),Vector2(360,2580),Vector2(180,2690)]),
	PackedVector2Array([Vector2(805,2610),Vector2(1035,2555),Vector2(1270,2560),Vector2(1510,2635)]),
	PackedVector2Array([Vector2(820,2860),Vector2(640,2940),Vector2(420,3010),Vector2(220,3110)]),
	PackedVector2Array([Vector2(835,2860),Vector2(1080,2910),Vector2(1320,2990),Vector2(1570,3100)]),
	PackedVector2Array([Vector2(900,-500),Vector2(900,-280),Vector2(850,-80),Vector2(790,180),Vector2(820,360),Vector2(838,480)]),
	PackedVector2Array([Vector2(-1050,1040),Vector2(-760,1050),Vector2(-480,1080),Vector2(-220,1130),Vector2(0,1140),Vector2(360,1140),Vector2(700,1140)]),
	PackedVector2Array([Vector2(-1040,440),Vector2(-760,455),Vector2(-500,480),Vector2(-260,515),Vector2(0,540),Vector2(370,550),Vector2(700,650)]),
	PackedVector2Array([Vector2(-1040,1770),Vector2(-760,1760),Vector2(-500,1745),Vector2(-250,1710),Vector2(0,1680),Vector2(350,1690),Vector2(790,1770)])
]

static func is_near_main_route(point: Vector2, clearance: float) -> bool:
	for route in MAIN_ROUTES:
		for index in range(route.size() - 1):
			if _distance_to_segment(point, route[index], route[index + 1]) <= clearance:
				return true
	return false

static func is_clear(farm: Node2D, point: Vector2, footprint_size: Vector2, route_clearance: float = 56.0) -> bool:
	if not is_instance_valid(farm) or not point.is_finite():
		return false
	var rect := Rect2(point - footprint_size * 0.5, footprint_size)
	if not FarmData.BUILDABLE_LAND.encloses(rect) or FarmData.FIELD_RESERVE.intersects(rect):
		return false
	if not SaveManager.LandData.owns_rect(rect, SaveManager.unlocked_land_zones):
		return false
	if is_near_main_route(point, route_clearance + maxf(footprint_size.x, footprint_size.y) * 0.5):
		return false
	if point.distance_to(Vector2(800, 600)) < 220.0:
		return false
	var player := farm.get_tree().get_first_node_in_group("farm_player") as Node2D
	if is_instance_valid(player) and point.distance_to(player.global_position) < 120.0:
		return false
	var probe := Node2D.new()
	probe.position = point
	probe.set_meta("placement_rect", Rect2(-footprint_size * 0.5, footprint_size))
	farm.add_child(probe)
	var clear := Placement.can_place(probe, point)
	farm.remove_child(probe)
	probe.free()
	return clear

static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)
