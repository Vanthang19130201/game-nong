extends Area2D

const Data = preload(
	"res://fishing_data.gd"
)
const TreasureData = preload("res://treasure_data.gd")

enum State {
	IDLE,
	WAITING_FOR_BITE,
	BITE_WINDOW,
	SUCCESS,
	FAILED,
	COOLDOWN
}

const CATCH_DISPLAY_TIME: float = 2.2
const AUTO_RECAST_DELAY: float = 0.65
const MAX_CAST_DISTANCE: float = 170.0

var state: State = State.IDLE

var deadline: float = 0.0
var bite_delay: float = 0.0
var bite_window: float = 1.0

var feedback: String = ""

var player: Node2D

var reserved_slot: bool = false

# A catch that could not enter the Barn remains claimable. Ordinary misses and
# cancellations never create a reward, preserving fishing's normal risk while
# preventing storage failures from deleting rare loot.
var retain_pending_reward: bool = false

var last_caught_fish: String = ""

var session_cast_world_position: Vector2 = (
	Vector2.ZERO
)

var session_player_origin: Vector2 = (
	Vector2.ZERO
)

var session_water_id: String = ""
var session_facing_direction: Vector2 = Vector2.DOWN

var fishing_visual: Node2D

var rng := RandomNumberGenerator.new()

@onready var label: Label = $Label

@onready var hud: Node = (
	get_tree()
	.get_first_node_in_group(
		"farm_hud"
	)
)


func _ready() -> void:
	# FishingSpot giờ là bộ điều khiển
	# cho toàn bộ phiên câu cá.
	add_to_group(
		"fishing_session_manager"
	)

	# Giữ group cũ để FishingUI không lỗi.
	add_to_group(
		"fishing_spots"
	)

	rng.randomize()

	_setup_fishing_visual()

	# Không còn dùng prompt cố định ở dock.
	label.hide()

	Inventory.inventory_changed.connect(
		_on_inventory_changed
	)


func now() -> float:
	return (
		Time.get_ticks_msec()
		/ 1000.0
	)


# ==================================================
# FREE CAST CONTROLLER
# ==================================================

func can_interact() -> bool:
	var farm_player := get_tree().get_first_node_in_group(
		"farm_player"
	)
	return (
		is_instance_valid(farm_player)
		and farm_player.has_method("can_start_free_fishing")
		and farm_player.can_start_free_fishing()
	)


func interact(
	_body: Node2D = null
) -> void:
	var farm_player := _body
	if not is_instance_valid(farm_player):
		farm_player = get_tree().get_first_node_in_group(
			"farm_player"
		)
	if (
		is_instance_valid(farm_player)
		and farm_player.has_method("request_fishing_cast")
	):
		farm_player.request_fishing_cast()


# ==================================================
# FREE FISHING
# ==================================================

func start_free_session(
	body: Node2D,
	cast_world_position: Vector2,
	water_id: String
) -> bool:

	if state != State.IDLE:
		return Inventory.fail("Phiên câu cá hiện tại chưa kết thúc.")

	if not is_instance_valid(body):
		return Inventory.fail("Không tìm thấy người chơi để bắt đầu câu.")

	if hud == null:
		return Inventory.fail("Không tìm thấy giao diện câu cá.")

	if is_instance_valid(
		hud.fishing_ui.active_spot
	):
		return Inventory.fail("Bạn đang ở trong một phiên câu cá.")

	if not Inventory.is_zone_unlocked(
		"fishing"
	):
		return Inventory.fail(tr("FISHING_UNLOCK_LEVEL_10"))

	if not Inventory.has_fishing_rod:
		return Inventory.fail(
			tr("FISHING_NEED_ROD")
		)

	if not _valid_cast_target(
		body,
		cast_world_position,
		water_id
	):
		return Inventory.fail(
			"Không có vùng nước câu hợp lệ phía trước."
		)

	player = body

	session_cast_world_position = (
		cast_world_position
	)

	session_player_origin = (
		player.global_position
	)

	session_water_id = water_id
	var facing_value: Variant = body.get("facing_vector")
	session_facing_direction = (
		facing_value.normalized()
		if facing_value is Vector2
		else Vector2.DOWN
	)

	if player.has_method(
		"begin_fishing_pose"
	):
		player.begin_fishing_pose()

	if not _begin_cast():
		_end_player_pose()

		player = null

		return false

	hud.fishing_ui.show_session(
		self
	)

	return true


