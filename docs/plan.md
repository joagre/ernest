# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log/`](log/README.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands to
[`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone
ends the file. A gap stands in the milestone whose item closes it, a defect of OTP's in
[`otp_bugs.md`](otp_bugs.md), a corner that only a built program meets in
[`known_issues.md`](known_issues.md), and a feature declined in a dated entry of the log; nothing
stands between.

---

## Where we are

**Ernest 0.11.0 is the last release**, of 2026-11-26, and the checkout works toward 0.12.0. The
table's rows for MVP 4.4 and Ernest 0.11.0 say what it holds. No promise of stability is made,
and a change to the language, the standard library or the libraries is driven by a need met in
use and recorded as `docs/language_feedback.md` records one. Ernest stays at 0.x until someone
outside the project depends on it, so that a break would cost them something, and 1.0 has no
date (the log's *Ernest Stays at 0.x*, which keeps what 1.0 will promise).

**MVP 4.4 is done since 2026-11-26**: the cost, the full review, the release review and the
release. The tag is `v0.11.0` at `8dedd59f`, published on GitHub with its archive and with no
announcement, so that the applications have a published floor (the log's *Ernest 0.11.0*).
ernest-httpd, ernest-epx and ernest-template were each told the tag, the archive and the lines
of its own that the release answers.

The milestones to come, in order: MVP 4.18, whose release, 0.12.0, is the launch, with the site
live and the announcement; and MVP 4.5 after it. Each section's opening says what the milestone
is and names the log entry that placed it.

**A line stands before the launch**, drawn on 2026-11-19 (the log's *The Line Before the
Launch*). A sentence of the report that a program shows false is mended before the launch,
MVP 4.18's release since 2026-11-23, by a narrower sentence first. A reading not yet made, a
cost, a question where the report is true and a report against OTP stand in MVP 4.5. Each
item is judged against that test when it is written and before it starts. Since 2026-11-21 a
find that only a built corner shows gets its line in [`known_issues.md`](known_issues.md),
and becomes an item when the user takes it up (the log's *The Short Rules Stay*).

**A finding an item names** is a line of a findings file that is gone, by its reader's letter
and number. One named as the findings' is `findings.md`'s as it stood at `ab68ef61`, the full
review's and the applications'. One named as the release review's is the file's as it stood
at `3051fbf5`, with the user's verdict beneath a decided line.

---

## MVP 4.18 (0.12.0, the site live and the announcement)

Decided with the user on 2026-11-23 (the log's *The Launch Is 0.11.1's*). ernest-httpd's
full review found holes in its security, and the site's going live is what puts that server
before the public, so the site's going live, MVP 4.4's item 6 once, waits for them, and the
announcement waits with the site, since it sends a reader there. Its release is the launch,
and it is 0.12.0, decided with the user on 2026-11-28 (the log's *The Launch's Release Is
0.12.0*).

**The applications release on 0.12.0**, all three, in item 3, decided with the user on
2026-11-28 (the log's *All Three Release on 0.12.0*). Of the two releases that were to
follow 0.11.0, moved here from MVP 4.4's item 5 on 2026-11-26, ernest-template's is out
since 2026-11-27, its tag `v0.11.0` at `23e2bdc` on GitHub, and both copies have taken it
(the log's *The Template's Tag Is Out*). ernest-epx's is not made: it releases once, on
0.12.0.

Ernest's session told all three applications the tag of 0.11.0 by a message on 2026-11-26
that names every line of the application's that the release answers. ernest-epx's issue
1, a module that does not load named in a foreign call's fault, is built for 0.12.0 (the
log's *A Module That Does Not Load Is Named*).

The items are taken in this order, not by their numbers, decided with the user on
2026-11-28 (the log's *ernest-httpd's Lines Are All In*): items 7, 1 and 9, closed that day; items 6, 8 and 10; item 2, the release, with the last read
before its tag; item 3; item 4; and item 5 last. Items 9 and 10 joined them on 2026-11-28
(*Robots and the Sitemap Before the Tag*, *The First Hour Before the Tag*).

1. **What ernest-httpd's review found of security**, closed 2026-11-28 (the log's *Item 1
   Built*). ernest-httpd's session mends its own, and said that day that it knows of no
   line beyond these (*ernest-httpd's Lines Are All In*). What was Ernest's came as
   entries 35 to 37 and 61 of its feedback file and one decision, each taken with the
   user and built for 0.12.0, or placed:
   - no function ends a socket and drops what its host holds: MVP 4.5's item 158 (*The
     Socket's Reset Stays After the Launch*);
   - a close and a kill after a failed TLS handshake waited 5 seconds: the host's
     `alert_timeout` is 0 (E.18; *The Host's Wait After Its Alert Goes*);
   - over TCP a close answered up to a second after its bytes: the closer looks sooner
     (E.18; *The Closer Looks Sooner*);
   - `Tcp.ipAddress` and a leading zero: E.18's clause and its test (*The Applications
     Told Again*);
   - an absolute form's authority, and a `CONNECT` target's: G.11 says that its fit is
     the server's (*The Authority's Fit Is the Server's*).

   ernest-httpd's session checked each verdict on an archive of `c4553aa8` and agrees
   with all five (the log's *ernest-httpd's Answer on Item 1*).

   Four `decide` lines of the findings' are a server's security too, each decided (the
   log's *The Applications' Lines Decided*): a command's environment, *H39*, and a
   client's renegotiation, *H53*, were built for 0.11.0; a call's wait under a backlog,
   *H54*, is MVP 4.5's item 174; and `Http.filePath`, *H59*, stays, with its page's two
   sentences.
2. **The release of 0.12.0**, by `docs/reviews/release.md`'s step. It is a minor release,
   and so a new floor (report §8.7).

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
   chapters and says where they stopped. The user asks them as item 1 closes, since the wait
   is about a week.
3. **ernest-template's release, then ernest-epx's, then ernest-httpd's**, each by its own
   session on the user's word, once 0.12.0 is out (the log's *The Floors and the
   Releases*, *The Template's Release Before ernest-httpd's*, *All Three Release on
   0.12.0*). The template's comes first, since ernest-epx and ernest-httpd copy from it
   and may have to follow its tag. ernest-epx's does not wait for its milestone 9.
   ernest-httpd's comes last, made with its readers.

   Ernest's session tells each the tag by a message that names every line of the
   application's own that the release answers, and asks each in turn when the one before
   it is out. Each application checks every verdict against the release before its own,
   and answers with any line it keeps, as `docs/clean_room.md`'s *The answer* says.
4. **The site live at ernest-lang.org**, so that each project it lists builds on the release
   it names (the log's *The Site Goes Live With 1.0*, *Ernest Stays at 0.x*): `make site` from
   0.12.0's tag, the copy of `build/site/` to the host, and the smoke test against the live site.

   Before the copy, ernest-epx's published archive is taken as `site/projects.md` says, by an
   entry in a `package.conf` and `ern unpack`, since MVP 4.17's item 9 wrote the sentence
   before that release. Where it fails, the site waits for the archive.

   The generator writes `/robots.txt` and `/sitemap.xml` since item 9, before the tag.

   ernest-httpd rehearses the switch on the machine, under a second unit on scratch ports,
   with Ernest 0.11.0's archive since 2026-11-28 and, since MVP 4.6, with the client, so
   that the switch at the launch swaps one archive for another on a path already walked;
   then, with its release of item 3 made, it switches once, the machine serving its one
   page meanwhile. Its
   container, two nodes capped at 128 processes, 128 MiB and one core, was built 2026-11-04
   (the log's *A Node's Schedulers*).

   A node of 0.11's form started on the rehearsal on 2026-11-28, past the two refusals
   0.11.0 made that can stop a deployed node: an `ernest.conf` that holds `public-key` or
   `utilization`, and a directory or an `ernest.conf` that any but its owner may write
   (the log's *The Nodes' Build*, *The Rehearsal on 0.11.0*).

   Decided with the user on 2026-11-17: the site's server takes a new build while it
   serves after the launch, if at all. A deploy ends at most six demo shells, the deploys
   around the launch come with a new floor, a restart either way, and nothing hands a
   listener over today (the log's *The Server's Answers*, its paragraph *New code under
   traffic*). What Ernest lacks for it is feedback 261, MVP 4.5's item 4.
5. **The announcement**, last. The user's `~/announcement.txt` outside the repository shows
   a shell's start line. `make version` does not write it and no test holds it, so the user
   sets it to the release's version before sending it (the log's *The Front Page in the
   Announcement's Manner*).
6. **Which libraries become packages**, a decision, built for 0.12 where it is taken (the log's *What Stands on Every Load Path*, *The Report
   Read Whole Against the Verdicts*). Seven stand on every load path that no job of the
   toolchain's calls: `Json`, `Http`, `Uri`, `Time`, `Base64`, `Proxy` and `Utilization`.
   A proposal weighs the rule that a library stands there only where the toolchain's
   jobs call it, and tries the other test, a package where a library is over a published
   specification.

   It also asks whether the standard library keeps `OrderedSet`, `OrderedMap` and
   `Random`, which E.0 holds by name since 2026-11-23, with what a move changes for each:
   `:load` at the prompt, definitions hashed where the standard library's agree by the
   floor, the start, the checking of foreign returns, and Appendix G's status.

   It says how a package would ship, in the installation or on the releases page; what a
   program names where a manifest is flat, `Http` with `Time` and `Uri`; whose version
   each takes; and what the examples, the guide's §7 and §9.6, the site's pages, the man
   pages and ernest-httpd's manifest become. It also asks whether the draw of
   `Peer.computeAnywhere` follows them, as a policy a library holds. It is read against
   each of those owners before the user decides.

   The proposal is [`proposals/libraries/`](proposals/libraries/README.md), written
   2026-11-28 and read against those owners (the log's *The Libraries' Proposal
   Written*). It recommends that none moves for 0.12.0, that Appendix G states its rule
   with six libraries listed by name, that E.0 keeps the three modules as it names them,
   and that E.0's rule 3 names E.27's draw. The decision is the user's.
7. **Three faults that vanish**, taken up by the user on 2026-11-23 from three lines of
   the known issues (the log's *Four Verdicts Changed After the Round*), built for 0.12.0
   and closed 2026-11-28, each line of the known issues gone with its fix. An `Os.exit`
   that a process kept for an adapted address calls once the end's wait is over gives the
   node its status (§8.6; the log's *An Os.exit After the Wait Gives Its Status*). A
   wrap's fault that such a process meets is the target's, in its function and once the
   function has returned (§6.5, §6.9; *A Wrap's Fault Met in the Function Is the
   Target's*, *A Wrap's Fault After the Function Is the Target's*). And a fault sent to
   a listener, a socket or a started program ends it (§6.5, §8.4; *A Resource Ends at a
   Fault*).
8. **Three lines of the release review before 0.11.0**, each met by a first reader, placed
   2026-11-26 (the log's *The Release Review Before 0.11.0, Decided*). A help where a
   token means one thing, the test of 2026-11-11's `++`: an assignment `total = total +
   1`, `import` at a declaration's place, `after` outside its `receive`, a named argument,
   `fn(x) -> e`, and the mailbox help naming `Process.run` (*U2 25, N 27, M26, L31*, *N
   8*, *M22*), each text decided with the user. The tour's *Work anywhere*, which shows
   one node taking every compute where a reader who types at once sees the work spread
   (*L7*): which run the page shows. And the shell page's sentence that it runs in a
   container with no network, true of ernest-lang.org's server alone (*Z7*).
9. **`/robots.txt` and `/sitemap.xml`**, closed 2026-11-28 (the log's *Robots and the
   Sitemap Built*), taken before the release since the site is built from 0.12.0's tag
   (*Robots and the Sitemap Before the Tag*). The generator writes both: the first lets
   every crawler read every path and names the sitemap, and the second names every page
   but the 404 page under ernest-lang.org alone, which the site's proposal decided and
   MVP 4.2 did not build (*The Site's Proposal Read*). `docs/design/site.md`'s *The
   root* lists them, and the site's test holds them.
10. **What a first hour meets, decided**, the first family of MVP 4.5's item 176, taken
    before the tag with items 6, 8 and 9, decided with the user on 2026-11-28 (the log's
    *The First Hour Before the Tag*): entries 289, 294, 297, 305, 309 and 313 of
    [`language_feedback.md`](language_feedback.md), each a question where the report is
    true, which a reader of the announcement meets in a first hour. They are decided as
    item 176 says: the session searches the log for each and runs its program, and the
    user answers the family once. A verdict that is cheap to build is built for 0.12.0.
    Any other is an item of MVP 4.5, a line of the known issues, or dropped in the log.

## MVP 4.5 (`:trace f`, two requests to OTP, a decision on a listener, and what the line left), after the launch

The shell's second round, decided with the user on 2026-09-30 (the log's *The Shell's Second
Round*) and decided again on 2026-10-30 against the attached shell (the log's *The Shell's Second
Round, Decided Again*), and following the launch since 2026-11-05 (the log's *MVP 4.3 Becomes
MVP 4.5*): of its eight items one remains, three moved into MVP 4.0's shell, where
the operator's prompt is, and four were dropped with their verdicts in the log.

On 2026-11-19 the milestone took what the line left after the launch (the log's *The Line
Before the Launch*), each item under the number it had in MVP 4.16, and others were found
later. On 2026-11-21 those that only a built corner, a test or the host alone shows became
lines of [`known_issues.md`](known_issues.md), each naming the item it was (the log's *The
Plan Sorted Against the Known Issues*). A find of that kind gets its line there since.

Items 118 and 122 are taken first, since no reading of their kind has come back empty. Item
176 follows, since a need met in use is what drives a change, then items 1 to 4, then items
68, 96, 113, 158, 174, 165, 166, 168 to 173, 175, 177 and 178, and item 167 last, so that
OTP's answer to its report may come first. The numbered items stand first below and the
rest after them, in the order they are taken.

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
   termination and a second would end the program at once, decided then. `ern test` would
   then name the case that runs at an interrupt, the findings' *B5*.
4. **Whether `Tcp` hands a listener over**, feedback 261, added with the user on 2026-11-17
   (the log's *The Server's Answers*, its paragraph *A listener handed over*): a listener
   given to another process, or a listen beside a live one, so that a program takes new code
   with no connection refused between. A decision, and nothing is built: it is read against
   E.0's admission rules first, and then against ernest-httpd's proposal for new code while
   it serves, where that session writes one. Where neither comes, the item closes on a log
   line that drops the entry and says why. A certificate read again without a restart is
   weighed with it, the findings' *PL2 L17* (the log's *The Runtime at the Host's Limits*).

What the line left, in the order it is taken:

- **118. What a listed peer's dial meets while a node ends**, found 2026-11-18 by item
  116's reading (the log's *The Job Halts Without the Host's Flush*, its paragraph *Item
  118*), and not read. A node's host takes dials from `ern_carrier:depart/0` until its
  process exits, and that time is long while the end waits on a stalled stream. An agent
  first shows, on two nodes, what a listed peer that dials then is told, what its sends and
  its monitors meet, and which reason the node's exit gives it, against §8.7 and §12.6's
  *A node's end*. What it shows is brought to the user.

  The showing with a peer that stands still was made by MVP 4.16's item 124 (the log's *A
  Node's End Waits for No Send*). A peer that connects while the node stops is told
  nothing and says `lost`, which §8.7 now states. The mechanism is this item's, shaped
  on 2026-11-20: the node takes no connection once it stops, so that a late dial is
  refused and answers `Unreachable`. It touches the handshake's rule, and an agent first
  probes a dial already under way when the node begins to stop.

  This item keeps the window of an end that waits on a stalled stream too, which stays
  unread until then. Two things were read of it and not shown: between the processes'
  deaths and the flush's end a peer that connects is still told of the end, and a
  utilization is answered with the number. Whether a termination that ends a stalled
  flush (§12.4) tells the peers was not read.
- **122. Whether a socket's writes that time out are bounded**, found 2026-11-18 by item
  106's reading (the log's *What a Program's Helper Holds*). E.18 says of `Tcp.write` what
  E.23 says of `Os.write`: a `Left(Timeout)` does not undo the write. A socket's writer
  takes its writes from its mailbox one after another, so by a reading the writes that
  timed out wait there and nothing bounds them. An agent first shows what a writer to a
  socket whose far end reads nothing makes the node hold, and what gives it back. The
  shape then follows item 106's: E.18 says what the rule costs, and what is held past
  its use is mended.

  Shown by MVP 4.16's item 100's probes on 2026-11-21: a close ends the writer with the
  writes it still holds, and one answered `Left(Timeout)` and not yet given to the host is
  never sent, which E.18's "may" allows. Read from the host's driver and not shown: a
  write's milliseconds may also wait on the far end's taking of the write's own bytes,
  against E.18's sentence. This item starts from both and keeps the bound.
- **176. The full review's feedback, decided**, from MVP 4.4's item 5, placed 2026-11-26
  (the log's *The Feedback Held by an Item*): the 42 entries of
  [`language_feedback.md`](language_feedback.md) that the full review and the builds
  around it left, the 21 the release review before 0.11.0 added, entries 321 to 341,
  and entries 342 and 343, which a build of 2026-11-28 added, each a question where the
  report is true. Nothing is built before its verdict.

  They are decided by family, as the review's `decide` round was. The session searches the
  log for each entry and runs its program, and writes a verdict for each line against §0
  and E.0. The user answers once a family, taking a line out to decide it alone. A verdict
  is a change to the report, built as an item of this milestone; a line of
  [`known_issues.md`](known_issues.md); or a line of the log that drops the entry.

  The families, in the order they are taken:
  - what a first hour meets, 289, 294, 297, 305, 309 and 313, is MVP 4.18's item 10,
    decided before the launch;
  - the language's rules: 278, 283, 286, 292, 295, 304, 308, 314 and 317;
  - processes and calls: 287, 296, 300, 303 and 318;
  - the library's functions: 275, 277, 279, 280, 288, 298, 306, 307, 310, 342 and 343;
  - the system's modules and the terminal: 271, 285, 290, 291, 293, 299, 311 and 319;
  - the toolchain: 282, 284, 302, 315 and 316;
  - the release review's, 321 to 341, each placed in one of the six as the item starts.

  A line that a later release review files as `felt` before this item starts joins them.
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
- **158. A socket ended with what its host holds dropped**, feedback 270, found
  2026-11-21 by ernest-httpd's session on 0.10.0 (the log's *A Close Answers Once Its
  Bytes Are Sent*, its paragraph *Left at the close*). Nothing in `Tcp` ends a socket and
  drops what its host holds: after a close or a kill the bytes go on, for up to E.18's
  bound, to a far end the program has given up. That session's server gives a client up
  at a write past its deadline, and three waves of 16 such clients took its node from 107
  MiB to 225, outside its caps. E.18 is true and a kill does what 0.10.0's close did, so
  it stands here. The shape: a function of `Tcp` that ends a socket at once, its far end
  reading a reset, weighed on E.0's admission rules and decided with the user.

  Since 0.11.0 that server holds a client's place through its close's wait, so its caps
  count what the host holds, and the place is held for up to E.18's bound. Read again on
  2026-11-28 with MVP 4.18's item 1, it stays here (the log's *The Socket's Reset Stays
  After the Launch*).
- **174. A call's wait under a backlog**, a decision, from the findings' *H54*, decided
  2026-11-26 (the log's *The Applications' Lines Decided*). Its first step is a design
  session with the user, and nothing is built before it. A call's wait reads its caller's
  whole mailbox, which §10 states: 1,000 calls to an echo process took 2, 66, 130, 254 and
  501 ms with 0, 10,000, 20,000, 40,000 and 80,000 messages waiting, and `Os.resize` and
  `Tcp.write` grow alike, where the host's own `gen:call` does not.

  The host marks a wait only where every clause carries the fresh reference, and Ernest's
  has two that do not, a restart asked for and a fault delivered (`ern_rt.erl`'s
  `waited_answer/3` and `forever_answer/2`). *The Rows That Grew* of 2026-10-20 holds the
  one design known, an identity on every ask and a loop in every `receive`, and called
  none plain. ernest-httpd's session met the cost in a flood of resizes, past its
  backpressure. To decide: whether a plainer design exists, and whether the wait is
  marked.

  Feedback 301 is decided with it. A system module's call with a limit is written two
  ways, and they are the two waits this design reads: `Fs` through `Address.call`, and
  `Tcp` and `Os` through `ern_rt:call_limited/2`.
- **165. A test of the node's file that fails where `TMPDIR` is long**, from MVP 4.17's
  item 163 (the log's *The Known Issues Sorted*). `ern_os_tests:unopened_node_file_test`
  binds a Unix socket at the `ernest.pid` of a directory under `TMPDIR`, and fails with
  `einval` where that path passes the 108 bytes the host holds, as a session's scratch
  directory does. The failure is the test's, and says nothing of the code. The test's
  directory is made where its path is short, and the test is run once under a long
  `TMPDIR`.
- **166. `reload_waits_on_no_stopped_peer` failed once**, from MVP 4.17's item 163 (the
  log's *The Known Issues Sorted*), found by MVP 4.16's item 100's `make test-full` on
  2026-11-21 (*A Close Answers Once Its Bytes Are Sent*; was item 159). In one full run of
  four the maker said the stopped third's loss before the asker's end. Whether that order
  is the code's, which §12.5's reload would then break, or the test's own is not known.
  `make flakes` is run over the nodes' tests, and a failure is diagnosed; where none comes
  in an hour, the item closes on a log line. `make cover` failed it in each of its three
  runs on 2026-11-23, a way to make it show (the log's *The Helper's Failure Under
  Recording*). It failed one full run of three on 2026-11-28 (*A Far End's Read Missed
  the Record*).
- **168. A row of the library's bench in a process of its own**, found 2026-11-22 by MVP
  4.4's item 2 (the log's *The Cost's Rows Read*). `Bytes.toList` at 10,000 bytes reads 5.4
  times the host's with nothing added: in the harness's process a compiled call of
  `binary_to_list/1` takes 33 µs and the host's side, which applies its export, 12, and in
  a fresh process the sign flips. `Os.closeInput` reads 2.4 times as the first row that
  starts a program, 1.2 moved last, for a reason not found. `ern_measure` times each row
  in a process of its own, so that no row rests on the rows before it, and
  `Os.closeInput`'s first timing is read again after it. `docs/development.md` names the
  two rows as the harness's until then.
- **169. One list of generalized values**, from MVP 4.4's item 4, the findings' *W23* (the
  log's *The Language's Rules*). A top-level `let` is generalized where its initializer is
  a value (§4.6), and a `let` in a block only where it binds a lambda (§3.9), so `let one
  = List.take` serves two types at top level and one in a block. To decide with the user:
  §4.6's values for a block's `let` too, with what §4.8 calls a definition, a cold reading
  and the argument's paragraph. With it, the release review's *P1 10*: the help `annotate
  the value where it is bound` names no value, where what is annotated is the lambda's
  parameter. And the round's cold reader's sixth: a negated number literal is a constant
  and no value (§4.6), so `let t = #(fn(x) = x, -1)` is refused where `1` in its place is
  generalized.
- **170. A prelude type's members written with their prefix**, from the findings' *P1 18,
  K 27*. `int.ern` declares `fn Int.+` and, unprefixed, `fn compare` and `fn negate`,
  which costs an exception sentence in §4.2, in §4.8 and in Appendix F. The standard
  library writes `fn Int.compare` and `fn Int.negate`, and the three sentences go. No
  program meets the rule.

  Feedback 312 is decided with it: the `compare` of `Bool`, `Char`, `Float`, `Int` and
  `String` is one body written five times, in the lines this item rewrites.
- **171. A member's heading in `ern doc`**, from the findings' *P1 17, PL1 L21*. §4.2
  refuses a member of an exported type and an exported value of the module of its name
  that share a name, since the page heads both `Main.Stack.compare`. `ern doc` heads a
  member by its use form, and the rule goes with its error. The key a member's page is
  looked up by is decided with it, and `ern_docs` takes a member's type from the checker
  (the findings' *C3 Clarity 3*).
- **172. Whether a definition is still "lacked"**, from the findings' *PL1 L16, PL1 L24*.
  §12.7 has a unit export what its module exports, and a definition held in no exporting
  unit lacked, on one bench row of 19.5% from 2026-10-11, before the emitter's calls
  changed on 2026-10-27. The row is read again; where it is gone, a unit exports all and
  "lacked" goes, decided with the user.
- **173. Where a private format stands**, from the findings' *P3 11* (the log's *The
  Report Recut*). A floor is one release of `ern` on one major release of OTP, so every
  reader of a definition's form, and of §12.6's frames, is the toolchain that wrote it,
  and Appendix H's 140 lines bind no second builder. To decide with the user: the layout
  in the report, or in the design notes with the report keeping what a program sees, what
  a form holds and what makes two definitions one. `docs/soundness.md` cites the layout
  and follows.
- **175. What `Markdown` gives a tool that reports a line**, feedback 320, a design first,
  from the findings' *T8*, decided 2026-11-26 (the log's *The Applications' Lines
  Decided*). No block of `Markdown.parse` carries its line, so each reader that reports a
  line reads Markdown itself, and they differ over a fence. The design is read from what
  the five readers need, a paragraph's first line in one and each line's kind in another,
  before a type that every `match` over a block pays for.
