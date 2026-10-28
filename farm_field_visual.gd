extends Node2D

# One static, batched field backdrop. It has no physics, input, or per-frame work.
const FarmData = preload("res://farm_data.gd")

const LIGHT_SOIL := Color("A7B875")
const FURROW := Color("526A3B")

var plots: Dictionary = {}


func configure(plot_nodes: Dictionary) -> void:
	plots = plot_nodes
	for plot in plots.values():
		if is_instance_valid(plot) and not plot.item_rect_changed.is_connected(_on_plot_changed):
			plot.item_rect_changed.connect(_on_plot_changed)
	if not Inventory.inventory_changed.is_connected(_on_plot_changed):
		Inventory.inventory_changed.connect(_on_plot_changed)
	queue_redraw()


func _on_plot_changed() -> void:
	queue_redraw()


func _draw() -> void:
	# Draw only purchased plots. Locked plot nodes remain interactive, but leave
	# no soil, lock icon, or ghost cell in the visible field.
	for group_index in range(4):
		var open_plots: Array[Dictionary] = []
		var first_number: int = group_index * 8 + 1
		for number in range(first_number, first_number + 8):
			if number > Inventory.unlocked_plot_count:
				continue
			var id: String = FarmData.plot_id(number)
			var plot = plots.get(id)
			var point: Vector2 = (
				to_local(plot.global_position)
				if is_instance_valid(plot)
				else FarmData.plot_position(number)
			)
			open_plots.append({
				"number": number,
				"position": point,
				"unlocked": true
			})

		for component in _connected_plot_groups(open_plots):
			_draw_plot_group(component, group_index)
	_draw_field_border_garden()
	_draw_block_paths()


func _connected_plot_groups(source: Array[Dictionary]) -> Array:
	# Moving one plot away must not stretch its original field across the map.
	var pending: Array = source.duplicate()
	var result: Array = []
	while not pending.is_empty():
		var component: Array = [pending.pop_back()]
		var found_neighbor: bool = true
		while found_neighbor:
			found_neighbor = false
			for candidate in pending.duplicate():
				for member in component:
					if candidate["position"].distance_to(member["position"]) <= 120.0:
						component.append(candidate)
						pending.erase(candidate)
						found_neighbor = true
						break
		result.append(component)
	return result


func _draw_plot_group(component: Array, group_index: int) -> void:
	var bounds := _plot_bounds(component)
	# Let the farm lawn show through between plots instead of painting one large
	# rectangular field slab. Only a small sod rim is drawn beneath each tile.
	_draw_group_edges(bounds)
	_draw_furrows(component)

	for entry in component:
		var cell := Rect2(entry["position"] - FarmData.PLOT_SIZE * 0.5, FarmData.PLOT_SIZE)
		# A soft sod rim fills the transparent edge around each tilled sprite.
		# Keep the backing green so the field blends into the farm instead of
		# forming a large red-brown block.
		var sod := cell.grow(2.0)
		_draw_rough_rect(sod.position, sod.size, Color("839b5d", 0.96), int(entry["number"]))

	_draw_bed_trim(bounds, group_index)
	if component.size() >= 4:
		_draw_field_accents(bounds, group_index)


func _plot_bounds(component: Array) -> Rect2:
	var first: bool = true
	var bounds := Rect2()
	for entry in component:
		var cell := Rect2(entry["position"] - FarmData.PLOT_SIZE * 0.5, FarmData.PLOT_SIZE)
		bounds = cell if first else bounds.merge(cell)
		first = false
	return bounds


func _draw_group_edges(bounds: Rect2) -> void:
	draw_line(bounds.position + Vector2(2, 1), Vector2(bounds.end.x - 2, bounds.position.y + 1), Color(LIGHT_SOIL, 0.72), 2.0, true)
	draw_line(Vector2(bounds.position.x + 2, bounds.end.y - 1), bounds.end - Vector2(2, 1), Color(FURROW, 0.68), 2.0, true)


func _draw_furrows(component: Array) -> void:
	for first in component:
		for second in component:
			if first["number"] >= second["number"]:
				continue
			var delta: Vector2 = second["position"] - first["position"]
			if is_equal_approx(absf(delta.x), FarmData.GRID_STEP.x) and absf(delta.y) < 1.0:
				var middle_x: float = (first["position"].x + second["position"].x) * 0.5
				draw_line(Vector2(middle_x, first["position"].y - 17), Vector2(middle_x, first["position"].y + 17), Color(FURROW, 0.88), 2.4, true)
			elif is_equal_approx(absf(delta.y), FarmData.GRID_STEP.y) and absf(delta.x) < 1.0:
				var middle_y: float = (first["position"].y + second["position"].y) * 0.5
				draw_line(Vector2(first["position"].x - 23, middle_y), Vector2(first["position"].x + 23, middle_y), Color(FURROW, 0.88), 2.4, true)


