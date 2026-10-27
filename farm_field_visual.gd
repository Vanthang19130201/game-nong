extends Node2D

# One static, batched field backdrop. It has no physics, input, or per-frame work.
const FarmData = preload("res://farm_data.gd")

const OUTER_SOIL := Color("765034")
const MAIN_SOIL := Color("A66D3F")
const LIGHT_SOIL := Color("C48752")
const FURROW := Color("8C5A36")
const HONEY := Color("E8B34F")
const LOCKED_GRASS := Color("789457")

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
	# Stable IDs keep the four 4x2 beds separate, even when one plot is moved.
	for group_index in range(4):
		var group_plots: Array[Dictionary] = []
		var first_number: int = group_index * 8 + 1
		for number in range(first_number, first_number + 8):
			var id: String = FarmData.plot_id(number)
			var plot = plots.get(id)
			var point: Vector2 = (
				to_local(plot.global_position)
				if is_instance_valid(plot)
				else FarmData.plot_position(number)
			)
			group_plots.append({
				"number": number,
				"position": point,
				"unlocked": number <= Inventory.unlocked_plot_count
			})

		for component in _connected_plot_groups(group_plots):
			_draw_plot_group(component, group_index)
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
	var has_unlocked: bool = false
	for entry in component:
		has_unlocked = has_unlocked or entry["unlocked"]

	if has_unlocked:
		# Soft shadow, irregular earth edge, and a lighter top lip unify the tiles.
		_draw_rough_rect(bounds.grow(4.0).position + Vector2(0, 3), bounds.grow(4.0).size, Color("4b3828", 0.18), group_index)
		_draw_rough_rect(bounds.grow(4.0).position, bounds.grow(4.0).size, OUTER_SOIL, group_index + 2)
		_draw_rough_rect(bounds.grow(2.0).position, bounds.grow(2.0).size, MAIN_SOIL, group_index + 4)
		_draw_group_edges(bounds)
		_draw_furrows(component)
	else:
		# Far locked beds blend into the lawn and only leave a quiet boundary.
		var outline := _rough_rect_points(bounds.grow(3.0), group_index)
		draw_polyline(_closed(outline), Color("a18b5d", 0.24), 1.5, true)

	for entry in component:
		var cell := Rect2(entry["position"] - FarmData.PLOT_SIZE * 0.5, FarmData.PLOT_SIZE)
		if entry["unlocked"]:
			# A few pixels of shared earth fill the transparent edge between plots.
			draw_rect(cell.grow(2.0), Color(MAIN_SOIL, 0.92), true)
		else:
			# Locked cells show grass instead of dark soil rectangles.
			var grass := LOCKED_GRASS
			var is_next_plot: bool = int(entry["number"]) == Inventory.unlocked_plot_count + 1
			grass.a = (0.82 if is_next_plot else 0.72) if has_unlocked else 0.12
			_draw_rough_rect(cell.grow(1.0).position, cell.grow(1.0).size, grass, int(entry["number"]))
			var locked_edge := Color("a6ad71", 0.52 if is_next_plot else (0.34 if has_unlocked else 0.2))
			draw_rect(cell.grow(-1.0), locked_edge, false, 1.2)

	if has_unlocked and component.size() >= 4:
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
			if first["number"] >= second["number"] or not first["unlocked"] or not second["unlocked"]:
				continue
			var delta: Vector2 = second["position"] - first["position"]
			if is_equal_approx(absf(delta.x), FarmData.GRID_STEP.x) and absf(delta.y) < 1.0:
				var middle_x: float = (first["position"].x + second["position"].x) * 0.5
				draw_line(Vector2(middle_x, first["position"].y - 17), Vector2(middle_x, first["position"].y + 17), Color(FURROW, 0.88), 2.4, true)
			elif is_equal_approx(absf(delta.y), FarmData.GRID_STEP.y) and absf(delta.x) < 1.0:
				var middle_y: float = (first["position"].y + second["position"].y) * 0.5
				draw_line(Vector2(first["position"].x - 23, middle_y), Vector2(first["position"].x + 23, middle_y), Color(FURROW, 0.88), 2.4, true)


func _draw_block_paths() -> void:
	# The existing 10 px gutters become quiet walking furrows between 4x2 beds.
	var vertical_x: float = (FarmData.plot_position(4).x + FarmData.plot_position(9).x) * 0.5
	var top_start: float = FarmData.plot_position(1).y - FarmData.PLOT_SIZE.y * 0.5
	var top_end: float = FarmData.plot_position(5).y + FarmData.PLOT_SIZE.y * 0.5
	var lower_start: float = FarmData.plot_position(17).y - FarmData.PLOT_SIZE.y * 0.5
	var lower_end: float = FarmData.plot_position(21).y + FarmData.PLOT_SIZE.y * 0.5
	_draw_gutter(Vector2(vertical_x, top_start), Vector2(vertical_x, top_end))
	_draw_gutter(Vector2(vertical_x, lower_start), Vector2(vertical_x, lower_end))
	var horizontal_y: float = (FarmData.plot_position(5).y + FarmData.plot_position(17).y) * 0.5
	for start_id in [1, 9]:
		var start_x: float = FarmData.plot_position(start_id).x - FarmData.PLOT_SIZE.x * 0.5
		var end_x: float = FarmData.plot_position(start_id + 3).x + FarmData.PLOT_SIZE.x * 0.5
		_draw_gutter(Vector2(start_x, horizontal_y), Vector2(end_x, horizontal_y))


func _draw_gutter(start: Vector2, finish: Vector2) -> void:
	draw_line(start, finish, Color(FURROW, 0.62), 3.0, true)
	draw_line(start + Vector2(0, -1), finish + Vector2(0, -1), Color(LIGHT_SOIL, 0.28), 1.0, true)


func _draw_field_accents(bounds: Rect2, group_index: int) -> void:
	# Sparse edge details only; plot surfaces and walkable approaches stay clear.
	var left_edge := bounds.position + Vector2(-3, bounds.size.y * 0.68)
	var right_edge := Vector2(bounds.end.x + 3, bounds.position.y + bounds.size.y * 0.32)
	_draw_small_stone(left_edge, 0.8)
	_draw_small_stone(left_edge + Vector2(9, 5), 0.55)
	_draw_small_stone(right_edge, 0.62)
	_draw_tuft(Vector2(bounds.position.x + bounds.size.x * 0.72, bounds.position.y - 4), 0.7)
	if group_index == 0:
		_draw_post(bounds.position + Vector2(1, 2))
	else:
		_draw_flower(bounds.end + Vector2(-6, 2), Color("e9c97a", 0.85))


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
