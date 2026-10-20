extends SceneTree
# Dev helper: screenshots of a few steps in each mode, saved to /tmp.
# Run (needs a display): godot --path . --disable-vsync --fixed-fps 30 -s tests/screenshots.gd
func _initialize():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	for spec in [["truth", 11], ["testimony", 2], ["testimony", 10]]:
		if m.mode != spec[0]:
			m._set_mode(spec[0])
		m._show(spec[1])
		await _shot(m, "%s_%d" % spec)
	m._set_mode("investigate")
	await _shot(m, "inv_0")
	m._inspect("bell_rope")
	await _shot(m, "inv_rope")
	m._test_selected()
	await _shot(m, "inv_pull")
	m._go(1)
	for oid in ["chair_roylott", "saucer"]:
		m._inspect(oid)
	await _shot(m, "inv_roylott")
	m._middle_pressed()
	await _shot(m, "inv_notes")
	quit()


func _shot(_m, name: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/g4_%s.png" % name)
