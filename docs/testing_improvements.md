# Testing improvements

Where the time of `make test` goes, and what would shorten it. A proposal stays until a plan item decides it, and keeps its number.

## Where the time goes

Measured again on 2026-09-28, warm, each area alone, with EUnit's time for every test, on a host with 8 cores that was not idle: the areas took 280 seconds one after another, as `make test` runs them. The morning's measurement, on an idle host, was 237.

| Area | Seconds | What dominates |
| --- | ---: | --- |
| the shell and the terminal | 95 | 70 tests one after another; three that wait on memory, `expressions_leave_no_code` 8, `declarations_let_go` 7 and `input_numbers_reused` 6; the pseudo-terminal harness's fixed `sleep` steps |
| the programs | 70 | `paced_output`, 27: its one check is a memory sample after 3 seconds, and it then waits for two million lines; the installation, 8; each example built and run by two launches of `ern`, about 2.5 each |
| the guide, the report and the catalogue of diagnostics | 50 | 280 units side by side, 331 seconds of them, each compiled by a launch of `ern` of its own |
| the Emacs mode | 36 | `typing.el`, which re-indents the whole file at every cut; the other seven take 6 seconds or less, side by side |
| the unit tests, the applications side by side | 27 | the emitter's tests, 23 seconds one after another, most of it tests that wait: 5 for 5,000 alarms, 1.7 twice for `Os.run`, 1.3 for a restart. Its golden files take 0.14 |
| a rebuild | 10 | after any beam under `erl/` is newer, a test's among them: the standard library, the libraries, the shell and the manual pages built again, and the tests' programs compiled again at their next run |
| the documents and the style | 2 | |

A launch of `ern` costs 0.3 seconds before it does anything, a build of a one-line module 0.6, and the same build in a node that is already running 0.08.

## Proposals

1. **`paced_output` ends after its memory sample**, saving about 23 seconds.
2. **`make test` runs the areas in parallel**, after the tests that compute are given explicit timeouts, since EUnit's 5 seconds fail under load. The suite then takes about as long as its longest area, the shell's 95 seconds, and somewhat more under the load it makes itself.
3. **The shell's tests wait for a condition, not a fixed time**: the prompt, or a program's first output. About 12 seconds, and no timing that races.
4. **`typing.el` checks each cut only near the cut**, saving most of its 36 seconds.
5. **The shell's tests run in parallel with each other**, each with a home and a scratch directory of its own. With proposal 2 this area is the longest.
6. **The catalogue's rejected programs are compiled in one node**, through `ern_cli:ern/2`, not a node each, saving most of the guide area's time.
7. **The rebuilds follow the compiler's own rule.** The Makefile deletes `build/stdlib`, `build/libs`, `build/shell` and `test/build` whenever any beam under `erl/` is newer, on the ground that a changed compiler leaves the build records valid; since §11.1 recompiles a module built by another build of `ern`, `ern build` already rebuilds what a changed compiler changes. Without the deletions a change outside the compiler rebuilds nothing, saving the rebuild's 10 seconds and the tests' recompiling, and every run tests the rule. It needs a defect fixed first: `compiler_build/0` hashes a list of the compiler's modules that leaves out six it calls, `ern_ast`, `ern_bitspec`, `ern_descriptor`, `ern_docs`, `ern_iface` and `ern_scope`, so a change to one of them leaves every `.erc` current; the deletions have hidden it here, and a user's build meets it.
8. **The compiler's hash leaves out `ern_cli`'s other jobs.** `ern_cli` is in the hash, so a change to `ern run`, `ern shell`, `ern format` or `ern config` recompiles every module; the build's own code in a module of its own would narrow it to what shapes a `.erc`.
9. **An application's unit tests run in parallel with each other**, those that share no state, as EUnit's `inparallel` runs them. The emitter's 23 seconds would come down to about its longest test, 5. With proposal 2 this is off the longest path, and frees a core.
10. **Every build a test makes that needs no host of its own runs in the test's node**, through `ern_cli:ern/2`, as proposal 6 does for the catalogue: the examples' builds in the programs area and the guide's builds, where a build by a launch of its own takes 0.6 seconds and one in the node 0.08. A program's run keeps its launch, since a program is a node of its own.
