extends "res://production_panel.gd"

var active_dairy: Node:
	get: return active_machine

func _init() -> void:
	machine_kind = "dairy"
