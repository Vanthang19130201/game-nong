extends Node

var hovered: Node2D
var original_modulate: Color
var hint: Label
@onready var player: Node2D = get_parent()

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	hint = Label.new()
	hint.theme = preload("res://assets/ui/ui_theme.tres")
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	hint.hide()

func _process(_delta: float) -> void:
	update_hover(get_viewport().get_mouse_position())

func update_hover(screen_position: Vector2) -> void:
	var target: Node2D = null
	if get_viewport().gui_get_hovered_control() == null:
		var world_position: Vector2 = player.get_canvas_transform().affine_inverse() * screen_position
		target = target_at(world_position)
		if target == null and not player.hud.blocks_world_input():
			target = land_at(world_position)
	if target != hovered:
		clear_hover()
		hovered = target
		if is_instance_valid(hovered):
			original_modulate = hovered.modulate
			hovered.modulate = original_modulate * Color(1.15, 1.15, 1.05)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if is_instance_valid(hovered):
		hint.text = tr("MOUSE_INTERACT_HINT") % _display_name(hovered)
		hint.reset_size()
		hint.position = (screen_position + Vector2(16, 20)).clamp(Vector2.ZERO, (get_viewport().get_visible_rect().size - hint.size).max(Vector2.ZERO))
		hint.show()

func clear_hover() -> void:
	if is_instance_valid(hovered):
		hovered.modulate = original_modulate
	hovered = null
	if is_instance_valid(hint):
		hint.hide()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func land_at(world_position: Vector2) -> Node2D:
	for zone in get_tree().get_nodes_in_group("land_zones"):
		if not zone.unlocked and zone.contains_point(world_position):
			return zone
	return null

func target_at(world_position: Vector2) -> Node2D:
	var nearest: Node2D
	var best_distance: float = INF
	for candidate in get_tree().get_nodes_in_group("farm_interactables"):
		if not player.can_interact_with(candidate) or not _contains_point(candidate, world_position):
			continue
		var distance: float = candidate.global_position.distance_squared_to(world_position)
		if distance < best_distance:
			nearest = candidate
			best_distance = distance
	return nearest

# Test each shape in its own local coordinates: this also supports layer-0
# fishing areas and scaled buildings without changing their physics settings.
func _contains_point(node: Node, world_position: Vector2) -> bool:
	if node is CollisionShape2D and not node.disabled and node.shape != null:
		var point: Vector2 = node.to_local(world_position)
		if node.shape is CircleShape2D:
			return point.length_squared() <= node.shape.radius * node.shape.radius
		return node.shape.get_rect().has_point(point)
	for child in node.get_children():
		if _contains_point(child, world_position):
			return true
	return false

func _display_name(target: Node) -> String:
	if target.is_in_group("farm_animals"):
		return tr("ANIMAL_SELL_HINT") % [Localization.display_name(target.animal_type), Inventory.Progression.ANIMALS[target.animal_type]["sell"]]
	if target.name == "SpinningMachine":
		return tr("BUILDING_SPINNING_MACHINE")
	if target.name == "Dairy":
		return tr("BUILDING_DAIRY")
	if target.get("decoration_id") != null:
		return tr(SaveManager.DecorationData.TYPES[target.decoration_id]["name_key"])
	if target.is_in_group("land_zones"):
		var data: Dictionary = SaveManager.LandData.ZONES[target.zone_id]
		return tr("LAND_HOVER_INFO") % [target.display_name, data["cost_coins"], data["cost_wood"], data["cost_stone"]]
	if target.get("plot_id") != null:
		return Localization.display_name(target.crop_type) if not target.crop_type.is_empty() else tr("MOUSE_SOIL_PLOT")
	if target.get("resource_type") != null:
		return tr("MOUSE_TREE") if target.resource_type == "wood" else tr("MOUSE_ROCK")
	if target.get("station_id") != null:
		return Localization.display_name(Inventory.Progression.BUILDINGS[target.station_id]["name"])
	var names: Dictionary = {"House": "BUILDING_HOUSE", "Warehouse": "BUILDING_BARN", "OrderBoard": "WORLD_ORDER_BOARD", "FishMarket": "TITLE_FISH_MARKET", "FishingSpot": "WORLD_FISHING_SPOT", "Bakery": "BUILDING_BAKERY", "Bridge": "WORLD_FISHING_AREA"}
	return tr(names.get(str(target.name), "MOUSE_SOIL_PLOT"))

func _exit_tree() -> void:
	clear_hover()
