extends Node

const DogData = preload("res://dog_data.gd")

signal missions_changed
signal mission_completed(mission: Dictionary)
signal reward_claimed(coins: int)
signal day_refreshed

const MAX_MISSIONS := 3
const COMPLETION_BONUS := 50

const TEMPLATES: Array[Dictionary] = [
	{"id":"plant_any", "category":"crop", "event":"crop_planted", "target_min":4, "target_max":6, "reward_min":20, "reward_max":30, "title_key":"DAILY_PLANT", "unlock":"always"},
	{"id":"harvest_any", "category":"harvest", "event":"crop_harvested", "target_min":4, "target_max":6, "reward_min":25, "reward_max":35, "title_key":"DAILY_HARVEST", "unlock":"always"},
	{"id":"sell_any", "category":"sell", "event":"item_sold", "target_min":3, "target_max":5, "reward_min":20, "reward_max":30, "title_key":"DAILY_SELL", "unlock":"always"},
	{"id":"fish_any", "category":"fishing", "event":"fish_caught", "target_min":1, "target_max":2, "reward_min":35, "reward_max":50, "title_key":"DAILY_FISH", "unlock":"fishing"},
	{"id":"order_any", "category":"orders", "event":"order_completed", "target_min":1, "target_max":1, "reward_min":45, "reward_max":55, "title_key":"DAILY_ORDER", "unlock":"orders"},
	{"id":"dog_feed", "category":"dog", "event":"dog_fed", "target_min":1, "target_max":1, "reward_min":25, "reward_max":35, "title_key":"DAILY_DOG_FEED", "unlock":"dog"},
	{"id":"dog_greet", "category":"dog_greet", "event":"dog_greeted", "target_min":1, "target_max":2, "reward_min":20, "reward_max":30, "title_key":"DAILY_DOG_GREET", "unlock":"dog"},
	{"id":"production_any", "category":"production", "event":"production_collected", "target_min":1, "target_max":2, "reward_min":30, "reward_max":45, "title_key":"DAILY_PRODUCTION", "unlock":"production"},
]

var daily_missions: Array[Dictionary] = []
var daily_mission_day := -1
var daily_completion_bonus_claimed := false


func _ready() -> void:
	GameClock.changed.connect(_on_clock_changed)
	Inventory.crop_planted.connect(func(_crop: String) -> void: record_event("crop_planted", 1))
	Inventory.crop_harvested.connect(func(_crop: String, amount: int) -> void: record_event("crop_harvested", amount))
	Inventory.item_sold.connect(func(_item: String, amount: int) -> void: record_event("item_sold", amount))
	SaveManager.dog_fed.connect(func(_pet_id: String) -> void: record_event("dog_fed", 1))
	SaveManager.dog_greeted.connect(func(_pet_id: String) -> void: record_event("dog_greeted", 1))
	OrderManager.order_completed.connect(func(_coins: int, _exp: int) -> void: record_event("order_completed", 1))
	call_deferred("ensure_current_day")


func get_save_data() -> Dictionary:
	return {
		"missions": daily_missions.duplicate(true),
		"day": daily_mission_day,
		"completion_bonus_claimed": daily_completion_bonus_claimed,
	}


func restore(data: Variant) -> void:
	var today := GameClock.absolute_day
	if data is Dictionary and int(data.get("day", -1)) == today and data.get("missions", []) is Array:
		daily_missions = _sanitize_missions(data.get("missions", []))
		daily_mission_day = today
		daily_completion_bonus_claimed = data.get("completion_bonus_claimed", false) == true
		if daily_missions.size() == MAX_MISSIONS:
			missions_changed.emit()
			return
	_generate_for_day(today)


func reset_for_new_game() -> void:
	daily_missions.clear()
	daily_mission_day = -1
	daily_completion_bonus_claimed = false
	ensure_current_day()


func ensure_current_day() -> void:
	if daily_mission_day != GameClock.absolute_day or daily_missions.size() != MAX_MISSIONS:
		_generate_for_day(GameClock.absolute_day)


