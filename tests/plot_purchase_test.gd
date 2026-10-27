extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var dialog: ConfirmationDialog

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: "+message)
		quit(1)
		assert(value,message)

func contrast(foreground: Color, background: Color) -> float:
	var first: float = foreground.srgb_to_linear().get_luminance()
	var second: float = background.srgb_to_linear().get_luminance()
	return (maxf(first,second)+0.05)/(minf(first,second)+0.05)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func button_center(button: Button) -> Vector2:
	return Vector2(dialog.position)+button.get_global_rect().get_center()

func open_plot(number: int) -> void:
	hud.open_plot_purchase(number)
	await create_timer(0.05).timeout
	check(dialog.visible and hud.blocks_world_input(),"plot popup is modal")
	check(dialog.dialog_text == tr("PLOT_PRICE") % [number,inv.FarmData.plot_price(number)],"popup uses centralized price")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	check(manager.reset_game(),"reset test fixture")
	root.size = Vector2i(1152,648)
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	dialog = hud.plot_purchase
	await create_timer(0.1).timeout
	check(inv.FarmData.MAX_PLOTS == 32 and inv.unlocked_plot_count == 8,"eight free plots, cap unchanged")
	var expected: Array[int] = []
	for tier in [{"count":8,"price":0},{"count":4,"price":50},{"count":4,"price":100},{"count":4,"price":175},{"count":4,"price":250},{"count":4,"price":375},{"count":4,"price":500}]:
		for n in range(tier["count"]):
			expected.append(tier["price"])
	for number in range(1,33):
		check(inv.FarmData.plot_price(number) == expected[number-1],"exact new price: plot "+str(number))
	check(inv.FarmData.plot_price(33) == -1,"no plots beyond 32")
	await open_plot(9)
	check(dialog.get_theme_stylebox("panel").bg_color.get_luminance() > 0.7,"cream dialog body, no dark default panel")
	check(dialog.get_theme_stylebox("embedded_border").bg_color.get_luminance() > 0.4,"light wood title bar")
	check(dialog.get_label().get_theme_color("font_color").get_luminance() < 0.3 and dialog.get_label().get_theme_font_size("font_size") == 20,"clear dark plot number and price")
	check(dialog.get_theme_icon("close").get_size() == Vector2(24,24),"visible project-owned close icon")
	for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		for state in [{"font":"font_color","style":"normal"},{"font":"font_focus_color","style":"normal"},{"font":"font_hover_color","style":"hover"},{"font":"font_pressed_color","style":"pressed"},{"font":"font_hover_pressed_color","style":"pressed"}]:
			check(contrast(button.get_theme_color(state["font"]),button.get_theme_stylebox(state["style"]).bg_color) >= 4.5,"readable %s contrast: %s" % [button.theme_type_variation,state["font"]])
	check(dialog.get_ok_button().get_theme_stylebox("focus").bg_color.a == 0.0,"focus ring never paints a pale background over Buy")
	await click(button_center(dialog.get_cancel_button()))
	check(not dialog.visible and inv.coins == 100 and inv.unlocked_plot_count == 8,"Cancel click changes no resources")
	await open_plot(9)
	var close_center: Vector2 = Vector2(dialog.position)+Vector2(dialog.size.x-dialog.get_theme_constant("close_h_offset"),-dialog.get_theme_constant("close_v_offset"))+dialog.get_theme_icon("close").get_size()/2
	await click(close_center)
	check(not dialog.visible and inv.coins == 100 and inv.unlocked_plot_count == 8,"X click cancels without buying")
	inv.coins = 49
	await open_plot(9)
	await click(button_center(dialog.get_ok_button()))
	check(dialog.visible and inv.coins == 49 and inv.unlocked_plot_count == 8 and dialog.dialog_text.contains("50"),"insufficient funds keep popup, inventory and new price")
	await click(button_center(dialog.get_cancel_button()))
	for number in range(9,33):
		var price: int = expected[number-1]
		inv.coins = price
		inv.inventory_changed.emit()
		var plot = manager.plots[inv.FarmData.plot_id(number)]
		check(plot.get_node("Visuals/LockedMarker").visible and not plot.get_node("Visuals/SoilSprite").visible and plot.get_node("PlantLabel").text.is_empty(),"locked plot uses a small marker without world price text")
		await open_plot(number)
		if number == 9 and "--capture" in OS.get_cmdline_user_args():
			await create_timer(1.55).timeout
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://plot_purchase.png") == OK,"capture popup colors and X")
		await click(button_center(dialog.get_ok_button()))
		check(not dialog.visible and inv.unlocked_plot_count == number and inv.coins == 0,"Buy click deducts exact price once: plot "+str(number))
		check(not inv.buy_plot(number) and inv.coins == 0,"duplicate buy cannot charge again")
	check(not inv.buy_plot(33) and manager.plots.size() == 32,"32 plot maximum preserved")
	var saved := ConfigFile.new()
	check(saved.load(manager.SAVE_PATH) == OK and saved.get_value("farm","unlocked_plot_count") == 32,"new purchases use unchanged save key")
	check(manager.reset_game(),"cleanup")
	print("PASS: plot_popup")
	quit()
