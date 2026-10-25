extends Node2D

# Keep pet spawning here, separate from each pet's movement script.
const DOG_SCENE = preload("res://dog.tscn")
var dog: CharacterBody2D

@onready var dog_home: Node2D = $DogHomePoint


func _ready() -> void:
	Inventory.inventory_changed.connect(_update_pets)
	_update_pets()


func _update_pets() -> void:
	if Inventory.has_dog:
		if not is_instance_valid(dog):
			dog = DOG_SCENE.instantiate()
			dog.home_point = dog_home
			dog.position = dog_home.position
			add_child(dog)
	elif is_instance_valid(dog):
		remove_child(dog)
		dog.queue_free()
		dog = null