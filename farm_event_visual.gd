extends Node2D

var prompt: Label
func _ready() -> void:
	add_to_group("placement_obstacles")
	add_to_group("farm_interactables")
	FarmEventManager.changed.connect(_refresh)
	GameClock.changed.connect(_refresh_time)
	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.theme = preload("res://assets/ui/ui_theme.tres")
	prompt.text = tr("EVENT_INTERACT_PROMPT")
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-62, -46)
	prompt.custom_minimum_size = Vector2(124, 22)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	FarmEventManager.setup(get_parent() as Node2D)
	_refresh(FarmEventManager.current_event_id)

func _process(_delta: float) -> void:
	var event_id: String = FarmEventManager.current_event_id
	var visible_event: bool = _is_event_visible(event_id)
	visible = visible_event and FarmEventManager.event_position != Vector2.ZERO
	if not visible:
		prompt.hide()
		return
	global_position = FarmEventManager.event_position
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= 160.0:
		FarmEventManager.discover_current_event()
	prompt.visible = can_interact()

func can_interact() -> bool:
	if not is_visible_in_tree() or FarmEventManager.event_collected or FarmEventManager.current_event_id not in ["fallen_branch", "lost_crate"]:
		return false
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player) or player.global_position.distance_to(global_position) > 76.0:
		return false
	var hud := get_tree().get_first_node_in_group("farm_hud")
	return hud == null or not hud.blocks_world_input()

func get_interaction_position() -> Vector2:
	return global_position

func interact(_player: Node2D = null) -> void:
	if can_interact() and FarmEventManager.collect_current_event():
		if FarmEventManager.current_event_id == "fallen_branch":
			get_tree().call_group("farm_hud", "show_floating_feedback", tr("TRADE_RESOURCE") % [2, tr("ITEM_WOOD")])
		else:
			get_tree().call_group("farm_hud", "show_inventory_change", "old_bottle", 1)
		prompt.hide()
		queue_redraw()

func _is_event_visible(event_id: String) -> bool:
	if event_id == "firefly_night":
		return GameClock.minutes >= 17.5 * 60.0 or GameClock.minutes < 5.0 * 60.0
	if event_id == "butterfly_day":
		return GameClock.minutes >= 6.0 * 60.0 and GameClock.minutes < 18.0 * 60.0
	return not event_id.is_empty() and not FarmEventManager.event_collected

func _refresh(_event_id: String) -> void:
	global_position = FarmEventManager.event_position
	queue_redraw()

func _refresh_time() -> void:
	if FarmEventManager.current_event_id in ["firefly_night", "butterfly_day"]:
		queue_redraw()

func _draw() -> void:
	if FarmEventManager.event_collected:
		return
	match FarmEventManager.current_event_id:
		"butterfly_day":
			for point in [Vector2(-18, -10), Vector2(12, 4), Vector2(22, -18), Vector2(-5, 20)]:
				_draw_butterfly(point)
		"mushroom_growth":
			for point in [Vector2(-16, 8), Vector2(12, 10), Vector2(0, 1)]:
				_draw_mushroom(point)
		"fallen_branch":
			draw_line(Vector2(-25, 8), Vector2(24, 1), Color("704b34"), 7.0, true)
			draw_line(Vector2(-2, 5), Vector2(4, -7), Color("8e6946"), 3.0, true)
		"lost_crate":
			var rect := Rect2(-18, -13, 36, 27)
			draw_rect(rect, Color("99693f"))
			draw_rect(rect, Color("543b2a"), false, 2.0)
			draw_line(Vector2(-17, 0), Vector2(17, 0), Color("d2a16a"), 3.0)
		"firefly_night":
			if _is_event_visible("firefly_night"):
				for point in [Vector2(-26, 4), Vector2(-9, -13), Vector2(18, -3), Vector2(27, 12), Vector2(5, 19), Vector2(-19, 20)]:
					draw_circle(point, 2.0, Color("f3d77d", 0.82))

func _draw_butterfly(point: Vector2) -> void:
	draw_circle(point + Vector2(-3, 0), 3.0, Color("e8b34f"))
	draw_circle(point + Vector2(3, 0), 3.0, Color("d58c70"))
	draw_line(point + Vector2(0, -3), point + Vector2(0, 4), Color("5b402d"), 1.0)

func _draw_mushroom(point: Vector2) -> void:
	draw_rect(Rect2(point + Vector2(-2, 1), Vector2(4, 8)), Color("f0dfb8"))
	draw_arc(point, 7.0, PI, TAU, 12, Color("bb7151"), 5.0, true)
