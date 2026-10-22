## Prototype screen (portrait phone). Asks the core for state and perception,
## turns it into a frame for MapView. Two modes: the true night, or Helen's
## testimony replayed with only what she perceived (guesses as ghosts), or the
## present-day investigation: tap objects to find clues for the notebook,
## or solving: answer the case's questions, backing each with found clues.
## Once solved, Holmes explains: the true night replayed with its proofs.
extends Control

const CaseData = preload("res://src/core/case_data.gd")
const Timeline = preload("res://src/core/timeline.gd")
const Perception = preload("res://src/core/perception.gd")
const Testimony = preload("res://src/core/testimony.gd")
const Investigation = preload("res://src/core/investigation.gd")
const Deduction = preload("res://src/core/deduction.gd")
const MapView = preload("res://src/view/map_view.gd")

const CASE_DIR := "res://cases/speckled-band/"
const WITNESS := "helen"
const PLAY_SECONDS := 1.8
const MODES := ["brief", "testimony", "investigate", "solve", "truth"]
const MODE_NAMES := { "brief": "The case", "truth": "The truth", "testimony": "Helen's testimony", "investigate": "Investigate", "solve": "Solve", "explain": "Holmes explains" }
const SEARCH_ROOMS := ["middle_room", "roylott_room"]

var data
var timeline
var perception
var testimony
var investigation
var deduction
var layout: Dictionary = {}

var mode := "brief"   # one of MODES, or "explain"
var steps: Array = [] # brief: the scene; truth: event indices; testimony: claim dicts; investigate: room ids
var step := 0
var playing := false
var _play_t := 0.0

var map: Control
var title: Label
var caption: Label
var slider: HSlider
var mode_label: Label
var mode_prev: Button
var mode_next: Button
var play_btn: Button
var prev_btn: Button
var next_btn: Button
var action_btn: Button
var notebook: Label
var solve_box: VBoxContainer
var selected := ""
var _notes_open := false
var _scroll_at_down := 0


func _ready() -> void:
	data = CaseData.load_file(CASE_DIR + "case.json")
	layout = JSON.parse_string(FileAccess.get_file_as_string(CASE_DIR + "layout.json"))
	timeline = Timeline.new(data)
	perception = Perception.new(data)
	testimony = Testimony.new(timeline, perception)
	investigation = Investigation.new(data)
	_inspected.clear()
	deduction = Deduction.new(data, investigation)
	_build_ui()
	_set_mode("brief")


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
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	mode_prev = _button("<", func(): _step_mode(-1))
	mode_prev.size_flags_horizontal = Control.SIZE_FILL
	mode_prev.custom_minimum_size.x = 96
	tabs.add_child(mode_prev)
	mode_label = _label(22)
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(mode_label)
	mode_next = _button(">", func(): _step_mode(1))
	mode_next.size_flags_horizontal = Control.SIZE_FILL
	mode_next.custom_minimum_size.x = 96
	tabs.add_child(mode_next)
	box.add_child(tabs)

	map = MapView.new()
	map.layout = layout
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.swiped.connect(_go)
	map.tapped_object.connect(_inspect)
	map.tapped_room.connect(_describe_room)
	box.add_child(map)

	notebook = _label(21)
	notebook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	notebook.visible = false
	box.add_child(notebook)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	solve_box = VBoxContainer.new()
	solve_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solve_box.add_theme_constant_override("separation", 8)
	scroll.add_child(solve_box)
	box.add_child(scroll)

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
	if mode == "brief":
		steps = [data.raw.get("briefing", {})]
	elif mode == "truth":
		for i in timeline.size():
			steps.append(i)
	elif mode == "testimony":
		var t: Dictionary = _testimony_of(WITNESS)
		steps = t.claims.duplicate()
	elif mode == "investigate":
		steps = SEARCH_ROOMS.duplicate()
	elif mode == "solve":
		for q in deduction.questions:
			steps.append(q.id)
	else:
		steps = deduction.explanation.duplicate()
	var at := _mode_index()
	mode_label.text = "%d/%d  %s" % [at + 1, MODES.size(), MODE_NAMES[mode]]
	mode_prev.disabled = at == 0
	mode_next.disabled = at == MODES.size() - 1
	var searching := mode == "investigate"
	slider.visible = mode in ["truth", "testimony", "explain"]
	prev_btn.get_parent().visible = mode != "brief"
	prev_btn.text = "< Room" if searching else "< Prev"
	next_btn.text = "Room >" if searching else "Next >"
	play_btn.text = "Play"
	slider.max_value = steps.size() - 1
	step = -1
	slider.set_value_no_signal(0)
	_show(0)


