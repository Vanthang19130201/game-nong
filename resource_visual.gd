extends Node2D

const RockData = preload("res://rock_data.gd")
@export var tree_texture: Texture2D
@export var rock_texture: Texture2D
@export var rock_textures: Dictionary = {}
@export var stump_texture: Texture2D
@export var depleted_rock_texture: Texture2D
@onready var resource_node: Node = get_parent()
@onready var default_texture: Texture2D = $ResourceSprite.texture

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
	$ResourceSprite.texture = texture if texture != null else default_texture
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
