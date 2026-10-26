extends Node2D

@export var warehouse_texture: Texture2D

func _ready() -> void:
	$BuildingSprite.texture = warehouse_texture
	$BuildingSprite.visible = warehouse_texture != null
	$Placeholder.visible = warehouse_texture == null
	if warehouse_texture != null:
		$BuildingSprite.scale = Vector2(160, 110) / warehouse_texture.get_size()

func _process(_delta: float) -> void:
	$Prompt.text = tr("WAREHOUSE_PROMPT") if get_parent().can_interact() else ""
