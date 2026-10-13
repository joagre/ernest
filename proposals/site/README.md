# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the docroot, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13, from the design the removed `site.md` and `documents.md` held |
| [`outlines.md`](outlines.md) | the outlines of Why and Features, which guide their writing; it goes once both are begun | current; begun 2026-10-13 as `documents.md` |
| `templates/` | the templates, early versions of the design, with their rendering contract in `templates/README.md` | a first design |
| `docroot/` | what is written by hand, laid out as served: the assets, the shell page's and the install page's places, and under `mockup/` the first design's pages, flat, to open in a browser | a first design |
| `tools/`, `Makefile`, `build/` | the prototype's generator, the rules that build and run it, and what they make: the compiled generator, and the served tree in `build/site/`, which git ignores | not written |

The milestone is MVP 4.2; the generator may come earlier, whenever it is wanted.

## Prototyping

The site is prototyped in this directory, its generator and its pages, as
`decisions.md` lays them out. Nothing goes to the plan until the user says the
proposal is ready. When it is, the plan's MVP 4.2 changes with it, since it
still builds the module pages from the doc chunk's parts.

What the prototype still lacks:

- `ern` has no command that gives a source's tokens, which the coloring needs.
- `releases/<version>.md` does not exist; the release step writes the notes
  only to GitHub today.
- The favicon and the approved dark logo are still to draw; `ernest-dark.svg`
  is a provisional derivative.
- `templates/header.html` links home by text alone, where `decisions.md` puts
  the stoat beside "Ernest".
