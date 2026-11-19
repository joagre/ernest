# Findings of the plan's reading for build order

The reading of 2026-11-19, sorted as [`reviews/full.md`](reviews/full.md)'s *The findings* says. One reader read [`plan.md`](plan.md) at `374e8279` for items that stand in the wrong build order, after item 132 was found to stand before item 114, whose root it needed (the log's *The Process Behind a Check, Built*). It ran no program.

The session has not yet read a line against its file. It does so, and searches the log, before a line is brought to the user.

## The lines

A line is `fix`, made in the round; `decide`, with the user; or `dropped`, with the reason; and `done` with the date once made. Every line here was `decide`, since each changes the plan's order or an item's words. A line carries the reader's recommendation, and the session's once it has read the line back. P is the reader.

- P1 — MVP 4.17's items 10 and 23 against MVP 4.4's items 5 and 6. The site is built from the release's tag, and item 10 writes the site's sentence on ernest-epx after that tag. decide: item 10 is cut in two, the repositories' part into MVP 4.4's item 4 and the site's sentence before the tag, and item 23 follows the first part.
- P2 — item 124 weighs one sentence of §8.7 for itself and for item 118, whose showing stands after the launch. decided with the user: item 124's agent makes item 118's showing in the same run, and item 118 keeps the rest. done 2026-11-19.
- P3 — items 93 and 95's first line are built before item 101's rule reads their verdicts again. decided with the user: item 101 before item 93 and before item 95's first line. done 2026-11-19.
- P4 — item 100 decides over the socket's writer that item 122 reads after the launch, and item 93 writes a sentence on `Tcp.close` that item 100 may reverse. decided with the user: item 100's probes take item 122's case. done 2026-11-19. The second half is dropped: item 93's sentence on `Tcp.close` is true as the code stands, a user meets it, and item 100 rewrites it where its verdict changes the close.
- P5 — item 115 may be the checker item that MVP 4.4's tabling must precede, and its paragraph does not say so. decided with the user: item 115 says that a verdict for the type checker takes the tabling first. done 2026-11-19.
- P6 — MVP 4.4's item 2 measures the fault's row before item 3 decides the trace. decide: item 3's verdict after item 2's first step and before the bench is read whole. The reader's least sure line.
- P7 — MVP 4.4's item 5 asks for an empty feedback file at the release, and entries 260, 261, 264 and 265 stand in MVP 4.5. decided with the user: item 5 lets an entry stand that an item of MVP 4.5 holds. done 2026-11-19.
- P8 — item 52 writes §11.2's lines on a history file that item 54's second line names again. decided with the user: item 54's second line is decided with item 52's table. done 2026-11-19.
- P9 — MVP 4.6 has no item that sweeps `proposals/homepage/` and `proposals/ernest_httpd/` before the launch's release. decided with the user: MVP 4.6's item 5. done 2026-11-19.
- P10 — items 134 and 135, which item 132 adds, join sets held in three places: MVP 4.4's item 4's list of MVP 4.5's items, MVP 4.5's sentence on its order, and the list under it. decided with the user: item 134 joins MVP 4.4's item 4's list, MVP 4.5's sentence on its order and its list, and item 135 stands last of what was found. done 2026-11-19.
- P11 — item 119 closes without `make test-browser`, and its last step changes the homepage's opening, whose first screen that test holds. decided with the user: item 119's last step closes on that target. done 2026-11-19.

## The reader's list

### Findings

#### 1. MVP 4.17's item 10 and item 23 against MVP 4.4's items 5 and 6: the site's sentence cannot be in the tag

