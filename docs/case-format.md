# Case Format — v0.2 (draft)

Drafted from *The Speckled Band* digest (Phase 4 of `case-digestion`). Each new case is checked against this format, and changes need Moon's approval.

## Principles

1. **A case is data.** One case = one folder `cases/<slug>/` holding `case.json`. The engine has no case-specific code.
2. **The display is a view.** The logic layer (simulator, perception, fairness checker, deduction checker) reads only `case.json`. The display (the isometric puppets for now) gets read-only state snapshots and a stream of events, and has no game logic. Any display, even a text log, can replace it.
3. **One event-script format for everything.** The true timeline, each testimony, and the player's theory all use the same event format, so all three can be replayed and compared.
4. **Fair by construction.** Every clue says how the player gets it, and every reasoning step lists its premises. A checker proves the solution can be reached (see Validation).
5. **World rules are stated in the world.** Any outside knowledge the solution needs exists as a reference entry the player can find.

**Why JSON:** Godot parses it natively, agents write it reliably, and validation tools can be written in any language.

## Top-level structure

```
case.json
├── meta          id, title, source, version, difficulty
├── verbs         action verbs this case uses (from the global registry)
├── locations     places, plus connections between them
├── objects       things in locations: states, inspect results, tests
├── actors        people and animals: traits, routines
├── documents     readable texts (will, inquest, letters)
├── references    world rules the player can look up (creatures, poisons)
├── events        the TRUE timeline as an event script
├── testimonies   each witness's claimed event script, per topic
├── clues         atoms of evidence and how each is obtained
├── hypotheses    theories the player can form, incl. red herrings
├── deduction     questions, solution cards, reasoning chain
└── flow          scenes, travel, unlock conditions, climax
```

## Sections

### `locations`
```json
{ "id": "middle_room", "name": "Julia's room", "scene": "stoke_moran",
  "light": "dark",
  "connections": [
    { "to": "corridor", "via": "door_middle", "kind": "door" },
    { "to": "roylott_room", "via": "ventilator", "kind": "vent",
      "passes": ["sound", "smell", "light"], "traversable_by": ["small_animal"] }
  ] }
```
`passes` tells the perception system what crosses the connection. A wall passes loud sound only. A closed door passes sound but not sight.

### `objects`
```json
{ "id": "bell_rope", "location": "middle_room",
  "states": { "attached": "hook" },
  "inspect": [ { "clue": "C_rope_dummy", "requires": [] } ],
  "tests": [ { "verb": "pull", "emits": [], "reveals": "C_rope_no_bell" } ] }
```
Every `inspect` and `test` result must reference a clue that is shown to the player (digest rule 1: no silent inspections).

### `actors`
```json
{ "id": "roylott", "kind": "human", "traits": ["strong", "violent"],
  "routine": [ { "t": "dusk", "verb": "enter", "target": "roylott_room" },
               { "t": "21:00", "verb": "extinguish", "target": "lamp_roylott" } ] }
```
Animals are actors too (`"kind": "animal"`, plus a `size` class used by `traversable_by`).

### `events` — the event script
```json
{ "id": "E12", "t": "1881-04-02T03:00", "approx": true,
  "actor": "roylott", "verb": "whistle", "target": null, "place": "roylott_room",
  "emits": [ { "sense": "sound", "loudness": 2, "desc": "a low, clear whistle" } ],
  "effects": [ { "actor": "adder", "set": { "goal": "return" } } ] }
```
- `emits` are what senses can pick up. The simulator works out who perceives each event from location, connections, light, and whether actors are awake.
- `perceived_by` can be added as an author override or as a check the simulator must agree with.
- `effects` change state, so the display can rebuild any moment by replaying events.

### `testimonies`
```json
{ "witness": "helen", "topic": "night_of_julias_death",
  "claims": [
    { "event": "E12", "basis": "perceived", "as": "a low whistle, then a clang" },
    { "verb": "enter", "actor": "gipsies", "basis": "guess" }
  ] }
```
`basis` is one of `perceived` (must match an event she could perceive), `heard_from`, `guess` or `lie`. The checker flags a `perceived` claim the witness couldn't have perceived, unless it's marked as a lie. Replaying a testimony shows only what she perceived, plus her guesses drawn as "ghost" puppets.