func _valid_cast_target(
	body: Node2D,
	cast_world_position: Vector2,
	water_id: String
) -> bool:
	if water_id.is_empty() or body.global_position.distance_to(
		cast_world_position
	) > MAX_CAST_DISTANCE:
		return false

	var cast_direction := (
		cast_world_position - body.global_position
	).normalized()
	var facing_value: Variant = body.get("facing_vector")
	var direction: Vector2 = (
		facing_value.normalized()
		if facing_value is Vector2
		else cast_direction
	)
	if direction.dot(
		cast_direction
	) < 0.7:
		return false

	for zone in get_tree().get_nodes_in_group("fishing_water_zones"):
		if (
			is_instance_valid(zone)
			and zone.water_id == water_id
			and zone.contains_world_point(cast_world_position)
			and not zone.contains_world_point(body.global_position)
		):
			return true

	return false


# ==================================================
# CAST
# ==================================================

func _begin_cast() -> bool:
	if not _can_continue_session():
		return false

	# Only a catch that has actually succeeded can have a persistent result.
	# A reward retained because the Barn was full can be retried after a reload
	# without consuming a second attempt or rolling a different result.
	var has_pending_reward := SaveManager.has_pending_fishing_reward()
	if not has_pending_reward and Inventory.fishing_attempts_remaining() <= 0:
		Inventory.fail(
			"Đã hết lượt câu cá."
		)

		return false

	if not Inventory.reserve_fishing_slot():
		Inventory.fail(
			tr("FISHING_BARN_FULL")
		)

		return false

	reserved_slot = true
	# A previously caught-but-undelivered result must survive any retry until it
	# can safely enter storage. Fresh casts deliberately do not reserve or save
	# a reward here: misses and cancellations must never create one.
	retain_pending_reward = has_pending_reward

	if not has_pending_reward:
		if not Inventory.consume_fishing_attempt():
			_release_slot()
			return false

	last_caught_fish = ""

	bite_delay = rng.randf_range(
		Data.MIN_BITE_DELAY,
		Data.MAX_BITE_DELAY
	)

	bite_window = Data.ROD_LEVELS[
		clampi(
			Inventory.fishing_rod_level,
			1,
			Data.ROD_LEVELS.size()
		)
	]["bite_window"]

	state = State.WAITING_FOR_BITE

	deadline = (
		now()
		+ bite_delay
	)

	feedback = (
		"Đang câu cá...\n"
		+ "Hãy kiên nhẫn, chờ cá cắn mồi."
	)

	_set_visual_mode(
		"WAITING"
	)
	AudioManager.play_sfx("fishing_cast", session_player_origin)
	get_tree().create_timer(0.22).timeout.connect(func() -> void:
		if state == State.WAITING_FOR_BITE:
			AudioManager.play_sfx("fishing_splash", session_cast_world_position)
	)

	return true


# ==================================================
# PROCESS
# ==================================================

func _process(
	_delta: float
) -> void:

	if state in [
		State.WAITING_FOR_BITE,
		State.BITE_WINDOW
	]:
		if not _can_continue_session():
			cancel_session()
			return

	_update_fishing_visual()

	_advance_state()


func _can_continue_session() -> bool:
	if not is_instance_valid(player):
		return false

	if not Inventory.is_zone_unlocked(
		"fishing"
	):
		return false

	if not Inventory.has_fishing_rod:
		return false

	if hud == null:
		return false

	if (
		player.global_position.distance_to(
			session_player_origin
		)
		> 20.0
	):
		return false

	if (
		player.global_position.distance_to(
			session_cast_world_position
		)
		> MAX_CAST_DISTANCE
	):
		return false

	return true


