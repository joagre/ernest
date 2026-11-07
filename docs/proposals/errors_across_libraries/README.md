# An error across a library

What each file here is, and which is current. Decided and built 2026-11-07, the third way
with every recommendation, as MVP 4.15's item 13 and the log's *An Error Across a Library*
record; the directory is kept as the record of the design until the milestone's row names
the log entries that argue it, and changes only in its form.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | the need; the three ways the plan names and a fourth, the third recommended; the rule; the questions, each with a recommendation; what the repository shows; what does not change; the cost; the build order | built 2026-11-07 as written, E.0 shape rule 11 and G.11 stating it |
| [`other_systems.md`](other_systems.md) | what Zig, OCaml, Roc, Go, Java, Erlang, Rust, Swift, Haskell, F#, Elm and Gleam do with two error types in one block, and what each costs on the principles | written 2026-11-07 |

The need is feedback 185: a block's `<-` takes one error type (§5.5), and `libs/http`'s
error wraps the socket's, so a program over the library lifts every `Tcp` call with
`Either.mapLeft(..., Http.Socket)`, a lift that says nothing.
