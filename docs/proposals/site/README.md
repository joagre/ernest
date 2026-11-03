# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the root, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13, from the design the removed `site.md` and `documents.md` held; read back 2026-10-30 with its findings applied |
| [`todo.md`](todo.md) | what the discussion found should change outside this directory, each line until it is made or dropped | current; begun 2026-11-03 |
| `templates/` | the templates and their fragments, each a token file of readable HTML, with the tokens each binds in `templates/README.md` | current; written 2026-11-03 from the mockup's pages |
| `root/` | the assets, laid out as served, and under `mockup/` a page of each kind in the settled look, flat, to serve and open in a browser | current; the look settled 2026-11-03 |
| `tools/`, `Makefile`, `build/` | the prototype's generator, the rules that build and run it, and what they make: the compiled generator, and the served tree in `build/site/`, which git ignores | not written |

The milestone is MVP 4.2. Its first item, the look by hand, is done (the log's *The Site's Look, by Hand*): the mockup holds a page of each kind in the settled look, and the templates are written. Next is its item 2, the generator.

## Prototyping

The site is prototyped in this directory, its generator and its pages, as
`decisions.md` lays them out. The proposal was ready on 2026-10-30, and the plan's
MVP 4.2 is its items in build order since that day.

What the prototype still lacks:

- The generator, item 2, with its `foreign` declaration over the toolchain's lexer, which the coloring needs. The mockup's pages were rendered by throwaway scripts, outside the repository, and the generator replaces them.
- The session client's remaining pieces, item 4: the snackbar at a session's end, the navigation that keeps the panel across pages, and the server's attach word in place of the client's own note.