## Tabs run in a line, not a loop: no wrapping past the first or last.
## Holmes explains sits in Solve's place.
func _mode_index() -> int:
	return MODES.find("solve" if mode == "explain" else mode)


func _step_mode(dir: int) -> void:
	var i := _mode_index() + dir
	if i >= 0 and i < MODES.size():
		_set_mode(MODES[i])


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
	elif mode == "solve" and deduction.all_solved():
		_set_mode("explain")
	elif mode == "solve":
		_submit()
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
	if mode == "brief":
		_show_brief(steps[i])
	elif mode == "truth":
		_show_truth(steps[i])
	elif mode == "testimony":
		_show_claim(steps[i])
	elif mode == "investigate":
		_show_room(steps[i])
	elif mode == "solve":
		_show_question()
	else:
		_show_explain(steps[i])
	_layout_for_mode()


func _layout_for_mode() -> void:
	var searching := mode == "investigate"
	map.visible = not (searching and _notes_open) and mode != "solve"
	solve_box.get_parent().visible = mode == "solve"
	notebook.visible = searching and _notes_open
	action_btn.visible = searching and selected != "" and not _notes_open \
		and not investigation.test_verbs(selected).is_empty()


# --- frames ---------------------------------------------------------------

## Arriving at the scene: the house as the night left it. Anything the
## case lists under "hide" (the culprit's tools) stays off the map.
func _show_brief(page: Dictionary) -> void:
	var last: int = timeline.size() - 1
	var f := _base_frame(timeline.event(last), timeline.state_after(last), page.get("focus", []), "")
	var hide: Array = page.get("hide", [])
	f.actors = f.actors.filter(func(a): return not hide.has(a.id))
	for id in f.rooms:
		f.rooms[id].lit = true  # the police bring lamps
	title.text = data.raw.meta.title
	caption.text = page.get("text", "")
	map.set_frame(f)


func _show_truth(ei: int) -> void:
	map.set_frame(_truth_frame(ei))


## Truth frame plus a caption and pointers at where the cited clues are found.
func _show_explain(s: Dictionary) -> void:
	var ei: int = data.event_index(s.event)
	var f := _truth_frame(ei)
	f.marks = {}
	var titles := []
	for id in s.clues:
		var c: Dictionary = investigation.clues[id]
		titles.append(c.title)
		var oid: String = c.source.get("object", "")
		if layout.objects.has(oid):
			f.marks[oid] = "done"
			f.selected = oid
	title.text = "Holmes explains  %s" % _clock(timeline.event(ei).t)
	caption.text = "Holmes: %s\nProof: %s" % [s.say, ", ".join(titles)]
	map.set_frame(f)


func _truth_frame(ei: int) -> Dictionary:
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
	return f


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
		for r in investigation.hear(WITNESS, c.event):
			caption.text += "\n%s %s" % ["Noted:" if r.new else "In notebook:", r.clue.title]
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
	f.labels = {}
	for oid in _inspected:
		f.labels[oid] = _object_name(oid)
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
var _inspected := {}  # oid -> true: objects the player has looked at, named on the map


func _inspect(oid: String) -> void:
	if mode != "investigate":
		return
	selected = oid
	_inspected[oid] = true
	var results: Array = investigation.inspect(oid)
	_bubble = "!" if results.any(func(r): return r.new) else "..."
	_result = _results_text(_object_name(oid).capitalize(), results)
	_show_room(_room_shown)