- **177. The release review's questions, decided**, from MVP 4.4's item 5, placed
  2026-11-26 (the log's *The Release Review Before 0.11.0, Decided*): the 54 `decide`
  lines of the review before 0.11.0 that are questions where the report is true, a recut,
  a name, a second way, a help's text or a rule a program does not show false. A line is
  `findings.md`'s as it stood at `3051fbf5`, the last commit that holds it, with the
  user's verdict beneath it.

  They are decided by family as item 176's entries are, after the launch, the names each
  after its word is searched across the report, the code and the shell
  (`docs/reviews/release.md`):
  - a job's says and refusals, *P3 5*, *P3 8*, *P3 9*, *P3 15*, *P3 10*, *E2 3*, *P3 16*,
    *C5 clarity 12*;
  - an error's help, *C1 3*, *P1 21*, *P1 3*, *K 2*;
  - the report's recuts, *P1 20*, *P1 14*, *P1 18*, *P3 14*, *P2 21*, *P2 22*, *P2 23*,
    *P2 35*, *P3 Rules that buy little*, *P1 16, K 9, K Kept*;
  - which page owns a fact, *U1 12*, *N 18*, *U1 20, N Leftovers*, *N 23, M27, M28, M29,
    L26, U2 18, N Leftovers*, *U2 17*, *U2 15*, *M12*;
  - the library's names, *P2 31*, *P2 33*, *P2 32*, *U1 15*, *N Names*, *N Names*, *N
    Names, E3 L1*, *N 29*;
  - the type rules, *P1 11*, *P1 12*;
  - what the guides show, *N 17*, *L27*, *L6*;
  - processes, monitors and waits, *P1 8*, *P1 9*, *P2 30*, *P2 34*;
  - the library's promises, *P2 27*, *E1 C3*;
  - Appendix H, *P3 12*;
  - a second way, *P1 4*, *U1 17*, *P3 11*;
  - alone, *E3 C7*, *N 7*.

  With them, the parts that ten lines made for 0.11.0 left open: the text of `ern test`'s
  refusal of a copy (*P3 1*) and of the advice to compile a module first (*N 6*); whether
  the guide's §10 grows (*L3*); the rule for a field named as a member (*K 5*) and for a
  member declared at one instance (*K 3*); the message that names `Foreign.Term` for an
  alarm (*K 6*); whether `Markdown.render` escapes a control character (*S 2*); whether
  `Fs.makeTempDir` removes a directory another wrote into (*S 4*) and the two checks
  become one (*S 5*); and whether an interface's values are checked as it is read (*C2
  D4*).
