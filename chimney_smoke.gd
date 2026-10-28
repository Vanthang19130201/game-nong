extends Node2D

# A tiny draw-only smoke loop for the house chimney.  It stays local to the
# House so it follows building movement and has no saved state.

var elapsed: float = 0.0


func _ready() -> void:
	position = Vector2(76, -91)
	z_index = 0


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 100000.0)
	queue_redraw()


func _draw() -> void:
	var rain_factor := 0.55 if WeatherManager.current_weather == "rain" else 1.0
	for index in range(4):
		var phase := fposmod(elapsed * 0.19 + float(index) * 0.24, 1.0)
		var point := Vector2(sin(elapsed * 0.7 + index) * (5.0 + phase * 9.0), -phase * 38.0)
		var radius := 3.0 + phase * 5.0
		var alpha := (1.0 - phase) * 0.16 * rain_factor
		draw_circle(point, radius, Color("e7e2d2", alpha))
