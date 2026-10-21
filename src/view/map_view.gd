## Isometric puppet view. Draws a frame prepared by main.gd. No game logic:
## it only knows tile positions (layout.json) and what the frame says to show.
extends Control

signal swiped(dir: int)
signal tapped_object(oid: String)

const DOOR_COLORS := { "open": Color("#6fbf73"), "closed": Color("#d9a441"), "locked": Color("#d0503c") }
const BUBBLE_COLORS := { "sound": Color("#fff6d8"), "speech": Color("#ffffff"), "light": Color("#fff3a0"), "smell": Color("#e2d6f5"), "thought": Color("#d8d8e8") }

var layout: Dictionary = {}
## frame = { rooms: {id: {lit, known, focus}}, doors: {id: state},
##           actors: [{id, tile, pose, alpha, label}], bubbles: [{tile, text, kind}],
##           objects: [ids to draw] (optional), center: tile the camera follows,
##           marks: {oid: "todo"|"done"} tappable objects (optional), selected: oid }
var frame: Dictionary = {}

const ZOOM := 1.6      # camera zoom over "whole house fits the width"
const ZOOM_MAX := 4.0  # player zoom on top of ZOOM
const WALL_H := 1.0    # wall height in tiles

var zoom := 1.0        # player zoom: pinch, wheel or +/- buttons
var _pan := Vector2.ZERO        # player pan, in raw iso units from the center
var _touches := {}     # finger index -> position, for pinching
var _gesture := false  # a drag or pinch is under way: release is not a tap
var _span := Vector2.ONE

var _shown := {}       # actor id -> animated tile position
var _center := Vector2(-1, -1)  # animated camera target (tile)
var _k := 1.0          # pixels per tile width
var _origin := Vector2.ZERO
var _press := Vector2.ZERO
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true   # zoomed in, the house must not spill over the UI
	var bar := VBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -76
	bar.offset_top = 4
	bar.offset_right = -4
	add_child(bar)
	for z in [["+", 1.5], ["-", 1.0 / 1.5]]:
		var b := Button.new()
		b.text = z[0]
		b.custom_minimum_size = Vector2(72, 72)
		b.add_theme_font_size_override("font_size", 32)
		b.modulate = Color(1, 1, 1, 0.8)
		b.pressed.connect(func(): zoom_at(size * 0.5, z[1]))
		bar.add_child(b)


func set_frame(f: Dictionary) -> void:
	if f.get("center") != frame.get("center"):
		_pan = Vector2.ZERO   # the story moved on: follow it again
	frame = f
	for a in f.get("actors", []):
		if not _shown.has(a.id):
			_shown[a.id] = a.tile
	queue_redraw()


func _process(delta: float) -> void:
	var moving := false
	var goal: Vector2 = frame.get("center", _center)
	if _center.x < 0:
		_center = goal
	if _center.distance_to(goal) > 0.01:
		_center = _center.lerp(goal, min(1.0, delta * 4.0))
		moving = true
	for a in frame.get("actors", []):
		var cur: Vector2 = _shown.get(a.id, a.tile)
		if cur.distance_to(a.tile) > 0.01:
			_shown[a.id] = cur.lerp(a.tile, min(1.0, delta * 6.0))
			moving = true
		else:
			_shown[a.id] = a.tile
	if moving:
		queue_redraw()


## Zoom by factor, keeping the point p (local coords) still on screen.
func zoom_at(p: Vector2, factor: float) -> void:
	var nz: float = clamp(zoom * factor, 1.0, ZOOM_MAX)
	if nz == zoom:
		return
	_fit()
	var q := (p - _origin) / _k            # raw iso point under p
	zoom = nz
	_fit()
	_pan += q - (p - _origin) / _k
	if zoom == 1.0:
		_pan = Vector2.ZERO
	_clamp_pan()
	queue_redraw()


