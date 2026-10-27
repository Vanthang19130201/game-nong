extends Node2D

const RockData = preload("res://rock_data.gd")
@export var tree_texture: Texture2D = preload("res://assets/environment/tree/Tree.png")
@export var tree_region: Rect2 = Rect2(0,2,1248,1230)
@export var tree_size: Vector2 = Vector2(128,160)
@export var tree_ground_y: float = 40.0
@export var rock_texture: Texture2D
@export var rock_textures: Dictionary = {}
@export var stump_texture: Texture2D
@export var depleted_rock_texture: Texture2D
@onready var resource_node: Node = get_parent()
@onready var default_texture: Texture2D = $ResourceSprite.texture

func _fit_tree() -> void:
	var sprite: Sprite2D = $ResourceSprite
	sprite.region_enabled = tree_region.has_area()
	sprite.region_rect = tree_region
	var art_size: Vector2 = tree_region.size if sprite.region_enabled else sprite.texture.get_size()
	var factor: float = minf(tree_size.x/art_size.x,tree_size.y/art_size.y)
	sprite.scale = Vector2.ONE*factor
	sprite.position = Vector2(0,tree_ground_y-art_size.y*factor/2)

func refresh() -> void:
	var wood: bool = resource_node.resource_type == "wood"
	var state: String = resource_node.state
	var depleted: bool = state == "DEPLETED"
	var texture: Texture2D = tree_texture if wood else rock_texture
	var color: Color = Color(0.15,0.5,0.2)
	var sprite_color: Color = $ResourceSprite.modulate
	if not wood:
		sprite_color = Color.WHITE
		color = RockData.TYPES[resource_node.rock_type]["color"]
		var typed_texture: Texture2D = rock_textures.get(resource_node.rock_type)
		if typed_texture == null:
			typed_texture = RockData.texture_for(resource_node.rock_type)
		if typed_texture != null:
			texture = typed_texture
		if not rock_textures.has(resource_node.rock_type) and RockData.texture_paths.size() < RockData.TYPES.size():
			sprite_color = color.lightened(0.5)
	if depleted:
		texture = stump_texture if wood else depleted_rock_texture
	var fallback: Texture2D = default_texture
	if not wood and fallback == tree_texture:
		fallback = null
	$ResourceSprite.texture = texture if texture != null else fallback
	$ResourceSprite.region_enabled = false
	if wood and $ResourceSprite.texture != null and not depleted:
		_fit_tree()
	if not wood and $ResourceSprite.texture != null:
		# All variants keep the existing 80x80 footprint; only the sprite scales.
		$ResourceSprite.scale = Vector2(80,80)/$ResourceSprite.texture.get_size()
	sprite_color.a = 0.3 if depleted else 1.0
	$ResourceSprite.modulate = sprite_color
	resource_node.progress.visible = state == "GATHERING"
	resource_node.visual.color = color
	resource_node.visual.modulate.a = 0.3 if depleted else 1.0
	_refresh_label()


func _process(_delta: float) -> void:
	_refresh_label()


func _refresh_label() -> void:
	var state: String = resource_node.state
	var wood: bool = resource_node.resource_type == "wood"
	if state == "GATHERING":
		resource_node.label.text = tr("WORLD_CHOPPING") if wood else tr("WORLD_MINING")
	elif state == "DEPLETED":
		resource_node.label.text = tr("WORLD_RESPAWNING") if resource_node.player_near else ""
	else:
		resource_node.label.text = tr("WORLD_GATHER") if resource_node.player_near else ""
