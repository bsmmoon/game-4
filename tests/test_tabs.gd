extends SceneTree
# Opens on the case briefing; tabs step both ways and stop at the ends.
# Needs a display: godot --path . --disable-vsync --fixed-fps 30 -s tests/test_tabs.gd
var fails := 0

func _initialize():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 30:
		await process_frame
	_check(m.mode == "brief" and m.steps.size() == 1, "opens on the scene")
	_check(m.caption.text.contains("Julia Stoner"), "scene names the victim")
	var ids: Array = m.map.frame.actors.map(func(a): return a.id)
	_check(ids.has("julia") and ids.has("helen") and not ids.has("adder"), "scene shows the people, hides the adder %s" % [ids])
	_check(m.mode_prev.disabled and not m.mode_next.disabled, "first tab: back disabled")
	await _shot(m, "brief_0")
	m.mode_prev.pressed.emit()
	_check(m.mode == "brief", "back from the first tab does not wrap")
	var seen := []
	for i in 4:
		m.mode_next.pressed.emit()
		seen.append(m.mode)
	_check(seen == ["testimony", "investigate", "solve", "truth"], "forward order %s" % [seen])
	_check(m.mode_next.disabled, "last tab: forward disabled")
	m.mode_prev.pressed.emit()
	_check(m.mode == "solve", "back from truth goes to solve")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(_m, name: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/g4_%s.png" % name)