func _advance_state() -> void:
	if state == State.IDLE:
		return

	if now() < deadline:
		return

	match state:
		State.WAITING_FOR_BITE:
			state = State.BITE_WINDOW

			deadline += bite_window

			feedback = (
				"CÁ CẮN MỒI!\n"
				+ "Nhấn SPACE ngay!"
			)

			_set_visual_mode(
				"BITE"
			)
			AudioManager.play_sfx("fishing_bite", session_cast_world_position)

			if now() >= deadline:
				_fail(
					tr("FISHING_MISSED")
				)

		State.BITE_WINDOW:
			_fail(
				tr("FISHING_MISSED")
			)

		State.SUCCESS:
			state = State.COOLDOWN

			deadline = (
				now()
				+ AUTO_RECAST_DELAY
			)

		State.FAILED:
			# Miss một lần là kết thúc.
			cancel_session()

		State.COOLDOWN:
			_auto_recast()


# ==================================================
# REEL
# ==================================================

func reel() -> void:
	if state not in [
		State.WAITING_FOR_BITE,
		State.BITE_WINDOW
	]:
		return

	if not _can_continue_session():
		cancel_session()
		return

	_advance_state()

	if state == State.WAITING_FOR_BITE:
		_fail(
			tr("FISHING_TOO_EARLY")
		)

	elif state == State.BITE_WINDOW:
		_catch_fish()


# ==================================================
# CATCH
# ==================================================

func _catch_fish() -> void:
	state = State.SUCCESS

	_release_slot()

	var is_retrying_pending_reward := SaveManager.has_pending_fishing_reward()
	var reward := SaveManager.get_pending_fishing_reward() if is_retrying_pending_reward else {}
	# A reward is rolled only after the player has reeled during the bite window.
	# It stays transient when the Barn has room; persistence is needed solely for
	# a completed catch that cannot currently be delivered.
	if not is_retrying_pending_reward:
		reward = _roll_success_reward()
	var fish := str(reward.get("item", ""))
	var amount := int(reward.get("amount", 0))
	if fish.is_empty() or amount != 1:
		_fail(tr("ERROR_FISH_SAVE"), is_retrying_pending_reward)
		return
	if not Inventory.can_add_item(fish, amount):
		if not is_retrying_pending_reward:
			if not _persist_full_barn_reward(reward):
				_fail(tr("ERROR_FISH_SAVE"))
				return
			retain_pending_reward = true
		_fail(
			tr("FISHING_BARN_FULL"),
			true
		)
		return
	var granted := false
	if is_retrying_pending_reward:
		granted = _claim_pending_fishing_reward(reward)
	else:
		granted = _grant_direct_fishing_reward(reward)
	if not granted:
		_fail(tr("ERROR_FISH_SAVE"), is_retrying_pending_reward)
		return
	retain_pending_reward = false

	last_caught_fish = fish
	DailyMissionManager.record_event("fish_caught", amount)
	if is_instance_valid(fishing_visual):
		fishing_visual.set_caught_fish(fish)

	_set_visual_mode(
		"CAUGHT"
	)

	feedback = tr("FISHING_CAUGHT") % Localization.display_name(fish)

	deadline = (
		now()
		+ CATCH_DISPLAY_TIME
	)

	AudioManager.play_sfx("treasure_found" if TreasureData.ITEMS.has(fish) else "fish_caught", session_cast_world_position)


func _roll_success_reward() -> Dictionary:
	# This is intentionally called only from `_catch_fish()` after a successful
	# reel. The token makes a full-Barn result reproducible once it must be saved.
	var token: int = rng.randi_range(1, 2147483647)
	var item_id := _resolve_fishing_reward(token)
	if item_id.is_empty() or item_id not in Inventory.BARN_ITEMS:
		return {}
	return {"item": item_id, "amount": 1, "token": token}


