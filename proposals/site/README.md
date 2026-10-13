# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`site.md`](site.md) | what is still open about the site, and its gaps | current; begun 2026-10-10, its settled parts moved to `decisions.md` on 2026-10-13 |
| [`documents.md`](documents.md) | the outlines of Why and Features, and what is open about them | current; begun 2026-10-13, its settled parts moved to `decisions.md` the same day |
| [`but_why.md`](but_why.md) | a first draft of the document `documents.md` describes, with the typing section drafted on 2026-10-13 and the other sections as headings and notes | a draft, food for thought |
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the docroot, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13 |
| `templates/` | the templates, early versions of the design, with their rendering contract in `templates/README.md` | a first design |
| `docroot/` | the pages served, as `decisions.md` lays them out: a directory for each part of the tree, holding a `remove.me` until its pages come; the assets; and under `mockup/` the first design's pages, flat, to open in a browser | a first design |
| `tools/`, `Makefile`, `build/` | the generator's beginnings | not written |

The milestone is MVP 4.2; the generator may come earlier, whenever it is wanted.

## What remains

The open items of `site.md` and `documents.md`, then the gaps `site.md` lists.
When none is open, the proposal is decided and goes to the plan.
