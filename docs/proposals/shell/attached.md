# A shell attached to a running node

Begun 2026-10-13 for MVP 4.0. Decided with the user the same day: a shell attaches to a node by a listed name and never by an address; the attached shell is the operator's, trusted as a peer is; and no sandbox of the language's is built. Read back against `docs/design/shell.md` on 2026-10-30 and rewritten over the cut that reading decided, section 2. `docs/design/shell.md` is the shell as built; this page is what attaching adds to it.

## 1. Two uses

An operator attaches a shell to a node to look inside it and to change it: read a binding, list its processes, load a fix. That is attaching, sections 2 to 4. The first node in production an operator attaches to is ernest-httpd, which runs as a node on the loopback for that reason (`../httpd/proposal.md`, *Under systemd*), and the deployment guide's section 6 shows it there.

A visitor of the website runs a shell in the browser to try the language. That is not attaching: a visitor is a stranger, and a stranger's shell is kept apart by the operating system, which costs the language nothing; it is the web server's, `../httpd/proposal.md`.

One node shared by every visitor, each in a sandboxed session attached to it, was weighed on 2026-10-13 and set aside. A sandbox the node enforced itself could be good and never the one wall: a visitor who exhausted the machine's memory would end every session with their own.

## 2. The cut

The attached shell's local half is the operator's machine, its terminal and its files; everything else is the node's. The shell of the design note, its session, its reader and its screen, runs on the node, and the note holds for it everywhere but where the shell touches the terminal or a file, which the local half does for it: the reader's subscription to the keys and its hold of the terminal, the screen's write, line mode's read of a line, the history's read and its appends, the startup files, `NO_COLOR` and `HOME`, `:load`'s and `:reload`'s read of a source and the listing of the source root for completion, and `:output`'s file. What crosses the carrier is the terminal's events, its size and the bytes written to it, and those files' contents.

The design note assumes everywhere that the shell runs on the node whose code it evaluates: inputs are compiled and loaded as modules of that node, bindings live in its store and are read by holders' getters, evaluators live on it, `Process.live()` and `Process.faults` are its, and `:load` fills its code table. The other cut, the session beside the operator and every front end function a call across the carrier, would split the note in two and put some thirty functions on the wire; this one puts one narrow interface there and keeps the note whole. It is the cut of Erlang's `erl -remsh`, whose shell process runs on the remote node with the local node as its terminal.

So an input is compiled on the node, since the checker's inputs, the node's interfaces and the session's scope, are there; a binding is read as the note reads one, with no compute; and nothing of an input is shipped.

## 3. Attaching

`ern shell --config-dir ops --attach name` attaches from a node of the shell's own, the directory `ops`, to the listed peer `name`, over the carrier, authenticated as every connection is, by the keys (report §12.5). The node lists the shell's key among its peers, without an address, since the shell dials in and is never dialed. On one machine the listing is `ern config`'s: `--peer-dir` lists each directory in the other, the peer's name being its directory's last segment, and `ern reload` tells the running node. An attached shell takes no file: the node's program runs there, and a file is loaded with `:load`.

A second form for a node on this machine, `--attach dir`, found by `ernest.pid` and the lock the node holds, was weighed and set aside on 2026-10-30. A process number opens no channel, the carrier needs a node on each side, and a node accepts a connection from a peer whose key it lists and no other, refusing even its own key as a peer's (§12.5); a channel for this form alone would be a second way.

An address on the line, `--attach ip:port`, was weighed and set aside on 2026-10-13. The node could check the shell's key, but no listed key would give the node a name for the shell to check, so the shell would trust whatever answered. The listed peer keeps both sides checked for three lines in `ops/ernest.conf`, which the node's side needs touching for anyway, the operator's key listed there.

At attach, the local half holds the terminal, reads the history and the startup files, reads `NO_COLOR` and `HOME` as the shell reads them, and spawns the shell's entry on the node with `Peer.spawn`, giving it its own address and what it read. The shell's units are the toolchain's own, which a node on the same floor loads from its tree as it is and never takes as forms (§12.7), so the spawn ships hashes and no code. The reader takes the events the local half forwards, the interrupt among them as a key, and the history's appends go back the same way; in line mode, where the local half's standard input is no terminal, there is no reader and the local half reads each line and sends it to the session, which takes it as it takes a line read itself. The screen writes by sending bytes to the local half, and its `Flush` is a call to it. The configuration directory's startup file is the shell's own node's, `ops`'s. The local half is written in Ernest, as the shell is.