- **Items.** MVP 4.17's item 10 (*The site*), item 23, MVP 4.4's items 5 and 6, MVP 4.6's item 2.
- **Mechanism.** `Makefile`'s `site` target exports the tag with `git archive "$(TAG)"`, and its comment says "Everything comes from the tag". MVP 4.4's item 6 runs "`make site` from that tag", the release's.
- **What goes wrong.** Item 10 writes `site/projects.md`'s sentence "once ernest-epx's release is an archive that `ern unpack` takes". ernest-epx releases after Ernest's tag, since its `make release` refuses a development build of the floor (the log's *The Floors and the Releases*). So the sentence is written after the tag, and the site built from the tag does not hold it. The launch day finds it: a second tag, or a site built from a commit that is no release.
- **Beside it.** Item 23 stands "once item 10 is done and before MVP 4.4's release", and item 10 cannot be done before that release. MVP 4.17's opening has it come before MVP 4.6, and MVP 4.6's item 2 is "begun after MVP 4.17", where items 10 and 23 run with MVP 4.4's items 4 and 5.
- **A second seam in item 10.** Its writes in the three repositories need the floor risen and "their sessions closed". MVP 4.4's item 4 has the floors rise "as they begin", the applications' reviews. Nothing places item 10's writes between the rise and the start of each review, so a review reads its repository without its manifest, or the write meets a running session.
- **Recommended.** Item 10 is cut in two. Its repositories' part stands in MVP 4.4's item 4, after the floors' rise and before each application's review. Its site sentence is written before the tag, and item 6's smoke test holds that ernest-epx's archive unpacks, since the site goes live after that release anyway. Item 23 follows the first part. MVP 4.6's item 2 says "after MVP 4.17's item 9".
- **Read from.** The `Makefile`, `site/projects.md`, the plan, and the log's *Packages and No Manager*, *The Floors and the Releases* and *A Built Proposal's Sweep Is an Item*.

#### 2. Item 124 rests on item 118's showing, which stands after the launch

- **Items.** MVP 4.16's item 124, MVP 4.5's item 118.
- **Mechanism.** `ern_carrier:depart/0`, called in `ern_cli:run_node/5`'s `after`. It sends each connected peer `node_ends` and then `net_adm:ping/1`. A peer that stands still holds that ping until the detector gives it up, and the host takes dials meanwhile. So item 124's setting, a store that stands still while the desk ends, is itself item 118's window between `depart` and the halt, with no stalled stream needed.
- **What goes wrong.** Item 124 weighs "whether one sentence of §8.7 on a peer that stands still and is not yet lost answers this item and MVP 4.5's item 118 together". Item 118 is "not read": nobody has shown what a listed peer's dial, its sends and its monitors meet in that window. A sentence written for both rests on no program for half of it, and ships in §8.7. Item 118's showing after the launch then rewrites it, or shows it false.
- **Recommended.** Item 124's diagnosing agent makes item 118's showing in the same setting, before the sentence is weighed. Item 118 keeps its decision in MVP 4.5 where the showing finds the report true. Or item 124's paragraph drops the question and its sentence speaks of item 124's case alone.
- **Read from.** The code for `depart/0` and its caller. The gateway's handling of a dial while departing was not read. The rest from the plan and the log's *The Line Before the Launch*, *A Down Follows the Send* and *The Job Halts Without the Host's Flush*.

#### 3. Items 93 and 95 build verdicts that item 101's rule reads again

- **Items.** MVP 4.16's items 93, 95 (its first line) and 101.
- **Mechanism.** `docs/limit_findings.md`'s section 3.2 lists the seven cases item 101 reads. Its row 52 is item 93's verdict: "a reader writes the next act after `closeInput`. The terminal harness was that code, and it flaked". Item 101 says "The seven are then read against the rule, and one that falls otherwise is brought to the user."
- **What goes wrong.** Item 93 stands in "What is decided and waits for its build", before "What needs the user". So `Os.closeInput` and `Tcp.closeListener` are built, with E.18 and E.23 changed, before the rule that reads their verdict again exists. Item 95's first line is a verdict of the same kind, made on 2026-11-17 before the rule: the order of two inputs' messages gets a sentence in the tour and the guide, and the mechanism, a session made one sender, was set aside. Under the rule item 101 recommends, both acts there are Ernest's own.
- **The risk.** Under the recommended rule row 52 stays a mechanism, so item 93 most likely stands. Item 95's first line is the one that could turn.
- **Recommended.** Item 101 is taken before item 93 and before item 95's first line. Item 92 and item 95's two other lines do not wait on it.
- **Read from.** The plan, `docs/limit_findings.md` and the log's *The Limits Read*, *Seven Entries of the Feedback* and *The Outside Reviews Read*. No code.

#### 4. Item 100 decides over the socket's writer that item 122 reads after the launch, and item 93 writes a sentence item 100 may reverse

