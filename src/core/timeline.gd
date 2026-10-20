## Ordered events plus the world state before/after each one.
extends RefCounted

const WorldState = preload("res://src/core/world_state.gd")

var case_data
var states: Array = []  # states[i] = world before events[i]; states[n] = final


func _init(data) -> void:
	case_data = data
	var s = WorldState.initial(data)
	states.append(s)
	for e in data.events:
		s = s.copy()
		s.apply(e)
		states.append(s)


func size() -> int:
	return case_data.events.size()


func event(i: int) -> Dictionary:
	return case_data.events[i]


func state_before(i: int):
	return states[i]


func state_after(i: int):
	return states[i + 1]