func _draw_block_paths() -> void:
	# Keep narrow walking furrows only where both neighboring beds are present.
	var vertical_x: float = (FarmData.plot_position(4).x + FarmData.plot_position(9).x) * 0.5
	var top_start: float = FarmData.plot_position(1).y - FarmData.PLOT_SIZE.y * 0.5
	var top_end: float = FarmData.plot_position(5).y + FarmData.PLOT_SIZE.y * 0.5
	var lower_start: float = FarmData.plot_position(17).y - FarmData.PLOT_SIZE.y * 0.5
	var lower_end: float = FarmData.plot_position(21).y + FarmData.PLOT_SIZE.y * 0.5
	var horizontal_y: float = (FarmData.plot_position(5).y + FarmData.plot_position(17).y) * 0.5
	if Inventory.unlocked_plot_count >= 9:
		_draw_gutter(Vector2(vertical_x, top_start), Vector2(vertical_x, top_end))
	if Inventory.unlocked_plot_count >= 17:
		var left_start: float = FarmData.plot_position(1).x - FarmData.PLOT_SIZE.x * 0.5
		var left_end: float = FarmData.plot_position(4).x + FarmData.PLOT_SIZE.x * 0.5
		_draw_gutter(Vector2(left_start, horizontal_y), Vector2(left_end, horizontal_y))
	if Inventory.unlocked_plot_count >= 25:
		_draw_gutter(Vector2(vertical_x, lower_start), Vector2(vertical_x, lower_end))
		var right_start: float = FarmData.plot_position(9).x - FarmData.PLOT_SIZE.x * 0.5
		var right_end: float = FarmData.plot_position(12).x + FarmData.PLOT_SIZE.x * 0.5
		_draw_gutter(Vector2(right_start, horizontal_y), Vector2(right_end, horizontal_y))


func _draw_bed_trim(bounds: Rect2, group_index: int) -> void:
	# A few low, broken timber edges define the bed without enclosing it.
	var top_y: float = bounds.position.y - 8.0
	var left_x: float = bounds.position.x - 8.0
	var right_x: float = bounds.end.x + 8.0
	var top_start: float = bounds.position.x + bounds.size.x * 0.1
	var top_end: float = bounds.end.x - bounds.size.x * 0.1
	_draw_rail(Vector2(top_start, top_y), Vector2(top_start + bounds.size.x * 0.25, top_y))
	_draw_rail(Vector2(top_end - bounds.size.x * 0.25, top_y), Vector2(top_end, top_y))
	_draw_rail(Vector2(left_x, bounds.position.y + bounds.size.y * 0.22), Vector2(left_x, bounds.end.y - bounds.size.y * 0.2))
	_draw_rail(Vector2(right_x, bounds.position.y + bounds.size.y * 0.2), Vector2(right_x, bounds.end.y - bounds.size.y * 0.22))


func _draw_rail(start: Vector2, finish: Vector2) -> void:
	var dark := Color("59402d", 0.88)
	var wood := Color("a47b4e", 0.92)
	draw_line(start + Vector2(0, 2), finish + Vector2(0, 2), dark, 5.0, true)
	draw_line(start, finish, wood, 3.0, true)
	for point in [start, finish]:
		draw_rect(Rect2(point + Vector2(-2, -5), Vector2(4, 10)), dark, true)
		draw_rect(Rect2(point + Vector2(-1, -4), Vector2(2, 7)), Color("c19a62"), true)


func _draw_gutter(start: Vector2, finish: Vector2) -> void:
	draw_line(start, finish, Color(FURROW, 0.62), 3.0, true)
	draw_line(start + Vector2(0, -1), finish + Vector2(0, -1), Color(LIGHT_SOIL, 0.28), 1.0, true)


func _draw_field_accents(bounds: Rect2, group_index: int) -> void:
	# Tiny meadow details sit on the green rim, away from crop tiles and paths.
	var left_edge := bounds.position + Vector2(-3, bounds.size.y * 0.68)
	var right_edge := Vector2(bounds.end.x + 3, bounds.position.y + bounds.size.y * 0.32)
	_draw_small_stone(left_edge, 0.8)
	_draw_small_stone(left_edge + Vector2(9, 5), 0.55)
	_draw_small_stone(right_edge, 0.62)
	_draw_tuft(Vector2(bounds.position.x + bounds.size.x * 0.72, bounds.position.y - 6), 0.72)
	_draw_tuft(Vector2(bounds.position.x + bounds.size.x * 0.28, bounds.end.y + 7), 0.58)
	if group_index == 0:
		_draw_post(bounds.position + Vector2(1, 2))
	else:
		_draw_flower(bounds.end + Vector2(-8, 2), Color("f0d38a", 0.92))
		_draw_flower(bounds.position + Vector2(bounds.size.x * 0.62, -6), Color("e9d7c0", 0.88))


