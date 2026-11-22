# Plan

The roadmap: what will be built, in what order, and what is built already. Why anything is the
way it is belongs to [`log/`](log/README.md), what the language is to
the report in [`report/`](../report/), how the code is arranged to
[`architecture.md`](architecture.md), and the commands and what the toolchain does not do yet
to [`development.md`](development.md).

Read "Where we are" first, then the milestones to come, in order; the table of every milestone
ends the file. A gap stands in the milestone whose item closes it, a defect of OTP's in
[`otp_bugs.md`](otp_bugs.md), a corner that only a built program meets in
[`known_issues.md`](known_issues.md), and a feature declined in a dated entry of the log; nothing
stands between.

---

## Where we are

**Ernest 0.10.0 is the last release**, of 2026-11-10, and the checkout works toward 0.11.0. The
table's rows for MVP 4.15 and Ernest 0.10.0 say what it holds. No promise of stability is made,
and a change to the language, the standard library or the libraries is driven by a need met in
use and recorded as `docs/language_feedback.md` records one. Ernest stays at 0.x until someone
outside the project depends on it, as MVP 4.4's opening says.

**MVP 4.6's items 2 and 4 are done since 2026-11-22. The next item is MVP 4.6's item 5**,
the proposals' reading and sweep.

The milestones to come, in order: MVP 4.6, MVP 4.4, whose release is the
launch, and MVP 4.5 after it. Each section's opening says what the milestone is and names the
log entry that placed it.

