# A shell attached to a running node, and a sandboxed session

Begun 2026-10-13 for MVP 4.0 and MVP 4.2. Decided the same day with the user in two parts: section 2, attaching, is MVP 4.0's, the operator's alone and with no sandbox, by a listed name and never an address; sections 3 and 4, the sandboxed session, are set aside, the website running the plain shell in a container per visitor as MVP 4.2 decided on 2026-10-10, since a language-level sandbox is never the one wall and the container needs nothing of the language. Sections 3 and 4 are kept as what was weighed. `shell_design.md` is the shell as built; this page is what attaching adds to it and what a session open to strangers must refuse and bound.

## 1. Two uses, one mechanism

An operator attaches a shell to a node to look inside it and to change it: read a binding, list its processes, load a fix. A visitor of the website attaches to a node the site runs, through a terminal in the browser, to try the language. The mechanism is one, a session of the shell's that runs on a node it did not start, and the second use adds a sandbox: what the session may not do, and how much of the node it may use.

MVP 4.2 as planned on 2026-10-10 put the website's sandbox outside the language, one container per visitor with the operating system's limits, since Ernest's system modules are ambient by design. One node for every visitor, with sessions attached to it, is the alternative this page weighs: cheaper by far per visitor and the same mechanism as the operator's, against a sandbox the node must enforce itself. The two can also stand together, the container as the outer wall and the sandboxed session inside it, which costs the container's price and buys the second wall.

## 2. Attaching

`ern shell --attach dir` attaches to the node started from the configuration directory `dir` on this machine, found as `ern stop --config-dir dir` finds it, by `ernest.pid` and the lock the node holds; the shell is then the node's, with no node of its own. `ern shell --config-dir ops --attach name` attaches from a node of the shell's own to the listed peer named `name`, over the carrier, authenticated as every connection is, by the keys. Neither takes a process number or an address: a node is reached by its key, and its address comes from a configuration and nowhere else (report §8.7), so a raw `ip:port` would be a second way around the configuration and an unauthenticated one.

What an attached session is on the node: a session of the shell's, with its evaluation processes rooted on the node, its inputs compiled where the shell runs and shipped as code crosses with a spawn (report §8.7), or compiled on the node; its bindings' values the node's, read by a compute that needs no wrapping; its `:processes` the node's, or the session's own under a sandbox; its `:load` and `:reload` acting on the node's code as they act on the shell's own today. `:quit` becomes `:detach`, which ends the session and leaves the node running; what the session started lives on for an operator and ends with the session under a sandbox.

Sessions are many on one node, where today one node is one session: a type declared at the prompt is the session's, `$Session.T` (Appendix H), and two sessions declaring one name must not meet, so a session has a namespace of its own, `$Session3.T`, and the code table keeps each session's units apart and lets them go when the session ends.

## 3. The sandbox

A session open to strangers runs on a node that is not theirs, beside other strangers' sessions, and must be kept from four things: reaching outside the node, reaching other sessions, exhausting the node, and learning what it should not.

**Reaching outside.** Refused at the prompt, by the checker, as a compile error naming the sandbox: `Tcp`, `Fs`, `Os` but for `Os.arguments` and the clock, `Code`, `Peer`, a `foreign fn` or `foreign type` declaration, `Erl.atom`, `Process.kill` of a process not the session's, and `:load` and `:reload` of anything but what the site curates, the tour's programs among them. The node that serves visitors lists no peers and runs no program but the site's, so that even an escape has nowhere to go.

**Reaching other sessions.** `Process.live` and `:processes` list the session's own processes; an address found by any means other than the session's own spawns is not reached, which the node enforces at `send` where the address's process is not the session's; `Peer.service` and `Peer.offer` are refused, so no session finds another's.

