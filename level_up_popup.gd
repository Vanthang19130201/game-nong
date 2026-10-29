extends Control

const ItemIcon = preload("res://item_icon.gd")
const Progression = preload("res://progression_data.gd")

@onready var card: PanelContainer = $Card
@onready var level_label: Label = $Card/Margin/Content/Level
@onready var unlock_title: Label = $Card/Margin/Content/UnlockTitle
@onready var unlock_grid: GridContainer = $Card/Margin/Content/UnlockGrid
@onready var reward_label: Label = $Card/Margin/Content/RewardRow/Reward
@onready var error_label: Label = $Card/Margin/Content/Error
@onready var claim_button: Button = $Card/Margin/Content/ClaimButton

var pending_events: Array[Dictionary] = []
var active_event: Dictionary = {}
var claiming: bool = false


func _ready() -> void:
	var loaded_level: int = Inventory.player_level
	var loaded_rewarded_level: int = Inventory.last_rewarded_level
	theme = preload("res://assets/ui/ui_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	claim_button.pressed.connect(_claim_current)
	Inventory.level_up.connect(_on_level_up)
	Inventory.level_up_events_cleared.connect(clear_events)
	get_viewport().size_changed.connect(_fit)
	_fit()
	call_deferred("_sync_unclaimed_levels", loaded_level, loaded_rewarded_level)


func sync_unclaimed_levels() -> void:
	_sync_unclaimed_levels(Inventory.player_level, Inventory.last_rewarded_level)


func _sync_unclaimed_levels(level_limit: int, rewarded_level: int) -> void:
	for level in range(rewarded_level + 1, level_limit + 1):
		_enqueue(level, Progression.unlocks_for_level(level), Progression.reward_for_level(level))


func _on_level_up(level: int, unlocks: Array, reward: Dictionary) -> void:
	_enqueue(level, unlocks, reward)


func _enqueue(level: int, unlocks: Array, reward: Dictionary) -> void:
	if level <= Inventory.last_rewarded_level or level > Inventory.player_level:
		return
	if not active_event.is_empty() and int(active_event["level"]) == level:
		return
	for event in pending_events:
		if int(event["level"]) == level:
			return
	pending_events.append({"level": level, "unlocks": unlocks.duplicate(true), "reward": reward.duplicate(true)})
	if active_event.is_empty():
		_show_next()


func _show_next() -> void:
	if pending_events.is_empty():
		active_event.clear()
		hide()
		return
	active_event = pending_events[0]
	_render_event()
	_fit()
	visible = true
	card.scale = Vector2(0.96, 0.96)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.16)


func _render_event() -> void:
	var level: int = int(active_event["level"])
	$Card/Margin/Content/Title.text = tr("LEVEL_UP_TITLE")
	level_label.text = tr("LEVEL_UP_LEVEL") % level
	var unlocks: Array = active_event.get("unlocks", [])
	unlock_title.visible = not unlocks.is_empty()
	unlock_grid.visible = not unlocks.is_empty()
	for child in unlock_grid.get_children():
		unlock_grid.remove_child(child)
		child.queue_free()
	for unlock in unlocks:
		_add_unlock_card(unlock)
	reward_label.text = tr("LEVEL_UP_REWARD_COINS") % int(active_event.get("reward", {}).get("coins", 0))
	$Card/Margin/Content/RewardTitle.text = tr("LEVEL_UP_REWARD_TITLE")
	claim_button.text = tr("LEVEL_UP_CLAIM")
	error_label.hide()
	claim_button.disabled = false
	claiming = false


func _add_unlock_card(unlock: Dictionary) -> void:
	var entry := PanelContainer.new()
	entry.theme_type_variation = &"CardPanel"
	entry.custom_minimum_size = Vector2(190, 48)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_grid.add_child(entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	entry.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_script(ItemIcon)
	icon.item_id = str(unlock.get("icon_id", unlock.get("id", "")))
	row.add_child(icon)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = &"MutedLabel"
	label.text = Localization.display_name(str(unlock.get("name", unlock.get("id", ""))))
	row.add_child(label)


func _claim_current() -> void:
	if claiming or active_event.is_empty():
		return
	claiming = true
	claim_button.disabled = true
	var level: int = int(active_event["level"])
	if not Inventory.claim_level_reward(level):
		claiming = false
		claim_button.disabled = false
		error_label.text = tr("LEVEL_UP_SAVE_ERROR")
		error_label.show()
		return
	pending_events.pop_front()
	active_event.clear()
	_show_next()


func clear_events() -> void:
	pending_events.clear()
	active_event.clear()
	claiming = false
	hide()


func _fit() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var card_size := Vector2(minf(560.0, viewport_size.x - 32.0), minf(520.0, viewport_size.y - 32.0))
	unlock_grid.columns = 1 if viewport_size.x < 520.0 else 2
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.position = (viewport_size - card_size) * 0.5
	card.size = card_size
	card.pivot_offset = card_size * 0.5
