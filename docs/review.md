# The review before a release

What a release runs to be ready, and nothing else. Between releases a change runs `make test` before the commit that closes its plan item (CLAUDE.md, *Tests*). The plan says when a review runs; each finding is fixed, planned, or dropped, and the commit messages say which. A full review, every reader over the whole of its area, runs seldom, as [`full_review.md`](full_review.md) says.

1. **A fresh clone builds and passes:** `git clone`, then `make` and `make test`, in a directory of its own. `make test` installs into a scratch prefix and from the release archive, and runs from there (`installation_test_`, [`install.md`](install.md)).
2. **Three machines:** `make dialyzer`; `make sanitize`, the helper in C under Clang's analyzer and the sanitizers; and `make load`, the loads of [`memory.md`](memory.md).
3. **Three readers** of [`full_review.md`](full_review.md), run as it runs them, with its briefs:
   - **The report:** K and P, the cold reader and the principles, as one reader.
   - **A newcomer:** N, with a program no earlier newcomer wrote.
   - **The code:** C, E and S as one reader, over what changed in `erl/`, `stdlib/`, `shell/` and `libs/` since the last release.
4. **The findings:** a defect is fixed, or planned in a milestone; clarity is fixed where it is cheap, and otherwise dropped.
5. **The release notes,** what changed since the last release and the newcomer's program, and then the tag.
