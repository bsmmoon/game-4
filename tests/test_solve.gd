extends SceneTree
# Solves the case by tapping the real Solve buttons (wrong answer first).
# Needs a display: godot --path . --disable-vsync --fixed-fps 30 -s tests/test_solve.gd
var m
var fails := 0


func _initialize():
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m._set_mode("testimony")
	for i in m.steps.size():
		m._show(i)
	_check(m.investigation.found.has("C_band"), "testimony notes Julia's last words")
	m._set_mode("investigate")
	for oid in ["shutter_middle", "ventilator", "bell_rope", "fauna_book", "saucer"]:
		m._inspect(oid)
	m.selected = "bell_rope"
	m._test_selected()
	m._set_mode("solve")
	await _frames(5)
	await _tap("The gipsies on the lawn")
	await _tap("Submit")
	_check("shutters" in m.caption.text, "wrong suspect gets the shutters hint")
	root.get_texture().get_image().save_png("/tmp/g4_solve_hint.png")
	await _tap("Dr. Roylott, her stepfather")
	await _tap("Vent to Roylott's room")
	await _tap("Saucer of milk")
	await _tap("Submit")
	_check(m.deduction.solved.has("culprit"), "culprit solved by tapping")
	for plan in [["A swamp adder: the speckled band", "The swamp adder", "Saucer of milk"],
			["Through the vent and down the rope to the bed", "Dummy bell-rope", "Rope rings no bell"]]:
		await _tap("Next >")
		for t in plan:
			await _tap(t)
		await _tap("Submit")
	_check(m.deduction.all_solved(), "all three questions solved")
	_check(m.caption.text.begins_with("Case closed"), "closing screen shown")
	var img := root.get_texture().get_image()
	img.save_png("/tmp/g4_solve_done.png")
	await _tap("Explain")
	_check(m.mode == "explain" and m.steps.size() == 10, "Explain starts the ten-step replay")
	for i in 3:
		await _tap("Next >")
	_check(m.caption.text.begins_with("Holmes: It slides down"), "step 4 explains the rope")
	_check(m.map.frame.marks.has("bell_rope"), "step 4 points at the rope")
	await _frames(10)
	root.get_texture().get_image().save_png("/tmp/g4_explain.png")
	print("ALL TESTS PASSED" if fails == 0 else "FAILURES: %d" % fails)
	quit(1 if fails else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Taps the first visible button with this text, through the input path.
func _tap(text: String) -> void:
	var b := _find(m, text)
	if b == null:
		_check(false, "button '%s' on screen" % text)
		return
	var scroll = m.solve_box.get_parent()
	if m.solve_box.is_ancestor_of(b):
		scroll.ensure_control_visible(b)
		await _frames(2)
	var p: Vector2 = b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		root.push_input(ev, true)
		await process_frame
	await _frames(2)


func _find(n: Node, text: String) -> Button:
	for c in n.get_children():
		if c is Button and c.text == text and c.is_visible_in_tree() and not c.is_queued_for_deletion():
			return c
		var f := _find(c, text)
		if f != null:
			return f
	return null


func _check(ok: bool, label: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", label, "  caption: ", m.caption.text)
