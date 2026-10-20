extends SceneTree
# Dev helper: screenshots of a few steps in both modes, saved to /tmp.
# Run (needs a display): godot --path . --disable-vsync --fixed-fps 30 -s tests/screenshots.gd
func _initialize():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	for spec in [["truth", 11], ["testimony", 2], ["testimony", 10]]:
		if m.mode != spec[0]:
			m._set_mode(spec[0])
		m._show(spec[1])
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png("/tmp/g4_%s_%d.png" % spec)
	quit()
