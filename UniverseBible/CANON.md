# Canon register · v0.1

The register lists every claim with a status. Files elsewhere explain and expand it; if they disagree with this
register, the register wins until the conflict is resolved.

## LOCKED: creator-approved

| ID | Fact | Consequence | Decision |
|---|---|---|---|
| LC-001 | **Magic and technology are fundamentally different forces.** Magic is genuinely supernatural, not misunderstood advanced technology. | No lore twist may reduce magic to undiscovered machinery or a scientific energy without a deliberate canon revision. | DEC-001 |
| LC-002 | **The true cause of the world's collapse is unknown.** | No document, narrator or character confirms an objective cause. | DEC-002 |
| LC-003 | **The three factions explain the collapse differently.** | Each faction needs a theory people can believe, with evidence, internal disagreement and blind spots. | DEC-002 |
| LC-004 | **One shared universe, many standalone stories.** Games can follow different characters and events without being direct sequels. | Franchise history never has to endorse every player-selectable ending. | DEC-003 |

## WORKING: current direction

| ID | Element | Working information | Source |
|---|---|---|---|
| WC-001 | Three factions | **The Foundry** (science · control · redemption), **The Dawnfaith** (faith · sacrifice · renewal), **The Lantern Cities** (trade · survival · opportunity). | ART |
| WC-002 | Eight heroes | Caelen, Elyra, Orion (Foundry); Seraphine, Valen, Lira (Dawnfaith); Jax, Nimue (Lantern Cities). Titles, roles, quotes and looks in `Characters/`. | ART |
| WC-003 | Foundry enemies | Scrap Drone, Forged Soldier, Sentry Core, Dogma Frame. | ART |
| WC-004 | Dawnfaith enemies | Zealot, Radiant Acolyte, Solar Guard, Halo Disciple. | ART |
| WC-005 | Lantern Cities enemies | Ratborn, Lantern Gunner, Smuggler Brute, Night Weaver. | ART |
| WC-006 | Bosses | The Protocol (Foundry), The Last Oracle (Dawnfaith), The Cinder King (Lantern Cities). Final encounter concept: The Eclipse Engine. | ART |
| WC-007 | Central conflict | An AI tied to the Foundry pursues a solution to the dying world at terrible cost to life and freedom. **Its diagnosis is not automatically correct.** | ART, specs |
| WC-008 | Visual language | Foundry = cyan, steel, navy. Dawnfaith = ivory, gold, light. Lantern Cities = ember, orange, red. Hostile machines glow red. | ART, specs |
| WC-009 | The Protocol's line | "Efficiency. Without exception." | ART |

## SHIPPED: in a build players have played

These are local canon for the 2D game (see `Games/TheLastLight2D.md`). Changing them means changing the game.

| ID | What players have seen | Where |
|---|---|---|
| SH-001 | Levels of Chapter 1: **Foundry Yard, Awakening, The Machine Hall, The Protocol**. | Game levels |
| SH-002 | Orion finds Caelen awake on a line where "the others … never woke". Orion "stopped obeying", knows the way out, and can't open the last door alone. | `chapter1.json`, scene `awakening.orion` |
| SH-003 | The player chooses whether Orion walks beside Caelen (`orion: trusted`) or ahead of him (`orion: watched`). | same |
| SH-004 | Orion says The Protocol "judged me once". | `chapter1.json`, scene `protocol.wake` |
| SH-005 | Gameplay: Caelen's special is **Command** (marks an enemy for his partner); Orion's is **Adapt** (guards a hit and counters). | Game |

## IN CONFLICT: waiting for a decision

See `CANON_AUDIT.md` for detail and options.

| ID | Conflict |
|---|---|
| CF-001 | The approved game specs say **"The sun is dying"**; the bible's open question 1 still asks what people observe when the world fails. |
| CF-002 | The approved specs say the AI concluded **life burns too much light** and is replacing living things with machines. Is that the AI's working motive, or a proposal? |
| CF-003 | The draft cast sheet has Seraphine knowing **the sun was dying before the AI existed**. That rules out one cause, which comes close to LC-002. |
| CF-004 | The old spec named a region **"the Dimmed"**; the bible proposes **"the Dimming"** for the crisis itself. |
| CF-005 | Draft backstories (Caelen built Orion and wrote the AI's ethics module; Orion was a disposal unit) fill in what the bible lists as UNKNOWN. |
| CF-006 | The 2D game's chapter-end text says the Eclipse Engine "is still turning", which treats it as a machine that already exists. |

## PROPOSED: no canon authority yet

| ID | Proposal | Origin |
|---|---|---|
| P-001 | People informally call the decline **the Dimming**. | Bible v0.1 (see CF-004) |
| P-002 | The Foundry's public model is the **Cascade Hypothesis**. | Bible v0.1 |
| P-003 | The Dawnfaith's prevailing doctrine is **the Severance**. | Bible v0.1 |
| P-004 | The Lantern Cities' popular belief is **the Stolen Light**. | Bible v0.1 |
| P-005 | Physical and supernatural failures sometimes appear together, sometimes apart. | Bible v0.1 |
| P-006 | The magic and technology interaction rules in `Systems/MagicVsTechnology.md`. | Bible v0.1 |
| P-007 | All character backstories, arcs, relationships and endings in `Characters/`. | Bible v0.1, cast sheet 2026-11-15 |
| P-008 | The eras in `TIMELINE.md`. | Bible v0.1 |

## UNKNOWN: deliberately open

- What causes the decline, and whether it has a single cause.
- Whether the decline can be reversed, delayed or only survived.
- The origin of magic and the cost of using it.
- The AI's original mandate and full history.
- Whether a conscious machine can develop or receive supernatural ability.
- Which endings, if any, later become history.
- Who the Last Oracle is relative to Seraphine.

## RETIRED

| What | Why | Where it lived |
|---|---|---|
| The autobattler cast (Maren Holt, Wick, Mother Sabeth, Osric, Ysolde, Fen Marrow, Sorrel, Halvard) | Replaced by the illustrated roster on 2026-11-15; some backstory moved onto the new heroes as proposals | `docs/design/cast-sheet.md` history, 2026-10-22 spec |

## Changing this register

To promote anything to LOCKED, you need explicit creator approval. Then add a dated entry in
`DECISION_LOG.md`, update this register, and update every affected file in the same change.
