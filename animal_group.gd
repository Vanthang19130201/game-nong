extends Node2D

const AnimalScene = preload("res://farm_animal.tscn")
const Placement = preload("res://building_placement.gd")
const FarmData = preload("res://farm_data.gd")

@export_enum("chicken", "cow", "pig", "sheep") var animal_type: String = "chicken"
@export_range(120.0, 180.0) var wander_radius: float = 150.0
var obstacles: Array[Rect2] = []
var editing: bool = false
var ground_y: float = 0.0
var last_home: Vector2
var refresh_timer: Timer
var growth_timer: Timer
var vocal_timer: Timer
var home: Node2D
var hud: Node

func _ready() -> void:
	add_to_group("farm_animal_groups")
	global_position = home.global_position
	z_index = home.z_index
	z_as_relative = false
	y_sort_enabled = true
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 0.5
	refresh_timer.timeout.connect(_refresh_area)
	add_child(refresh_timer)
	growth_timer = Timer.new()
	growth_timer.name = "GrowthRefreshTimer"
	growth_timer.wait_time = 10.0
	growth_timer.timeout.connect(_refresh_growth)
	add_child(growth_timer)
	vocal_timer = Timer.new()
	vocal_timer.name = "AmbientVocalTimer"
	vocal_timer.one_shot = true
	vocal_timer.timeout.connect(_try_animal_vocal)
	add_child(vocal_timer)
	home.state_changed.connect(_refresh_status)
	# farm.gd owns spawning and count synchronization, not the station scene.

func animals() -> Array[Node]:
	var result: Array[Node] = []
	for child in get_children():
		if child not in [refresh_timer, growth_timer, vocal_timer]:
			result.append(child)
	return result

func _refresh_status() -> void:
	for animal in animals():
		animal.refresh_status()

func _refresh_growth() -> void:
	for animal in animals():
		animal.update_growth()

func sync_count() -> void:
	var station_id: String = Inventory.Progression.ANIMALS[animal_type]["building"]
	var records: Array = SaveManager.animal_records(animal_type).duplicate(true) if Inventory.owns_building(station_id) else []
	var existing: Dictionary = {}
	for animal in animals():
		existing[animal.animal_id] = animal
	for animal_id in existing.keys():
		if not records.any(func(record: Dictionary) -> bool: return record.get("id", "") == animal_id):
			var retired: Node = existing[animal_id]
			retired.retire()
			remove_child(retired)
			retired.queue_free()
	global_position = home.global_position
	_cache_obstacles()
	for record in records:
		var animal_id: String = str(record["id"])
		if existing.has(animal_id) and is_instance_valid(existing[animal_id]):
			var existing_animal: Node2D = existing[animal_id]
			existing_animal.update_record(record)
			# A newly purchased juvenile can briefly have no free random point
			# before surrounding stations finish registering. Re-check it on each
			# sync so a valid adult record never remains invisibly stranded.
			if not existing_animal.visible:
				_relocate(existing_animal)
			continue
		var animal = AnimalScene.instantiate()
		add_child(animal)
		animal.configure(animal_type, self, record)
		_relocate(animal)
	set_process(not records.is_empty())
	if not records.is_empty():
		if refresh_timer.is_stopped():
			refresh_timer.start()
		if growth_timer.is_stopped():
			growth_timer.start()
		if vocal_timer.is_stopped():
			_schedule_animal_vocal()
	else:
		refresh_timer.stop()
		growth_timer.stop()
		vocal_timer.stop()
	last_home = global_position

func _schedule_animal_vocal() -> void:
	if is_instance_valid(vocal_timer):
		vocal_timer.start(randf_range(8.0, 20.0))

func _try_animal_vocal() -> void:
	var player := get_tree().get_first_node_in_group("farm_player")
	var nearby: Array[Node] = []
	if is_instance_valid(player):
		for animal in animals():
			if is_instance_valid(animal) and animal.visible and player.global_position.distance_to(animal.global_position) <= 420.0:
				nearby.append(animal)
	if not nearby.is_empty():
		var animal: Node = nearby[randi() % nearby.size()]
		var sound_id := "chicken_cluck"
		match animal.animal_type:
			"cow": sound_id = "cow_moo"
			"pig": sound_id = "pig_oink"
			"sheep": sound_id = "sheep_baa"
		AudioManager.play_sfx(sound_id, animal.global_position)
	_schedule_animal_vocal()

func _process(_delta: float) -> void:
	if not is_instance_valid(home):
		return
	if not is_instance_valid(hud):
		hud = get_tree().get_first_node_in_group("farm_hud")
	var is_editing: bool = hud != null and hud.edit_farm != null and hud.edit_farm.active
	var moved: bool = not home.global_position.is_equal_approx(last_home)
	if moved or editing != is_editing:
		editing = is_editing
		global_position = home.global_position
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
		if node.is_in_group("farm_animals"):
			continue
		if node != home and not node.is_visible_in_tree():
			continue
		if node.is_in_group("farm_decorations"):
			if not SaveManager.DecorationData.TYPES[node.decoration_id]["solid"] or node.is_open:
				continue
		obstacles.append(Placement.bounds(node))
	# Include our own building even before its parent has registered it. Animals
	# roam around their shelter but never through its footprint.
	var home_rect: Rect2 = Placement.bounds(home)
	if home_rect not in obstacles:
		obstacles.append(home_rect)
	ground_y = to_local(Vector2(global_position.x, home_rect.end.y)).y

func _refresh_area() -> void:
	if not is_instance_valid(home):
		return
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
