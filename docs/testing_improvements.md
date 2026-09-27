# Testing improvements

Where the time of `make test` goes, and what would shorten it. The checks themselves, and when each runs, are [`coherence.md`](coherence.md)'s; this file is only about how long they take. It holds each proposal until a plan item decides it: done, planned with a date, or weighed and left alone. A decided proposal leaves the file, and a proposal keeps the number it was written under.

## Where the time goes

Measured on 2026-09-27 at commit `4c39893`, on an otherwise idle host with 8 cores. A full `make test` took 198 seconds.

| Part | Seconds | What dominates |
| --- | ---: | --- |
| The `test/` areas, one after another in one EUnit call | about 146 | the shell 84, the programs 53, the guide 8, the documents 1.5 |
| The Emacs mode's tests | 30 | `typing.el`, 25 |
| The unit tests, the applications in parallel | 24 | the emitter's golden files, 23 |

Within those parts:

- `paced_output` in `test/ern_integration_tests.erl` takes 20 seconds. Its one check is a memory sample taken after 3 seconds; the other 16 wait for two million paced lines to finish.
- Three of the shell's memory tests take about 5 seconds each.
- Each other shell test takes 0.5 to 1.5 seconds. A shell starts and quits in 0.49; the rest is the pseudo-terminal harness, whose fixed `sleep` steps add up to 9.6 seconds over 17 steps.
- The interrupt test sleeps 2 seconds before it sends its signal.
- `typing.el` re-indents the whole file at every cut of every file it types, so its time grows with the square of a file's length.
- An `ern` command starts in 0.39 seconds: 0.24 is the Erlang VM, and 0.15 the escript. The tests start `ern` about 100 times, many of them in parallel, so start-up is a cost but not the main one. Start-up looks up no host name, since `ern` starts no distribution: `ERL_INETRC` set to read the hosts file first, and `-connect_all false`, changed neither time, measured on 2026-09-28.

Run side by side with `make -j5`, the four `test/` areas and the Emacs tests took 102 to 106 seconds instead of about 176. In one of two rounds, `block_of_one_test` in `test/ern_style_tests.erl` passed EUnit's default timeout of 5 seconds under the combined load.

## Proposals

1. **`paced_output` ends after its memory sample.** It saves about 16 seconds and checks the same thing.
2. **`make test` runs the areas in parallel.** The tests that can pass 5 seconds under load, the style tests first, are given explicit timeouts before it. A full run would take about 110 to 120 seconds.
3. **The shell's tests wait for a condition, not a fixed time**: the prompt, or a program's first output, as the test of reading standard input does since `c7a185c`. It saves about 12 seconds, and removes timing that races, as that test's did.
4. **`typing.el` checks each cut only near the cut**, or cuts less often. It saves most of its 25 seconds.
5. **The shell's tests run in parallel with each other.** After proposal 2, the shell area is the longest, at about 84 seconds. Each test first needs a home and a scratch directory of its own.
