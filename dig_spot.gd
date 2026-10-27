extends Area2D

var spot_id: String = ""
var reward: Dictionary = {}
var is_hidden_treasure: bool = false
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
	if is_hidden_treasure:
		for point in [Vector2(-15, 5), Vector2(14, 7), Vector2(0, 12)]:
			draw_colored_polygon(PackedVector2Array([point+Vector2(-5,2), point+Vector2(-2,-4), point+Vector2(4,-2), point+Vector2(6,3)]), Color("9b9480"))
		draw_colored_polygon(PackedVector2Array([Vector2(-28,12), Vector2(-21,-1), Vector2(-10,-5), Vector2(3,-2), Vector2(16,-6), Vector2(28,3), Vector2(23,15), Vector2(9,18), Vector2(-13,17)]), Color("745a3e", 0.58))
		draw_arc(Vector2.ZERO, 17, PI + 0.35, TAU - 0.35, 18, Color("b79563", 0.76), 3.0, true)
		draw_arc(Vector2(1, 1), 10, PI + 0.25, TAU - 0.25, 14, Color("69513a", 0.65), 2.0, true)
		return
	var soil := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		soil.append(Vector2(cos(angle) * 22.0, 8.0 + sin(angle) * 12.0))
	draw_colored_polygon(soil, Color("866744", 0.32))
	draw_arc(Vector2.ZERO, 13, PI + 0.45, TAU - 0.45, 18, Color("b7935e", 0.62), 2.0, true)
	draw_line(Vector2(-9, 5), Vector2(-3, 2), Color("68523b", 0.55), 1.5, true)
	draw_line(Vector2(4, 7), Vector2(9, 4), Color("68523b", 0.5), 1.5, true)
	draw_circle(Vector2(-17, 7), 2.2, Color("9a7951", 0.72))
	draw_circle(Vector2(18, 4), 1.8, Color("b28b5a", 0.72))
