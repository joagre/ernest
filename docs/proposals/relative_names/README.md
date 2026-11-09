# Relative names

What each file here is, and which is current. The proposal is decided and the report
states it; the directory is the record of its design until the plan's MVP 4.15, item 16,
builds it.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | the rule: a qualified name resolves from the writer's namespace outward, and its shortest resolving form is the only form; the questions the rule raises, each with a recommendation; what does not change; the cost; the build order | current; written 2026-11-02 from the discussion the log's *What the Server Taught* records, its five recommendations agreed with the user the same day; read against every owner it touches and decided 2026-11-09 (the log's *Relative Names*), the report stating it; kept as the record until MVP 4.15's item 16 is built |
| [`other_systems.md`](other_systems.md) | what C++, C#, Go, Rust, Haskell, OCaml, Elixir, Erlang and Unison do with a long name, and what each costs on the principles | written 2026-11-02 |

The need is feedback 204: the shell, moved under the taken namespace `Ernest`, names its
own modules `Ernest.Shell.Command.parse` at 139 sites, and any program with a tree of
modules pays the same.
