extends VBoxContainer

const GAIN_COLOR := Color("8df59b")
const LOSS_COLOR := Color("ffab70")
const MAX_TOASTS := 4

# Keep the latest message available for UI checks.
var text: String = ""
var popup_mode: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -180
	offset_right = 180
	offset_top = -128
	offset_bottom = -128
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()
	hide()


func _fit_width() -> void:
	var half_width: float = minf(180, (get_viewport_rect().size.x - 24) / 2)
	offset_left = -half_width
	offset_right = half_width
	if popup_mode:
		offset_left = -half_width*2-16
		offset_right = -16


func set_popup_mode(enabled: bool) -> void:
	popup_mode = enabled
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if enabled else Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_END if enabled else Control.GROW_DIRECTION_BEGIN
	offset_top = 112 if enabled else -128
	offset_bottom = offset_top
	_fit_width()


func show_message(message: String) -> void:
	text = message
	if get_child_count() >= MAX_TOASTS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.05, 0.92)
	background.set_corner_radius_all(10)
	background.content_margin_left = 18
	background.content_margin_right = 18
	background.content_margin_top = 12
	background.content_margin_bottom = 12
	toast.add_theme_stylebox_override("panel", background)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 8)
	toast.add_child(lines)
	for line in message.split("\n", false):
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", GAIN_COLOR if line.begins_with("+") else LOSS_COLOR)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		lines.add_child(label)
	add_child(toast)
	show()
	var tween := toast.create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_remove_toast.bind(toast))


func _remove_toast(toast: Control) -> void:
	remove_child(toast)
	toast.queue_free()
	if get_child_count() == 0:
		hide()
