extends Camera2D

@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.5
@export var zoom_step: float = 0.1
@export var zoom_smoothing: float = 12.0

var target_zoom: float = 1.0
var following_player: bool = true
var dragging: bool = false
var pan_center: Vector2
var follow_smoothing: bool
@onready var hud: Node = get_tree().get_first_node_in_group("farm_hud")

func _ready() -> void:
	follow_smoothing = position_smoothing_enabled
	target_zoom = zoom.x
	get_viewport().size_changed.connect(_fit_view)
	_fit_view()

func _process(delta: float) -> void:
	if dragging and (_modal_open() or get_viewport().gui_get_hovered_control() != null):
		end_pan()
	var next_zoom: float = lerpf(zoom.x, target_zoom, 1.0 - exp(-zoom_smoothing * delta))
	if is_equal_approx(next_zoom, target_zoom):
		next_zoom = target_zoom
	zoom = Vector2.ONE * next_zoom
	if following_player:
		position = Vector2.ZERO
	else:
		pan_center = _clamp_center(pan_center)
		global_position = pan_center
		force_update_scroll()

func _input(event: InputEvent) -> void:
	# A release over UI must also end a drag that began over the world.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		end_pan()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("focus_camera") and not event.is_echo():
		if not _modal_open():
			focus_player()
			get_viewport().set_input_as_handled()
		return
	if _modal_open() or get_viewport().gui_get_hovered_control() != null:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				request_zoom(zoom_step * event.factor)
			MOUSE_BUTTON_WHEEL_DOWN:
				request_zoom(-zoom_step * event.factor)
			MOUSE_BUTTON_MIDDLE:
				begin_pan()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		pan_by(event.relative)
		get_viewport().set_input_as_handled()

# These methods also provide an entry point for future touch gestures.
func request_zoom(amount: float) -> void:
	target_zoom = clampf(target_zoom + amount, _minimum_zoom(), max_zoom)

func begin_pan() -> void:
	pan_center = _clamp_center(get_screen_center_position())
	following_player = false
	dragging = true
	position_smoothing_enabled = false
	global_position = pan_center
	force_update_scroll()

func pan_by(screen_delta: Vector2) -> void:
	if not dragging:
		return
	pan_center = _clamp_center(pan_center - screen_delta / zoom)
	global_position = pan_center
	force_update_scroll()

func end_pan() -> void:
	dragging = false

func focus_player() -> void:
	end_pan()
	following_player = true
	position = Vector2.ZERO
	position_smoothing_enabled = follow_smoothing

func _modal_open() -> bool:
	if not is_instance_valid(hud):
		return false
	# Edit Mode intentionally locks gameplay, while allowing camera controls.
	if hud.edit_farm.active:
		return hud.edit_farm.delete_confirmation.visible
	return hud.blocks_world_input() or hud.fishing_ui.panel.visible

func _minimum_zoom() -> float:
	var map_size := Vector2(limit_right - limit_left, limit_bottom - limit_top)
	var view_size: Vector2 = get_viewport_rect().size
	# On large windows, stop zooming out before the viewport exceeds the map.
	return clampf(maxf(view_size.x / map_size.x, view_size.y / map_size.y), min_zoom, max_zoom)

func _clamp_center(point: Vector2) -> Vector2:
	var half_view: Vector2 = get_viewport_rect().size / zoom / 2.0
	var start := Vector2(limit_left, limit_top) + half_view
	var finish := Vector2(limit_right, limit_bottom) - half_view
	var middle := Vector2(limit_left + limit_right, limit_top + limit_bottom) / 2.0
	return Vector2(clampf(point.x, minf(start.x, middle.x), maxf(finish.x, middle.x)), clampf(point.y, minf(start.y, middle.y), maxf(finish.y, middle.y)))

func _fit_view() -> void:
	target_zoom = clampf(target_zoom, _minimum_zoom(), max_zoom)
	zoom = Vector2.ONE * clampf(zoom.x, _minimum_zoom(), max_zoom)
	if not following_player:
		pan_center = _clamp_center(pan_center)
		global_position = pan_center
	force_update_scroll()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		end_pan()
