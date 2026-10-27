extends Node2D

@export var warehouse_texture: Texture2D

func _ready() -> void:
	if warehouse_texture != null:
		$BuildingSprite.texture = warehouse_texture
		var size := warehouse_texture.get_size()
		if size.x > 0.0 and size.y > 0.0:
			var target: Vector2 = $BuildingSprite.target_size
			$BuildingSprite.scale = Vector2.ONE * minf(target.x / size.x, target.y / size.y)

func _process(_delta: float) -> void:
	$Prompt.text = tr("WAREHOUSE_PROMPT") if get_parent().can_interact() else ""
