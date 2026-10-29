extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	await process_frame
	var presenter := preload("res://transaction_feedback.gd").new()
	root.add_child(presenter)
	for index in 5:
		presenter.show_notification("Thông báo tiếng Việt rất dài số %d: Trồng cây, thu hoạch và nhận phần thưởng." % index, "mission", 4.0)
	await process_frame
	check(presenter.get_child_count() == 3, "toast stack keeps at most three visible entries")
	for panel in presenter.get_children():
		var label := panel.get_child(0).get_child(0).get_child(1) as Label
		check(label != null and label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "toast body wraps long Vietnamese text")
	presenter.show_notification("Kho đã đầy", "warning", 4.0)
	presenter.show_notification("Kho đã đầy", "warning", 4.0)
	check(presenter.get_child_count() == 3, "identical warning is combined instead of stacked")
	if failures.is_empty():
		print("PASS: notification_ui")
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)
		return
	quit()
