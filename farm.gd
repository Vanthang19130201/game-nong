extends Node2D

# Keep pet spawning here, separate from each pet's movement script.
const FarmData = preload("res://farm_data.gd")
const SOIL_SCENE = preload("res://soil_plot.tscn")
const DOG_SCENE = preload("res://dog.tscn")
const LAND_SCENE = preload("res://land_zone.tscn")
const FIELD_VISUAL_SCRIPT = preload("res://farm_field_visual.gd")
const AnimalGroup = preload("res://animal_group.gd")
const Placement = preload("res://building_placement.gd")
const FishingWaterZone = preload("res://fishing_water_zone.gd")
const WATER_AMBIENCE_SCRIPT = preload("res://pond_ambience.gd")

var dog: CharacterBody2D # legacy alias: points at Shiba when owned.
var dogs_by_id: Dictionary = {}
var decoration_manager: Node
var animal_groups: Dictionary = {}

@onready var dog_home: Node2D = $DogHomePoint
@onready var dog_house: Node2D = get_node_or_null("DogHouse")


func _ready() -> void:
	_create_farm_grid()
	_create_field_visual()
	_setup_fishing_waters()

	for id in SaveManager.LandData.ZONES:
		var zone = LAND_SCENE.instantiate()
		zone.zone_id = id
		zone.name = id
		add_child(zone)

	Inventory.inventory_changed.connect(_update_buildings)
	_update_buildings()

	decoration_manager = Node.new()
	decoration_manager.name = "DecorationManager"
	decoration_manager.set_script(
		preload("res://decoration_manager.gd")
	)
	add_child(decoration_manager)

	_place_resources()
	var dig_manager := Node.new()
	dig_manager.name = "DigSpotManager"
	dig_manager.set_script(preload("res://dig_spot_manager.gd"))
	add_child(dig_manager)
	dig_manager.setup(self)
	var wildlife_visual := Node2D.new()
	wildlife_visual.name = "WildlifeVisual"
	wildlife_visual.set_script(preload("res://wildlife_visual.gd"))
	add_child(wildlife_visual)
	var event_visual := Node2D.new()
	event_visual.name = "FarmEventVisual"
	event_visual.set_script(preload("res://farm_event_visual.gd"))
	add_child(event_visual)
	var merchant_visual := Node2D.new()
	merchant_visual.name = "WanderingMerchantVisual"
	merchant_visual.set_script(preload("res://wandering_merchant_visual.gd"))
	add_child(merchant_visual)

	Inventory.inventory_changed.connect(_update_animals)
	_update_animals()

	Inventory.inventory_changed.connect(_update_pets)
	_update_pets()


func _place_resources() -> void:
	# Keep resource positions unless they overlap restored objects or the player.
	# Relocating a resource within its zone never changes its saved cooldown.
	for resource in SaveManager.resources.values():
		if _resource_position_is_clear(
			resource,
			resource.global_position
		):
			continue

		var zone: String = SaveManager.LandData.zone_at(
			resource.global_position
		)

		var area: Rect2 = SaveManager.LandData.ZONES[
			zone
		]["area"]

		var found: bool = false

		for y in range(
			int(area.position.y) + 64,
			int(area.end.y) - 32,
			64
		):
			for x in range(
				int(area.position.x) + 64,
				int(area.end.x) - 32,
				64
			):
				var point := Vector2(x, y)

				var footprint: Rect2 = Placement.bounds(
					resource
				)

				footprint.position += (
					point
					- resource.global_position
				)

				if (
					area.encloses(footprint)
					and _resource_position_is_clear(
						resource,
						point
					)
				):
					resource.global_position = point
					found = true
					break

			if found:
				break

		if not found:
			# A completely filled zone cannot safely accept another resource.
			resource.zone_id = "unplaced"

		resource._update_zone(true)


func _resource_position_is_clear(
	resource: Node2D,
	point: Vector2
) -> bool:
	if not Placement.can_place(
		resource,
		point,
		false
	):
		return false

	var footprint := Placement.bounds(resource)

	footprint.position += (
		point
		- resource.global_position
	)

	var player_shape: CollisionShape2D = (
		$Player/CollisionShape2D
	)

	var player_bounds: Rect2 = (
		player_shape.global_transform
		* player_shape.shape.get_rect()
	)

	return not footprint.intersects(
		player_bounds.grow(8.0)
	)


