extends PanelContainer

const DogData = preload("res://dog_data.gd")

var hud: Node
var body: VBoxContainer
var title: Label
var name_dialog: ConfirmationDialog
var name_input: LineEdit
var pending_pet_id: String = ""

func _ready() -> void:
	name = "DogHousePanel"
	theme = preload("res://assets/ui/ui_theme.tres")
	theme_type_variation = &"GamePanel"
	z_index = 32
	custom_minimum_size = Vector2(640, 460)
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -320
	offset_top = -230
	offset_right = 320
	offset_bottom = 230
	visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	name_dialog = ConfirmationDialog.new()
	name_dialog.title = tr("DOG_NAME_TITLE")
	name_dialog.ok_button_text = tr("DOG_SAVE_NAME")
	name_dialog.min_size = Vector2i(360, 150)
	name_input = LineEdit.new()
	name_input.placeholder_text = tr("DOG_NAME_PLACEHOLDER")
	name_input.max_length = 16
	name_dialog.add_child(name_input)
	name_dialog.confirmed.connect(_confirm_name)
	add_child(name_dialog)
	get_viewport().size_changed.connect(_fit)
	_fit()

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false
	name_dialog.hide()

func _fit() -> void:
	var view := get_viewport_rect().size
	var width := minf(640.0, view.x - 32.0)
	var height := minf(460.0, view.y - 32.0)
	custom_minimum_size = Vector2(width, height)
	offset_left = -width * 0.5
	offset_top = -height * 0.5
	offset_right = width * 0.5
	offset_bottom = height * 0.5

func refresh() -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		child.queue_free()
	var heading := HBoxContainer.new()
	body.add_child(heading)
	title = Label.new()
	title.text = tr("DOG_HOUSE")
	title.theme_type_variation = &"SectionTitle"
	heading.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var close_button := Button.new()
	close_button.text = tr("UI_CLOSE")
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	var intro := Label.new()
	intro.text = tr("DOG_HOUSE_INTRO")
	intro.theme_type_variation = &"MutedLabel"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 7)
	scroll.add_child(cards)
	var profiles: Dictionary = SaveManager.dog_profiles()
	var available_title := Label.new()
	available_title.text = tr("DOG_AVAILABLE")
	available_title.theme_type_variation = &"SectionTitle"
	cards.add_child(available_title)
	for variant_id in DogData.DOG_VARIANTS:
		if not profiles.has(str(DogData.DOG_VARIANTS[variant_id]["pet_id"])):
			cards.add_child(_dog_card(variant_id, profiles))
	var owned_title := Label.new()
	owned_title.text = tr("DOG_OWNED_SECTION")
	owned_title.theme_type_variation = &"SectionTitle"
	cards.add_child(owned_title)
	for variant_id in DogData.DOG_VARIANTS:
		if profiles.has(str(DogData.DOG_VARIANTS[variant_id]["pet_id"])):
			cards.add_child(_dog_card(variant_id, profiles))
	var food_row := HBoxContainer.new()
	body.add_child(food_row)
	var food_info := Label.new()
	food_info.text = "%s: %d   ·   %s" % [tr("DOG_FOOD"), Inventory.dog_food, tr("UI_PRICE_COINS") % DogData.DOG_FOOD_PRICE]
	food_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_row.add_child(food_info)
	for amount in [1, 5]:
		var buy_food := Button.new()
		buy_food.text = tr("DOG_BUY_FOOD") + " %d · %d" % [amount, DogData.DOG_FOOD_PRICE * amount]
		buy_food.disabled = Inventory.coins < DogData.DOG_FOOD_PRICE * amount or not Inventory.can_add_item("dog_food", amount)
		buy_food.pressed.connect(_buy_food.bind(amount))
		food_row.add_child(buy_food)

