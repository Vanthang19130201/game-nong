extends Node

signal changed

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const DAYS_PER_SEASON: int = 28
@export var seconds_per_game_minute: float = 1.0
var day: int = 1
var minutes: float = 360.0
var season: String = "spring"
var gameplay_hud: Node
var gameplay_player: Node2D

func _process(delta: float) -> void:
	if is_gameplay_active():
		advance(delta)

func is_gameplay_active() -> bool:
	if get_tree().paused or SaveManager.resetting:
		return false
	if not is_instance_valid(gameplay_hud):
		gameplay_hud = get_tree().get_first_node_in_group("farm_hud")
	if not is_instance_valid(gameplay_player):
		gameplay_player = get_tree().get_first_node_in_group("farm_player")
	return gameplay_hud != null and gameplay_player != null and gameplay_player.is_inside_tree() and not gameplay_hud.blocks_world_input()

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var before: String = "%s:%d:%d" % [season, day, int(minutes)]
	minutes += seconds / maxf(0.01, seconds_per_game_minute)
	var days_passed: int = floori(minutes / 1440.0)
	minutes = fmod(minutes, 1440.0)
	var total_days: int = day - 1 + days_passed
	season = SEASONS[(SEASONS.find(season) + floori(total_days / float(DAYS_PER_SEASON))) % SEASONS.size()]
	day = total_days % DAYS_PER_SEASON + 1
	if before != "%s:%d:%d" % [season, day, int(minutes)]:
		changed.emit()

func get_save_data() -> Dictionary:
	return {"day":day, "minutes":minutes, "season":season}

func restore(data: Dictionary) -> void:
	var saved_day = data.get("day", 1)
	var saved_minutes = data.get("minutes", 360.0)
	var saved_season = data.get("season", "spring")
	day = saved_day if saved_day is int and saved_day >= 1 and saved_day <= DAYS_PER_SEASON else 1
	minutes = float(saved_minutes) if (saved_minutes is int or saved_minutes is float) and is_finite(saved_minutes) and saved_minutes >= 0 and saved_minutes < 1440 else 360.0
	season = saved_season if saved_season is String and saved_season in SEASONS else "spring"
	changed.emit()
