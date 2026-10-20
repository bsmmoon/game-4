## Headless test: godot --headless --path . -s tests/test_core.gd
extends SceneTree

const CaseData = preload("res://src/core/case_data.gd")
const Timeline = preload("res://src/core/timeline.gd")
const Perception = preload("res://src/core/perception.gd")
const Testimony = preload("res://src/core/testimony.gd")

var failures := 0


func _init() -> void:
	var data = CaseData.load_file("res://cases/speckled-band/case.json")
	var tl = Timeline.new(data)
	var tm = Testimony.new(tl, Perception.new(data))

	_eq(tl.size(), 23, "event count")
	var final = tl.states[tl.size()]
	_eq(final.actors.adder.get("in"), "safe", "adder back in the safe")
	_eq(final.actors.julia.location, "corridor", "julia ends in corridor")
	_eq(final.objects.door_middle.door, "open", "julia's door open at the end")

	var helen := []
	for i in tm.perceived_indices("helen"):
		helen.append(tl.event(i).id)
	print("Helen perceives: ", helen)
	for id in ["E03", "E12", "E14", "E16", "E17", "E18", "E19", "E20", "E21", "E22"]:
		_true(id in helen, "helen perceives " + id)
	for id in ["E06", "E07", "E08", "E09", "E10", "E11", "E15"]:
		_true(not (id in helen), "helen does not perceive " + id)

	var julia_bite = tm.perceivers_at(data.event_index("E10"))
	_true(julia_bite.has("julia"), "julia perceives the bite")
	_true(not tm.perceivers_at(data.event_index("E06")).has("julia"), "sleeping julia misses the lantern")

	var problems = tm.check(data.testimonies[0])
	_eq(problems.size(), 0, "helen's testimony is consistent: %s" % [problems])

	var bad = {"witness": "helen", "claims": [{"event": "E09", "basis": "perceived", "as": "I heard a hiss."}]}
	_eq(tm.check(bad).size(), 1, "checker rejects an impossible claim")

	print("FAILURES: %d" % failures if failures else "ALL TESTS PASSED")
	quit(1 if failures else 0)


func _eq(a, b, label: String) -> void:
	if a != b:
		failures += 1
		print("FAIL %s: got %s, expected %s" % [label, a, b])


func _true(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		print("FAIL " + label)