func record_event(event_type: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	ensure_current_day()
	var changed := false
	for index in daily_missions.size():
		var mission := daily_missions[index]
		if str(mission.get("event", "")) != event_type or bool(mission.get("claimed", false)):
			continue
		var old_progress := int(mission.get("progress", 0))
		var target := int(mission.get("target", 1))
		mission["progress"] = mini(target, old_progress + amount)
		daily_missions[index] = mission
		changed = true
		if old_progress < target and int(mission["progress"]) >= target:
			mission_completed.emit(mission.duplicate(true))
	if changed:
		missions_changed.emit()
		SaveManager.save_game.call_deferred()


func claim_mission(mission_id: String) -> bool:
	ensure_current_day()
	for index in daily_missions.size():
		var mission := daily_missions[index]
		if str(mission.get("id", "")) != mission_id:
			continue
		if bool(mission.get("claimed", false)) or int(mission.get("progress", 0)) < int(mission.get("target", 1)):
			return false
		var reward := int(mission.get("reward_coins", 0))
		if reward <= 0 or Inventory.coins > 9223372036854775807 - reward:
			return false
		mission["claimed"] = true
		daily_missions[index] = mission
		Inventory.coins += reward
		if not SaveManager.save_game():
			Inventory.coins -= reward
			mission["claimed"] = false
			daily_missions[index] = mission
			return false
		Inventory.inventory_changed.emit()
		missions_changed.emit()
		reward_claimed.emit(reward)
		return true
	return false


func claim_completion_bonus() -> bool:
	if daily_completion_bonus_claimed or not daily_missions.all(func(m: Dictionary) -> bool: return int(m.get("progress", 0)) >= int(m.get("target", 1))):
		return false
	if Inventory.coins > 9223372036854775807 - COMPLETION_BONUS:
		return false
	daily_completion_bonus_claimed = true
	Inventory.coins += COMPLETION_BONUS
	if not SaveManager.save_game():
		Inventory.coins -= COMPLETION_BONUS
		daily_completion_bonus_claimed = false
		return false
	Inventory.inventory_changed.emit()
	missions_changed.emit()
	reward_claimed.emit(COMPLETION_BONUS)
	return true


func unclaimed_completed_count() -> int:
	var completed: int = 0
	for mission in daily_missions:
		if int(mission.get("progress", 0)) >= int(mission.get("target", 1)) and not bool(mission.get("claimed", false)):
			completed += 1
	return completed


func _on_clock_changed() -> void:
	if daily_mission_day != GameClock.absolute_day:
		_generate_for_day(GameClock.absolute_day)
		day_refreshed.emit()
		SaveManager.save_game.call_deferred()


func _generate_for_day(day_key: int) -> void:
	var pool: Array[Dictionary] = []
	for template in TEMPLATES:
		if _is_template_unlocked(str(template["unlock"])):
			pool.append(template)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4441494c + day_key * 7919
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap := pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = swap
	daily_missions.clear()
	var used_categories: Dictionary = {}
	for template in pool:
		if daily_missions.size() >= MAX_MISSIONS:
			break
		if used_categories.has(template["category"]):
			continue
		daily_missions.append(_mission_from_template(template, rng))
		used_categories[template["category"]] = true
	for template in TEMPLATES:
		if daily_missions.size() >= MAX_MISSIONS:
			break
		if _is_template_unlocked(str(template["unlock"])) and not daily_missions.any(func(m: Dictionary) -> bool: return m["id"] == template["id"]):
			daily_missions.append(_mission_from_template(template, rng))
	daily_mission_day = day_key
	daily_completion_bonus_claimed = false
	missions_changed.emit()


func _mission_from_template(template: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var target := rng.randi_range(int(template["target_min"]), int(template["target_max"]))
	var reward := rng.randi_range(int(template["reward_min"]), int(template["reward_max"]))
	return {"id":template["id"], "category":template["category"], "event":template["event"], "title_key":template["title_key"], "target":target, "progress":0, "reward_coins":reward, "claimed":false}


func _is_template_unlocked(rule: String) -> bool:
	match rule:
		"fishing": return Inventory.is_zone_unlocked("fishing")
		"orders": return Inventory.player_level >= 7
		"dog": return SaveManager.pet_dogs.keys().any(func(pet_id: String) -> bool: return DogData.is_pet_enabled(pet_id))
		"production": return Inventory.owns_feed_mill or Inventory.owns_chicken_coop or Inventory.owns_cow_shed or Inventory.owns_pig_pen or Inventory.owns_sheep_barn
		_: return true


func _sanitize_missions(raw: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for value in raw:
		if not value is Dictionary:
			continue
		var template: Dictionary = TEMPLATES.filter(func(item: Dictionary) -> bool: return item["id"] == str(value.get("id", ""))).front() if TEMPLATES.any(func(item: Dictionary) -> bool: return item["id"] == str(value.get("id", ""))) else {}
		if template.is_empty():
			continue
		var target := clampi(int(value.get("target", template["target_min"])), int(template["target_min"]), int(template["target_max"]))
		restored.append({"id":template["id"], "category":template["category"], "event":template["event"], "title_key":template["title_key"], "target":target, "progress":clampi(int(value.get("progress", 0)), 0, target), "reward_coins":clampi(int(value.get("reward_coins", template["reward_min"])), int(template["reward_min"]), int(template["reward_max"])), "claimed":value.get("claimed", false) == true})
	return restored
