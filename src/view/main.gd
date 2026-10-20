## Prototype screen (portrait phone). Asks the core for state and perception,
## turns it into a frame for MapView. Two modes: the true night, or Helen's
## testimony replayed with only what she perceived (guesses as ghosts), or the
## present-day investigation: tap objects to find clues for the notebook.
extends Control

const CaseData = preload("res://src/core/case_data.gd")
const Timeline = preload("res://src/core/timeline.gd")
const Perception = preload("res://src/core/perception.gd")
const Testimony = preload("res://src/core/testimony.gd")
const Investigation = preload("res://src/core/investigation.gd")
const MapView = preload("res://src/view/map_view.gd")

const CASE_DIR := "res://cases/speckled-band/"
const WITNESS := "helen"
const PLAY_SECONDS := 1.8
const MODES := ["truth", "testimony", "investigate"]
const MODE_NAMES := { "truth": "The truth", "testimony": "Helen's testimony", "investigate": "Investigate" }
const SEARCH_ROOMS := ["middle_room", "roylott_room"]

var data
var timeline
var perception
var testimony
var investigation
var layout: Dictionary = {}

var mode := "truth"   # one of MODES
var steps: Array = [] # truth: event indices; testimony: claim dicts; investigate: room ids
var step := 0
var playing := false
var _play_t := 0.0

var map: Control
var title: Label
var caption: Label
var slider: HSlider
var mode_btn: Button
var play_btn: Button
var prev_btn: Button
var next_btn: Button
var action_btn: Button
var notebook: Label
var selected := ""
var _notes_open := false


