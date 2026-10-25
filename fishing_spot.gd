extends Area2D

const Data = preload("res://fishing_data.gd")
enum State { IDLE, WAITING_FOR_BITE, BITE_WINDOW, SUCCESS, FAILED, COOLDOWN }

var state: State = State.IDLE
var deadline: float = 0.0
var bite_delay: float = 0.0
var bite_window: float = 1.0
var feedback: String = ""
var player: Node2D
var reserved_slot: bool = false
var rng := RandomNumberGenerator.new()
@onready var label: Label = $Label
@onready var hud: Node = get_tree().get_first_node_in_group("farm_hud")


func _ready() -> void:
	add_to_group("farm_interactables")
	add_to_group("fishing_spots")
	rng.randomize()
	Inventory.inventory_changed.connect(_on_inventory_changed)


func now() -> float:
	# A reaction session is transient: monotonic time ignores changes to system clock.
	return Time.get_ticks_msec() / 1000.0


func can_interact() -> bool:
	if state != State.IDLE or not Inventory.is_zone_unlocked("fishing"):
		return false
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player") and body.global_position.distance_to(global_position) <= Data.SESSION_DISTANCE:
			return true
	return false


func interact(body: Node2D = null) -> void:
	start_session(body)


func start_session(body: Node2D = null) -> bool:
	if not can_interact() or hud == null or hud.blocks_world_input() or is_instance_valid(hud.fishing_ui.active_spot):
		return false
	if not Inventory.has_fishing_rod:
		return Inventory.fail("You need a Fishing Rod.")
	player = body if body != null else get_tree().get_first_node_in_group("farm_player")
	if not is_instance_valid(player) or is_instance_valid(player.active_resource):
		return false
	if not Inventory.reserve_fishing_slot():
		return Inventory.fail("Barn is full.")
	reserved_slot = true
	bite_delay = rng.randf_range(Data.MIN_BITE_DELAY, Data.MAX_BITE_DELAY)
	# Snapshot rod level once, so upgrading mid-session cannot change the deadline.
	bite_window = Data.ROD_LEVELS[clampi(Inventory.fishing_rod_level, 1, Data.ROD_LEVELS.size())]["bite_window"]
	state = State.WAITING_FOR_BITE
	deadline = now() + bite_delay
	feedback = "Fishing...\nWaiting for a bite..."
	hud.fishing_ui.show_session(self)
	return true


func _process(_delta: float) -> void:
	if state in [State.WAITING_FOR_BITE, State.BITE_WINDOW]:
		if not _session_valid():
			cancel_session()
			return
	_advance_state()
	if state == State.IDLE:
		label.text = "FISHING SPOT\n[E] / Fish" if Inventory.is_zone_unlocked("fishing") else "FISHING SPOT\nLevel 10"
	elif state == State.BITE_WINDOW:
		label.text = "!!! FISH BITE !!!\nPRESS E / REEL!"
	else:
		label.text = feedback


func _session_valid() -> bool:
	return is_instance_valid(player) and player.global_position.distance_to(global_position) <= Data.SESSION_DISTANCE and Inventory.is_zone_unlocked("fishing") and Inventory.has_fishing_rod and hud != null and not hud.blocks_world_input()


func _advance_state() -> void:
	if state == State.IDLE or now() < deadline:
		return
	match state:
		State.WAITING_FOR_BITE:
			state = State.BITE_WINDOW
			# Preserve the exact bite deadline even when a frame arrives late.
			deadline += bite_window
			feedback = "!!! FISH BITE !!!\nPRESS E / REEL!"
			if now() >= deadline:
				_fail("The fish got away!")
		State.BITE_WINDOW:
			_fail("The fish got away!")
		State.SUCCESS, State.FAILED:
			state = State.COOLDOWN
			deadline = now() + Data.COOLDOWN_TIME
		State.COOLDOWN:
			state = State.IDLE
			feedback = ""
			_clear_ui()


func reel() -> void:
	if state not in [State.WAITING_FOR_BITE, State.BITE_WINDOW]:
		return
	if not _session_valid():
		cancel_session()
		return
	_advance_state()
	if state == State.WAITING_FOR_BITE:
		_fail("Too early! The fish got scared.")
	elif state == State.BITE_WINDOW:
		_catch_fish()


func _catch_fish() -> void:
	# Change state before any Inventory signal. One reaction grants at most one fish.
	state = State.SUCCESS
	var fish: String = _roll_fish()
	_release_slot()
	if not Inventory.can_add_item(fish, 1):
		# Defensive fallback for external/debug changes to capacity during the session.
		_fail("Barn is full.")
		return
	feedback = "Caught: %s" % Data.FISH[fish]["name"]
	deadline = now() + Data.RESULT_TIME
	Inventory.add_item(fish, 1)


func _roll_fish() -> String:
	var total: int = 0
	for info in Data.FISH.values():
		total += info["weight"]
	var roll: int = rng.randi_range(1, total)
	for fish in Data.FISH:
		roll -= Data.FISH[fish]["weight"]
		if roll <= 0:
			return fish
	return "small_fish"


func _fail(message: String) -> void:
	_release_slot()
	state = State.FAILED
	feedback = message
	deadline = now() + Data.RESULT_TIME


func _release_slot() -> void:
	if reserved_slot:
		Inventory.release_fishing_slot()
		reserved_slot = false


func cancel_session() -> void:
	_release_slot()
	if state in [State.WAITING_FOR_BITE, State.BITE_WINDOW]:
		state = State.IDLE
		deadline = 0.0
		feedback = ""
	player = null
	_clear_ui()


func _clear_ui() -> void:
	if is_instance_valid(hud) and hud.fishing_ui.active_spot == self:
		hud.fishing_ui.clear_session()


func _on_inventory_changed() -> void:
	if SaveManager.resetting:
		cancel_session()
		state = State.IDLE
		deadline = 0.0
		feedback = ""
	elif state in [State.WAITING_FOR_BITE, State.BITE_WINDOW] and not _session_valid():
		cancel_session()


func _exit_tree() -> void:
	_release_slot()
