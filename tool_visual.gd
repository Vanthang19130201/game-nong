extends Node2D

var tool_id: String = ""
var facing: String = ""
var base_rotation: float = 0.0
var swinging: bool = false
var swing_tween: Tween


func set_equipped(item_id: String, direction: String) -> void:
	tool_id = item_id if item_id in ["axe", "hammer", "fishing_rod"] else ""
	set_facing(direction)
	visible = not tool_id.is_empty()
	queue_redraw()


func set_facing(direction: String) -> void:
	if direction not in ["up", "down", "left", "right"]:
		return
	if facing == direction:
		return
	facing = direction
	match facing:
		"up":
			position = Vector2(-5, -28)
			base_rotation = 0.0
			z_index = -1
		"down":
			position = Vector2(6, -28)
			base_rotation = PI * 0.72
			z_index = 1
		"left":
			position = Vector2(-5, -27)
			base_rotation = -PI * 0.5
			z_index = 1
		"right":
			position = Vector2(5, -27)
			base_rotation = PI * 0.5
			z_index = 1
	if not swinging:
		rotation = base_rotation
	queue_redraw()


func play_swing(target_world_position: Vector2) -> void:
	if tool_id not in ["axe", "hammer"] or swinging:
		return
	swinging = true
	var direction := (target_world_position - global_position).normalized()
	var aim_rotation := direction.angle() + PI * 0.5
	var windup := base_rotation - signf(wrapf(aim_rotation - base_rotation, -PI, PI)) * 0.42
	swing_tween = create_tween().set_loops()
	swing_tween.tween_property(self, "rotation", windup, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "rotation", aim_rotation, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(self, "rotation", base_rotation, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func stop_swing() -> void:
	if swing_tween != null and swing_tween.is_valid():
		swing_tween.kill()
	swing_tween = null
	swinging = false
	rotation = base_rotation


func _finish_swing() -> void:
	swinging = false
	rotation = base_rotation


func tip_world_position() -> Vector2:
	return to_global(Vector2(5, -42 if tool_id == "fishing_rod" else -25))


func _draw() -> void:
	if tool_id.is_empty():
		return
	if tool_id == "fishing_rod":
		_draw_rod()
	else:
		_draw_handle()
		if tool_id == "axe":
			_draw_axe_head()
		else:
			_draw_hammer_head()


func _draw_handle() -> void:
	# Narrow handle, beveled wood, and a small hand grip keep the tool visually
	# attached to the character instead of looking like a floating icon.
	draw_line(Vector2(0, 5), Vector2(0, -25), Color("493426"), 5.2, true)
	draw_line(Vector2(0, 4), Vector2(0, -24), Color("a97443"), 3.0, true)
	draw_line(Vector2(1, 2), Vector2(1, -18), Color("d6aa72", 0.9), 0.9, true)
	draw_line(Vector2(-2, 2), Vector2(2, 2), Color("67452f"), 1.4, true)


func _draw_axe_head() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -22), Vector2(-13, -27), Vector2(-20, -23),
		Vector2(-22, -16), Vector2(-17, -11), Vector2(-7, -12),
		Vector2(-2, -16), Vector2(3, -19)
	]), Color("53686a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -27), Vector2(-20, -23), Vector2(-22, -16),
		Vector2(-17, -11), Vector2(-17, -20)
	]), Color("d8dfd0"))
	draw_line(Vector2(-2, -22), Vector2(-13, -27), Color("46372b"), 1.2, true)
	draw_line(Vector2(-19, -21), Vector2(-19, -15), Color("f0e4c8"), 1.0, true)
	draw_line(Vector2(-5, -17), Vector2(-2, -20), Color("88634a"), 1.2, true)


func _draw_hammer_head() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -25), Vector2(10, -25), Vector2(13, -22),
		Vector2(13, -17), Vector2(10, -14), Vector2(-4, -14),
		Vector2(-7, -17), Vector2(-7, -22)
	]), Color("48504c"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -24), Vector2(9, -24), Vector2(11, -21),
		Vector2(11, -18), Vector2(9, -16), Vector2(-3, -16),
		Vector2(-5, -18), Vector2(-5, -22)
	]), Color("89958c"))
	draw_line(Vector2(8, -23), Vector2(9, -17), Color("e1dec9"), 1.4, true)
	draw_line(Vector2(-3, -24), Vector2(8, -24), Color("b9c0b4"), 1.0, true)
	draw_line(Vector2(-2, -14), Vector2(7, -14), Color("4a4033"), 1.0, true)


func _draw_rod() -> void:
	# Compact cork-and-wood grip meets the hand; the tapered rod is drawn as
	# two lines so all four facing rotations keep the same clean silhouette.
	draw_line(Vector2(0, 5), Vector2(0, -34), Color("483326"), 3.6, true)
	draw_line(Vector2(-1, 3), Vector2(-1, -31), Color("b77e49"), 2.0, true)
	draw_line(Vector2(0, -34), Vector2(5, -42), Color("67482f"), 1.3, true)
	draw_line(Vector2(0, -34), Vector2(5, -42), Color("d1a36c"), 0.7, true)
	draw_line(Vector2(-2, -8), Vector2(2, -8), Color("775132"), 1.1, true)
	draw_line(Vector2(-2, -13), Vector2(2, -13), Color("775132"), 1.1, true)
	draw_circle(Vector2(0, 4), 2.5, Color("62452f"))
	draw_circle(Vector2(0, 0), 2.0, Color("d3ad77"))
