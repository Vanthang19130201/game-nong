extends Node

signal changed(weather_id: String)

const WeatherData = preload("res://weather_data.gd")
var current_weather: String = "sunny"
var current_day_key: int = 0
var _restoring: bool = false

func _ready() -> void:
	current_day_key = WeatherData.day_key()
	GameClock.changed.connect(_on_clock_changed)

func is_raining() -> bool:
	return current_weather == "rain"

func fish_bonus() -> float:
	return 0.02 if is_raining() else 0.0

func get_save_data() -> Dictionary:
	return {"weather_id": current_weather, "day_key": current_day_key}

func restore(data: Variant) -> void:
	var day_key := WeatherData.day_key()
	var saved_weather := ""
	var saved_key := -1
	if data is Dictionary:
		saved_weather = str(data.get("weather_id", ""))
		saved_key = int(data.get("day_key", -1))
	if saved_key == day_key and WeatherData.WEATHER.has(saved_weather):
		current_day_key = day_key
		current_weather = saved_weather
	else:
		_roll_for_day(day_key)
	changed.emit(current_weather)

func reset() -> void:
	_roll_for_day(WeatherData.day_key())
	changed.emit(current_weather)

func _on_clock_changed() -> void:
	if _restoring:
		return
	var key := WeatherData.day_key()
	if key == current_day_key:
		return
	_roll_for_day(key)
	changed.emit(current_weather)
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()

func _roll_for_day(key: int) -> void:
	current_day_key = key
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57454154 + key * 7919
	var total := 0
	for data in WeatherData.WEATHER.values():
		total += int(data["weight"])
	var roll := rng.randi_range(1, total)
	for id in WeatherData.WEATHER:
		roll -= int(WeatherData.WEATHER[id]["weight"])
		if roll <= 0:
			current_weather = id
			return
	current_weather = "sunny"
