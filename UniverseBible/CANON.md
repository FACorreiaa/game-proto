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
| LC-005 | **The sun is weakening; that is the main visible sign of the decline.** *Why* it weakens stays unknown (LC-002). | Every region shows it; each faction reads it differently. | DEC-006 |
| LC-006 | **"The Dimming"** is the name for the decline as people live it; **"the Dimmed"** are the places where it has finished and no light holds. | Use both; never use either as a name for the cause. | DEC-009 |

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
| WC-010 | The AI's motive | The AI believes organic life burns too much of the remaining light, so it is replacing living things with machines that need none. **This is its belief, not the truth** (WC-007). | Specs, DEC-007 |
| WC-011 | Seraphine's secret | Records buried by the old oracles show the light failing **earlier than official history admits**. That is evidence about *when*, not *why*. | DEC-008 |
| WC-009 | The Protocol's line | "Efficiency. Without exception." | ART |

## SHIPPED: in a build players have played

These are local canon for the 2D game (see `Games/TheLastLight2D.md`). Changing them means changing the game.

| ID | What players have seen | Where |
|---|---|---|
| SH-001 | Levels of Chapter 1: **Foundry Yard, Awakening, The Machine Hall, The Protocol**. | Game levels |
| SH-002 | Orion finds Caelen awake on a line where "the others … never woke". Orion "stopped obeying", knows the way out, and can't open the last door alone. | `chapter1.json`, scene `awakening.orion` |
| SH-003 | The player chooses whether Orion walks beside Caelen (`orion: trusted`) or ahead of him (`orion: watched`). | same |
| SH-004 | Orion says The Protocol "judged me once". | `chapter1.json`, scene `protocol.wake` |
| SH-006 | Chapter-end text: "The Protocol is silent. It was only a voice. The Eclipse Engine has not stopped." | Results screen (from the next build) |
| SH-005 | Gameplay: Caelen's special is **Command** (marks an enemy for his partner); Orion's is **Adapt** (guards a hit and counters). | Game |

## Resolved conflicts

All six conflicts from the v0.1 audit were decided on 2026-11-16 (DEC-006 to DEC-011). See `CANON_AUDIT.md`.

## PROPOSED: no canon authority yet

| ID | Proposal | Origin |
|---|---|---|
| P-002 | The Foundry's public model is the **Cascade Hypothesis**. | Bible v0.1 |
| P-003 | The Dawnfaith's prevailing doctrine is **the Severance**. | Bible v0.1 |
| P-004 | The Lantern Cities' popular belief is **the Stolen Light**. | Bible v0.1 |
| P-005 | Physical and supernatural failures sometimes appear together, sometimes apart. | Bible v0.1 |
| P-006 | The magic and technology interaction rules in `Systems/MagicVsTechnology.md`. | Bible v0.1 |
| P-007 | All character backstories, arcs, relationships and endings in `Characters/`, unless marked otherwise. Each is decided per character (DEC-010). | Bible v0.1, cast sheet 2026-11-15 |
| P-008 | The eras in `TIMELINE.md`. | Bible v0.1 |

## UNKNOWN: deliberately open

- What causes the decline, and whether it has a single cause.
- Whether the decline can be reversed, delayed or only survived.
- The origin of magic and the cost of using it.
- The AI's original mandate and full history.
- Whether a conscious machine can develop or receive supernatural ability.
- Which endings, if any, later become history.
- Who the Last Oracle is relative to Seraphine.
- What the Eclipse Engine physically is, where it is, and how far along it is.

## RETIRED

| What | Why | Where it lived |
|---|---|---|
| The autobattler cast (Maren Holt, Wick, Mother Sabeth, Osric, Ysolde, Fen Marrow, Sorrel, Halvard) | Replaced by the illustrated roster on 2026-11-15; some backstory moved onto the new heroes as proposals | `docs/design/cast-sheet.md` history, 2026-10-22 spec |

## Changing this register

To promote anything to LOCKED, you need explicit creator approval. Then add a dated entry in
`DECISION_LOG.md`, update this register, and update every affected file in the same change.
