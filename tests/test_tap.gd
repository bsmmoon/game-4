extends SceneTree
# Taps the rope's ? mark through the real input path and expects a clue.
# Needs a display: godot --path . --disable-vsync --fixed-fps 30 -s tests/test_tap.gd
func _initialize():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m._set_mode("investigate")
	for i in 60:
		await process_frame
	var mv = m.map
	var o = mv.layout.objects["bell_rope"]
	var p = mv.get_global_transform() * mv.iso(Vector2(o.x, o.y))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		root.push_input(ev, true)
		await process_frame
	var ok: bool = m.investigation.found == ["C_rope_dummy"]
	print("ALL TESTS PASSED" if ok else "FAIL tap on rope found %s" % [m.investigation.found])
	quit(0 if ok else 1)
