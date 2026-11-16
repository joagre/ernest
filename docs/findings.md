# Findings of the reading of three process documents

The reading of 2026-11-16 over `5355d88b`, sorted as [`reviews/full.md`](reviews/full.md)'s *The findings* says. The session read [`reviews/principles.md`](reviews/principles.md), [`clean_room.md`](clean_room.md) and [`memory_checks.md`](memory_checks.md) against `CLAUDE.md` and [`agents.md`](agents.md), with no agent. They are the documents that say how work is done and that the reading of the review documents left unread (the log's *The Review Documents Read Against the Rules*).

The session ran the checks that cost cycles: every function, test and file `memory_checks.md` cites was looked for in the tree, its loads were read against `LOADS` in `test/Makefile`, and the list of sessions was read for C2.

None of the three stands in the template or in a copy, so nothing here goes there.

## The lines

A line is `fix`, made in the round; `decide`, with the user; or `dropped`, with the reason; and `done` with the date once made. A `decide` line carries the session's recommendation.

### `reviews/principles.md`

- P1 — *How it runs* points at `full.md`'s and restates five of its rules beside the pointer. The restatement lacks what `full.md` gained on 2026-11-16: what a reader is handed, and what the session writes into a brief. fix: the pointer, and the review's own differences alone. It waits on P2.
- P2 — the pointer now brings `full.md`'s first step, the release's clone and its `make test-full`, to a review whose readers run nothing. decide: the readers read a clone of the one revision, since the checkout the user edits cannot hold it, and no check runs before them.
- P3 — `fix` means two things. Here it is "fixed in the milestone's edits"; in `full.md`, and in CLAUDE.md's *Tests* for any review, it is made at once. decide: `fix` is `full.md`'s, made at once, and a disagreement between two sections that needs a choice is `report`.

### `clean_room.md`

- C1 — the list of what Ernest's session writes in an application names four files of the template's, and gives the application's log to its own session. Every refresh from a tag has written the copy's log entry that names the tag, and the refresh of 2026-11-16 wrote `release.md` in both copies too. decide: the list gains the log's entry that names the tag, and the lines of `release.md` a change of the template's carries.
- C2 — Ernest's session "writes only while the application's session is not running". The refresh of 2026-11-16 wrote ernest-httpd while its session stood open and idle, as it has for a day. decide: the narrower sentence, that it writes while the application's session is not at work and its tree is clean, and tells it by a message after, which is news.
- C3 — the list of what an application feels against a principle was behind CLAUDE.md's. fix: the repeated form. done 2026-11-16.
- C4 — "A verdict is built the same day." CLAUDE.md's *Defects and gaps* gives a line three ends, a report change, a milestone's item or a line of the log, and the applications' three lines of 2026-11-11 became items. decide: the three ends by a pointer, and one made now is built as *Before code* says, with its regression test.

### `memory_checks.md`

- M1 — every function, test and file it cites stands in the tree: sixteen functions, nine tests, eight files. The table's seven loads are `LOADS`' six and the shell's, which the harness writes, as the document says. Nothing found.
- M2 — *What is kept, and what lets it go*, about 2,200 words, states when each row, unit and process goes. The design notes state it too: two lines of two sampled, the captures' row in `design/runtime.md` and what a detach keeps in `design/shell.md`. CLAUDE.md gives how memory is checked to this file, and how the runtime keeps its books to its design note. decide: the design notes own what a component keeps and when it lets go; this file keeps the loads, the reading, what the host keeps and the tracing, and points at the notes. The verdict rests on two samples, and the move is an item of its own: each line read against its note, and one a note lacks moved there.