func _describe_room(id: String) -> void:
	if mode != "investigate" or not data.locations.has(id):
		return
	selected = ""
	_bubble = ""
	var loc: Dictionary = data.locations[id]
	_result = "%s\n%s" % [loc.name, loc.get("description", "")]
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
		var c: Dictionary = investigation.clues[id]
		lines.append("- %s: %s" % [c.title, c.text])
	return "\n".join(lines)


# --- solve ------------------------------------------------------------------

var _choice := {}      # question id -> picked option id
var _backing := {}     # question id -> picked clue ids
var _verdict := ""     # caption for the last submit


func _show_question() -> void:
	var q: Dictionary = deduction.questions[step]
	_verdict = ""
	title.text = "Solve  %d of %d solved" % [deduction.solved.size(), deduction.questions.size()]
	_build_question(q)
	_solve_caption()


func _build_question(q: Dictionary) -> void:
	for ch in solve_box.get_children():
		ch.queue_free()
	var ask := _label(24)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.text = "%d. %s" % [step + 1, q.ask]
	solve_box.add_child(ask)
	var done: bool = deduction.solved.has(q.id)
	for o in q.options:
		var b := _toggle(o.text, _choice.get(q.id, "") == o.id, func(): _pick_option(q.id, o.id))
		b.disabled = done
		solve_box.add_child(b)
	var need := _label(21)
	need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	need.text = "\nBack it up: pick %d clues from your notebook." % deduction.pick
	if investigation.found.is_empty():
		need.text += "\nYour notebook is empty. Investigate first."
	solve_box.add_child(need)
	var picked: Array = _backing.get(q.id, [])
	for id in investigation.found:
		var b := _toggle(investigation.clues[id].title, picked.has(id), func(): _pick_clue(q.id, id))
		b.custom_minimum_size.y = 72
		b.add_theme_font_size_override("font_size", 21)
		b.disabled = done
		solve_box.add_child(b)


## Solve-list buttons pass touches on to the scroll box, so a drag that
## starts on a button still scrolls, and a drag never counts as a pick.
func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var scroll: ScrollContainer = solve_box.get_parent()
	var b := _button(text, func():
		if abs(scroll.scroll_vertical - _scroll_at_down) > 8:
			_build_question(deduction.question(steps[step]))
		else:
			cb.call())
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.button_down.connect(func(): _scroll_at_down = scroll.scroll_vertical)
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	b.modulate = Color("#ffd75e") if on else Color.WHITE
	return b


func _pick_option(qid: String, oid: String) -> void:
	_choice[qid] = oid
	_verdict = ""
	_build_question(deduction.question(qid))
	_solve_caption()


func _pick_clue(qid: String, cid: String) -> void:
	var picked: Array = _backing.get(qid, [])
	if picked.has(cid):
		picked.erase(cid)
	else:
		picked.append(cid)
	_backing[qid] = picked
	_verdict = ""
	_build_question(deduction.question(qid))
	_solve_caption()


func _submit() -> void:
	var q: Dictionary = deduction.questions[step]
	if deduction.solved.has(q.id):
		return
	var v: Dictionary = deduction.answer(q.id, _choice.get(q.id, ""), _backing.get(q.id, []))
	_verdict = { "solved": "Solved! ", "weak": "", "wrong": "Not quite. " }[v.verdict] + v.text
	title.text = "Solve  %d of %d solved" % [deduction.solved.size(), deduction.questions.size()]
	if v.verdict == "solved":
		_build_question(q)
	_solve_caption()


func _solve_caption() -> void:
	var q: Dictionary = deduction.questions[step]
	if deduction.all_solved():
		caption.text = "Case closed.\n%s\nTap Explain to hear Holmes walk through the night." % data.raw.deduction.get("closing", "")
		play_btn.text = "Explain"
	elif deduction.solved.has(q.id):
		caption.text = "Solved: " + q.get("explain", "")
		play_btn.text = "Solved"
	else:
		caption.text = _verdict if _verdict != "" else "Pick an answer and %d clues, then Submit." % deduction.pick
		play_btn.text = "Submit"


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
