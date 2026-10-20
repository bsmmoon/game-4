extends SceneTree
# Zoom and pan on the map through the real input path: + button, pinch,
# drag-to-pan (not a tap), and a tap on a ? mark while zoomed in.
# Needs a display: godot --path . --disable-vsync --fixed-fps 30 -s tests/test_zoom.gd
var m
var mv
var fails := 0


func _initialize():
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m._set_mode("investigate")
	await _frames(60)
	mv = m.map
	var plus: Button = mv.get_child(0).get_child(0)
	await _click(plus.get_global_rect().get_center())
	_check(is_equal_approx(mv.zoom, 1.5), "+ button zooms in (zoom %s)" % mv.zoom)

	var c: Vector2 = mv.get_global_rect().get_center()
	await _touch(0, c - Vector2(40, 0), true)
	await _touch(1, c + Vector2(40, 0), true)
	await _drag(1, c + Vector2(80, 0))
	await _touch(1, c + Vector2(80, 0), false)
	await _touch(0, c - Vector2(40, 0), false)
	_check(mv.zoom > 1.9, "pinch zooms in (zoom %s)" % mv.zoom)

	var o = mv.layout.objects["bell_rope"]
	var before: Vector2 = mv.get_global_transform() * mv.iso(Vector2(o.x, o.y))
	var start := c + Vector2(0, 60)
	await _press(start, true)
	for i in 5:
		await _move(start + Vector2(-20 * (i + 1), 0), Vector2(-20, 0))
	await _press(start + Vector2(-100, 0), false)
	await _frames(3)
	var after: Vector2 = mv.get_global_transform() * mv.iso(Vector2(o.x, o.y))
	_check(after.x < before.x - 50, "drag pans the map")
	_check(m.investigation.found.is_empty() and m.step == 0, "a pan is neither a tap nor a swipe")

	await _click(after)
	_check(m.investigation.found == ["C_rope_dummy"], "tap on ? works while zoomed (found %s)" % [m.investigation.found])
	await _frames(10)
	root.get_texture().get_image().save_png("/tmp/g4_zoom.png")
	print("ALL TESTS PASSED" if fails == 0 else "FAILURES: %d" % fails)
	quit(1 if fails else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _press(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _move(p: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = p
	ev.relative = rel
	root.push_input(ev, true)
	await process_frame


func _click(p: Vector2) -> void:
	await _press(p, true)
	await _press(p, false)
	await _frames(2)


func _touch(i: int, p: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.pressed = down
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _drag(i: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = i
	ev.position = p
	root.push_input(ev, true)
	await process_frame


func _check(ok: bool, label: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", label)
