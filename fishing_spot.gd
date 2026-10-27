extends Area2D

const Data = preload(
	"res://fishing_data.gd"
)

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
const MAX_CAST_DISTANCE: float = 150.0

var state: State = State.IDLE

var deadline: float = 0.0
var bite_delay: float = 0.0
var bite_window: float = 1.0

var feedback: String = ""

var player: Node2D

var reserved_slot: bool = false

var last_caught_fish: String = ""

var session_cast_world_position: Vector2 = (
	Vector2.ZERO
)

var session_player_origin: Vector2 = (
	Vector2.ZERO
)

var session_water_id: String = ""

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
# OLD FIXED SPOT DISABLED
# ==================================================

func can_interact() -> bool:
	return false


func interact(
	_body: Node2D = null
) -> void:
	pass


# ==================================================
# FREE FISHING
# ==================================================

func start_free_session(
	body: Node2D,
	cast_world_position: Vector2,
	water_id: String
) -> bool:

	if state != State.IDLE:
		return false

	if not is_instance_valid(body):
		return false

	if hud == null:
		return false

	if is_instance_valid(
		hud.fishing_ui.active_spot
	):
		return false

	if not Inventory.is_zone_unlocked(
		"fishing"
	):
		return false

	if not Inventory.has_fishing_rod:
		return Inventory.fail(
			tr("FISHING_NEED_ROD")
		)

	player = body

	session_cast_world_position = (
		cast_world_position
	)

	session_player_origin = (
		player.global_position
	)

	session_water_id = water_id

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


# ==================================================
# CAST
# ==================================================

func _begin_cast() -> bool:
	if not _can_continue_session():
		return false

	if (
		Inventory.fishing_attempts_remaining()
		<= 0
	):
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

	var fish: String = (
		_roll_fish()
	)

	_release_slot()

	if not Inventory.can_add_item(
		fish,
		1
	):
		_fail(
			tr("FISHING_BARN_FULL")
		)
		return

	last_caught_fish = fish

	_set_visual_mode(
		"CAUGHT"
	)

	feedback = (
		"Bạn đã câu được %s!"
		% Localization.display_name(
			Data.FISH[fish]["name"]
		)
	)

	deadline = (
		now()
		+ CATCH_DISPLAY_TIME
	)

	Inventory.add_item(
		fish,
		1
	)


func _roll_fish() -> String:
	var total: int = 0

	for fish_info in Data.FISH.values():
		total += fish_info[
			"weight"
		]

	var roll: int = rng.randi_range(
		1,
		total
	)

	for fish in Data.FISH:
		roll -= Data.FISH[
			fish
		]["weight"]

		if roll <= 0:
			return fish

	return "small_fish"


# ==================================================
# FAIL
# ==================================================

func _fail(
	message: String
) -> void:

	_release_slot()

	last_caught_fish = ""

	state = State.FAILED

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

	if (
		Inventory.fishing_attempts_remaining()
		<= 0
	):
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
	var origin := (
		to_local(
			player.global_position
		)
		+ Vector2(0, -14)
	)

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
