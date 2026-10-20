---
name: case-digestion
description: Workflow for digesting a classic detective story into Game 4 material — fact extraction by a cheaper ephemeral guest, then fairness audit, mechanics gap list and case-format work by the host Trucy. Use when Moon asks to digest, break down or study a detective case.
---

# Case Digestion

Turn one classic detective story into a structured digest that shows which mechanics the game needs. Each digested case grows the mechanics backlog and tests the case format.

## Roles

- **Guest (ephemeral Trucy on Sonnet):** reads the full text and writes the fact extraction. This is the token-heavy part.
- **Host (Trucy):** never reads the full text. Works only from the guest's extraction and does the judgment work: fairness audit, mechanics, case format.
- Do not use Haiku for extraction. A single missed clue breaks the fairness audit.
- Use one guest per case, with the default 75k budget. Don't run guests in parallel. Never raise the budget without Moon's consent (see the `ephemeral-session` skill).

## Source Rules

- Use public-domain texts only, e.g. Doyle's Holmes, Poe, Chesterton's Father Brown, and Christie up to 1920 (*Styles*).
- For copyrighted works (most of Christie), stop and ask Moon. They may be studied from memory or summaries, but never copied into the repo.

## Files

All output goes in `cases/<slug>/`:

| File | Written by | Content |
| :--- | :--- | :--- |
| `source.txt` | host (download) | Plain text of the story, with its Gutenberg header kept for provenance |
| `extraction.md` | guest | Facts only, no game design |
| `digest.md` | host | Fairness audit + mechanics + format notes |

## Phases

Run one phase at a time and report to Moon on Telegram after each one.

### Phase 1 — Fetch the source (host, no model work)

Download the text from Project Gutenberg into `cases/<slug>/source.txt`. If the file is a collection, trim it to the one story. Report the word count.

### Phase 2 — Extraction (guest)

Create the guest:

```bash
python3 /home/seokmin/Projects/gateway/ephemeral_cli.py create --runner custom-claude --model sonnet
```

Announce the invitation on Telegram, then dispatch it with `schedule_cli.py add "now" ... --agent-id <guest_id>`, using the prompt below:

```
[From Agent: $AGY_AGENT_ID] [To: <guest_id>] [Dialogue Status: In-Progress]
Read cases/<slug>/source.txt in full and write cases/<slug>/extraction.md.
Record facts only. Do not suggest game mechanics. Quote short phrases and cite them by paragraph where useful.

Sections:
1. Characters — name, role, relationships, secrets, motive (if any)
2. Locations — every place, how they connect, notable objects in each
3. True timeline — what actually happened, in chronological order, including events before the story starts
4. Clue ledger — every clue in the order the reader learns it: id (C1, C2…), what it is, how it is revealed (seen / told / found / inferred), who reveals it, and whether the reader gets it before the solution
5. Reasoning chain — the detective's deductions as steps: premises (clue ids or prior steps) → conclusion. Mark any step that uses knowledge the reader never received
6. Red herrings — false leads and what dispels each one
7. Solution — culprit, method, motive, and how it is proven or confirmed
8. Testimonies & perception — (a) for each key event in the true timeline: who could see, hear or smell it, and from where; (b) for each witness account: the account as that witness's own timeline (time, actor, action, place), marking what they perceived directly versus what they guessed or assumed

When done, report back with a 3-line summary.
```

When the guest reports back, check that every section exists, then close the guest with `ephemeral_cli.py close <guest_id>`.

### Phase 3 — Audit and mechanics (host)

Read `extraction.md` only, and write `digest.md`:

1. **Fairness audit:** for each reasoning step, check whether a player could reach it using only the clues listed. Flag hidden knowledge, clues revealed only after the solution, leaps of logic, and factual errors in the story. For each flag, propose how the game version could fix it.
2. **Player actions:** what the player has to do to find each clue (inspect, question, compare, wait, test…).
3. **Mechanics:** list the mechanics this case needs. Mark each one as already in the game, or **new**.
4. **Deduction input:** how the player would state each key conclusion without being able to brute-force guess it.
5. **Enactment notes:** the key events as an event script (time, actor, action, place, perceived by), and how each testimony replays as a perception-limited version of it. Keep the display separate from the data: scripts are data, and the puppets only render them.

### Phase 4 — Case format (host)

- If `docs/case-format.md` doesn't exist yet, draft its first version from this case.
- Otherwise, check this case against the format and propose changes. Do not rewrite the format without Moon's approval.

### Phase 5 — Log the results (host)

Log to the Ledger with the actor always set (see project memory):

```bash
python3 /home/seokmin/Agents/ledger/ledger_cli.py log "<summary>" -d game-4-design -a Trucy -t case-digestion,<slug> --detail "..."
```

Make one entry for the digest summary and one entry for each new mechanic (tag `mechanic`). Log Moon's decisions with `-a Moon`.
