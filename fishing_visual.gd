extends Node2D

const FishingData = preload("res://fishing_data.gd")

enum Mode {
	HIDDEN,
	WAITING,
	BITE,
	CAUGHT,
	FAILED
}

var mode: Mode = Mode.HIDDEN

var elapsed: float = 0.0

var cast_origin: Vector2 = Vector2.ZERO

var caught_fish_id: String = "tilapia"
var caught_fish_sprite: Sprite2D

@export var bobber_position: Vector2 = Vector2(
	-114,
	12
)


func _ready() -> void:
	z_index = 10
	caught_fish_sprite = Sprite2D.new()
	caught_fish_sprite.name = "CaughtFishSprite"
	caught_fish_sprite.z_index = 2
	caught_fish_sprite.centered = true
	caught_fish_sprite.visible = false
	add_child(caught_fish_sprite)

	visible = false

	set_process(false)


# ==================================================
# PUBLIC
# ==================================================

func set_cast_origin(value: Vector2) -> void:
	cast_origin = value

	if visible:
		queue_redraw()


func set_caught_fish(fish_id: String) -> void:
	caught_fish_id = fish_id
	if not is_instance_valid(caught_fish_sprite):
		return
	var fish_info: Dictionary = FishingData.FISH.get(fish_id, {})
	var asset_path: String = str(fish_info.get("asset_path", ""))
	var artwork: Texture2D = null
	if not asset_path.is_empty():
		artwork = load(asset_path) as Texture2D
	caught_fish_sprite.texture = artwork
	if artwork == null:
		caught_fish_sprite.visible = false
		return
	var artwork_size: Vector2 = artwork.get_size()
	var scale_factor: float = 46.0 / maxf(artwork_size.x, artwork_size.y)
	caught_fish_sprite.scale = Vector2.ONE * scale_factor
	if mode == Mode.CAUGHT:
		caught_fish_sprite.visible = true


func show_waiting() -> void:
	set_mode(Mode.WAITING)


func show_bite() -> void:
	set_mode(Mode.BITE)


func show_caught() -> void:
	set_mode(Mode.CAUGHT)


func show_failed() -> void:
	set_mode(Mode.FAILED)


func hide_visual() -> void:
	set_mode(Mode.HIDDEN)


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return

	mode = new_mode

	elapsed = 0.0

	visible = (
		mode != Mode.HIDDEN
	)
	if is_instance_valid(caught_fish_sprite):
		if mode == Mode.CAUGHT and caught_fish_sprite.texture != null:
			_update_caught_fish_sprite()
		caught_fish_sprite.visible = mode == Mode.CAUGHT and caught_fish_sprite.texture != null

	set_process(visible)

	queue_redraw()


# ==================================================
# PROCESS
# ==================================================

func _process(delta: float) -> void:
	elapsed += delta
	if mode == Mode.CAUGHT:
		_update_caught_fish_sprite()

	queue_redraw()


func _update_caught_fish_sprite() -> void:
	if not is_instance_valid(caught_fish_sprite) or caught_fish_sprite.texture == null:
		return
	var hand_point: Vector2 = cast_origin + Vector2(18, -9)
	var water_point: Vector2 = _current_bobber_position()
	# Keep the hooked fish near the upper part of the line, closer to Player
	# than the water, so it stays readable over both pond and river.
	caught_fish_sprite.position = water_point.lerp(hand_point, 0.66) + Vector2(0, sin(elapsed * 7.0) * 2.0 - 7.0)
	var line_to_player: Vector2 = hand_point - water_point
	caught_fish_sprite.rotation = line_to_player.angle() - PI + sin(elapsed * 5.0) * 0.09


func _draw() -> void:
	if mode == Mode.HIDDEN:
		return

	var bobber := _current_bobber_position()

	match mode:
		Mode.WAITING:
			_draw_line(
				cast_origin,
				bobber
			)

			_draw_waiting_ripple(
				bobber
			)

			_draw_bobber(
				bobber
			)

		Mode.BITE:
			_draw_line(
				cast_origin,
				bobber
			)

			_draw_bite_ripples(
				bobber
			)

			_draw_bobber(
				bobber
			)

		Mode.CAUGHT:
			_draw_caught_ripples(
				bobber
			)

			_draw_catch_sequence(
				bobber
			)
			if caught_fish_id == "moon_fish" and is_instance_valid(caught_fish_sprite) and caught_fish_sprite.visible:
				_draw_moon_fish_catch_effect(caught_fish_sprite.position)

		Mode.FAILED:
			_draw_line(
				cast_origin,
				bobber
			)

			_draw_failed_ripple(
				bobber
			)

			_draw_bobber(
				bobber
			)


# ==================================================
# BOBBER
# ==================================================

func _current_bobber_position() -> Vector2:
	var offset := Vector2.ZERO

	match mode:
		Mode.WAITING:
			offset.y = (
				sin(elapsed * 3.0)
				* 1.2
			)

		Mode.BITE:
			offset.y = (
				4.0
				+ sin(elapsed * 18.0)
				* 2.0
			)

		Mode.FAILED:
			offset.x = (
				sin(elapsed * 12.0)
				* 2.0
			)

	return (
		bobber_position
		+ offset
	)


