extends Node2D

# Keep pet spawning here, separate from each pet's movement script.
const FarmData = preload("res://farm_data.gd")
const SOIL_SCENE = preload("res://soil_plot.tscn")
const DOG_SCENE = preload("res://dog.tscn")
const COW_SHED_SCENE = preload("res://cow_shed.tscn")
const DEFAULT_COW_SHED_POSITION = Vector2(900, 1020)
var dog: CharacterBody2D

@onready var dog_home: Node2D = $DogHomePoint
@onready var dog_house: Node2D = $DogHouse


func _ready() -> void:
	_create_farm_grid()
	Inventory.inventory_changed.connect(ensure_cow_shed_exists)
	ensure_cow_shed_exists()
	Inventory.inventory_changed.connect(_update_pets)
	_update_pets()


func ensure_cow_shed_exists() -> void:
	# Normally main.tscn supplies this node. Recover it if a world omits it.
	var shed = get_node_or_null("CowShed")
	if shed == null:
		if not Inventory.owns_cow_shed:
			return
		shed = COW_SHED_SCENE.instantiate()
		shed.name = "CowShed"
		shed.position = DEFAULT_COW_SHED_POSITION
		add_child(shed)
	# There is no building-position save or Edit Mode yet: use one safe location.
	shed.position = DEFAULT_COW_SHED_POSITION
	shed.scale = Vector2.ONE
	shed.visible = Inventory.owns_cow_shed


func _update_pets() -> void:
	dog_house.visible = Inventory.has_dog_house
	var home: Node2D = dog_house if Inventory.has_dog_house else dog_home
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
