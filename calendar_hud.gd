extends PanelContainer

# Weather is presentation data until the farm has a real weather system.
@export var weather_name_key: String = "WEATHER_SUNNY"

func _ready() -> void:
	GameClock.changed.connect(refresh)
	get_viewport().size_changed.connect(_fit)
	refresh()
	_fit.call_deferred()

func refresh() -> void:
	$Content/Date/Day.text = tr("CALENDAR_DAY") % GameClock.day
	$Content/Date/Season.text = tr("SEASON_" + GameClock.season.to_upper())
	$Content/Time/Hour.text = "%02d:%02d" % [floori(GameClock.minutes / 60.0), int(GameClock.minutes) % 60]
	$Content/Time/Weather.text = tr(weather_name_key)

func _fit() -> void:
	size = Vector2(204,88)
	var view: Vector2 = get_viewport_rect().size
	position = Vector2(view.x-size.x-72,12)
	if view.x < 660:
		position = Vector2(view.x-size.x-12,get_parent().get_node("StatsBackdrop").get_rect().end.y+12)
