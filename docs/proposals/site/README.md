# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the docroot, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13, from the design the removed `site.md` and `documents.md` held; read back 2026-10-30 with its findings applied |
| `templates/` | the templates, early versions of the design, with their rendering contract in `templates/README.md` | a first design |
| `docroot/` | the assets, laid out as served, and under `mockup/` the first design's pages, flat, to open in a browser, with the logos they show | a first design |
| `tools/`, `Makefile`, `build/` | the prototype's generator, the rules that build and run it, and what they make: the compiled generator, and the served tree in `build/site/`, which git ignores | not written |

The milestone is MVP 4.2; the generator may come earlier, whenever it is wanted.

## Prototyping

The site is prototyped in this directory, its generator and its pages, as
`decisions.md` lays them out. The proposal was ready on 2026-10-30, and the plan's
MVP 4.2 is its items in build order since that day.

What the prototype still lacks:

- The generator's `foreign` declaration over the toolchain's lexer, which the coloring needs (decided 2026-10-30).
- `CHANGES.md` holds no release yet; the release step writes its first section at the next release (2026-10-30).
- The templates hold the first design, which `decisions.md` has moved past in
  the header's stoat, the favicon, the footer's rooms, the homepage's order and
  the shell's controls; the fragments for a list's items do not exist yet.
- The tour's pages: its document, `tour/README.md`, is written (2026-10-24), and the
  prototype does not render it yet.
