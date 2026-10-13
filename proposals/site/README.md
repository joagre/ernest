# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`site.md`](site.md) | the gaps the decisions leave, and the proposal's status | current; begun 2026-10-10, its settled parts moved to `decisions.md` on 2026-10-13 |
| [`documents.md`](documents.md) | the outlines of Why and Features, and what is open about them | current; begun 2026-10-13, its settled parts moved to `decisions.md` the same day |
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the docroot, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13 |
| `templates/` | the templates, early versions of the design, with their rendering contract in `templates/README.md` | a first design |
| `docroot/` | the pages served, as `decisions.md` lays them out: a directory for each part of the tree, holding a `remove.me` until its pages come; the assets; and under `mockup/` the first design's pages, flat, to open in a browser | a first design |
| `Makefile` | the prototype's build | empty |

The milestone is MVP 4.2; the generator may come earlier, whenever it is wanted.

## Prototyping

The site is prototyped in this directory, its generator and its pages, as
`decisions.md` lays them out. Nothing goes to the plan until the user says the
proposal is ready; the gaps `site.md` lists stay there meanwhile.