**Exhausting the node.** The limits are the node's to enforce, in its configuration, and a session that passes one is ended with a line saying which: a deadline on each input's evaluation, after which its process is killed, as the host's deadlock detector cannot help on a node; a heap bound on each process the session starts, which the host enforces per process and which ends the process alone; a count of processes a session may have at once; a size and a rate of inputs; an idle time after which the session is detached; and a length of output per input, after which the rest is dropped and said. Atoms are the one count no limit returns: an input's namespace and its unit are two atoms the node never gives back (report §11.2), so a public node is restarted on a schedule, at a quiet hour, which the deployment guide's section 4 already teaches for any node that is sent code without end.

**Learning what it should not.** `Os.environment` is refused with `Os`; a diagnostic shows no path of the server's; a fault's trace names the session's own functions and not another session's; the shell's history is in memory for the session and on no disk.

## 4. `:clear`

A session that wants to start over has everything it made removed: its bindings, its types, its processes, its units. The plain way is that `:clear` is `:detach` and a new session in one step, since a session must be cheap to make and cheap to end for the website at all; what the old session started is killed, its units deleted and purged, and the prompt returns with a fresh namespace. Removing the user's work selectively, keeping the standard library's state and the site's, is the same operation, because nothing of the session's is shared with anything else by construction.

## 5. What other systems do

- **Erlang's `erl -remsh`** attaches a shell to a running node over the distribution, authenticated by the cookie; everything the node can do the shell can do, which is the operator's case and no sandbox.
- **The Go and Rust playgrounds** run each submission in a fresh sandbox with time, memory and output limits and no network, and keep nothing; a container or a VM per run, which is MVP 4.2's plan of 2026-10-10.
- **Try Elixir, Try OCaml, Jupyter kernels** run one process per visitor behind a web terminal, each with its own limits; one kernel per user, not one kernel for all.
- **Elixir's Livebook** attaches a notebook to a running node and evaluates cells there, the operator's case, with no sandbox.

No system known to me runs strangers' sessions on one shared runtime without a process-level wall; those that share one runtime trust their users. The precedent for the website is one runtime per visitor, and the precedent for attaching is the operator's.

## 6. Open

1. **One node for all visitors, or a container each.** The container is the known-safe wall and costs a BEAM per visitor, some tens of megabytes and a second to start; the shared node costs little per visitor and needs every wall of section 3 built and kept. The two together cost the container's price and buy a second wall. To decide first, since it decides how much of section 3 is built.
2. **Where inputs compile.** On the shell's side, shipped as code crosses, or on the node; the sandbox's refusals are the checker's, so where the checker runs decides where they are enforced, and a sandbox enforced only on the client's side is no sandbox: the node must refuse what arrives, not trust what was sent.
3. **The heap bound.** The host ends a process that passes its heap bound; whether the session is ended with it, or told, as a fault is reported.
4. **`:load` of the tour's programs.** Whether the site's curated modules are loaded by name from the node's load path, which is `:load`'s normal way, and nothing else.
5. **An address on the command line.** `ern shell --config-dir xx --attach ip:port`, raised 2026-10-13, reaches a remote node without listing it: the shell has its key from `xx`, so the node checks the shell and admits it, but no listed key gives the node a name for the shell to check, so the shell would trust whatever answers at the address, which §8.7 excludes. The listed peer, `--attach name`, keeps both sides checked for three lines in `xx/ernest.conf`, which the node's side needs touching for anyway, the operator's key listed there; an address with a key beside it on the line, `--attach ip:port --key file`, is that row written on the line, a second way to say what the file says. Decided 2026-10-13 with the user: the name alone, as `ernest.conf` lists it; no address on the line.
6. **What an operator's attached session may do that a visitor's may not**, which is the whole of section 3, and whether the mode is the node's configuration, `"sessions": "sandboxed"`, and never the shell's flag, since the shell is the client's.

## 7. If decided

MVP 4.0 builds section 2 for the operator, with the sessions' namespaces and the code table's part; MVP 4.2 builds section 3 and 4 for the website, on whichever wall section 6's first question chooses, the generator and the site's pages beside it.
