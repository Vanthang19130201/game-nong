extends SceneTree

const AnimalData = preload("res://animal_data.gd")
const ProgressionData = preload("res://progression_data.gd")
const BakeryData = preload("res://bakery_data.gd")
const DairyData = preload("res://dairy_data.gd")
const SpinningData = preload("res://spinning_machine_data.gd")
const LoomData = preload("res://loom_data.gd")
const LanternScript = preload("res://player_lantern.gd")


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)


func run_checks() -> void:
	var now := 50000.0
	for animal_type in ["chicken", "cow", "sheep", "pig"]:
		var data: Dictionary = AnimalData.SPECIES[animal_type]
		var baby := float(data["baby_seconds"])
		var young := float(data["young_seconds"])
		check(AnimalData.stage_for(animal_type, now, now) == 1, animal_type + " starts as baby")
		check(AnimalData.stage_for(animal_type, now - baby - 0.1, now) == 2, animal_type + " progresses to young")
		check(AnimalData.stage_for(animal_type, now - baby - young - 0.1, now) == 3, animal_type + " progresses to adult")
		check(AnimalData.stage_for(animal_type, AnimalData.adult_born_at(animal_type, now), now) == 3, animal_type + " old-save timestamp restores adult")
		check(AnimalData.scale_for(animal_type, 1) < AnimalData.scale_for(animal_type, 2), animal_type + " baby is visibly smaller")
		check(AnimalData.scale_for(animal_type, 2) < AnimalData.scale_for(animal_type, 3), animal_type + " young is visibly smaller")
	check(float(ProgressionData.PRODUCTS["chicken_coop"]["time"]) < float(ProgressionData.PRODUCTS["cow_shed"]["time"]), "chicken production remains faster than cow")
	check(float(ProgressionData.PRODUCTS["cow_shed"]["time"]) < float(ProgressionData.PRODUCTS["sheep_barn"]["time"]), "cow production remains faster than sheep")
	check(float(ProgressionData.PRODUCTS["sheep_barn"]["time"]) < float(ProgressionData.PRODUCTS["pig_pen"]["time"]), "pig production is slowest")
	check(float(BakeryData.RECIPES["bread"]["time"]) >= 45.0, "bakery timers are no longer instant")
	check(float(DairyData.RECIPES["cream"]["time"]) >= 60.0, "dairy timers are no longer instant")
	check(float(SpinningData.RECIPES["cotton_thread"]["time"]) >= 90.0, "spinning timers are no longer instant")
	check(float(LoomData.RECIPES["cotton_cloth"]["time"]) >= 180.0, "loom timers are no longer instant")
	var lantern: Node2D = LanternScript.new()
	get_root().add_child(lantern)
	GameClock.minutes = 18.0 * 60.0
	GameClock.changed.emit()
	check(lantern.active_at_night and lantern.visible, "lantern turns on at 18:00")
	GameClock.minutes = 6.0 * 60.0
	GameClock.changed.emit()
	check(not lantern.active_at_night and not lantern.visible, "lantern turns off at 06:00")
	lantern.queue_free()
	print("PASS: life_cycle_presentation")
	quit()
