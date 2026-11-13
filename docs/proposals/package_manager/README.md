# Packages

What each file here is, and which is current. The proposal is decided and planned, as MVP 4.16's items 4 to 10. Nothing in it is authoritative.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | a package as a directory with a manifest, `package.conf`, found in the working directory; a root that writes every version itself, and a dependency's lines read as claims; one namespace for each package; an archive downloaded by hand and unpacked by `ern unpack`; a package's Erlang and C; Appendix G unchanged; what does not change; the cost; the build order; what it meets | current; written 2026-11-09, each of its seven questions decided with the user, and read against every owner it names; planned that day as MVP 4.16's items 4 to 10; item 4, the report's §11.9, done 2026-11-11; where the report has left it, the log's *The Proposal Held Against the Report* and *An Installed Program's Packages* list |
| [`trial.md`](trial.md) | the proposal tried on paper: the three other repositories' manifests, the template's Makefile as it would stand, a program over ernest-epx, a package that loads a package, and what the trial found | written 2026-11-09; its findings are in the proposal |
| [`other_systems.md`](other_systems.md) | what Go, Elm, Cargo, Hex, npm, Nix and Erlang/OTP do with a dependency, each from its own documents, and what the proposal takes from each | written 2026-11-09 |

The need: a library of Appendix G stands on every job's load path, and a library in a repository of its own is reached only by a load path written by hand, so that being listed is the one easy way to be loaded.

It supersedes the log's *Packages* in part, as the log's *A Package and Its Manifest* says.
