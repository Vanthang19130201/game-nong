extends PanelContainer

var _list: VBoxContainer
var _bonus: Button

const PANEL_WIDTH := 460.0
const PANEL_HEIGHT := 330.0

func _ready() -> void:
	theme = preload("res://assets/ui/ui_theme.tres")
	theme_type_variation = &"GamePanel"
	# Compact centred modal: never allow this panel to stretch from the top to
	# the bottom of the HUD viewport.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_fit()
	get_viewport().size_changed.connect(_fit)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = tr("DAILY_TITLE")
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = tr("UI_CLOSE")
	close.pressed.connect(hide)
	header.add_child(close)
	var subtitle := Label.new()
	subtitle.text = tr("DAILY_REFRESH")
	subtitle.theme_type_variation = &"MutedLabel"
	content.add_child(subtitle)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_list)
	_bonus = Button.new()
	_bonus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bonus.pressed.connect(_claim_bonus)
	content.add_child(_bonus)
	DailyMissionManager.missions_changed.connect(refresh)
	DailyMissionManager.reward_claimed.connect(func(coins: int) -> void: _show_reward(coins))
	refresh()
	hide()

func open_panel() -> void:
	refresh()
	_fit()
	show()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := minf(PANEL_WIDTH, maxf(300.0, view.x - 32.0))
	var height := minf(PANEL_HEIGHT, maxf(250.0, view.y - 32.0))
	custom_minimum_size = Vector2(width, height)
	offset_left = -width * 0.5
	offset_top = -height * 0.5
	offset_right = width * 0.5
	offset_bottom = height * 0.5

func refresh() -> void:
	if not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for mission in DailyMissionManager.daily_missions:
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		card.custom_minimum_size.y = 56
		_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done := int(mission.get("progress", 0)) >= int(mission.get("target", 1))
		var state := tr("DAILY_CLAIMED") if bool(mission.get("claimed", false)) else (tr("DAILY_READY") if done else "%d/%d" % [mission.get("progress", 0), mission.get("target", 1)])
		label.text = "%s\n%s  •  🪙 %d" % [tr(str(mission.get("title_key", ""))), state, mission.get("reward_coins", 0)]
		# Keep the status compact and rely on the normal UI font instead of emoji
		# glyphs, which are not available on every Windows install.
		label.text = "%s\n%s  +%d" % [tr(str(mission.get("title_key", ""))), state, mission.get("reward_coins", 0)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var claim := Button.new()
		claim.text = tr("DAILY_CLAIM")
		claim.disabled = not done or bool(mission.get("claimed", false))
		claim.pressed.connect(_claim_mission.bind(str(mission.get("id", ""))))
		row.add_child(claim)
	_bonus.text = tr("DAILY_BONUS") % DailyMissionManager.COMPLETION_BONUS
	_bonus.disabled = DailyMissionManager.daily_completion_bonus_claimed or not DailyMissionManager.daily_missions.all(func(m: Dictionary) -> bool: return int(m.get("progress", 0)) >= int(m.get("target", 1)))

func _claim_mission(mission_id: String) -> void:
	if DailyMissionManager.claim_mission(mission_id):
		refresh()

func _claim_bonus() -> void:
	if DailyMissionManager.claim_completion_bonus():
		refresh()

func _show_reward(coins: int) -> void:
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud):
		hud.show_transaction_feedback(tr("DAILY_REWARD") % coins, "reward")
