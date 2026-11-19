# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log/`](log/README.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone
ends the file. A gap stands in the milestone whose item closes it, a defect of OTP's in
[`otp_bugs.md`](otp_bugs.md), and a feature declined in a dated entry of the log; nothing stands
between.

---

## Where we are

**Ernest 0.10.0 is the last release**, of 2026-11-10, and the checkout works toward 0.11.0. The
table's rows for MVP 4.15 and Ernest 0.10.0 say what it holds. No promise of stability is made,
and a change to the language, the standard library or the libraries is driven by a need met in
use and recorded as `docs/language_feedback.md` records one. Ernest stays at 0.x until someone
outside the project depends on it, as MVP 4.4's opening says.

**The next item is MVP 4.16's item 115**, a `monitor` in an adapted address's function.

The milestones to come, in order: MVP 4.16, MVP 4.17, MVP 4.6, MVP 4.4, whose release is the
launch, and MVP 4.5 after it. Each section's opening says what the milestone is and names the
log entry that placed it.

**A line stands before MVP 4.4**, drawn on 2026-11-19 (the log's *The Line Before the
Launch*). A sentence of the report that a program shows false is mended before MVP 4.4, by a
narrower sentence first. A reading not yet made, a cost, a question where the report is true
and a report against OTP stand in MVP 4.5. Each new item is judged against that test when it
is written into the plan, and its paragraph says which side it stands on and why. One that
goes to MVP 4.5 keeps its date and its fix's shape.

---

## MVP 4.16 (a deadlock's scope and its report, a package's manifest and build, the flake hunt, and what its builds and the outside reviews found)

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*): two
proposals built before the launch, so that the full review reads them and the launch shows them.
It follows Ernest 0.10.0, and the checkout then works toward the launch's minor. Its item 11,
the flake hunt, stands apart from the two.

Split with the user on 2026-11-14: the rest of the packages proposal, items 7 to 10, 23 and
43, is MVP 4.17's, each under the number it had here (the log's *The Milestone Split*).

### What is left

Each item left stands alone. The items stand below in the order they are taken, in three
groups. The groups' order was decided with the user on 2026-11-15 (the log's *A Status Read
Before the Watch*, its paragraph *The order of what is left*): what the builds found, then
what needs the user. An item planned since stands where its group's sentence says.

Six items moved to MVP 4.5 on 2026-11-19, each under its number: items 68, 96, 103, 113, 118
and 122. Item 123 moved to MVP 4.4's item 2 the same day (the log's *The Line Before the
Launch*).

**What was found**, each item begun by an agent that shows it or tests it.

- **115. A `monitor` in an adapted address's function, and a help that leads to a second
  refusal**, found 2026-11-18 by item 111's build (the log's *A Checker Acts for the
  Target*). §6.5 says whose a `monitor` in `f` is. `adapted` takes a function that receives
  nothing, and the type checker refused a `monitor` in the agent's lambda. Its help says to
  give the lambda its mailbox type, and the lambda so written is refused again, since a
  function that receives and one that receives nothing do not match. An agent shows both
  first: whether any program can write a `monitor` in `f`, and the help's two texts. What
  changes, §6.5's sentence or the type checker, is then decided with the user. Where it is
  the type checker, MVP 4.4's tabling of the checker's cases comes first, as its item 4
  says of a checker item.
- **120. A termination ends the subscribers' wait where a stream is stalled**, found
  2026-11-18 by item 117's probes (the log's *A Termination Ends a Stalled Flush*, its
  paragraph *The subscribers' wait*). A plain run with standard output stalled and a
  subscriber that never answers was alive after three terminations, where §8.6 has a
  termination once the end has begun end the program at once. The termination that cuts
  the wait has the runner say `the end was cut short`, and that line waits on standard
  error, which is held behind standard output.

  The shape, decided with the user: the runner records that it took a termination, and
  the next termination kills the writers, as item 117's does. The line is kept wherever
  nothing stalls, and a run that is stalled needs one more termination. Whether §11.2
  says so is brought to the user at the item's cold reading.

  An agent shows first whether the line that says whom the end waits for holds the same
  way. It also shows what item 117 left: the shell's end at once, `ern test` after a
  launch ended so, and an `Os.exit` during the flush.