- **Items.** MVP 4.16's items 93 and 100, MVP 4.5's item 122.
- **Mechanism.** `ern_tcp:send/5` hands each write to the socket's writer, and `write_timed_out/2` answers `Left(Timeout)` and keeps the write's place. `stop_writer/1` kills the writer at a close, and its comment says a write held back "has given none". So a write that timed out and still waits in the writer's mailbox is dropped by a close, where E.18 says a `Left(Timeout)` does not undo the write. The second of item 100 is `LINGER_CHECK`, a fifth of `LINGER_IDLE`, in `lingering/5`.
- **What goes wrong, first.** Item 100's third question is what a program can wait on to know that the far end has taken a socket's bytes. Its answer depends on what the writer holds and what a close does with it. That is item 122's showing, moved after the launch. Item 100 either decides without it, or its probes make most of item 122's showing, which is then made twice.
- **What goes wrong, second.** Item 93 writes into E.18 that `Tcp.close` stays a send and answers before the connection has closed. That was decided on 2026-11-17. Item 100's third question was placed on 2026-11-19, and a close that answers once the bytes are taken is one of its plain answers. Item 100 would then rewrite item 93's sentence.
- **Recommended.** Item 100's probes take item 122's case with them: a far end that reads nothing, writes that time out, then a close. Item 122 starts from that showing. Item 93 builds its two closes and leaves the sentence on `Tcp.close` to item 100.
- **Read from.** The code of `src/runtime/ern_tcp.erl` at the functions named, E.18, the plan and the log's *Two Lines on a Close*, *What a Program Can Wait On Before Its End* and *What a Program's Helper Holds*.

#### 5. Item 115 may be the checker item that MVP 4.4's tabling must come before

