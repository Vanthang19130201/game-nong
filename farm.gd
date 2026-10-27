extends Node2D

# Keep pet spawning here, separate from each pet's movement script.
const FarmData = preload("res://farm_data.gd")
const SOIL_SCENE = preload("res://soil_plot.tscn")
const DOG_SCENE = preload("res://dog.tscn")
const LAND_SCENE = preload("res://land_zone.tscn")
const AnimalGroup = preload("res://animal_group.gd")
const Placement = preload("res://building_placement.gd")
var dog: CharacterBody2D
var decoration_manager: Node
var animal_groups: Dictionary = {}

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
	_place_resources()
	Inventory.inventory_changed.connect(_update_animals)
	_update_animals()
	Inventory.inventory_changed.connect(_update_pets)
	_update_pets()


func _place_resources() -> void:
	# Keep resource positions unless they overlap restored objects or the player.
	# Relocating a resource within its zone never changes its saved cooldown.
	for resource in SaveManager.resources.values():
		if _resource_position_is_clear(resource, resource.global_position):
			continue
		var zone: String = SaveManager.LandData.zone_at(resource.global_position)
		var area: Rect2 = SaveManager.LandData.ZONES[zone]["area"]
		var found: bool = false
		for y in range(int(area.position.y)+64,int(area.end.y)-32,64):
			for x in range(int(area.position.x)+64,int(area.end.x)-32,64):
				var point := Vector2(x,y)
				var footprint: Rect2 = Placement.bounds(resource)
				footprint.position += point-resource.global_position
				if area.encloses(footprint) and _resource_position_is_clear(resource, point):
					resource.global_position = point
					found = true
					break
			if found:
				break
		if not found:
			# A completely filled zone cannot safely accept another resource.
			resource.zone_id = "unplaced"
		resource._update_zone(true)


func _resource_position_is_clear(resource: Node2D, point: Vector2) -> bool:
	if not Placement.can_place(resource, point, false):
		return false
	var footprint := Placement.bounds(resource)
	footprint.position += point - resource.global_position
	var player_shape: CollisionShape2D = $Player/CollisionShape2D
	var player_bounds: Rect2 = player_shape.global_transform * player_shape.shape.get_rect()
	return not footprint.intersects(player_bounds.grow(8.0))


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
		var owned: bool = info.get("always_owned", false) or (Inventory.has_dog_house if id == "dog_house" else Inventory.owns_building(id))
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
		if not info.get("preserve_scale", false):
			building.scale = Vector2.ONE
		building.z_index = maxi(1, building.z_index)
		if id == "dog_house":
			dog_house = building
	_restore_owned_land_positions()


func _update_animals() -> void:
	# Only counts are saved. World entities are reconstructed around their home.
	for kind in Inventory.Progression.ANIMALS:
		var id: String = Inventory.Progression.ANIMALS[kind]["building"]
		var home = SaveManager.buildings.get(id)
		if not is_instance_valid(home):
			continue
		var group = animal_groups.get(kind)
		if not is_instance_valid(group):
			group = Node2D.new()
			group.set_script(AnimalGroup)
			group.name = "Chickens" if kind == "chicken" else "Cows"
			group.animal_type = kind
			group.wander_radius = 150.0 if kind == "chicken" else 170.0
			group.home = home
			animal_groups[kind] = group
			add_child(group)
		group.home = home
		group.sync_count()


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