- **178. An abandoned line's end drawn in its order**, from the review's *E2 1*, a line of
  [`known_issues.md`](known_issues.md) until then. Since the shell's build of 2026-11-26
  the session draws the end of a line `C-c` abandons, and the reader goes on drawing the
  keys typed after it, so during a `:load` or a `:reload` the transcript shows those keys
  as the abandoned line and the prompt stands empty over an editor that holds them. No
  input is lost. A diagnosis first, by one agent with `abandon.sh`: the reader draws the
  end again and the session's prompt waits on it, or the reader holds its keys until the
  end is drawn, with a test that types after `C-c` and `interrupts_in_one_read` still
  passing.
- **167. The map's square**, found 2026-11-22 by MVP 4.4's item 3 (the log's *The Raise's
  Walk Reported* and *The Sentence Alone for the Square*). A raise reads a recursion
  beneath it whole, OTP's defect (`docs/otp_bugs.md`, report 28), so `List.map` over 80,000
  texts that `String.toInt` refuses takes 2.7 seconds, against 5 milliseconds where each is
  an integer. §10 states the cost. Where a release of OTP that Ernest requires bounds the
  walk, the item closes on a log line. Report 28 is the user's to file, taken up on
  2026-11-23, and the wait for OTP's answer begins with the filing.

  To decide with the user otherwise, between two mechanisms and neither. The primitives
  that answer a refusal the host raises check first, `String.toIntBase`, `Bytes.fromHex`
  and `Float.div`: a refusal then takes no raise, each conversion that succeeds pays a
  scan, and `Json.parse` and a foreign function's raise stay. Or `List`'s recursions
  become loops, which covers every raise in a function `List` calls and leaves a program's
  own recursion. Neither closes the square, and each is weighed against E.0 rule 1 and
  against keeping no code only for speed.

