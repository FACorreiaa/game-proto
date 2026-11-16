# The Last Light: the 2D action-platformer

The first game. Stage-based 2D action-platformer for iPhone, iPad and Mac. The code lives in this repository
(`LastLight/`, `LastLightCore/`); the design is in
`docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md`.

## What it uses from the bible

| Element | Status in the bible | In the game |
|---|---|---|
| The Foundry, its colours, its enemies, The Protocol | WORKING (ART) | Chapter 1 region and boss |
| Caelen, Orion | WORKING (ART); backstory PROPOSED | Lead and companion |
| Seraphine, Nimue as other leads | WORKING (ART); arcs PROPOSED | Chosen at New Game by faction. Each has her own opening (DRAFT-005). Kits are gameplay, not canon: Seraphine's **Light Listens** heals, Nimue's **Lantern Trick** leaves a decoy |
| The AI's goal | WORKING (WC-010) | Implied: a line where the others never woke |
| The Eclipse Engine | WORKING (ART); details UNKNOWN | Hook at the end of Chapter 1 (DEC-011) |

## Local canon this game has shipped

SH-001 to SH-005 in `CANON.md`. Any new dialogue or text that states a world fact goes through `CANON.md`
before it ships.

## What this game must not decide

- The cause of the collapse.
- The origin or cost of magic. The first chapter has none, which suits the Foundry.
- Who the Last Oracle is.
- Which of its endings is history.

## Draft: the three openings (DRAFT-005, PROPOSED)

Direction chosen by the creator on 2026-11-16: each lead comes into the Foundry for her own reason and meets Orion
in her own way. The lines below are drafts for the creator's verdict. Nothing here is canon.

**Route (next build).** New Game asks for a faction. Each lead plays her opening, then the shared levels:
Foundry Yard, The Machine Hall, The Protocol. This changes the shipped order in SH-001 (Foundry Yard used to come
before Awakening, which put Orion beside Caelen before they had met). SH-001 should be updated once this ships.

| Lead | Opening | Motive | How she meets Orion |
|---|---|---|---|
| Caelen | Awakening (unchanged) | Wakes on the line | Orion finds him awake (SH-002) |
| Seraphine | The Sun Gauges: up the Foundry's outer works to the floor where it measures the light | To see whether the Foundry's numbers match her buried records (WC-011) | Orion asks why anyone would walk into the Foundry |
| Nimue | The Undercroft: her smuggling route under the Foundry | Three of her runners went onto the line; she is taking them back | Orion tells her he is not one of the machines that took them |

All three end on the same choice as Caelen's (`orion: trusted` or `watched`), so The Protocol's lines work for every
lead. The Machine Hall opens with one line per lead, read from a `lead` story flag.

**New world claims in these drafts, each needing a verdict:**

1. The Foundry measures the light's loss ("every hour, every degree") at the Sun Gauges.
2. The Foundry's numbers match Seraphine's buried records, and "someone has known for a long time" (fits WC-011:
   when, not why).
3. What the Foundry knows about the light is kept "behind the Protocol" (Orion to Seraphine).
4. The line Nimue's runners were taken to "runs past the Protocol" (Orion to Nimue).
5. Orion "cannot lie, not even to be kind". This is a trait, and it constrains every later Orion line.
6. Caelen knows the Machine Hall floor "and doesn't know why". This hints at lost memory and leans on his PROPOSED
   backstory (he built Orion).
7. Faction card for Caelen: "Find out what you built". This also leans on that backstory.
8. Nimue's people are called "runners".

Card names, titles, themes and quotes come from the concept art. The one-line motives on the cards are drafts.
