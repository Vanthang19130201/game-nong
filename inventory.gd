extends Node

signal inventory_changed

var wheat_seed: int = 10
var wheat: int = 0
var coins: int = 100


func use_wheat_seed() -> bool:
	if wheat_seed <= 0:
		print("Het hat giong!")
		return false

	wheat_seed -= 1
	inventory_changed.emit()

	print("Hat giong con lai: ", wheat_seed)

	return true


func add_wheat(amount: int = 1):
	wheat += amount
	inventory_changed.emit()

	print("Lua hien tai: ", wheat)


func add_coins(amount: int):
	coins += amount
	inventory_changed.emit()


func remove_coins(amount: int) -> bool:
	if coins < amount:
		return false

	coins -= amount
	inventory_changed.emit()

	return true