func _draw_field_border_garden() -> void:
	# A narrow planted border makes the whole field feel intentional while staying
	# outside every one of the 32 possible plot footprints.
	var half_size: Vector2 = FarmData.PLOT_SIZE * 0.5
	var first_position: Vector2 = FarmData.plot_position(1)
	var last_position: Vector2 = FarmData.plot_position(FarmData.MAX_PLOTS)
	var left: float = first_position.x - half_size.x
	var right: float = last_position.x + half_size.x
	var top: float = first_position.y - half_size.y - 19.0
	var bottom: float = last_position.y + half_size.y + 20.0
	for index in range(5):
		var x: float = lerpf(left + 12.0, right - 12.0, float(index) / 4.0)
		_draw_tuft(Vector2(x, top - 2.0), 0.75 if index % 2 == 0 else 0.58)
		_draw_tuft(Vector2(x + 18.0, bottom + 1.0), 0.62)
		if index % 2 == 0:
			_draw_flower_cluster(Vector2(x + 7.0, top), index)
			_draw_flower_cluster(Vector2(x - 7.0, bottom), index + 1)
	# Tiny stepping stones mark the west entrance without covering the first plot.
	for y in [first_position.y + 30.0, first_position.y + 48.0, first_position.y + 66.0]:
		_draw_small_stone(Vector2(left - 10.0, y), 0.88)
	_draw_flower_cluster(Vector2(right + 8.0, first_position.y + 20.0), 3)
	_draw_flower_cluster(Vector2(right + 8.0, last_position.y - 18.0), 4)


func _draw_flower_cluster(center: Vector2, variation: int) -> void:
	var petal_colors: Array[Color] = [Color("f0d38a"), Color("eee0c2"), Color("d9aab0")]
	for index in range(3):
		var x_offset: float = float(index - 1) * 5.0
		_draw_flower(center + Vector2(x_offset, 0), petal_colors[(index + variation) % petal_colors.size()])


func _draw_small_stone(point: Vector2, scale: float) -> void:
	draw_circle(point + Vector2(1, 1), 3.2 * scale, Color("5f5542", 0.4))
	draw_circle(point, 2.7 * scale, Color("b2a58a", 0.72))
	draw_line(point + Vector2(-1.5, -0.8), point + Vector2(1.3, -1.1), Color("ded0ae", 0.7), 0.8, true)


func _draw_tuft(point: Vector2, scale: float) -> void:
	draw_line(point, point + Vector2(-4, -8) * scale, Color("748d4c", 0.85), 1.5, true)
	draw_line(point, point + Vector2(0, -10) * scale, Color("a2ae66", 0.85), 1.6, true)
	draw_line(point, point + Vector2(4, -7) * scale, Color("748d4c", 0.85), 1.5, true)


func _draw_flower(point: Vector2, petal: Color) -> void:
	draw_line(point + Vector2(0, 6), point, Color("637c45"), 1.2, true)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3)]:
		draw_circle(point + offset, 2.0, petal)
	draw_circle(point, 1.2, Color("d5a34a"))


func _draw_post(point: Vector2) -> void:
	draw_rect(Rect2(point - Vector2(2, 7), Vector2(5, 15)), Color("60432f"), true)
	draw_rect(Rect2(point - Vector2(1, 6), Vector2(3, 12)), Color("a47b4e"), true)
	draw_rect(Rect2(point + Vector2(-3, -8), Vector2(7, 3)), Color("c19a67"), true)


func _draw_rough_rect(position: Vector2, size: Vector2, color: Color, variation: int) -> void:
	draw_colored_polygon(_rough_rect_points(Rect2(position, size), variation), color)


func _rough_rect_points(rect: Rect2, variation: int) -> PackedVector2Array:
	var nudge: float = float(variation % 3)
	return PackedVector2Array([
		Vector2(rect.position.x + 3 + nudge, rect.position.y + 1),
		Vector2(rect.end.x - 5, rect.position.y + 2 + nudge),
		Vector2(rect.end.x - 1, rect.position.y + 5),
		Vector2(rect.end.x - 2, rect.end.y - 4 - nudge),
		Vector2(rect.end.x - 6, rect.end.y - 1),
		Vector2(rect.position.x + 5, rect.end.y - 2),
		Vector2(rect.position.x + 1, rect.end.y - 6),
		Vector2(rect.position.x + 2, rect.position.y + 6)
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result
