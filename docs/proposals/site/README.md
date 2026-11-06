# The website

What each file here is, and which is current. Built: MVP 4.2 closed on 2026-11-06, and its row
in the plan names the log entries that argue it. The proposal is kept as the record of its
design while the tools and the tests cite it, and goes with MVP 4.4's item 6.

| File | What it is | Status |
|---|---|---|
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the purpose, the root, the anchors, the pages, the look, the links, the templates, the generation, the live shell and the documents | the record; begun 2026-10-13, from the design the removed `site.md` and `documents.md` held; read back 2026-10-30 with its findings applied |
| `root/mockup/` | a page of each kind in the settled look, flat; the assets it named moved to `site/root/assets/` on 2026-11-03, so a page here no longer finds `../assets` | the record of item 1; the look settled 2026-11-03 |

The milestone was MVP 4.2. Its first item, the look by hand (the log's *The Site's Look, by Hand*), left the mockup, a page of each kind in the settled look, and the templates. Its item 2, the generator, is `tools/site.ern`, which reads the templates and the assets from `site/` at the repository's root, where they moved from this directory on 2026-11-03.

## Prototyping

The site was prototyped in this directory, its templates and its pages, as
`decisions.md` lays them out. The proposal was ready on 2026-10-30, and the plan's
MVP 4.2 was its items in build order from that day.
