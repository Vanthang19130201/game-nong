extends RefCounted

# Visual metadata only. IDs, physical bodies, queues and saved anchors live in
# their existing scenes/managers. Source PNGs are retained alongside alpha copies.
const ROOT: String = "res://assets/buildings/v2/transparent/"
const ENTRIES: Dictionary = {
	"house": {"file": "01_main_house.png", "region": Rect2(82,124,1123,953), "size": Vector2(218,160), "ground": 80.0},
	"feed_mill": {"file": "02_feed_mill.png", "region": Rect2(169,153,918,915), "size": Vector2(160,120), "ground": 38.0},
	"bakery": {"file": "03_bakery.png", "region": Rect2(106,83,1064,1050), "size": Vector2(180,135), "ground": 54.0},
	"spinning_machine": {"file": "04_spinning_machine.png", "region": Rect2(145,238,1015,819), "size": Vector2(170,125), "ground": 48.0},
	"loom": {"file": "05_loom.png", "region": Rect2(195,167,879,935), "size": Vector2(170,125), "ground": 48.0},
	"cow_shed": {"file": "06_cow_barn.png", "region": Rect2(21,90,1213,987), "size": Vector2(186,180), "ground": 52.0},
	"chicken_coop": {"file": "07_chicken_coop.png", "region": Rect2(92,171,1106,874), "size": Vector2(144,144), "ground": 36.0},
	"pig_pen": {"file": "08_pig_pen.png", "region": Rect2(29,164,1190,938), "size": Vector2(190,188), "ground": 56.0},
	"sheep_barn": {"file": "09_sheep_barn.png", "region": Rect2(40,114,1184,970), "size": Vector2(190,188), "ground": 56.0},
	"market_stall": {"file": "10_market_stall.png", "region": Rect2(0,27,1528,971), "size": Vector2(160,120), "ground": 29.0},
}
static var _textures: Dictionary = {}
static var _thumbnails: Dictionary = {}


static func texture_for(id: String) -> Texture2D:
	if not ENTRIES.has(id):
		return null
	if not _textures.has(id):
		_textures[id] = load(ROOT + str(ENTRIES[id]["file"])) as Texture2D
	return _textures[id] as Texture2D


static func thumbnail_for(id: String) -> Texture2D:
	if not ENTRIES.has(id):
		return null
	if not _thumbnails.has(id):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture_for(id)
		atlas.region = ENTRIES[id]["region"]
		atlas.filter_clip = true
		_thumbnails[id] = atlas
	return _thumbnails[id] as Texture2D


static func apply_to(sprite: Sprite2D, id: String) -> void:
	var entry: Dictionary = ENTRIES[id]
	var rect: Rect2 = entry["region"]
	var target: Vector2 = entry["size"]
	var factor: float = minf(target.x / rect.size.x, target.y / rect.size.y)
	sprite.texture = texture_for(id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.region_rect = rect
	sprite.region_filter_clip_enabled = true
	sprite.centered = true
	sprite.target_size = target
	sprite.scale = Vector2.ONE * factor
	sprite.offset = Vector2(0, -rect.size.y * 0.5)
	sprite.position = Vector2(0, float(entry["ground"]))


static func place_labels(sprite: Sprite2D) -> void:
	var rect: Rect2 = sprite.transform * sprite.get_rect()
	var visuals := sprite.get_parent()
	var building := visuals.get_parent()
	var title: Label = visuals.get_node_or_null("NameLabel") as Label
	if title == null and sprite.artwork_id in ["feed_mill", "bakery", "spinning_machine"]:
		title = building.get_node_or_null("StatusLabel") as Label
	if title != null:
		title.position.y = rect.position.y - title.size.y - 10.0
	var prompt: Label = visuals.get_node_or_null("Prompt") as Label
	if prompt == null:
		prompt = building.get_node_or_null("InteractionPrompt") as Label
	if prompt != null:
		prompt.position.y = rect.end.y + 10.0
