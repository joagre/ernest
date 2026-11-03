# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the root, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | current; begun 2026-10-13, from the design the removed `site.md` and `documents.md` held; read back 2026-10-30 with its findings applied |
| `root/mockup/` | a page of each kind in the settled look, flat; the assets it named moved to `site/root/assets/` on 2026-11-03, so a page here no longer finds `../assets` | the record of item 1; the look settled 2026-11-03 |

The milestone is MVP 4.2. Its first item, the look by hand, is done (the log's *The Site's Look, by Hand*): the mockup holds a page of each kind in the settled look, and the templates are written. Its item 2, the generator, is `tools/site.ern`, which reads the templates and the assets from `site/` at the repository's root, where they moved from this directory on 2026-11-03.

## Prototyping

The site was prototyped in this directory, its templates and its pages, as
`decisions.md` lays them out. The proposal was ready on 2026-10-30, and the plan's
MVP 4.2 is its items in build order since that day.

What the site still lacks:

- The generator's pages beyond the guide's, item 2. The mockup's pages were rendered by throwaway scripts, outside the repository, and the generator replaces them.
- The session client's remaining pieces, item 4: the snackbar at a session's end, the navigation that keeps the panel across pages, and the server's attach word in place of the client's own note.
