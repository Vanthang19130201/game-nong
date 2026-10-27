extends Area2D

var spot_id: String = ""
var reward: Dictionary = {}
var player: Node2D
var prompt: Label

func _ready() -> void:
	add_to_group("farm_interactables")
	add_to_group("placement_obstacles")
	player = get_tree().get_first_node_in_group("farm_player")
	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.text = tr("DIG_PROMPT")
	prompt.theme = preload("res://assets/ui/ui_theme.tres")
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-54, -35)
	prompt.custom_minimum_size = Vector2(108, 20)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	prompt.hide()
	queue_redraw()

func can_interact() -> bool:
	if not is_instance_valid(player) or not is_visible_in_tree():
		return false
	var hud := get_tree().get_first_node_in_group("farm_hud")
	return (hud == null or not hud.blocks_world_input()) and not is_instance_valid(player.get("active_resource")) and player.global_position.distance_to(global_position) <= 76.0

func _process(_delta: float) -> void:
	if is_instance_valid(prompt):
		prompt.visible = can_interact()

func interact(_player: Node2D = null) -> void:
	if can_interact():
		var manager := get_tree().get_first_node_in_group("dig_spot_manager")
		if is_instance_valid(manager):
			manager.collect_spot(spot_id)

func get_interaction_position() -> Vector2:
	return global_position

func _draw() -> void:
	var soil := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		soil.append(Vector2(cos(angle) * 22.0, 8.0 + sin(angle) * 12.0))
	draw_colored_polygon(soil, Color("866744", 0.32))
	draw_arc(Vector2.ZERO, 15, PI + 0.3, TAU - 0.3, 20, Color("b7935e", 0.72), 4.0, true)
	draw_line(Vector2(-4, -4), Vector2(4, 4), Color("6d4439", 0.85), 2.0, true)
	draw_line(Vector2(4, -4), Vector2(-4, 4), Color("6d4439", 0.85), 2.0, true)
