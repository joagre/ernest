# The Ernest website

A proposal, under discussion. What is settled is in
[`decisions.md`](decisions.md); this file holds what is still open. The
templates under `templates/` are early versions of the design, and
`templates/README.md` holds their rendering contract. The milestone is MVP 4.2,
after 0.5.0; the generator can come earlier, whenever it is wanted.

## Open

1. **Names in code.** Whether a function in a code block links to its library
   page and a type to its declaration, through `man/`'s declarations.

## Gaps

- `ern` has no command that gives a source's tokens, which the coloring needs.
- `releases/<version>.md` does not exist; the release step writes the notes
  only to GitHub today.
- The favicon, a simplified stoat head, and the approved dark logo are still to
  draw; `ernest-dark.svg` is a provisional derivative.
- `templates/header.html` links home by text alone, where `decisions.md` puts
  the stoat beside "Ernest".

## Status

Early versions: the templates are a first design, and the generator is not
written. What the discussion has settled is in [`decisions.md`](decisions.md);
nothing enters the plan until the proposal is decided. When it does, the plan's
MVP 4.2 changes with it: it still builds the module pages from the doc chunk's
parts, where `decisions.md` renders them from `man/`. The plan's MVP 4.2
section records what was agreed on 2026-10-10: the generator is a program beside
`tools/manual.ern` against the library's tree, nothing of the site enters the
library, `roff` moves to the manual tool when the library is next touched, and
the generator may come before the rest of the milestone.