---

## Milestones

| | What | Done | Release | Where its reasons are |
|---|---|---|---|---|
| MVP 1 | the chain: parser, types, BEAM | 2026-09-18 | commit `7913df85` | the log's entries of 2026-09-17 and 2026-09-18; [`architecture.md`](architecture.md) |
| MVP 2 | the rest of the report on one node | 2026-09-19 | | the log's entries of 2026-09-19 |
| MVP 2.5 | a complete standard library | 2026-09-20 | | the log's entries from 2026-09-18 to 2026-09-20 |
| MVP 2.9 | an Emacs major mode | 2026-09-23, out of order | | [`emacs_mode.md`](design/emacs_mode.md) |
| The report read as a Wirth report | the report read against Wirth's register and §0, about thirty issues decided one at a time | 2026-09-23 and 2026-09-24 | | the log's entries of those two days, one an issue |
| MVP 2.61 | the guide as the user's document | 2026-09-24, out of order | | the log's entries of 2026-09-24 |
| MVP 2.6 | the shell | 2026-09-25 | | [`design/shell.md`](design/shell.md); the log's entries from 2026-09-20 to 2026-09-25 |
| `libs/markdown` | a CommonMark renderer, now under MVP 4.1 | 2026-09-25 | | Appendix G.2 |
| The code read back after the shell | every line of Ernest and Erlang read for the principles, clumsiness and defects | 2026-09-25 | | *The Code Read Back* |
| MVP 2.65 | the language and the toolchain read back | 2026-09-26 | | the log's entries from 2026-09-25 to 2026-09-26 |
| MVP 2.66 | the standard library's `Supervisor` | 2026-09-27 | | the log's entries of 2026-09-27 |
| MVP 2.8 | the formatter | 2026-09-28, out of order | | the log's entries from 2026-09-27 to 2026-09-28 |
| MVP 2.7 | a program started from a command line, and the appendix of libraries | 2026-09-28 | | the log's entries from 2026-09-27 to 2026-09-28 |
| MVP 2.95 | manual pages, an installation, the review | 2026-09-28 | | the log's entries of 2026-09-28 |
| MVP 2.96 | a result annotation written with `:`, and a process's addresses taught | 2026-09-29 | | the log's entries of 2026-09-28 |
| MVP 2.98 | what the first review left | 2026-09-30 | | `findings.md` as it stood at `b7d34c0`, its readers' lists in its history to `08edfda`; the log's entries from 2026-09-29 to 2026-09-30 |
| MVP 2.99 | a restart begins afresh, and the first release | 2026-09-30 | tag `v0.1.0` | the log's entries from 2026-09-27 to 2026-09-30 |
| The principles review | the report and the guide against §0, and §0 against what it decided | 2026-10-01, and again 2026-10-09 before MVP 3.1 | | the log's entries from 2026-09-30 to 2026-10-01 |
| Ernest 0.2.0 | the review's rules shipped as one, after the release review | 2026-10-01 | tag `v0.2.0` | the log's entries of 2026-10-01 |
| MVP 2.99b | what the release review left, names that read among it; operations records: the requirement `needs a.compare`, a record filled from a namespace, an ordered set and an ordered map; running as a service | 2026-10-03 | | `findings.md` as it stood at `d6996f1`; `docs/proposals/operations/` as it stood at `42a51d22`; the log's entries from 2026-10-02 to 2026-10-03 |
| The full review's findings | the 570 findings of MVP 2.99c's item 6, worked before its release | 2026-10-05 | | `findings.md` as it stood at `0d2de61`; the log's entries from 2026-10-04 to 2026-10-05 |
| MVP 2.99c | the language argued: the type system's argument, generated programs, the grammar and the library's laws as machines; then a release, Ernest 0.3.0 | 2026-10-05 | tag `v0.3.0` | [`soundness.md`](soundness.md); the log's entries from 2026-10-01 to 2026-10-05 |
| Ernest 0.3.1 | the documentation rewritten: the manual pages, the examples, the guide and the report's precision, from MVP 2.99d's items 4, 5, 7 and 8 | 2026-10-05 | tag `v0.3.1` | MVP 2.99d's entries |
| MVP 2.99d | the library stands on the host, measured with the prelude and the emitted code, and the report's and the guide's feedback | 2026-10-06 | | [`otp_bugs.md`](otp_bugs.md); the log's entries from 2026-10-05 to 2026-10-06 |
| The shell shows a bracket's match | a closing bracket stands the cursor on its match, ahead of the shell's second round | 2026-10-06 | | *The Shell Shows a Bracket's Match* |
| MVP 3.0 | peers: one program on several nodes, by its proposal | 2026-10-09 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; the log's entries from 2026-10-08 to 2026-10-09 |
| MVP 3.1 | code by its hash: a hash for each definition, nodes of different builds on one floor, the shell's reload by hash, termination told, and `Standing`; then a read of what it built | 2026-10-10 | | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; the log's entries from 2026-10-09 to 2026-10-10 |
| MVP 3.25 | placing work by name: `Peer.compute` on a named peer, `Peer.utilization` with the node's measure its maintainer's, and `Placement` in `Balancer`'s place | 2026-10-11 | | the log's entries from 2026-10-11 to 2026-10-24 |
| MVP 3.26 | kill darlings: the reply's obligation and `!` gone, `receiving M` in place of `with M` on a function that receives alone, the value restriction relaxed for data, the held replies gone, and the guide's *A library that waits* | 2026-10-16 | | `docs/proposals/kill_darlings/` as it stood at `42a51d22`; the log's entries from 2026-10-14 to 2026-10-16 |
| MVP 3.2 | code with a spawn: the exchange, the bare node, every unit held for the node's life, and `Code`; then a release, Ernest 0.4.0, the first with nodes | the code by 2026-10-15; the release 2026-10-18 | tag `v0.4.0` | `docs/proposals/nodes_and_code/` as it stood at `42a51d22`; the log's entries from 2026-10-10 to 2026-10-18 |
| MVP 3.27 | measured across machines: the exchange's numbers of 2026-10-13 again between three machines on one LAN, the push against the pull across them, the spawn's end at the reaper and the bench's three other rows that grew measured piece by piece, every fault with a trace, the programs tests' limits derived, and the annotation out of the hash | 2026-10-21 | | the log's entries from 2026-10-20 to 2026-10-21 |
| MVP 3.28 | what stands before the tour: a clause's body all or none, which §11.6 states and `ern format` writes; `--libs-dir dir`; `--verbose`; and seven items the feedback left: four messages that name the form, the rules of an Ernest program installed, the libraries on the default load path, `ok` as `Unit`, `Test.faults`, the foreign call measured, and doc examples run by `ern test`; with what the builds found: a type and the module of its name share a namespace, a module under a taken namespace refused, `List.mapFold`, a mailbox type ending in `Msg`, the prelude's `Unit` as a descriptor word, a `make` with nothing to do measured, and each doc example a program of its own in a directory of its own | 2026-10-22 | | the log's entries from 2026-09-20 to 2026-10-24 |
| MVP 3.29 | the bookkeeping behind §8.6 on one rule, the look reads what a process marks and no operation writes a shared row: the foreign call's count gone for a read of the waiting process, the timed receive's and the call's marks in the process's own dictionary, every slow wait of the runtime's own marked and held by a test, the callees' row kept on a write-concurrent table and measured against two other kinds, a kill one function and a frame from another node; a ground `let` compiled to its term; the foreign cause naming the function; one checker of the library's examples; a launch a row of its own table, halved; the runtime's fixed waits and the tests' sleeps, polls and limits gone for waits on what each means; `make bench` with a memory of its last run and of the release's, by ratio; the language measured against the host's own Erlang, construct by construct and in three programs written twice; the runtime's design note; and a deadlock found among *Why Ernest*'s claims | 2026-10-22 | | the log's entries from 2026-09-19 to 2026-10-22 |
| MVP 3.295 | what the language measurement found: a `Float` operation the host's own with no `try`, the runtime reading a `badarith`'s frame, a chain of five from 1.65 to 1.23 times the host's and the ray tracer from 1.95 to 1.70; `Map.get`'s number closed as the type's; and the bench's parts as targets, its memory kept a table at a time | 2026-10-22 | | the log's entries of 2026-10-22 |
| MVP 3.296 | what the tour's outline asked: a restart runs the function it was given, stated in §6.9 and the deployment guide, with the guide's sentence that a binding is its node's own; `ern config --listen` and `--peer-dir dir`; the Erlang and the Gleam programmer reading `why.md` and `faq.md`, and every guide read for a word used before it is said; two messages the tour's spike found wanting; and the runtime's own frames out of a designed fault's trace | 2026-10-23 | | `findings.md` as it stood at `fd5b361c`; the log's entries of 2026-10-23 |
| The full review's findings before 0.5.0 | the 218 lines of the review run over `1329d1d2`: 159 `fix` made in ten batches by area and an integration pass, 52 `decide` taken one at a time, 9 dropped; the service monitor and `demonitor` added to the language, `Reply.process` and `compare` over tuples, lists, `Optional` and `Either` to the library, each with its page and its test | 2026-10-24 | | `findings.md` as it stood at `08997105`; the log's entries of 2026-10-24 |
| MVP 3.3 | the tour, `tour/`: a third way into Ernest beside the report and the guide, one program, the counter, grown through eight chapters from a process with a typed mailbox, through the same counter on a peer that holds none of its code, to its move to new code there, where the deployment guide takes over; with it a README for `report/` and for `guide/`, the README's three ways in, the guide's taste of the rest, and the path read by a fresh reader and the two skeptics | 2026-10-24 | | the outline, `docs/proposals/tour/` as it stood at `688ffa03`; the log's entries from 2026-10-10 to 2026-10-24 |
| MVP 3.9 | the review, and Ernest 0.5.0: the nodes' and the code's design notes, the proposals built by then swept, the full review and its findings, the process-only mark narrowed and a wrap's `self` its recipient's, what the lease broker found, the release review and Ernest 0.5.0, a release with no promise of stability | 2026-10-25 | tag `v0.5.0` | `findings.md` as it stood at `105fb3fc`; the log's entries from 2026-10-16 to 2026-10-25 |
| MVP 3.95 | what the review and 0.5.0 left: the release review read back, a restart told across nodes by the runtime's own frames, the harness counting a test's steps, the review round's method with an owner, the site proposal's sitting, the first fault's cost measured, the member regime's missing test, the teller's late delivery closed, dialyzer in the full run, and Ernest 0.6.0, the protocol's version moved | 2026-10-25 | tag `v0.6.0` | `findings.md` as it stood at `c6eab569`; the log's entries from 2026-10-24 to 2026-10-25 |
| MVP 3.96 | the report pared to the language, `language.md` holding what decides what a program means and the runtime's mechanism chapter 12 of `toolchain.md`, and what the paring found: the build's cost per function linear, one function per initializer, the nested group's third restart, the newcomer's feedback decided, the second cut to E.27, the comments' paragraphs, the emitter's calls as the host's, `<-` at the prompt and `Test.until` | 2026-10-30 | | the log's entries from 2026-10-25 to 2026-10-30 |
| MVP 4.0 | a shell attached to a running node: each input run on the node, its processes listed and its code loaded and reloaded from the prompt, as `erl -remsh` attaches, its proposal `docs/proposals/shell/attached.md` as it stood at `facbd285`; and the release review before 0.7.0, eight readers over what changed since 0.6.0, its fix lines and its eight batches decided and built | 2026-10-31 | tag `v0.7.0` | the log's entries from 2026-10-30 to 2026-10-31 |
| The pun | a field given or matched by the variable of its own name written once, `Desk(=local)`, swept over 874 sites with the style test holding it; the round that opened it, ten feedback lines decided and three rules built, a guard's field read, the shell's line by site, and the timed wait's effect, superseded the same day by a `receive` that always receives and `Clock.sleep`; an alarm that can be canceled; `make version`, Appendix D whole, the settler's restart tested, the guide's lines after the release review read; the three outside programs on floor 0.8 | 2026-11-01 | the release after 0.7.0 | the log's entries from 2026-10-30 to 2026-11-01 |
| Ernest 0.8.0 | a small release, the pun's: a doc example run at its own mailbox type, a census of forms over the repository's Ernest, a one-field request's reply declared positional and passed bare, and the release review before it, 92 findings | 2026-11-01 | tag `v0.8.0` | the log's entries of 2026-11-01 |
| MVP 4.1 | ernest-httpd, an HTTP/1.1 server in Ernest in a repository of its own, which serves ernest-lang.org since 2026-11-02, and what it asked of Ernest: TLS in `Tcp`, a program under a pseudo-terminal in `Os`, the libraries `base64`, `crypto`, `time` and `http`, seventeen lines of feedback decided the days they came, the terminal tests' harness in Ernest, and the release | 2026-11-03 | ernest-httpd 0.1.0, tag `v0.1.0` in its repository; Ernest 0.9.0 | the proposal `docs/proposals/httpd/`, gone with this row, the server's own at https://github.com/joagre/ernest-httpd/blob/v0.1.0/docs/proposals/basic/proposal.md; the log's entries from 2026-11-01 to 2026-11-02 |
| Ernest 0.9.0 | the server's release: what ernest-httpd asked of Ernest, and the release review before it, 112 lines fixed and 23 decided | 2026-11-03 | tag `v0.9.0` | the log's *The Release Review Before 0.9.0* |
| MVP 4.2 | the website, built and live with MVP 4.18's item 4: what Ernest is, its characteristics, the three doors, the tour, the guide, the report and the library's pages, generated from a tag by `make site`, the projects' page, the live shell's page side, and the browser test that holds it | 2026-11-06 | | the design note `docs/design/site.md`; the log's entries from 2026-10-05 to 2026-11-06 |
| MVP 4.15 | what the server taught: a node at the host's limits, of processes, of ports and of open files; nothing at the wait and memory shown; `kill` on a `Process`; text from bytes that are not all UTF-8; a worker's value or its end; a program's environment and a signal named; `libs/http`'s values and `libs/uri`; an error across a library; the libraries' shims read against E.0 rule 1; what a lambda's reach finds on a peer; relative names; a terminal that is gone and the host's warnings on standard error; the compiled modules the host cannot read or load, and a load past its limits; four refusals before the review; a listener's backlog; 48 items, the repository's layout between the first two, and the release review before 0.10.0 | 2026-11-10 | Ernest 0.10.0, tag `v0.10.0` | the proposals `docs/proposals/relative_names/` and `docs/proposals/errors_across_libraries/`, gone with item 15 (the log's *A Built Proposal's Sweep Is an Item*); the log's entries from 2026-11-02 to 2026-11-10 |
| Ernest 0.10.0 | the release of what the server taught, and the release review before it, which read the milestone's diff, 126 lines fixed and 25 decided in eighteen decisions | 2026-11-10 | tag `v0.10.0` | the log's *The Release Review Before 0.10.0* |
| MVP 4.16 | a deadlock's scope and its report, a package's manifest and build, the flake hunt, and what its builds and the outside reviews found; `Tcp.close` answers once its bytes are sent; the short rules stay and the known issues' list begins | 2026-11-21 | | the log's entries from 2026-11-11 to 2026-11-21 |
| MVP 4.17 | the shell's editing, what a job trusts, and the rest of packages: archives and the guide; `:keys`, the known issues sorted, and the OTP defects read against their issues | 2026-11-21 | | the log's entries from 2026-11-14 to 2026-11-21 |
| MVP 4.6 | the server owning both ends of its socket: the site's script imports the client the server ships, the generator takes no configuration and the browser test serves a stub client; the homepage and the blocks' tools; the stylesheet in the reader's font size; `Bytes.toHex` in lower case | 2026-11-22 | | the proposals `docs/proposals/ernest_httpd/` and `docs/proposals/homepage/`, gone with item 5; the log's entries from 2026-11-09 to 2026-11-22 |
| The full review's findings before 0.11.0 | the 929 lines of the review run over `93a13b13`, the principles review inside it: 446 made as plain fixes or as defects a report sentence states, 431 decided with the user, 52 filed; and the 51 lines the three applications' reviews found of Ernest's, 9 fixed, 20 decided, 4 felt, 6 an item's and 12 dropped | 2026-11-26 | | `findings.md` as it stood at `ab68ef61`; the log's entries from 2026-11-23 to 2026-11-26 |
| MVP 4.4 | the road's last milestone before a program: the promise of stability dropped, Ernest staying at 0.x; what each row of the bench may pay, read and decided, with §10 stating it; what a raise reads, the depth staying 64; the full review, the principles review inside it, with the three applications' lines; the mechanisms read against what they force, every row staying; a result that is never empty, the type staying `List`; and the release review and the release of 0.11.0, on Linux; its item 6, the site live, moved to MVP 4.18, and the two releases that follow 0.11.0 with it | 2026-11-26 | Ernest 0.11.0, tag `v0.11.0` | the log's *MVP 4.4, the Road's End*, *The Cost Read*, *What a Raise Reads*, *The Full Review Closed*, *A Result Never Empty, Built* and its entries of 2026-11-26 |
| The release review's findings before 0.11.0 | the 382 lines of the review run over `6c6b8ef1`: 198 `fix`, made by two writers and eleven builders; 123 decided with the user in eleven families, 47 made, 54 MVP 4.5's item 177, 3 MVP 4.18's item 8, 7 lines of the known issues, 10 dropped, one item 169's and one done; 39 filed; 22 matters of clarity dropped; and the round's cold reading of the review's own diff, 18 defects and 6 matters of clarity, four decided sentences among them read otherwise | 2026-11-26 | | `findings.md` as it stood at `3051fbf5`; the log's entries of 2026-11-26 from *The Release Review Before 0.11.0, Its Readers* |
| Ernest 0.11.0 | the release of packages, and of the language, the library and the toolchain held against each other, with the release review before it | 2026-11-26 | tag `v0.11.0` | the log's *Ernest 0.11.0* |
| MVP 4.18 | what ernest-httpd's review found of security, the release of 0.12.0, the three applications' releases on it, the site live at ernest-lang.org and the announcement: the launch; a decision on which libraries become packages; three faults that vanish, from the known issues; three lines of the release review before 0.11.0 that a first reader meets; the site's `/robots.txt` and `/sitemap.xml`; and the six entries of the feedback that a first hour meets, decided | | | above |
| MVP 4.5 | the shell's second round, two requests to OTP, for what a purge needs and for the interrupt, a decision on a listener handed over, and what the line of 2026-11-19 left after the launch: six items of MVP 4.16, a test and a flake from the known issues' sort, the library bench's rows each in a process of its own from MVP 4.4's item 2, the map's square from its item 3, five decisions from its item 4, the 42 entries of the feedback file that the full review left and the 21 of the release review before 0.11.0, decided by family, that review's 54 questions where the report is true, and an abandoned line's end in the shell | | | above |
