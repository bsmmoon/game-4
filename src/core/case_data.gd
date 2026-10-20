## Loads a case.json and indexes it. Pure data, no display code.
extends RefCounted

var raw: Dictionary = {}
var locations: Dictionary = {}   # id -> location dict
var objects: Dictionary = {}     # id -> object dict
var actors: Dictionary = {}      # id -> actor dict
var events: Array = []           # sorted by time
var testimonies: Array = []


static func load_file(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read case file: %s" % path)
		return null
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid case JSON: %s" % path)
		return null
	var data = load("res://src/core/case_data.gd").new()
	data._index(parsed)
	return data


func _index(d: Dictionary) -> void:
	raw = d
	for l in d.get("locations", []):
		locations[l.id] = l
	for o in d.get("objects", []):
		objects[o.id] = o
	for a in d.get("actors", []):
		actors[a.id] = a
	events = d.get("events", []).duplicate()
	for e in events:
		e["seconds"] = parse_time(e.t)
	events.sort_custom(func(a, b): return a.seconds < b.seconds)
	testimonies = d.get("testimonies", [])


## "d1 03:00:15" -> seconds since day 0 midnight.
static func parse_time(t: String) -> int:
	var parts := t.split(" ")
	var day := int(parts[0].substr(1))
	var hms := parts[1].split(":")
	return day * 86400 + int(hms[0]) * 3600 + int(hms[1]) * 60 + (int(hms[2]) if hms.size() > 2 else 0)


func event_index(id: String) -> int:
	for i in events.size():
		if events[i].id == id:
			return i
	return -1
