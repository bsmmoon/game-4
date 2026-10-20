## Present-day investigation: inspecting and testing objects reveals clues.
## Tracks what the player has found. Pure data, no display code.
extends RefCounted

var case_data
var clues: Dictionary = {}   # id -> clue dict
var found: Array = []        # clue ids, in discovery order


func _init(data) -> void:
	case_data = data
	for c in data.raw.get("clues", []):
		clues[c.id] = c


## Object ids the player can inspect or test.
func inspectables() -> Array:
	var out := []
	for oid in case_data.objects:
		var o: Dictionary = case_data.objects[oid]
		if not o.get("inspect", []).is_empty() or not o.get("tests", []).is_empty():
			out.append(oid)
	return out


func test_verbs(oid: String) -> Array:
	var out := []
	for t in case_data.objects[oid].get("tests", []):
		out.append(t.verb)
	return out


## Every inspection shows a result (digest rule 1): all clues whose
## requirements were met before this look come back, each marked new or
## already known. A gated clue needs a second look.
func inspect(oid: String) -> Array:
	var out := []
	var known := found.duplicate()
	for entry in case_data.objects[oid].get("inspect", []):
		if _met(entry.get("requires", []), known):
			out.append(_reveal(entry.clue))
	return out


## Returns { emits: [...], results: [{clue, new}] }. Emits let the view
## (and later the perception system) play what the test makes happen.
func test(oid: String, verb: String) -> Dictionary:
	for t in case_data.objects[oid].get("tests", []):
		if t.verb == verb:
			var results := []
			if _met(t.get("requires", []), found):
				results.append(_reveal(t.reveals))
			return { "emits": t.get("emits", []), "results": results }
	return { "emits": [], "results": [] }


## Hearing a witness's claim notes what they said (digest rule: testimony
## is evidence too). Returns [{clue, new}] for clues sourced from it.
func hear(witness: String, event: String) -> Array:
	var out := []
	for id in clues:
		var src: Dictionary = clues[id].get("source", {})
		if src.get("type") == "testimony" and src.get("witness") == witness and src.get("event") == event:
			out.append(_reveal(id))
	return out


## True once every clue this object can give has been found.
func exhausted(oid: String) -> bool:
	var o: Dictionary = case_data.objects[oid]
	for entry in o.get("inspect", []):
		if not found.has(entry.clue):
			return false
	for t in o.get("tests", []):
		if not found.has(t.reveals):
			return false
	return true


func core_total() -> int:
	return clues.values().filter(func(c): return c.get("core", false)).size()


func core_found() -> int:
	return found.filter(func(id): return clues[id].get("core", false)).size()


## Authoring check: every inspect/test points at a real clue, and every
## inspect/test clue is reachable from the object its source names.
func validate() -> Array:
	var errors := []
	var refs := {}
	for ref in case_data.raw.get("references", []):
		refs[ref.id] = ref
	var reachable := {}
	for oid in case_data.objects:
		var o: Dictionary = case_data.objects[oid]
		for entry in o.get("inspect", []):
			reachable[entry.clue] = [oid, "inspect"]
		for t in o.get("tests", []):
			reachable[t.reveals] = [oid, "test"]
	for id in reachable:
		if not clues.has(id):
			errors.append("%s %s reveals unknown clue %s" % [reachable[id][0], reachable[id][1], id])
	for id in clues:
		var src: Dictionary = clues[id].get("source", {})
		if src.get("type") == "testimony":
			if not _claims(src.get("witness", "")).has(src.get("event")):
				errors.append("clue %s cites %s on %s, who never claims it" % [id, src.get("witness"), src.get("event")])
		elif src.get("type") == "reference":
			if not refs.has(src.get("reference")):
				errors.append("clue %s cites unknown reference %s" % [id, src.get("reference")])
			elif refs[src.reference].get("found_in") != src.get("object"):
				errors.append("clue %s: reference %s is not found in %s" % [id, src.reference, src.get("object")])
			if reachable.get(id) != [src.get("object"), "inspect"]:
				errors.append("clue %s: reference must be inspected on %s" % [id, src.get("object")])
		elif src.get("type") in ["inspect", "test"]:
			if not reachable.has(id):
				errors.append("clue %s is never revealed" % id)
			elif reachable[id] != [src.get("object"), src.type]:
				errors.append("clue %s source says %s %s, but %s %s reveals it" % [id, src.type, src.get("object"), reachable[id][1], reachable[id][0]])
	return errors


func _claims(witness: String) -> Array:
	var out := []
	for t in case_data.testimonies:
		if t.witness == witness:
			for c in t.claims:
				if c.has("event"):
					out.append(c.event)
	return out


func _met(requires: Array, known: Array) -> bool:
	for id in requires:
		if not known.has(id):
			return false
	return true


func _reveal(id: String) -> Dictionary:
	var fresh := not found.has(id)
	if fresh:
		found.append(id)
	return { "clue": clues[id], "new": fresh }
