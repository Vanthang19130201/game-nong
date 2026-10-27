extends CanvasModulate

# Soft world-wide color changes. HUD controls are on a CanvasLayer and keep
# their original colors.
const NIGHT_COLOR := Color(0.78, 0.83, 0.96, 1.0)
const DAWN_COLOR := Color(1.0, 0.93, 0.82, 1.0)
const DAY_COLOR := Color.WHITE
const EVENING_COLOR := Color(1.0, 0.86, 0.72, 1.0)
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
	var hour: float = fposmod(minutes / 60.0, 24.0)
	if hour < 4.0 or hour >= 20.0:
		return NIGHT_COLOR
	if hour < 5.0:
		return NIGHT_COLOR.lerp(DAWN_COLOR, _smooth(hour - 4.0))
	if hour < 7.0:
		return DAWN_COLOR.lerp(DAY_COLOR, _smooth((hour - 5.0) / 2.0))
	if hour < 17.0:
		return DAY_COLOR
	if hour < 18.5:
		return DAY_COLOR.lerp(EVENING_COLOR, _smooth((hour - 17.0) / 1.5))
	return EVENING_COLOR.lerp(NIGHT_COLOR, _smooth((hour - 18.5) / 1.5))


func _smooth(value: float) -> float:
	var amount: float = clampf(value, 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)
