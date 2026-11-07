# An error across a library

What each file here is, and which is current. All of it is under discussion, as
CLAUDE.md says of a proposal: nothing flows from it into the plan, the log or the
report until the proposal is decided. The plan's MVP 4.15, item 13, names it.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | the need; the three ways the plan names and a fourth, the third recommended; the rule; the questions, each with a recommendation; what the repository shows; what does not change; the cost; the build order | current; written 2026-11-07, to be decided with the user |
| [`other_systems.md`](other_systems.md) | what Zig, OCaml, Roc, Go, Java, Erlang, Rust, Swift, Haskell, F#, Elm and Gleam do with two error types in one block, and what each costs on the principles | written 2026-11-07 |

The need is feedback 185: a block's `<-` takes one error type (§5.5), and `libs/http`'s
error wraps the socket's, so a program over the library lifts every `Tcp` call with
`Either.mapLeft(..., Http.Socket)`, a lift that says nothing.
