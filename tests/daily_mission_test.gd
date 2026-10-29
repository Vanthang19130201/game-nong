extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	await process_frame
	var daily = root.get_node("DailyMissionManager")
	var inventory = root.get_node("Inventory")
	var clock = root.get_node("GameClock")
	clock.restore({"day": 1, "minutes": 360.0, "season": "spring", "absolute_day": 1})
	daily.reset_for_new_game()
	check(daily.daily_missions.size() == 3, "daily creates exactly three missions")
	var categories: Dictionary = {}
	for mission in daily.daily_missions:
		categories[mission["category"]] = true
	check(categories.size() == 3, "daily mission categories are different when pool permits")
	var mission: Dictionary = daily.daily_missions[0]
	daily.record_event(str(mission["event"]), int(mission["target"]))
	check(int(daily.daily_missions[0]["progress"]) == int(mission["target"]), "event progress caps at mission target")
	var coins_before: int = inventory.coins
	var reward := int(daily.daily_missions[0]["reward_coins"])
	check(daily.claim_mission(str(mission["id"])), "completed mission claims successfully")
	check(inventory.coins == coins_before + reward, "mission reward grants coins exactly once")
	check(not daily.claim_mission(str(mission["id"])) and inventory.coins == coins_before + reward, "mission reward cannot be claimed twice")
	var save_data: Dictionary = daily.get_save_data()
	daily.restore(save_data)
	check(bool(daily.daily_missions[0]["claimed"]), "save restore preserves claimed state")
	clock.restore({"day": 2, "minutes": 360.0, "season": "spring", "absolute_day": 2})
	daily.ensure_current_day()
	check(daily.daily_mission_day == 2 and not bool(daily.daily_missions[0]["claimed"]), "new game day resets missions without OS clock")
	if failures.is_empty():
		print("PASS: daily_missions")
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)
		return
	quit()
