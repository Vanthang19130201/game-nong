extends Node2D

# Keep pet spawning here, separate from each pet's movement script.
const FarmData = preload("res://farm_data.gd")
const SOIL_SCENE = preload("res://soil_plot.tscn")
const DOG_SCENE = preload("res://dog.tscn")
const LAND_SCENE = preload("res://land_zone.tscn")
const Placement = preload("res://building_placement.gd")
var dog: CharacterBody2D
var decoration_manager: Node

@onready var dog_home: Node2D = $DogHomePoint
@onready var dog_house: Node2D = get_node_or_null("DogHouse")


func _ready() -> void:
	_create_farm_grid()
	for id in SaveManager.LandData.ZONES:
		var zone = LAND_SCENE.instantiate()
		zone.zone_id = id
		zone.name = id
		add_child(zone)
	Inventory.inventory_changed.connect(_update_buildings)
	_update_buildings()
	decoration_manager = Node.new()
	decoration_manager.name = "DecorationManager"
	decoration_manager.set_script(preload("res://decoration_manager.gd"))
	add_child(decoration_manager)
	Inventory.inventory_changed.connect(_update_pets)
	_update_pets()


func _restore_owned_land_positions() -> void:
	var changed: bool = false
	for id in SaveManager.buildings:
		var building = SaveManager.buildings[id]
		if not is_instance_valid(building) or not building.visible:
			continue
		if SaveManager.LandData.owns_rect(Placement.bounds(building), SaveManager.unlocked_land_zones):
			continue
		var destination: Vector2 = FarmData.BUILDINGS[id]["position"]
		if not Placement.can_place(building,destination):
			# Deterministic fallback for legacy farms whose defaults are occupied.
			var found: bool = false
			for y in range(128,1472,64):
				for x in range(128,1664,64):
					var point := Vector2(x,y)
					if Placement.can_place(building,point):
						destination = point
						found = true
						break
				if found:
					break
		building.global_position = destination
		SaveManager.building_positions[id] = building.position
		changed = true
	if changed:
		SaveManager.save_game.call_deferred()


func ensure_cow_shed_exists() -> void:
	_update_buildings()


func _update_buildings() -> void:
	for id in FarmData.BUILDINGS:
		var info: Dictionary = FarmData.BUILDINGS[id]
		var owned: bool = id == "house" or (Inventory.has_dog_house if id == "dog_house" else Inventory.owns_building(id))
		var building = get_node_or_null(info["node"])
		if building == null and owned:
			var scene = load(info["scene"]) if not info["scene"].is_empty() else null
			if not (scene is PackedScene):
				push_warning("Missing building scene: " + id)
				continue
			building = scene.instantiate()
			building.name = info["node"]
			add_child(building)
		if building == null:
			continue
		if not SaveManager.register_building(id, building):
			continue
		building.visible = owned
		building.scale = Vector2.ONE
		building.z_index = maxi(1, building.z_index)
		if id == "dog_house":
			dog_house = building
	_restore_owned_land_positions()


func _update_pets() -> void:
	var home: Node2D = dog_house if Inventory.has_dog_house and is_instance_valid(dog_house) else dog_home
	if Inventory.has_dog:
		if not is_instance_valid(dog):
			dog = DOG_SCENE.instantiate()
			dog.home_point = home
			dog.position = home.position
			add_child(dog)
		elif dog.home_point != home:
			dog.set_home_point(home)
	elif is_instance_valid(dog):
		remove_child(dog)
		dog.queue_free()
		dog = null
	if is_instance_valid(dog):
		dog.wander_bounds = $Player.farm_bounds

func _create_farm_grid() -> void:
	for number in range(1, FarmData.MAX_PLOTS + 1):
		var id: String = FarmData.plot_id(number)
		var plot = SaveManager.plots.get(id)
		if not is_instance_valid(plot):
			plot = SOIL_SCENE.instantiate()
			plot.name = "SoilPlot%d" % number
			plot.plot_id = id
			plot.position = FarmData.plot_position(number)
			add_child(plot)
		else:
			plot.position = FarmData.plot_position(number)
