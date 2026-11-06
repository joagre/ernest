# The other repositories

What of the `temp*.md` suggestions reaches `ernest-template`, and from it `ernest-epx` and `ernest-httpd`, for one layout and one way of working across the four. A change goes to the template first, then into each application by hand, as the template's copies are kept. Ernest's session makes these changes in the template and in each application, since they are the repository's shape and not what the program says (`docs/clean_room.md`). One stays with an application's own session: what it adds to its full review (item 9). Read 2026-11-04.

**When.** Items 3, 4, 6 and 8 were made at one stop, on 2026-11-06, with Ernest's restructuring, after MVP 4.2 closes and before MVP 4.15's item 2, the owner row item 4 needs among them. Items 5, 7 and 9 follow Ernest's CLAUDE.md redraft, before MVP 4.15's item 2 and before the three applications' sessions start (the log's *The Layout's Rest First*).

## Found first: the rule for src/ and tools/

All three keep an Ernest tool in `tools/`, `ernest-template/tools/docs.ern`, built into `tools/build/`. In an application `src/` is the program's own source root (`ernest-epx/src/epx.ern` is `Epx`), so a tool moved there would become a module of the library, which it is not.

So the rule across the four, recommended in place of the layout's change 1:
- **`src/` holds what a release ships.** Ernest's toolchain, runtime, stdlib, libraries and shell; an application's program or library.
- **`tools/` holds what works on the repository and is not shipped, in any language.** Ernest's scripts and its Ernest tools, `site.ern`, `site/` with its shim beside it, and `manual.ern`; an application's `docs.ern`.

Ernest's change 1 then keeps its Ernest tools in `tools/`, a source root as an application's is, and only the site's shim moves, into `tools/site/`. The old README said it already: `src/` holds the Ernest a release ships.

## To the template, then to each application

1. **Each source root keeps a `build/` of its own, unchanged.** `src/` builds into `build/`, which mirrors it (report §11.1) and is what `make install` and `make release` take. `tools/`, `test/` and `examples/` each build beside themselves, as `TEMPLATE.md` says. Ernest divides its one `build/` by role, since it ships several roots.
2. **`erl/` stays where an application has one.** In `ernest-epx` it holds host applications put on `--libs-dir`, its submodules, so the name is its role. No change.
3. **`SECURITY.md`.** The template gains one, saying where to report a security hole privately. `ernest-httpd`, which serves the site and its live shell, needs it most; `ernest-epx` takes the template's for consistency.
4. **The README's shape.** What the program is and where to begin, central links only, no argument the program's own documents make. The template's README and the guidance in `TEMPLATE.md` say so; each application's README is read against it. Read 2026-11-04: the three READMEs are 703 to 808 words, open by saying what the program is, and argue no design, so they need less than Ernest's did. One change for all three:
   - Their *The documents* lists every working document, design, plan, log, release, proposals, language feedback, CLAUDE.md, and in `ernest-epx` its bugs file, its third-party licenses and its acknowledgments, most of them for work on the repository and not for its user. The full list moves to a `docs/README.md` in each, which then owns what each document is, as Ernest's does.
   - The README keeps what its reader needs: the template, the program's entry points and a link to `docs/README.md`; `ernest-epx`, a library, *Using it*, the manual pages, `examples/` with its pictures, and `docs/README.md`; `ernest-httpd`, a server, `deploy/README.md` for the operator, `examples/` for the example site, and `docs/README.md`.

   And per repository:
   - The template's placeholder opening, "What the program does, in a paragraph", carries the guidance in `TEMPLATE.md`: what the program is for its reader, then where to begin, no argument its documents make.
   - `ernest-epx`'s opening sentence carries the library, epx, the repository's own URL, the pixmaps, the window and what it takes nothing back from. The URL links the repository to itself and goes, and the sentence splits in two.
   - `ernest-httpd`'s opening stays: one sentence of what it serves, one of what it implements.

   *Building*, *Running* or *Using it*, and *License* stay in all three.
