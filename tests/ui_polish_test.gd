extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: "+message)
		quit(1)
		assert(value,message)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func contrast(first: Color, second: Color) -> float:
	var a: float = first.srgb_to_linear().get_luminance()
	var b: float = second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func check_controls(node: Node) -> void:
	if node is Control:
		check(node.scale == Vector2.ONE,"no Control/Label scaling: "+str(node.get_path()))
	for child in node.get_children():
		check_controls(child)

func open_panel(id: String) -> Control:
	hud.close_all_panels()
	match id:
		"storage": hud._toggle_storage()
		"shop": hud._toggle_shop()
		"build": hud.open_build()
		"land": hud.open_land_purchase("land_01")
		"orders": hud.open_orders()
		"settings": hud._toggle_settings()
		_:
			var world: Node = manager.buildings.get(id) if id != "market" else farm.get_node("FishMarket")
			player.position = world.global_position+Vector2(0,32)
			await create_timer(0.08).timeout
			match id:
				"house": hud.open_house(world)
				"feed_mill": hud.open_station(world)
				"bakery": hud.open_bakery(world)
				"dairy": hud.open_dairy(world)
				"spinning_machine": hud.open_spinning_machine(world)
				"market": hud.open_fish_market(world)
	await create_timer(0.08).timeout
	var panels: Dictionary = {"storage":hud.storage_panel,"shop":hud.shop_build_panel,"build":hud.shop_build_panel,"land":hud.land_panel,"orders":hud.order_panel,"settings":hud.settings_panel,"house":hud.house_panel,"feed_mill":hud.station_panel,"bakery":hud.bakery_panel,"dairy":hud.dairy_panel,"spinning_machine":hud.spinning_machine_panel,"market":hud.fish_market_panel}
	return panels[id]

func check_panel(panel: Control, id: String) -> void:
	var screen := Rect2(Vector2.ZERO,root.get_visible_rect().size)
	check(panel.visible and not hud.hotbar.visible and hud.blocks_world_input(),"modal hides equipment and blocks world: "+id)
	check(screen.encloses(panel.get_rect()),"popup fits screen: "+id+" "+str(screen.size)+" got "+str(panel.get_rect()))
	check(panel.get_rect().get_center().distance_to(screen.get_center()) <= 1,"popup centered: "+id)
	var footer: Control = panel.get_node("Margin/Content/Footer")
	check(footer.size.y >= 70 and footer.size.y <= 90,"separate footer height: "+id)
	var buttons: Array = footer.find_children("*","Button",true,false)
	check(buttons.size() == 1 and screen.encloses(buttons[0].get_global_rect()),"Close always on screen: "+id)
	var scroll: Control = panel.get_node_or_null("Margin/Content/ContentScroll")
	if scroll == null:
		scroll = panel.get_node_or_null("Margin/Content/Scroll")
	if scroll == null:
		scroll = panel.get_node("Margin/Content/Tabs")
	check(scroll.get_global_rect().end.y < footer.get_global_rect().position.y,"content cannot overlap Close: "+id)
	if "--capture" in OS.get_cmdline_user_args() and screen.size == Vector2(1280,720):
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://polish_"+id+".png") == OK,"capture "+id)
	await click(buttons[0].get_global_rect().get_center())
	check(not panel.visible and hud.hotbar.visible,"mouse Close restores hotbar: "+id)

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save required")
	check(manager.reset_game(),"fixture reset")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 100000
	inv.normalize_exp()
	for id in ["feed_mill","chicken_coop","cow_shed","bakery"]:
		check(inv.buy_building(id),"fixture purchase "+id)
	inv.owns_dairy = true
	inv.owns_spinning_machine = true
	inv.inventory_changed.emit()
	await create_timer(0.1).timeout
	var snapshot: Dictionary = {}
	for item in manager.INVENTORY_DEFAULTS:
		snapshot[item] = inv.get(item)
	for field in ["player_level","player_exp","selected_crop","house_level","silo_level","barn_level","silo_capacity","barn_capacity","unlocked_plot_count"]:
		snapshot[field] = inv.get(field)
	var theme: Theme = hud.UI_THEME
	for type in ["Button","PurchaseButton","OptionButton"]:
		for state in [{"color":"font_color","style":"normal"},{"color":"font_focus_color","style":"normal"},{"color":"font_hover_color","style":"hover"},{"color":"font_pressed_color","style":"pressed"},{"color":"font_hover_pressed_color","style":"pressed"}]:
			check(contrast(theme.get_color(state["color"],type),theme.get_stylebox(state["style"],type).bg_color) >= 4.5,"readable button state: "+type+" "+state["color"])
	check(theme.get_stylebox("tab_selected","TabBar").bg_color != theme.get_stylebox("tab_hovered","TabBar").bg_color,"selected tab distinct from hover")
	for view in [Vector2i(1280,720),Vector2i(960,540),Vector2i(800,450),Vector2i(360,640)]:
		root.size = view
		root.content_scale_size = view
		await create_timer(0.08).timeout
		check(root.get_visible_rect().size == Vector2(view),"test logical viewport matches requested resize")
		for id in ["storage","shop","build","land","orders","settings","house","feed_mill","bakery","dairy","spinning_machine","market"]:
			var panel: Control = await open_panel(id)
			await check_panel(panel,id)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	await create_timer(0.08).timeout
	await open_panel("storage")
	var slot: Button = hud.storage_panel.item_cells["wheat_seed"]
	var motion := InputEventMouseMotion.new()
	motion.position = slot.get_global_rect().get_center()
	root.push_input(motion,true)
	await process_frame
	var hint: Label = hud.storage_panel.get_node("Margin/Content/ItemHint")
	check(hint.text.contains(root.get_node("Localization").display_name("wheat_seed")) and slot._get_tooltip(Vector2.ZERO).contains(root.get_node("Localization").display_name("wheat_seed")),"inventory exposes item tooltip and keeps the reserved hint row")
	check(hint.get_global_rect().end.y <= hud.storage_panel.get_node("Margin/Content/Footer").get_global_rect().position.y,"hint never overlaps footer")
	hud.close_all_panels()
	for item in snapshot:
		check(inv.get(item) == snapshot[item],"UI never changes economy/inventory: "+item)
	check_controls(hud)
	check(manager.reset_game(),"cleanup")
	print("PASS: ui_polish")
	quit()
