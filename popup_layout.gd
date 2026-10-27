extends Node

# UI-only chrome and viewport fitting, shared by the existing popup panels.
const UI_THEME = preload("res://assets/ui/ui_theme.tres")
var preferred_size := Vector2(480,540)
var body: VBoxContainer
var footer: CenterContainer
var close_button: Button
@onready var panel: PanelContainer = get_parent()

func _ready() -> void:
	panel.theme = UI_THEME
	get_viewport().size_changed.connect(fit)
	panel.visibility_changed.connect(_visibility_changed)
	panel.minimum_size_changed.connect(_visibility_changed)
	fit.call_deferred()

func build(title_text: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation",12)
	margin.add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.theme_type_variation = &"Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 48
	scroll.clip_contents = true
	content.add_child(scroll)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	footer = CenterContainer.new()
	footer.name = "Footer"
	footer.custom_minimum_size.y = 72
	footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(footer)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = tr("UI_CLOSE")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(140,44)
	footer.add_child(close_button)
	return body

func _visibility_changed() -> void:
	if panel.visible:
		fit.call_deferred()

func fit() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = preferred_size.min(view-Vector2(24,32))
	panel.position = (view-panel.size)/2
