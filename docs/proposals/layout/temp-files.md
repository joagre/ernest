# Individual files, discussed

Files read one at a time for whether each says what it should, and only that. Begun 2026-11-04.

## README.md

**Now.** 1,715 words, about a third of `guide/why.md`'s 4,953, and most of that third is `why.md`'s own:
- the counter with its shell session;
- the Gleam comparison with its refused program;
- the four `ern config` commands and the session that run the counter on a second node;
- the six claims, each a sentence of argument;
- the three ways in, each a paragraph.

It argues where it should point.

**The reader.** A programmer who knows Erlang and Gleam, who has read the case for processes and for types. They need what is different, a taste of it, and where to go next.

**The shape proposed, about 400 to 500 words:**
1. One paragraph placing Ernest for that reader: Gleam's types on Erlang's processes, and three things neither has:
   - a process's mailbox type in its function's type, so every send is checked;
   - code that crosses to another node by its definition's hash, nothing installed there first;
   - two nodes as two configuration files over one TLS connection, no cluster to join.
2. One example, the one that stops a Gleam programmer: the counter, about 12 lines, then the program the compiler refuses, `count` called where the mailbox is another type, with its error. `process.receive(subject)` lets that through. The shell sessions and the two-node walk-through go: `why.md` and the tour have them.
3. The six claims as a bare list of links, title only, each to its section of `why.md`.
4. The three ways in, a line each: the tour for an evening, the guide for the language, the report for the rules.
5. *Where it stands*, *Installing* and *License*, kept as they are. *Installing* is the site's Install page, so it stays whole.

**Before trimming.**
- `ern_tour_tests` runs the README's shell sessions, and the documents test holds its start lines. Cutting the sessions cuts those cases, on purpose.
- The generator takes only *Installing* from the README for the Install page; confirm the trim leaves the site unchanged.

**Its links.** 21 places today. Only the central ones stay, each a destination or an index that carries the rest:
- Kept: `guide/why.md` (through the claims' links, not eleven separate ones); `guide/faq.md`, the Gleam and Erlang reader's questions; the tour, the guide (`guide/language.md`) and the report, the three ways in; `examples/`, one link, its README listing the programs; `ernest-template`, the next step once convinced; `site/projects.md`, what is written in Ernest; the releases page; `LICENSE`.
- One link to `guide/README.md` replaces `guide/style.md` and `guide/deployment.md`, which it lists.
- Dropped: `docs/man/` (Installing's `man Ernest.List` shows the manual); `docs/development.md` and `docs/plan.md` (for work on Ernest, which takes no contribution before 1.0); `editors/emacs/README.md` (named in Installing's last sentence, or carried by `guide/README.md`); `examples/snake.ern` and `web_server.ern` (the examples' README lists them).
- `THIRD_PARTY_LICENSES` stays in the License section's one sentence only, where it belongs, and is no reading link.

**The draft.** Written 2026-11-04 and landed as `README.md` 2026-11-06: the opening for an Erlang and Gleam reader, crediting Unison, Gleam and Erlang in that order and leading with code that travels; the counter; its code started on a second node by `Peer.spawn`; the refusal of the wrong mailbox; the six claims as links; five ways in; *Where it stands* naming no version; *Installing* and *License* as they are. Read and judged good, with two fixes made in it.

**Gleam, to fix and to check before the launch.**
- The README writes `process.receive(subject)`, and `guide/why.md` twice. Gleam's `process.receive` takes a timeout, `process.receive(subject, within)`, with `receive_forever(subject)` the form without one, as far as known here; a Gleam reader meets a wrong call in the one line meant for them. Fixed in all three places.
- The claim itself, that a `Subject` lets a receive compile in a process that does not own it and leaves the mistake to the run, stands in the README, `why.md` and `guide/faq.md`. Checked against `gleam_erlang`'s current documentation before the site goes live, since knowledge here of its latest version may be out of date.

## The first claim's name

Decided with the user, 2026-11-04: the claim now titled "Code goes where it runs" becomes **"Code travels"**, the picture a newcomer keeps, so that the README's opening, "built around code that travels", echoes the claim instead of standing beside a second phrasing of it.
- Reaches: `guide/why.md`'s heading and its line in the opening list, the anchor becoming `#code-travels`; the homepage, which shows the claim by name from `why.md`, so it follows; the README's claim link (made in the draft); every page linking `#code-goes-where-it-runs`, which the documents test lists.
- Not the report nor the guide's teaching: they keep their precise terms, code that *crosses* with a spawn (§8.7) and a definition's *reach*, so that one concept has one name where rules are stated.

## guide/why.md

**Now.** 4,953 words: an opening of 798, then the six claims argued one by one with programs, 30 to 1,108 words each. The sections are the argument and earn their length. The opening is where it trims.

1. The opening paragraph, "Ernest is a small functional language for concurrent programs, on the Erlang runtime. A process started on another node brings its code along…", says what Ernest is, which is the README's, in the words the README drops as too obvious. Cut it: the document opens with "The argument for the design, in six claims…" and goes to the claims.
2. The opening's list argues each claim twice: each item is a paragraph of about 110 words, then its section argues the same with its program. Each item's first sentence stays, since the homepage shows the first four claims each by its name and that sentence; the "So…" that follows goes, the sections carrying it.
3. The first claim becomes "Code travels", in the list and as its section's heading, its anchor `#code-travels` (see *The first claim's name* above).
4. `process.receive(subject)`, twice here, becomes Gleam's real call, and its claim is checked against `gleam_erlang`'s current documentation (see *Gleam* above).

About 700 words go, to some 4,250; no argument and no program is touched, and the homepage shows the same text.
5. "Its parts come from elsewhere" stays, as part of the argument, in the README's order: Unison, Gleam, Erlang. "Ernest is for programs written in it from the start", what Ernest is not for, stays as it is: the honest answer to an Erlang reader's "can I use it in my OTP system?", which nothing else gives.

**The draft.** Written 2026-11-04 and landed as `guide/why.md` 2026-11-06, built from `why.md` with 1 to 5 applied: 4,509 words from 4,953. Judged good with the user.

## tools/release/README.md (release/README.md after the layout's change 3)

**Now.** 535 words: what a reader of the archive or an installation needs first, which CLAUDE.md's owner table gives it. Mostly a map of where each document stands once installed, under the prefix. It repeats none of the main README's argument.

1. Its opening is the old sentence, "a small functional language for concurrent programs, on the Erlang runtime". It becomes the new README's first sentence, "a small BEAM language built around code that travels", so the two begin alike and part after it.
2. The list of installed paths stays whole. Its reader has no repository to browse, only files under a prefix, so a document not named by its path is not found; the list is the README's purpose. (The main README's links were cut for the other reason: a GitHub reader follows indexes.)

