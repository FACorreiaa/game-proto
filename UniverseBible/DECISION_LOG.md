# Decision log

Each entry records the creator's decision as given, its date, and the files it touched. Drafts awaiting a
decision are listed separately.

## Decisions

| ID | Date | Decision | Status | Files touched |
|---|---|---|---|---|
| DEC-001 | 2026-11-16 | Magic and technology are fundamentally different forces; magic is genuinely supernatural rather than misunderstood technology. | LOCKED | CANON, WORLD_OVERVIEW, Systems/*, Factions/* |
| DEC-002 | 2026-11-16 | The true cause of the world's collapse is unknown at the start, and each of the three factions has a convincing but incomplete explanation. The truth may emerge across several games, and no game requires the others. | LOCKED | CANON, WORLD_OVERVIEW, COLLAPSE_MYSTERY, Factions/*, TIMELINE |
| DEC-003 | 2026-11-16 | The Last Light is one shared universe for standalone stories about different characters and events, not one continuous campaign. | LOCKED (direction) | CANON, Games/ContinuityAndEndings |
| DEC-004 | 2026-11-15 | Seraphine keeps her name. | LOCKED | Characters/Seraphine |
| DEC-005 | 2026-11-16 | The bible is a living encyclopedia: plain Markdown in Git, one topic per file, six canon labels, kept separate from game code. | LOCKED (process) | README, CLAUDE |
| DEC-006 | 2026-11-16 | CF-001, option A: the weakening sun is the main visible sign of the decline; its cause stays unknown. Creator: "ok". | LOCKED | CANON, WORLD_OVERVIEW, OPEN_QUESTIONS, Factions/Dawnfaith |
| DEC-007 | 2026-11-16 | CF-002, option A: the AI believes life burns too much light and is replacing living things with machines. That is its belief, not the truth. Creator: "ok". | WORKING | CANON, Systems/Technology, Games/TheLastLight2D |
| DEC-008 | 2026-11-16 | CF-003, option A: Seraphine's buried records show the light failing earlier than official history admits. They say when, not why. Creator: "ok". | WORKING | CANON, Characters/Seraphine, TIMELINE |
| DEC-009 | 2026-11-16 | CF-004: keep both names. The Dimming is the decline as lived; the Dimmed are the places where it has finished. Creator: "both". | LOCKED | CANON, WORLD_OVERVIEW, Locations |
| DEC-010 | 2026-11-16 | CF-005, option A: cast-sheet backstories stay PROPOSED and are decided one character at a time. Creator: "ok". | LOCKED (process) | CANON, Characters/* |
| DEC-011 | 2026-11-16 | CF-006, option B, chosen by Claude on the creator's delegation ("you decide"): the chapter-end line no longer says the Eclipse Engine is "still turning". New line: "The Protocol is silent. It was only a voice. The Eclipse Engine has not stopped." The Engine's physical form stays UNKNOWN. | WORKING (wording is the creator's verdict) | CANON, Bestiary/EclipseEngine, Games/TheLastLight2D, game text |

## Drafts awaiting a decision

| ID | Date | Draft | Files |
|---|---|---|---|
| DRAFT-002 | 2026-11-16 | Faction theories: Cascade Hypothesis, the Severance, the Stolen Light. | COLLAPSE_MYSTERY, Factions/* |
| DRAFT-004 | 2026-11-15 | Cast sheet: backstories, Jax's new name, the Last Oracle title clash. | Characters/* |
| DRAFT-006 | 2026-11-16 | Chapter 2, The Lantern Cities: three levels, enemy behaviour, lead-aware lines and the chapter-end line. Region chosen by the creator ("Lantern Cities … but follow the lore"); every line and claim is a draft. | Games/TheLastLight2D, Bestiary/LanternCities, `chapter2.json` |
| DRAFT-005 | 2026-11-16 | The three openings and the faction pick: Seraphine's Sun Gauges, Nimue's Undercroft, lead-aware lines in the Machine Hall, and a chapter ending per lead and per Orion choice. Direction "own motives" chosen by the creator; every line and the world claims they make are drafts. | Games/TheLastLight2D, game text (`chapter1.json`, faction cards) |

## How to amend

When the creator approves a draft, record their exact wording and the date, update `CANON.md`, update every
affected file, and scan the bible and the shipped game text for contradictions.