func _resolve_fishing_reward(token: int) -> String:
	# TreasureData.roll contains the shared rare-container/Gem branch. A local
	# seeded RNG makes the result reproducible from the persisted token as well
	# as from the persisted item value.
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = token
	var treasure_bonus: float = 0.02 if FarmEventManager.is_active("fishing_day") else 0.0
	var treasure: String = TreasureData.roll(
		reward_rng,
		WeatherManager.fish_bonus(),
		treasure_bonus
	)
	return treasure if not treasure.is_empty() else _roll_fish(reward_rng)


func _claim_pending_fishing_reward(reward: Dictionary) -> bool:
	var item_id := str(reward.get("item", ""))
	var amount := int(reward.get("amount", 0))
	if item_id.is_empty() or amount != 1 or not Inventory.can_add_item(item_id, amount):
		return false
	var old_item_count: int = Inventory.get(item_id)
	var old_discovery: Dictionary = DiscoveryManager.get_save_data()
	if not Inventory.add_item(item_id, amount, false):
		return false
	SaveManager.clear_pending_fishing_reward()
	if not SaveManager.save_game():
		Inventory.set(item_id, old_item_count)
		DiscoveryManager.restore(old_discovery)
		SaveManager.set_pending_fishing_reward(reward)
		return false
	Inventory.inventory_changed.emit()
	return true


func _grant_direct_fishing_reward(reward: Dictionary) -> bool:
	var item_id := str(reward.get("item", ""))
	var amount := int(reward.get("amount", 0))
	if item_id.is_empty() or amount != 1 or not Inventory.can_add_item(item_id, amount):
		return false
	var old_item_count: int = Inventory.get(item_id)
	var old_discovery: Dictionary = DiscoveryManager.get_save_data()
	if not Inventory.add_item(item_id, amount, false):
		return false
	# The result was not pending, so saving the inventory is enough. Roll back
	# the in-memory side effects if the snapshot cannot be committed.
	if not SaveManager.save_game():
		Inventory.set(item_id, old_item_count)
		DiscoveryManager.restore(old_discovery)
		return false
	Inventory.inventory_changed.emit()
	return true


func _persist_full_barn_reward(reward: Dictionary) -> bool:
	# This is the only point at which a newly caught reward becomes persistent:
	# the catch succeeded, but storage rejected delivery. Save before reporting
	# the full-Barn feedback so restarting cannot reroll or delete rare loot.
	if not SaveManager.set_pending_fishing_reward(reward):
		return false
	if SaveManager.save_game():
		return true
	SaveManager.clear_pending_fishing_reward()
	return false


func _roll_fish(roll_rng: RandomNumberGenerator = null) -> String:
	# Preserve the existing no-argument helper for fishing tests and any scene
	# callers, while deterministic pending rewards pass their persisted RNG.
	var active_rng: RandomNumberGenerator = roll_rng if roll_rng != null else rng
	var available: Array[String] = []
	var weights: Array[int] = []
	var total: int = 0
	for fish_id in Data.CATCHABLE_FISH_IDS:
		var info: Dictionary = Data.FISH[fish_id]
		var weight: int = int(info["weight"])
		available.append(fish_id)
		weights.append(weight)
		total += weight
	if total <= 0:
		return "tilapia"

	var roll: int = active_rng.randi_range(
		1,
		total
	)

	for index in range(available.size()):
		roll -= weights[index]

		if roll <= 0:
			return available[index]

	return "tilapia"


func _fish_is_available(info: Dictionary) -> bool:
	var weather_list: Variant = info.get("weather", [])
	if weather_list is Array and not weather_list.is_empty() and WeatherManager.current_weather not in weather_list:
		return false
	if info.has("time_start") and info.has("time_end"):
		var hour := GameClock.minutes / 60.0
		var start := float(info["time_start"])
		var finish := float(info["time_end"])
		if start > finish:
			return hour >= start or hour < finish
		return hour >= start and hour < finish
	return true


# ==================================================
# FAIL
# ==================================================

