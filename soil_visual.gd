extends Node2D

@export var soil_texture: Texture2D
@export var soil_size: Vector2 = Vector2(64, 48)

# Keys such as WHEAT_GROWING / WHEAT_READY; assign textures in the Inspector.
@export var crop_textures: Dictionary = {}
@onready var plot: Node = get_parent()
@onready var default_crop_texture: Texture2D = $CropSprite.texture
@onready var default_soil_texture: Texture2D = $SoilSprite.texture

func refresh() -> void:
	var label: Label = plot.get_node("PlantLabel")
	var color: ColorRect = plot.get_node("SoilColor")
	var unlocked: bool = plot.is_unlocked()
	var texture: Texture2D = soil_texture if soil_texture != null else default_soil_texture
	$SoilSprite.texture = texture
	if texture != null:
		$SoilSprite.scale = soil_size / texture.get_size()
	$SoilSprite.visible = unlocked
	color.visible = not unlocked or texture == null
	$CropSprite.z_index = $SoilSprite.z_index + 1
	color.color = Color(0.3, 0.15, 0.06, 1) if unlocked else Color(0.2, 0.2, 0.2, 1)
	$SoilSprite.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5)
	var key: String = Localization.display_name(plot.crop_type) + "_" + plot.PlotState.keys()[plot.state]
	$CropSprite.texture = crop_textures.get(key, default_crop_texture)
	$CropSprite.visible = unlocked and plot.state != plot.PlotState.EMPTY
	if not unlocked:
		label.text = tr("PLOT_LOCKED") % plot.FarmData.plot_price(plot.FarmData.plot_number(plot.plot_id))
	elif plot.state == plot.PlotState.EMPTY:
		label.text = ""
	elif plot.state == plot.PlotState.GROWING:
		label.text = Localization.display_name(plot.crop_type) + "..."
	else:
		label.text = Localization.display_name(plot.crop_type) + tr("WORLD_READY_LINE")
