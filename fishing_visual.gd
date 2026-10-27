extends Node2D

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

# The fishing dock in the current scene sits to the right of the river,
# so negative X points into the water.
@export var bobber_position: Vector2 = Vector2(-108, 12)


func _ready() -> void:
	z_index = 3
	visible = false
	set_process(false)


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return

	mode = new_mode
	elapsed = 0.0
	visible = mode != Mode.HIDDEN
	set_process(visible)
	queue_redraw()


func set_cast_origin(value: Vector2) -> void:
	cast_origin = value
	if visible:
		queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if mode == Mode.HIDDEN:
		return

	var bobber := _current_bobber_position()

	# Fishing line. Keep it thin so it does not cover the map.
	draw_line(
		cast_origin,
		bobber,
		Color(0.96, 0.90, 0.76, 0.95),
		2.0,
		true
	)

	_draw_ripples(bobber)
	_draw_bobber(bobber)


func _current_bobber_position() -> Vector2:
	var offset := Vector2.ZERO

	match mode:
		Mode.WAITING:
			offset.y = sin(elapsed * 3.0) * 1.2

		Mode.BITE:
			# Bobber dips quickly when the fish bites.
			offset.y = 4.0 + sin(elapsed * 18.0) * 2.0

		Mode.CAUGHT:
			# Pull the bobber up a little while the catch card is shown.
			offset.y = -minf(elapsed * 18.0, 12.0)

		Mode.FAILED:
			offset.x = sin(elapsed * 12.0) * 2.0

	return bobber_position + offset


func _draw_bobber(center: Vector2) -> void:
	var outline := Color("5b402d")
	var white := Color("f5ead2")
	var red := Color("d8583f")

	# Stem.
	draw_line(
		center + Vector2(0, -10),
		center + Vector2(0, -3),
		outline,
		2.0,
		true
	)

	# Round bobber with dark outline.
	draw_circle(center, 8.0, outline)
	draw_circle(center, 6.2, white)

	# Red lower half, approximated by a small rectangle.
	draw_rect(
		Rect2(center + Vector2(-6, 0), Vector2(12, 6)),
		red,
		true
	)

	if mode == Mode.BITE:
		draw_circle(
			center,
			9.0 + sin(elapsed * 16.0) * 1.5,
			Color(1.0, 0.78, 0.20, 0.32)
		)


func _draw_ripples(center: Vector2) -> void:
	var ripple_color := Color(0.86, 0.96, 1.0, 0.72)

	match mode:
		Mode.WAITING:
			var phase := fmod(elapsed * 18.0, 14.0)
			draw_arc(
				center + Vector2(0, 4),
				10.0 + phase,
				0.15,
				PI - 0.15,
				24,
				Color(ripple_color, 0.62),
				2.0,
				true
			)

		Mode.BITE:
			for index in range(3):
				var radius := 12.0 + index * 10.0 + fmod(elapsed * 24.0, 8.0)
				draw_arc(
					center + Vector2(0, 4),
					radius,
					0.05,
					PI - 0.05,
					30,
					Color(0.95, 0.99, 1.0, 0.95),
					3.0,
					true
				)

		Mode.CAUGHT:
			for index in range(2):
				var radius := 15.0 + index * 13.0 + elapsed * 8.0
				draw_arc(
					center + Vector2(0, 4),
					radius,
					0.0,
					PI,
					28,
					Color(0.92, 0.98, 1.0, maxf(0.15, 0.75 - elapsed * 0.25)),
					2.0,
					true
				)

		Mode.FAILED:
			var radius := 10.0 + elapsed * 14.0
			draw_arc(
				center + Vector2(0, 4),
				radius,
				0.0,
				PI,
				28,
				Color(0.8, 0.9, 0.95, maxf(0.1, 0.65 - elapsed * 0.3)),
				1.5,
				true
			)
