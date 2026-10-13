# The website

What each file here is, and which is current. All of it is under discussion,
as CLAUDE.md says of a proposal: nothing flows from it into the plan, the log
or the report until the proposal is decided. `decisions.md` records what the
discussion has settled meanwhile.

| File | What it is | Status |
|---|---|---|
| [`site.md`](site.md) | the site's design: what it is for, its pages and templates, how it is generated from what the repository holds, how its pages link, the live shell beside every page, and what has to be decided before it enters the plan | current; begun 2026-10-10, the linking and the shell panel added 2026-10-13 |
| [`documents.md`](documents.md) | the documents the project will have, which reader each serves, what `but_why.md` and `features.md` are to hold, the doors and the rooms, and the order of writing | current; begun 2026-10-13 |
| [`but_why.md`](but_why.md) | a first draft of the document `documents.md` describes, with the typing section drafted on 2026-10-13 and the other sections as headings and notes | a draft, food for thought |
| [`decisions.md`](decisions.md) | what the discussion has settled, tersely: the docroot's tree and its rules, and the anchors | current; begun 2026-10-13 |
| `templates/` | the templates, early versions of the design, with their rendering contract in `templates/README.md` | a first design |
| `docroot/` | the pages served, as `decisions.md` lays them out: a directory for each part of the tree, holding a `remove.me` until its pages come; the assets; and under `mockup/` the first design's pages, flat, to open in a browser | a first design |
| `tools/`, `Makefile`, `build/` | the generator's beginnings | not written |

The milestone is MVP 4.2; the generator may come earlier, whenever it is wanted.

## Work order

When the work starts, the notes are hardened in this order, decided 2026-10-13:

1. **`documents.md`, the set and the doors.** The site shows documents, so the
   set decides the site map, the header, the paths and what the generator
   reads. Most of the set exists; the open part is the two new documents, their
   place in the repository and who tests them, and which entrances are doors.
   One sitting.
2. **`site.md`, the linking.** It follows from the set, and it is the part a
   reader sees; the site map is settled in `decisions.md`. The open questions
   there are the version the site shows and the header's list.
3. **The generator's mechanics**, `site.md`'s chapter cuts and tokens.
   They depend only on the report, the guide and the library, which exist, so
   they can be hardened at any time, in parallel with writing; the plan lets
   the generator come before the milestone.
4. **The shell service**, the container, the limits and the panel. Last, since
   it is the one part with operations behind it and nothing else waits on it.

Meanwhile `features.md` is written at any point, an afternoon that gives
everything else something to point at, and `but_why.md`'s chapters are
written while the generator is built, each with its examples compiled before
they are quoted.