- **Items.** MVP 4.16's item 115, MVP 4.4's item 4 (*The checker's cases tabled*).
- **Mechanism.** The refusal is `ern_types.erl`'s "a function that receives nothing where one that receives is needed" and its twin, lines 990 and 992. That is inference over mailbox types, groups 1 and 5 of the eight the tabling lists.
- **What goes wrong.** The tabling "comes earlier where a checker item comes before the review". Item 115 decides between §6.5's sentence and the type checker, and its paragraph does not name the tabling. Where the verdict is the type checker, the change to inference is built without the tests the tabling would add.
- **Recommended.** Item 115's paragraph says that a verdict for the type checker takes the tabling first.
- **Read from.** The plan and the log's *The Outside Reviews Read*. The checker's two texts were found by a search, and the refusal was not run.

#### 6. MVP 4.4's item 2 measures the fault's row before item 3 decides the trace

- **Items.** MVP 4.4's items 2 and 3.
- **Mechanism.** `ern_rt.erl:4343` sets `backtrace_depth` to 64, and `test/bench/ern_bench.erl:41` varies it. Item 2's one candidate for a defect is the fault's report, "whether the trace is taken at the raise or when a line is written". Item 3 ends "or decided against the trace `backtrace_depth` keeps".
- **What goes wrong.** Item 2 writes its verdicts and rates into one log entry and a section of the runtime's design note, and holds `why.md`'s cost claims to them. Where item 3 then changes what the trace keeps, the fault's row and each row that raises are measured again, and the entry, the note and `why.md` are written twice.
- **Recommended.** Item 3's verdict is taken after item 2's first step, the fault row made readable, and before the bench is read whole.
- **Read from.** The plan alone, with the two sites of `backtrace_depth` found by a search. The bench and the log's entries for items 2 and 3 were not read.

#### 7. The launch's release asks for an empty feedback file, and four entries stand after the launch

- **Items.** MVP 4.4's item 5, MVP 4.5's items 4, 5, 96 and 113.
- **Mechanism.** `docs/language_feedback.md` holds entries 260, 261, 264 and 265, and its opening says an entry stays until a plan item decides it. The four are items 96, 4, 5 and 113 of MVP 4.5. Three were moved or placed there on 2026-11-19 by the line.
- **What goes wrong.** Item 5 has "the feedback file and the findings file empty" at the launch's release. The reason held while every entry was decided before the launch, and no longer does.
- **Recommended.** Item 5 says which entries may stand at the release, those an item of MVP 4.5 holds. Or the file's opening lets an entry go once an item holds it.
- **Read from.** The plan and the feedback file.

#### 8. Item 52 writes the history file's lines that item 54 names again

- **Items.** MVP 4.17's items 52 and 54.
- **Mechanism.** §11.2's lines `the history is not kept, since /home/ada/.ernest/history ...` and `Ernest.Shell`'s `Unkept` in `src/shell/ernest/shell/history.ern`.
- **What goes wrong.** Item 52 adds a line to §11.2 for each case of no history, and rewords the host's refusal in them. Item 54's second line then decides how the shell names the history file, recommended as §11.5 names a file. The lines and their tests' texts are written by item 52 and rewritten by item 54.
- **Recommended.** Item 54's second line is decided with item 52's table, before item 52 builds. The cost of the plan's order is a handful of expected texts.
- **Read from.** §11.2 and the shell's module, with the plan.

### Orders found right

- **MVP 4.16, items 132, 133, 134 and 135.** Item 132 before item 133: item 133's fix changes the held address, and `ern_rt:sent/1`'s test of a row sends a message to a process of another node either way. Item 132 before item 135: a resource's process has a row, so item 132 changes nothing for it, and item 135 then adds to the sentences of §6.5 and §8.4 that item 132 writes. Item 134 after the launch: its two shapes are the checker's `{ern, fault, Cause}`, which takes the receiver's stack, and `sent/1`'s `{ern, #fault{}}`, which carries a trace, and both stand after item 132. No system process can be a check's target, since no program can name one (`ern_rt.erl:1227`).
- **MVP 4.16, items 124, 125 and 126.** Item 124 before item 125: item 125's tests end a node whose senders wait on a stopped peer, which is item 124's case, so they are written after its verdict. The three disconnect sites (`ern_carrier.erl:352`, `ern_gateway.erl:244` and `595`) are not on a node's end, so item 125 does not change what item 124 diagnoses. Item 125 before item 126: a `find` frame refused by the new guard meets the disconnect item 125 mends.
- **MVP 4.16, the rest.** Items 115 and 132 change different sentences of §6.5. Item 120 before MVP 4.5's items 68 and 118: item 68 is of a job outside a run, and item 118's window is shown on what item 120 leaves. Items 92 and 93 change different sentences of E.18 and E.23. Item 101 before item 100 and item 68, as the plan says. Item 133 before item 101's eighth case and MVP 4.5's item 113: an address that carries the process behind it holds under either verdict.
- **MVP 4.17.** Item 119 before item 52: different paragraphs of §11.2. Item 54 before item 8: `ern unpack`'s refusals are written after the quoting is decided. Items 7, 8 and 9 in that order. Item 119 before MVP 4.6's item 4, which measures the first screen after the opening's last clause.
- **MVP 4.6.** Items 2 and 4 touch the browser test in different places. Item 2 before MVP 4.4's item 4, so the full review reads it.
- **MVP 4.4.** Item 4 before item 5 before item 6, apart from findings 1, 6 and 7.
- **MVP 4.5.** Items 118 and 122 first, apart from findings 2 and 4. Nothing found fixes item 134's place among the rest.

### Seen beside the order

- MVP 4.6 has no item that reads and sweeps `proposals/homepage/` and `proposals/ernest_httpd/` before the launch's release, which `CLAUDE.md`'s *Proposals* asks for.
- When items 134 and 135 are written in, three places hold the sets they join: MVP 4.4's item 4 lists MVP 4.5's items a finding is sorted to, MVP 4.5's opening states its order by number, and its list "in the order it is taken" stands under it.
- Item 119 closes on `make test-shell` and `make test`, and its last step changes the homepage's opening, whose first screen `make test-browser` holds at three sizes.

### Not read

- The log before 2026-11-17, but for *The Floors and the Releases*, *A Built Proposal's Sweep Is an Item* and *MVP 4.6 Before the Launch*. The entries for MVP 4.4's items 2, 3 and 4 and for MVP 4.5's items 1 and 2 were not read.
- The proposals under `docs/proposals/`, but for the homepage's README. The packages proposal's build order and question 5 were not read.
- The gateway (`ern_gateway.erl`), the exchange, the runner's handling of a termination, the shell's Ernest but for `history.ern`, the type checker but for two texts, the bench, the site's generator and the browser test.
- §8.7, §11.5, §12.2 and §12.6 of the report. §6.5 and §8.4 were read in item 132's diff alone, and E.18 at its paragraphs on a close.
- `docs/soundness.md`, the design notes and the three other repositories.
- No probe and no test was run. Item 108's probes were read in their report alone.
