extends Node2D

const AnimalScene = preload("res://farm_animal.tscn")
const Placement = preload("res://building_placement.gd")
const FarmData = preload("res://farm_data.gd")

@export_enum("chicken", "cow") var animal_type: String = "chicken"
@export_range(120.0, 180.0) var wander_radius: float = 150.0
var obstacles: Array[Rect2] = []
var editing: bool = false
var ground_y: float = 0.0
var last_home: Vector2
var refresh_timer: Timer
var home: Node2D
var hud: Node

func _ready() -> void:
	home = get_parent().get_parent()
	y_sort_enabled = true
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 0.5
	refresh_timer.timeout.connect(_refresh_area)
	add_child(refresh_timer)
	Inventory.inventory_changed.connect(sync_count)
	# Parent buildings restore their position and ownership during _ready().
	sync_count.call_deferred()

func animals() -> Array[Node]:
	var result: Array[Node] = []
	for child in get_children():
		if child != refresh_timer:
			result.append(child)
	return result

func sync_count() -> void:
	var station_id: String = "chicken_coop" if animal_type == "chicken" else "cow_shed"
	var count: int = Inventory.get(animal_type + "_count") if Inventory.owns_building(station_id) else 0
	var current: Array[Node] = animals()
	while current.size() > count:
		var animal: Node = current.pop_back()
		remove_child(animal)
		animal.queue_free()
	_cache_obstacles()
	while current.size() < count:
		var animal = AnimalScene.instantiate()
		add_child(animal)
		animal.configure(animal_type, self)
		_relocate(animal)
		current.append(animal)
	set_process(count > 0)
	if count > 0:
		if refresh_timer.is_stopped():
			refresh_timer.start()
	else:
		refresh_timer.stop()
	last_home = global_position

func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		hud = get_tree().get_first_node_in_group("farm_hud")
	var is_editing: bool = hud != null and hud.edit_farm != null and hud.edit_farm.active
	var moved: bool = not global_position.is_equal_approx(last_home)
	if moved or editing != is_editing:
		editing = is_editing
		last_home = global_position
		_refresh_area()
		for animal in animals():
			animal.rest()

func _cache_obstacles() -> void:
	obstacles.clear()
	var nodes: Array = get_tree().get_nodes_in_group("farm_interactables")
	for node in get_tree().get_nodes_in_group("placement_obstacles") + SaveManager.buildings.values():
		if is_instance_valid(node) and node not in nodes:
			nodes.append(node)
	for node in nodes:
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if node != home and not node.is_visible_in_tree():
			continue
		if node.is_in_group("farm_decorations"):
			if not SaveManager.DecorationData.TYPES[node.decoration_id]["solid"] or node.is_open:
				continue
		obstacles.append(Placement.bounds(node))
	# Include our own building even before its parent has registered it.
	var home_rect: Rect2 = Placement.bounds(home)
	if home_rect not in obstacles:
		obstacles.append(home_rect)
	ground_y = to_local(Vector2(global_position.x, home_rect.end.y)).y

func _refresh_area() -> void:
	_cache_obstacles()
	for animal in animals():
		if not animal.visible or not is_position_valid(animal.position, animal.body_radius):
			_relocate(animal)
		elif animal.walking and not path_is_clear(animal.position, animal.target, animal.body_radius):
			animal.rest()

func is_position_valid(point: Vector2, radius: float) -> bool:
	if not point.is_finite() or point.length() + radius > wander_radius:
		return false
	var footprint := Rect2(to_global(point) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if not FarmData.BUILDABLE_LAND.encloses(footprint):
		return false
	if not SaveManager.LandData.owns_rect(footprint, SaveManager.unlocked_land_zones):
		return false
	for obstacle in obstacles:
		if footprint.intersects(obstacle):
			return false
	return true

func path_is_clear(start: Vector2, end: Vector2, radius: float) -> bool:
	# Check the whole short walk, not just its destination. This also prevents
	# crossing a thin fence or clipping through a corner between two frames.
	var steps: int = maxi(1, ceili(start.distance_to(end) / 8.0))
	for step in range(1, steps + 1):
		if not is_position_valid(start.lerp(end, float(step) / steps), radius):
			return false
	return true

func find_position(animal: Node2D, require_path: bool = false) -> Vector2:
	for attempt in range(48):
		var point: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * (wander_radius - animal.body_radius)
		if not is_position_valid(point, animal.body_radius):
			continue
		var spaced: bool = true
		for other in animals():
			if other != animal and other.visible and other.position.distance_to(point) < animal.spacing:
				spaced = false
				break
		if spaced and (not require_path or path_is_clear(animal.position, point, animal.body_radius)):
			return point
	return Vector2(INF, INF)

func _relocate(animal: Node2D) -> void:
	var point: Vector2 = find_position(animal)
	# A crowded corner may have very little free ground. Search deterministically
	# before hiding a visual; retry when the layout changes. Never change count.
	if not point.is_finite():
		for y in range(-int(wander_radius), int(wander_radius), 16):
			for x in range(-int(wander_radius), int(wander_radius), 16):
				if is_position_valid(Vector2(x, y), animal.body_radius):
					point = Vector2(x, y)
					break
			if point.is_finite():
				break
	animal.visible = point.is_finite()
	if animal.visible:
		animal.position = point
		animal.z_index = -2 if point.y < ground_y else 0
	animal.rest()
