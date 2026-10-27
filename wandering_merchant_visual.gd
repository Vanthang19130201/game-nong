extends Node2D

var prompt: Label

func _ready() -> void:
	add_to_group("farm_interactables")
	add_to_group("placement_obstacles")
	FarmEventManager.merchant_changed.connect(_refresh)
	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.text = tr("MERCHANT_INTERACT")
	prompt.theme = preload("res://assets/ui/ui_theme.tres")
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-66, -54)
	prompt.custom_minimum_size = Vector2(132, 20)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	_refresh()

func _process(_delta: float) -> void:
	visible = FarmEventManager.merchant_active and FarmEventManager.merchant_position != Vector2.ZERO
	if not visible:
		prompt.hide()
		return
	global_position = FarmEventManager.merchant_position
	prompt.visible = can_interact()

func can_interact() -> bool:
	if not is_visible_in_tree() or not FarmEventManager.merchant_active:
		return false
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player) or player.global_position.distance_to(global_position) > 86.0:
		return false
	var hud := get_tree().get_first_node_in_group("farm_hud")
	return hud == null or not hud.blocks_world_input()

func get_interaction_position() -> Vector2:
	return global_position

func interact(_player: Node2D = null) -> void:
	if not can_interact():
		return
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud):
		hud.open_wandering_merchant(self)

func _refresh() -> void:
	if is_instance_valid(prompt):
		prompt.visible = false
	queue_redraw()

func _draw() -> void:
	# Small friendly merchant, hand cart and packed satchel.
	draw_rect(Rect2(-27, 11, 54, 13), Color("895b3c"))
	draw_rect(Rect2(-23, 14, 46, 4), Color("d0a16c"))
	draw_circle(Vector2(-17, 28), 5, Color("5b402d"))
	draw_circle(Vector2(18, 28), 5, Color("5b402d"))
	draw_rect(Rect2(-10, -19, 20, 27), Color("6f8f4a"))
	draw_circle(Vector2(0, -27), 9, Color("d3a77a"))
	draw_rect(Rect2(-11, -35, 22, 5), Color("745037"))
	draw_rect(Rect2(6, -17, 14, 17), Color("bd8650"))
	draw_rect(Rect2(7, -14, 12, 2), Color("e7c275"))
