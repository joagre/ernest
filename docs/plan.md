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

**Ernest 0.10.0 is the last release**, of 2026-11-10, and the checkout works toward 0.11.0. The
table's rows for MVP 4.15 and Ernest 0.10.0 say what it holds. No promise of stability is made,
and a change to the language, the standard library or the libraries is driven by a need met in
use and recorded as `docs/language_feedback.md` records one. Ernest stays at 0.x until someone
outside the project depends on it, as MVP 4.4's opening says.

**MVP 4.6 is done since 2026-11-22. MVP 4.4's item 4, the full review, is at its last
step.** Ernest's own review is done: the four legs, every decided line of the findings
closed, the ten questions that waited answered and built, and `make test-full` passing on
`f02be453` (the log's *Ernest's Own Review Done, and What Item 4 Still Holds*).

**The sort of what the applications' reviews found of Ernest's is made**, 2026-11-26 (the
log's *The Applications' Lines Sorted*). The 51 lines of the three repositories'
`docs/language_feedback.md`, each reproduced against `c9a0d66d`, stand in
`docs/findings.md` under *The applications' lines*: 9 `fix`, 20 `decide`, 4 `felt`, 6 an
item's and 12 `dropped`, and seven of the session's own that the readers met on the way.
The fixes are made: their sentences, a test for each, the pages of the declarations
they touch and *Z15*'s mend of `ern doc --verbose` (the log's *The Plain Fixes' Tests*).

