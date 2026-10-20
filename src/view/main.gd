## Prototype screen (portrait phone). Asks the core for state and perception,
## turns it into a frame for MapView. Two modes: the true night, or Helen's
## testimony replayed with only what she perceived (guesses as ghosts).
extends Control

const CaseData = preload("res://src/core/case_data.gd")
const Timeline = preload("res://src/core/timeline.gd")
const Perception = preload("res://src/core/perception.gd")
const Testimony = preload("res://src/core/testimony.gd")
const MapView = preload("res://src/view/map_view.gd")

const CASE_DIR := "res://cases/speckled-band/"
const WITNESS := "helen"
const PLAY_SECONDS := 1.8

var data
var timeline
var perception
var testimony
var layout: Dictionary = {}

var mode := "truth"   # "truth" | "testimony"
var steps: Array = [] # truth: event indices; testimony: claim dicts
var step := 0
var playing := false
var _play_t := 0.0

var map: Control
var title: Label
var caption: Label
var slider: HSlider
var mode_btn: Button
var play_btn: Button


func _ready() -> void:
	data = CaseData.load_file(CASE_DIR + "case.json")
	layout = JSON.parse_string(FileAccess.get_file_as_string(CASE_DIR + "layout.json"))
	timeline = Timeline.new(data)
	perception = Perception.new(data)
	testimony = Testimony.new(timeline, perception)
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
	mode_btn = _button("", func(): _set_mode("testimony" if mode == "truth" else "truth"))
	box.add_child(mode_btn)

	map = MapView.new()
	map.layout = layout
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.swiped.connect(_go)
	box.add_child(map)

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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_button("< Prev", func(): _go(-1)))
	play_btn = _button("Play", _toggle_play)
	row.add_child(play_btn)
	row.add_child(_button("Next >", func(): _go(1)))
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
	steps.clear()
	if mode == "truth":
		for i in timeline.size():
			steps.append(i)
		mode_btn.text = "Truth  |  tap: Helen's testimony"
	else:
		var t: Dictionary = _testimony_of(WITNESS)
		steps = t.claims.duplicate()
		mode_btn.text = "Helen's testimony  |  tap: truth"
	slider.max_value = steps.size() - 1
	step = -1
	slider.set_value_no_signal(0)
	_show(0)


func _go(dir: int) -> void:
	_show(clamp(step + dir, 0, steps.size() - 1))


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
	else:
		_show_claim(steps[i])


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