5. **CLAUDE.md.**
   - The kept-proposals rule: a proposal refused or not taken up stays, its README's status line saying which; only a built one goes.
   - The owner table names `docs/README.md`, or the docs, once, not each document twice.
   - The plain register, as Ernest's CLAUDE.md is redrafted.

   The template first, then each copy, as a rule's change always goes.

   Read 2026-11-04. The copies keep close to the template: each differs only in its first two lines, its name and its one-line description, and `ernest-epx` lacks the `deploy/` row, having no `deploy/`. One read covers the three, and one fix carries to them. Each is about 3,300 words.
   - The owner table makes `README.md` the owner of "what the program is, how it is built, tested and run, and what each document is". With item 4, the README keeps the first three and a new row makes `docs/README.md` the owner of what each document is, Ernest's arrangement in all four.
   - *Proposals* says when a built proposal goes, as Ernest's does, and gains the same sentence on one refused or not taken up.
   - The redraft goes in order: Ernest's CLAUDE.md first; then the template's, cut again from it, as its first line says it is "cut from Ernest's own"; then each copy takes the template's whole and keeps its own first two lines. The plain wording is written once, not four times. About 3,300 words to some 2,200, about 1,400 tokens a session in each, an estimate Ernest's redraft did not bear out: the plain register cut no words there, only the owner table did (the log's *CLAUDE.md Redrafted*).
   - **Good rules travel every way, decided with the user 2026-11-04.** By their headings, the applications' files hold no rule Ernest's lacks: their thirteen differing headings are Ernest's rules fitted to an application ("The design changes first", "The program is beautiful", "A test lives in the module it tests"), the three alike. But a sibling's wording of a shared rule may have grown clearer, which only a reading line by line shows. So:
     - A harvest before the redraft: the four files read side by side, rule by rule, and a sibling's clearer wording of a shared rule, or a rule of its that applies, taken into Ernest's draft first; then the template is cut from it, and the copies take the template's. The best phrasing wins wherever it was written.
     - A standing rule, in Ernest's CLAUDE.md and the template's: a good rule found in an application goes to the template, and to Ernest's where it applies, and from the template to the other copies. Today the template's first line says a rule changes in the template first and then each copy, one way alone.
6. **`.gitignore`.** Read for drift as Ernest's was. `build/` matches at any depth, so the template's and each copy's `test/build/`, `tools/build/` and `examples/build/` go.
7. **A log grown past GitHub's rendering**, split by day as Ernest's is, past about 300 KB: a rule in the template for when an application's log grows, not a change now, since the applications' logs are small.

8. **The clean room by messages** (Ernest's `docs/clean_room.md`, 2026-11-04). The template's CLAUDE.md and README say a line is "carried to Ernest" without how, rightly, since the template serves a stranger too, whose channel is Ernest's tracker. One clause makes it exact for both: carried to Ernest by its issue tracker, or, for an application built in Ernest's clean room, by a message to Ernest's session. `ernest-epx` names neither. `ernest-httpd`'s reply file went from its feedback file's header in its own commit, and no repository names it now.

9. **A full review** (the log's *The Applications' Full Review*, 2026-11-05). The template gains `docs/full_review.md` beside `docs/release.md`, cut from Ernest's as its CLAUDE.md is, with its row in the owner table:
   - It runs only when the user says so, and not while its last findings are open.
   - Its readers read the whole repository: a cold reader who uses the program, a code reader, a documents reader, and a security reader where the program takes input from outside.
   - What a reader finds of Ernest's goes to `docs/language_feedback.md`, and the rest is sorted as `docs/release.md`'s findings are.

   Each copy takes it, and its own session adds what it alone has: `ernest-epx`, its window tried on a screen; `ernest-httpd`, the security reader over its live shell.

## Items 5, 7 and 9 as made

Drafted and landed 2026-11-06, each cut agreed with the user: `ernest-template`'s `CLAUDE.md`, its new `docs/full_review.md`, and the lines of `docs/README.md`, `README.md`, `TEMPLATE.md` and the starter log that follow them, then `ernest-epx` and `ernest-httpd`, a commit in each (the log's *The Template Cut Again*).

**The count.** `CLAUDE.md` is 3,863 words from 3,623. As in Ernest's, a chain split at its clauses is not fewer words, and the new rules add about 200.

**What the first cut left out stays out.** Most sentences Ernest's file has and the template's lacks are older than the template, so the first cut dropped them on purpose: the reasons inside a rule, and the longer forms of *No fixed sleep* and *The program is beautiful*. The draft takes Ernest's wording only where it splits a chain. It takes Ernest's rules of 2026-11-06: a new file is added before its check runs, this file is among the plain documents, a flake is tested under what it was seen under, and the standing rule on where a good rule goes.

**What the reading found wrong in the file.**
- *Style* said the style guide is read "from the installation beside `ern` or a checkout's `guide/`", against *Authority*, where the installation is the only Ernest a session sees. The draft says the installation.
- The road a feedback line takes stood twice and differed. The owner table's row had item 8's two roads, and *Defects and gaps* still said the user carries the line "as an issue of Ernest's repository or by hand". The draft states the road once, in *Defects and gaps*, and the row keeps what the file is: the user carries a line by the tracker, and in the clean room the session carries it by a message, as `docs/clean_room.md` has it.
- The row said a line is "in the shape of Ernest's file of that name", which no installation holds. *Defects and gaps* states a line's shape, so the phrase goes.
- *The repository* restated the rule that a gap goes to Ernest and is not worked around. Its sentence that a gap goes to Ernest first and is fixed there moves to the rule in *Defects and gaps*, with its two examples, a refusal and a line the tool should say.

**The copies take the file whole.** `ernest-epx`'s file differed in two rows: it lacked `deploy/README.md`'s, which says "where `deploy/` exists" and so is true there, and its `CHANGES.md` row said "from the release after 0.1.0 on", which its `CHANGES.md` says itself. The template's row no longer says where the notes begin. What a copy keeps is now the title and the sentence under it, on what the program is, and the sentence on the template stands in a paragraph of its own.

**The owner table.** `docs/release.md`'s row goes and `docs/full_review.md` gets none, against item 9's word: `docs/README.md` lists both, as Ernest's table leaves its reviews to its `docs/README.md`. The rows for `deploy/README.md`, `examples/README.md`, `language_feedback.md` and `findings.md` stay, since each names a file before it exists. A finished milestone's row moves from the plan's row to *Where a sentence goes*.

**Item 7's number.** The draft splits a log that nears 250 KB, not 300, since Ernest's log stopped rendering between 301 and 309 KB and its test's ceiling is 256. The template's tool and its `CLAUDE.md` name `docs/log.md` by its path, so the rule has the session tell the user, and the split waits for the template's change.

**The full review.** Four readers, K, C, D and S, lettered as Ernest's are, each brief cut from Ernest's reader of that letter. `TEMPLATE.md` said a copy is never updated from the template, though each copy's `CLAUDE.md` has been taken from it again and again, and now says which three files a copy takes again.

**The reader.** One reader who had not heard the reasoning read the old file against the draft, and the new review cold. It found one rule loosened, the road's wording having lost who carries a line, and four smaller losses, all restored but the two phrases named above. It found the template's README saying `make test` lists a paragraph past a hundred words, where the tool refuses one past 150, and `ernest-epx`'s README says the same. Two things it found the old file already had. A fresh clone was asked for before the commit it would clone, and is now run after the closing commit and before the report. A function the library lacks "is written in Ernest or waits" beside "nothing here goes around it", which was decided with the user: such a function is written in the program where Ernest can express it, its line naming it, and every other gap waits.

## Not carried

- Ernest's own: the role-named `src/` directories (toolchain, shared, runtime, nodes), the shims beside their libraries, `release/`, the examples' and tests' renames, `docs/reviews/`, `code_style.md` and `memory_checks.md`, the "Code travels" claim and the Gleam line. An application has none of these parts.
