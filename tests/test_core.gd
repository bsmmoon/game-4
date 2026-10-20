## Headless test: godot --headless --path . -s tests/test_core.gd
extends SceneTree

const CaseData = preload("res://src/core/case_data.gd")
const Timeline = preload("res://src/core/timeline.gd")
const Perception = preload("res://src/core/perception.gd")
const Testimony = preload("res://src/core/testimony.gd")
const Investigation = preload("res://src/core/investigation.gd")
const Deduction = preload("res://src/core/deduction.gd")

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

	var inv = Investigation.new(data)
	_eq(inv.validate(), [], "clue data is consistent")
	_eq(inv.inspectables().size(), 9, "nine inspectable objects")
	_eq(inv.core_total(), 15, "fifteen core clues")
	var r: Array = inv.inspect("bell_rope")
	_eq(r.size(), 1, "rope gives one inspect clue")
	_true(r[0].new and r[0].clue.id == "C_rope_dummy", "rope inspect reveals the dummy rope")
	_true(not inv.inspect("bell_rope")[0].new, "second inspect shows the clue again, not new")
	_true(not inv.exhausted("bell_rope"), "rope still has a test to try")
	_eq(inv.test_verbs("bell_rope"), ["pull"], "rope can be pulled")
	var t: Dictionary = inv.test("bell_rope", "pull")
	_eq(t.results[0].clue.id, "C_rope_no_bell", "pulling the rope: no bell")
	_true(inv.exhausted("bell_rope"), "rope exhausted after inspect + test")
	_eq(inv.core_found(), 2, "two clues found")
	_eq(inv.test("bell_rope", "kick").results, [], "unknown test gives nothing")

	var gated = CaseData.new()
	gated._index({ "objects": [{ "id": "box", "inspect": [{ "clue": "A", "requires": [] }, { "clue": "B", "requires": ["A"] }] }],
		"clues": [{ "id": "A", "text": "a", "source": { "type": "inspect", "object": "box" } },
			{ "id": "B", "text": "b", "source": { "type": "inspect", "object": "box" } },
			{ "id": "C", "text": "c", "source": { "type": "inspect", "object": "jar" } }] })
	var gi = Investigation.new(gated)
	_eq(gi.inspect("box").size(), 1, "gated clue hidden until its requirement is found")
	_eq(gi.inspect("box").size(), 2, "gated clue shows once requirement found")
	_eq(gi.validate().size(), 1, "validator catches an unreachable clue")

	var heard: Array = inv.hear("helen", "E19")
	_true(heard.size() == 1 and heard[0].clue.id == "C_band", "hearing a claim notes the clue")
	_eq(inv.hear("helen", "E21"), [], "a claim with no clue gives nothing")
	_eq(inv.inspect("fauna_book")[0].clue.id, "C_ref_adder", "book reveals the adder reference")

	var dd = Deduction.new(data, inv)
	_eq(dd.validate(), [], "every question is answerable from findable clues")
	_eq(dd.answer("culprit", "gipsies", []).verdict, "wrong", "wrong suspect gets a hint")
	_true("shutters" in dd.answer("culprit", "gipsies", []).text, "gipsies hint points at the shutters")
	_eq(dd.answer("path", "vent", ["C_rope_dummy", "C_band"]).verdict, "weak", "one backing clue is not enough")
	_eq(dd.answer("path", "vent", ["C_rope_dummy", "C_bed_clamped"]).verdict, "weak", "unfound clues don't count")
	_eq(dd.answer("path", "vent", ["C_rope_dummy", "C_rope_no_bell"]).verdict, "solved", "two found backing clues solve it")
	_true(not dd.all_solved(), "one of three questions solved")
	_eq(dd.explanation.size(), 10, "ten explanation steps")
	dd.explanation = [dd.explanation[1], dd.explanation[0]]
	_true(dd.validate().size() > 1, "validator catches out-of-order steps and unexplained clues")

	var unfair = CaseData.new()
	unfair._index({ "objects": [], "clues": [{ "id": "X", "text": "x", "core": true, "source": { "type": "inspect", "object": "nowhere" } }],
		"deduction": { "pick": 1, "questions": [{ "id": "q", "ask": "?", "evidence": ["X"],
			"options": [{ "id": "a", "correct": true }, { "id": "b" }] }] } })
	_eq(Deduction.new(unfair, Investigation.new(unfair)).validate().size(), 4, "validator catches unfindable evidence, too few clues, missing hint, unexplained clue")

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
