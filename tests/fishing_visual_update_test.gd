extends SceneTree

const EXPECTED_WEIGHTS: Dictionary = {
	"tilapia": 22, "perch": 18, "catfish": 16, "loach": 14,
	"snakehead": 12, "salmon": 8, "koi_orange": 7, "koi_gold": 3
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
	check(data.CATCHABLE_FISH_IDS.size() == 8, "exactly eight new fish are catchable")
	for fish_id in data.CATCHABLE_FISH_IDS:
		var info: Dictionary = data.FISH[fish_id]
		check(int(info.get("weight", 0)) == int(EXPECTED_WEIGHTS[fish_id]), "configured weight for " + fish_id)
		check(ResourceLoader.exists(str(info.get("asset_path", ""))), "source artwork exists for " + fish_id)
		check(fish_id in inventory.BARN_ITEMS and inventory.get(fish_id) == 0, "Barn/save inventory supports " + fish_id)
		total += int(info["weight"])
	check(total == 100, "catch weights total 100")
	for fish_id in data.LEGACY_FISH_IDS:
		check(data.is_legacy_fish(fish_id) and fish_id in inventory.BARN_ITEMS, "legacy fish remains safe and sellable: " + fish_id)
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
	print("PASS: fishing_visual_update")
	quit()
