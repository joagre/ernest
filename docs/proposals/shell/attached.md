# A shell attached to a running node

Begun 2026-10-13 for MVP 4.0. Decided with the user the same day: a shell attaches to a node by a listed name and never by an address; the attached shell is the operator's, trusted as a peer is; and no sandbox of the language's is built. `docs/design/shell.md` is the shell as built; this page is what attaching adds to it.

## 1. Two uses

An operator attaches a shell to a node to look inside it and to change it: read a binding, list its processes, load a fix. That is attaching, section 2.

A visitor of the website runs a shell in the browser to try the language. That is not attaching: a visitor is a stranger, and a stranger's shell is kept apart by the operating system, which costs the language nothing; it is the web server's, `../httpd/proposal.md`.

One node shared by every visitor, each in a sandboxed session attached to it, was weighed on 2026-10-13 and set aside. A sandbox the node enforced itself could be good and never the one wall: a visitor who exhausted the machine's memory would end every session with their own.

## 2. Attaching

`ern shell --attach dir` attaches to the node started from the configuration directory `dir` on this machine, found as `ern stop --config-dir dir` finds it, by `ernest.pid` and the lock the node holds. The shell is then the node's, with no node of its own.

`ern shell --config-dir ops --attach name` attaches from a node of the shell's own to the listed peer named `name`, over the carrier, authenticated as every connection is, by the keys. Neither form takes a process number or an address: a node is reached by its key, and its address comes from a configuration and nowhere else (report §8.7).

An address on the line, `--attach ip:port`, was weighed and set aside. The node could check the shell's key, but no listed key would give the node a name for the shell to check, so the shell would trust whatever answered. The listed peer keeps both sides checked for three lines in `ops/ernest.conf`, which the node's side needs touching for anyway, the operator's key listed there.

An attached session is a session of the shell's on the node. Its evaluation processes are rooted on the node; its inputs are compiled where the shell runs and shipped as code crosses with a spawn (report §8.7), or compiled on the node; its bindings' values are the node's, read by a compute that needs no wrapping; its `:processes` are the node's; and its `:load` and `:reload` act on the node's code as they act on the shell's own today. `:quit` becomes `:detach`, which ends the session and leaves the node running with what the session started.

Sessions are many on one node, where today one node is one session. Operators attach to one node at once, and a type declared at the prompt is the session's, `$Session.T` (Appendix H), so two sessions declaring one name must not meet: a session has a namespace of its own, `$Session3.T`, and the code table keeps each session's units apart and lets them go when the session ends.

## 3. What other systems do

- **Erlang's `erl -remsh`** attaches a shell to a running node over the distribution, authenticated by the cookie; everything the node can do the shell can do, which is the operator's case and the shape of section 2.
- **Elixir's Livebook** attaches a notebook to a running node and evaluates cells there, the operator's case, with no sandbox.


## 4. Open, for MVP 4.0's design

1. **Where inputs compile**, on the shell's side and shipped as code crosses, or on the node.
2. **A session's process on the node**: its root, what it is to `Process.live`, and what the session shows when the node is lost.
3. **`:load` and `:reload` on the node**: what they load from, the node's load path or the shell's source root, and what a reload replaces where other sessions, or the node's program, hold the previous version.
4. **The deployment guide's section 6**, rewritten over the attached shell once it exists.
