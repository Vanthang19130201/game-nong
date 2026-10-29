extends SceneTree

const EXPECTED_WEIGHTS: Dictionary = {
	"tilapia": 21, "perch": 17, "catfish": 15, "loach": 13,
	"snakehead": 11, "salmon": 8, "koi_orange": 7, "koi_gold": 3, "moon_fish": 5
}

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, description: String) -> void:
	if not value:
		push_error("TEST FAILED: " + description)
		quit(1)

func run_checks() -> void:
	var data_script: Script = load("res://fishing_data.gd")
	var data: Variant = data_script.new()
	var inventory_script: Script = load("res://inventory.gd")
	var inventory: Variant = inventory_script.new()
	var total: int = 0
	check(data.CATCHABLE_FISH_IDS.size() == 9, "exactly nine fish are catchable")
	for fish_id in data.CATCHABLE_FISH_IDS:
		var info: Dictionary = data.FISH[fish_id]
		check(int(info.get("weight", 0)) == int(EXPECTED_WEIGHTS[fish_id]), "configured weight for " + fish_id)
		check(ResourceLoader.exists(str(info.get("asset_path", ""))), "source artwork exists for " + fish_id)
		check(fish_id in inventory.BARN_ITEMS and inventory.get(fish_id) == 0, "Barn/save inventory supports " + fish_id)
		total += int(info["weight"])
	check(total == 100, "catch weights total 100")
	var icon_script: Script = load("res://item_icon.gd")
	for fish_id in data.CATCHABLE_FISH_IDS:
		var icon: Control = icon_script.new()
		root.add_child(icon)
		icon.item_id = fish_id
		await process_frame
		check(icon._visual_texture != null, "item icon loads provided art: " + fish_id)
		icon.queue_free()
	var spot_script: Script = load("res://fishing_spot.gd")
	var spot: Variant = spot_script.new()
	spot.rng.seed = 1997
	var rolls: Dictionary = {}
	for fish_id in data.CATCHABLE_FISH_IDS:
		rolls[fish_id] = 0
	for sample in range(10000):
		var rolled: String = spot._roll_fish()
		check(rolled in data.CATCHABLE_FISH_IDS, "no legacy ID is rolled")
		rolls[rolled] += 1
	for fish_id in data.CATCHABLE_FISH_IDS:
		var expected: float = float(EXPECTED_WEIGHTS[fish_id]) / 100.0
		check(absf(float(rolls[fish_id]) / 10000.0 - expected) < 0.025, "sampled probability for " + fish_id)
	var visual_script: Script = load("res://fishing_visual.gd")
	var visual: Variant = visual_script.new()
	root.add_child(visual)
	visual.set_cast_origin(Vector2(80, 80))
	visual.bobber_position = Vector2(120, 220)
	visual.set_caught_fish("moon_fish")
	visual.show_caught()
	await process_frame
	var caught_sprite: Sprite2D = visual.get_node_or_null("CaughtFishSprite") as Sprite2D
	check(caught_sprite != null, "caught fish uses its own Sprite2D node")
	check(caught_sprite.texture != null and caught_sprite.visible and caught_sprite.texture.resource_path.ends_with("moon_fish.png"), "success shows the exact Moon Fish artwork")
	check(caught_sprite.position.distance_to(Vector2(120, 220)) > 10.0, "caught fish is lifted off the water toward Player")
	visual.show_failed()
	await process_frame
	check(not caught_sprite.visible, "failed fishing hides the caught fish sprite")
	visual.hide_visual()
	check(not caught_sprite.visible, "closing or cancelling fishing hides the caught fish sprite")
	visual.queue_free()
	print("PASS: fishing_visual_update")
	quit()
