extends Area2D

const Data = preload("res://fishing_data.gd")

enum State {
	IDLE,
	WAITING_FOR_BITE,
	BITE_WINDOW,
	SUCCESS,
	FAILED,
	COOLDOWN
}

const CATCH_DISPLAY_TIME: float = 1.8
const AUTO_RECAST_DELAY: float = 0.65

var state: State = State.IDLE
var deadline: float = 0.0
var bite_delay: float = 0.0
var bite_window: float = 1.0
var feedback: String = ""
var player: Node2D
var reserved_slot: bool = false
var last_caught_fish: String = ""
var fishing_visual: Node2D
var rng := RandomNumberGenerator.new()

@onready var label: Label = $Label
@onready var hud: Node = get_tree().get_first_node_in_group("farm_hud")


func _ready() -> void:
	add_to_group("farm_interactables")
	add_to_group("fishing_spots")
	rng.randomize()
	_setup_fishing_visual()
	Inventory.inventory_changed.connect(_on_inventory_changed)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func can_interact() -> bool:
	if state != State.IDLE or not Inventory.is_zone_unlocked("fishing"):
		return false

	for body in get_overlapping_bodies():
		if (
			body.is_in_group("farm_player")
			and body.global_position.distance_to(global_position) <= Data.SESSION_DISTANCE
		):
			return true

	return false


func interact(body: Node2D = null) -> void:
	start_session(body)


func start_session(body: Node2D = null) -> bool:
	if (
		not can_interact()
		or hud == null
		or hud.blocks_world_input()
		or is_instance_valid(hud.fishing_ui.active_spot)
	):
		return false

	if not Inventory.has_fishing_rod:
		return Inventory.fail(tr("FISHING_NEED_ROD"))

	player = body if body != null else get_tree().get_first_node_in_group("farm_player")

	if not is_instance_valid(player) or is_instance_valid(player.active_resource):
		return false

	if not _begin_cast():
		player = null
		return false

	hud.fishing_ui.show_session(self)
	return true


func _begin_cast() -> bool:
	if not _can_continue_session():
		return false

	if Inventory.fishing_attempts_remaining() <= 0:
		Inventory.fail("Đã hết lượt câu cá.")
		return false

	if not Inventory.reserve_fishing_slot():
		Inventory.fail(tr("FISHING_BARN_FULL"))
		return false

	reserved_slot = true

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
	deadline = now() + bite_delay
	feedback = "Đang câu cá...\nHãy kiên nhẫn, chờ cá cắn mồi."
	_set_visual_mode("WAITING")

	return true


func _process(_delta: float) -> void:
	if state in [State.WAITING_FOR_BITE, State.BITE_WINDOW]:
		if not _can_continue_session():
			cancel_session()
			return

	_update_fishing_visual()
	_advance_state()

	if state == State.IDLE:
		label.text = (
			tr("FISHING_SPOT_PROMPT")
			if can_interact()
			else tr("WORLD_FISHING_SPOT")
		)
	elif state == State.BITE_WINDOW:
		label.text = "!!! CÁ CẮN MỒI !!!"
	elif state == State.SUCCESS:
		label.text = "Câu thành công!"
	elif state == State.FAILED:
		label.text = "Cá đã chạy mất!"
	elif state == State.COOLDOWN:
		label.text = "Chuẩn bị thả câu..."
	else:
		label.text = feedback


func _can_continue_session() -> bool:
	return (
		is_instance_valid(player)
		and player.global_position.distance_to(global_position) <= Data.SESSION_DISTANCE
		and Inventory.is_zone_unlocked("fishing")
		and Inventory.has_fishing_rod
		and hud != null
		and not hud.blocks_world_input()
	)


func _advance_state() -> void:
	if state == State.IDLE or now() < deadline:
		return

	match state:
		State.WAITING_FOR_BITE:
			state = State.BITE_WINDOW
			deadline += bite_window
			feedback = "CÁ CẮN MỒI!\nNhấn SPACE ngay!"
			_set_visual_mode("BITE")

			if now() >= deadline:
				_fail(tr("FISHING_MISSED"))

		State.BITE_WINDOW:
			_fail(tr("FISHING_MISSED"))

		State.SUCCESS:
			state = State.COOLDOWN
			deadline = now() + AUTO_RECAST_DELAY

		State.FAILED:
			# Miss một lần thì kết thúc buổi câu.
			# Giữ thông báo thất bại đủ lâu để người chơi đọc,
			# sau đó trả về map thay vì tự động đốt lượt câu tiếp theo.
			cancel_session()

		State.COOLDOWN:
			# Chỉ câu thành công mới được tự động thả câu tiếp.
			_auto_recast()


