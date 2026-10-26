extends Node2D

@export var zone_id: String = "farm_core"
var sign: Label
var unlocked: bool:
	get: return zone_id in SaveManager.unlocked_land_zones
var display_name: String:
	get: return tr(SaveManager.LandData.ZONES[zone_id]["name_key"])

func _ready() -> void:
	add_to_group("land_zones")
	z_index = -6
	var area: Rect2 = SaveManager.LandData.ZONES[zone_id]["area"]
	position = area.position
	sign = Label.new()
	sign.position = area.size/2 - Vector2(130,12)
	sign.size.x = 260
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_font_size_override("font_size",14)
	sign.add_theme_color_override("font_outline_color",Color.BLACK)
	sign.add_theme_constant_override("outline_size",3)
	add_child(sign)
	Inventory.inventory_changed.connect(refresh)
	refresh()

func refresh() -> void:
	sign.text = tr("LAND_LOCKED_SIGN") % display_name
	sign.visible = not unlocked
	queue_redraw()

func contains_point(point: Vector2) -> bool:
	return SaveManager.LandData.ZONES[zone_id]["area"].has_point(point)

func _draw() -> void:
	if unlocked:
		return
	var rect := Rect2(Vector2.ZERO, SaveManager.LandData.ZONES[zone_id]["area"].size)
	draw_rect(rect, Color(0.95,0.78,0.35,0.12))
	draw_rect(rect.grow(-2), Color(0.85,0.73,0.4,0.65), false, 2)
