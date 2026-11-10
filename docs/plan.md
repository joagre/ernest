# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log/`](log/README.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone ends the file. A gap
stands in the milestone whose item closes it, a defect of OTP's in [`otp_bugs.md`](otp_bugs.md),
and a feature declined in a dated entry of the log; nothing stands between.

---

## Where we are

**Ernest 0.9.0 is the last release**, of 2026-11-03, the server's: what ernest-httpd asked of
Ernest on its way to serving the site, and the release review before it, which read two days'
diff, its 112 lines fixed and 23 decided (the log's *The Release Review Before 0.9.0* and the
entries MVP 4.1's row names). No promise of
stability is made, and a change to the language, the standard library or the libraries is driven
by a need met in use and recorded as `docs/language_feedback.md` records one.

The server is released and so is what shaped Ernest on its way, and the checkout works toward
0.10.0.

MVP 4.2, the website, is built, and goes live with MVP 4.4's release, its item 6 (the log's
*Ernest Stays at 0.x*).

The repository's layout is built, between MVP 4.15's items 1 and 2, and the three other
repositories have taken their shape (the log's *The Layout Built*, *The Other Repositories'
Shape*). What the layout proposal still held is made at the same stop, the template's CLAUDE.md
and its copies last, and the proposal has gone (the log's *The Layout's Rest First*, *The Template
Cut Again*, *The Layout's Proposal Read*). The three applications' sessions start next.

The rest of MVP 4.15, what the server taught, follows. Then comes MVP 4.16, a deadlock's scope
and its report and packages, before the launch (the log's *MVP 4.16, the Proposals Before the
Launch*). Then MVP 4.4, the cost, the full review and the launch's release, where the road ends
and a program begins (the log's *MVP 4.4, the Road's End*). MVP 4.5, the shell's second round,
follows the launch (the log's *MVP 4.3 Becomes MVP 4.5*), and MVP 4.6 after it, the server
owning both ends of its socket.

Ernest stays at 0.x until someone outside the project depends on it (the log's *Ernest
Stays at 0.x*). The back end to BEAM's own instructions that closed the road is not built, decided
2026-10-30 (the log's *No Back End to BEAM's Own Instructions*). A finished milestone is a
row of the table at the end, its reasons in the log entries the row names.

---

## MVP 4.15 (what the server taught), about a week and a half

What building and deploying ernest-httpd showed of Ernest, decided 2026-11-02 (the log's *What
the Server Taught*), built after the site's generator (the log's *The Generator Before MVP
4.15*). The items stand in build order, set 2026-11-03, each group done with one look at its
area: the runtime, the standard library's readings, the libraries, the nodes, and relative
names last, since they sweep every site of Ernest once. The eleven decisions for the user, in
items 8, 9, 13, 15, 16, 21, 28, 30, 32, 35 and 36, were discussed early, so that no build waited
on them, the last six on 2026-11-09.

The items left are built in this order, set 2026-11-08 and read again the same day (the log's
*The Items Left Read Again*), items 17, 20, 22, 26, 31, 33 and 34 done by item sessions:

1. One design session for what no test checks, done 2026-11-09: items 36, 21, 30, 32, 19 and
   29 decided, each in its paragraph below, and item 16's proposal read against its owners and
   stated in the report (the log's *Lean at the Limits*, *What `running` Finds*, *The Shell at
   a Full Table*, *A Terminal That Is Gone*, *The Host Says Running*, *Relative Names*).
2. Items 19, 21, 29, 30, 32, 35 and 36, each a report sentence and its build, done 2026-11-09
   (each item's paragraph below).
3. Item 37 decided in a design session, and built, done 2026-11-09.
4. Item 38's build, by an item session, done 2026-11-09.
5. Item 41 diagnosed and fixed, by an item session, done 2026-11-09.
6. Items 39 and 40 decided in a design session, and built, done 2026-11-09.
7. Item 16's build last, done 2026-11-09.
8. Item 42's fix, by an item session, done 2026-11-09.
9. Item 43, by an item session, done 2026-11-10.
10. Item 44, by an item session.
11. Item 45, by an item session.

When the milestone ends, Ernest's session tells ernest-httpd's by a message, as
`docs/clean_room.md` says, the archive's path and commit, that no archive carries a collection at
the wait (the log's *Nothing at the Wait*), and that the release answers that
program's lines still open, each by Ernest's number, and so hands over the site for its
rehearsal of the switch (MVP 4.4's item 6): `make site` from the release's tag, given the
configuration ernest-httpd will serve it with, writes it to `build/site/`, the tag naming the
commit that made it.

ernest-epx's session is told the same archive and item 26's verdict on its
line, and each of the two checks its verdicts against the archive and answers with any line it
keeps, as `docs/clean_room.md`'s *The answer* says (the log's *Both Applications at the
Milestone's End*). All three are told item 16's rule, which each plans for its floor's rise. ernest-template and ernest-epx stay on floor 0.9 until MVP 4.4's item 4 (the
log's *The Floors and the Releases*).

The release's note tells a program with a tree of modules to write each qualified name in its
shortest form from its module's place, as each error's help writes it, and to rename a module
named after a taken namespace at any depth (§4.2; the log's *Relative Names, Built*).

Between items 1 and 2 the repository's layout was built, in one commit, so that items 2 to 21
build in the layout that stays and the archive ernest-httpd rehearses on holds it (the log's
*The Repository's Layout*, *The Layout's Independent Reading*, *The Layout Built*, *The Layout's
Renames*, *The Log by Day*, *The README Recut*). Its proposal went once read (the log's *The
Layout's Proposal Read*).

At the same stop ernest-template, ernest-epx and ernest-httpd took their shape, a commit in each
(the log's *One Stop for the Layout*, *The Other Repositories' Shape*). No floor rose and none
of them released: the changes wait on `main` for MVP 4.4's item 5.

CLAUDE.md is redrafted, 2026-11-06: its owner table names `docs/README.md` once, and its length
stays, since the plain register cut no words (the log's *CLAUDE.md Redrafted*). The template's is
cut again from it, ernest-epx's and ernest-httpd's are the template's whole, and each of the three
has the template's new `docs/full_review.md`, a commit in each (the log's *The Layout's Rest
First*, *The Template Cut Again*).

The three applications' sessions start next, and each adds what it alone has to its
`docs/full_review.md`: ernest-epx a reader who tries its window on a screen, and ernest-httpd what
reader S reads of its live shell. The release note's line on the installed layout waits for MVP
4.4's item 5.

1. **The runtime at the host's limits**, done 2026-11-04 (the log's *A Node's Limits*, *A Node's
   Schedulers*, *The Hangup's Order* and *ernest-httpd's Lines 18 to 21*).

2. **Nothing at the wait**, done 2026-11-07 (§10, E.18, E.21; the log's *Nothing at the Wait* and
   *Nothing at the Wait Built*). A `receive` without an `after` is the host's again, so its waiting
   frame names the last call before the wait or its function's head, as E.21 has said since
   2026-10-23, and not the `receive`'s own line.
3. **Memory shown**, done 2026-11-07 (E.21, §11.2; the log's *Memory Shown*). `Process.status` has
   a `memory` field, and `:processes` writes it. A binary is counted whole for each reference, so
   the lines can add up to more than the node holds, and a socket's counts its writer's and,
   since item 18, its closer's.
4. **The deployment guide says what a waiting process holds**, done 2026-11-07, its section 7's
   last sentence (the log's *Memory Shown*).
5. **`kill` takes a `Process`**, done 2026-11-07 (§6.5, §6.9, §9.5, E.21; the log's *`kill` Takes a
   `Process`*). `Process.kill` went, and a site that holds an address writes
   `kill(Process.fromAddress(worker))`. ernest-httpd meets it at its floor's rise.
6. **Text from bytes that are not all UTF-8**, done 2026-11-07 (E.5, §11.2; the log's *Text from
   Bytes*). `String.fromUtf8Lossy` and `String.fromUtf8Piece` stand, and the shell's and the
   harness's own decoding went.
7. **A text after its prefix, and a slice to the end**, done 2026-11-07 (E.0 rule 2, E.5, E.20;
   the log's *A Text after Its Prefix*). `String.drop`, `Bytes.drop`, `String.stripPrefix` and
   `String.stripSuffix` stand, and the sites are written with them. `String.drop` reverses the
   refusal of 2026-09-26. Feedback 215 is dropped: no search by code points stands beside
   E.5's, since `toList` reads them.
8. **A worker's value or its end**, done 2026-11-07 (E.21, E.24; the log's *A Worker's Value or
   Its End*, *A Worker's Value or Its End Built*, *A Test's Scratch, and JSON on One Line*, *A
   Case's Standard Error*). `Process.run`, `Fs.makeTempDir`, `Json.encode` and `Test.capture`
   stand, `Test.faults` is written over `run`, and the sites are written with it.
   ernest-httpd's lines 20 and 21 wait for its session.
9. **A program's environment, and a signal named**, done 2026-11-07 (E.23; the log's *A
   Program's Environment, and a Signal Named*, *A Program's Environment, and a Signal Named
   Built*). `Os.Command`'s `environment` and `workingDirectory` and `Os.signal` stand, and the
   sites are written with them. The other repositories write the two fields when their floor
   is 0.10. Ernest's session writes ernest-template's `tools/docs.ern`, since the template has
   no session of its own, and the applications take it from the template's tag; ernest-httpd's
   session writes its `ernest_httpd.ern`, `smoke.ern` and `session.ern`, told at the
   milestone's end.
10. **`libs/http`'s values**, done 2026-11-07 (G.11; the log's *`libs/http`'s Values*).
    `Http.http11` and `Http.defaultLimits` stand, and the sites are written with them. ernest-httpd
    writes them in `smoke.ern`, `hosts.ern`, `static.ern` and `shell.ern` when its floor is 0.10,
    by its own session, told at the milestone's end.
11. **`libs/uri`**, done 2026-11-07 (G.12, G.11; the log's *`libs/uri`* and *`libs/uri` Built*).
    `Uri.parse`, `Uri.parseAuthority` and `Uri.decode` stand, and `Http.target`, `Http.cookies`,
    `Http.cookie` and `Http.chunk`; `examples/fetch.ern` and `web_server.ern` are written with them.
    ernest-httpd writes them in `static.ern`, `hosts.ern`, `config.ern` and `shell.ern` when its
    floor is 0.10, by its own session, told at the milestone's end.
12. **A process owns what it opens**, done 2026-11-07 (E.18, E.21; the log's *A Process Owns What
    It Opens*). `examples/fetch.ern` runs its fetch under `Process.run`, whose end closes the
    socket on every way out, and no form of the language closes on leaving a block.
13. **An error across a library**, feedback 185, decided 2026-11-07 (E.0 shape rule 11, G.11;
    the log's *An Error Across a Library*): a library's error that wraps `Io.Error` is the error
    of every operation of its protocol on the resource, so `Http.writeRequest`,
    `Http.writeResponse` and `Http.writeChunk` stand beside its reads, `ReadError` is
    `SocketError`, and a program over `Http` meets `Io.Error` only where it opens the connection.
    The proposal under `docs/proposals/errors_across_libraries/` is its record. Built the same
    day. ernest-httpd meets the rename at its first build against 0.10.0, before its rehearsal
    of the switch, and its `smoke.ern` writes its requests with `writeRequest` by its own
    session, told at the milestone's end.
14. **The libraries' shims read against E.0 rule 1**, done 2026-11-07 (E.0 rule 1, G.6, G.8,
    G.11; the log's *The Libraries' Shims Read Against E.0 Rule 1*). `Base64.decode`, `Json.parse`
    and `Http`'s heads are Ernest around a primitive, and a head is read on from the line under
    way, so its lines are not read again. `roff` stays in `libs/markdown`, since `ern doc --man`
    lays its pages out with it as §11.4 says, beside `tools/manual.ern` (principle 2).
15. **What a lambda's reach finds on a peer**, feedback 217, done 2026-11-08 (§4.6, §8.7, §11.2,
    §12.7; the log's *What a Lambda's Reach Finds on a Peer*, *A Top-Level Binding Stays the
    Node's*, *The Shell Attaches as a Program Spawns* and its *Built*). The shell's code crosses
    to the node it attaches to as a program's does, and a node of another release on the floor
    runs it; `Ansi.clearBelow` and `Ansi.clearScreen` are literals. The first attach to a node
    took about three seconds on nike, the node compiling the shell, until item 28 had a node hold
    the shell of its own build.
16. **Relative names**, feedback 204, done 2026-11-09 (§4.2, §11.1, §11.2, §11.5, Appendix F;
    the log's *Relative Names* and *Relative Names, Built*). A qualified name resolves from the
    writer's namespace outward and is written in its shortest resolving form, a taken namespace
    is refused as a segment at any depth, and a module is recompiled, by the build and by
    `:reload`, where a qualified name of its source would now resolve elsewhere.

    The three other repositories take the rule at their floor's rise (MVP 4.4's item 4), each by
    its own session, since a program's sources are its own session's (`docs/clean_room.md`): a
    name written longer than its shortest form written short, and no module named as a taken
    namespace at depth. On 2026-11-09 none of the three holds either, ernest-httpd's 13 modules
    standing flat under `src/`, so each builds under the rule as it is; Ernest's session tells
    them the rule at the milestone's end all the same, and each session puts it in its own
    `docs/plan.md` as an item of its floor's rise, where it is checked.
17. **`or` inside a pattern**, done 2026-11-08 (§5.10, §11.5; the log's *An `or` Stands Between
    Patterns* and *An `or` Inside a Pattern Refused*). The parser refuses it at the alternatives
    it joins, and in a clause its help writes the clause's alternatives out whole.
18. **A node's own processes at a full table**, done 2026-11-08 (§11.2, §12.5, E.18, E.21, E.27;
    the log's *A Node's Own Processes at a Full Table*). A socket's closer is made with the
    socket, the gateway's worker for a peer as the connection opens, and a peer's restart is
    waited for in the worker. An arrival, a checker and the shell's input at a full table each
    answer `error:system_limit`.
19. **A keys read that fails**, done 2026-11-09 (§12.1, §12.3, §11.8; the log's *A Terminal That
    Is Gone*, *A Terminal That Is Gone, Built*). Keys the host can no longer read, their read
    failing or answering the end of input, end the program by the hangup's signal, and a shell
    on a node, whose hangup is a reload, says that its terminal is gone.
20. **The runtime at the host's limit of descriptors**, done 2026-11-08 (§12, E.18, E.23; the log's
    *The Runtime at the Limit of Open Files*). A run loads at its start the toolchain's own Erlang
    of the run's side with the host's modules it calls, a unit loads with the modules it calls, and
    TLS loaded whole at its first request, which item 36 turned; every request at the limit answers the host's refusal.
21. **A process a fix leaves out of reach**, done 2026-11-09 (E.28, §6.5, Appendix H; the log's
    *What `running` Finds*, *What `running` Finds, Built*). `Code.running(f)` finds the
    processes of a definition of `f`'s name whose mailbox type is `f`'s, on any version the node
    holds, so a fix in a loop's reach or its body leaves its old processes found, and the guides
    and the tour teach the changed message type as the limit.
22. **The sockets load on nike**, done 2026-11-08 (the log's *The Sockets Load on One
    Scheduler*). Its steps were the host's socket buffers, kept on each scheduler, and the load
    runs on one, its warm-up and its bound unchanged.
23. **A segmentation fault of the host in the typed programs**, moved to MVP 4.4's item 5 on
    2026-11-08, whose review decides it (the log's *The Items Left Read Again*).
24. **The shell's listing under load**, done 2026-11-08 (E.21; the log's *The Host Says
    Running*). A process that waits is `Running` while the host works in it, as it does in every
    process once code is let go, and the shell's listing tests allow it.
25. **A capture's write-back at the run's end**, done 2026-11-08 (E.24, §8.6; the log's *A
    Capture Written Back at the End*). The run's end tells every capture's collector that it ends
    and waits for it before it flushes the streams, so that what a collector writes back is
    written.
26. **`Float.atan2` at the origin**, done 2026-11-08 (E.9; the log's *`Float.atan2` at the
    Origin*). E.9 states `0.0` at the origin, the host's answer, and ernest-epx's line is
    feedback 236. Its verdict goes to ernest-epx's session at the milestone's end (the log's
    *Both Applications at the Milestone's End*).
27. **A binding an arrival linked to a fault**, done 2026-11-08 (§12.7; the log's *A Top-Level
    Binding Stays the Node's* and *The Shell Attaches as a Program Spawns Built*). An arrival
    links a binding the node holds to its holder, with its value or not.
28. **The first attach on a slow machine**, done 2026-11-08 (§8.7, §11.2; the log's *A Node
    Holds the Shell* and its *Built*). A node holds the shell of its own build of `ern` from its
    start, so a shell of that build attaches with an exchange that ships nothing, and a node of a
    tree whose shell is not built is refused at its start.
29. **What a process that waits holds when a value is let go**, done 2026-11-09 (§10, E.21; the
    log's *The Host Says Running*, *A Waiting Process Collected*). A process that waits is
    collected where the host lets go a value it references, which the deployment guide's §7
    says too, and a test holds the fall and the heap kept.
30. **The shell at a full table**, done 2026-11-09 (§7.4, §10, §12.1, §12.5, E.1, E.17, E.18,
    E.21, E.23; the log's *The Shell at a Full Table*, *A Full Table's Answers, Built*). A
    subscription's fault reports come through a courier made with it, and a request of `Fs`,
    `Tcp`, `Os` or `Terminal` the table of processes leaves no room to serve answers
    `Left(Other("error:system_limit"))`; the shell lives at a full table.
31. **The carrier's acceptor at a full table**, done 2026-11-08 (§12.5; the log's *The
    Carrier's Acceptor at a Full Table*). A node runs the host's TLS distribution through a
    module of its own, `ern_tls_dist`, whose acceptor takes each connection before it makes the
    connection's process, closes one that any step leaves no room for and says so, and at the
    limit of open files tries again once a dial's time has passed.
32. **A dial from a full table**, done 2026-11-09 (§12.5, §11.8; the log's *Lean at the
    Limits*, *A Full Table's Answers, Built*). A node whose table of processes has room for no
    process ends when it dials a peer, its connections lost before the host ends it with
    status 1. `docs/otp_bugs.md`'s 12 is the report, whose filing is the user's.
33. **A program's TLS at a full table**, done 2026-11-09 (§7.4, §12.5, E.18; the log's *A
    Program's TLS at a Full Table*). A `connectTls`, an `accept` over TLS and a `listenTls`
    whose processes the host's TLS cannot start fault their caller with `error:system_limit`,
    where each waited for ever.
34. **A flake of `broken_exchange_test_`**, done 2026-11-09 (§12.7; the log's *The Flake of
    `broken_exchange_test_`*). The test's program spawned again before the bare node had
    dropped its first spawn's exchange, which the second joined; the program now waits until
    the test has seen the drop.
35. **The first request over TLS at a full table**, done 2026-11-09 (E.18; the log's *Lean at
    the Limits*, *TLS as the Host Loads It*). E.18 states that a run's first request over TLS at a
    full table of processes may end the run or never answer, the host's defect in
    `docs/otp_bugs.md`'s 17, whose filing is the user's.
36. **What a run holds for a limit, read again**, done 2026-11-09 (§12, E.18, E.21; the log's
    *Lean at the Limits*, *TLS as the Host Loads It*). The host's TLS loads as the host loads it,
    a handshake at the limit of open files failing, and a socket's closer is made as the socket
    ends, in its writer's room, the connection reset where the table refuses it.
37. **A write to a terminal that is gone**, done 2026-11-09 (§12.1, §11.8; the log's *A Write to
    a Terminal That Is Gone*, *A Write to a Terminal That Is Gone, Built*, *A Write to a Terminal
    That Is Gone, Swept*). A stream that can no longer be written ends the program by the hangup's
    signal where it was a terminal as the job started, and with 141 otherwise, and the shell at a
    terminal writes its screen through the job's own ports, so that it says its terminal is gone.
38. **The host's log handler at a terminal that is gone**, done 2026-11-09 (§12.1, §11.8; the
    log's *A Write to a Terminal That Is Gone, Built*, *The Host's Log Handler at a Terminal
    That Is Gone, Built*, *The Host's Log Handler at a Terminal That Is Gone, Swept*). The
    host's default log handler writes through the job's standard output, `ern_out`'s, which
    writes text as UTF-8 and bytes as they are, so that a warning it can no longer write ends
    the program as §12.1 says.
39. **A pipe into a parenthesized pipe**, done 2026-11-09 (§5.7, §5.1; the log's *A Pipe Into
    a Parenthesized Pipe*). A pipe in parentheses is a value the outer pipe applies and does
    not fill: `x |> (a |> f)` is `f(a)(x)`, where the parser read `f(x, a)` and `ern format`
    failed. §5.7 also says what stands on a pipe's right, operands joined by the operators
    that bind tighter.
40. **Where the host's own warnings go**, done 2026-11-09 (§11, §11.2, §12.1; the log's
    *Where the Host's Warnings Go*). What the host logs as a warning or worse, a job writes
    on standard error as the host formats it, where it stood on standard output among what
    the program wrote. It goes the way the job's own lines go, so a shell of its own shows
    it as a program's standard error, a node writes it whichever process logged it, and
    what was logged before the job's end is written before the job ends. §11 also says
    which of the host's reports are not written.
41. **A flake of `shell_write_terminal_gone_test_`**, done 2026-11-09 (§12.1, §12.5; the log's
    *The Flake of `shell_write_terminal_gone_test_`*). The hangup's reload says its line on the
    shell's screen, a write that ended the shell before or after the test's own. The test now
    runs a shell on no node, in a session of its own that the hangup's signal does not reach;
    the reload's line is a test of its own, and `shell_terminal_gone_test_` takes that line
    before the shell's last or after it.

42. **A compiled module whose atoms the host cannot read**, done 2026-11-09 (§11, §11.1, §11.2,
    §11.5; the log's *A Compiled Module the Host Cannot Read*). A `.erc` whose atom chunk is
    empty, as item 40's reader made one, is no compiled module to every job, as junk is: §11's
    refusal where a job is given it, compiled again where a build finds it as a module's own,
    and refused where it stands for a dependency. A run names a file it refuses from the
    working directory, as §11.5 names one, and writes nothing of the emulator's report of a
    module it could not load, as §11 says. The host's reader raised, `docs/otp_bugs.md`'s 18,
    whose filing is the user's.
43. **A compiled module the host cannot load**, done 2026-11-10 (§11, §11.1, §11.2, E.28; the
    log's *A Compiled Module the Host Cannot Load*). A `.erc` whose code the host will not load
    is no compiled module to a job that loads it or builds its source: `ern build` compiles it
    again, `ern run`, `ern test` and the shell refuse it by its file, and `Code.load` answers
    `Left(Invalid)`, asked as each file is read, so that the answer does not hang on how the
    unit is made. `ern doc`, `Code.hashes` and a build's reading of a dependency take only what
    they read. Decided with the user: the build asks the host's loader of its own modules'
    code, about 10 ms a megabyte of compiled code, by principle 1.
44. **A load past the host's atoms**, found 2026-11-10 by item 43's probe, for an item session
    before MVP 4.15's release (§11.2, §10; the log's *A Compiled Module the Host Cannot Load*).
    A load whose module brings more atoms than the host has room for ends the host, `no more
    index entries in atom_tab`, status 1, and so does the build's check of a module's code,
    where §11.2 says a load past one of the host's limits fails as one the node cannot load.
    §11.2 is to state the host's end, as §10 states exhausted memory, the shape *Lean at the
    Limits* decides, with a test in a host of its own, as `ern_integration_tests` fills the
    atoms. The item decides whether it goes to `docs/otp_bugs.md`.
45. **A flake of `os_signal_after_an_unread_exit_test`**, found 2026-11-10 by item 43's
    `make test-full`, for an item session before MVP 4.15's release (E.23; the log's *A Compiled
    Module the Host Cannot Load*). Seen once in two full runs, `Right(Unit)` where E.23 answers
    `Closed` to a signal to a program that has exited though no read has taken its exit. The
    cause is not found, and the item diagnoses it under `make test-full`'s load. A window to
    read first: the host's kernel closes an exiting process's files before the process can be
    reaped, so the child may say `gone` before the helper can learn of the shell's exit.

Dropped on 2026-11-02, its verdict in the log: feedback 184, a shorter form for a command
started with no input.

## MVP 4.16 (a deadlock's scope and its report, and packages), about a week

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*): two
proposals built before the launch, so that the full review reads them and the launch shows them.
It follows MVP 4.15's release, and the checkout then works toward the launch's minor.

The first three items are the deadlock proposal's,
[`proposals/deadlock/`](proposals/deadlock/README.md), each part named as the proposal numbers
it.

1. **A deadlock's claim given its scope**, Part 2: "A deadlock of the whole program is found" in
   the README's list, `guide/why.md`, the tour's chapter 5 and `docs/design/site.md`; the limit
   stated in Why and guide §5.4; the typed mailbox dropped from Why's argument; the status
   premise named in `docs/design/runtime.md`'s *The look*; and the proposal's programs held as
   regression tests. The log's entry that argues the proposal is written with it. The two claims
   the proposal makes from memory, of Pony's collector and Go's work on leaked goroutines, are
   checked against their documents or cut. It closes on `make test-docs` and the runtime's
   target.
2. **The callee in a deadlock's report**, Part 4: each waiting group's line says on whom it
   waits, a group split by its callee's site. It cuts a restated clause of §8.6, so its sentences
   in §8.6 and §12.4 are read cold, and it is decided the day it is built. It touches the runtime
   and closes on `make test-full`.
3. **Who waits on whom**, Part 3: `Process.Calling` gains its callee, whether a limit ends the
   wait and the moment the call began (E.21); `Process.peer` names a process's peer; and
   `:processes` writes them, with a line for each cycle of calls without limit (§11.2). It
   reports and never faults. It breaks a match on `Process.Calling`, one site here and four in
   ernest-httpd, whose session meets it at its floor's rise. It closes on `make test-full`, and
   `make bench` confirms the call's rows within their noise, before MVP 4.4's item 2 reads the
   cost.

The other seven are the packages proposal's build order,
[`proposals/package_manager/`](proposals/package_manager/README.md).

4. **The report's sentences on a package**: a new section at the end of §11, §11's opening,
   §11.1, §11.2, Appendix F and Appendix G's opening, read cold before the build. The log's
   entry that argues the proposal is written with them. It supersedes in part *Packages*, *MVP
   2.7, the Fetcher, and No Server* and *A Library Is Fetched by Its URL*, and records the
   argument of *A Libs Flag Instead of the Environment* beside the one that won.
5. **The manifest read and the load path**: every job finds `package.conf` in the directory it
   is started in and puts the named packages on its load path, `lib/` filled by hand. The look
   is measured on a job with no manifest before anything is built on it.
6. **`ern build`'s checks**: each named package's claims held against the root's lines, a
   package's `src` and `build` as its roots, and the named packages built in their order. The
   trial's table of refusals is its first test.
7. **`Crypto.sha256`, and libraries over the host's gzip and tar**, each an E.0 reading and its
   section of Appendix G first.
8. **`ern unpack`**, in Ernest, over the three: an archive's digest checked against its line,
   and the archive unpacked whole or not at all, one with an entry outside its own directory
   refused. Where the job's module stands under `Ernest` is decided as the item opens.
9. **The guide's section on a package.**
10. **The other repositories**, with MVP 4.4's items 4 and 5: at its floor's rise each takes its
    manifest, ernest-template first with its Makefile cut, and ernest-epx's release carries its
    host part as the proposal's question 5 says.

## MVP 4.4 (the cost, the full review and the launch's release), about three weeks

Decided with the user on 2026-10-31 (the log's *MVP 4.4, the Road's End*): the road's last
milestone before a program, so that the review reads a language that ernest-httpd,
the website and the operator's prompt have used. After it the road is a program's.

Its release is the next minor of 0.x, decided with the user on 2026-11-05. 1.0 has no date: it
comes when someone outside this project depends on Ernest, so that a break would cost them
something (the log's *Ernest Stays at 0.x*, which keeps what 1.0 will promise).

1. **The promise**, dropped 2026-11-05 (the log's *Ernest Stays at 0.x*).
2. **The cost.** The fault row made readable first, a median over runs with more iterations,
   since its spread in one run is half its value (the log's *The Release Review Before 0.7.0*,
   *The raise's rise is noise*). Then the bench whole, idle, and each row above a fraction of the
   host's read: by design, a message §10 states and the log argues, with what it buys and the rate
   at which a program feels it; or a defect, the fault's report at 36 times the host the one
   candidate, whether the trace is taken at the raise or when a line is written. The verdicts and
   rates are one log entry and the rules a section of the runtime's design note beside how it
   keeps its books, `why.md`'s cost claims held to them; read before the review.

   A `match` guard that calls a function, feedback 235, is read with them: it compiles into a
   chain of closures, which cost `Base64.decode`'s loop about four times the host where the same
   test in the body cost 1.4 to 2.3 (the log's *The Libraries' Shims Read Against E.0 Rule 1*).
   The emitter compiles it so that a loop pays the call alone, or §11 states the cost.
3. **The raise a primitive catches**, `ern_json:decode` among them, whose cost grows with the
   caller's stack, 0.4 microseconds on a shallow stack and 110 at 100,000 frames, the trace's
   capture (found 2026-11-01; the log's *The Four Libraries*): read in erts and taken to
   `otp_bugs.md`, or decided against the trace `backtrace_depth` keeps.
4. **The full review**, as `docs/reviews/full.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says, the batches' sentences read cold before the build.

   Before its readers start, `tools/paragraphs.sh`, `tools/comments.sh` and
   `tools/unicode_width.escript` are weighed against CLAUDE.md's *Shims*, each written in Ernest
   or its reason to stay stated (the log's *The Layout's Proposal Read*).

   Before them too, `docs/soundness.md`'s section 7 is recut, decided 2026-11-07: its paragraphs
   cut at their turns and ordered by claim, not by the history of the rules that wrote them, and
   section 1 naming the two claims it argues beyond the four, that no process runs after the end
   and that a process's code stands while it runs, with no paragraph's content changed, so that
   the cold reader reads the argument and not its history (the log's *The Argument Recut*).

   Beside it, on the user's word, ernest-template, ernest-epx and ernest-httpd are each reviewed
   whole by their own sessions, by the `docs/full_review.md` each took at the layout's stop, against the archive of the
   commit the readers read; ernest-httpd's review has a security reader, since it goes public at
   item 6. What they find of Ernest's comes as lines of their feedback files and is sorted in this
   round (the log's *The Applications' Full Review*, *Ernest Stays at 0.x*). As they begin, the
   three floors rise to the launch's minor, each by its own session, since a development build of
   the floor is what an archive before the release is (the log's *The Floors and the Releases*).
   Each takes its manifest then (MVP 4.16's item 10).
   Ernest's session names the minor, the archive's path and its commit to all three by a message,
   and asks for the reviews, on the user's word.
5. **The launch's release**, the next minor of 0.x, by `docs/reviews/release.md`'s step, on Linux:
   macOS unverified and said so in the README's installing sentence and the note, which also
   says that the installed layout changed, for a script that points inside an installation (the
   log's *The Layout Built*); the feedback file and the findings file empty.

   The same week, in this order, each by its own session on the user's word: ernest-template's
   release, since the others copy from it; ernest-epx's, not waiting for its milestone 9, and
   carrying its host part as a package's (MVP 4.16's item 10); and
   ernest-httpd's, with its readers (the log's *The Floors and the Releases*). Ernest's session
   tells all three the tag by a message, and asks each in turn when the one before it is out.

   The release review decides the segmentation fault of the host in the typed programs, moved
   from MVP 4.15's item 23. On 2026-11-07, one run of `make test-full` on nike ended in a
   segmentation fault of the host in `make -C test typed`, after 30 seconds. No core was kept,
   and a host that dies prints no seed. The fault did not come again in 172 runs of the target,
   up to 24 at once with fixed seeds, nor in three runs of `make test-full`. Ernest loads no
   native code into the host, so the fault is OTP 29's (erts 17.1.1).

   The target runs with core dumps on, so the next fault leaves its core in `test/`. That core
   is read with `gdb` and its stack goes to `docs/otp_bugs.md` and to the OTP team. Where none
   comes by the review, the review decides whether the watch stays.
6. **The site live at ernest-lang.org**, last, so that each project it lists builds on the release
   it names, moved from MVP 4.2 on 2026-11-04 (the log's *The Site
   Goes Live With 1.0*), and with the launch's release since 2026-11-05 (the log's *Ernest Stays
   at 0.x*): `make site` from that tag, the copy of `build/site/` to the host, and
   the smoke test against the live site. The Website of the repository's About is the address
   already (the log's *The Release Cleanup*).

   Before it, the generator writes `/robots.txt` and `/sitemap.xml`, the second naming
   ernest-lang.org alone, which the site's proposal decided and MVP 4.2 did not build (the log's
   *The Site's Proposal Read*); `docs/design/site.md`'s *The root* lists them then.

   ernest-httpd rehearses the switch on the machine,
   under a second unit on scratch ports, with the archive of MVP 4.15's release, so that the
   switch at the launch swaps one archive for another on a path already walked; then, with its
   release of item 5 made, it switches once, the machine serving its one page meanwhile. Its container with its two nodes was built 2026-11-04 on the archive
   from 612faac8: caps of 128 processes and 128 MiB, and one core, the user's choice from its
   measure, 3.2 s from start to the homepage's example answered against 6.7 s at half a core.

---

## MVP 4.5 (`:trace f`), about a week, after the launch

The shell's second round, decided with the user on 2026-09-30 (the log's *The Shell's Second
Round*) and decided again on 2026-10-30 against the attached shell (the log's *The Shell's Second
Round, Decided Again*): of its eight items one remains, three moved into MVP 4.0's shell, where
the operator's prompt is, and four were dropped with their verdicts in the log.

1. **`:trace f`**, a proposal first: each call of `f` on the node and each return printed at the
   operator's prompt, the values by their descriptors (§11.2), with a bound a busy node needs, as
   Erlang's `recon_trace` has one; the runtime has no tracing hook today, so the design decides
   how a function of a unit is traced by its position and what the bound is. Built after MVP 4.0,
   on the node.

It follows the launch since 2026-11-05 (the log's *MVP 4.3 Becomes MVP 4.5*).

---

## MVP 4.6 (the server owns both ends of its socket), a few days, after the launch

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*), the
proposal [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md). The site's script speaks
the server's wire, its generator reads the server's configuration and its browser test stubs the
server's socket. Each goes, for a client the server ships.

1. **The ask**, sent to ernest-httpd's session by a message on the user's word, as
   `docs/clean_room.md` says: a client script served at `/shell/client.js`, the limits the server
   enforces, a client that is never stale, and its own test. The server's part adds and takes
   nothing away, so the site that went live at the launch is served on.
2. **Ernest's side**, once a release of the server's serves the client on the machine. `site.js`'s
   session calls the client. The generator takes no configuration, and `make site` the tag alone.
   The shell's page takes its numbers from the client's limits and names no memory. The browser
   test serves a stub client. `docs/design/site.md` changes in five sections, with the sweep the
   proposal lists. It goes live with the site of the release that follows, and closes on
   `make test`, the site's targets and `make test-browser`.

---

## Milestones

| | What | Done | Release | Where its reasons are |
|---|---|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | 2026-09-18 | commit `7913df85` | the log's entries of 2026-09-17 and 2026-09-18; [`architecture.md`](architecture.md) |
| MVP 2 | the rest of the report on one node | 2026-09-19 | | the log's entries of 2026-09-19 |
| MVP 2.5 | a complete standard library | 2026-09-20 | | *The Erlang Standard Library, Read for Ernest*, *Fs by Its Structure, and the Table*, *One Token for the Project* |
| MVP 2.9 | an Emacs major mode | 2026-09-23, out of order | | [`emacs_mode.md`](design/emacs_mode.md) |
| The report read as a Wirth report | the report read against Wirth's register and §0, about thirty issues decided one at a time | 2026-09-23 and 2026-09-24 | | the log's entries of those two days, one an issue |
| MVP 2.61 | the guide as the user's document | 2026-09-24, out of order | | the log's entries of 2026-09-24 |
| MVP 2.6 | the shell | 2026-09-25 | | [`design/shell.md`](design/shell.md); the log's entries from 2026-09-20 to 2026-09-25 |
| `libs/markdown` | a CommonMark renderer, now under MVP 4.1 | 2026-09-25 | | Appendix G.2 |
| The code read back after the shell | every line of Ernest and Erlang read for the principles, clumsiness and defects | 2026-09-25 | | *The Code Read Back* |
| MVP 2.65 | the language and the toolchain read back | 2026-09-26 | | *The Report Read Cold, Its Plain Half* to *The Closing of Step 10*; the log's entries of 2026-09-25 and 2026-09-26 |
| MVP 2.66 | the standard library's `Supervisor` | 2026-09-27 | | *No Remote Computation in the Language*, *A Sibling Restarts at Its Next Wait*, *The `Supervisor`'s Shape* |
| MVP 2.8 | the formatter | 2026-09-28, out of order | | *What the Formatter Keeps*, *Layout for the Reader*, *Format on Save*, *The Formatter Before the Release* |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | 2026-09-28 | | *A Program's Command Line Is `Os`'s* to *The Working Directory*, *What the Loads Found*, *The Shell's Code Memory*, *Atoms, Counted*, *Running as a Service*, *The Libraries in the Report*, *Back Pressure, Again*, *What Ernest Adds Stays at Four*, *The Guide Read in Order* |
| MVP 2.95 | manual pages, an installation, the review | 2026-09-28 | | *Manual Pages Named `Ernest.List`*, *`ern(1)` Is §11*, *What Building the Manual Pages Found*, *`bin/ern` Is a Launcher*, *The Layout Under the Prefix*, *One Archive, Compiled Where It Is Installed*, *A Lean Review*, *The Time of `make test`*, *What MVP 2.95 Takes From the Rest*, *What `Fs` Holds*, *No Mac for the First Release* |
| MVP 2.96 | a result annotation written with `:`, and a process's addresses taught | 2026-09-29 | | *A Result Is Annotated With `:`*, *A Process's Addresses, Taught in Order* |
| MVP 2.98 | what the first review left | 2026-09-30 | | the log's entries of 2026-09-29 and 2026-09-30, *The Report's Cheap Lines* to *`closeListener` Names What It Closes*; `findings.md` as it stood at `b7d34c0`, its readers' lists in its history to `08edfda` |
| MVP 2.99 | a restart begins afresh, and the first release | 2026-09-30 | tag `v0.1.0` | *The First Release Is for Others*, *The First Release Follows MVP 2.99*, *A Restart Begins Afresh*, *`ern(1)` Has Its Sections*, *The Release Review*, *The Release Review's Security Lines* to *The Release Review's Questions* |
| The principles review | the report and the guide against §0, and §0 against what it decided | 2026-10-01, and again 2026-10-09 before MVP 3.1 | | *The Principles Review*, *The Attack Plan*, *The Principles Review Closed*; *The Principles Review of 2026-10-09* and its *Judgments* |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | 2026-10-01 | tag `v0.2.0` | *The Release Review Before 0.2.0*, *A Release After the Review*, *The Release's Pages in `man/`* |
| MVP 2.99b | what the release review left, names that read among it; operations records: the requirement `needs a.compare`, a record filled from a namespace, an ordered set and an ordered map; running as a service | 2026-10-03 | | *The Erlang Read and Renamed*, *The Ernest Read and Renamed*, *The Requirement Built*, *MVP 2.99b's Questions, One by One*, *`Address.ask` Is Taken Out*, *The Operators Stay Ernest*, *The Hardening Built*, *The Runtime as a Service, Built*, *The Service Manager's Checks*, *The Reaper's Look at Rest*, *The Boundary Trusts a Type Variable*, *The Report in Three Files*; `findings.md` as it stood at `d6996f1`; `docs/proposals/operations/` as it stood at `42a51d22` |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | 2026-10-05 | | *The Full Review Run*, *The Full Review's Questions, One by One*, *A Release Carries No History*; `findings.md` as it stood at `0d2de61` |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | 2026-10-05 | tag `v0.3.0` | *The Language Argued Before Peers*, *The Grammar Generated Against*, *The Library's Laws Held*, *The Typed Programs Generated*, *The Replies Generated*, *The Type System Argued*, *What Erlang Held, Moved*, *The Release Review Before 0.3.0*; [`soundness.md`](soundness.md) |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | 2026-10-05 | tag `v0.3.1` | MVP 2.99d's entries |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | 2026-10-06 | | *MVP 2.99d's First Measurements*, *The Prelude Measured*, *The Library Stands on the Host*, *The Emitted Code Measured*, *Spawn Keeps Its Wait*, *Kept Only for Speed, Taken Out*, *Fs.removeAll Removed*; [`otp_bugs.md`](otp_bugs.md) |
| The shell shows a bracket's match | a closing bracket stands the cursor on its match, ahead of the shell's second round | 2026-10-06 | | *The Shell Shows a Bracket's Match* |
| MVP 3.0 | peers: one program on several nodes, by its proposal | 2026-10-09 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Carrier*, *Addresses, Messages and Monitors Across Nodes*, *Calls Across Nodes*, *A Node's End and Its Reload*, *The Module Peer*, *Load and Balancer*, *The Module Json*, *The Tests Wait on What They Mean*, *The Milestones After 3.0, Weighed Again*, *The Plan Rewritten from the Split Proposals*, *MVP 3.0's Findings Decided* |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing`; then a read of what it built | 2026-10-10 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Canonical Form, Built*, *The Code Table, Built*, *The Spawn by Hash, Built*, *The Shell's Reload by Hash, Built*, *Termination Told, Built*, *Standing and the Refusal, Built*, *What MVP 3.1 Costs, Measured*, *MVP 3.1 Read*, *MVP 3.1 Done*, *The Feedback Pass Before MVP 3.2*, *A Milestone for Placing Work by Load*, *The Back End Last* |
| MVP 3.25 | placing work by name: `Peer.compute` on a named peer, `Peer.utilization` with the node's measure its maintainer's, and `Placement` in `Balancer`'s place | 2026-10-11 | | *The Placement Proposals Swept*; *Placing Work by Name* |
| MVP 3.26 | kill darlings: the reply's obligation and `!` gone, `receiving M` in place of `with M` on a function that receives alone, the value restriction relaxed for data, the held replies gone, and the guide's *A library that waits* | 2026-10-16 | | `docs/proposals/kill_darlings/` as it stood at `42a51d22`; *Kill Darlings*, *§0 Read Again* |
| MVP 3.2 | code with a spawn: the exchange, the bare node, every unit held for the node's life, and `Code`; then a release, Ernest 0.4.0, the first with nodes | the code by 2026-10-15; the release 2026-10-18 | tag `v0.4.0` | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; *The Feedback Pass Before MVP 3.2*, *The Typed-Channels Example*, *The Service Named*, *Names Read as a Newcomer Reads Them*, *The Report for Code with a Spawn*, *Placing Work by Name*, *American English Throughout*, *The Pages Written From `main`*, *Pages Written Where Out of Date*, *The Tools Measured*, *The Tools Measured Again*, *The Repository Laid Out Again*, *The Layout Completed*, *Tables in `libs/markdown`*, *The Programs Tests' Bounds*, *The Design Notes Leave the Proposals*, *The Examples Are Programs*, *The Runtime's Own Processes*, *The Shell on a Private Type*, *Before the Tag, the Last Builds*, *Ernest 0.4.0 Ends MVP 3.2*, *The Release Review Before 0.4.0* |
| MVP 3.27 | measured across machines: the exchange's numbers of 2026-10-13 again between three machines on one LAN, the push against the pull across them, the spawn's end at the reaper and the bench's three other rows that grew measured piece by piece, every fault with a trace, the programs tests' limits derived, and the annotation out of the hash | 2026-10-21 | | *The Numbers Across Machines*; *The Machines*, *The Numbers Across Machines*, *The Rows That Grew*, *Every Fault Carries a Trace*, *The Nodes Tests' Bounds*, *The Later List Sorted*, *The Annotation Out of the Hash* |
| MVP 3.28 | what stands before the tour: a clause's body all or none, which §11.6 states and `ern format` writes; `--libs-dir dir`; `--verbose`; and seven items the feedback left: four messages that name the form, the rules of an Ernest program installed, the libraries on the default load path, `ok` as `Unit`, `Test.faults`, the foreign call measured, and doc examples run by `ern test`; with what the builds found: a type and the module of its name share a namespace, a module under a taken namespace refused, `List.mapFold`, a mailbox type ending in `Msg`, the prelude's `Unit` as a descriptor word, a `make` with nothing to do measured, and each doc example a program of its own in a directory of its own | 2026-10-22 | | *The Later List Sorted*; *Clause Bodies All or None*; *A Libs Flag Instead of the Environment*; *A Build Says What It Decided*; *A Make With Nothing to Do*; *What the Feedback Left*; *The Window's Three Asks*; *Nothing Waits for a Program*; *The Foreign Call Measured* |
| MVP 3.29 | the bookkeeping behind §8.6 on one rule, the look reads what a process marks and no operation writes a shared row: the foreign call's count gone for a read of the waiting process, the timed receive's and the call's marks in the process's own dictionary, every slow wait of the runtime's own marked and held by a test, the callees' row kept on a write-concurrent table and measured against two other kinds, a kill one function and a frame from another node; a ground `let` compiled to its term; the foreign cause naming the function; one checker of the library's examples; a launch a row of its own table, halved; the runtime's fixed waits and the tests' sleeps, polls and limits gone for waits on what each means; `make bench` with a memory of its last run and of the release's, by ratio; the language measured against the host's own Erlang, construct by construct and in three programs written twice; the runtime's design note; and a deadlock found among *Why Ernest*'s claims | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*; *`make bench` Read Against the Cost Rules*; *The Language Against the Host*; *The Foreign Call Measured*; *Deadlock Is Quiescence* |
| MVP 3.295 | what the language measurement found: a `Float` operation the host's own with no `try`, the runtime reading a `badarith`'s frame, a chain of five from 1.65 to 1.23 times the host's and the ray tracer from 1.95 to 1.70; `Map.get`'s number closed as the type's; and the bench's parts as targets, its memory kept a table at a time | 2026-10-22 | | *The Sitting on §8.6's Bookkeeping*, its paragraphs *The Float chain* and *Built*; *The Language Against the Host* |
| MVP 3.296 | what the tour's outline asked: a restart runs the function it was given, stated in §6.9 and the deployment guide, with the guide's sentence that a binding is its node's own; `ern config --listen` and `--peer-dir dir`; the Erlang and the Gleam programmer reading `why.md` and `faq.md`, and every guide read for a word used before it is said; two messages the tour's spike found wanting; and the runtime's own frames out of a designed fault's trace | 2026-10-23 | | *What the Outline Asked*, *Two Nodes on One Machine, Built*, *The Skeptics' Read*, *What the Skeptics Found*, *The Hash's Parents*, *Two Messages, and the Runtime's Frames Weighed Again*; `findings.md` as it stood at `fd5b361c` |
| The full review's findings before 0.5.0 | the 218 lines of the review run over `1329d1d2`: 159 `fix` made in ten batches by area and an integration pass, 52 `decide` taken one at a time, 9 dropped; the service monitor and `demonitor` added to the language, `Reply.process` and `compare` over tuples, lists, `Optional` and `Either` to the library, each with its page and its test | 2026-10-24 | | *The Review's Fixes, First Round*, *The Runtime's Note States No Why*, *The Review's Decisions*; `findings.md` as it stood at `08997105` |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program, the counter, grown through eight chapters from a process with a typed mailbox, through the same counter on a peer that holds none of its code, to its move to new code there, where the deployment guide takes over; with it a README for `report/` and for `guide/`, the README's three ways in, the guide's taste of the rest, and the path read by a fresh reader and the two skeptics | 2026-10-24 | | *The Tour*, *The Tour, Shorter*, *What the Outline Asked*, *The Skeptics' Read*, *What the Skeptics Found*, *The Tour's Programs, Built*, *The Tour Written*; the outline, `docs/proposals/tour/` as it stood at `688ffa03` |
| MVP 3.9 | the review, and Ernest 0.5.0: the nodes' and the code's design notes, the proposals built by then swept, the full review and its findings, the process-only mark narrowed and a wrap's `self` its recipient's, what the lease broker found, the release review and Ernest 0.5.0, a release with no promise of stability | 2026-10-25 | tag `v0.5.0` | *MVP 3.9 Weighed*, *The Nodes' and the Code's Notes*, *The Design Notes Leave the Proposals*, *The Full Review Before 0.5.0*, *The Review's Fixes, First Round*, *The Review's Decisions*, *The Process-Only Mark Marks a Wait*, *A Wrap's `self` Is Its Recipient's*, *Two Nodes Tests Take the Fault's Line*, *One Name for Every Order*, *The Shell's End Writes What It Was Told*, *A Restart Empties Before It Tells*, *A Member Has One Face*, *The Release Review Before 0.5.0*; `findings.md` as it stood at `105fb3fc` |
| MVP 3.95 | what the review and 0.5.0 left: the release review read back, a restart told across nodes by the runtime's own frames, the harness counting a test's steps, the review round's method with an owner, the site proposal's sitting, the first fault's cost measured, the member regime's missing test, the teller's late delivery closed, dialyzer in the full run, and Ernest 0.6.0, the protocol's version moved | 2026-10-25 | tag `v0.6.0` | *The Release Review Read Back*, *A Restart Told Across Nodes*, *A Restart Told Across Nodes, Built*, *The Report's Readers Read the Diff*, *The Teller's Late Delivery*, *The Teller's Late Delivery, Built*, *The Harness Counts a Test's Steps*, *The First Fault's Cost*, *The Review's Decisions*, *A Member Has One Face*, *The Report Pared After 0.6.0*, *The Release Review Before 0.6.0*; `findings.md` as it stood at `c6eab569` |
| MVP 3.96 | the report pared to the language, `language.md` holding what decides what a program means and the runtime's mechanism chapter 12 of `toolchain.md`, and what the paring found: the build's cost per function linear, one function per initializer, the nested group's third restart, the newcomer's feedback decided, the second cut to E.27, the comments' paragraphs, the emitter's calls as the host's, `<-` at the prompt and `Test.until` | 2026-10-30 | | *The Report Pared After 0.6.0*, *The Report Pared, Built*, *The Build's Cost per Function*, *One Function per Initializer*, *The Nested Group's Third Restart*, *What the Newcomer's Feedback Left*, *The Second Cut, §8.7 to E.27*, *The Comments' Paragraphs*, *The Emitter's Calls Against the Host's, Built*, *Small Library Functions Stay Calls*, *`<-` at the Prompt*, *`Test.until`, Built* |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches, its proposal `docs/proposals/shell/attached.md` as it stood at `facbd285`; and the release review before 0.7.0, eight readers over what changed since 0.6.0, its fix lines and its eight batches decided and built | 2026-10-31 | tag `v0.7.0` | *The Attached Shell's Cut*, *The Attached Shell's Sentences*, *The Session's Screen and the Toolchain's Units, Built*, *The Attached Shell, Built*, *The Guides Over the Attached Shell*, *The Attached Shell, Tested*, *The End's Lines Reach the Screen*, *A Line-Mode Input's Cost*, *The Attached Shell's Last Row*, *The Attached Shell's Own Node, Quiet*, *An Expression's One Unit, and an Input's Cost Flat*, *The Detach Keeps What Declares a Function*, *The Release Review Before 0.7.0*, *The Release Review's Code Fixes*, *The Argument's Four Decisions*, *Sites, Sessions and Their Names*, *The Input's Process*, *One Word to Leave*, *The Shell's Own Node*, *Reload, Services and Tests*, *The Library's Lines*, *The Claims, the README and the Tour* |
| The pun | a field given or matched by the variable of its own name written once, `Desk(=local)`, swept over 874 sites with the style test holding it; the round that opened it, ten feedback lines decided and three rules built, a guard's field read, the shell's line by site, and the timed wait's effect, superseded the same day by a `receive` that always receives and `Clock.sleep`; an alarm that can be canceled; `make version`, Appendix D whole, the settler's restart tested, the guide's lines after the release review read; the three outside programs on floor 0.8 | 2026-11-01 | the release after 0.7.0 | *The Pun*, *The Pun's Opening Round*, *A `receive` Always Receives*, *An Alarm Can Be Canceled*, *`make version`, Appendix D Whole, the Settler's Restart*, *The Guide's Lines After the Release Review* |
| Ernest 0.8.0 | a small release, the pun's: a doc example run at its own mailbox type, a census of forms over the repository's Ernest, a one-field request's reply declared positional and passed bare, and the release review before it, 92 findings | 2026-11-01 | tag `v0.8.0` | the log's *Ernest 0.8.0, a Small Release*, *The Release Review Before 0.8.0* |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, which serves ernest-lang.org since 2026-11-02, and what it asked of Ernest: TLS in `Tcp`, a program under a pseudo-terminal in `Os`, the libraries `base64`, `crypto`, `time` and `http`, seventeen lines of feedback decided the days they came, the terminal tests' harness in Ernest, and the release | 2026-11-03 | ernest-httpd 0.1.0, tag `v0.1.0` in its repository; Ernest 0.9.0 | the proposal `docs/proposals/httpd/`, gone with this row, the server's own at https://github.com/joagre/ernest-httpd/blob/v0.1.0/docs/proposals/basic/proposal.md; the log's *TLS in `Tcp` and a Terminal in `Os`*, *WebSocket Is the Server's*, *The Four Libraries*, *A Path Through a File*, *Three Lines From the Server*, *No Numbered Variables*, *A Close, an Exit and a Write*, *An Archive Says Its Commit*, *Two Lines on TLS*, *A Program After Its Exit*, *Four Lines From the Deployment*, *What the Server Taught*, *The Hangup's Order*, *The Error's Place*, *The Harness in Ernest*, *Three Flakes Read* |
| Ernest 0.9.0 | the server's release: what ernest-httpd asked of Ernest, and the release review before it, 112 lines fixed and 23 decided | 2026-11-03 | tag `v0.9.0` | the log's *The Release Review Before 0.9.0* |
| MVP 4.2 | the website, built and live with MVP 4.4's item 6: what Ernest is, its characteristics, the three doors, the tour, the guide, the report and the library's pages, generated from a tag by `make site`, the projects' page, the live shell's page side, and the browser test that holds it | 2026-11-06 | | the design note `docs/design/site.md`; the log's *ehttpd and the Website*, *The Tour Written*, *The Generator Before MVP 4.15*, *A Node's Limits*, *The Site's Look, by Hand*, *The Generator's First Stage*, *The Generator's Second Stage*, *The Generator's Third Stage*, *The Pages Read Against the Principles*, *A Release Carries No History*, *The Start Line's Length*, *The Client's Questions*, *The Site Goes Live With 1.0*, *The Mode's Brackets*, *Projects, a Page of Their Own*, *The Browser Test's Flake*, *The Site's Proposal Read* |
| MVP 4.16 | a deadlock's scope and its report, and packages | | | above |
| MVP 4.4 | the cost analysis, the full review and the launch's release, Linux | | | above |
| MVP 4.5 | the shell's second round | | | above |
| MVP 4.6 | the server owning both ends of its socket | | | above |