**A line stands before MVP 4.4**, drawn on 2026-11-19 (the log's *The Line Before the
Launch*). A sentence of the report that a program shows false is mended before MVP 4.4, by a
narrower sentence first. A reading not yet made, a cost, a question where the report is true
and a report against OTP stand in MVP 4.5. Each item is judged against that test when it is
written and before it starts. Since 2026-11-21 a find that only a built corner shows gets its
line in [`known_issues.md`](known_issues.md), and becomes an item when the user takes it up
(the log's *The Short Rules Stay*).

---

## MVP 4.6 (the server owns both ends of its socket, the homepage, and a digest in lower case), a few days, before the launch

Decided with the user on 2026-11-09 (the log's *MVP 4.16, the Proposals Before the Launch*), the
proposal [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md), and moved before the
launch on 2026-11-10, once the server's reset under load was fixed and the three floors stood at
0.10 (the log's *MVP 4.6 Before the Launch*). The site's script spoke the server's wire, its
generator read the server's configuration and its browser test stubbed the server's socket, and
item 2 put a client the server ships in place of each. The order keeps the proposal's: the
server's part first, which adds and takes nothing away, and no day but the launch's switch
changes both repositories, on a path the rehearsal has walked.

1. **The ask**, done on 2026-11-10 (the log's *The Client's Interface Agreed*). The server
   serves the client as its design's *The client* states it, and the rehearsal serves it at
   `https://ernest-lang.org:8443/` until the launch's switch. The server's part goes into
   the release its item 5 makes for the launch.
2. **Ernest's side**, done on 2026-11-22 (the log's *The Server's Client in the Site*).
   `site.js` imports the client, the generator and `make site` take no configuration, and
   the browser test serves a stub client. The rehearsal serves the site built from it, and
   ernest-lang.org takes it with the launch's switch.
3. **The homepage and the blocks' tools**, done on 2026-11-19, ahead of this milestone (the
   log's *The Homepage Built*), the proposal
   [`proposals/homepage/`](proposals/homepage/README.md). The opening's last clause came
   with MVP 4.17's item 119, on 2026-11-21, and item 2 reads the site's design note as
   this item left it.
4. **The stylesheet's units**, done on 2026-11-22 (the log's *The Stylesheet's Units*).
   The page follows the reader's font size and measures as before at 16 pixels, and what a
   phone at 24 showed past its box was fixed with it.
5. **The proposals' reading and sweep**, before MVP 4.4's release. [`proposals/ernest_httpd/`](proposals/ernest_httpd/README.md)
   and [`proposals/homepage/`](proposals/homepage/README.md) are read for what they hold
   that no owner has yet, in a reading decided with the user. That goes to the site's
   design note or the log. The item removes each directory once this milestone's row names
   the log entries that argue it and nothing else cites the directory.
6. **A digest written in lower case**, feedback 273, added with the user on 2026-11-22 (the
   log's *Three Feedback Entries Decided*), before MVP 4.4 so that its full review reads it.
   `Bytes.toHex` writes upper case (E.20), and `Ernest.Unpack` and `tools/site.ern` lowercase
   what it writes, while `Uri`'s percent-encoding keeps the upper case RFC 3986 asks of it.
   **The decision, its shape**, the user's when the item starts. The recommendation:
   `toHex` writes lower case, as the host's `binary:encode_hex/2` can, and `Uri` uppercases
   its own escape; least surprise decides (§0's principle 1), since a digest and most
   languages' hexadecimal are lower case, and one way seconds it (principle 2), against a
   second function beside `toHex`. E.20's line, the examples of `Crypto` and `Bytes`, the
   two sites' second step and the tests they hold change with it.

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

   It is taken before item 2, whole, decided with the user 2026-11-19 (the log's *The Plan
   Read for Build Order*). Its reading says what a raise does with the stack beneath it,
   which item 2's one candidate and item 123 rest on. Its verdict may change the depth,
   which E.28 and §10 state, or add the bench a row for a raise beneath a deep stack, and
   item 2 then reads the bench once.
4. **The full review**, as `docs/reviews/full.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says.

   A finding that meets one of MVP 4.5's items 68, 96, 103, 113, 118, 122, 134 and 140 is
   sorted to that item. It comes before the launch only where a program shows a sentence of the report
   false (the log's *The Line Before the Launch*).

   Before its readers start:

   - **Eve beside nike**, to decide with the user, raised 2026-11-19. The review's clone
     builds and runs `make test-full` on committed code while the readers read, and eve,
     alone of the other machines, could run it beside nike. CLAUDE.md's *What is the user's* keeps another machine to tests
     of nodes across a network, so that rule changes first, in the template, or the clone
     stays on nike. Recommended: eve runs the clone, which needs committed code alone. A
     second machine was weighed for an item's build the same day and helped nothing there.
   - **The tools weighed.** `tools/paragraphs.sh`, `tools/comments.sh` and
     `tools/unicode_width.escript` are weighed against CLAUDE.md's *The work*, each
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
   - **The other repositories take their manifests**, MVP 4.17's item 10, moved here on
     2026-11-19 (the log's *The Plan Read for Build Order*). The write is the floors' rise:
     a manifest's `ernest` line takes the place of the Makefile's `ERN_VERSION`, and no
     release before the launch's reads a manifest. ernest-template is first, with its
     Makefile cut, and ernest-epx's release carries its host part as the proposal's
     question 5 says.

     Ernest's session writes it against the archive of the commit the readers are to read,
     and runs `make` in each. A defect of Ernest's that the three show is mended and the
     archive made again, before the commit is named and the readers start. What fails for
     the application's own code goes to its session in the message.

     - **Who writes what**, decided with the user 2026-11-11. This session writes the
       packages' part in the three, their sessions closed, as a change across the
       repositories in their shape alone (`docs/clean_room.md`): each manifest, the
       template's Makefile and `TEMPLATE.md`, and ernest-epx's moved files and Makefile.
       ernest-epx's release stays its own session's. So do ernest-httpd's four matches on a
       bare `Process.Calling`, which take `Process.Calling()` then, since MVP 4.16's item 3
       gave it fields (E.21).
     - **An installed program**, decided with the user 2026-11-13 (the log's *An Installed
       Program's Packages*). The launcher gives `--package-dir` with its root and loses its
       loop, and `make install` copies `package.conf`. A program's own Erlang is named from
       a directory of its own, `erl` in a checkout, so that `lib` holds the named packages
       alone. `ern_unpack_tests`' `priv_test` holds a `priv` found through `code:priv_dir`, since MVP
       4.17's item 8.
     - **The template's archive**, found 2026-11-14, reading ernest-epx's release step. It
       holds a library's Erlang under `lib/<name>/ebin` and `lib/<name>/priv`, each link
       copied through, where §11.9 has a package's Erlang under its own `ebin` with its
       `priv` beside it. The item moves it there, and holds the archive it makes to `ern
       unpack`'s rules on an archive's members.
   - **The packages proposal's reading and sweep**, MVP 4.17's item 23, moved here with
     item 10. It follows the manifests' write, which is the last that reads the proposal,
     and comes before the release, as *A Built Proposal's Sweep Is an Item* places one.

   Beside it, on the user's word, ernest-template, ernest-epx and ernest-httpd are each reviewed
   whole by their own sessions, by the `docs/full_review.md` each took at the layout's stop,
   against the archive of the commit the readers read; ernest-httpd's review has a security
   reader, since it goes public at item 6. What they find of Ernest's comes as lines of
   their feedback files and is sorted in this round (the log's *The Applications' Full
   Review*, *Ernest Stays at 0.x*).

   As they begin, the three floors rise to the launch's minor, since a development build of
   the floor is what an archive before the release is (the log's *The Floors and the
   Releases*). The rise is the manifests' write above. Ernest's session then names the minor,
   the archive's path and its commit to all three by a message, and asks for the reviews, on
   the user's word. Each application's own session opens on the new floor, changes what its
   code needs there and begins its review.

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

   The announcement, the user's `~/announcement.txt` outside the repository, shows a shell's
   start line. `make version` does not write it and no test holds it, so the user sets it to
   the release's version before sending it (the log's *The Front Page in the Announcement's
   Manner*).
6. **The site live at ernest-lang.org**, last, so that each project it lists builds on the release
   it names (the log's *The Site Goes Live With 1.0*, *Ernest Stays at 0.x*): `make site` from
   that tag, the copy of `build/site/` to the host, and the smoke test against the live site.

   Before the copy, ernest-epx's published archive is taken as `site/projects.md` says, by an
   entry in a `package.conf` and `ern unpack`, since MVP 4.17's item 9 wrote the sentence
   before that release. Where it fails, the site waits for the archive.

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
7. **The mechanisms read against what they force**, read and closed 2026-11-21 with every
   row staying (the log's *The Mechanisms' Reading Closed*).

## MVP 4.5 (`:trace f`, two requests to OTP, a decision on a listener, and what the line left), about two weeks, after the launch

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

Items 118 and 122 are taken first, since no reading of their kind has come back empty. Items
1 to 4 follow, then items 68, 96, 113, 158, 165 and 166.

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
  in an hour, the item closes on a log line.

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
| MVP 4.16 | a deadlock's scope and its report, a package's manifest and build, the flake hunt, and what its builds and the outside reviews found; `Tcp.close` answers once its bytes are sent; the short rules stay and the known issues' list begins | 2026-11-21 | | *A Deadlock of the Whole Program*, *A Package and Its Manifest*, *The Root Package Read*, *The Named Packages Built*, *The Flake Hunt*, *The Review's Feedback Decided*, *One Copy of the Pages*, *The Synopsis's Rule*, *A Status Read Before the Watch*, *A Hiding Module Refused*, *The Ownership Test Built*, *A Given Path Resolved Once*, *The Proposal Held Against the Report*, *One Namespace at the Root*, *An Installed Program's Packages*, *The Client's Line*, *What One Read Answers*, *Building*, *The Sentences Held by Tests*, *A Compiled Form's Sources*, *A Document Beside a Module That Fails*, *A Library's Function in a Program*, *The Sweep's Reading*, *What the Toolchain's Page Is Made From*, *The Front Page From Its Motive*, *The README's Top Comes First*, *The Front Page in the Announcement's Manner*, *The Shell's Last Line*, *The Named Packages Read*, *The Reading's Round*, *The Rules Read Against Each Other*, *The Milestone Split*, *No Module's Source*, *An Index That Is No File*, *A Sender That Outlives Its Run*, *The Rules Read for Clarity*, *A Limit Ends Its Own Test*, *Three Orders the Supervisor Tests Read*, *A Delivery Counted Before Its End*, *A Listener Closed Before Its Accept*, *Seven Entries of the Feedback*, *A Program's Line Beside the Prompt*, *A Program Named Before It Runs*, *A Subscriber That Ends Beside Main*, *A Terminal's Echo Beside Its End*, *A Signal Before the Pause*, *A Reaper That Outlives Its Runner*, *Two Hours for a Hunt*, *A Termination Lost With OTP Alone*, *A Message at a Checker*, *The First Start's Schedulers*, *Twenty-Six Hosts Are the Cost*, *Two Orders Stated*, *The Watcher Holds Who Waits*, *No Restarted After a Death*, *The Style Test Reads the Roots' Tests*, *The Resize Told by Its Signal*, *The Review Documents Read Against the Rules*, *Three Process Documents Read Against the Rules*, *Two Tests Wait for Their Subscriber*, *A Record After a Cancel*, *A Port Another Socket Holds*, *The Busy Wait Stays*, *What a Load Could Not Load*, *Each Failure Once*, *Lanes in Place of Chunks*, *One Way to Start a Line Session*, *A Port Its Listener's Connections Left*, *A Home of the Run's Own*, *The Hunt's Rounds Tested*, *A Status Lost to a Write*, *A Checker Among the Processes*, *The Outside Reviews Read*, *What Waits for a Peer*, *What a Full Buffer Holds*, *A Connection That Cannot Drain*, *A Head in Pieces, Tested*, *A Lock Held to the Process's End*, *A New OTP and Nothing Else New*, *The Runtime's Processes Wait on No Peer*, *A Message Is Placed in Parts*, *What a Program's Helper Holds*, *Suspended Is the Host's Word*, *What a Peer's Worker Waits On*, *The Type Lines Are Held*, *The Run's Home Stated Once*, *A Checker Acts for the Target*, *The Job Halts Without the Host's Flush*, *A Termination Ends a Stalled Flush*, *A Check Stands Through a Loss*, *A Down Follows the Send*, *The Roots' Unit Tests Under the Run's Home*, *A Body, Tested*, *G.11 States What a Client Sends*, *An ASCII Case in the Library*, *A Header's Name in ASCII Case*, *A List Header's Elements*, *The Process Behind a Check*, *The Process Behind a Check, Built*, *A Bad Message's Fault to a Foreign Target*, *A `monitor` in an Adapted Address's Function*, *The Runner Waits for No Line*, *The Shell Ends at Once*, *`ern test` Ends by a Signal That Cut an End*, *A Subscriber Named Unanswered*, *A Node's End Waits for No Send*, *The Disconnect Waits for Nothing*, *A Worker Waits on No Third Node*, *An Address Given Back, on Another Node*, *One Check for an Address of a Recursive Type*, *A Fault at a Wait Names Its `receive`*, *A Process Printed with a Dot, Built*, *One Check by the Type's Hash*, *What the Boundary Trusts at a Type Variable*, *Three Corners of a Diagnostic*, *A Wait for a Life, Built*, *An Order Nobody Promised*, *The Order Through One Check*, *The Two Closes Answer*, *Two Shell Sessions Written*, *A Send and a Call in Two Inputs*, *The Close Follows the Last Byte*, *A Failed Write Loses What Had Arrived*, *A Close Answers Once Its Bytes Are Sent*, *The Short Rules Stay* |
| MVP 4.17 | the shell's editing, what a job trusts, and the rest of packages: archives and the guide; `:keys`, the known issues sorted, and the OTP defects read against their issues | 2026-11-21 | | *The Milestone Split*, *The Homepage and the Shell's Editing Planned*, *The Plan Read for Build Order*, *The Trust Said Once*, *A Refusal Holds No Control Character*, *An Input Edited by Its Lines*, *The Shell Says a Refusal in the Jobs' Words*, *Each Value in the Escape of Its Own Notation*, *The Live Region Named Once*, *A Window onto the Input*, *A Window onto the Input, Built*, *SHA-256 Beside SHA-1*, *An Archive Read by the Host*, *A Package in the Guide*, *The Keys Listed by `:keys`*, *The Known Issues Sorted*, *The OTP Defects Read Against Their Issues* |
| MVP 4.6 | the server owning both ends of its socket, the homepage, and a digest in lower case | | | above |
| MVP 4.4 | the cost analysis, the full review and the launch's release, Linux | | | above |
| MVP 4.5 | the shell's second round, two requests to OTP, for what a purge needs and for the interrupt, a decision on a listener handed over, and what the line of 2026-11-19 left after the launch: six items of MVP 4.16, and a test and a flake from the known issues' sort | | | above |
