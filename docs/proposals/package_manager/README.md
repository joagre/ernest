# Packages

What each file here is, and which is current. The proposal is under discussion: all of it is tentative, and nothing flows from it into the report, the plan or the log.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | a package as a directory with a manifest, `package.conf`, found in the working directory; a root that writes every version itself, and a dependency's lines read as claims; one namespace for each package; an archive downloaded by hand and unpacked by `ern unpack`; a package's Erlang and C; Appendix G unchanged; what does not change; the cost; the build order; what it meets | current; written 2026-11-09, each of its seven questions decided with the user, and read against every owner it names |
| [`trial.md`](trial.md) | the proposal tried on paper: the three other repositories' manifests, the template's Makefile as it would stand, a program over ernest-epx, a package that loads a package, and what the trial found | written 2026-11-09; its findings are in the proposal |
| [`other_systems.md`](other_systems.md) | what Go, Elm, Cargo, Hex, npm, Nix and Erlang/OTP do with a dependency, each from its own documents, and what the proposal takes from each | written 2026-11-09 |

The need: a library of Appendix G stands on every job's load path, and a library in a repository of its own is reached only by a load path written by hand, so that being listed is the one easy way to be loaded.

One question stands with the user: whether a version before 1.0.0 is exempt from the proposal's rule that a break takes a new name, as Go exempts one.

It supersedes the log's *Packages* in part, which the log says once the proposal is decided.
