## Solving the case: answer each question and back it with found clues.
## A wrong answer gets a hint, never a game over. Pure data, no display code.
extends RefCounted

const Investigation = preload("res://src/core/investigation.gd")

var case_data
var investigation
var questions: Array = []
var pick: int = 2            # clues needed to back an answer
var solved: Dictionary = {}  # question id -> option id
var explanation: Array = []  # [{event, clues, say}], replayed once solved


func _init(data, inv) -> void:
	case_data = data
	investigation = inv
	var d: Dictionary = data.raw.get("deduction", {})
	questions = d.get("questions", [])
	pick = d.get("pick", 2)
	explanation = d.get("explanation", [])


func question(qid: String) -> Dictionary:
	for q in questions:
		if q.id == qid:
			return q
	return {}


## Returns { verdict, text }. verdict is "solved", "wrong" (a hint in text)
## or "weak" (right answer, but the clues picked don't back it up).
func answer(qid: String, option_id: String, picked: Array) -> Dictionary:
	var q := question(qid)
	var opt := _option(q, option_id)
	if opt.is_empty():
		return { "verdict": "wrong", "text": "Pick an answer." }
	if not opt.get("correct", false):
		return { "verdict": "wrong", "text": opt.get("hint", "That doesn't fit.") }
	var backing := 0
	for id in picked:
		if investigation.found.has(id) and q.evidence.has(id):
			backing += 1
	if backing < pick:
		return { "verdict": "weak", "text": "Right, but prove it: %d of the clues you picked back this up. You need %d." % [backing, pick] }
	solved[qid] = option_id
	return { "verdict": "solved", "text": q.get("explain", "") }


func all_solved() -> bool:
	return solved.size() == questions.size()


## Authoring check: each question is fair, i.e. answerable from clues a
## player can actually find, and each wrong theory can be refuted.
func validate() -> Array:
	var errors := []
	var clues: Dictionary = investigation.clues
	var findable := _findable()
	for q in questions:
		var correct: Array = q.options.filter(func(o): return o.get("correct", false))
		if correct.size() != 1:
			errors.append("question %s has %d correct options" % [q.id, correct.size()])
		for o in q.options:
			if not o.get("correct", false) and o.get("hint", "") == "":
				errors.append("question %s option %s has no hint" % [q.id, o.id])
		var usable := 0
		for id in q.get("evidence", []):
			if not clues.has(id):
				errors.append("question %s cites unknown clue %s" % [q.id, id])
			elif not clues[id].get("core", false):
				errors.append("question %s cites non-core clue %s" % [q.id, id])
			elif not findable.has(id):
				errors.append("question %s cites unfindable clue %s" % [q.id, id])
			else:
				usable += 1
		if usable < pick:
			errors.append("question %s: only %d findable clues, needs %d" % [q.id, usable, pick])
	var hyps := {}
	for h in case_data.raw.get("hypotheses", []):
		hyps[h.id] = h
		for id in h.get("refuted_by", []):
			if not findable.has(id):
				errors.append("hypothesis %s refuted by unfindable clue %s" % [h.id, id])
	for q in questions:
		for o in q.options:
			if o.has("hypothesis") and not hyps.has(o.hypothesis):
				errors.append("question %s option %s cites unknown hypothesis %s" % [q.id, o.id, o.hypothesis])
	errors.append_array(_validate_explanation(findable))
	return errors


## The closing replay walks the true night in order, every step is backed
## by findable clues, and every core clue pays off somewhere.
func _validate_explanation(findable: Array) -> Array:
	var errors := []
	var cited := {}
	var last := -1
	for s in explanation:
		var ei: int = case_data.event_index(s.get("event", ""))
		if ei < 0:
			errors.append("explanation cites unknown event %s" % s.get("event"))
		elif ei <= last:
			errors.append("explanation step %s is out of order" % s.event)
		else:
			last = ei
		for id in s.get("clues", []):
			cited[id] = true
			if not findable.has(id):
				errors.append("explanation step %s cites unfindable clue %s" % [s.get("event"), id])
	for id in investigation.clues:
		if investigation.clues[id].get("core", false) and not cited.has(id):
			errors.append("core clue %s is never explained" % id)
	return errors


## Plays a thorough player on a fresh investigation: inspect and test
## everything until nothing new turns up, and hear every claim.
func _findable() -> Array:
	var sim = Investigation.new(case_data)
	for t in case_data.testimonies:
		for c in t.claims:
			if c.has("event"):
				sim.hear(t.witness, c.event)
	var before := -1
	while sim.found.size() != before:
		before = sim.found.size()
		for oid in sim.inspectables():
			sim.inspect(oid)
			for verb in sim.test_verbs(oid):
				sim.test(oid, verb)
	return sim.found


func _option(q: Dictionary, option_id: String) -> Dictionary:
	for o in q.get("options", []):
		if o.id == option_id:
			return o
	return {}
