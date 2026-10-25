extends Node2D

@export var tree_texture: Texture2D
@export var rock_texture: Texture2D
@export var stump_texture: Texture2D
@export var depleted_rock_texture: Texture2D
@onready var resource_node: Node = get_parent()
@onready var default_texture: Texture2D = $ResourceSprite.texture

func refresh() -> void:
	var wood: bool = resource_node.resource_type == "wood"
	var state: String = resource_node.state
	var depleted: bool = state == "DEPLETED"
	var texture: Texture2D = tree_texture if wood else rock_texture
	if depleted:
		texture = stump_texture if wood else depleted_rock_texture
	$ResourceSprite.texture = texture if texture != null else default_texture
	$ResourceSprite.modulate.a = 0.3 if depleted else 1.0
	resource_node.progress.visible = state == "GATHERING"
	resource_node.visual.color = Color(0.15, 0.5, 0.2) if wood else Color(0.5, 0.5, 0.55)
	resource_node.visual.modulate.a = 0.3 if depleted else 1.0
	_refresh_label()


func _process(_delta: float) -> void:
	_refresh_label()


func _refresh_label() -> void:
	var state: String = resource_node.state
	var wood: bool = resource_node.resource_type == "wood"
	if state == "GATHERING":
		resource_node.label.text = "Chopping..." if wood else "Mining..."
	elif state == "DEPLETED":
		resource_node.label.text = "Respawning..." if resource_node.player_near else ""
	else:
		resource_node.label.text = "[E] Gather" if resource_node.player_near else ""
