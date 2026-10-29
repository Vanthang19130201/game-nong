extends Node2D

# Presentation-only night lantern. It follows the existing Player node and
# reads GameClock directly, so it adds neither an item requirement nor a
# second time-of-day system.
const NIGHT_START_MINUTE := 18.0 * 60.0
const MORNING_END_MINUTE := 6.0 * 60.0

var active_at_night := false
var elapsed := 0.0


func _ready() -> void:
	z_index = -1
	GameClock.changed.connect(_refresh_for_time)
	_refresh_for_time()


func _process(delta: float) -> void:
	if not active_at_night:
		return
	elapsed = fposmod(elapsed + delta, 100000.0)
	queue_redraw()


func _refresh_for_time() -> void:
	var minute := fposmod(GameClock.minutes, 1440.0)
	active_at_night = minute >= NIGHT_START_MINUTE or minute < MORNING_END_MINUTE
	visible = active_at_night
	set_process(active_at_night)
	queue_redraw()


func _draw() -> void:
	if not active_at_night:
		return
	# A small warm pool of light, drawn without a map-sized light texture.
	var pulse := 0.92 + sin(elapsed * 2.4) * 0.05
	var center := Vector2(6.0, -10.0)
	for ring in range(5, 0, -1):
		var ratio := float(ring) / 5.0
		var color := Color(1.0, 0.77, 0.36, 0.045 + (1.0 - ratio) * 0.035)
		draw_circle(center, 42.0 * ratio * pulse, color)
	# A subtle hanging lantern near the hand/hip.
	draw_line(center + Vector2(0, -6), center + Vector2(0, -1), Color("6c4c2f"), 1.5, true)
	draw_rect(Rect2(center + Vector2(-3.5, -1), Vector2(7, 9)), Color("7d5735"), true)
	draw_rect(Rect2(center + Vector2(-2.0, 0.5), Vector2(4, 6)), Color(1.0, 0.79, 0.32, 0.92), true)
