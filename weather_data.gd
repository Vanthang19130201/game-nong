extends RefCounted

const WEATHER: Dictionary = {
	"sunny": {"name_key": "WEATHER_SUNNY", "icon": "res://assets/ui/weather_sun.svg", "weight": 50},
	"cloudy": {"name_key": "WEATHER_CLOUDY", "icon": "res://assets/environment/weather_cloud.svg", "weight": 30},
	"rain": {"name_key": "WEATHER_RAIN", "icon": "res://assets/environment/weather_rain.svg", "weight": 20}
}

static func day_key() -> int:
	return GameClock.absolute_day
