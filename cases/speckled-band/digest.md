# The Speckled Band — Digest

Phase 3 of `case-digestion`. Written from `extraction.md` only. Clue IDs (C#), reasoning steps (S#) and red herrings (R#) refer to that file.

**Verdict:** the story is a strong case, but as written it isn't fair. The physical setup (sealed room, dummy rope, ventilator, clamped bed) plays fair. The final leap to a trained snake does not. A game version can be made fair by putting the missing knowledge into the world, so the player can find it. That approach shapes most of the mechanics below.

---

## 1. Fairness audit

| Step | Verdict | Problem | Game fix |
|---|---|---|---|
| S1 sealed room | Fair | — | Each locked door, barred shutter and blocked chimney is something the player can inspect. |
| S2 gipsy theory | Fair (red herring) | — | Keep as a hypothesis the player can form and then disprove (see M11). |
| S3 money motive | Mostly fair | The will is only reported by Holmes (C20) | Make the will a document the player reads at Doctors' Commons. |
| S4 nothing enters by door or window | Fair | — | — |
| S5 opening between the rooms | Fair | — | The cigar smell (C6) points to it, and the ventilator can also be found by inspection. |
| S6 rope is a bridge | **Partly unfair** | The bed clamp (C32) is missing from the room description | Make the clamp visible and inspectable on the bed. |
| S7 it's a snake | **Unfair** | Climbing ropes, venom that tests can't detect, and unseen punctures (C45) are all outside knowledge | See the knowledge sources below |
| S8 milk and whistle training | **Unfair**, and wrong in real life | Real snakes are deaf to airborne sound and don't drink milk | Pick one: (a) state the creature's properties in the world, or (b) change the method (see the note below) |
| S9 recalled before morning | Fair once S8 is fixed | — | — |
| S10 Roylott stands on the chair | **Unfair** | The result of the chair inspection (C29) is never shown | Show boot prints on the chair seat when it's inspected. |
| S11 clang = safe door | Fair only in hindsight | The safe's role comes after the solution | Make it a test: closing the safe makes the same clang that Helen describes (M3). |
| S12 lash = handling tool | Fair | — | — |
| S13 Julia saw the snake | Fair once S7 is fixed | — | — |
| S14 Helen moved into the death room | Fair | — | — |
| S15 trap the culprit | Fair | — | This becomes the climax stakeout (M12). |

**Knowledge sources that make S7–S8 fair** (all must be findable before the solution):
- Roylott's shelf of "technical books": a book on Indian fauna, bookmarked at the swamp adder. It states the snake's speed, its venom, and how small the bite marks are.
- A letter from his Indian correspondent listing the animals sent to him, including one "not to be let loose about the grounds".
- The inquest report, readable in-game: "two small marks on the wrist, taken for insect bites", and no poison found.
- The training method, whatever we pick, must have a physical trace: the saucer (C28), plus something seen or heard that links the whistle to the snake.

**On the snake's real biology:** the game world should have stated rules, not borrowed folklore. Two options:
- **(a) Keep the whistle and milk,** but make the creature fictional ("the swamp adder"), with its properties written in the in-game reference. This is fair, because the player is told the rule.
- **(b) Use real behaviour:** snakes sense vibration, so Roylott taps the ventilator grate. Helen's "metallic clang" then becomes the recall signal. The milk becomes water, or a warm brick to draw the snake back.

Trucy prefers (a): it keeps the iconic whistle, and the in-game reference becomes a reusable mechanic (M8).

**Story slips to fix in our version:** the twins' ages against the timeline, and the income figures (£1000 vs ~£1,100). Pick one consistent set.

**General rules this case suggests:**
1. Every inspection shows its result. No silent "Holmes looked at the chair" moments (C29, the lens at L737–741, the rope at L1047).
2. Outside knowledge the solution depends on must exist in the world as something the player can find.
3. Narrative-only clues (C1, the mud on Helen's sleeve) are flavour. They can stay as deduction warm-ups, but they don't count toward the solution.

---

## 2. Player actions

| Action | Examples in this case |
|---|---|
| Travel | Baker Street → Doctors' Commons → Leatherhead → Stoke Moran; the Crown Inn as a lookout |
| Interview | Helen: her family history, the night of Julia's death, the whistle, the repairs |
| Observe a person | The bruises on Helen's wrist (C18), Roylott's strength and threats (C19) |
| Inspect objects | The shutters, bell-rope, ventilator, bed clamp, chair seat, safe, saucer, lash, chimney staples |
| Test objects | Pull the bell-rope (no bell rings); try to force the shutters; shut the safe (the clang) |
| Read documents | The will, the inquest report, the fauna book, the correspondent's letter |
| Compare | When the rope and ventilator were installed, and when Julia got engaged (C34) |
| Wait / stake out | Watch from the inn until his light goes out; sit in the dark until 3 a.m. |
| Act in real time | Strike a light and lash the rope at the right moment |

---

## 3. Mechanics

The game has no mechanics yet, so everything below is **new**. ★ marks what this case can't work without.

| ID | Mechanic | What this case needs from it |
|---|---|---|
| M1 ★ | Locations and travel | Linked scenes; isometric rooms with doors, windows and adjacency |
| M2 ★ | Inspect | Object → clue, with the result always shown |
| M3 | Interactive tests | Object states and actions: rope (pull), shutter (force), safe (open/close → sound) |
| M4 ★ | Testimony | Interviews by topic; each account is a claimed event script (see §5) |
| M5 ★ | Documents | The will, the inquest report, letters, books |
| M6 ★ | Time and schedules | A clock, day and night, NPC routines (Roylott comes home at dusk, his light goes out at 9 p.m.) |
| M7 ★ | Perception | Events give off sight, sound and smell. Who notices depends on location, walls, openings, light and whether they're awake. This decides what each witness can honestly report |
| M8 | Reference knowledge | In-world facts the player can look up (creatures, poisons, medicine). Makes S7–S8 fair |
| M9 ★ | Deduction board | Link clues to conclusions; build a theory |
| M10 ★ | Enactment replay | Replay any event script as puppets: testimony, the player's theory, and finally the truth |
| M11 | Disprovable hypotheses | Theories like the gipsies (R1) that specific clues rule out |
| M12 | Stakeout / climax | Wait for a scheduled event to fire, then step in at the right moment |
| M13 | Light and darkness | A lit room can be seen through the ventilator; sitting in the dark is a deliberate choice |
| M14 | Locks and seals | Door, shutter and chimney states; "locked from the inside" logic |
| M15 | Non-human actors | The snake, baboon and cheetah are actors in event scripts too |

---

## 4. Deduction input

Combining Moon's enactment idea with the fairness checker:

- **The player answers by building the night's event script,** from action cards (who, verb, target, place, time). Examples: "Roylott → put through → snake → ventilator → ~3 a.m." and "snake → descend → bell-rope".
- **Each card must cite supporting clues.** A card with no citation is a guess, and the game says so.
- **The game replays the theory** as puppets and marks contradictions with known evidence, e.g. "the door was locked from inside, but your script has someone entering".
- **No brute-force guessing:** answers are confirmed in groups (as in Obra Dinn, where fates are confirmed three at a time). Feedback says only how many cards are right, never which ones.
- **Key questions to settle:** who did it, the method (how the snake was delivered and recalled), the motive (the will), and the evidence that proves it (the stakeout).

---

## 5. Enactment notes

Moon's idea: act out events visually, whether the version shown is true or not. The extraction gives enough to script the night of Julia's death. The true timeline (§3 #12) lists only what Helen saw, so Roylott's actions below are reconstructed from the Solution (§7) and Holmes's explanation.

**The truth, as an event script (draft):**

| Time | Actor | Action | Place | Perceived by |
|---|---|---|---|---|
| 23:00 | Julia | leaves Helen's room, locks her own door | corridor → middle room | Helen (hears the key) |
| ~03:00 | Roylott | lights the dark-lantern, stands on the chair | Roylott's room | — (Julia asleep) |
| ~03:00 | Roylott | puts the snake through the ventilator | ventilator | — |
| ~03:00 | snake | climbs down the rope onto the bed, bites Julia | middle room | Julia (wakes) |
| ~03:00 | Julia | strikes a match, sees the snake | middle room | — |
| ~03:00 | Julia | screams | middle room | Helen (hears) |
| ~03:00 | Roylott | whistles | Roylott's room | Helen (hears a low whistle), Julia |
| ~03:00 | snake | climbs back through the ventilator | ventilator | — |
| ~03:00 | Roylott | shuts the snake in the safe | Roylott's room | Helen (hears a metallic clang) |
| ~03:00 | Julia | unlocks the door, staggers out, "the speckled band!", points, collapses | corridor | Helen (sees) |
| ~03:05 | Roylott | comes out in a dressing-gown, sends for a doctor | corridor | Helen (sees) |

**Helen's testimony** is the "Perceived by: Helen" rows, plus her guesses (the gipsies, death by fright). When it's replayed, the player sees *only* what she perceived: sounds play over a dark corridor. This is a fair way to show her uncertainty (R5).

**What the extraction lacked for this:** perception per event, and witness accounts as separate timelines. I derived both here. The skill's extraction prompt now asks for these directly (section 8).

**Architecture (Moon's decision #100):** case data, the event simulator, perception and the fairness checker form a pure data/logic layer with no display code. The puppet display only reads that state and plays events, so it can be swapped out. Phase 4 should design the format with this split.
