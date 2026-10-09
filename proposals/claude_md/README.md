# CLAUDE.md consolidated

Status: a proposal, written on 2026-10-09, for a consolidated `CLAUDE.md`, every rule kept. [`CLAUDE.md`](CLAUDE.md) here is the draft as it would stand at the repository's root; this note says what moved where. Nothing of it is in force until the user copies it over the root's file.

## What changed in form, and nothing in substance

- **Plain imperatives.** Every rule is restated as an instruction in the fewest plain words, its substance unchanged: "Decide the owner before you write" for "A sentence goes to its owner before it is written". The report's register stays the report's.
- **One closing list.** *Done means four things*, *Closing an item* and *Stop after each plan item* were three lists of one thing. The nine-line checklist remains, its line 8 holding the four things, and the other two go; *Stop after each plan item* is one bullet of *Done*.
- **The proposals table goes.** It restated each directory's `README.md` and had gone stale the same day it was written: it named `mvp3.1.md` and `mvp3.2.md` as under discussion after they were read through. One paragraph says what `proposals/` is and points at each directory's README; the three design notes are rows of the ownership table, where they already were.
- **The two list-holding documents join the ownership table**, `docs/language_feedback.md` and `docs/findings.md`, each as a row, since that is what the table is for.
- **The five rules on stopping are two bullets of *Before code*.** "A change is stated and made", "that rare case is a design question", "no decision is left pending" and "stop after each plan item" overlapped; the first two are one bullet, the third stays, the fourth is *Done*'s.
- **Sub-bullets became sentences** where a sub-bullet was a clause of its parent: *Features are judged on the principles*, *What Ernest adds costs a fraction*, *Ernest is beautiful*, *No fixed sleep*, the five of *Shims*, *Nothing routes around a defect*, *The report's section numbers never change*.
- **"List the sections a module implements" and "quote the exact section" join *The report changes first***, being its two practices.
- **"A refusal names its MVP" joins *Fix a known defect when found***, being the gap rule's other half.
- **"Every surprise is decided" joins *Read the result back***, which it qualifies.
- **"Clear before short" joins the register rule**, which it qualifies.

## What stayed as it was

The authority section, the ownership table's rows, the repository section, the design rules, the shim rules, the defect rules, the test rules, the writing rules, the conformance section, the glossary rule and the `@docs/style.md` import.

## Size

| File | Words |
|---|---|
| `CLAUDE.md` at the root today | 3,761 |
| this draft | 3,343 |
| `docs/style.md`, imported by both | 2,850 |

The glossary is left where it is. Moving it out of the import, to a file read before naming anything in an area, would cut what loads each session by about a quarter more, and is the user's call.