func _draw_line(
	start: Vector2,
	finish: Vector2
) -> void:

	draw_line(
		start,
		finish,
		Color(
			0.96,
			0.90,
			0.76,
			0.95
		),
		2.0,
		true
	)


func _draw_bobber(center: Vector2) -> void:
	var outline := Color("5b402d")

	var white := Color("f5ead2")

	var red := Color("d8583f")

	draw_line(
		center + Vector2(0, -12),
		center + Vector2(0, -3),
		outline,
		2.0,
		true
	)

	draw_circle(
		center,
		8.0,
		outline
	)

	draw_circle(
		center,
		6.2,
		white
	)

	draw_rect(
		Rect2(
			center + Vector2(-6, 0),
			Vector2(12, 6)
		),
		red,
		true
	)

	if mode == Mode.BITE:
		draw_circle(
			center,
			10.0
			+ sin(elapsed * 16.0)
			* 1.6,
			Color(
				1.0,
				0.78,
				0.20,
				0.32
			)
		)


# ==================================================
# WATER
# ==================================================

func _draw_waiting_ripple(
	center: Vector2
) -> void:

	var phase := fmod(
		elapsed * 18.0,
		14.0
	)

	draw_arc(
		center + Vector2(0, 4),
		10.0 + phase,
		0.15,
		PI - 0.15,
		24,
		Color(
			0.86,
			0.96,
			1.0,
			0.62
		),
		2.0,
		true
	)


func _draw_bite_ripples(
	center: Vector2
) -> void:

	for index in range(3):
		var radius := (
			12.0
			+ index * 10.0
			+ fmod(
				elapsed * 24.0,
				8.0
			)
		)

		draw_arc(
			center + Vector2(0, 4),
			radius,
			0.05,
			PI - 0.05,
			30,
			Color(
				0.95,
				0.99,
				1.0,
				0.95
			),
			3.0,
			true
		)


func _draw_caught_ripples(
	center: Vector2
) -> void:

	for index in range(2):
		var radius := (
			14.0
			+ index * 14.0
			+ elapsed * 8.0
		)

		draw_arc(
			center + Vector2(0, 5),
			radius,
			0.0,
			PI,
			28,
			Color(
				0.92,
				0.98,
				1.0,
				maxf(
					0.18,
					0.75
					- elapsed * 0.25
				)
			),
			2.4,
			true
		)


func _draw_failed_ripple(
	center: Vector2
) -> void:

	var radius := (
		10.0
		+ elapsed * 14.0
	)

	draw_arc(
		center + Vector2(0, 4),
		radius,
		0.0,
		PI,
		28,
		Color(
			0.8,
			0.9,
			0.95,
			maxf(
				0.1,
				0.65
				- elapsed * 0.3
			)
		),
		1.5,
		true
	)


# ==================================================
# CAUGHT FISH ANIMATION
# ==================================================

func _draw_catch_sequence(
	water_point: Vector2
) -> void:

	# cast_origin chính là vị trí gần tay nhân vật.
	var hand_point := (
		cast_origin
		+ Vector2(18, -9)
	)

	var caught_position: Vector2 = water_point.lerp(hand_point, 0.66)
	if is_instance_valid(caught_fish_sprite):
		caught_position = caught_fish_sprite.position
	_draw_line(cast_origin, caught_position)
	var jump_duration := 0.48

	if elapsed < jump_duration:
		var t := clampf(
			elapsed / jump_duration,
			0.0,
			1.0
		)

		var fish_position := (
			water_point.lerp(
				hand_point,
				t
			)
		)

		# Quỹ đạo cong khi cá nhảy lên.
		fish_position.y -= (
			sin(t * PI)
			* 48.0
		)

		_draw_splash(
			water_point,
			1.0 - t
		)

		# The exact caught-species art is drawn by CaughtFishSprite.

	else:
		# Sau khi bay tới người chơi,
		# cá đứng gần tay như đang được cầm lên.
		_draw_held_fish(caught_position)

		_draw_hold_sparkles(caught_position)

		_draw_success_glow(caught_position)


func _draw_moon_fish_catch_effect(center: Vector2) -> void:
	var pulse: float = 0.5 + sin(elapsed * 5.0) * 0.5
	draw_circle(center, 28.0 + pulse * 4.0, Color(0.53, 0.56, 1.0, 0.10))
	draw_arc(center + Vector2(-12.0, -13.0), 7.0, -1.1, 2.3, 16, Color(0.90, 0.90, 1.0, 0.92), 1.4, true)
	for index: int in range(3):
		var angle: float = elapsed * 1.8 + float(index) * TAU / 3.0
		var sparkle: Vector2 = center + Vector2(cos(angle), sin(angle * 1.3)) * (24.0 + pulse * 3.0)
		draw_line(sparkle + Vector2(-2.4, 0.0), sparkle + Vector2(2.4, 0.0), Color(0.93, 0.91, 1.0, 0.9), 1.2, true)
		draw_line(sparkle + Vector2(0.0, -2.4), sparkle + Vector2(0.0, 2.4), Color(0.93, 0.91, 1.0, 0.9), 1.2, true)


