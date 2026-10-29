extends CanvasModulate

# Soft world-wide color changes. HUD controls are on a CanvasLayer and keep
# their original colors.
const NIGHT_COLOR := Color(0.72, 0.79, 0.93, 1.0)
const PRE_DAWN_COLOR := Color(0.78, 0.82, 0.93, 1.0)
const DAWN_COLOR := Color(1.0, 0.92, 0.80, 1.0)
const DAY_COLOR := Color(1.0, 0.99, 0.96, 1.0)
const GOLDEN_HOUR_COLOR := Color(1.0, 0.91, 0.78, 1.0)
const EVENING_COLOR := Color(0.93, 0.79, 0.78, 1.0)
const BLEND_SPEED: float = 2.0

var target_color: Color = Color.WHITE


func _ready() -> void:
	color = _color_for_time(GameClock.minutes)
	target_color = color
	GameClock.changed.connect(_on_clock_changed)


func _process(delta: float) -> void:
	if color.is_equal_approx(target_color):
		return
	color = color.lerp(target_color, clampf(delta * BLEND_SPEED, 0.0, 1.0))


func _on_clock_changed() -> void:
	target_color = _color_for_time(GameClock.minutes)


func _color_for_time(minutes: float) -> Color:
	var minute: float = fposmod(minutes, 1440.0)
	# The same single CanvasModulate owns every time-of-day world tint.
	# Key colors deliberately remain light enough for farming/fishing readability.
	if minute < 240.0:
		return NIGHT_COLOR
	if minute < 300.0:
		return NIGHT_COLOR.lerp(PRE_DAWN_COLOR, _smooth((minute - 240.0) / 60.0))
	if minute < 360.0:
		return PRE_DAWN_COLOR.lerp(DAWN_COLOR, _smooth((minute - 300.0) / 60.0))
	if minute < 450.0:
		return DAWN_COLOR.lerp(DAY_COLOR, _smooth((minute - 360.0) / 90.0))
	if minute < 930.0:
		return DAY_COLOR
	if minute < 1050.0:
		return DAY_COLOR.lerp(GOLDEN_HOUR_COLOR, _smooth((minute - 930.0) / 120.0))
	if minute < 1110.0:
		return GOLDEN_HOUR_COLOR.lerp(EVENING_COLOR, _smooth((minute - 1050.0) / 60.0))
	if minute < 1200.0:
		return EVENING_COLOR.lerp(NIGHT_COLOR, _smooth((minute - 1110.0) / 90.0))
	return NIGHT_COLOR


func _smooth(value: float) -> float:
	var amount: float = clampf(value, 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)
