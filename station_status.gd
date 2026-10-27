extends PanelContainer

# World UI only. The station remains responsible for production and rewards.
@onready var station: Area2D = get_parent().get_parent()
@onready var icon: Control = $Content/Row/Icon
@onready var label: Label = $Content/Row/Label
@onready var progress: ProgressBar = $Content/Progress
var elapsed: float = 0.0
var prompt: Label

func _ready() -> void:
	prompt = Label.new()
	prompt.name = "InteractionPrompt"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color("fff4d7"))
	prompt.add_theme_color_override("font_outline_color", Color("59402f"))
	prompt.add_theme_constant_override("outline_size", 3)
	get_parent().add_child.call_deferred(prompt)
	station.state_changed.connect(refresh)
	station.visibility_changed.connect(refresh)
	station.body_entered.connect(_on_body_changed)
	station.body_exited.connect(_on_body_changed)
	resized.connect(_place_above_building)
	refresh()
	_place_above_building.call_deferred()

func refresh() -> void:
	var product: Dictionary = station.Progression.PRODUCTS[station.station_id]
	progress.visible = station.state == "PRODUCING"
	set_process(progress.visible and station.is_visible_in_tree())
	elapsed = 0.0
	icon.item_id = product["item"] if station.state == "READY" else product["feed"]
	match station.state:
		"HUNGRY":
			label.text = tr("WORLD_ANIMALS_NEED_FEED")
			label.modulate = Color("8b5a2b")
		"PRODUCING":
			label.modulate = Color.WHITE
			_update_progress()
		"READY":
			label.text = tr("WORLD_PRODUCT_READY") % Localization.display_name(product["item"])
			label.modulate = Color("3f7138")
	visible = station.state in ["HUNGRY", "PRODUCING", "READY"]
	# Containers shrink as well as grow when the progress row disappears.
	reset_size()
	_refresh_prompt()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.2:
		elapsed = 0.0
		if station.state == "PRODUCING":
			_update_progress()
		_refresh_prompt()

func _on_body_changed(_body: Node2D) -> void:
	_refresh_prompt.call_deferred()

func _refresh_prompt() -> void:
	if prompt == null:
		return
	var near: bool = station.is_visible_in_tree() and station.can_interact()
	prompt.text = ""
	if near:
		match station.state:
			"HUNGRY": prompt.text = tr("ANIMAL_FEED_PROMPT")
			"READY": prompt.text = tr("ANIMAL_EGG_PROMPT" if station.station_id == "chicken_coop" else "ANIMAL_MILK_PROMPT")
			"PRODUCING": prompt.text = tr("WORLD_PRODUCTION_TIMER") % ceili(maxf(0.0, station.ready_at - Time.get_unix_time_from_system()))
	var sprite: Sprite2D = get_parent().get_node("BuildingSprite")
	var rect: Rect2 = sprite.transform * sprite.get_rect()
	prompt.position = Vector2(rect.get_center().x - 110, rect.end.y + 10)
	prompt.size = Vector2(220, 22)

func _update_progress() -> void:
	var remaining: float = maxf(0.0, station.ready_at - Time.get_unix_time_from_system())
	var duration: float = maxf(0.001, station.ready_at - station.started_at)
	progress.value = clampf(1.0 - remaining / duration, 0.0, 1.0)
	label.text = tr("WORLD_PRODUCTION_TIMER") % ceili(remaining)

func _place_above_building() -> void:
	var sprite: Sprite2D = get_parent().get_node("BuildingSprite")
	var rect: Rect2 = sprite.transform * sprite.get_rect()
	position = Vector2(rect.get_center().x - size.x / 2.0, rect.position.y - size.y - 10.0)
