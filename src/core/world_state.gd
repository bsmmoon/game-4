## A snapshot of the world: actor and object states. Built by replaying events.
extends RefCounted

var actors: Dictionary = {}   # id -> {location, awake, ...}
var objects: Dictionary = {}  # id -> states dict


static func initial(case_data):
	var s = load("res://src/core/world_state.gd").new()
	for id in case_data.actors:
		s.actors[id] = case_data.actors[id].get("start", {}).duplicate(true)
	for id in case_data.objects:
		s.objects[id] = case_data.objects[id].get("states", {}).duplicate(true)
	return s


func copy():
	var s = load("res://src/core/world_state.gd").new()
	s.actors = actors.duplicate(true)
	s.objects = objects.duplicate(true)
	return s


func apply(event: Dictionary) -> void:
	for fx in event.get("effects", []):
		if fx.has("actor"):
			actors[fx.actor].merge(fx.set, true)
		elif fx.has("object"):
			if not objects.has(fx.object):
				objects[fx.object] = {}
			objects[fx.object].merge(fx.set, true)
