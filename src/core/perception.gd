## Decides who could perceive each event, from location, connections,
## passage states, light and wakefulness. Pure logic.
extends RefCounted

const COST_OPEN := 0
const COST_CLOSED := 2
const COST_WALL := 2
const COST_VENT := 1

var case_data


func _init(data) -> void:
	case_data = data


## Locations where the event happens: its place, a target location (move),
## and both sides of a target passage (door, window).
func event_locations(e: Dictionary) -> Array:
	var locs := [e.place]
	var target = e.get("target")
	if target != null and case_data.locations.has(target):
		locs.append(target)
	elif target != null:
		for c in case_data.locations[e.place].connections:
			if c.get("via") == target and not locs.has(c.to):
				locs.append(c.to)
	return locs


## Returns {actor_id: [senses]} for everyone who perceives event e.
func perceivers(e: Dictionary, before, after) -> Dictionary:
	var result := {}
	var locs := event_locations(e)
	for id in case_data.actors:
		var senses := []
		var a_before: Dictionary = before.actors[id]
		var a_after: Dictionary = after.actors[id]
		if id == e.actor or id == e.get("target"):
			senses.append("self")
		var awake: bool = a_before.get("awake", true) or a_after.get("awake", true)
		if not awake and senses.is_empty():
			continue
		var loc: String = a_before.location
		if locs.has(loc) or locs.has(a_after.location):
			if _lit(loc, e, before):
				senses.append("sight")
		for em in e.get("emits", []):
			match em.sense:
				"sound":
					if _sound_reaches(locs, loc, int(em.loudness), before):
						senses.append("sound")
				"smell", "light":
					if locs.has(loc) or _adjacent_passing(e.place, loc, em.sense, before):
						senses.append(em.sense)
		if not senses.is_empty():
			result[id] = senses
	return result


func _lit(loc: String, e: Dictionary, state) -> bool:
	if case_data.locations[loc].get("light") == "lit":
		return true
	for em in e.get("emits", []):
		if em.sense == "light":
			return true
	for oid in state.objects:
		if state.objects[oid].get("lit", false) and case_data.objects[oid].get("location") == loc:
			return true
	return false


func _passage_cost(c: Dictionary, state) -> int:
	match c.kind:
		"wall":
			return COST_WALL
		"vent":
			return COST_VENT
		_:
			var st = state.objects.get(c.via, {}).get("door", "closed")
			return COST_OPEN if st == "open" else COST_CLOSED


## Cheapest muffling cost from any source location to the listener (Dijkstra).
func _sound_reaches(sources: Array, listener: String, loudness: int, state) -> bool:
	var best := {}
	var frontier := []
	for s in sources:
		best[s] = 0
		frontier.append(s)
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return best[a] < best[b])
		var cur: String = frontier.pop_front()
		for c in case_data.locations[cur].connections:
			var cost: int = best[cur] + _passage_cost(c, state)
			if cost < best.get(c.to, 1 << 30):
				best[c.to] = cost
				frontier.append(c.to)
	return loudness - best.get(listener, 1 << 30) >= 1


func _adjacent_passing(from: String, to: String, sense: String, state) -> bool:
	for c in case_data.locations[from].connections:
		if c.to != to:
			continue
		if sense in c.get("passes", []):
			return true
		if c.kind == "door" and _passage_cost(c, state) == COST_OPEN:
			return true
	return false