func _ready() -> void:
	data = CaseData.load_file(CASE_DIR + "case.json")
	layout = JSON.parse_string(FileAccess.get_file_as_string(CASE_DIR + "layout.json"))
	timeline = Timeline.new(data)
	perception = Perception.new(data)
	testimony = Testimony.new(timeline, perception)
	investigation = Investigation.new(data)
	_build_ui()
	_set_mode("truth")


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14161c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	title = _label(24)
	title.clip_text = true
	box.add_child(title)
	mode_btn = _button("", func(): _set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()]))
	box.add_child(mode_btn)

	map = MapView.new()
	map.layout = layout
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.swiped.connect(_go)
	map.tapped_object.connect(_inspect)
	box.add_child(map)

	notebook = _label(21)
	notebook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	notebook.visible = false
	box.add_child(notebook)

	caption = _label(21)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(0, 200)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(caption)

	slider = HSlider.new()
	slider.custom_minimum_size = Vector2(0, 56)
	slider.step = 1
	slider.value_changed.connect(func(v): _show(int(v)))
	box.add_child(slider)
	action_btn = _button("", _test_selected)
	box.add_child(action_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	prev_btn = _button("", func(): _go(-1))
	row.add_child(prev_btn)
	play_btn = _button("", _middle_pressed)
	row.add_child(play_btn)
	next_btn = _button("", func(): _go(1))
	row.add_child(next_btn)
	box.add_child(row)


func _label(fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	b.clip_text = true
	b.pressed.connect(cb)
	return b


# --- navigation -----------------------------------------------------------

func _set_mode(m: String) -> void:
	mode = m
	if playing:
		_toggle_play()
	steps.clear()
	_notes_open = false
	selected = ""
	if mode == "truth":
		for i in timeline.size():
			steps.append(i)
	elif mode == "testimony":
		var t: Dictionary = _testimony_of(WITNESS)
		steps = t.claims.duplicate()
	else:
		steps = SEARCH_ROOMS.duplicate()
	var next: String = MODES[(MODES.find(mode) + 1) % MODES.size()]
	mode_btn.text = "%s  |  tap: %s" % [MODE_NAMES[mode], MODE_NAMES[next]]
	var searching := mode == "investigate"
	slider.visible = not searching
	prev_btn.text = "< Room" if searching else "< Prev"
	next_btn.text = "Room >" if searching else "Next >"
	play_btn.text = "Play"
	slider.max_value = steps.size() - 1
	step = -1
	slider.set_value_no_signal(0)
	_show(0)


func _go(dir: int) -> void:
	if mode == "investigate":
		_notes_open = false
		selected = ""
		step = -1 if steps.size() > 1 else step
		_show(posmod(steps.find(_room_shown) + dir, steps.size()))
		return
	_show(clamp(step + dir, 0, steps.size() - 1))


func _middle_pressed() -> void:
	if mode == "investigate":
		_notes_open = not _notes_open
		_show_room(_room_shown)
	else:
		_toggle_play()


func _toggle_play() -> void:
	playing = not playing
	play_btn.text = "Pause" if playing else "Play"
	if playing and step >= steps.size() - 1:
		_show(0)
	_play_t = 0.0


func _process(delta: float) -> void:
	if not playing:
		return
	_play_t += delta
	if _play_t >= PLAY_SECONDS:
		_play_t = 0.0
		if step >= steps.size() - 1:
			_toggle_play()
		else:
			_go(1)


func _show(i: int) -> void:
	if i == step:
		return
	step = i
	slider.set_value_no_signal(i)
	if mode == "truth":
		_show_truth(steps[i])
	elif mode == "testimony":
		_show_claim(steps[i])
	else:
		_show_room(steps[i])
	_layout_for_mode()


func _layout_for_mode() -> void:
	var searching := mode == "investigate"
	map.visible = not (searching and _notes_open)
	notebook.visible = searching and _notes_open
	action_btn.visible = searching and selected != "" and not _notes_open \
		and not investigation.test_verbs(selected).is_empty()


# --- frames ---------------------------------------------------------------

func _show_truth(ei: int) -> void:
	var e: Dictionary = timeline.event(ei)
	var after = timeline.state_after(ei)
	var focus: Array = perception.event_locations(e)
	var f := _base_frame(e, after, focus, "")
	for em in e.get("emits", []):
		f.bubbles.append({ "tile": _actor_tile(after, e.actor, f), "text": em.desc,
			"kind": "speech" if e.verb == "speak" else em.sense })
	var who := []
	var pv: Dictionary = testimony.perceivers_at(ei)
	for id in pv:
		if id != e.actor:
			who.append("%s (%s)" % [_name(id), ", ".join(pv[id])])
	title.text = "The truth  %s" % _clock(e.t)
	caption.text = "%s: %s\nPerceived by: %s" % [_name(e.actor), _describe(e), "no one" if who.is_empty() else "; ".join(who)]
	map.set_frame(f)


func _show_claim(c: Dictionary) -> void:
	var ei: int = data.event_index(c.get("event", ""))
	var basis: String = c.basis
	var f: Dictionary
	var t := "?"
	if ei >= 0:
		var e: Dictionary = timeline.event(ei)
		var after = timeline.state_after(ei)
		t = _clock(e.t)
		var senses: Array = testimony.perceivers_at(ei).get(WITNESS, [])
		f = _base_frame(e, after, [], WITNESS)
		var here: Vector2 = _actor_tile(after, WITNESS, f)
		f.center = here
		if not senses.has("sight"):
			for em in e.get("emits", []):
				if senses.has(em.sense):
					f.bubbles.append({ "tile": here, "text": "(heard) " + em.desc, "kind": em.sense })
		f.bubbles.append({ "tile": here, "text": c.as, "kind": "speech" })
		caption.text = "Helen: \"%s\"\nBasis: %s (%s)" % [c.as, basis, ", ".join(senses) if not senses.is_empty() else "nothing!"]
	else:
		var last = timeline.state_after(timeline.size() - 1)
		f = _base_frame({}, last, [], WITNESS)
		var ghost := { "id": c.actor, "tile": _spot(c.place), "pose": "stand", "alpha": 0.35, "label": c.actor + "?" }
		f.actors.append(ghost)
		f.center = ghost.tile
		f.rooms[c.place] = { "known": true, "lit": false, "focus": true, "name": data.locations[c.place].name }
		f.bubbles.append({ "tile": ghost.tile, "text": c.as, "kind": "thought" })
		caption.text = "Helen: \"%s\"\nBasis: %s. She never perceived this; the ghost is her theory." % [c.as, basis]
	title.text = "Helen's testimony  %s" % t
	map.set_frame(f)


# --- investigation ----------------------------------------------------------

var _room_shown := ""
var _result := ""   # caption for the last inspect/test


## Present day: every room known and lit, no one around, inspectable
## objects marked "?" until all their clues are found.
func _show_room(room: String) -> void:
	if room != _room_shown:
		_result = ""
	_room_shown = room
	var last = timeline.state_after(timeline.size() - 1)
	var f := { "rooms": {}, "doors": {}, "actors": [], "bubbles": [], "marks": {},
		"objects": data.objects.keys(), "center": _spot(room), "selected": selected }
	for id in layout.rooms:
		f.rooms[id] = { "lit": true, "known": true, "focus": id == room, "name": data.locations[id].name }
	for oid in last.objects:
		if last.objects[oid].has("door") and oid.begins_with("door_"):
			f.doors[oid] = last.objects[oid].door
	for oid in investigation.inspectables():
		f.marks[oid] = "done" if investigation.exhausted(oid) else "todo"
	if selected != "" and _bubble != "":
		f.bubbles.append({ "tile": Vector2(layout.objects[selected].x, layout.objects[selected].y),
			"text": _bubble, "kind": "thought" })
	var n: int = investigation.core_found()
	var total: int = investigation.core_total()
	title.text = "Investigate  %s" % data.locations[room].name
	play_btn.text = "Back" if _notes_open else "Notes %d/%d" % [n, total]
	caption.text = _result if _result != "" else "Tap a ? to inspect it. Swipe or use Room buttons to move.\nClues found: %d of %d." % [n, total]
	notebook.text = _notebook_text()
	if selected != "":
		var verbs: Array = investigation.test_verbs(selected)
		if not verbs.is_empty():
			action_btn.text = "%s the %s" % [verbs[0].capitalize(), _object_name(selected)]
	map.set_frame(f)
	_layout_for_mode()


var _bubble := ""


func _inspect(oid: String) -> void:
	if mode != "investigate":
		return
	selected = oid
	var results: Array = investigation.inspect(oid)
	_bubble = "!" if results.any(func(r): return r.new) else "..."
	_result = _results_text(_object_name(oid).capitalize(), results)
	_show_room(_room_shown)


func _test_selected() -> void:
	if selected == "":
		return
	var verb: String = investigation.test_verbs(selected)[0]
	var t: Dictionary = investigation.test(selected, verb)
	_bubble = "(no sound)" if t.emits.is_empty() else ", ".join(t.emits.map(func(e): return e.desc))
	_result = _results_text("%s the %s" % [verb.capitalize(), _object_name(selected)], t.results)
	_show_room(_room_shown)


func _results_text(head: String, results: Array) -> String:
	if results.is_empty():
		return head + "\nNothing more to learn here yet."
	var lines := [head]
	for r in results:
		lines.append(("NEW: " if r.new else "") + r.clue.text)
	return "\n".join(lines)


func _notebook_text() -> String:
	if investigation.found.is_empty():
		return "Notebook\n\nNo clues yet. Inspect the objects marked ?."
	var lines := ["Notebook  (%d of %d)" % [investigation.core_found(), investigation.core_total()], ""]
	for id in investigation.found:
		lines.append("- " + investigation.clues[id].text)
	return "\n".join(lines)


func _object_name(oid: String) -> String:
	return oid.replace("_middle", "").replace("_roylott", "").replace("_", " ")


## Rooms, doors and puppets for a state. With a witness, only the witness's
## room is known, and only actors she can see there are drawn.
func _base_frame(e: Dictionary, state, focus: Array, witness: String) -> Dictionary:
	var f := { "rooms": {}, "doors": {}, "actors": [], "bubbles": [] }
	if e.has("place"):
		f.center = _spot(e.place)
	var wloc: String = state.actors[witness].location if witness != "" else ""
	for id in layout.rooms:
		var lit: bool = perception._lit(id, e, state)
		f.rooms[id] = { "lit": lit, "known": witness == "" or id == wloc,
			"focus": focus.has(id) or id == wloc, "name": data.locations[id].name }
	f.objects = []
	for oid in data.objects:
		if f.rooms.get(data.objects[oid].get("location", ""), {}).get("known", false):
			f.objects.append(oid)
	for oid in state.objects:
		if state.objects[oid].has("door") and oid.begins_with("door_"):
			f.doors[oid] = state.objects[oid].door
	var per_loc := {}
	for id in state.actors:
		var a: Dictionary = state.actors[id]
		if witness != "" and id != witness and not (a.location == wloc and f.rooms[wloc].lit):
			continue
		var tile: Vector2
		var holder = a.get("in")
		if holder != null and layout.objects.has(holder):
			tile = Vector2(layout.objects[holder].x, layout.objects[holder].y)
		else:
			var n: int = per_loc.get(a.location, 0)
			per_loc[a.location] = n + 1
			tile = _spot(a.location) + Vector2(n * 0.7 - 0.35, -n * 0.35)
		var animal: bool = data.actors[id].get("kind") == "animal"
		f.actors.append({ "id": id, "tile": tile, "animal": animal,
			"pose": "lie" if not a.get("awake", true) else "stand",
			"alpha": 1.0, "label": "" if animal else _name(id).split(" ")[0] })
	return f


func _actor_tile(_state, id: String, f: Dictionary) -> Vector2:
	for a in f.actors:
		if a.id == id:
			return a.tile
	return Vector2.ZERO


func _spot(loc: String) -> Vector2:
	var s: Dictionary = layout.spots[loc]
	return Vector2(s.x, s.y)


func _testimony_of(witness: String) -> Dictionary:
	for t in data.testimonies:
		if t.witness == witness:
			return t
	return {}


func _name(id) -> String:
	if id != null and data.actors.has(id):
		return data.actors[id].name
	return str(id)


func _describe(e: Dictionary) -> String:
	var target = e.get("target")
	var s: String = e.verb.replace("_", " ")
	if target != null:
		s += " " + (_name(target) if data.actors.has(target) else str(target).replace("_", " "))
	return s


## "d1 03:00:15" -> "03:00:15"
func _clock(t: String) -> String:
	return t.split(" ")[1]