func _clamp_pan() -> void:
	_pan = _pan.clamp(-_span * 0.6, _span * 0.6)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
		else:
			_touches.erase(ev.index)
	elif ev is InputEventScreenDrag and _touches.has(ev.index):
		if _touches.size() == 2:
			var other: Vector2 = _touches[_touches.keys().filter(func(i): return i != ev.index)[0]]
			var before: float = other.distance_to(_touches[ev.index])
			var after: float = other.distance_to(ev.position)
			if before > 10:
				zoom_at((other + ev.position) * 0.5, after / before)
			_gesture = true
		_touches[ev.index] = ev.position
	elif ev is InputEventMagnifyGesture:
		zoom_at(ev.position, ev.factor)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_at(ev.position, 1.15 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT and zoom > 1.0:
		if _touches.size() < 2:
			_pan -= ev.relative / _k
			_clamp_pan()
			queue_redraw()
		if ev.position.distance_to(_press) > 20:
			_gesture = true
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press = ev.position
			_gesture = false
		elif _gesture:
			_gesture = false
		else:
			var d: Vector2 = ev.position - _press
			if abs(d.x) > 60 and abs(d.x) > abs(d.y):
				swiped.emit(-1 if d.x > 0 else 1)
			elif d.length() < 20:
				var oid := object_at(ev.position)
				if oid != "":
					tapped_object.emit(oid)


## Nearest tappable object to a point (local coords), within a finger's reach.
func object_at(p: Vector2) -> String:
	var best := ""
	var best_d: float = max(44.0, _k * 0.3)
	for oid in frame.get("marks", {}):
		if layout.objects.has(oid):
			var d := iso(Vector2(layout.objects[oid].x, layout.objects[oid].y)).distance_to(p)
			if d < best_d:
				best_d = d
				best = oid
	return best


# --- projection -----------------------------------------------------------

func _iso_raw(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 0.5, (p.x + p.y) * 0.25)


func iso(p: Vector2) -> Vector2:
	return _origin + _iso_raw(p) * _k


func _fit() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in layout.rooms.values():
		for c in [Vector2(r.x, r.y), Vector2(r.x + r.w, r.y), Vector2(r.x, r.y + r.h), Vector2(r.x + r.w, r.y + r.h)]:
			var q := _iso_raw(c)
			lo = lo.min(q)
			hi = hi.max(q)
	var span := hi - lo
	_span = span
	_k = min(size.x * 0.94 / span.x, size.y * 0.80 / span.y) * ZOOM * zoom
	var c := (_iso_raw(_center) if _center.x >= 0 else lo + span * 0.5) + _pan
	_origin = size * 0.5 - c * _k + Vector2(0, size.y * 0.12)


# --- drawing --------------------------------------------------------------

func _draw() -> void:
	if layout.is_empty():
		return
	_fit()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#14161c"))
	var rooms: Dictionary = frame.get("rooms", {})
	var order: Array = layout.rooms.keys()
	order.sort_custom(func(a, b): return layout.rooms[a].x + layout.rooms[a].y < layout.rooms[b].x + layout.rooms[b].y)
	for id in order:
		_draw_room(id, layout.rooms[id], rooms.get(id, {}))
	var visible_objects: Array = frame.get("objects", layout.objects.keys())
	var shown: Array = layout.objects.keys().filter(func(oid): return not oid.begins_with("door_") and visible_objects.has(oid))
	shown.sort_custom(func(a, b): return layout.objects[a].x + layout.objects[a].y < layout.objects[b].x + layout.objects[b].y)
	for oid in shown:
		_draw_object(oid, layout.objects[oid])
	for oid in frame.get("marks", {}):
		if layout.objects.has(oid):
			_draw_mark(layout.objects[oid], frame.marks[oid], frame.get("selected", "") == oid)
	for oid in frame.get("doors", {}):
		if layout.objects.has(oid):
			_draw_door(layout.objects[oid], frame.doors[oid])
	var actors: Array = frame.get("actors", []).duplicate()
	actors.sort_custom(func(a, b): return _pos(a).x + _pos(a).y < _pos(b).x + _pos(b).y)
	for a in actors:
		_draw_puppet(a)
	var stack := {}
	for b in frame.get("bubbles", []):
		var key := str(b.tile)
		stack[key] = stack.get(key, 0) + 1
		_draw_bubble(b, stack[key] - 1)


func _pos(a: Dictionary) -> Vector2:
	return _shown.get(a.id, a.tile)


func _draw_room(id: String, r: Dictionary, st: Dictionary) -> void:
	var pts := PackedVector2Array([iso(Vector2(r.x, r.y)), iso(Vector2(r.x + r.w, r.y)),
		iso(Vector2(r.x + r.w, r.y + r.h)), iso(Vector2(r.x, r.y + r.h))])
	var base := Color("#c9b48a") if id != "lawn" else Color("#4f7a45")
	if id == "corridor":
		base = Color("#a89a80")
	var col := base if st.get("lit", false) else base.darkened(0.65)
	if not st.get("known", true):
		col = col.darkened(0.7)
	draw_colored_polygon(pts, col)
	var edge := Color("#ffe08a") if st.get("focus", false) else Color(0, 0, 0, 0.6)
	draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 3.0 if st.get("focus", false) else 1.5, true)
	if id != "lawn":
		_draw_walls(r, col)
	if st.get("known", true):
		var name: String = st.get("name", id)
		var at := iso(Vector2(r.x + 0.3, r.y + 0.3)) + Vector2(-_k * 0.4, _k * 0.15)
		draw_string(_font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(17), Color(1, 1, 1, 0.55))


