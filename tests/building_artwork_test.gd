extends SceneTree

const IDS: Array[String] = ["feed_mill", "bakery", "dairy", "spinning_machine", "market_stall", "order_board"]
const TARGETS: Array[Vector2] = [Vector2(160, 120), Vector2(180, 135), Vector2(180, 135), Vector2(170, 125), Vector2(160, 120), Vector2(150, 115)]
const FOOTPRINTS: Array[Rect2] = [Rect2(-64, -36, 128, 72), Rect2(-85, -55, 170, 110), Rect2(-85, -65, 170, 120), Rect2(-85, -55, 170, 110), Rect2(-72, -48, 144, 88), Rect2(-72, -36, 144, 72)]
const AREA_SIZES: Array[Vector2] = [Vector2(144, 100), Vector2(210, 160), Vector2(210, 160), Vector2(210, 160), Vector2(180, 170), Vector2(160, 110)]

var farm: Node
var inv: Node
var manager: Node
var hud: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func artwork(building: Node) -> Sprite2D:
	return building.get_node("Visuals/Sprite2D" if building.name == "OrderBoard" else "Visuals/BuildingSprite")

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func fixture(id: String, paths: Array[String] = [], manual: Texture2D = null) -> Node2D:
	var holder := Node2D.new()
	var sprite: Sprite2D = load("res://artwork_sprite.gd").new()
	sprite.artwork_id = id
	sprite.target_size = Vector2(120, 90)
	sprite.texture_paths = paths
	sprite.texture = manual
	sprite.fallback_paths.append(NodePath("../Placeholder"))
	var fallback := ColorRect.new()
	fallback.name = "Placeholder"
	holder.add_child(fallback)
	holder.add_child(sprite)
	root.add_child(holder)
	return holder

func check_loading() -> void:
	var missing := fixture("__missing_building_artwork__")
	check(missing.get_child(1).texture == null and missing.get_child(0).visible, "missing artwork keeps placeholder")
	missing.free()
	var crop: Texture2D = load("res://assets/crops/wheat/stage_3.png")
	var manual := fixture("bakery", [], crop)
	check(manual.get_child(1).texture == crop and not manual.get_child(0).visible, "manual texture has priority over automatic artwork")
	manual.free()
	var custom := fixture("", ["res://assets/crops/wheat/stage_3.png"])
	check(custom.get_child(1).texture == crop and not custom.get_child(0).visible, "custom path works without an artwork id")
	custom.free()
	var standard := fixture("bakery", ["res://assets/crops/wheat/stage_3.png"])
	check(standard.get_child(1).texture.resource_path.ends_with("bakery.svg"), "standard SVG precedes optional custom paths")
	standard.free()
	var authored: Sprite2D = load("res://artwork_sprite.gd").new()
	authored.texture = crop
	authored.scale = Vector2.ONE * 0.15
	root.add_child(authored)
	check(authored.texture == crop and authored.scale == Vector2.ONE * 0.15, "existing authored scale is preserved when target size is unset")
	authored.free()
	var icon: Control = load("res://item_icon.gd").new()
	icon.size = Vector2(96, 40)
	root.add_child(icon)
	for id in ["wheat", "corn", "carrot"]:
		icon.item_id = id
		check(icon._crop_texture != null and icon._crop_texture.resource_path == "res://assets/crops/%s/stage_3.png" % id, "crop PNG loaded " + id)
	for id in ["wheat_seed", "egg", "milk", "chicken_feed", "bread", "egg_cake", "cream", "butter", "cheese", "river_fish", "axe"]:
		icon.item_id = id
		check(icon._crop_texture == null, "vector icon preserved " + id)
	icon.free()