- **124. A node's end says `Unreachable` of a process that waited in a send**, found
  2026-11-18 by item 121's probes (the log's *A Down Follows the Send*, its paragraph *A
  node's end, found beside it*). A desk's program ended while two of its processes waited
  in a `send` to a store that stood still. Once the store ran again, the watchers on the
  store and on a third node were told `Unreachable` of one sender or both in 2 runs of
  4, and the store took none of their messages. A fault the runtime found in the entry
  process while it waited so gave `Unreachable` and never `Fault`, 3 runs of 3.

  §8.7 says that every `Down` already on its way crosses before the node's connections
  close, and that a peer's monitor gives `ProgramEnd`. By a reading, the node ends before
  a sender's exit has placed the rest of its message, and the host says such a process
  is gone while its exit still waits. An agent diagnoses it first. What it finds is
  brought to the user: whether the node's end can wait for those exits, or §8.7 says
  what a peer is told of a process that ended so.

  The narrower sentence is weighed first, and a question with it: whether one sentence of
  §8.7 on a peer that stands still and is not yet lost answers this item and MVP 4.5's
  item 118 together (the log's *The Line Before the Launch*).

  The agent makes item 118's showing in the same run, decided with the user on
  2026-11-19. The ending node pings each connected peer once it has told it of its end,
  so a store that stands still holds the node in item 118's window. The agent records
  what a listed peer that dials then is told, what its sends and its monitors meet, and
  which reason the node's exit gives it. A sentence that showing finds false is mended
  with this item, and the rest stays item 118's.
- **125. A disconnect that waits on no connection**, found 2026-11-19 by item 108's
  reading (the log's *What a Peer's Worker Waits On*). `erlang:disconnect_node/1` holds
  the host's `net_kernel` until the connection's controller has taken its exit, and over
  TLS the controller reads nothing while its socket is full. A node calls it at a reload
  that removes a peer, at a frame it cannot read and at the peer limit's refusal. With a
  peer stopped and its connection full, a reload that removed it left the node deciding
  no loss. It held another peer's worker, a termination and that peer's departure, until
  the stopped node ran again.

  The fix's shape, decided with the user: the three sites call
  `net_kernel:async_disconnect/1`, which sends the same exit and does not wait. Its
  documentation is hidden, and `docs/code_style.md`'s *Shims* names its use with the
  build. An agent builds it against the reading's probes, which become its tests: the
  reload, the termination behind it, and the peer really stopped.

  The build shows three things beside it. The first is the gateway's refusal at the peer
  limit under the hold, since the nodes' note says the gateway waits on no peer. The
  second is the line "its connection was ended", said before the disconnect is made,
  which then says what is so. The third is one unconfirmed sighting, shown or dismissed:
  a node whose program had ended, lost as silent by a quiet peer on a sound connection.

  The agent writes the host's behavior as report 26 in [`otp_bugs.md`](otp_bugs.md)'s
  form, reproduced with OTP alone, and the session runs its script as placed. Filing is
  the user's.
- **126. A worker's fault for a third node, and a `find`'s alias**, found 2026-11-19 by
  item 108's reading (the log's *What a Peer's Worker Waits On*). At a full process table
  a worker cannot start the process kept for an adapted address, and sends the fault to
  the address's process itself, which may be on a third node. The host held the worker
  there, and its own peer's `find` went unanswered. The `find` frame answers to the alias
  it names and checks no node, where the `compute` frame does.

  The fixes' shapes, decided with the user: the worker sets the host's `async_dist`
  around that one send, and the nodes' note lists it; the `find` frame takes the
  `compute` frame's guard. An agent builds both, the first against the reading's probe,
  which becomes its test.
- **133. An address given back, on another node**, found 2026-11-19 by item 114's build
  (the log's *The Process Behind a Check, Built*), read from the code and not shown. An
  address of the program's that foreign code gave back at another type crosses to another
  node as it is held. Only the node that made the check can lead from the checker to the
  process behind it. On another node `Process.fromAddress` of it answers the checker, a
  `kill` of that ends nothing, and a fault sent from there reaches the checker as a
  message, where E.21 has `fromAddress` go through every check.

  Read beside it: a check in front of a process of another node, given back at its own
  type, is held as foreign, since that process has no row on this node, where §8.4 has
  it the program's own. What is sent through it is checked again and takes one step
  more.

  By the line's test the first stands here, decided with the user: E.21's line, written
  with item 114, would be shown false. An agent shows both on two nodes first. The fix's
  shape for the first: the held address carries the process behind it. The second is
  decided with the user after the showing, by the line's test.
- **135. A resource's process meets no fault**, found 2026-11-19 by the cold reading of
  item 132's sentences (the log's *A Bad Message's Fault to a Foreign Target*), shown by
  the reader's probe and the session's run. A listener is started by the runtime and has
  no wait of Ernest's. After a fault in `f` and after a bad message through its check,
  each fault stood unread in its mailbox, the listener answered its port, and the run
  ended with status 0. By a reading a socket does the same.

  §6.5 and §8.4 have the receiver fault at the wait that reaches it, and a program with
  no foreign code shows that false, so by the line's test the item stands here. To
  decide with the user at its turn: whether the resource ends at the fault, or the fault
  is dropped and a sentence says so. The narrower sentence is weighed first.

**What is decided and waits for its build** stands between the two. Item 93 and item 95's
first line are taken after item 101, decided with the user on 2026-11-19: each is a
verdict on an order nobody promised, made before item 101's rule, which reads it again.
Item 92 and item 95's other two lines keep their place.

- **92. A wait for a life says so in its name**, decided with the user on 2026-11-17 (the
  log's *Seven Entries of the Feedback*, feedback 255). `Tcp.acceptForever`,
  `Tcp.readForever` and `Os.readForever` wait without a limit, as `Address.callForever`
  does. A write, a connect and a file's call get no twin, since each is a request that must
  be answered.

  The report changes first: E.0 shape rule 8 with its list of the waits without a limit,
  E.18 and E.23. An agent builds the three. `examples/shout.ern`, `examples/web_server.ern`
  and `tools/flakes.ern` take them and lose their clause for a `Timeout`. The same build
  names the time for a file once in `tools/site/run.ern`, `tools/manual.ern` and
  `tools/site.ern`, as `tools/flakes.ern` does.
- **93. A close answers once it is made**, decided with the user on 2026-11-17 (the log's
  *Seven Entries of the Feedback*, feedback 258). `Os.closeInput` and `Tcp.closeListener`
  are sends, and a caller that acts at once after one may act before it. The terminal
  harness did, and a listen on a port right after its listener's `closeListener` was
  refused in 21 of 5,000 rounds of the session's probe.

  Decided: `closeInput` answers `Unit` once the close is made, under a terminal once it is
  hung up and under pipes once the end is placed behind the bytes already written. It takes
  no time, as `signal` takes none, and on a program whose process has ended it faults as a
  read does. `closeListener` answers `Unit` once the listener has ended, and at once on one
  that has ended already. `Tcp.close` stays a send, and E.18 says that it answers before
  the connection has closed.

  E.18 and E.23 change first. An agent builds the two, each with a test that acts at once
  after the close, and the terminal harness's write of nothing goes. The build follows
  item 101, whose rule reads this verdict as one of its seven.
- **95. A shell session that shows more than the report promises**, decided with the user
  on 2026-11-17 (the log's *The Outside Reviews Read*, its paragraph *Three shell
  sessions*). The session writes it, and it closes on `make test`.

  - A send and a call to another node, in two inputs, written after item 101, whose rule
    reads this verdict again. The tour's chapter 2 says that each
    input is a sender of its own, that the report orders one sender's messages alone
    (§6.4), that the page shows one order, and that a program which needs the order sends
    both from one process. The guide's §1.4 gains the same as a clause. The transcripts
    stay as typed, and the README stays as it is.
  - A move shown as done. In the tour's chapter 8 the attached shell's two listings move
    after the lines at `a`'s shell, where a `report` is answered. The deployment guide's
    "Asked again, it finds none" says what it rests on, that the counter has taken its
    `Upgrade` by then.
  - The tour's restart limit. Chapter 4 starts its counter with `within = 3600000`, in
    the text and in `test/ern_tour_tests.erl`, and its sentence on the minute follows.

**What needs the user**, each a design discussion of its own. Item 101 stands first, since
its rule is the measure for item 100, for MVP 4.5's item 68, and for item 93 and item 95's
first line, which follow it. Item 100, ernest-httpd's
session's two lines on a close, follows it, and three of that session's tests wait on it.

- **101. What an order nobody promised gets: no sentence, a sentence, or a mechanism**,
  found 2026-11-17 by a reading of the log's findings at the limits since 0.10.0
  ([`limit_findings.md`](limit_findings.md), its section 3.2; the log's *The Limits Read*).
  Seven times a test of Ernest's own expected an order the report does not give. Three got
  no sentence, two a sentence in the report, and two a mechanism. Each entry gives a reason,
  and none says what tells the three apart: two give the same reader's prediction for
  opposite answers.

  Decided with the user, in a design discussion of its own: the test that tells them apart,
  as one rule of `CLAUDE.md`'s *Defects and gaps*, beside the rule for where the report is
  silent. The item first reads the seven entries whole.

  Recommended, on the reading alone: a mechanism where both acts are Ernest's own and
  ordering them costs a fraction of them; a sentence where one act is the host's and a
  program meets the order; nothing where no program can tell. The seven are then read
  against the rule, and one that falls otherwise is brought to the user.

  An eighth case is read with the seven, placed with the user on 2026-11-18 (the log's *A
  Checker Acts for the Target*), though no test met it: the order of the messages foreign
  code sends. Each address that crossed has a check of its own (§8.4), so what foreign code
  sends through two addresses of one process, and what it sends against what its caller
  sends after it, can change places. §6.4 and §8.7 give a process's messages an order, and
  no sentence says whether a message foreign code sends is a process's.
- **100. When a close reaches the far end, and what a read answers after one**, feedback
  262 and 263, found 2026-11-17 by ernest-httpd's session on 0.10.0 (the log's *Two Lines on
  a Close*). A socket that ended while its host held bytes closed, for the far end, a second
  after its last byte. A write answered `Left(Closed)` lost the bytes that had arrived and
  no read had taken. E.18 says neither when the close reaches the far end nor what a read
  answers after it.

  The item first runs both probes here. It shows where the second is spent and where the
  bytes go: in Ernest's code, the host's socket or the kernel. It searches the log for what
  was decided of each, *What One Read Answers* and *A Socket Lives Until It Is Closed* among
  its entries.

  The probes take the case of MVP 4.5's item 122 with them, decided with the user on
  2026-11-19: a far end that reads nothing, writes that time out, then a close. By a
  reading, a close ends the socket's writer and drops a write that timed out and still
  waits there, where E.18 says that a `Left(Timeout)` does not undo the write. The third
  question below rests on what that shows.

  Decided with the user, in a design discussion of its own, one question at a time: whether
  the close follows the last byte at once, and whether a write that answers `Left(Closed)`
  keeps what has arrived for the reads after it.

  A third question joins the two, placed with the user on 2026-11-19 (the log's *What a
  Program Can Wait On Before Its End*): what a program can wait on to know that the far end
  has taken a socket's bytes, before the program ends. E.18 sends them "until the runtime
  stops", and since item 116 a job's end cuts what a slow client has not taken. No
  recommendation is made before the probes.

  Recommended, on that session's probes alone: the close follows the last byte, since a
  reader predicts so (principle 1), and a second that no entry decided is a defect. A read
  after the close answers what arrived before it and then `Left(Closed)`, and E.18 says so.
  The write's case waits for the probe, since Ernest cannot keep what the kernel drops at a
  reset. E.18 changes first.

  Three of ernest-httpd's regression tests wait on the verdicts, and that session is told
  them.

### What is done

Items 1 to 3 are the deadlock proposal's, read and swept by item 20. Items 4 to 6 are the first
of the packages proposal's build order,
[`proposals/package_manager/`](proposals/package_manager/README.md). Item 12, the feedback, was
taken first. Items 30, 29, 31, 33, 26 to 28 and 34 came before items 5 and 6, decided with the
user on 2026-11-13 (the log's *A Reading by Decisions*), and items 41, 42, 45 and 46 followed
them. What an item decided is its log entry's, and the report's at the sections its row names.

| Item | What | Done | The report's sections; the log's entries |
|---|---|---|---|
| 1 | A deadlock's claim given its scope | 2026-11-11 | *A Deadlock of the Whole Program* |
| 2 | The callee in a deadlock's report | 2026-11-11 | *A Deadlock of the Whole Program* |
| 3 | Who waits on whom | 2026-11-11 | *A Deadlock of the Whole Program* |
| 4 | The report's sentences on a package | 2026-11-11 | *A Package and Its Manifest* |
| 5 | The manifest read and the load path | 2026-11-14 | §11.2, §11.9, E.28; *The Root Package Read* |
| 6 | `ern build`'s checks and the named packages built | 2026-11-14 | §11.1, §11.9; *The Named Packages Built* |
| 11 | The flake hunt | 2026-11-15 | *The Flake Hunt* |
| 12 | The feedback of the release review before 0.10.0, and the applications': feedback 237 to 247 and the applications' three lines, feedback 249 to 251, in one session; six build, items 14 to 19, and eight are dropped there | 2026-11-11 | *The Review's Feedback Decided* |
| 13 | The checkout's manual pages | 2026-11-11 | *One Copy of the Pages* |
| 14 | `Tcp.accept` at the limit of open files | 2026-11-11 | *The Review's Feedback Decided*, 249 |
| 15 | `List.tryForEach` | 2026-11-11 | *The Review's Feedback Decided*, 239 |
| 16 | `Bool.compare` | 2026-11-11 | *The Review's Feedback Decided*, 243 |
| 17 | `Char`'s six class predicates | 2026-11-11 | *The Review's Feedback Decided*, 247 |
| 18 | `Http.target` and the characters a browser sends raw | 2026-11-11 | *The Review's Feedback Decided*, 250 |
| 19 | The help at `++` | 2026-11-11 | *The Review's Feedback Decided*, 251 |
| 20 | The deadlock proposal's reading and sweep | 2026-11-11 | *A Deadlock of the Whole Program* |
| 21 | Item 3's follow-up | 2026-11-11 | *A Deadlock of the Whole Program* |
| 22 | ern(1)'s SYNOPSIS | 2026-11-11 | *The Synopsis's Rule* |
| 24 | The flake of `reads_limited_test` | 2026-11-15 | E.21; *A Status Read Before the Watch* |
| 25 | A second cold reading of §11.9 | 2026-11-11 | *A Package and Its Manifest* |
| 26 | A module that hides a library another uses | 2026-11-13 | *A Hiding Module Refused* |
| 27 | The ownership test's group bits | 2026-11-14 | §11.2, §12.5; *The Ownership Test Built* |
| 28 | A given path opened as resolved, with the user | 2026-11-14 | §11; *A Given Path Resolved Once* |
| 29 | A reading of MVP 4.16's design on the stronger model, with the user | 2026-11-13 | §11.9, §8.6; *The Proposal Held Against the Report* |
| 30 | The root's modules, as the lookup and the loaders find them, with the user | 2026-11-13 | §4.2, §11.1, §11.2; *One Namespace at the Root* |
| 31 | An independent reading's four points on a package, with the user | 2026-11-13 | §11, §11.2, §11.7, §11.9; *An Installed Program's Packages* |
| 32 | The flake of `deadlock_line_on_a_test_test` | 2026-11-15 | §11.2, §8.6; *The Client's Line* |
| 33 | What one `Tcp.read` answers, and what an unread socket holds, with the user | 2026-11-13 | E.18; *What One Read Answers* |
| 34 | Regression tests of the sentences item 29 stated | 2026-11-14 | [`development.md`](development.md)'s *Building*; *The Sentences Held by Tests* |
| 35 | A compiled module's dependency that has only a source | 2026-11-16 | §11.1, §11.2; *A Compiled Form's Sources* |
| 36 | `ern doc src-dir` beside a module that fails | 2026-11-17 | §11.4; *A Document Beside a Module That Fails* |
| 37 | The library's functions written in a program; the applications lose no function to the library | 2026-11-15 | E.14; *A Library's Function in a Program*, *The Sweep's Reading* |
| 38 | ern(1) written again after `make doc` | 2026-11-15 | §11.4; *What the Toolchain's Page Is Made From* |
| 39 | The README's top written again, with the user | 2026-11-16 | *The Front Page From Its Motive*, *The README's Top Comes First*, *The Front Page in the Announcement's Manner* |
| 40 | The flake of `log_terminal_gone_test_` and three tests beside it | 2026-11-15 | §11.8, §8.6, E.23; *The Shell's Last Line* |
| 41 | An independent reading of item 6's commit, `f9c5b972` | 2026-11-14 | *The Named Packages Read* |
| 42 | The round of the reading's findings | 2026-11-14 | *The Reading's Round* |
| 44 | A reading of `CLAUDE.md` for rules that contradict or repeat each other, with the user | 2026-11-15 | *The Rules Read Against Each Other* |
| 45 | The milestone split in two | 2026-11-14 | *The Milestone Split* |
| 46 | What item 42's round left to decide | 2026-11-14 | *No Module's Source*, *An Index That Is No File* |
| 51 | The flake of `delivery_foreign_code_arranges_test` | 2026-11-16 | §6.9, §8.4, §8.6; *A Sender That Outlives Its Run* |
| 55 | A reading of `CLAUDE.md` for clarity, with the user | 2026-11-15 | *The Rules Read for Clarity* |
| 56 | A test canceled at its limit ends its host's later tests | 2026-11-15 | *A Limit Ends Its Own Test* |
| 57 | The flakes of three tests of `ern_supervisor_tests` | 2026-11-16 | §6.4, §6.9, E.21, E.22; *Three Orders the Supervisor Tests Read* |
| 58 | The flake of `adapted_is_not_a_process_test` | 2026-11-16 | §6.5, §6.9; *A Delivery Counted Before Its End* |
| 59 | The flake of `write_given_no_time_test` | 2026-11-16 | E.18; *A Listener Closed Before Its Accept* |
| 60 | What item 11 left: feedback 254 to 259, each decided with the user, and `Tcp`'s two closes probed | 2026-11-17 | E.0 rule 2; *Seven Entries of the Feedback* |
| 61 | The flake of `load_beside_a_module_hiding_a_library` | 2026-11-16 | §6.4, §11.2; *A Program's Line Beside the Prompt* |
| 62 | The flake of `signal_jobs_take_any_mode_test`, and two tests beside it | 2026-11-15 | §11.2, §12.5; *A Program Named Before It Runs* |
| 63 | The flake of `subscribed_while_the_end_waits_test` | 2026-11-16 | §6.9, §8.6, E.23; *A Subscriber That Ends Beside Main* |
| 64 | The flake of `ern_os_tests`' `terminal_test` | 2026-11-16 | E.23; *A Terminal's Echo Beside Its End* |
| 65 | The flake of `ern_os_tests`' `resize_test` | 2026-11-16 | E.23; *A Signal Before the Pause* |
| 66 | The flake of `ern_tcp_tests`' `write_holds_up_no_read` | 2026-11-16 | §8.6; *A Reaper That Outlives Its Runner* |
| 67 | The flake of `shell_reload_terminal_gone`, closed as not reproducible | 2026-11-16 | *The Shell's Last Line*, *Two Hours for a Hunt* |
| 69 | OTP's 22nd report: a termination sent to a port's program before it runs, reproduced with OTP alone; filing is the user's | 2026-11-17 | [`otp_bugs.md`](otp_bugs.md), 22; *A Termination Lost With OTP Alone* |
| 70 | The look reads each checker as it reads a system process, so a message that waits at one is in flight | 2026-11-17 | §8.4, §8.6; *A Sender That Outlives Its Run*, *A Message at a Checker* |
| 71 | The flake of `ern_cli_tests`' `node_limit_flags_test` | 2026-11-16 | §12, §12.5; *The First Start's Schedulers* |
| 72 | A build with nothing to do, measured: `ern build` is not slow, and nothing is built, with the user | 2026-11-17 | *Twenty-Six Hosts Are the Cost* |
| 73 | A child that waits to run again runs once the group is whole, with the user | 2026-11-17 | E.22; *Two Orders Stated*, *The Watcher Holds Who Waits* |
| 74 | A process's end ends its deliveries of `Restarted` not yet placed, and no other delivery, with the user | 2026-11-17 | §6.9, §8.7; *No Restarted After a Death* |
| 75 | The style test reads the export lists of the roots' test modules | 2026-11-16 | *The Style Test Reads the Roots' Tests* |
| 76 | `Os.resize`'s example, told of the resize by the signal | 2026-11-16 | E.23; *The Resize Told by Its Signal* |
| 77 | The review documents read against `CLAUDE.md` and `docs/agents.md`, with the user, and their lines carried to the template and its copies | 2026-11-16 | *The Review Documents Read Against the Rules* |
| 78 | A reading of `reviews/principles.md`, `clean_room.md` and `memory_checks.md` against `CLAUDE.md` and `docs/agents.md`, with the user | 2026-11-16 | *Three Process Documents Read Against the Rules* |
| 79 | Two tests wait for their subscriber's subscription before they end | 2026-11-16 | §6.2, §8.6, E.23; *Two Tests Wait for Their Subscriber* |
| 80 | The hunt marks a record that follows a cancel in its host | 2026-11-16 | *A Record After a Cancel* |
| 81 | `listen_of_one_family_test` tells another socket's port from the regression it holds | 2026-11-16 | E.18; *A Port Another Socket Holds* |
| 82 | A host's start on a busy machine, measured: the busy wait stays, with the user | 2026-11-17 | *The Busy Wait Stays* |
| 83 | What a load says of what it could not load, with the user | 2026-11-16 | §11.1, §11.2; *What a Load Could Not Load*, *Each Failure Once* |
| 84 | The tests run side by side run in lanes, a test begun as soon as one ends: `make test-nodes` in 108 s for 209 s, with the user | 2026-11-17 | *Lanes in Place of Chunks* |
| 85 | The sessions the shell's tests start in line mode, each form by one helper | 2026-11-16 | *One Way to Start a Line Session* |
| 86 | E.18's sentence on a port still closing, narrowed, with the user | 2026-11-16 | E.18; *A Port Another Socket Holds*, *A Port Its Listener's Connections Left* |
| 87 | `make test-shell` runs under a home of the run's own, with the user | 2026-11-18 | *A Home of the Run's Own* |
| 88 | A test runs the hunt's rounds: the host's first cancel carried from one round to the next, and the record of a directory that cannot be removed | 2026-11-18 | *The Hunt's Rounds Tested* |
| 90 | OTP's 23rd report: a write to a port whose program has ended loses its exit status, not stated by OTP and reproduced with OTP alone; filing is the user's | 2026-11-17 | [`otp_bugs.md`](otp_bugs.md), 23; *A Status Lost to a Write* |
| 91 | The look reads each checker among the processes of its two reads | 2026-11-18 | §8.4, §8.6; *A Message at a Checker*, *A Checker Among the Processes* |
| 94 | Two sentences on what crosses nodes, and their three tests: what waits for a peer in the host's buffer, and an adapted address that keeps nothing alive where it was made | 2026-11-17 | §6.2, §6.5, §8.7; *The Outside Reviews Read*, *What Waits for a Peer* |
| 97 | What else waits where a `send` to a peer waits, and a gateway that waits on no peer | 2026-11-18 | §6.6, §6.7, §8.7, Appendix E.27; *What a Full Buffer Holds* |
| 98 | A node whose program has ended ends while a lost peer's socket holds output; OTP's 24th report | 2026-11-17 | §12.6; [`otp_bugs.md`](otp_bugs.md), 24; *A Connection That Cannot Drain* |
| 99 | A request's head read from a socket a piece to each read; the library's own cases held the rest, which the item's search had missed | 2026-11-19 | Appendix G.11; *A Head in Pieces, Tested* |
| 102 | A node's lock on `ernest.pid` held until its process has ended, with the user | 2026-11-18 | §11.2, §12.5; *A Lock Held to the Process's End*, *A New OTP and Nothing Else New* |
| 104 | The runtime's processes that serve the whole node wait on no peer, with the user | 2026-11-18 | §6.9, §8.7, §12.7; *The Runtime's Processes Wait on No Peer* |
| 105 | A message for a peer is placed in the host's buffer in parts, with the user | 2026-11-18 | §8.7; *A Message Is Placed in Parts* |
| 106 | What a program's helper holds for a program that does not read, with the user | 2026-11-18 | Appendix E.21, E.23; *What a Program's Helper Holds* |
| 107 | `Process.status` says `Suspended` of a process the host holds, with the user | 2026-11-18 | §11.2, Appendix E.21; *What a Full Buffer Holds*, *Suspended Is the Host's Word* |
| 108 | A peer's worker read whole; items 125 and 126 hold the fixes, with the user | 2026-11-19 | §6.5, §8.7, §12.6; *What a Peer's Worker Waits On* |
| 109 | A test that holds Appendix E's `type` lines to the library | dropped 2026-11-19 on the user's word: `ern_prelude_tests` holds them, and Appendix G's | *The Type Lines Are Held* |
| 110 | `test/Makefile` states the run's directory and its home once, for every area of the full run | 2026-11-19 | *The Run's Home Stated Once* |
| 111 | A checker acts for its address's target, with the user | 2026-11-18 | §8.4, §10, §12.3; *A Checker Acts for the Target* |
| 116 | The job halts without the host's flush, with the user | 2026-11-18 | §8.6, §11, E.18; *The Job Halts Without the Host's Flush* |
| 117 | A termination once the end's wait is over ends the end at once | 2026-11-18 | §8.6, §11.2, §12.5; *A Termination Ends a Stalled Flush* |
| 112 | A check stands through a loss of its target's node, and a fault goes straight to its target and can pass a message that takes §6.5's step, with the user | 2026-11-19 | §6.5, §8.4, §10; *A Check Stands Through a Loss* |
| 121 | A process killed while what it sends waits has sent it, and its `Down` may wait on a third node, with the user | 2026-11-19 | §6.6, §6.9, §8.7; *A Down Follows the Send* |
| 127 | The roots' unit tests run under the run's home, `AREA_RUN` in `test/run.mk` for both makefiles, with the user | 2026-11-19 | *The Roots' Unit Tests Under the Run's Home* |
| 128 | A body read a piece to each read, a body that never ends, a close inside the trailers and a limit met in bytes from the socket, with the user | 2026-11-19 | Appendix G.11; *A Body, Tested* |
| 129 | G.11 states what a client sends in a body; `Http` reads white space as spaces and tabs and a coding in ASCII case; `Char` and `String` gain `toAsciiLower` and `toAsciiUpper`, with the user | 2026-11-19 | Appendices E.0, E.5, E.6, G.11; *G.11 States What a Client Sends*, *An ASCII Case in the Library* |
| 130 | `Http.header` and `Http.headers` compare a name in ASCII case, left to the session by the user | 2026-11-19 | Appendix G.11; *A Header's Name in ASCII Case* |
| 131 | `Http.elements`, a list header's elements, a quoted string keeping its comma and nothing else, and a body's framing refuses a `Transfer-Encoding` whose quoted string does not end, feedback 267, with the user | 2026-11-19 | Appendix G.11; *A List Header's Elements* |
| 114 | `Process.fromAddress` answers the process behind a check, and a fault to an adapted address over an address given back at another type is its target's, with the user | 2026-11-19 | §8.4, Appendix E.21; *The Process Behind a Check*, *The Process Behind a Check, Built* |
| 132 | A bad message's fault to a foreign process the runtime did not start is sent as a fault in `f` is, an exit signal, and a foreign address gains no check of its own, with the user | 2026-11-19 | §6.5, §8.4, Appendix F; *A Bad Message's Fault to a Foreign Target* |

---

## MVP 4.17 (the shell's editing, what a job trusts, and the rest of packages: archives, the guide and the other repositories), about a week

Split from MVP 4.16 with the user on 2026-11-14 (the log's *The Milestone Split*), so that MVP
4.16 ends with its small items, and the discussion of §11.9 opens a milestone, where it can
change what is built. Its items keep the numbers they had in MVP 4.16, since the log cites
them by number. It follows MVP 4.16, and comes before MVP 4.6, as its items
did. Item 43 added items 47 to 49 and cut what item 8 builds. Item 119, the shell's editing,
was placed first in it with the user on 2026-11-18 (the log's *The Homepage and the Shell's
Editing Planned*).

### What is left

The shell's editing is built first.

- **119. An input of several lines is edited by its lines**, found 2026-11-17 on the
  rehearsal, with the homepage's counter waiting in the shell. No key moves between the
  lines of an input, and the up arrow puts the last input in their place. The reasons are
  [`proposals/homepage/reasons.md`](proposals/homepage/reasons.md)'s *The shell's
  editing*. Each line below was decided with the user on 2026-11-18. §11.2's *Editing*
  changes first, after one cold reading of its sentences.

  - In an input of several lines the up and down arrows move between its lines. From its
    first line the up arrow walks the history back, and from its last line the down arrow
    walks it forward. An input of one line behaves as it does today.
  - `C-p` and `C-n` follow the arrows.
  - `C-a` and `C-e` go to the start and the end of the cursor's line.
  - The cursor keeps its column on the new line, and stands at the line's end where the
    line is shorter.
  - An input recalled by the up arrow shows with the cursor on its first line, and one
    recalled by the down arrow with the cursor on its last, so that walking the history
    takes one press an entry.
  - `Home`, `End` and `Delete` are bound as `C-a`, `C-e` and `C-d`.

  Then the shell's design note, the shell's Ernest, the documents that restate the keys
  and the terminal harness's tests change. None of them was read for the item but §11.2.
  The build closes on `make test-shell` and `make test`.

  The homepage's opening then gains its last clause, which MVP 4.6's item 3 left for this
  item (the proposal [`proposals/homepage/`](proposals/homepage/README.md), *Open*, 1).
  That step closes on `make test-browser`, which holds the page's first screen.

What item 43's discussion decided is built next, each item changing the report first (the
log's *The Trust Said Once*). Items 52 and 54 are left of it.

- **52. What item 50's cold reading left**, found 2026-11-14 in §11.2's *Startup and history*,
  each older than the item's edit, and decided with the user the same day (the log's *The
  Trust Said Once*, its paragraph *Four lines of the reading*).

  - The shell says a host's refusal in the words every other job uses, `permission
    denied`. The shell words fifteen errors of `Io` itself. The item first reads each
    against §11's texts, and brings the table to the user before it is built.
  - Each case of no history gets its line in §11.2: a history file that cannot be read or
    written, and a `HOME` unset or relative.
  - "The person's" becomes "its user's".
  - §11.2 says that a link at `$HOME/.ernest` is followed. No guard is added.

  Item 54's second line, how the shell names the history file, is decided with the
  table, since both write the same lines of §11.2.

  The report changes first. The build closes on `make test-shell` and
  `make test`.
- **54. What item 49 left to decide**, found 2026-11-15 by its survey and its build (the
  log's *A Refusal Holds No Control Character*). Each line is decided with the user, and
  carries the session's recommendation.

  - A path written into a document. `--emit-erl`'s first line writes the source's path
    raw, where a line feed in it ends the comment, and a page's last line writes it as
    `\u{1B}`. Recommended: both as `\xHH`, and the sentence in §11.5, since §11.1 and
    §11.4 say "as §11.5 writes one".
  - The shell names the history file by its absolute path where it lies under the
    working directory, and the startup file beside it from that directory. Recommended:
    both as §11.5 names a file.
  - A text read from a file in a line that is no refusal: a peer's name in a reload's
    note is written raw. Recommended: the note is written as a refusal is. The host's
    log text and the text after `ern: internal error` are the host's, and stay.
  - A value a refusal quotes from a configuration is written with a control character
    below U+0020 as JSON's `\u001B`, and DEL and U+0080 to U+009F as `\x7F`.
    Recommended: the quoting writes every control character of §2.1 as JSON does.
  - The attached shell's end has no test of a cause that holds a control character.
    Recommended: none, since it would be a nodes' test for one call.
  - Feedback 253, decided with the user on 2026-11-17 (the log's *Seven Entries of the
    Feedback*): the library stays. The shell names its hexadecimal once, in a private
    function that faults as `Http`'s `chunk` does, and `escapedChar` and `hexByte` call it.

Then the packages proposal's build order,
[`proposals/package_manager/`](proposals/package_manager/README.md), as it stood in MVP 4.16.
No further cold reading of §11.9's diff runs: each of items 7 and 8 reads its own sentences of
§11.9 against its build and its probes before it closes, as items 5 and 6 did, and a finding
changes the report first (the log's *A Package and Its Manifest*).

- **7. `Crypto.sha256`**, its E.0 reading and its line of Appendix G first. Decided with the
  user 2026-11-14 (the log's *An Archive Without Links*): no library over tar or gzip is
  written, and none reads the tar format in Ernest.
- **8. `ern unpack`**, in Ernest, over `Crypto.sha256` and the host's `erl_tar`. Its rules
  were decided with the user on 2026-11-14: a member's kind and the host's `erl_tar` in the
  log's *An Archive Without Links*, and which rules stay in *The Trust Said Once*.

  - **The report first.** The item rewrites §11.9's paragraphs on an archive: its paragraph
    on where a link may reach goes, and §11.9 states the rules of a member's name and kind
    itself. It decides there whether a member of a kind the host does not know is passed
    over or refused, a pax global header among them, which `git archive` writes.
  - **An archive's rules.** Three stay: its digest, a member's name under the archive's
    directory with no `..`, and a member's kind. A member is a directory or a regular file,
    and an archive that holds anything else is refused. A name given twice is no fault, and
    the last stands. A file is made by the mask, and of a member's mode only whether its
    owner may run it is read. A test over hostile archives holds the rules.
  - **What is not tested.** An empty or a `.` segment, the kind of the directory's own
    member and a control character in a name. A broken archive fails with the host's
    reason.
  - **The job.** `erl_tar` lists the members and hands over the files' bytes, a gzip
    archive read from its bytes, and the two calls are foreign functions of the job's own
    module. Where the module stands under `Ernest` is decided as the item opens, and so is
    how its Ernest gets the manifest's entries. The shape: the command reads the manifest
    once, by the read every job shares, and hands the job its entries (the log's *The Root
    Package Read*).
- **9. The guide's section on a package.** It says what an entry's digest promises: the archive
  that `ern unpack` unpacks, and nothing of a `lib` filled by hand or changed since (the
  log's *An Installed Program's Packages*). It teaches `--package-dir` with a program
  started from another directory.

  Decided with the user 2026-11-17 (the log's *Packages and No Manager*): the item also
  writes `guide/faq.md`'s question on why Ernest has packages and no package manager, its
  answer the entry's three claims and their cost, and reads the faq's sentence on `gleam
  add` again. Both texts use the report's verbs, which get their line in the glossary.
  Whether a test holds the phrase out of the user-facing texts is decided as the item
  opens.
- **10. The other repositories**, with MVP 4.4's items 4 and 5: at its floor's rise each takes its
  manifest, ernest-template first with its Makefile cut, and ernest-epx's release carries its
  host part as the proposal's question 5 says.

  - **Who writes what**, decided with the user 2026-11-11. This session writes the
    packages' part in the three, their sessions closed, as a change across the repositories
    in their shape alone (`docs/clean_room.md`): each manifest, the template's Makefile and
    `TEMPLATE.md`, and ernest-epx's moved files and Makefile. ernest-epx's release stays its
    own session's. So do ernest-httpd's four matches on a bare `Process.Calling`, which
    take `Process.Calling()` then, since item 3 gave it fields (E.21).
  - **An installed program**, decided with the user 2026-11-13 (the log's *An Installed
    Program's Packages*). The launcher gives `--package-dir` with its root and loses its
    loop, and `make install` copies `package.conf`. A program's own Erlang is named from a
    directory of its own, `erl` in a checkout, so that `lib` holds the named packages alone.
    The item's tests take a `priv` found through `code:priv_dir`.
  - **The template's archive**, found 2026-11-14, reading ernest-epx's release step. It
    holds a library's Erlang under `lib/<name>/ebin` and `lib/<name>/priv`, each link copied
    through, where §11.9 has a package's Erlang under its own `ebin` with its `priv` beside
    it. The item moves it there, and holds the archive it makes to `ern unpack`'s rules on
    an archive's members.
  - **The site**, decided with the user 2026-11-17 (the log's *Packages and No Manager*).
    Once ernest-epx's release is an archive that `ern unpack` takes, `site/projects.md`
    says in one sentence how a project is taken, an entry in `package.conf` and `ern
    unpack`.

The proposal's sweep is last.

- **23. The packages proposal's reading and sweep**, once item 10 is done and before MVP 4.4's
  release, as *A Built Proposal's Sweep Is an Item* places one.

### What is done

The discussion came first, item 43, and items 47 to 50 built what it decided.

| Item | What | Done | The log's entries |
|---|---|---|---|
| 43 | Whether §11.9 can promise less | decided 2026-11-14 | *The Trust Said Once* |
| 47 | The trust said once, and the defenses that go | 2026-11-14, in two builds | *The Trust Said Once*, its paragraphs *The first build* and *The second build* |
| 48 | One paragraph on a name that reaches no regular file | 2026-11-15, in two builds | *The Trust Said Once*, its paragraphs *The fourth build's sentences* to *The corner closed* |
| 49 | A control character in a path a job writes: a refusal holds none, and §11 says so | 2026-11-15 | *A Refusal Holds No Control Character* |
| 50 | The history file's owner | 2026-11-14 | *The Trust Said Once*, its paragraphs *A fourth test*, *A directory the shell cannot make its own* and *The third build* |
| 53 | What item 48's cold reading left | dropped 2026-11-14 on the user's word: no more is spent on a name that reaches no regular file | *The Trust Said Once*, its paragraph *The corner closed* |

---

## MVP 4.6 (the server owns both ends of its socket, and the homepage), a few days, before the launch

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*), the
proposal [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md), and moved before the
launch on 2026-11-10, once the server's reset under load was fixed and the three floors stood at
0.10 (the log's *MVP 4.6 Before the Launch*). The site's script speaks the server's wire, its
generator reads the server's configuration and its browser test stubs the server's socket. Each
goes, for a client the server ships. The order keeps the proposal's: the server's part first,
which adds and takes nothing away, and no day but the launch's switch changes both repositories,
on a path the rehearsal has walked.

1. **The ask**, done on 2026-11-10 (the log's *The Client's Interface Agreed*). The server
   serves the client as its design's *The client* states it, and the rehearsal serves it at
   `https://ernest-lang.org:8443/` until the launch's switch. The server's part goes into
   the release its item 5 makes for the launch.
2. **Ernest's side**, begun after MVP 4.17 and built against the rehearsal's server.
   `site.js`'s session imports the client, an ES module, on demand. The generator takes no
   configuration, and `make site` the tag alone. The shell's page takes its numbers from the
   client's limits and names no memory. The browser test serves a stub client that speaks the
   agreed interface. `docs/design/site.md` changes in five sections, citing the server's
   design's *The client* for the interface, with the sweep the proposal lists. It goes live
   with the launch's switch, and closes on `make test`, the site's targets and
   `make test-browser`.
3. **The homepage and the blocks' tools**, done on 2026-11-19, ahead of this milestone (the
   log's *The Homepage Built*), the proposal
   [`proposals/homepage/`](proposals/homepage/README.md). The opening's last clause is
   MVP 4.17's item 119, and item 2 reads the site's design note as this item left it.
4. **The stylesheet's units**, after item 3 (the proposal's *The stylesheet's units*).
   `:root`'s size follows the reader's, and the widths at which the layout changes and the
   page's width leave the pixel, together or not at all. The first screen's three sizes
   are measured again, and the page is looked at with the browser's font size at 20 and at
   24 pixels.
5. **The proposals' reading and sweep**, once items 2 and 4 and MVP 4.17's item 119 are
   done, and before MVP 4.4's release. [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md)
   and [`proposals/homepage/`](proposals/homepage/README.md) are read for what they hold
   that no owner has yet, in a reading decided with the user. That goes to the site's
   design note or the log. The item removes each directory once this milestone's row names
   the log entries that argue it and nothing else cites the directory.

---

## MVP 4.4 (the cost, the full review and the launch's release), about four weeks

Decided with the user on 2026-10-31 (the log's *MVP 4.4, the Road's End*): the road's last
milestone before a program, so that the review reads a language that ernest-httpd,
the website and the operator's prompt have used. After it the road is a program's.

Its release is the next minor of 0.x, decided with the user on 2026-11-05. Ernest stays at 0.x
until someone outside this project depends on it, so that a break would cost them something,
and 1.0 has no date (the log's *Ernest Stays at 0.x*, which keeps what 1.0 will promise).

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

   MVP 4.16's item 123, what 20,000 faults at once hold, is read with the fault's report,
   moved here on 2026-11-19 (the log's *The Line Before the Launch*). It was found
   2026-11-18 by item 106's probes (the log's *What a Program's Helper Holds*, its paragraph
   *Found beside it*). A kill of a program with 20,000 writers waiting faulted them all, and
   the node's memory peaked at 4.4 GB while their reports were written, about 220 KB a
   report. An agent first shows what one fault's report holds and what many at once add, and
   the fix's shape follows what it shows.
3. **The raise a primitive catches**, `ern_json:decode` among them, whose cost grows with the
   caller's stack, 0.4 microseconds on a shallow stack and 110 at 100,000 frames, the trace's
   capture (found 2026-11-01; the log's *The Four Libraries*): read in erts and taken to
   `otp_bugs.md`, or decided against the trace `backtrace_depth` keeps.
4. **The full review**, as `docs/reviews/full.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says.

   A finding that meets one of MVP 4.5's items 68, 96, 103, 113, 118, 122 and 134 is sorted to
   that item. It comes before the launch only where a program shows a sentence of the report
   false (the log's *The Line Before the Launch*).

   Before its readers start:

   - **The tools weighed.** `tools/paragraphs.sh`, `tools/comments.sh` and
     `tools/unicode_width.escript` are weighed against CLAUDE.md's *Ernest or Erlang*, each
     written in Ernest or its reason to stay stated (the log's *The Layout's Proposal Read*).
   - **The argument recut**, decided 2026-11-07. `docs/soundness.md`'s section 7 is recut: its
     paragraphs cut at their turns and ordered by claim, not by the history of the rules that
     wrote them, and section 1 naming the two claims it argues beyond the four, that no process
     runs after the end and that a process's code stands while it runs, with no paragraph's
     content changed, so that the cold reader reads the argument and not its history (the log's
     *The Argument Recut*).
   - **The checks that cost cycles**, built, decided with the user 2026-11-10, so that the
     readers start from what a tool lists (the log's *The Listings Before a Review*).

     The refusals left after the four built before the release review before 0.10.0 (the log's
     *The Refusals Before the Release Review, Built*), each added with the tree cleaned to
     zero: `xref`'s unused exports and its layers, with a short list of the exports called by
     name, each with its reason, and near misses for the checker beside the typed programs.
     From then on each runs with the checks of its kind: `xref`'s in `make xref`, and the near
     misses in `make test-full`.

     The listings, which a review runs: `cover` over `make test-full` for the full review,
     clones and each module's size for the full and the release reviews, and the slowest tests
     for the release review. `docs/reviews/full.md`, `release.md` and `development.md` name
     each check in the commit that builds it.

     Decided first, with the user: whether the checker warns of a private function no code
     calls (§11).
   - **What is kept, stated once**, found 2026-11-16 by the reading of three process
     documents (the log's *Three Process Documents Read Against the Rules*).
     `docs/memory_checks.md`'s *What is kept, and what lets it go* says when each row, unit
     and process goes, and the design notes say it too, in the two places sampled.

     Decided with the user: the design notes own what a component keeps and when it lets
     go. `memory_checks.md` keeps the loads, the reading, what the host keeps and the
     tracing, and points at the notes. A reader reads each line against its note. A line a
     note lacks moves there, and one a note states goes. The session writes it, and it
     closes on `make test-docs`.
   - **The documents' listings**, built, decided with the user 2026-11-16, so that the readers
     of the report, the guide and the tour start from what a tool lists (the log's *The
     Documents Before the Launch*). `docs/reviews/full.md` names each in the commit that
     builds it.

     Five listings, which the full review runs. The words of each section of the guide and
     the tour, as `make coverage` counts the report's. Each section of the report with the
     places of the guide that cite it, and a section none cites named. Each term of Appendix
     F with its count in the report, the guide and the tour. Each fenced block no test
     compiles or runs, by its mark and its file. Each section of the three by the commits
     that touched it, most first.

     One refusal, added with the site cleaned to zero: the browser test's check that a page
     does not scroll sideways on a phone reads every page the site writes.
   - **The checker's cases tabled**, decided with the user 2026-11-17 (the log's *The
     Outside Reviews Read*, its paragraph *The checker's cases*). An agent tables the
     eight groups of cases the paragraph lists, where a fault of inference over mailbox
     types would show: each case, and the test that holds it under
     `src/toolchain/checker/test/` or in `test/ern_typed_programs_tests.erl`, or none. A
     case with no test gets one. It comes earlier where a checker item comes before the
     review.

   Beside it, on the user's word, ernest-template, ernest-epx and ernest-httpd are each reviewed
   whole by their own sessions, by the `docs/full_review.md` each took at the layout's stop,
   against the archive of the commit the readers read; ernest-httpd's review has a security
   reader, since it goes public at item 6. What they find of Ernest's comes as lines of
   their feedback files and is sorted in this round (the log's *The Applications' Full
   Review*, *Ernest Stays at 0.x*).

   As they begin, the three floors rise to the launch's minor, each by its own session, since
   a development build of the floor is what an archive before the release is (the log's *The
   Floors and the Releases*). Ernest's session names the minor, the archive's path and its
   commit to all three by a message, and asks for the reviews, on the user's word.

   The three floors stand on 0.10 since 2026-11-10, and rise together from there (the log's
   *The Release Review Before 0.10.0*, its last paragraph).
5. **The launch's release**, the next minor of 0.x, by `docs/reviews/release.md`'s step, on Linux:
   macOS unverified and said so in the README's installing sentence and the note, which also
   says that the installed layout changed, for a script that points inside an installation (the
   log's *The Layout Built*); the findings file empty, and the feedback file holding only entries
   that an item of MVP 4.5 holds.

   Before the tag, the last read, decided with the user 2026-11-16 (the log's *The Documents
   Before the Launch*). The user reads the tour, the guide and the report on the site built
   from the release's commit, once the release review's findings are made and before reader
   K's round, which then reads its sentences with the rest. So what ships has been read
   whole, as a visitor meets it.

   The order is a visitor's: the front page and the tour, aloud and then doing what it says;
   `guide/why.md`; `guide/language.md` in three sittings; `guide/faq.md`;
   `guide/deployment.md`; and `report/language.md` whole. The library's and the toolchain's
   files are read as reference, by ten lookups and the twenty sections the listing of commits
   names first. The session calls each sitting, with its page, its start and its end, and
   sorts its marks before it calls the next.

   A mark is a place and three words: skimmed, tripped, wrong or not what was meant, or good
   and to be kept. The read changes sentences alone. Anything larger is an item after the
   launch, since a round of fixes would leave the text unread again.

   One reader from outside, an Erlang programmer, reads the tour and the guide's first
   chapters and says where they stopped. The user asks them as item 4 closes, since the wait
   is about a week.

   The same week, in this order, each by its own session on the user's word: ernest-template's
   release, since the others copy from it; ernest-epx's, not waiting for its milestone 9; and
   ernest-httpd's, with its readers (the log's *The Floors and the Releases*). Ernest's session
   tells all three the tag by a message, and asks each in turn when the one before it is out.
   The message names every line of the application's that the release answers, MVP 4.16's item
   12's among them, each by Ernest's number. Each application checks every verdict against the
   release before its own, and answers with any line it keeps, as `docs/clean_room.md`'s *The
   answer* says.

   The release review decides the segmentation fault of the host in the typed programs, moved
   there on 2026-11-08 (the log's *The Items Left Read Again*): the target runs with core
   dumps on, so the next fault leaves its core in `test/`, whose stack goes to `docs/otp_bugs.md`
   and to the OTP team, and where none comes by the review, the review decides whether the
   watch stays.

   The announcement, the user's `~/announcement.txt` outside the repository, shows a shell's
   start line. `make version` does not write it and no test holds it, so the user sets it to
   the release's version before sending it (the log's *The Front Page in the Announcement's
   Manner*).
6. **The site live at ernest-lang.org**, last, so that each project it lists builds on the release
   it names (the log's *The Site Goes Live With 1.0*, *Ernest Stays at 0.x*): `make site` from
   that tag, the copy of `build/site/` to the host, and the smoke test against the live site.

   Before it, the generator writes `/robots.txt` and `/sitemap.xml`, the second naming
   ernest-lang.org alone, which the site's proposal decided and MVP 4.2 did not build (the log's
   *The Site's Proposal Read*); `docs/design/site.md`'s *The root* lists them then.

   ernest-httpd rehearses the switch on the machine,
   under a second unit on scratch ports, with Ernest 0.10.0's archive and, once its part of MVP
   4.6 serves the client, with the client, so that the
   switch at the launch swaps one archive for another on a path already walked; then, with its
   release of item 5 made, it switches once, the machine serving its one page meanwhile. Its
   container, two nodes capped at 128 processes, 128 MiB and one core, was built 2026-11-04
   (the log's *A Node's Schedulers*).

   Decided with the user on 2026-11-17: the site's server takes a new build while it
   serves after the launch, if at all. A deploy ends at most six demo shells, the deploys
   around the launch come with a new floor, a restart either way, and nothing hands a
   listener over today (the log's *The Server's Answers*, its paragraph *New code under
   traffic*). What Ernest lacks for it is feedback 261, MVP 4.5's item 4.

---

## MVP 4.5 (`:trace f`, two requests to OTP, a decision on a listener, and what the line left), about two weeks, after the launch

The shell's second round, decided with the user on 2026-09-30 (the log's *The Shell's Second
Round*) and decided again on 2026-10-30 against the attached shell (the log's *The Shell's Second
Round, Decided Again*), and following the launch since 2026-11-05 (the log's *MVP 4.3 Becomes
MVP 4.5*): of its eight items one remains, three moved into MVP 4.0's shell, where
the operator's prompt is, and four were dropped with their verdicts in the log.

On 2026-11-19 the milestone took what the line left after the launch (the log's *The Line
Before the Launch*): six items of MVP 4.16, each under the number it had there, and feedback
264 as item 5. An item number above 5 in their paragraphs is MVP 4.16's. An item found later
and judged to stand here is added the same way, with its date and its fix's shape.

Items 118 and 122 are taken first, since no reading of their kind has come back empty. Items
1 to 4 follow, then items 68, 96, 113, 134 and 5. Item 103 is last, since nothing of Ernest's
meets it.

1. **`:trace f`**, a proposal first: each call of `f` on the node and each return printed at the
   operator's prompt, the values by their descriptors (§11.2), with a bound a busy node needs, as
   Erlang's `recon_trace` has one; the runtime has no tracing hook today, so the design decides
   how a function of a unit is traced by its position and what the bound is. Built on the node.
2. **A request to OTP for what a purge needs**, added with the user on 2026-11-16 (the log's *A
   Purge Needs Sight*): a way to learn that no function value of a module's code is alive on the
   node, so that a node may let go code no one uses (§11.2 *What a node holds*). The emulator
   keeps no count of them, as its source read that day shows. The item chooses between two
   requests, a count the emulator keeps and a scan when asked, and drafts the one chosen for the
   user to file; nothing is built. Two decisions for the user stand in it: whether the contradiction
   in the documentation of `erlang:check_process_code/3` is filed as a report of
   `docs/otp_bugs.md`, and, where OTP refuses, whether a token of the runtime's own is weighed.
3. **A request to OTP that `os:set_signal/2` take `sigint`**, added with the user on 2026-11-17
   (the log's *Seven Entries of the Feedback*, feedback 256): the host hands the interrupt to
   no Erlang code, so §8.6 ends a program at once and tells no subscriber. An agent reads
   OTP's source and its tracker for whether it was asked before, and drafts the request for
   the user to file; nothing is built. Were it granted, a first interrupt would be a
   termination and a second would end the program at once, decided then.
4. **Whether `Tcp` hands a listener over**, feedback 261, added with the user on 2026-11-17
   (the log's *The Server's Answers*, its paragraph *A listener handed over*): a listener
   given to another process, or a listen beside a live one, so that a program takes new code
   with no connection refused between. A decision, and nothing is built: it is read against
   E.0's admission rules first, and then against ernest-httpd's proposal for new code while
   it serves, where that session writes one. Where neither comes, the item closes on a log
   line that drops the entry and says why.
5. **Whether a program can wait for a peer's telling**, feedback 264, found 2026-11-17 by
   the read-back of MVP 4.16's item 97 (the log's *What a Full Buffer Holds*). Four sites of
   the tests read `Peer.utilizations` in a loop with a sleep of the teller's interval, since
   a telling is the runtime's frame and no message shows that one came. A decision, and
   nothing is built: a wait for a telling is read against E.0's admission rules. Where a
   rule admits it, E.27 changes first. Where none does, the four sites keep their wait with
   its reason beside it, and the item closes on a log line that drops the entry.

What the line left, in the order it is taken:

- **118. What a listed peer's dial meets while a node ends**, found 2026-11-18 by item
  116's reading (the log's *The Job Halts Without the Host's Flush*, its paragraph *Item
  118*), and not read. A node's host takes dials from `ern_carrier:depart/0` until its
  process exits, and that time is long while the end waits on a stalled stream. An agent
  first shows, on two nodes, what a listed peer that dials then is told, what its sends and
  its monitors meet, and which reason the node's exit gives it, against §8.7 and §12.6's
  *A node's end*. What it shows is brought to the user.

  The showing with a peer that stands still is made by MVP 4.16's item 124, decided with
  the user on 2026-11-19, and what it finds false is mended there. This item keeps the
  rest, and the window of an end that waits on a stalled stream, which stays unread
  until then.
- **122. Whether a socket's writes that time out are bounded**, found 2026-11-18 by item
  106's reading (the log's *What a Program's Helper Holds*). E.18 says of `Tcp.write` what
  E.23 says of `Os.write`: a `Left(Timeout)` does not undo the write. A socket's writer
  takes its writes from its mailbox one after another, so by a reading the writes that
  timed out wait there and nothing bounds them. An agent first shows what a writer to a
  socket whose far end reads nothing makes the node hold, and what gives it back. The
  shape then follows item 106's: E.18 says what the rule costs, and what is held past
  its use is mended.

  What a close does with such writes is shown by MVP 4.16's item 100's probes, decided
  with the user on 2026-11-19, and what they find false is mended there. This item starts
  from that showing and keeps the bound.
- **68. A job that ends at once, and its other stream**, found 2026-11-15 by item 40's
  diagnosis (the log's *The Shell's Last Line*). A stream that can no longer be written ends
  a job outside a run at once, and so does the host's termination or hangup (§11). Neither
  end writes the other stream out, and the host writes a stream from a thread of its own, so
  a line the job has said on standard error may be lost where its standard output's reader
  has gone. That is read from the code, and the item first runs a program that shows it.

  Decided with the user: whether an end at once writes out what the other stream took.
  Recommended: it does where a stream has gone, as the job's own end does since item 40,
  and §11 says so; a signal's end stays at once, since a stream whose reader is slow would
  hold a termination.
- **96. A write that reaches the disk**, feedback 260, found 2026-11-17 (the log's *The
  Outside Reviews Read*, its paragraph *A write that survives a crash*). `Fs` has no sync,
  so a program that keeps data across a power loss cannot be written in Ernest. E.0 rule 1
  admits the operation, since the host has `file:sync/1` and `file:datasync/1`.

  Decided with the user, in a design discussion of its own: its shape. `Fs` has paths and
  no open file, where the host's sync takes an open file, and a write that survives needs
  the file synced and, after the rename, its directory. Recommended: one function over a
  path, a file's or a directory's, with `Fs.write` left as it is, since a write that always
  synced would make every write pay for a need few have. E.17 changes first.
- **113. A process for each address that crossed**, feedback 265, found 2026-11-18 by the
  cold reading of item 111's sentences (the log's *A Checker Acts for the Target*). §8.4
  keeps one check for each distinct address that has crossed, until the process the address
  names ends, and an adapted address is distinct by its function and by what it captured.
  A server that gives foreign code a fresh adapted address for each request keeps a process
  for each while it lives, which §10 states. To decide with the user: whether a check ends
  sooner, and at what.

  Weighed with it: since item 112 a check of a process on a node that never connects again
  stands until the program ends (the log's *A Check Stands Through a Loss*).
- **134. The term of a fault a foreign process takes as a message**, found 2026-11-19 by
  item 132's showing (the log's *A Bad Message's Fault to a Foreign Target*). A foreign
  process on another node than the fault's sender takes a fault as a message (§6.5), and
  the report gives that message no term. The code has two shapes: the cause alone from a
  check, and the whole fault from a fault in `f`. §6.5 is true as it stands and silent
  on the term, so by the line's test the item stands here.

  The shape: §12.2 states one term, and the code sends one shape. §12.2 says three
  things more of the exit signal a foreign process of the sender's node is sent: that a
  process that traps exits takes it as a message, which process it comes from, and that
  the trace of a bad message's fault is empty.
- **103. Two behaviors of OTP's that no report holds**, found 2026-11-17 by item 98's
  build and decided with the user the same day (the log's *A Connection That Cannot Drain*,
  its paragraph *Decided after the close*). `net_kernel:setopts/2` for a node answers
  `{error, noconnection}` where it is called at once on the node's `nodeup`, since the host
  sends that message before the connection counts as up: 40 of 1,000 connections with OTP
  alone. `net_kernel:setopts(new, ...)` answers `{error, enotsup}` under TLS distribution,
  since `inet_tls_dist` exports no `setopts/2`, which has no script with OTP alone yet.

  Nothing of Ernest's meets either, since the carrier sets its sockets' options by boot
  flags. An agent writes both as reports in [`otp_bugs.md`](otp_bugs.md)'s form, each
  reproduced with OTP alone, and the session runs each script as placed. Filing is the
  user's.

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
| MVP 4.15 | what the server taught: a node at the host's limits, of processes, of ports and of open files; nothing at the wait and memory shown; `kill` on a `Process`; text from bytes that are not all UTF-8; a worker's value or its end; a program's environment and a signal named; `libs/http`'s values and `libs/uri`; an error across a library; the libraries' shims read against E.0 rule 1; what a lambda's reach finds on a peer; relative names; a terminal that is gone and the host's warnings on standard error; the compiled modules the host cannot read or load, and a load past its limits; four refusals before the review; a listener's backlog; 48 items, the repository's layout between the first two, and the release review before 0.10.0 | 2026-11-10 | Ernest 0.10.0, tag `v0.10.0` | the proposals `docs/proposals/relative_names/` and `docs/proposals/errors_across_libraries/`, gone with item 15 (the log's *A Built Proposal's Sweep Is an Item*); the log's *What the Server Taught*, *The Items Left Read Again*, *Lean at the Limits*, *What `running` Finds*, *The Shell at a Full Table*, *A Terminal That Is Gone*, *The Host Says Running*, *Relative Names*, *A Built Proposal's Sweep Is an Item*, *Nothing at the Wait*, *Both Applications at the Milestone's End*, *The Floors and the Releases*, *Relative Names, Built*, *The Repository's Layout*, *The Layout Built*, *One Stop for the Layout*, *The Other Repositories' Shape*, *CLAUDE.md Redrafted*, *The Template Cut Again*, *The Layout's Proposal Read*, *A Node's Limits*, *A Node's Schedulers*, *The Hangup's Order*, *ernest-httpd's Lines 18 to 21*, *Nothing at the Wait Built*, *Memory Shown*, *`kill` Takes a `Process`*, *Text from Bytes*, *A Text after Its Prefix*, *A Worker's Value or Its End*, *A Worker's Value or Its End Built*, *A Test's Scratch, and JSON on One Line*, *A Case's Standard Error*, *A Program's Environment, and a Signal Named*, *A Program's Environment, and a Signal Named Built*, *`libs/http`'s Values*, *`libs/uri`*, *`libs/uri` Built*, *A Process Owns What It Opens*, *An Error Across a Library*, *The Libraries' Shims Read Against E.0 Rule 1*, *What a Lambda's Reach Finds on a Peer*, *A Top-Level Binding Stays the Node's*, *The Shell Attaches as a Program Spawns*, *An `or` Stands Between Patterns*, *An `or` Inside a Pattern Refused*, *A Node's Own Processes at a Full Table*, *A Terminal That Is Gone, Built*, *The Runtime at the Limit of Open Files*, *What `running` Finds, Built*, *The Sockets Load on One Scheduler*, *A Capture Written Back at the End*, *`Float.atan2` at the Origin*, *The Shell Attaches as a Program Spawns Built*, *A Node Holds the Shell*, *A Waiting Process Collected*, *A Full Table's Answers, Built*, *The Carrier's Acceptor at a Full Table*, *A Program's TLS at a Full Table*, *The Flake of `broken_exchange_test_`*, *TLS as the Host Loads It*, *A Write to a Terminal That Is Gone*, *A Write to a Terminal That Is Gone, Built*, *A Write to a Terminal That Is Gone, Swept*, *The Host's Log Handler at a Terminal That Is Gone, Built*, *The Host's Log Handler at a Terminal That Is Gone, Swept*, *A Pipe Into a Parenthesized Pipe*, *Where the Host's Warnings Go*, *The Flake of `shell_write_terminal_gone_test_`*, *A Compiled Module the Host Cannot Read*, *A Compiled Module the Host Cannot Load*, *A Load Past the Host's Limits*, *The Flake of `os_signal_after_an_unread_exit_test`*, *A Write and a Resize after an Unread Exit*, *The Listings Before a Review*, *The Refusals Before the Release Review, Built*, *One Name for xref*, *A Listener's Backlog*, *The Release Review Before 0.10.0* |
| Ernest 0.10.0 | the release of what the server taught, and the release review before it, which read the milestone's diff, 126 lines fixed and 25 decided in eighteen decisions | 2026-11-10 | tag `v0.10.0` | the log's *The Release Review Before 0.10.0* |
| MVP 4.16 | a deadlock's scope and its report, a package's manifest and build, the flake hunt, and what its builds and the outside reviews found | | | above |
| MVP 4.17 | the shell's editing, what a job trusts, and the rest of packages: archives, the guide and the other repositories | | | above |
| MVP 4.6 | the server owning both ends of its socket, and the homepage | | | above |
| MVP 4.4 | the cost analysis, the full review and the launch's release, Linux | | | above |
| MVP 4.5 | the shell's second round, two requests to OTP, for what a purge needs and for the interrupt, a decision on a listener handed over, and what the line of 2026-11-19 left after the launch: six items of MVP 4.16 and a decision on a wait for a telling | | | above |
