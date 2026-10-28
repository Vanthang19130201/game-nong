extends Node2D

# Presentation-only footsteps.  A handful of short-lived records are drawn by
# this one node instead of allocating particle nodes for every player step.

const STEP_DISTANCE: float = 22.0
var dirt_paths: Array[Dictionary] = [
	{"points": PackedVector2Array([Vector2(700, 480), Vector2(700, 1140)]), "width": 44.0},
	{"points": PackedVector2Array([Vector2(700, 650), Vector2(920, 650)]), "width": 32.0},
	{"points": PackedVector2Array([Vector2(700, 1140), Vector2(1750, 1140), Vector2(1750, 850)]), "width": 38.0},
	{"points": PackedVector2Array([Vector2(700, 1140), Vector2(790, 1770), Vector2(815, 2860), Vector2(880, 3060)]), "width": 38.0},
	{"points": PackedVector2Array([Vector2(900, -500), Vector2(790, 180), Vector2(838, 480)]), "width": 38.0},
	{"points": PackedVector2Array([Vector2(-1050, 1040), Vector2(0, 1140), Vector2(700, 1140)]), "width": 38.0},
	{"points": PackedVector2Array([Vector2(1975, 850), Vector2(2040, 930), Vector2(2040, 1800)]), "width": 30.0}
]
var wood_surfaces: Array[Rect2] = [
	Rect2(1788, 780, 168, 142), Rect2(1928, 968, 115, 110), Rect2(1990, 1398, 118, 108)
]

var body: CharacterBody2D
var last_world_position: Vector2
var distance_since_step: float = 0.0
var sound_cooldown: float = 0.0
var particles: Array[Dictionary] = []


func _ready() -> void:
	body = get_parent() as CharacterBody2D
	if body != null:
		last_world_position = body.global_position
	z_index = -1


func _process(delta: float) -> void:
	if not is_instance_valid(body):
		return
	var moved := body.global_position.distance_to(last_world_position)
	var is_walking := body.velocity.length_squared() > 64.0 and moved > 0.01
	if is_walking:
		distance_since_step += moved
		if distance_since_step >= STEP_DISTANCE:
			distance_since_step = fmod(distance_since_step, STEP_DISTANCE)
			_spawn_step(surface_at(body.global_position))
	else:
		distance_since_step = minf(distance_since_step, STEP_DISTANCE * 0.55)
	last_world_position = body.global_position
	sound_cooldown = maxf(0.0, sound_cooldown - delta)
	var active := false
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			particles.remove_at(index)
			continue
		var particle_position: Vector2 = particle["position"]
		var particle_velocity: Vector2 = particle["velocity"]
		particle["position"] = particle_position + particle_velocity * delta
		particles[index] = particle
		active = true
	if active or is_walking:
		queue_redraw()


func _spawn_step(surface: String) -> void:
	var origin := body.global_position + Vector2(
		randf_range(-3.0, 3.0),
		5.0
	)

	var life := (
		0.34 if surface == "dirt"
		else 0.42 if surface == "grass"
		else 0.25
	)

	particles.append({
		"position": origin,
		"velocity": Vector2(
			randf_range(-5.0, 5.0),
			-randf_range(5.0, 10.0)
		),
		"life": life,
		"max_life": life,
		"surface": surface
	})

	if sound_cooldown <= 0.0:
		AudioManager.play_random_sfx(
			"footstep_soft",
			body.global_position
		)
		sound_cooldown = 0.19


func surface_at(world_position: Vector2) -> String:
	for area in wood_surfaces:
		if area.has_point(world_position):
			return "wood"
	for path in dirt_paths:
		if _distance_to_polyline(world_position, path["points"]) <= float(path["width"]) * 0.5:
			return "dirt"
	return "grass"


func _draw() -> void:
	for particle in particles:
		var alpha := clampf(float(particle["life"]) / float(particle["max_life"]), 0.0, 1.0)
		var world_point: Vector2 = particle["position"]
		var point := to_local(world_point)
		match str(particle["surface"]):
			"grass":
				draw_line(point, point + Vector2(-2, -5), Color("b4c875", 0.62 * alpha), 1.4, true)
				draw_line(point + Vector2(2, 1), point + Vector2(4, -3), Color("71994f", 0.58 * alpha), 1.2, true)
			"dirt":
				draw_circle(point, 2.5 * (1.0 - alpha * 0.35), Color("d8bc83", 0.36 * alpha))
			"wood":
				draw_line(point + Vector2(-3, 0), point + Vector2(3, 0), Color("d1a86c", 0.42 * alpha), 1.1, true)


func _distance_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	var nearest := INF
	for index in range(points.size() - 1):
		nearest = minf(nearest, _distance_to_segment(point, points[index], points[index + 1]))
	return nearest


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var line := finish - start
	var length_squared := line.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var factor := clampf((point - start).dot(line) / length_squared, 0.0, 1.0)
	return point.distance_to(start.lerp(finish, factor))