No draft: the change is one sentence.

## CLAUDE.md

**Now.** 5,368 words on 2026-11-04 and 5,771 on 2026-11-06, some 7,000 tokens, which every session pays before it works. Little history in it (two anecdotes and a log citation in a rule), and its one deliberate repetition, *Closing an item*, pays for itself as the checklist a session runs. It is long because it is thorough.

1. The owner table, 676 words, names 18 documents under `docs/` that `docs/README.md` lists and describes, and the table itself makes `docs/README.md` the owner of what each document under `docs/` is: CLAUDE.md breaks its own one-owner rule there. Keep its rows for owners outside `docs/`, and replace the 18 with one, `docs/README.md`, each document under `docs/` the owner of its subject. About 350 words; the cost is a file read in a session that needs a `docs/` owner it does not know.
2. The rest is sentences: much of it is written in the report's dense register, long chains of clauses, where *Writing* asks the plan and the log for "plain and short, one point to a sentence", which a document every session reads whole needs as much. Estimated 5,400 words to about 3,500, some 2,500 tokens a session, no rule dropped.

**How.** It is the user's rule book, and each cut is agreed line by line. A draft rule for rule, as with the READMEs, in a session with tokens to spare; then a reading that maps every rule of the old file to a sentence of the new, so that none is lost.

**The harvest.** Read 2026-11-06, Ernest's file against the template's. The template holds no rule that Ernest lacks and that applies here: its one candidate, `make test` from a fresh clone before an item that touched the build closes, is step 1 of Ernest's release review. It words five shared rules more plainly, and the draft takes those: a measurement's end, the paragraph, the design question, the surprise decided, and the sweep standing under *Done*, where the order of work has it.

**The draft.** Written 2026-11-06 as `temp-CLAUDE.md`: 5,441 words from 5,771. The owner table is 318 words from 686, its `docs/` rows now the log, the plan, `docs/README.md` and `findings.md`, and the five READMEs that `docs/README.md` lists gone with them. The sentences made plain are not fewer words: a chain split at its clauses repeats its subject, so *The repository*, *Tests* and *Done* each grew a little. So the estimate above, about 3,500 words with no rule dropped, does not hold. Under the table, a shorter file drops content, a reason, an example or a rule moved to an owner read when it applies, and each such cut is the user's.

A word diff of the draft against the file, with the links' prefix taken off, is the map: it lists every phrase that went and every one that came.
