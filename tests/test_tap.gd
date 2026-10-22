extends SceneTree
# Taps through the real input path: the rope's ? mark gives a clue and names
# the rope on the map; a bare patch of floor describes the room.
# Needs a display: godot --path . --disable-vsync --fixed-fps 30 -s tests/test_tap.gd
var fails := 0


func _initialize():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m._set_mode("investigate")
	for i in 60:
		await process_frame
	var mv = m.map
	_check(mv.frame.get("labels", {}).is_empty(), "no object names before inspecting")
	var o = mv.layout.objects["bell_rope"]
	await _tap(mv, Vector2(o.x, o.y))
	_check(m.investigation.found == ["C_rope_dummy"], "tap on rope found %s" % [m.investigation.found])
	_check(mv.frame.labels.keys() == ["bell_rope"], "rope named after inspecting: %s" % [mv.frame.labels])
	await _tap(mv, Vector2(8.5, 3.3))  # bare floor in Julia's room
	_check(m.caption.text.begins_with("Julia's room\nA homely"), "room tap shows description: %s" % m.caption.text)
	_check(m.selected == "", "room tap clears the selected object")
	print("ALL TESTS PASSED" if fails == 0 else "FAILS: %d" % fails)
	quit(0 if fails == 0 else 1)


func _tap(mv, tile: Vector2) -> void:
	var p = mv.get_global_transform() * mv.iso(tile)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		root.push_input(ev, true)
		await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)