## Cutaway walls: only the back two (north and west), so nothing in the room
## is hidden. open_north skips the north one (the corridor's is the rooms' front).
func _draw_walls(r: Dictionary, floor_col: Color) -> void:
	var hi := Vector2(0, -_k * 0.5 * WALL_H)
	var wall := Color("#8c7a5e").lerp(floor_col, 0.3)
	var nw := iso(Vector2(r.x, r.y))
	var sw := iso(Vector2(r.x, r.y + r.h))
	var ne := iso(Vector2(r.x + r.w, r.y))
	draw_colored_polygon(PackedVector2Array([sw, nw, nw + hi, sw + hi]), wall.darkened(0.2))
	if not r.get("open_north", false):
		draw_colored_polygon(PackedVector2Array([nw, ne, ne + hi, nw + hi]), wall)
		draw_line(nw + hi, ne + hi, Color(0, 0, 0, 0.5), 2.0, true)
	draw_line(sw + hi, nw + hi, Color(0, 0, 0, 0.5), 2.0, true)
	draw_line(nw, nw + hi, Color(0, 0, 0, 0.35), 1.0, true)


## Label size for the current zoom: grows with it, but less than the map.
func _fs(base: int) -> int:
	return int(base * min(sqrt(zoom), 2.0))


func _draw_object(oid: String, o: Dictionary) -> void:
	var s := iso(Vector2(o.x, o.y))
	var parts: Array = o.get("parts", [])
	if parts.is_empty():
		draw_circle(s, _k * 0.06, Color("#3a2f25"))
	for p in parts:
		_draw_box(Vector2(o.x + p[0], o.y + p[1]), Vector3(p[2], p[3], p[4]), p[5], Color(p[6]))
	draw_string(_font, s + Vector2(_k * 0.08, _k * 0.12), oid.replace("_", " ").replace(" middle", "").replace(" roylott", ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(14), Color(1, 1, 1, 0.5))


## An upright box centered on tile c: w along x, d along y, h tall, its
## bottom z above the floor. Draws the top and the two faces toward the viewer.
func _draw_box(c: Vector2, size3: Vector3, z: float, col: Color) -> void:
	var up := Vector2(0, -_k * 0.5)
	var x0 := c.x - size3.x * 0.5
	var x1 := c.x + size3.x * 0.5
	var y0 := c.y - size3.y * 0.5
	var y1 := c.y + size3.y * 0.5
	var lo := up * z
	var hi := up * (z + size3.z)
	var p := func(x, y, h): return iso(Vector2(x, y)) + h
	draw_colored_polygon(PackedVector2Array([p.call(x0, y1, lo), p.call(x1, y1, lo), p.call(x1, y1, hi), p.call(x0, y1, hi)]), col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([p.call(x1, y0, lo), p.call(x1, y1, lo), p.call(x1, y1, hi), p.call(x1, y0, hi)]), col.darkened(0.45))
	var top := PackedVector2Array([p.call(x0, y0, hi), p.call(x1, y0, hi), p.call(x1, y1, hi), p.call(x0, y1, hi)])
	draw_colored_polygon(top, col)
	draw_polyline(top + PackedVector2Array([top[0]]), Color(0, 0, 0, 0.35), 1.0, true)


func _draw_mark(o: Dictionary, mark: String, selected: bool) -> void:
	var s := iso(Vector2(o.x, o.y))
	var r: float = max(14.0, _k * 0.12)
	var col := Color("#6fbf73") if mark == "done" else Color("#ffd84a")
	if selected:
		draw_circle(s, r * 1.5, Color(col, 0.3))
	draw_arc(s, r, 0, TAU, 24, col, 3.0, true)
	var glyph := "ok" if mark == "done" else "?"
	draw_string(_font, s + Vector2(-r, r * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r), col)


func _draw_door(o: Dictionary, state: String) -> void:
	var s := iso(Vector2(o.x, o.y))
	var w := _k * 0.22
	draw_rect(Rect2(s - Vector2(w, w * 0.35), Vector2(w * 2, w * 0.7)), DOOR_COLORS.get(state, Color.GRAY))


func _draw_puppet(a: Dictionary) -> void:
	var s := iso(_pos(a))
	var u := _k
	var col: Color = Color(layout.actor_colors.get(a.id, "#cccccc"))
	col.a = a.get("alpha", 1.0)
	var shade := Color(0, 0, 0, 0.35 * col.a)
	draw_set_transform(s, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, u * 0.16, shade)
	draw_set_transform(Vector2.ZERO)
	if a.get("animal", false):
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(s + Vector2((i - 4) * u * 0.05, sin(i * 1.3) * u * 0.035 - u * 0.04))
		draw_polyline(pts, col, max(2.0, u * 0.04), true)
	elif a.get("pose", "stand") == "lie":
		draw_rect(Rect2(s + Vector2(-u * 0.22, -u * 0.12), Vector2(u * 0.44, u * 0.12)), col)
		draw_circle(s + Vector2(-u * 0.28, -u * 0.08), u * 0.08, col.lightened(0.25))
	else:
		draw_rect(Rect2(s + Vector2(-u * 0.09, -u * 0.42), Vector2(u * 0.18, u * 0.40)), col)
		draw_circle(s + Vector2(0, -u * 0.52), u * 0.10, col.lightened(0.25))
	var label: String = a.get("label", "")
	if label != "":
		draw_string(_font, s + Vector2(-u * 0.5, u * 0.16), label, HORIZONTAL_ALIGNMENT_CENTER, u, _fs(16), Color(1, 1, 1, col.a))


func _draw_bubble(b: Dictionary, slot: int) -> void:
	var fs := _fs(19)
	var maxw := size.x * 0.6
	var text: String = b.text
	var ts := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs)
	var pad := Vector2(10, 6)
	var anchor := iso(b.tile) + Vector2(0, -_k * 0.75)
	var box := Rect2(anchor - Vector2(ts.x * 0.5 + pad.x, ts.y + pad.y * 2) - Vector2(0, slot * (ts.y + 24)), ts + pad * 2)
	box.position.x = clamp(box.position.x, 4.0, size.x - box.size.x - 4.0)
	box.position.y = max(box.position.y, 4.0)
	var col: Color = BUBBLE_COLORS.get(b.kind, Color.WHITE)
	draw_rect(box, col)
	draw_rect(box, Color(0, 0, 0, 0.7), false, 2.0)
	if slot == 0:
		var tip := box.position + Vector2(box.size.x * 0.5, box.size.y)
		var foot := Vector2(clamp(anchor.x, box.position.x + 8, box.end.x - 8), anchor.y + 10)
		draw_colored_polygon(PackedVector2Array([tip - Vector2(8, 1), tip + Vector2(8, -1), foot]), col)
	draw_multiline_string(_font, box.position + pad + Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, maxw, fs, -1, Color("#1a1a1a"))
