# The review before a release

What a release runs to be ready, and nothing else. Between releases a change runs `make test` before the commit that closes its plan item (CLAUDE.md, *Tests*). The plan says when a review runs; each finding is fixed, planned, or dropped, and the commit messages say which.

1. **A fresh clone builds and passes:** `git clone`, then `make` and `make test`, in a directory of its own. `make test` installs into a scratch prefix and from the release archive, and runs from there (`install_test_`, `release_test_`, [`install.md`](install.md)).
2. **Three machines:** `make dialyzer`; `make sanitize`, the helper in C under Clang's analyzer and the sanitizers; and `make load`, the loads of [`memory.md`](memory.md).
3. **Three readers**, each given only the files it reads and nothing that argues for them. Each hands in a list, most serious first, defects apart from clarity:
   - **The report.** "You know Erlang, ML and Go, not Ernest. Read `ernest_report.md` against its §0 principles. Report what contradicts itself or the principles, where one who builds a toolchain from it must guess, and every rule that buys a program little."
   - **A newcomer.** "Read `README.md`, then `ernest_guide.md` alone, doing its exercises with `bin/ern`, then write a program the guide does not show, with its tools and its messages. Report where you were lost, what was false, and what the language made harder than it should be."
   - **The code.** "Read what changed in `erl/`, `stdlib/`, `shell/` and `libs/` since the last release, against the report and `docs/style.md`. Report defects, and each place where untrusted input reaches something it should not."
4. **The findings:** a defect is fixed, or planned in a milestone; clarity is fixed where it is cheap, and otherwise dropped.
5. **The release notes,** what changed since the last release, and then the tag.