func check_visual(building: Node2D, index: int, preview: Image) -> void:
	var id := IDS[index]
	var sprite := artwork(building)
	var path := "res://assets/buildings/%s/%s.svg" % [id, id]
	check(sprite.artwork_id == id and sprite.texture != null and sprite.texture.resource_path == path, "scene auto loads SVG " + id)
	check(building.find_children("*", "Sprite2D", true, false).size() == 1, "exactly one building sprite " + id)
	check(sprite.target_size == TARGETS[index] and is_equal_approx(sprite.scale.x, sprite.scale.y), "target size and uniform aspect ratio " + id)
	var fitted_size := sprite.texture.get_size() * sprite.scale
	check(fitted_size.x <= TARGETS[index].x + 0.01 and fitted_size.y <= TARGETS[index].y + 0.01, "artwork fits target " + id)
	check(building.get_node("CollisionShape2D").shape.size == AREA_SIZES[index], "interaction range unchanged " + id)
	check(farm.Placement.bounds(building) == building.global_transform * FOOTPRINTS[index], "placement footprint unchanged " + id)
	check(not sprite.fallback_paths.is_empty(), "fallback paths configured " + id)
	for path_to_fallback in sprite.fallback_paths:
		var fallback := sprite.get_node_or_null(path_to_fallback)
		check(fallback is CanvasItem and not fallback.visible, "fallback exists and is hidden " + id)
	var real_texture := sprite.texture
	sprite.texture = null
	for path_to_fallback in sprite.fallback_paths:
		check(sprite.get_node(path_to_fallback).visible, "removing artwork restores fallback " + id)
	sprite.texture = real_texture
	for path_to_fallback in sprite.fallback_paths:
		check(not sprite.get_node(path_to_fallback).visible, "restoring artwork hides fallback " + id)
	var image := sprite.texture.get_image()
	check(image != null and image.get_size() == Vector2i(256, 192), "SVG imports at native resolution " + id)
	check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(128, 0).a == 0.0, "transparent canvas " + id)
	var used := image.get_used_rect()
	check(used.position.x > 0 and used.position.y > 0 and used.end.x < 256 and used.end.y < 192, "artwork has canvas margins " + id)
	preview.blend_rect(image, Rect2i(0, 0, 256, 192), Vector2i(12 + (index % 3) * 280, 12 + (index / 3) * 216))
	var label: Label = building.get_node("Visuals/Prompt" if id == "market_stall" else ("Label" if id == "order_board" else "StatusLabel"))
	check(label.position.y + label.size.y <= sprite.position.y - sprite.texture.get_height() * sprite.scale.y * 0.5 - 4, "text stays above artwork " + id)
	check(label.visible and label.get_theme_font_size("font_size") == 12 and label.get_theme_constant("outline_size") == 3, "status text remains readable " + id)

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "test uses an isolated save")
	check(manager.reset_game(), "reset test fixture")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	inv.player_level = 20
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.normalize_exp()
	for id in ["feed_mill", "bakery"]:
		check(inv.buy_building(id), "purchase existing building " + id)
	# Placement purchases are covered by the existing Dairy/Spinning regressions.
	inv.owns_dairy = true
	inv.owns_spinning_machine = true
	inv.inventory_changed.emit()
	await create_timer(0.15).timeout
	check_loading()
	var preview := Image.create(840, 432, false, Image.FORMAT_RGBA8)
	preview.fill(Color("e5dec8"))
	for index in range(IDS.size()):
		var id := IDS[index]
		var building: Node2D = farm.get_node("OrderBoard" if id == "order_board" else "MarketStall") if id in ["order_board", "market_stall"] else manager.buildings[id]
		check_visual(building, index, preview)
		hud.close_all_panels()
		player.global_position = building.global_position + Vector2(0, 64 if id == "market_stall" else 0)
		await create_timer(0.12).timeout
		check(building.can_interact(), "player can reach building " + id)
		check(player._nearest_interactable() == building, "E selects the intended fixture " + id)
		await key(KEY_E)
		match id:
			"feed_mill": check(hud.active_station == building and hud.feed_queue.visible, "E opens Feed Mill")
			"bakery": check(hud.bakery_panel.visible, "E opens Bakery")
			"dairy": check(hud.dairy_panel.visible, "E opens Dairy")
			"spinning_machine": check(hud.spinning_machine_panel.visible, "E opens Spinning Machine")
			"market_stall": check(hud.market_stall_panel.visible and hud.market_stall_panel.active_stall == building, "E opens Market Stall")
			"order_board": check(hud.order_panel.visible, "E opens Order Board")
		await key(KEY_ESCAPE)
		check(not hud.blocks_world_input(), "ESC closes building panel " + id)
	check(preview.save_png("res://building-artwork-preview.png") == OK, "save artwork contact sheet")
	check(manager.reset_game(), "cleanup isolated fixture")
	print("PASS: building_artwork (six SVGs, fallback, aspect ratio, footprints, crop icons, E and panels)")
	quit()