func _restore_owned_land_positions() -> void:
	var changed: bool = false

	for id in SaveManager.buildings:
		var building = SaveManager.buildings[id]

		if (
			not is_instance_valid(building)
			or not building.visible
		):
			continue

		if SaveManager.LandData.owns_rect(
			Placement.bounds(building),
			SaveManager.unlocked_land_zones
		):
			continue

		var destination: Vector2 = (
			FarmData.BUILDINGS[id]["position"]
		)

		if not Placement.can_place(
			building,
			destination
		):
			# Deterministic fallback for legacy farms whose defaults are occupied.
			var found: bool = false

			for y in range(
				128,
				1472,
				64
			):
				for x in range(
					128,
					1664,
					64
				):
					var point := Vector2(
						x,
						y
					)

					if Placement.can_place(
						building,
						point
					):
						destination = point
						found = true
						break

				if found:
					break

		building.global_position = destination

		SaveManager.building_positions[id] = (
			building.position
		)

		changed = true

	if changed:
		SaveManager.save_game.call_deferred()


func ensure_cow_shed_exists() -> void:
	_update_buildings()


func _update_buildings() -> void:
	for id in FarmData.BUILDINGS:
		var info: Dictionary = (
			FarmData.BUILDINGS[id]
		)

		var owned: bool = (
			info.get("always_owned", false)
			or (
				Inventory.has_dog_house
				if id == "dog_house"
				else Inventory.owns_building(id)
			)
		)

		var building = get_node_or_null(
			info["node"]
		)

		if building == null and owned:
			var scene = (
				load(info["scene"])
				if not info["scene"].is_empty()
				else null
			)

			if not (
				scene is PackedScene
			):
				push_warning(
					"Missing building scene: "
					+ id
				)
				continue

			building = scene.instantiate()
			building.name = info["node"]

			add_child(building)

		if building == null:
			continue

		if not SaveManager.register_building(
			id,
			building
		):
			continue

		# The existing Dog House stays on the map as a visual landmark.
		# Ownership and pet behavior continue to use Inventory.has_dog_house.
		building.visible = owned

		if not info.get(
			"preserve_scale",
			false
		):
			building.scale = Vector2.ONE

		building.z_index = maxi(
			1,
			building.z_index
		)

		if id == "dog_house":
			dog_house = building

	_restore_owned_land_positions()


func _update_animals() -> void:
	# Only counts are saved. World entities are reconstructed around their home.
	for kind in Inventory.Progression.ANIMALS:
		var id: String = (
			Inventory.Progression
			.ANIMALS[kind]["building"]
		)

		var home = SaveManager.buildings.get(
			id
		)

		if not is_instance_valid(home):
			continue

		var group = animal_groups.get(
			kind
		)

		if not is_instance_valid(group):
			group = Node2D.new()

			group.set_script(
				AnimalGroup
			)

			group.name = kind.capitalize() + "Group"

			group.animal_type = kind

			group.wander_radius = 125.0 if kind == "chicken" else 145.0 if kind == "cow" else 130.0 if kind == "pig" else 135.0

			group.home = home

			animal_groups[kind] = group

			add_child(group)

		group.home = home
		group.sync_count()


func _update_pets() -> void:
	var home: Node2D = (
		dog_house
		if (
			Inventory.has_dog_house
			and is_instance_valid(dog_house)
		)
		else dog_home
	)

	var profiles: Dictionary = SaveManager.dog_profiles()
	for pet_id in dogs_by_id.keys():
		if profiles.has(pet_id) and is_instance_valid(dogs_by_id[pet_id]):
			continue
		var stale: Node = dogs_by_id[pet_id]
		if is_instance_valid(stale):
			stale.queue_free()
		dogs_by_id.erase(pet_id)
	for pet_id in profiles:
		var runtime: CharacterBody2D = dogs_by_id.get(pet_id)
		var slot: int = preload("res://dog_data.gd").DOG_IDS.find(pet_id)
		if not is_instance_valid(runtime):
			runtime = DOG_SCENE.instantiate()
			runtime.name = pet_id.capitalize()
			add_child(runtime)
			runtime.wander_bounds = $Player.farm_bounds
			runtime.configure(pet_id, profiles[pet_id], home, maxi(slot, 0))
			# New dogs use separated yard points. Returning dogs resume their last
			# safe farm position instead of piling up at the Dog House after reload.
			runtime.global_position = runtime.restored_position()
			dogs_by_id[pet_id] = runtime
		else:
			runtime.set_home_point(home)
			runtime.wander_bounds = $Player.farm_bounds
			runtime.refresh_profile(profiles[pet_id])
	dog = dogs_by_id.get("dog_shiba") if dogs_by_id.has("dog_shiba") else (dogs_by_id.values()[0] if not dogs_by_id.is_empty() else null)


