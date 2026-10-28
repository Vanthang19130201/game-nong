extends Node2D

const RockData = preload("res://rock_data.gd")
const TREE_SPECIES_TEXTURES: Dictionary = {
	"oak": preload("res://assets/environment/tree/Tree.png"),
	"autumn": preload("res://assets/environment/tree/autumn_tree.svg"),
	"pine": preload("res://assets/environment/tree/pine_tree.svg"),
	"blossom": preload("res://assets/environment/tree/blossom_tree.svg")
}
@export var tree_texture: Texture2D = preload("res://assets/environment/tree/Tree.png")
@export var tree_region: Rect2 = Rect2(0,2,1248,1230)
@export var tree_size: Vector2 = Vector2(128,160)
@export var tree_ground_y: float = 40.0
@export var rock_texture: Texture2D
@export var rock_textures: Dictionary = {}
@export var stump_texture: Texture2D
@export var depleted_rock_texture: Texture2D = preload("res://assets/environment/rocks/rock_rubble.svg")
@onready var resource_node: Node = get_parent()
@onready var default_texture: Texture2D = $ResourceSprite.texture
var _last_state: String = ""
var _tree_shake_tween: Tween


func _ready() -> void:
	_last_state = resource_node.state
	queue_redraw()


func _draw() -> void:
	if resource_node.resource_type != "wood" or resource_node.state != "DEPLETED":
		return

	# A visible stump remains while the tree's saved respawn timer is active.
	_draw_ellipse(Vector2(0, 39), Vector2(24, 6), Color("3e4e34", 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 39), Vector2(-13, 24), Vector2(-9, 20),
		Vector2(10, 20), Vector2(14, 25), Vector2(18, 39),
		Vector2(11, 37), Vector2(5, 41), Vector2(-3, 38), Vector2(-10, 41)
	]), Color("775039"))
	draw_line(Vector2(-12, 30), Vector2(-10, 39), Color("9a6845"), 3.0, true)
	draw_line(Vector2(10, 29), Vector2(13, 38), Color("5b3f2f"), 3.0, true)
	_draw_ellipse(Vector2(0, 22), Vector2(13, 6), Color("63422f"))
	_draw_ellipse(Vector2(0, 21), Vector2(10, 4), Color("d5ae72"))
	draw_arc(Vector2(0, 21), 6.0, 0.2, TAU - 0.2, 20, Color("9b7049"), 1.4, true)
	draw_arc(Vector2(0, 21), 2.8, 0.2, TAU - 0.2, 16, Color("b98b58"), 1.2, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _fit_tree() -> void:
	var sprite: Sprite2D = $ResourceSprite
	sprite.region_enabled = sprite.texture == tree_texture and tree_region.has_area()
	sprite.region_rect = tree_region
	var art_size: Vector2 = tree_region.size if sprite.region_enabled else sprite.texture.get_size()
	var factor: float = minf(tree_size.x/art_size.x,tree_size.y/art_size.y)
	sprite.scale = Vector2.ONE*factor
	sprite.position = Vector2(0,tree_ground_y-art_size.y*factor/2)

func refresh() -> void:
	var wood: bool = resource_node.resource_type == "wood"
	var state: String = resource_node.state
	var previous_state := _last_state
	var depleted: bool = state == "DEPLETED"
	var texture: Texture2D = tree_texture if wood else rock_texture
	var color: Color = Color(0.15,0.5,0.2)
	var sprite_color: Color = Color.WHITE if wood else $ResourceSprite.modulate
	if wood:
		texture = TREE_SPECIES_TEXTURES.get(resource_node.tree_species, tree_texture)
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
	$ResourceSprite.visible = not (wood and depleted)
	if wood and depleted:
		# artwork_sprite.gd enables the ColorRect fallback when its sprite hides;
		# a depleted tree should show only the stump, never the green placeholder.
		resource_node.visual.hide()
	if wood and $ResourceSprite.texture != null and not depleted:
		_fit_tree()
	if not wood and $ResourceSprite.texture != null:
		# All variants keep the existing 80x80 footprint; only the sprite scales.
		var art_size: Vector2 = $ResourceSprite.texture.get_size()
		var factor := minf(80.0 / art_size.x, 80.0 / art_size.y)
		$ResourceSprite.scale = Vector2.ONE * factor
		$ResourceSprite.position = Vector2(0, 40.0 - art_size.y * factor * 0.5)
	sprite_color.a = 0.3 if depleted else 1.0
	$ResourceSprite.modulate = sprite_color
	resource_node.progress.visible = state == "GATHERING"
	resource_node.visual.color = color
	resource_node.visual.modulate.a = 0.3 if depleted else 1.0
	_refresh_label()
	queue_redraw()
	if wood and state == "GATHERING" and previous_state != "GATHERING":
		_start_tree_shake()
	elif wood and state == "DEPLETED" and previous_state == "GATHERING":
		_stop_tree_shake()
		_spawn_leaf_burst()
	elif state != "GATHERING":
		_stop_tree_shake()
	_last_state = state


func _start_tree_shake() -> void:
	_stop_tree_shake()
	var sprite: Sprite2D = $ResourceSprite
	_tree_shake_tween = create_tween().set_loops()
	_tree_shake_tween.tween_property(sprite, "rotation", -0.025, 0.055)
	_tree_shake_tween.tween_property(sprite, "rotation", 0.025, 0.055)
	_tree_shake_tween.tween_property(sprite, "rotation", 0.0, 0.055)


func _stop_tree_shake() -> void:
	if _tree_shake_tween != null and _tree_shake_tween.is_valid():
		_tree_shake_tween.kill()
	_tree_shake_tween = null
	$ResourceSprite.rotation = 0.0


func _spawn_leaf_burst() -> void:
	var burst := Node2D.new()
	burst.name = "ChopLeafBurst"
	add_child(burst)
	var colors := [Color("78a84b"), Color("a4bf55"), Color("d0bd62"), Color("5d9145")]
	var origin: Vector2 = $ResourceSprite.position + Vector2(0, -40)
	var tween := create_tween()
	for index in range(8):
		var leaf := Polygon2D.new()
		leaf.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(3, -2), Vector2(2, 4),
			Vector2(0, 6), Vector2(-2, 3), Vector2(-3, -2)
		])
		leaf.color = colors[index % colors.size()]
		leaf.position = origin
		burst.add_child(leaf)
		var angle := TAU * float(index) / 8.0 - PI * 0.5
		var spread := Vector2(cos(angle) * 28.0, sin(angle) * 22.0 - 8.0)
		tween.parallel().tween_property(leaf, "position", origin + spread, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(leaf, "rotation", float(index % 2) * 2.4 - 1.2, 0.58)
		tween.parallel().tween_property(leaf, "modulate:a", 0.0, 0.42).set_delay(0.16)
	tween.chain().tween_callback(burst.queue_free)


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
