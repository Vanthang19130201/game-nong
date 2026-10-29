extends VBoxContainer

# Shared HUD presenter for brief player-facing messages. World pickup feedback
# remains in FloatingFeedback so it can follow the player without competing.
const MAX_VISIBLE := 3
const DEFAULT_DURATION := 2.45
const GAIN_COLOR := Color("8df59b")
const LOSS_COLOR := Color("ffab70")
const ACCENTS := {"info":Color("7eaec7"), "success":Color("6f9b62"), "reward":Color("c99b36"), "warning":Color("c58b47"), "level_up":Color("c89a35"), "mission":Color("6e9a76"), "item":Color("8a9e6b"), "unlock":Color("a483ba")}
const ICONS := {"info":"i", "success":"✓", "reward":"✦", "warning":"!", "level_up":"★", "mission":"✓", "item":"+", "unlock":"✦"}
var _entries: Array[PanelContainer] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -210.0
	offset_right = 210.0
	offset_top = 18.0
	offset_bottom = 240.0
	add_theme_constant_override("separation", 8)

func set_popup_mode(_enabled: bool) -> void:
	pass

func show_message(message: String) -> void:
	show_notification(message, "warning" if _looks_like_warning(message) else "info")

func show_notification(message: String, notification_type: String = "info", duration: float = DEFAULT_DURATION) -> void:
	var clean := message.strip_edges()
	if clean.is_empty():
		return
	for panel in _entries:
		if is_instance_valid(panel) and str(panel.get_meta("notification_text", "")) == clean:
			_restart(panel, duration)
			return
	while _entries.size() >= MAX_VISIBLE:
		_remove(_entries[0])
	var panel := _make_panel(clean, notification_type)
	_entries.append(panel)
	add_child(panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.98, 0.98)
	var tween := panel.create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_schedule_exit(panel, duration)

func _make_panel(message: String, notification_type: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.pivot_offset = Vector2(210, 22)
	panel.set_meta("notification_text", message)
	panel.add_theme_stylebox_override("panel", _style_for(notification_type))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon := Label.new()
	icon.text = str(ICONS.get(notification_type, "i"))
	icon.custom_minimum_size = Vector2(24, 24)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", ACCENTS.get(notification_type, ACCENTS.info))
	row.add_child(icon)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("563d29"))
	row.add_child(label)
	return panel

func _style_for(notification_type: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3d9")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ACCENTS.get(notification_type, ACCENTS.info)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.18, 0.12, 0.07, 0.18)
	style.shadow_size = 4
	return style

func _restart(panel: PanelContainer, duration: float) -> void:
	var tween: Tween = panel.get_meta("lifetime", null)
	if tween != null and tween.is_valid():
		tween.kill()
	panel.modulate.a = 1.0
	_schedule_exit(panel, duration)

func _schedule_exit(panel: PanelContainer, duration: float) -> void:
	var tween := panel.create_tween()
	panel.set_meta("lifetime", tween)
	tween.tween_interval(maxf(0.8, duration))
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_remove.bind(panel))

func _remove(panel: PanelContainer) -> void:
	_entries.erase(panel)
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()

func _looks_like_warning(message: String) -> bool:
	var lowered := message.to_lower()
	return "không" in lowered or "đầy" in lowered or "thiếu" in lowered or "lỗi" in lowered