func _fail(
	message: String,
	keep_pending: bool = false
) -> void:

	_release_slot()
	# Once a result was retained because the Barn was full, a retry must not
	# accidentally destroy it merely because the player misses that retry.
	var should_keep_pending := keep_pending or retain_pending_reward
	retain_pending_reward = should_keep_pending and SaveManager.has_pending_fishing_reward()

	last_caught_fish = ""

	state = State.FAILED
	AudioManager.play_sfx("fishing_fail", session_cast_world_position)

	_set_visual_mode(
		"FAILED"
	)

	feedback = (
		message
		+ "\nBuổi câu đã kết thúc."
	)

	deadline = (
		now()
		+ Data.RESULT_TIME
	)


# ==================================================
# CONTINUE AFTER SUCCESS
# ==================================================

func _auto_recast() -> void:
	if not _can_continue_session():
		cancel_session()
		return

	if not SaveManager.has_pending_fishing_reward() and Inventory.fishing_attempts_remaining() <= 0:
		cancel_session()

		Inventory.fail(
			"Đã hết lượt câu cá."
		)

		return

	if not _begin_cast():
		cancel_session()


# ==================================================
# CAMERA TARGET
# ==================================================

func get_camera_focus_position() -> Vector2:
	if not is_instance_valid(player):
		return session_cast_world_position

	return (
		player.global_position
		+ session_cast_world_position
	) * 0.5


# ==================================================
# VISUAL
# ==================================================

func _setup_fishing_visual() -> void:
	fishing_visual = Node2D.new()

	fishing_visual.name = (
		"FishingVisual"
	)

	fishing_visual.set_script(
		preload(
			"res://fishing_visual.gd"
		)
	)

	add_child(
		fishing_visual
	)


func _update_fishing_visual() -> void:
	if not is_instance_valid(
		fishing_visual
	):
		return

	if not is_instance_valid(player):
		return

	# Dây xuất phát gần tay Player.
	var hand_world_position: Vector2 = (
		player.get_rod_tip_world_position()
		if player.has_method("get_rod_tip_world_position")
		else player.global_position + Vector2(0, -10) + session_facing_direction * 8.0
	)
	var origin := to_local(hand_world_position)

	fishing_visual.set_cast_origin(
		origin
	)

	# Phao xuất hiện đúng vị trí Player
	# đang hướng vào nước.
	fishing_visual.bobber_position = (
		to_local(
			session_cast_world_position
		)
	)


func _set_visual_mode(
	mode_name: String
) -> void:

	if not is_instance_valid(
		fishing_visual
	):
		return

	match mode_name:
		"WAITING":
			fishing_visual.set_mode(
				fishing_visual.Mode.WAITING
			)

		"BITE":
			fishing_visual.set_mode(
				fishing_visual.Mode.BITE
			)

		"CAUGHT":
			fishing_visual.set_mode(
				fishing_visual.Mode.CAUGHT
			)

		"FAILED":
			fishing_visual.set_mode(
				fishing_visual.Mode.FAILED
			)

		_:
			fishing_visual.set_mode(
				fishing_visual.Mode.HIDDEN
			)


# ==================================================
# CLEANUP
# ==================================================

func _release_slot() -> void:
	if not reserved_slot:
		return

	Inventory.release_fishing_slot()

	reserved_slot = false


func _end_player_pose() -> void:
	if (
		is_instance_valid(player)
		and player.has_method(
			"end_fishing_pose"
		)
	):
		player.end_fishing_pose()


func cancel_session() -> void:
	_release_slot()

	_end_player_pose()

	state = State.IDLE

	deadline = 0.0

	feedback = ""

	last_caught_fish = ""
	retain_pending_reward = false

	session_cast_world_position = (
		Vector2.ZERO
	)

	session_player_origin = (
		Vector2.ZERO
	)

	session_water_id = ""

	_set_visual_mode(
		"HIDDEN"
	)

	player = null

	_clear_ui()


func _clear_ui() -> void:
	if not is_instance_valid(hud):
		return

	if (
		hud.fishing_ui.active_spot
		== self
	):
		hud.fishing_ui.clear_session()


func _on_inventory_changed() -> void:
	if SaveManager.resetting:
		cancel_session()


func _exit_tree() -> void:
	_release_slot()