func _draw_splash(
	center: Vector2,
	alpha: float
) -> void:

	draw_arc(
		center + Vector2(0, 4),
		15.0,
		0.0,
		PI,
		28,
		Color(
			0.95,
			1.0,
			1.0,
			0.95 * alpha
		),
		3.0,
		true
	)

	draw_line(
		center + Vector2(-6, 0),
		center + Vector2(-12, -11),
		Color(
			0.94,
			0.99,
			1.0,
			0.75 * alpha
		),
		2.0,
		true
	)

	draw_line(
		center + Vector2(6, 0),
		center + Vector2(12, -11),
		Color(
			0.94,
			0.99,
			1.0,
			0.75 * alpha
		),
		2.0,
		true
	)


func _draw_held_fish(
	center: Vector2
) -> void:

	# Một điểm màu da nhỏ tạo cảm giác tay đang giữ cá.
	draw_circle(
		center + Vector2(-12, 3),
		3.2,
		Color("e3c09b")
	)


func _draw_success_glow(
	center: Vector2
) -> void:

	var glow_color := Color(
		1.0,
		0.93,
		0.55,
		0.24
	)

	draw_circle(
		center,
		16.0
		+ sin(elapsed * 8.0)
		* 1.5,
		glow_color
	)


func _draw_hold_sparkles(
	center: Vector2
) -> void:

	var sparkle := Color(
		1.0,
		0.93,
		0.60,
		0.95
	)

	var points := [
		Vector2(-20, -17),
		Vector2(17, -18),
		Vector2(4, -29)
	]

	for offset in points:
		var point: Vector2 = (
			center + offset
		)

		draw_line(
			point + Vector2(-3, 0),
			point + Vector2(3, 0),
			sparkle,
			1.5,
			true
		)

		draw_line(
			point + Vector2(0, -3),
			point + Vector2(0, 3),
			sparkle,
			1.5,
			true
		)


# ==================================================
# FISH DRAWING
# ==================================================

func _fish_color() -> Color:
	return Color("c79b68")


func _draw_fish(
	center: Vector2,
	angle: float,
	size_scale: float
) -> void:

	var body_color := _fish_color()

	var outline := Color("65462f")

	var body_points := [
		Vector2(-13, -8),
		Vector2(5, -8),
		Vector2(13, -3),
		Vector2(13, 3),
		Vector2(5, 8),
		Vector2(-13, 8)
	]

	var tail_points := [
		Vector2(13, 0),
		Vector2(24, -10),
		Vector2(24, 10)
	]

	var fin_points := [
		Vector2(-1, -2),
		Vector2(6, -8),
		Vector2(6, -1)
	]

	var body := _transform_points(
		body_points,
		center,
		angle,
		size_scale
	)

	var tail := _transform_points(
		tail_points,
		center,
		angle,
		size_scale
	)

	var fin := _transform_points(
		fin_points,
		center,
		angle,
		size_scale
	)

	draw_colored_polygon(
		body,
		body_color
	)

	draw_polyline(
		_closed(body),
		outline,
		2.0,
		true
	)

	draw_colored_polygon(
		tail,
		body_color
	)

	draw_polyline(
		_closed(tail),
		outline,
		2.0,
		true
	)

	draw_colored_polygon(
		fin,
		body_color.lightened(0.12)
	)

	draw_polyline(
		_closed(fin),
		outline,
		1.5,
		true
	)

	var eye_position := (
		_rotate_point(
			Vector2(-7, -1),
			angle
		)
		* size_scale
		+ center
	)

	draw_circle(
		eye_position,
		1.9 * size_scale,
		Color("3d2a20")
	)

	# Highlight mắt.
	draw_circle(
		eye_position
		+ Vector2(-0.5, -0.5),
		0.6 * size_scale,
		Color.WHITE
	)


func _transform_points(
	points: Array,
	center: Vector2,
	angle: float,
	size_scale: float
) -> PackedVector2Array:

	var result := PackedVector2Array()

	for value in points:
		var point: Vector2 = value

		point *= size_scale

		point = _rotate_point(
			point,
			angle
		)

		result.append(
			point + center
		)

	return result


func _closed(
	points: PackedVector2Array
) -> PackedVector2Array:

	var result := PackedVector2Array()

	for point in points:
		result.append(point)

	if points.size() > 0:
		result.append(
			points[0]
		)

	return result


func _rotate_point(
	point: Vector2,
	angle: float
) -> Vector2:

	return Vector2(
		point.x * cos(angle)
		- point.y * sin(angle),

		point.x * sin(angle)
		+ point.y * cos(angle)
	)
