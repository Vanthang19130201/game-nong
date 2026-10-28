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
	color.color = Color("87965f") if unlocked else Color("789457", 0.16)
	# The plot texture now carries its own muted grass-and-earth palette.
	$SoilSprite.modulate = Color.WHITE
	# Keep the node/reference for old scenes, but never draw text across a plot.
	label.text = ""
	label.hide()
	# Keep only the next sequential plot visible as a meadow tile, so its location
	# is discoverable while all later locked plots remain completely hidden.
	var is_next_plot: bool = not unlocked and FarmData.plot_number(plot.plot_id) == Inventory.unlocked_plot_count + 1
	$LockedMarker.visible = is_next_plot
	$LockedMarker.modulate = Color(1.0, 0.98, 0.88, 0.96)
	# The next-plot preview must sit under the Player, not paint over their feet.
	z_index = -1 if is_next_plot else 0
	$LockedMarker.z_index = 0
	set_process(unlocked and plot.state == plot.PlotState.GROWING)
	$GrowthTime.visible = unlocked and plot.state == plot.PlotState.GROWING
	refresh_elapsed = 0.0
	_refresh_crop()
	_update_growth_time()
	queue_redraw()


func _draw() -> void:
	if plot.is_unlocked():
		return
	if FarmData.plot_number(plot.plot_id) != Inventory.unlocked_plot_count + 1:
		return
	var near_player: bool = plot.player_near
	var tile := PackedVector2Array([
		Vector2(-29, -21), Vector2(-24, -23), Vector2(24, -22),
		Vector2(30, -18), Vector2(29, 19), Vector2(24, 22),
		Vector2(-24, 22), Vector2(-30, 18)
	])
	draw_colored_polygon(tile, Color("819d5b", 0.97))
	var outline := tile.duplicate()
	outline.append(tile[0])
	draw_polyline(outline, Color("35492f", 0.9), 5.0, true)
	draw_polyline(outline, Color("fff0b7", 1.0), 3.4 if near_player else 2.8, true)
	draw_polyline(outline, Color("e8b34f", 0.98 if near_player else 0.82), 1.4, true)
	draw_rect(Rect2(-24, -17, 48, 34), Color("dce6ad", 0.14), false, 1.0)
	# Small grass stitches and a pair of flowers make the preview feel like lawn,
	# while leaving the lock badge readable in the middle.
	for tuft_x in [-22.0, 21.0]:
		draw_line(Vector2(tuft_x, 14), Vector2(tuft_x - 2, 8), Color("c5d489", 0.95), 1.4, true)
		draw_line(Vector2(tuft_x, 14), Vector2(tuft_x + 2, 7), Color("a9c46d", 0.95), 1.5, true)
	draw_circle(Vector2(-17, -12), 1.8, Color("f2d38a"))
	draw_circle(Vector2(17, 13), 1.8, Color("f3e5ca"))

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