func _dog_card(variant_id: String, profiles: Dictionary) -> PanelContainer:
	var data: Dictionary = DogData.DOG_VARIANTS[variant_id]
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(570, 108)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = DogData.texture_for_variant(variant_id)
	portrait.custom_minimum_size = Vector2(82, 82)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var pet_id := str(data["pet_id"])
	var owned: bool = profiles.has(pet_id)
	var header := Label.new()
	header.text = str(data["display_name"]) if not owned else str(profiles[pet_id].get("name", data["default_name"])) + " · " + str(data["display_name"])
	header.theme_type_variation = &"SectionTitle"
	details.add_child(header)
	var personality := Label.new()
	personality.text = tr("DOG_PERSONALITY_" + variant_id.to_upper())
	personality.theme_type_variation = &"MutedLabel"
	personality.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(personality)
	if not owned:
		var required := Label.new()
		required.text = tr("DOG_REQUIRES_LEVEL") % int(data["unlock_level"])
		required.theme_type_variation = &"MutedLabel"
		details.add_child(required)
	if owned:
		var hunger := dog_hunger_text(float(profiles[pet_id].get("hunger", 100.0)))
		var status := Label.new()
		status.text = hunger
		status.add_theme_color_override("font_color", Color("c85c45") if float(profiles[pet_id].get("hunger", 100.0)) <= DogData.HUNGRY_THRESHOLD else Color("5a7442"))
		details.add_child(status)
	var actions := VBoxContainer.new()
	row.add_child(actions)
	if not owned:
		var adopt := Button.new()
		adopt.text = tr("DOG_ADOPT") + " · " + str(data["price"])
		adopt.disabled = Inventory.coins < int(data["price"]) or Inventory.player_level < int(data["unlock_level"])
		adopt.pressed.connect(_adopt.bind(variant_id, pet_id))
		actions.add_child(adopt)
	else:
		var feed := Button.new()
		feed.text = tr("DOG_FEED")
		feed.disabled = Inventory.dog_food <= 0 or float(profiles[pet_id].get("hunger", 100.0)) >= 99.9
		feed.pressed.connect(_feed.bind(pet_id))
		actions.add_child(feed)
		var rename := Button.new()
		rename.text = tr("DOG_RENAME")
		rename.pressed.connect(_start_rename.bind(pet_id, str(profiles[pet_id].get("name", data["default_name"]))))
		actions.add_child(rename)
	return card

func dog_hunger_text(value: float) -> String:
	return "%s: %d%%" % [tr("DOG_HUNGER"), roundi(value)]

func _adopt(variant_id: String, pet_id: String) -> void:
	if SaveManager.adopt_dog(variant_id):
		pending_pet_id = pet_id
		name_input.text = str(DogData.DOG_VARIANTS[variant_id]["default_name"])
		name_dialog.popup_centered()
		AudioManager.play_sfx("ui_success")
	else:
		hud.show_transaction_feedback(tr("DOG_ADOPT_FAILED"))
	refresh()

func _start_rename(pet_id: String, current_name: String) -> void:
	pending_pet_id = pet_id
	name_input.text = current_name
	name_dialog.popup_centered()

func _confirm_name() -> void:
	if pending_pet_id.is_empty():
		return
	if SaveManager.rename_dog(pending_pet_id, name_input.text):
		hud.show_transaction_feedback(tr("DOG_RENAME_SUCCESS"))
	else:
		hud.show_transaction_feedback(tr("DOG_NAME_INVALID"))
	pending_pet_id = ""
	refresh()

func _buy_food(amount: int) -> void:
	if SaveManager.buy_dog_food(amount):
		hud.show_transaction_feedback(tr("DOG_FOOD_BOUGHT"))
		AudioManager.play_sfx("coin")
	else:
		hud.show_transaction_feedback(tr("TRADE_NO_COINS"))
	refresh()

func _feed(pet_id: String) -> void:
	if SaveManager.dog_hunger(pet_id) >= 99.9:
		hud.show_transaction_feedback(tr("DOG_NOT_HUNGRY"))
		return
	if SaveManager.feed_dog(pet_id):
		hud.show_transaction_feedback(tr("DOG_FEED_SUCCESS"))
		AudioManager.play_sfx("ui_success")
	else:
		hud.show_transaction_feedback(tr("DOG_FOOD_NONE"))
	refresh()
