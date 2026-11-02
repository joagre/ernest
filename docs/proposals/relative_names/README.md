# Relative names

What each file here is, and which is current. All of it is under discussion, as
CLAUDE.md says of a proposal: nothing flows from it into the plan, the log or the
report until the proposal is decided. The plan's MVP 4.15, item 6, names it.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | the rule: a qualified name resolves from the writer's namespace outward, and its shortest resolving form is the only form; the questions the rule raises, each with a recommendation; what does not change; the cost; the build order | current; written 2026-11-02 from the discussion the log's *What the Server Taught* records |
| [`other_systems.md`](other_systems.md) | what C++, C#, Go, Rust, Haskell, OCaml, Elixir, Erlang and Unison do with a long name, and what each costs on the principles | written 2026-11-02 |

The need is feedback 204: the shell, moved under the taken namespace `Ernest`, names its
own modules `Ernest.Shell.Command.parse` at 139 sites, and any program with a tree of
modules pays the same.