**The `decide` lines are answered and built**, the 20 and feedback 281, which the user
added: each under its line in the findings (the log's *The Applications' Lines Decided*
and *The Applications' Lines Built*). `make test` passes.

**Next, the close of item 4.** `make test-full`. Then each session is answered by a
message as `docs/clean_room.md`'s *The answer* says, the answers drafted under the
probes directory's `mvp44_item4/apps/messages/`, with an archive made on the user's
word. Then `docs/findings.md` goes, the review's entry is written with its counts, and
item 4 closes.

Leg 4's entries in the log are *The First Build of Leg 4*, *The Renames
of the Library's Names*, *The Runtime's Second Build*, *The First Fable Round*, *The
Nodes' Build*, *The Libraries' Build*, *The Second Fable Round*, *The Cli's Build*, *The
Third Fable Round*, *The Session Stays on Fable*, *The Shell's Build*, *The Report's
Own Lines*, *The Shell's Second Build*, *The Tests' Build*, *The Blocks Checked*, *The Terminal's Stylesheet*, *The Language Guide Recut* and *The Other Guides, the Tour
and the Front Pages*, *The Decided Lines Audited*, *The Audit's Build*, *The Documents' Lines*, *The Parser Held to Appendix A*, *The Session's Own Lines*, *The Full Check, and
Dialyzer's Nine*, *The Ten Answered*, *A Function's Result Crosses*, *The Interrupt Ends a
Running Load*, *The Three Terms and §12.9*, *A Part's Anchor* and *Ernest's Own Review Done, and What
Item 4 Still Holds*.

The changed sentences of §3 to §9 were read cold 2026-11-24 in a copy of the report, 59
finds under their lines as *Read cold 2026-11-24*, 37 plain and 21 for the user, answered
the same day, with *Z13* and *Z14* closed (the log's *The Changed Sentences Read Cold* and
*The Cold Reading's Answers*).

The copy took the answers, and what they change was read cold once the same day: 32 finds
under their lines as *Read cold again 2026-11-24*, 26 plain and applied in the copy, and
six for the user, answered the same day, the copy taking them and its long paragraphs cut
(the log's *The Answers Read Cold* and *The Answers Read Cold's Six*). The readings were
made 2026-11-23 (the log's *Leg 4's Readings*) and answered by the user 2026-11-24, 27
answers taken one at a time, each under its line (the log's *Leg 4's Answers*).

Four verdicts were taken back:
`Supervisor.group` spawns at its call, `Proxy`'s hook stays, a compute that picks
answers `Unreachable` where it holds no utilization, and the deployment guide keeps its
row for a certificate that names another host. §7.4's sentence on an argument outside a
domain was written a third time. Three lines are new: *Z10*, decided, *Z11*, a fix, and
*Z12*, decided. Where an answer sends its builder to check a thing first, its line says
what comes back to the user.

The three applications were told the renames and the first build's answers 2026-11-25,
with an archive of `0a0a14ea`. The `1r` and `1` lines of `docs/findings.md` are written (the log's
*The Plain Lines of Leg 4*), but four `1` lines a build must make, which the findings' note
names. The leg goes on so: the `2a`, `2b` and decided lines by agents, one brief to an owner
holding all its lines and those four among them. Each decided line holds its verdict
beneath it, and a verdict that says a reader reads first, or that a line comes back to the
user, is done so.

Four verdicts were changed after the round, and a cold reading of the decided lines mended
thirty places more, twenty plainly and ten with the user. Their lines say so (the log's
*Four Verdicts Changed After the Round*, *Before Leg 4 Builds* and *The Ten of the Cold
Reading*).

Two readers then read the report whole against the verdicts, one `report/language.md`
and one the other two files, and found 64 places more. Most are a sentence a verdict
made stale without naming it, and are mended in the verdicts' lines. Three verdicts
were taken back: a standard namespace stays taken at every depth, `OrderedSet`,
`OrderedMap` and `Random` stay in Appendix E, and §7.4 sorts no domain by kind (the
log's *The Report Read Whole Against the Verdicts*). The next cold reading is of the
report itself, as leg 4 changes it.

Its third leg, the `decide` round, closed 2026-11-23: the sort checked, the sentences
for §0 and E.0, the twenty-two families, the line that stood alone and the batch of
refusals that rested on a count, each under its entry of the log for that day, from
*What a Diagnostic Says* to *The Refusals That Rested on a Count*.

Its first two legs, the decisions before the readers and the readers, closed 2026-11-23.
Items 2 and 3, the cost and the raise a primitive catches, are closed since 2026-11-22,
and item 8, a result that is never empty, since 2026-11-23.

The milestones to come, in order: MVP 4.4, whose release is 0.11.0; MVP 4.18, whose release,
0.11.1, is the launch, with the site live and the announcement; and MVP 4.5 after it. Each
section's opening says what the milestone is and names the log entry that placed it.

**A line stands before MVP 4.4**, drawn on 2026-11-19 (the log's *The Line Before the
Launch*). A sentence of the report that a program shows false is mended before MVP 4.4, by a
narrower sentence first. A reading not yet made, a cost, a question where the report is true
and a report against OTP stand in MVP 4.5. Each item is judged against that test when it is
written and before it starts. Since 2026-11-21 a find that only a built corner shows gets its
line in [`known_issues.md`](known_issues.md), and becomes an item when the user takes it up
(the log's *The Short Rules Stay*).

---

## MVP 4.4 (the cost, the full review and the release of 0.11.0)

Decided with the user on 2026-10-31 (the log's *MVP 4.4, the Road's End*): the road's last
milestone before a program, so that the review reads a language that ernest-httpd,
the website and the operator's prompt have used. After it the road is a program's.

Its release is the next minor of 0.x, decided with the user on 2026-11-05. It is not the
launch since 2026-11-23: the site goes live and the announcement is sent with 0.11.1, MVP
4.18's, once what ernest-httpd's review found of its security is mended (the log's *The
Launch Is 0.11.1's*). What the full review decides is still built for 0.11.0. Ernest stays at 0.x
until someone outside this project depends on it, so that a break would cost them something,
and 1.0 has no date (the log's *Ernest Stays at 0.x*, which keeps what 1.0 will promise).

The milestone was set at about four weeks before the full review decided 427 lines. Leg 4
says what is left once its readings are in, and no figure stands until then.

1. **The promise**, dropped 2026-11-05 (the log's *Ernest Stays at 0.x*).
2. **The cost**, read, decided and closed 2026-11-22 (the log's *The Cost Read*, which names
   the entry of each decision and each build). Each row of the bench at twice the host's or
   more is by design, with what it buys and the rate at which a program feels it, or was a
   defect and is built. §10 states what a row may pay, and `docs/design/runtime.md`'s *What
   an operation may cost* holds the rules, with `guide/why.md`'s cost claims held to them.

   What the item left: three lines of `docs/known_issues.md`, a crowd of faults reported
   slowly, a copy onto itself under a capability or a policy by path, and the shell's
   comparison of two source roots; MVP 4.5's item 168, the library bench's rows each in a
   process of its own; the bench's reference tables, which the release makes again, since
   the rows moved; and item 8, which its close found.
3. **The raise a primitive catches**, read, decided and closed 2026-11-22 (the log's *What a
   Raise Reads*, which names the entry of each decision). A raise reads a recursion of one
   call beneath it whole, a defect of OTP's, `docs/otp_bugs.md`'s report 28, whose filing is
   the user's. The depth stays 64. §10 and E.28 say what a raise reads and what the host
   keeps, the bench holds a row for a raise beneath 100,000 frames of one call, and what
   Ernest could build against the square a map meets is MVP 4.5's item 167.

   Item 2 and the known issue of a crowd of faults, MVP 4.16's item 123 once, rest on two
   things the reading showed. A trace's terms are built only where a catch uses the stack
   trace or the error ends the process. An entry of the stack a raise saves is a word,
   beside the arguments of a host function that raised, which the trace keeps. And the
   bench's host twin ran its rows beneath forty frames on a shallow stack until this item, so
   the ratios of those rows in the log before 2026-11-22 are too high, a refused `String.toInt`'s by about a quarter and a fault's by about a tenth.
4. **The full review**, as `docs/reviews/full.md` says, the principles review inside it, over the swept
   form after the pun and with the three programs written since 0.7.0; its findings sorted and
   worked as it says.

   A finding that meets one of MVP 4.5's items is sorted to that item. It comes before the
   release only where a program shows a sentence of the report false (the log's *The Line
   Before the Launch*).

   It runs in four legs, each ended by a commit, decided with the user 2026-11-23 (the log's
   *The Full Review in Four Legs*). The session stops at each cut and tells the user the
   model to switch to, since a session's model changes only after a `/clear`:

   1. The stronger model: the decisions before the readers start, closed 2026-11-23 (the
      log's *The Decisions Before the Readers*). The review's clone stays on nike, where it
      builds and passes before the readers start, as `docs/reviews/release.md`'s first step
      says, and no rule changes. The checker says nothing of a private function no code
      calls, as §0's principle 3 has it. The three tools are written in Ernest.
      `docs/soundness.md`'s section 7 is recut, and its section 1 names the two claims
      beyond the four.
   2. The coding model at the stronger effort: the builds before the readers start, the rest of the list below.
      Then the readers are started, and their lists are written whole into the findings
      file. The principles review runs merged with it, 31 agents, decided with the user
      2026-11-23 (the log's *The Principles Review Inside*). Closed 2026-11-23 with 36
      readers, their lists whole in `docs/findings.md` (the log's *The Full Review's
      Readers*), and the lists pre-sorted on the coding model into lines, decided with the user (the
      log's *The Findings Pre-Sorted*).
   3. The stronger model: the sort checked, every `3`, `2b`, `1r` and `4` line read with its
      finding and a sample of `1` and `2a`, a line that needs judgment moved to `3`, and a
      plain defect that no report sentence covers moved to a fix. Then the `decide` lines
      with the user, the sentences for §0 and E.0 first and then each family, each verdict
      and each fix's shape written into the findings file. The stronger model writes a verdict for each
      line of a family and marks the lines whose verdict does not follow plainly, and the
      user answers once a family, taking a line out to decide it alone. In each family the
      lines come first that show the report false or contradicting itself, that touch
      soundness or security, or that a first user meets. Closed 2026-11-23 (the log's
      *The Refusals That Rested on a Count*).
   4. The coding model at the stronger effort, and the stronger model since 2026-11-26 (below): the `1` and
      `1r` lines by the session, the `2a`, `2b` and decided
      lines by agents, one brief to an owner holding all its lines, the libraries' with the
      standard library's and the examples' and the site's with the tests', the diffs
      read back,
      `make test-full` and the close. It opens with the findings' *Before leg 4 builds*,
      in this order: the readings a verdict asks for first, and what comes back brought
      to the user in one round; the cold readings of the changed sentences of §3 to §9;
      the renames and the other changes the applications meet, with their message, so
      that the three can start; and then the rest.

      Until 2026-11-26 the leg's session ran on the coding model at the stronger effort, and a verdict that
      came back during the builds waited for a round on the stronger model at a cut, a session of its
      own on the stronger model, of which three were held (the log's *One Fable Round
      Before the Close* and *A Fable Round at a Cut*).

      Since 2026-11-26 the session stays on the stronger model, the user's word, and each
      build's agent runs on the coding model at the stronger effort (the log's *The Session Stays on Fable*).
      A verdict that comes back is put to the user at the next cut where no agent runs,
      one decision at a time, the argument first and a recommendation naming its
      principle, and its answer is written under its line as *Answered*, the report's
      sentences it settles beside it. Each question that waits is named here as it
      comes. The session stops at a commit and asks for a `/clear` where its context is
      worth dropping.

      The ten questions that waited were answered 2026-11-26, each as recommended (the
      log's *The Ten Answered*). Built: rule 3's "stated whole" with E.13 named (*P2
      42*), a record update's bullet in §10, rule 2's sentence narrowed to text, shape
      rule 8's two phrases, the certificate's row as *R2 2* has it, and a function's
      result among what crosses into foreign code (the log's *A Function's Result
      Crosses*), and the interrupt that ends a running load (the log's *The
      Interrupt Ends a Running Load*). The three terms of a shell's processes and
      §12.9 are written (*G 23*, *G 21*, the log's *The Three Terms and §12.9*), and a
      part of §11.2 has its anchor on the site (the log's *A Part's Anchor*). Nothing
      of the ten is left to build.

      The first round was held 2026-11-25 (the log's *The First Fable Round*), its three
      decisions answered under *B8*, *B10*, *P1 11, K 19, W17* and *PL1 L32, …*. *B8* and
      *B10* are built with the shell's lines, their part of the runtime among them; the
      taken refusal's text and the help where a root module hides a library's with the
      cli's; `:load`'s answer with the shell's; and `List.<>` with the standard
      library's. The nodes' build and the standard library's are done (the log's *The
      Nodes' Build* and *The Libraries' Build*).

      The second round was held 2026-11-25 (the log's *The Second Fable Round*), its six
      decisions answered under *T5*, *N C29*, *T18*, *P3 3, P3 9, T25*, twice, and *S3,
      S6*. The cli's build took the five texts and `Http.filePath`'s `OPTIONS` step,
      §8.7's sentence read cold before it (the log's *The Cli's Build*).

      The third round was held 2026-11-26 (the log's *The Third Fable Round*), its five
      decisions answered under *B6*, *Z17*, *N C26*, *T5* and *N C24*. The shell's build
      took all five, the cli's code of the last two among them (the log's *The Shell's
      Build*). Its second build took the two decided lines the first brief left out,
      *E2 C14* and *E2 C2*, the trace of a reload's faulting binding, and the help's
      line for `:browse` (the log's *The Shell's Second Build*).

      The report's own 73
      decided lines are written, read cold, with the tests and the tools that follow
      them (the log's *The Report's Own Lines*). The tests' build with the examples' and
      the site's is done, in two (the log's *The Tests' Build* and *The Blocks Checked*), and *Z1*
      is found and mended, the page's own defect (the log's *The Terminal's
      Stylesheet*).

      The documents are written each by a writer on the stronger model, one after
      another. The language guide is done (the log's *The Language Guide Recut*), and
      so are the other guides with the tour and the front pages (the log's *The Other
      Guides, the Tour and the Front Pages*), and `docs/` (the log's *The Documents'
      Lines*). The log's and the plan's own lines are the session's, and are written
      (the log's *The Session's Own Lines*).

      `make test-grammar` failed once, on seed 71865135, where the parser took a text
      that Appendix A does not derive, a marked variable in parentheses or before a
      body's `=`. The parser refuses both now (the log's *The Parser Held to Appendix
      A*).

      The guide's writer found four decided sentences of the report unwritten, each of
      a line with two owners. Two readers audited the decided lines that carried no
      closing bullet, one against the report and one against the code
      (`leg4/builds/audit/`). The report lacked the sentences of twelve lines, which
      are written and read cold (the log's *The Decided Lines Audited*). The code
      lacks four things, *U 12*'s test of a guide's quoted line among them, and a
      fifth was found beside them: an address given to a function value that foreign
      code gave stood behind no check, where §8.4 has one. One build took the five
      (the log's *The Audit's Build*).

      The readings were made 2026-11-23 (the log's *Leg 4's Readings*) and answered
      2026-11-24 (the log's *Leg 4's Answers*), and the changed sentences were read cold
      2026-11-24 in a copy of the report, whose 21 finds for the user were answered the same
      day (the log's *The Changed Sentences Read Cold* and *The Cold Reading's Answers*).
      The copy took the answers, and what they change was read cold once, six finds
      coming to the user and answered (the log's *The Answers Read Cold* and *The
      Answers Read Cold's Six*). The report was written from the copy 2026-11-25, in
      one commit with the first build (the log's *The First Build of Leg 4*).

   Leg 3 puts the `decide` round before a fix is built, where `docs/reviews/full.md` has
   the `fix` lines made at once and the `decide` lines after, so that the design is one
   block. The readers' models are their own, whichever session starts them: a reader of
   the code or of what the toolchain does runs on the coding model at the stronger effort, and every other
   reader on the stronger model, which leg 2's briefs name outright.

   Before its readers start:

   - **The three tools in Ernest**, done 2026-11-23 (the log's *The Three Tools in
     Ernest*): `tools/words.ern` and `tools/unicode_width.ern`, in place of
     `tools/paragraphs.sh`, `tools/comments.sh` and `tools/unicode_width.escript`.
   - **The checks that cost cycles**, decided with the user 2026-11-10, so that the readers
     start from what a tool lists (the log's *The Listings Before a Review*).

     The refusals are done 2026-11-23, each with the tree cleaned to zero (the log's *The
     Applications' Order* and *The Refusals Before the Readers, Built*): `make xref` refuses a
     call against the applications' order and an export nothing calls, `make test-typed` the
     checker's near misses, and a style test a private function nothing calls.

     The listings are done 2026-11-23 (the log's *The Listings Before a Review, Built*):
     `make cover`, `make clones`, `make sizes` and `make slowest`, which the reviews name.
   - **The helper's failure under recording**, done 2026-11-23 (the log's *The Helper's
     Failure Under Recording*): the recorder's, mended.
   - **What is kept, stated once**, done 2026-11-23 (the log's *What Is Kept, Stated
     Once*). The design notes own what a component keeps and when it lets go, and
     `docs/memory_checks.md` points at them.
   - **The documents' listings**, done 2026-11-23 (the log's *The Documents' Listings,
     Built*): `make lengths`, `citations`, `terms`, `unchecked` and `edits`, which the full
     review's readers of the report, the guide and the tour start from, and the browser
     test holds every page of the site to no sideways scroll on a phone.
   - **Two defects the listings found**, done 2026-11-23 (the log's *An Operator's Anchor
     and a List of Sections*): the site writes an anchor's fragment percent-encoded, and a
     list of sections after a document's name is that document's to its end.
   - **The checker's cases tabled**, done 2026-11-23 (the log's *The Checker's Cases
     Tabled*): 132 cases, 73 held before and 59 by new tests, no defect. When a spawn's
     capture's type is read is decided (the log's *When a Capture's Type Is Read*), and so is
     how a requirement's error names its callee (the log's *A Requirement's Callee, Named*).
   - **How a diagnostic names a name**, decided 2026-11-23 in four questions (the log's
     *How a Diagnostic Names a Name*): §11.5's rule for a type name is every declared
     name's, a witness writes its constructors as the source does, a prelude type the
     module hides prints `Prelude.x` as a function does, and §5.6's fill error names the
     declaration. The findings' line *PL6 3* holds the sentences, which leg 4 builds.
   - **§3.11's two ends**, decided 2026-11-23 (the log's *§3.11's Two Ends*): the report
     follows the checker at both. A peer spawn's mailbox type and a compute's result type
     are known whole by the end of the definition they are written in, which §4.8 says is
     a local `fn` too. The findings' line *PL6 2* holds the sentences, which leg 4 writes.
   - **The other repositories take their manifests**, done 2026-11-23 (the log's *The
     Other Repositories' Manifests*): ernest-template's `0155cf2`, tagged `v0.11.0`,
     ernest-epx's `479b1c6`, against the archive of `fcb26908`, each session told by a
     message. ernest-httpd's session took its `6690e4f` off main on the user's word, since
     its `make test` failed there, and takes the template's tag in one commit with its own
     fixes. ernest-epx's release with its host part is its session's own. All three hold
     their commits unpushed until 0.11.0 is released.
   - **The packages proposal's reading and sweep**, done 2026-11-23 (the log's *The
     Packages Proposal Swept*): read against its owners and removed, what only it held kept
     in the log.

   Beside it, on the user's word, ernest-template, ernest-epx and ernest-httpd are each reviewed
   whole by their own sessions, by the `docs/full_review.md` each took at the layout's stop,
   against the archive of the commit the readers read; ernest-httpd's review has a security
   reader, since it goes public in MVP 4.18. What they find of Ernest's comes as lines of
   their feedback files and is sorted in this round (the log's *The Applications' Full
   Review*, *Ernest Stays at 0.x*).

   As they begin, the three floors rise to this release's minor, since a development build of
   the floor is what an archive before the release is (the log's *The Floors and the
   Releases*). The rise is the manifests' write above. Ernest's session then names the minor,
   the archive's path and its commit to all three by a message, and asks for the reviews, on
   the user's word, sent 2026-11-23 once Ernest's readers were done. Each
   application's own session opens on the new floor, changes what its code needs there and
   begins its review. Their findings are sorted after leg 3's, in a sort of their own.

   The message names the review's three legs, each ended by a commit: the floor's rise, the
   readers and their lists in the findings file; the sort and the lines to decide, with the
   user; and the fixes and the close (the log's *Where a Session Is Cut*).
5. **The release of 0.11.0**, the next minor of 0.x, by `docs/reviews/release.md`'s step, on Linux:
   macOS unverified and said so in the README's installing sentence and the note, which also
   says that the installed layout changed, for a script that points inside an installation (the
   log's *The Layout Built*); the findings file empty, and the feedback file holding only entries
   that an item of MVP 4.5 holds. It is tagged and published with no announcement, so that
   the applications have a published floor.

   The same week, in this order, each by its own session on the user's word: ernest-template's
   release, since the others copy from it, and ernest-epx's, not waiting for its milestone 9
   (the log's *The Floors and the Releases*). ernest-httpd's release is MVP 4.18's. Ernest's
   session tells all three the tag by a message, and asks each in turn when the one before
   it is out. The message names every line of the application's that the release answers,
   MVP 4.16's item 12's among them, each by Ernest's number. Each application checks every
   verdict against the release before its own, and answers with any line it keeps, as
   `docs/clean_room.md`'s *The answer* says.
6. **The site live at ernest-lang.org**, moved to MVP 4.18 on 2026-11-23, with the last read,
   the reader from outside and the announcement (the log's *The Launch Is 0.11.1's*).
7. **The mechanisms read against what they force**, read and closed 2026-11-21 with every
   row staying (the log's *The Mechanisms' Reading Closed*).
8. **A result that is never empty**, feedback 274, counted, decided and closed 2026-11-23
   (the log's *A Clause That Cannot Run*, *A Result Never Empty, Counted*, *A Result Never
   Empty, Decided* and *A Result Never Empty, Built*). The type stays `List`, and the
   report says in words that a list is never empty: E.5, E.20, G.2 and E.0 shape rule 6.
   `guide/style.md` gives a case the value's shape rules out no value. `Bytes.splitOnce`
   entered, and no split at the last occurrence did. 53 sites of this repository took a
   form where every case can come, or a clause that faults.

   What the item left: the 19 likely and 8 unchased finds, which nobody has shown;
   ernest-httpd's sites, told to its session, which its full review reads against the
   rule; and one line of `docs/known_issues.md`, `Markdown.parse` on a line that holds a
   no-break space alone.

## MVP 4.18 (0.11.1, the site live and the announcement), after MVP 4.4

Decided with the user on 2026-11-23 (the log's *The Launch Is 0.11.1's*). ernest-httpd's
full review found holes in its security, and the site's going live is what puts that server
before the public, so MVP 4.4's item 6 waits for them, and the announcement waits with
the site, since it sends a reader there. Its release is the launch.

1. **What ernest-httpd's review found of security.** ernest-httpd's session mends its own.
   What is Ernest's among it comes as lines of its feedback file, sorted when its session
   sends them, each mended for 0.11.1 or filed as `docs/reviews/full.md`'s *The findings*
   says.

   Three are in hand since 2026-11-23, its feedback's entries 35 to 37 on `Tcp.close` (the
   log's *The Ten of the Cold Reading*), each with a probe its session ran. Two are
   defects a first server meets: a close and a kill after a failed TLS handshake wait 5
   seconds with nothing to send, where E.18 has a kill end a socket at once; and over
   TCP a close answers up to a second after the far end has read everything, by a look
   once a second, which is a poll in the runtime. One is a gap: no function ends a
   socket and drops what its host holds.

   Both defects were reproduced 2026-11-26 against `c9a0d66d` (the log's *The
   Applications' Lines Sorted*). The 5 seconds are the host's: its connection process
   reads for up to its `alert_timeout` after an alert of its own, which Ernest sets
   nowhere, and a close after the far end's alert answers at once. The second is the
   closer's look once a second. Through a kill's 5 seconds the socket's process reads
   `Receiving`, beside E.21's `Suspended`, which the mend reads. Four `decide` lines of
   the sort are a server's security, the findings' *H39*, *H53*, *H54* and *H59*, and
   each is mended here or filed as it is decided.
2. **The release of 0.11.1**, by `docs/reviews/release.md`'s step. It is 0.12.0 where a
   mend of item 1 changes a frame or the form, since a patch moves neither (report §8.7),
   and the milestone's other items then name that release.

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
3. **ernest-httpd's release**, with its readers, by its own session on the user's word, once
   0.11.1 is out (the log's *The Floors and the Releases*). Ernest's session tells it the
   tag by a message that names every line of its own the release answers, and it answers
   with any line it keeps, as `docs/clean_room.md`'s *The answer* says.
4. **The site live at ernest-lang.org**, so that each project it lists builds on the release
   it names (the log's *The Site Goes Live With 1.0*, *Ernest Stays at 0.x*): `make site` from
   0.11.1's tag, the copy of `build/site/` to the host, and the smoke test against the live site.

   Before the copy, ernest-epx's published archive is taken as `site/projects.md` says, by an
   entry in a `package.conf` and `ern unpack`, since MVP 4.17's item 9 wrote the sentence
   before that release. Where it fails, the site waits for the archive.

   Before it, the generator writes `/robots.txt` and `/sitemap.xml`, the second naming
   ernest-lang.org alone, which the site's proposal decided and MVP 4.2 did not build (the log's
   *The Site's Proposal Read*); `docs/design/site.md`'s *The root* lists them then.

   ernest-httpd rehearses the switch on the machine, under a second unit on scratch ports,
   with Ernest 0.10.0's archive and, since MVP 4.6, with the client, so that the switch at
   the launch swaps one archive for another on a path already walked; then, with its release
   of item 3 made, it switches once, the machine serving its one page meanwhile. Its
   container, two nodes capped at 128 processes, 128 MiB and one core, was built 2026-11-04
   (the log's *A Node's Schedulers*).

   Before the switch, a node of 0.11's form starts on the rehearsal, since leg 4 made two
   refusals that can stop a deployed node: an `ernest.conf` that holds `public-key` or
   `utilization`, and a directory or an `ernest.conf` that any but its owner may write
   (the log's *The Nodes' Build*).

   Decided with the user on 2026-11-17: the site's server takes a new build while it
   serves after the launch, if at all. A deploy ends at most six demo shells, the deploys
   around the launch come with a new floor, a restart either way, and nothing hands a
   listener over today (the log's *The Server's Answers*, its paragraph *New code under
   traffic*). What Ernest lacks for it is feedback 261, MVP 4.5's item 4.
5. **The announcement**, last. The user's `~/announcement.txt` outside the repository shows
   a shell's start line. `make version` does not write it and no test holds it, so the user
   sets it to the release's version before sending it (the log's *The Front Page in the
   Announcement's Manner*).
6. **Which libraries become packages**, a decision, taken while item 1 waits and built
   for 0.12 where it is taken (the log's *What Stands on Every Load Path*, *The Report
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
7. **Three faults that vanish**, taken up by the user on 2026-11-23 from the known
   issues' lines 15, 16 and 20 (the log's *Four Verdicts Changed After the Round*), and
   built while item 1 waits, for 0.11.1: a fault a listener or a socket never meets, after
   a fault in an adapted address's function over it or a bad message through its check
   (§6.5, §8.4; was item 135); a wrap's fault lost in the process kept for an adapted
   address (§6.9; was item 136, two runs and not diagnosed); and an `Os.exit` that such a
   process calls on a node, not read once the end's wait is over (§8.6; was item 140).
   Each ends a run with status 0 or writes no fault's line. Each line of the known issues
   goes with its fix.

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
1 to 4 follow, then items 68, 96, 113, 158, 174, 165, 166, 168 to 173 and 175, and item 167
last, so that OTP's answer to its report may come first.

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
- **174. A call's wait under a backlog**, a decision, from the findings' *H54*, decided
  2026-11-26 (the log's *The Applications' Lines Decided*). Its first step is a design
  session with the user, and nothing is built before it. A call's wait reads its caller's
  whole mailbox, which §10 states: 1,000 calls to an echo process took 2, 66, 130, 254 and
  501 ms with 0, 10,000, 20,000, 40,000 and 80,000 messages waiting, and `Os.resize` and
  `Tcp.write` grow alike, where the host's own `gen:call` does not.

  The host marks a wait
  only where every clause carries the fresh reference, and Ernest's has two that do not,
  a restart asked for and a fault delivered (`ern_rt.erl`'s `waited_answer/3` and
  `forever_answer/2`). *The Rows That Grew* of 2026-10-20 holds the one design known, an
  identity on every ask and a loop in every `receive`, and called none plain.
  ernest-httpd's session met the cost in a flood of resizes, past its backpressure. To
  decide: whether a plainer design exists, and whether the wait is marked.
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
  Recording*).
- **168. A row of the library's bench in a process of its own**, found 2026-11-22 by MVP
  4.4's item 2 (the log's *The Cost's Rows Read*). `Bytes.toList` at 10,000 bytes reads 5.4
  times the host's with nothing added: in the harness's process a compiled call of
  `binary_to_list/1` takes 33 µs and the host's side, which applies its export, 12, and in
  a fresh process the sign flips. `Os.closeInput` reads 2.4 times as the first row that
  starts a program, 1.2 moved last, for a reason not found. `ern_measure` times each row
  in a process of its own, so that no row rests on the rows before it, and
  `Os.closeInput`'s first timing is read again after it. `docs/development.md` names the
  two rows as the harness's until then.
- **169. One list of generalized values**, from MVP 4.4's item 4, the findings' *W23*
  (the log's *The Language's Rules*). A top-level `let` is generalized where its
  initializer is a value (§4.6), and a `let` in a block only where it binds a lambda
  (§3.9), so `let one = List.take` serves two types at top level and one in a block. To
  decide with the user: §4.6's values for a block's `let` too, with what §4.8 calls a
  definition, a cold reading and the argument's paragraph.
- **170. A prelude type's members written with their prefix**, from the findings' *P1 18,
  K 27*. `int.ern` declares `fn Int.+` and, unprefixed, `fn compare` and `fn negate`,
  which costs an exception sentence in §4.2, in §4.8 and in Appendix F. The standard
  library writes `fn Int.compare` and `fn Int.negate`, and the three sentences go. No
  program meets the rule.
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
| MVP 4.4 | the cost analysis, the full review and the release of 0.11.0, Linux | | | above |
| MVP 4.18 | what ernest-httpd's review found of security, the release of 0.11.1, the site live at ernest-lang.org and the announcement: the launch; a decision on which libraries become packages; and three faults that vanish, from the known issues | | | above |
| MVP 4.5 | the shell's second round, two requests to OTP, for what a purge needs and for the interrupt, a decision on a listener handed over, and what the line of 2026-11-19 left after the launch: six items of MVP 4.16, a test and a flake from the known issues' sort, the library bench's rows each in a process of its own from MVP 4.4's item 2, the map's square from its item 3, and five decisions from its item 4 | | | above |
