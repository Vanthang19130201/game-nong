extends Node2D

const Icon = preload("res://item_icon.gd")
var item_id: String = ""
var state: String = ""
var icon: Control
var bob: Tween
var base_y: float

func _ready() -> void:
	z_index = 8
	icon = Icon.new()
	icon.position = Vector2(-10, -10)
	icon.size = Vector2(20, 20)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	visibility_changed.connect(_update_bob)
	hide()

func configure(height: float) -> void:
	base_y = -height - 19.0
	position = Vector2(0, base_y)

func refresh(next_state: String, next_item: String) -> void:
	if state == next_state and item_id == next_item:
		return
	state = next_state
	item_id = next_item
	icon.item_id = item_id
	visible = state in ["HUNGRY", "READY"]
	queue_redraw()
	_update_bob()

func _update_bob() -> void:
	if bob != null:
		bob.kill()
		bob = null
	position.y = base_y
	if state == "READY" and is_visible_in_tree():
		bob = create_tween().set_loops()
		bob.tween_property(self, "position:y", base_y - 3.0, 0.5).set_trans(Tween.TRANS_SINE)
		bob.tween_property(self, "position:y", base_y, 0.5).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0 if state == "READY" else 12.0, Color("78583e"))
	draw_circle(Vector2.ZERO, 12.5 if state == "READY" else 10.5, Color("fff0c5") if state == "READY" else Color("e9dec0"))
