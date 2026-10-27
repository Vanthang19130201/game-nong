extends RefCounted

# Visual data only. Add another crop's three textures here without changing
# farming, inventory or save data. Sizes are in world pixels, not source pixels.
const STAGES: Dictionary = {
	"WHEAT": [preload("res://assets/crops/wheat/stage_1.png"), preload("res://assets/crops/wheat/stage_2.png"), preload("res://assets/crops/wheat/stage_3.png")],
	"CORN": [preload("res://assets/crops/corn/stage_1.png"), preload("res://assets/crops/corn/stage_2.png"), preload("res://assets/crops/corn/stage_3.png")],
	"CARROT": [preload("res://assets/crops/carrot/stage_1.png"), preload("res://assets/crops/carrot/stage_2.png"), preload("res://assets/crops/carrot/stage_3.png")]
}
const SIZES: Array[Vector2] = [Vector2(18,16), Vector2(30,28), Vector2(44,40)]
const MATURE_SIZES: Dictionary = {"CORN": Vector2(44,44), "CARROT": Vector2(42,32)}
static var texture_bounds: Dictionary = {}

static func growth_stage(plot: Node) -> int:
	if plot.state == plot.PlotState.READY:
		return 3
	if plot.state != plot.PlotState.GROWING:
		return 0
	var duration: float = maxf(0.001, plot.ready_at - plot.planted_at)
	var progress: float = (Time.get_unix_time_from_system() - plot.planted_at) / duration
	return 2 if progress >= 0.5 else 1

static func texture_for(crop: String, stage: int) -> Texture2D:
	return STAGES[crop][stage-1] if STAGES.has(crop) and stage in [1,2,3] else null

static func display_size(crop: String, stage: int) -> Vector2:
	return MATURE_SIZES.get(crop, SIZES[2]) if stage == 3 else SIZES[stage-1]

static func visible_rect(texture: Texture2D) -> Rect2:
	# Cache alpha bounds once per texture, never read image pixels each frame.
	var id: int = texture.get_instance_id()
	if not texture_bounds.has(id):
		var image: Image = texture.get_image()
		var rect: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
		if image != null and not image.is_empty():
			var used: Rect2i = image.get_used_rect()
			if used.has_area():
				rect = Rect2(used)
		texture_bounds[id] = rect
	return texture_bounds[id]
