# A shell attached to a running node

Begun 2026-10-13 for MVP 4.0, and decided the same day with the user in what it settles: a shell attaches to a node by a listed name and never by an address; the attached shell is the operator's, trusted as a peer is; and the website runs the plain shell in a container per visitor, so no sandbox of the language's is built. `shell_design.md` is the shell as built; this page is what attaching adds to it, and what the web machine runs instead.

## 1. Two uses

An operator attaches a shell to a node to look inside it and to change it: read a binding, list its processes, load a fix. A visitor of the website runs a shell in the browser to try the language. The first is attaching, section 2. The second is not: a visitor is a stranger, and a stranger's shell is kept apart by the operating system, section 3, which costs nothing of the language. One node shared by every visitor, each in a sandboxed session attached to it, was weighed on 2026-10-13 and set aside, since a sandbox the node enforced itself could be good and never the one wall, a visitor who exhausted the machine's memory ending every session with his own, while the container is proven and cheap.

## 2. Attaching

`ern shell --attach dir` attaches to the node started from the configuration directory `dir` on this machine, found as `ern stop --config-dir dir` finds it, by `ernest.pid` and the lock the node holds; the shell is then the node's, with no node of its own. `ern shell --config-dir ops --attach name` attaches from a node of the shell's own to the listed peer named `name`, over the carrier, authenticated as every connection is, by the keys. Neither takes a process number or an address: a node is reached by its key, and its address comes from a configuration and nowhere else (report §8.7). An address on the line, `--attach ip:port`, was weighed and set aside: the node could check the shell's key, but no listed key would give the node a name for the shell to check, so the shell would trust whatever answered; the listed peer keeps both sides checked for three lines in `ops/ernest.conf`, which the node's side needs touching for anyway, the operator's key listed there.

What an attached session is on the node: a session of the shell's, with its evaluation processes rooted on the node, its inputs compiled where the shell runs and shipped as code crosses with a spawn (report §8.7), or compiled on the node; its bindings' values the node's, read by a compute that needs no wrapping; its `:processes` the node's; its `:load` and `:reload` acting on the node's code as they act on the shell's own today. `:quit` becomes `:detach`, which ends the session and leaves the node running with what the session started.

Sessions are many on one node, where today one node is one session: operators attach to one node at once, and a type declared at the prompt is the session's, `$Session.T` (Appendix H), so two sessions declaring one name must not meet; a session has a namespace of its own, `$Session3.T`, and the code table keeps each session's units apart and lets them go when the session ends.

## 3. The web machine: a container per visitor

The website's shell is today's `ern shell`, unchanged, behind a pseudo-terminal in a container of its own for each visitor, started by the web server as the browser's connection opens and thrown away as it closes; `:clear`, where the site offers one, is the container started again. The container is the operating system's wall, bubblewrap, firejail or a `systemd-run` scope with cgroup limits, a few megabytes each, and not a container daemon, which would idle at a hundred. The limits are the container's: memory, a cap that ends the one visitor who passes it; CPU, one scheduler for the shell's BEAM and a quota of a fraction of a core, so that a visitor's tight loop cannot take the server; no network; an idle time of a few minutes; and a cap on sessions at once, with a plain line past it.

Measured on 2026-10-13, on an eight-core machine: a bare `erl` with nothing loaded is 71 MB, a bare Ernest node listening 87 MB, and a program's run 72 MB at its peak and 0.6 seconds from start to exit. So a visitor's shell is a BEAM of about 90 MB that starts in under a second. On the web machine of two cores and 2 GB, the system and the site's own node take about 300 MB, which leaves ten or twelve shells at a cap of 128 MB each; ten sessions at once is the cap to set, and memory is the first and cheapest thing to add if the site ever wants more.

## 4. What other systems do

- **Erlang's `erl -remsh`** attaches a shell to a running node over the distribution, authenticated by the cookie; everything the node can do the shell can do, which is the operator's case and the shape of section 2.
- **The Go and Rust playgrounds** run each submission in a fresh sandbox with time, memory and output limits and no network, and keep nothing; a container or a VM per run, which is section 3's shape.
- **Try Elixir, Try OCaml and Jupyter's kernels** run one process per visitor behind a web terminal, each with its own limits; one runtime per user, not one for all.
- **Elixir's Livebook** attaches a notebook to a running node and evaluates cells there, the operator's case, with no sandbox.

No system known to me runs strangers' sessions on one shared runtime without a process-level wall; those that share one runtime trust their users.

## 5. Open, for MVP 4.0's design

1. **Where inputs compile**, on the shell's side and shipped as code crosses, or on the node.
2. **A session's process on the node**: its root, what it is to `Process.live`, and what the session shows when the node is lost.
3. **`:load` and `:reload` on the node**: what they load from, the node's load path or the shell's source root, and what a reload replaces where other sessions, or the node's program, hold the previous version.
4. **The deployment guide's section 6**, rewritten over the attached shell once it exists.
