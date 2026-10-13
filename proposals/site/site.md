# The Ernest website

A proposal, under discussion. What is settled is in
[`decisions.md`](decisions.md); nothing is open, and this file holds the gaps
the decisions leave and the proposal's status. The templates under
`templates/` are early versions of the design, and `templates/README.md` holds
their rendering contract. The milestone is MVP 4.2, after 0.5.0; the generator
can come earlier, whenever it is wanted.

## Gaps

- `ern` has no command that gives a source's tokens, which the coloring needs.
- `releases/<version>.md` does not exist; the release step writes the notes
  only to GitHub today.
- The favicon, a simplified stoat head, and the approved dark logo are still to
  draw; `ernest-dark.svg` is a provisional derivative.
- `templates/header.html` links home by text alone, where `decisions.md` puts
  the stoat beside "Ernest".

## Status

When the proposal is decided, the plan's MVP 4.2 changes with it: it still
builds the module pages from the doc chunk's parts, where `decisions.md`
renders them from `man/`.