## 4. The session on the node

**Its processes.** The session is the root of its own chain, its row naming the shell's node as the peer whose spawn started it. The front end's tables are made on the node at the first attach and their rows are keyed by the session's number; the session's load path and the interfaces behind it are the node's, read from the node's own state and not from a runner's load, and its source root is the operator's. `Process.live()` leaves out each session's own processes, the session, the reader, the screen, the input that runs and the evaluators, as the shell's launch has the runtime leave its own out today, so that `:processes` in any session lists the node's program's processes and what inputs spawned. The session subscribes to the node's faults and says each at the prompt as the shell says its own, the node's program's among them, and `:faults` lists them.

**Its names.** Sessions are many on one node, where today one node is one session. Operators attach to one node at once, and a type declared at the prompt is the session's, `$Session.T` (Appendix H), so two sessions declaring one name must not meet: a session has a number on the node and a namespace of its own, `$Session3.T`. Every host name an input makes carries the session's number too, its module, its holder and the checking modules `$Fields` and `$Signature`, and the numbers given again are the session's. The code table keeps each session's units apart and lets them go as the purge allows.

**Its output.** Standard output and standard error are system processes of the node (§8.2), and the shell today reaches its screen because the runner binds the launch's sinks to it. On a node with a program of its own that binding cannot be the launch's: the runtime routes a write to standard output or standard error by the writing process's root, a process rooted in a session writing to that session's screen, and a root with no screen, the program's and a detached session's survivors, writing to the node's (§12.1). By the runtime's note's rule, the row and its reader are named: a session writes a row of its root and its screen at its start and removes it at its end, and the standard streams read it, and the writer's row for its root, at each write, a fraction of the write; a process of the runtime's own that acts for another, a delivery, writes as the one it acts for. The look changes nothing, since a node makes none (§8.6).

**Loading and reloading.** `:load name` compiles the operator's source, which the local half reads and ships as text, against the node's interfaces, and loads the result on the node as the note loads one; completion for `:load` lists the operator's source root. `:reload` finds a changed source among the operator's as `:load` reads one, by the hash the node's compiled module carries. A module has one current version on the node: a reload by any session is the node's, every session's next input is checked against it, and a session's previous interfaces are for the types its own inputs named, as the note has them today with one session.

**Detaching.** `:detach` stands in `:quit`'s place, and `C-d` and the end of input detach as they quit today. It ends the session's own processes and an input that runs, and leaves the node running with what the session started: the evaluators, what they started and every process an input spawned are the node's from then on, as `Code.load` leaves what it evaluated under `ern run` (Appendix E.28), so a fix loaded as a service binding survives the detach. The session's inputs' modules are freed as the purge allows, a unit a live process runs kept.

**The node's loss.** The session monitors the local half and the local half the session, across nodes (§6.9). A connection lost ends the session as a detach does, with the reason `Unreachable`, and the local half says `the node name is lost` on standard error and exits with status 1; a node that ended, by `ern stop` or its program's end, ends the local half the same way with status 0 and a line saying the node ended. A node detects no deadlock (§8.6), so the reader's wait on events from another node raises no question for the look.

## 5. What other systems do

- **Erlang's `erl -remsh`** attaches a shell to a running node over the distribution, authenticated by the cookie; the shell process runs on the remote node and the local node is its terminal, which is section 2's cut; everything the node can do the shell can do, which is the operator's case.
- **Elixir's Livebook** attaches a notebook to a running node and evaluates cells there, the operator's case, with no sandbox.

## 6. What the report gains

The sentences the build writes first, each in the section that owns it:

1. §11.2: `ern shell --config-dir ops --attach name`, which takes no file; `:detach` in `:quit`'s place; sessions many on a node, each with a number; what `:processes`, `:load`, `:reload`, `:output` and `:faults` are on the node; the operator's files read by the operator's machine; what the shell says and exits with at the node's loss and at its end.
2. Appendix H: a session's one namespace becomes each session's, `$Session3`.
3. §12.1: a write to standard output or standard error routed by the writing process's root.
4. Appendix E.21: `Process.live()` leaving out every session's own processes.

Nothing of §3 to §9 changes, so the soundness argument stands as it is.

## 7. Open

Nothing. What the build finds goes to the plan.
