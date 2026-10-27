extends RefCounted

const FarmData = preload("res://farm_data.gd")
const GRID_SIZE: float = 64.0
const OWNED_LAND: Rect2 = FarmData.BUILDABLE_LAND

static func snap_position(position: Vector2) -> Vector2:
	return position.snapped(Vector2(GRID_SIZE, GRID_SIZE))

# Shared by edit mode and future building/decor placement. Preview nodes never
# participate in gameplay, collision queries or saves.
static func can_place(source: Node2D, position: Vector2, require_owned_land: bool = true) -> bool:
	var is_plot: bool = source.get("plot_id") != null
	var stable_id = SaveManager.buildings.find_key(source)
	var valid_anchor: bool = FarmData.valid_saved_building_position(stable_id, position) if stable_id != null else FarmData.valid_building_position(position)
	if is_plot:
		# Soil may use the field reserve; buildings keep their existing restriction.
		valid_anchor = source.is_unlocked() and position.is_finite() and OWNED_LAND.has_point(position)
	if not valid_anchor:
		return false
	var footprint: Rect2 = bounds(source)
	footprint.position += position - source.global_position
	if not OWNED_LAND.encloses(footprint):
		return false
	if require_owned_land and not SaveManager.LandData.owns_rect(footprint, SaveManager.unlocked_land_zones):
		return false
	var obstacles: Array = source.get_tree().get_nodes_in_group("farm_interactables")
	for decoration in source.get_tree().get_nodes_in_group("placement_obstacles"):
		if decoration not in obstacles:
			obstacles.append(decoration)
	for building in SaveManager.buildings.values():
		if building not in obstacles:
			obstacles.append(building)
	for obstacle in obstacles:
		if not is_instance_valid(obstacle) or obstacle == source or not obstacle.is_visible_in_tree():
			continue
		if is_plot and obstacle.is_in_group("farm_decorations") and not SaveManager.DecorationData.TYPES[obstacle.decoration_id]["solid"]:
			continue
		var padding: float = 0.0 if is_plot or source.is_in_group("farm_decorations") or source.get("decoration_id") != null or obstacle.is_in_group("farm_decorations") else 4.0
		if footprint.grow(padding).intersects(bounds(obstacle)):
			return false
	return true

static func bounds(source: Node2D) -> Rect2:
	if source.has_method("get_placement_rect"):
		return source.get_placement_rect()
	# Artwork may overhang. Authored footprints keep placement unchanged.
	if source.has_meta("placement_rect"):
		return source.global_transform * source.get_meta("placement_rect")
	var graphics: Array = []
	_collect_graphics(source, graphics)
	var result := Rect2(source.global_position - Vector2(32,32), Vector2(64,64))
	var first: bool = true
	for graphic in graphics:
		var rect: Rect2 = graphic.get_rect() if graphic is Sprite2D else (Rect2(Vector2.ZERO, graphic.size) if graphic is ColorRect else _polygon_rect(graphic.polygon))
		rect = graphic.get_global_transform() * rect
		result = rect if first else result.merge(rect)
		first = false
	# Empty-texture placeholders (or future decorations) still have a footprint.
	if first:
		for shape in source.find_children("*", "CollisionShape2D", true, false):
			if shape.shape != null:
				var rect: Rect2 = shape.global_transform * shape.shape.get_rect()
				result = rect if first else result.merge(rect)
				first = false
	return result

static func create_preview(source: Node2D) -> Node2D:
	if source.has_method("create_placement_preview"):
		return source.create_placement_preview()
	var preview := Node2D.new()
	preview.z_index = 100
	var graphics: Array = []
	_collect_graphics(source, graphics)
	for graphic in graphics:
		var copy: Node2D
		if graphic is Sprite2D:
			var sprite := Sprite2D.new()
			sprite.texture = graphic.texture
			sprite.centered = graphic.centered
			sprite.offset = graphic.offset
			sprite.region_enabled = graphic.region_enabled
			sprite.region_rect = graphic.region_rect
			sprite.region_filter_clip_enabled = graphic.region_filter_clip_enabled
			sprite.flip_h = graphic.flip_h
			sprite.flip_v = graphic.flip_v
			copy = sprite
		else:
			var polygon := Polygon2D.new()
			polygon.polygon = graphic.polygon if graphic is Polygon2D else PackedVector2Array([Vector2.ZERO, Vector2(graphic.size.x,0), graphic.size, Vector2(0,graphic.size.y)])
			polygon.color = graphic.color
			copy = polygon
		copy.transform = source.global_transform.affine_inverse() * graphic.get_global_transform()
		preview.add_child(copy)
	var outline := Polygon2D.new()
	var rect: Rect2 = bounds(source)
	rect.position -= source.global_position
	outline.polygon = PackedVector2Array([rect.position, rect.position+Vector2(rect.size.x,0), rect.end, rect.position+Vector2(0,rect.size.y)])
	outline.color = Color(1,1,1,0.25)
	preview.add_child(outline)
	return preview

static func _collect_graphics(node: Node, result: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if (node is Sprite2D and node.texture != null) or node is ColorRect or node is Polygon2D:
		result.append(node)
	for child in node.get_children():
		_collect_graphics(child, result)

static func _polygon_rect(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect
