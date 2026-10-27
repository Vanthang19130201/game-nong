extends "res://production_panel.gd"

var active_bakery: Node:
	get: return active_machine

func _init() -> void:
	machine_kind = "bakery"
