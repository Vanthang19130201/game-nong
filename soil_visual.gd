extends Node2D

const CropVisuals = preload("res://crop_visual_data.gd")
const FarmData = preload("res://farm_data.gd")
@export var soil_texture: Texture2D
@export var soil_size: Vector2 = Vector2(64, 48)

# Optional Inspector overrides: WHEAT_STAGE_1/2/3. Legacy WHEAT_GROWING /
# WHEAT_READY overrides still work for existing scenes.
@export var crop_textures: Dictionary = {}
@onready var plot: Node = get_parent()
@onready var default_crop_texture: Texture2D = $CropSprite.texture
@onready var default_soil_texture: Texture2D = $SoilSprite.texture
var displayed_stage: int = 0
var refresh_elapsed: float = 0.0

func refresh() -> void:
	var label: Label = plot.get_node("PlantLabel")
	var color: ColorRect = plot.get_node("SoilColor")
	var unlocked: bool = plot.is_unlocked()
	var texture: Texture2D = soil_texture if soil_texture != null else default_soil_texture
	$SoilSprite.texture = texture
	if texture != null:
		$SoilSprite.scale = soil_size / texture.get_size()
	$SoilSprite.visible = unlocked
	color.visible = unlocked and texture == null
	color.color = Color("A66D3F") if unlocked else Color("789457", 0.16)
	# READY emphasis belongs around the crop, not across the complete soil tile.
	$SoilSprite.modulate = Color.WHITE
	# Keep the node/reference for old scenes, but never draw text across a plot.
	label.text = ""
	label.hide()
	$LockedMarker.visible = not unlocked
	var plot_number: int = FarmData.plot_number(plot.plot_id)
	var next_plot: bool = plot_number == Inventory.unlocked_plot_count + 1
	$LockedMarker.modulate = Color(1, 1, 1, 0.92 if next_plot else 0.28)
	set_process(unlocked and plot.state == plot.PlotState.GROWING)
	$GrowthTime.visible = unlocked and plot.state == plot.PlotState.GROWING
	refresh_elapsed = 0.0
	_refresh_crop()
	_update_growth_time()
	queue_redraw()


func _draw() -> void:
	if plot.is_unlocked():
		return
	if FarmData.plot_number(plot.plot_id) != Inventory.unlocked_plot_count + 1 or not plot.player_near:
		return
	draw_rect(Rect2(-31, -23, 62, 46), Color("E8B34F", 0.12), true)
	draw_rect(Rect2(-31, -23, 62, 46), Color("E8B34F", 0.88), false, 2.0)

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 0.25:
		refresh_elapsed = 0.0
		if CropVisuals.growth_stage(plot) != displayed_stage:
			_refresh_crop()
		_update_growth_time()

func _update_growth_time() -> void:
	if not $GrowthTime.visible:
		return
	var seconds: int = maxi(0, ceili(plot.ready_at - Time.get_unix_time_from_system()))
	$GrowthTime.text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]

func _refresh_crop() -> void:
	displayed_stage = CropVisuals.growth_stage(plot) if plot.is_unlocked() else 0
	$CropAccent.set_crop_visual(displayed_stage, plot.state == plot.PlotState.READY)
	$CropSprite.hide()
	$FallbackCropVisual.hide()
	if displayed_stage == 0:
		$CropSprite.texture = null
		return
	var key: String = plot.crop_type + "_STAGE_" + str(displayed_stage)
	var legacy_key: String = plot.crop_type + "_" + plot.PlotState.keys()[plot.state]
	var texture: Texture2D = crop_textures.get(key, crop_textures.get(legacy_key, CropVisuals.texture_for(plot.crop_type, displayed_stage)))
	if texture == null:
		texture = default_crop_texture
	var target_size: Vector2 = CropVisuals.display_size(plot.crop_type, displayed_stage)
	if texture != null:
		var rect: Rect2 = CropVisuals.visible_rect(texture)
		$CropSprite.texture = texture
		$CropSprite.region_enabled = true
		$CropSprite.region_rect = rect
		$CropSprite.scale = Vector2.ONE * minf(target_size.x / rect.size.x, target_size.y / rect.size.y)
		$CropSprite.offset = Vector2(0, -rect.size.y / 2.0)
		$CropSprite.modulate = Color(1.04, 1.02, 0.97) if plot.state == plot.PlotState.READY else Color.WHITE
		$CropSprite.show()
	else:
		# Existing crops without stage art keep a small recognizable item visual.
		$CropSprite.texture = null
		$FallbackCropVisual.item_id = plot.crop_type.to_lower()
		$FallbackCropVisual.size = target_size
		$FallbackCropVisual.position = Vector2(-target_size.x / 2.0, 12.0 - target_size.y)
		$FallbackCropVisual.modulate = Color.WHITE if displayed_stage == 3 else Color(0.75,1,0.7)
		$FallbackCropVisual.show()
