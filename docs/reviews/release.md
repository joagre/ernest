# The review before a release

What a release runs to be ready, and nothing else. Between releases an item that touched the runtime, the nodes or the emitter runs `make test-full` before its closing commit, and any other its area's target (CLAUDE.md, *Tests*). The plan says when a review runs; each finding is fixed, planned, or dropped, and the commit messages say which. A full review, every reader over the whole of its area, runs seldom, as [`full.md`](full.md) says.

1. **A fresh clone builds and passes:** `git clone`, then `make` and `make test-full`, in a directory of its own, on a machine running nothing else, before the readers start. `make test-full` installs into a scratch prefix and from the release archive, and runs from there (`installation_test_`, [`design/install.md`](../design/install.md)).
2. **Five machines**, over the commit the review starts on; once the findings are made, `make sections` and `make bench` run again over the release's commit, `make load` where the round changed the runtime and `make sanitize` where it changed the helper; dialyzer runs in the clone's full run:
   - `make sanitize`, the helper in C under Clang's analyzer and the sanitizers;
   - `make load`, the loads of [`memory_checks.md`](../memory_checks.md);
   - `make service`, a program started, stopped and started again by the host's service manager, whose launchd checks run only on a Mac, and on the first one at hand;
   - `make sections`, which names a section of the report no test cites, and names only a section of a milestone not yet built, which that milestone's item names;
   - `make test-browser`, the site's client in a headless Chrome, on the machine with Chrome; and the panel against a real shell by hand on a server of the site's, a session started, a block pasted and loaded, a transcript's input pasted, Stop, Restart and the warning, since the test's socket is a stub;
   - and `make bench`, three runs with the machine idle, the median of each row's ratio to Erlang's no worse than the rows the log last recorded, which the log's entry for this review then holds; then, over the release's commit, `make bench-release`, which keeps the last of its three as the release's run, the second reference every later run is compared with; it lives in the build directory, under bench/release, on the machine that ran it, goes with `make clean`, and a machine without one runs `make bench-release` over its own first run.
3. **The readers** of [`full.md`](full.md), run as it runs them, with its briefs:
   - **The report:** P, the principles, and K, the cold reader, over the report's diff since the last release where a review read the report whole within it, and over the whole report otherwise, as [`full.md`](full.md) reads an area a release review read whole (the log's *The Report's Readers Read the Diff*).
   - **A newcomer:** N, with a program no earlier newcomer wrote.
   - **The skeptics:** L and M, the Erlang and the Gleam programmer, over `README.md`, `guide/why.md`, the tour and `guide/faq.md`, and the guide's chapters that changed since the last release.
   - **The code:** C, E and S as one reader, over what changed in `src/` since the last release, or since the last full review where that is later.
   - **The guide:** U, when a rule of the report changed since the last release, over the sections of the guide that teach what changed.
   - **The argument:** the report's reader, when a rule [`soundness.md`](../soundness.md) covers changed since the last release, over the argument's paragraphs for those rules beside the report's sections: every step that does not follow from the rule it cites.
   - **The round:** K, once the findings are made, over the diff from the commit the review started on to the release's commit of the report, the guide, the tour and `README.md`, the lines the review's own rounds wrote and no reader has read (the log's *The Release Review Read Back*); the review before 0.7.0 read the report's alone, and its guide lines wait for the next reader of them.
4. **The findings:** a defect is fixed, or planned in a milestone; clarity is fixed where it is cheap, and otherwise dropped; the lines are sorted as [`full.md`](full.md)'s *The findings* says, and the round runs as its *How it runs* says, smaller. A `decide` line is argued as CLAUDE.md's *Before code* says, after the log is searched for the decision it may sharpen and the program that shows it is run.

   A name a reader lists is decided after the word is searched across the report, the code and the shell, never from its module alone. Where it means something else anywhere in Ernest, the two meanings are weighed on §0's principles, a word carrying two where a reader who knows Ernest first keeps them apart, and the log names the principle that decided and the other meaning the verdict weighed.
5. **The release:**
   - `VERSION` naming the release, which `make version V=x.y.z` set once the last release was tagged, and which a release of another version, a patch, sets now: the target sets `VERSION` and every line the tests hold to it, the documents' start lines, the session fixtures' and the site's expected index page's (`tools/version.sh`), then writes the pages again by `make man`;
   - where the release is a patch, the library's listings, the form's version (Appendix H) and the protocol's version unchanged since the minor, which the tests hold, and the type of each foreign declaration of the shell's under `src/shell/`, read against the minor's tag, since two patch levels stand on one floor and a shell of one runs on a node of the other (report §8.7, §11.2);
   - every module of `src/stdlib/` and `src/libs/` that appeared since the last release, and every exported declaration that did, ending its doc block with its own `since` (Appendix E.0 shape rule 6, whose shape and versions `make test` holds);
   - the pages `make man` writes into `docs/man/`, committed with the release;
   - the About text of the repository on GitHub, which follows the opening of `README.md`, and which no test holds;
   - the release's section of `CHANGES.md`, first in the file, committed before the tag, which is the release's note: the release step copies it as the notes of the release on GitHub, so that the note is written once (the log's *A Release Carries No History* and *The Release Cleanup*);
   - the tag, signed, `git tag -s vVERSION`, with an SSH key GitHub holds as a signing key, so that GitHub marks it verified;
   - then the archive `make release` writes at the tag, `ern-VERSION.tar.gz`, and its checksum, `ern-VERSION.tar.gz.sha256`, both published beside the tag, since an archive made before the tag says its commit (§11.7);
   - and once the tag is made, `make version V=<next minor>.0`, committed at once, so that `VERSION` names the release the checkout works toward and a development build says `0.8.0-dev` while 0.7.0 is the latest release.

   The section restates no change, and its date stands in its heading and nowhere else. It says:
   - what the release is, in words, naming no milestone, review or log entry, since a reader of the notes is a user;
   - what a program written for the previous release changes, which is the reader's next step and no history;
   - that until 1.0 a release may refuse a program the previous release accepted, and that the release's report is what holds;
   - the report's diff between the last release's tag and this one's, `git diff v0.2.0 v0.3.0 -- report/` for 0.3.0;
   - and what changed, one line a change naming the report's section or Appendix E's entry where it is read, and nothing else.

**The models.** The readers run as [`full.md`](full.md)'s *The models* says, and the machines need none. Of the findings, a design question or a sentence of the report takes a design session, and a named fix and the release itself an item session.