func _auto_recast() -> void:
	if not _can_continue_session():
		cancel_session()
		return

	if Inventory.fishing_attempts_remaining() <= 0:
		cancel_session()
		Inventory.fail("Đã hết lượt câu cá.")
		return

	if not _begin_cast():
		cancel_session()


func reel() -> void:
	if state not in [State.WAITING_FOR_BITE, State.BITE_WINDOW]:
		return

	if not _can_continue_session():
		cancel_session()
		return

	_advance_state()

	if state == State.WAITING_FOR_BITE:
		_fail(tr("FISHING_TOO_EARLY"))
	elif state == State.BITE_WINDOW:
		_catch_fish()


func _catch_fish() -> void:
	# Chuyển state trước khi Inventory phát signal để một lần giật chỉ nhận một cá.
	state = State.SUCCESS

	var fish: String = _roll_fish()

	_release_slot()

	if not Inventory.can_add_item(fish, 1):
		_fail(tr("FISHING_BARN_FULL"))
		return

	last_caught_fish = fish
	_set_visual_mode("CAUGHT")

	feedback = (
		"Bạn đã câu được %s!"
		% Localization.display_name(Data.FISH[fish]["name"])
	)

	# Cho người chơi đủ thời gian nhìn thẻ khoe cá.
	deadline = now() + CATCH_DISPLAY_TIME

	Inventory.add_item(fish, 1)


func _roll_fish() -> String:
	var total: int = 0

	for fish_info in Data.FISH.values():
		total += fish_info["weight"]

	var roll: int = rng.randi_range(1, total)

	for fish in Data.FISH:
		roll -= Data.FISH[fish]["weight"]

		if roll <= 0:
			return fish

	return "small_fish"


func _fail(message: String) -> void:
	_release_slot()

	last_caught_fish = ""
	state = State.FAILED
	_set_visual_mode("FAILED")
	feedback = message + "\nBuổi câu đã kết thúc."
	deadline = now() + Data.RESULT_TIME


func _release_slot() -> void:
	if reserved_slot:
		Inventory.release_fishing_slot()
		reserved_slot = false


func cancel_session() -> void:
	_release_slot()

	state = State.IDLE
	deadline = 0.0
	feedback = ""
	last_caught_fish = ""
	_set_visual_mode("HIDDEN")
	player = null

	_clear_ui()


func _clear_ui() -> void:
	if (
		is_instance_valid(hud)
		and hud.fishing_ui.active_spot == self
	):
		hud.fishing_ui.clear_session()


func _on_inventory_changed() -> void:
	if SaveManager.resetting:
		cancel_session()
	elif (
		state in [State.WAITING_FOR_BITE, State.BITE_WINDOW]
		and not _can_continue_session()
	):
		cancel_session()


func _setup_fishing_visual() -> void:
	fishing_visual = Node2D.new()
	fishing_visual.name = "FishingVisual"
	fishing_visual.set_script(preload("res://fishing_visual.gd"))
	add_child(fishing_visual)


func _update_fishing_visual() -> void:
	if not is_instance_valid(fishing_visual):
		return

	if is_instance_valid(player):
		# Convert the player's body position into FishingSpot local space.
		# Slight upward offset makes the line look like it comes from the hands.
		var origin := to_local(player.global_position) + Vector2(0, -14)
		fishing_visual.set_cast_origin(origin)


func _set_visual_mode(mode_name: String) -> void:
	if not is_instance_valid(fishing_visual):
		return

	match mode_name:
		"WAITING":
			fishing_visual.set_mode(fishing_visual.Mode.WAITING)

		"BITE":
			fishing_visual.set_mode(fishing_visual.Mode.BITE)

		"CAUGHT":
			fishing_visual.set_mode(fishing_visual.Mode.CAUGHT)

		"FAILED":
			fishing_visual.set_mode(fishing_visual.Mode.FAILED)

		_:
			fishing_visual.set_mode(fishing_visual.Mode.HIDDEN)


func _exit_tree() -> void:
	_release_slot()
