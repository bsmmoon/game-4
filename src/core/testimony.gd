## Turns a testimony into a perception-limited script and checks it.
extends RefCounted

var timeline
var perception


func _init(tl, perc) -> void:
	timeline = tl
	perception = perc


func perceivers_at(i: int) -> Dictionary:
	return perception.perceivers(timeline.event(i), timeline.state_before(i), timeline.state_after(i))


## Event indices the witness actually perceived (ground truth from simulation).
func perceived_indices(witness: String) -> Array:
	var out := []
	for i in timeline.size():
		if perceivers_at(i).has(witness):
			out.append(i)
	return out


## Fairness rule 3: every "perceived" claim must match an event the witness
## could perceive, unless it is marked as a lie. Returns a list of problems.
func check(testimony: Dictionary) -> Array:
	var problems := []
	var witness: String = testimony.witness
	for claim in testimony.claims:
		if claim.basis != "perceived":
			continue
		var i: int = timeline.case_data.event_index(claim.get("event", ""))
		if i < 0:
			problems.append("%s: claim refers to unknown event %s" % [witness, claim.get("event")])
		elif not perceivers_at(i).has(witness):
			problems.append("%s could not have perceived %s (%s)" % [witness, claim.event, claim.as])
	return problems
