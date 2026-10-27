extends Node2D

const SafePlacement = preload("res://safe_world_placement.gd")

var farm: Node2D
var wildlife: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var current_day: int = -1

func _ready() -> void:
	farm = get_parent() as Node2D
	z_index = 3
	GameClock.changed.connect(_on_day_changed)
	current_day = GameClock.absolute_day
	_seed_day()

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player):
		return
	var moved := false
	for animal in wildlife:
		var position: Vector2 = animal["position"]
		var target: Vector2 = animal["target"]
		var discovery_id: String = animal["type"]
		if position.distance_to(player.global_position) <= 132.0 and not DiscoveryManager.has_discovered("nature", discovery_id):
			DiscoveryManager.discover("nature", discovery_id)
		if position.distance_to(target) < 3.0:
			if position.distance_to(player.global_position) < 142.0 and not animal["fleeing"]:
				animal["target"] = _flee_target(position, player.global_position)
				animal["fleeing"] = true
				animal["speed"] = 100.0 if animal["type"] == "rabbit" else 145.0
			else:
				animal["fleeing"] = false
				animal["speed"] = 0.0
		else:
			var direction: Vector2 = position.direction_to(target)
			animal["position"] = position + direction * minf(float(animal["speed"]) * delta, position.distance_to(target))
			moved = true
	if moved:
		queue_redraw()

func _seed_day() -> void:
	wildlife.clear()
	current_day = GameClock.absolute_day
	rng.seed = 0x57494C44 + GameClock.absolute_day * 4409
	var points: Array[Vector2] = []
	for y in range(280, 2260, 88):
		for x in range(190, 1660, 88):
			var point := Vector2(x, y)
			if SafePlacement.is_clear(farm, point, Vector2(18, 16), 74.0):
				points.append(point)
	for index in range(points.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap := points[index]
		points[index] = points[other]
		points[other] = swap
	var birds := mini(rng.randi_range(2, 4), points.size())
	for index in range(birds):
		_add_wildlife("bird", points[index])
	var next_index := birds
	if rng.randf() < 0.24:
		var rabbits := mini(rng.randi_range(1, 2), points.size() - next_index)
		for index in range(rabbits):
			_add_wildlife("rabbit", points[next_index + index])
func _add_wildlife(kind: String, point: Vector2) -> void:
	wildlife.append({"type":kind, "position":point, "target":point, "speed":0.0, "fleeing":false})

func _flee_target(from: Vector2, player: Vector2) -> Vector2:
	var away := (from - player).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	for attempt in range(8):
		var direction := away.rotated(rng.randf_range(-1.1, 1.1))
		var point := from + direction * rng.randf_range(92.0, 150.0)
		if SafePlacement.is_clear(farm, point, Vector2(18, 16), 32.0):
			return point
	return from

func _on_day_changed() -> void:
	if GameClock.absolute_day == current_day:
		return
	_seed_day()

func _draw() -> void:
	for animal in wildlife:
		var point: Vector2 = animal["position"]
		if animal["type"] == "bird":
			_draw_oval(point, Vector2(6, 3), Color("eee0c3"))
			draw_circle(point + Vector2(4, -2), 2.2, Color("9a6845"))
			draw_line(point + Vector2(-4, -1), point + Vector2(-9, -4), Color("80664d"), 1.5, true)
			draw_line(point + Vector2(-4, 1), point + Vector2(-9, 4), Color("80664d"), 1.5, true)
		else:
			draw_circle(point, 6.5, Color("c5b99a"))
			_draw_oval(point + Vector2(-2, -8), Vector2(2, 5), Color("c5b99a"))
			_draw_oval(point + Vector2(3, -8), Vector2(2, 5), Color("c5b99a"))
			draw_circle(point + Vector2(2, -1), 1.0, Color("5b402d"))

func _draw_oval(point: Vector2, radius: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		polygon.append(point + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(polygon, color)
