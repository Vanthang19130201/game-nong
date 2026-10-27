extends Node2D

func _ready() -> void:
	FarmEventManager.changed.connect(_refresh)
	GameClock.changed.connect(_refresh_time)
	_refresh(FarmEventManager.current_event_id)

func _refresh(_event_id: String) -> void:
	queue_redraw()

func _refresh_time() -> void:
	if FarmEventManager.is_active("firefly_night"):
		queue_redraw()

func _draw() -> void:
	var event_id: String = FarmEventManager.current_event_id
	match event_id:
		"butterfly_day":
			for point in [Vector2(620, 620), Vector2(820, 760), Vector2(390, 840), Vector2(1500, 700)]:
				_draw_butterfly(point)
		"mushroom_growth":
			for point in [Vector2(360, 890), Vector2(790, 1080), Vector2(1580, 1150)]:
				_draw_mushroom(point)
		"fallen_branch":
			draw_line(Vector2(300, 760), Vector2(354, 745), Color("704b34"), 8.0, true)
			draw_line(Vector2(325, 752), Vector2(330, 739), Color("8e6946"), 4.0, true)
		"lost_crate":
			var rect := Rect2(1600, 1000, 34, 26)
			draw_rect(rect, Color("99693f"))
			draw_rect(rect, Color("543b2a"), false, 2.0)
			draw_line(Vector2(1601, 1013), Vector2(1633, 1013), Color("d2a16a"), 3.0)
		"firefly_night":
			if GameClock.minutes >= 19.0 * 60.0 or GameClock.minutes < 5.0 * 60.0:
				for point in [Vector2(600, 760), Vector2(670, 830), Vector2(820, 710), Vector2(1020, 920), Vector2(1440, 760), Vector2(1530, 870)]:
					draw_circle(point, 2.0, Color("f3d77d", 0.82))
		"fishing_day":
			pass

func _draw_butterfly(point: Vector2) -> void:
	draw_circle(point + Vector2(-3, 0), 3.0, Color("e8b34f"))
	draw_circle(point + Vector2(3, 0), 3.0, Color("d58c70"))
	draw_line(point + Vector2(0, -3), point + Vector2(0, 4), Color("5b402d"), 1.0)

func _draw_mushroom(point: Vector2) -> void:
	draw_rect(Rect2(point + Vector2(-2, 1), Vector2(4, 8)), Color("f0dfb8"))
	draw_arc(point, 7.0, PI, TAU, 12, Color("bb7151"), 5.0, true)