### `clues`
```json
{ "id": "C_chair_marks", "text": "Boot marks on the chair seat.",
  "source": { "type": "inspect", "object": "chair_roylott" },
  "available": { "after": ["enter:roylott_room"] }, "core": true }
```
`source.type` is one of `inspect`, `test`, `testimony`, `document`, `reference`, `observe_person` or `stakeout`. `core: false` marks flavour clues (e.g. Holmes reading Helen's sleeve). Every clue has a short `title` for the notebook and the Solve screen.

v0.2 (built): a `reference` clue also names its `reference` and is revealed by inspecting `object` (the book). A `testimony` clue names `witness` and `event`, and is noted when the player hears that claim. The checker requires the witness to actually make that claim.

### `references`
```json
{ "id": "R_swamp_adder", "title": "The Swamp Adder", "found_in": "fauna_book",
  "facts": ["comes back to a whistle", "drinks milk",
            "venom leaves no trace in chemical tests", "leaves two tiny puncture marks"] }
```

### `hypotheses`
```json
{ "id": "H_gipsies", "statement": "The gipsies killed Julia.",
  "refuted_by": ["C_shutters_barred", "C_door_locked_inside"] }
```

### `deduction`
v0.2 (built, replaces the event-card sketch below for now):
```json
{ "pick": 2, "closing": "Dr. Roylott sent a trained swamp adder...",
  "questions": [
    { "id": "culprit", "ask": "Who killed Julia?",
      "options": [ { "id": "roylott", "text": "Dr. Roylott", "correct": true },
                   { "id": "gipsies", "text": "The gipsies", "hypothesis": "H_gipsies",
                     "hint": "How would anyone outside get in? Look at the shutters..." } ],
      "evidence": ["C_vent_inner", "C_chair_marks", "..."],
      "explain": "Only Roylott's room connects to Julia's..." } ] }
```
The player picks an option and backs it with `pick` found clues from `evidence`. A wrong option shows its `hint`; the right option with weak backing says how many picked clues count. Nothing is ever a game over. The checker requires exactly one correct option per question, a hint on every wrong option, at least `pick` evidence clues that are core and findable by a simulated thorough player, and findable `refuted_by` clues for every hypothesis.

v0.1 sketch (event cards, not built yet):
```json
{ "questions": ["culprit", "method", "motive", "proof"],
  "solution": [ { "actor": "roylott", "verb": "release", "target": "adder", "place": "ventilator" }, "..." ],
  "chain": [ { "id": "S10", "premises": ["C_chair_marks", "C_vent_high"], "concludes": "Roylott stands on the chair to reach the vent" } ],
  "confirm_group_size": 3 }
```
The player builds a theory out of event cards. Cards are checked in groups of `confirm_group_size`, and the game reports only how many are correct.

### `flow`
Scenes, travel between them, the in-game clock, unlock conditions, and the climax (e.g. a stakeout that fires `E_vigil` events while the player waits).

## Validation (fairness checker)

A case is valid only if:
1. Every `chain` premise is a `core` clue or an earlier step, and every clue can be reached through `flow`.
2. Every fact the solution needs that isn't evident in play is backed by a `references` entry the player can find.
3. Every `perceived` claim in a testimony matches an event the witness could perceive (simulated), or is marked as a lie.
4. Every hypothesis has at least one `refuted_by` clue the player can reach.
5. Replaying `events` from the initial state never breaks a lock, seal or connection rule.

## Global registries (outside cases)

- `data/verbs.json`: each verb has its arguments, preconditions, `emits` defaults and effects. **The verb list is the mechanics list.**
- The display maps each verb to one puppet animation in its own files. Case data never names animations.

## Open questions

- Time format: in-world calendar timestamps or relative case time?
- How much perception should the simulator compute, and how much should authors write by hand?
- Should the player get any clues for free during an interview?
- Should a case be one JSON file, or split per section once cases get large?