func _create_farm_grid() -> void:
	for number in range(
		1,
		FarmData.MAX_PLOTS + 1
	):
		var id: String = (
			FarmData.plot_id(number)
		)

		var plot = SaveManager.plots.get(
			id
		)

		if not is_instance_valid(plot):
			plot = SOIL_SCENE.instantiate()

			plot.name = (
				"SoilPlot%d"
				% number
			)

			plot.plot_id = id

			plot.position = (
				FarmData.plot_position(
					number
				)
			)

			add_child(plot)


func _create_field_visual() -> void:
	if get_node_or_null("FarmFieldVisual") != null:
		return
	var field_visual := Node2D.new()
	field_visual.name = "FarmFieldVisual"
	# Keep the shared dirt bed behind plot tiles and the Player.
	field_visual.z_index = -2
	field_visual.set_script(FIELD_VISUAL_SCRIPT)
	add_child(field_visual)
	field_visual.configure(SaveManager.plots)


func _setup_fishing_waters() -> void:

	var river := FishingWaterZone.new()

	river.name = "RiverFishingWater"
	river.water_id = "river"
	river.shape_mode = "rect"

	# Sông thật trong main.tscn:
	# x = 1800 -> 1940
	# y = 0 -> 2400
	river.zone_size = Vector2(
		140,
		2400
	)

	river.draw_visual = false

	# Sông đã có RiverWalls nên không cần tạo collision nữa.
	river.block_player = false

	# Tâm chính xác của sông.
	river.position = Vector2(
		1870,
		1200
	)

	add_child(river)
	_add_water_ambience(river, "RiverAmbience")


	# ============================================
	# HỒ CÂU CÁ
	# ============================================

	var pond := FishingWaterZone.new()

	pond.name = "FishingPond"
	pond.water_id = "pond"
	pond.shape_mode = "polygon"
	pond.zone_polygon = PackedVector2Array([
		Vector2(-34, -700), Vector2(34, -710),
		Vector2(86, -680), Vector2(119, -622),
		Vector2(131, -523), Vector2(115, -408),
		Vector2(146, -278), Vector2(132, -127),
		Vector2(151, 20), Vector2(138, 180),
		Vector2(120, 341), Vector2(91, 482),
		Vector2(54, 610), Vector2(0, 665),
		Vector2(-68, 640), Vector2(-112, 575),
		Vector2(-138, 470), Vector2(-126, 335),
		Vector2(-151, 190), Vector2(-133, 35),
		Vector2(-151, -125), Vector2(-132, -285),
		Vector2(-148, -440), Vector2(-123, -560),
		Vector2(-90, -650)
	])

	pond.draw_visual = true
	pond.block_player = true
	pond.water_color = Color("68aeb0")
	pond.deep_water_color = Color("427f8d")
	pond.bank_color = Color("c6ad78")

	pond.position = Vector2(
		2240,
		1190
	)

	add_child(pond)

	_add_water_ambience(pond, "PondAmbience")


	# ============================================
	# TÊN HỒ
	# ============================================

	var label := Label.new()

	label.name = "FishingPondLabel"
	label.text = "Hồ câu cá"

	label.theme = preload(
		"res://assets/ui/ui_theme.tres"
	)

	label.position = Vector2(
		2098,
		455
	)

	label.custom_minimum_size = Vector2(
		130,
		24
	)

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	label.add_theme_font_size_override(
		"font_size",
		13
	)

	label.add_theme_color_override(
		"font_color",
		Color("fff2cf")
	)

	label.add_theme_color_override(
		"font_outline_color",
		Color("4a3525")
	)

	label.add_theme_constant_override(
		"outline_size",
		3
	)

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	label.z_index = 2

	add_child(label)


func _add_water_ambience(water: Node2D, node_name: String) -> void:
	var ambience := Node2D.new()
	ambience.name = node_name
	ambience.set_script(WATER_AMBIENCE_SCRIPT)
	water.add_child(ambience)
