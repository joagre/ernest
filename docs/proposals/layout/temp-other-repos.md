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
4. **The README's shape.** What the program is and where to begin, central links only, no argument the program's own documents make. The template's README and the guidance in `TEMPLATE.md` say so; each application's README is read against it.
5. **CLAUDE.md.**
   - The kept-proposals rule: a proposal refused or not taken up stays, its README's status line saying which; only a built one goes.
   - The owner table names `docs/README.md`, or the docs, once, not each document twice.
   - The plain register, as Ernest's CLAUDE.md is redrafted.

   The template first, then each copy, as a rule's change always goes.
6. **`.gitignore`.** Read for drift as Ernest's was; the template's reads clean now, but for item 1's paths.
7. **A log grown past GitHub's rendering**, split by month as Ernest's would be: a rule in the template for when an application's log grows, not a change now, since the applications' logs are small.

## Not carried

- Ernest's own: the role-named `src/` directories (toolchain, shared, runtime, nodes), the shims beside their libraries, `release/`, the examples' and tests' renames, `docs/reviews/`, `code_style.md` and `memory_checks.md`, the "Code travels" claim and the Gleam line. An application has none of these parts.
