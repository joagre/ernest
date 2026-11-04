# The other repositories

What of the `temp*.md` suggestions reaches `ernest-template`, and from it `ernest-epx` and `ernest-httpd`, for one layout and one way of working across the four. A change goes to the template first, then into each application by hand, as the template's copies are kept. Each application's own session makes it there (`docs/clean_room.md`); this file is what Ernest's side asks. Read 2026-11-04.

## Found first: the rule for src/ and tools/

All three keep an Ernest tool in `tools/`, `ernest-template/tools/docs.ern`, built into `tools/build/`. In an application `src/` is the program's own source root (`ernest-epx/src/epx.ern` is `Epx`), so a tool moved there would become a module of the library, which it is not.

So the rule across the four, recommended in place of the layout's change 1:
- **`src/` holds what a release ships.** Ernest's toolchain, runtime, stdlib, libraries and shell; an application's program or library.
- **`tools/` holds what works on the repository and is not shipped, in any language.** Ernest's scripts and its Ernest tools, `site.ern`, `site/` with its shim beside it, and `manual.ern`; an application's `docs.ern`.

Ernest's change 1 then keeps its Ernest tools in `tools/`, a source root as an application's is, and only the site's shim moves, into `tools/site/`. The old README said it already: `src/` holds the Ernest a release ships.

## To the template, then to each application

1. **Every build product under `build/`.** The template's `.gitignore` and Makefile build each source root beside its source, `tools/build/`, `test/build/` and `examples/build/`, beside the top-level `build/`. They become `build/tools/`, `build/test/` and `build/examples/`, as Ernest's change 4 puts everything under `build/`.
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
   - The redraft goes in order: Ernest's CLAUDE.md first; then the template's, cut again from it, as its first line says it is "cut from Ernest's own"; then each copy takes the template's whole and keeps its own first two lines. The plain wording is written once, not four times. About 3,300 words to some 2,200, about 1,400 tokens a session in each.
   - It names no build path: the `build/` changes of item 1 are the Makefile's and `.gitignore`'s.
   - **Good rules travel every way, decided with the user 2026-11-04.** By their headings, the applications' files hold no rule Ernest's lacks: their thirteen differing headings are Ernest's rules fitted to an application ("The design changes first", "The program is beautiful", "A test lives in the module it tests"), the three alike. But a sibling's wording of a shared rule may have grown clearer, which only a reading line by line shows. So:
     - A harvest before the redraft: the four files read side by side, rule by rule, and a sibling's clearer wording of a shared rule, or a rule of its that applies, taken into Ernest's draft first; then the template is cut from it, and the copies take the template's. The best phrasing wins wherever it was written.
     - A standing rule, in Ernest's CLAUDE.md and the template's: a good rule found in an application goes to the template, and to Ernest's where it applies, and from the template to the other copies. Today the template's first line says a rule changes in the template first and then each copy, one way alone.
6. **`.gitignore`.** Read for drift as Ernest's was; the template's reads clean now, but for item 1's paths.
7. **A log grown past GitHub's rendering**, split by month as Ernest's would be: a rule in the template for when an application's log grows, not a change now, since the applications' logs are small.

## Not carried

- Ernest's own: the role-named `src/` directories (toolchain, shared, runtime, nodes), the shims beside their libraries, `release/`, the examples' and tests' renames, `docs/reviews/`, `code_style.md` and `memory_checks.md`, the "Code travels" claim and the Gleam line. An application has none of these parts.
