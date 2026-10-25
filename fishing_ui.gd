extends Control

var active_spot: Node = null
@onready var hud: Node = get_parent()
@onready var panel: PanelContainer = $Panel
@onready var info: Label = $Panel/Content/Info
@onready var reaction_bar: ProgressBar = $Panel/Content/ReactionBar
@onready var reel_button: Button = $Panel/Content/Reel
@onready var fish_button: Button = $Fish


func _ready() -> void:
	reel_button.pressed.connect(_reel)
	fish_button.pressed.connect(_start)
	$Panel/Content/Close.pressed.connect(close_session)
	clear_session()


func show_session(spot: Node) -> void:
	active_spot = spot
	panel.show()
	fish_button.hide()


func clear_session() -> void:
	active_spot = null
	panel.hide()
	reaction_bar.value = 0
	info.text = ""


func close_session() -> void:
	if is_instance_valid(active_spot):
		active_spot.cancel_session()
	clear_session()


func handle_interact() -> bool:
	if not is_instance_valid(active_spot):
		return false
	active_spot.reel()
	return true


func _reel() -> void:
	# Same state validation and reward path as keyboard E.
	if not hud.blocks_world_input():
		handle_interact()


func _start() -> void:
	var spot = _nearby_spot()
	if spot != null and not hud.blocks_world_input():
		spot.start_session()


func _nearby_spot() -> Node:
	var player = get_tree().get_first_node_in_group("farm_player")
	var nearest: Node = null
	var distance: float = INF
	if player == null:
		return null
	for spot in get_tree().get_nodes_in_group("fishing_spots"):
		var candidate_distance: float = player.global_position.distance_squared_to(spot.global_position)
		if spot.can_interact() and candidate_distance < distance:
			nearest = spot
			distance = candidate_distance
	return nearest


func _process(_delta: float) -> void:
	fish_button.visible = not is_instance_valid(active_spot) and not hud.blocks_world_input() and _nearby_spot() != null
	var remaining: int = Inventory.fishing_attempts_remaining()
	fish_button.text = tr("FISHING_ATTEMPTS") % [remaining, Inventory.FishingData.ATTEMPTS_PER_CYCLE]
	if remaining == 0:
		var seconds: int = Inventory.fishing_cycle_seconds_left()
		fish_button.text = tr("FISHING_ATTEMPTS_WAIT") % [int(seconds / 3600), int(seconds / 60) % 60]
	if not is_instance_valid(active_spot):
		panel.hide()
		return
	info.text = active_spot.feedback
	var reacting: bool = active_spot.state == active_spot.State.BITE_WINDOW
	var waiting: bool = active_spot.state == active_spot.State.WAITING_FOR_BITE
	reel_button.disabled = not (reacting or waiting)
	reel_button.text = tr("FISHING_REEL_NOW") if reacting else tr("FISHING_REEL")
	info.modulate = Color(1.0, 0.8, 0.1) if reacting else Color.WHITE
	reaction_bar.visible = reacting
	reaction_bar.max_value = active_spot.bite_window
	reaction_bar.value = maxf(0.0, active_spot.deadline - active_spot.now()) if reacting else 0.0
