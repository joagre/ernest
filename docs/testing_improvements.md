# Testing improvements

Where the time of `make test` goes, and what would shorten it. A proposal stays until a plan item decides it, and keeps its number.

## Where the time goes

Measured on 2026-09-28, on an idle host with 8 cores: `make test` took 237 seconds, one area after another.

| Area | Seconds | What dominates |
| --- | ---: | --- |
| the shell and the terminal | 95 | the pseudo-terminal harness's fixed `sleep` steps, and three memory tests of about 5 seconds each |
| the programs | 59 | `paced_output`, 20: its one check is a memory sample after 3 seconds |
| the guide, the report and the catalogue of diagnostics | 38 | the catalogue's 197 rejected programs, each in a node of its own |
| the Emacs mode | 29 | `typing.el`, which re-indents the whole file at every cut |
| the unit tests, the applications in parallel | 24 | the emitter's golden files |

## Proposals

1. **`paced_output` ends after its memory sample**, saving about 16 seconds.
2. **`make test` runs the areas in parallel**, after the tests that compute are given explicit timeouts, since EUnit's 5 seconds fail under load. About 110 seconds.
3. **The shell's tests wait for a condition, not a fixed time**: the prompt, or a program's first output. About 12 seconds, and no timing that races.
4. **`typing.el` checks each cut only near the cut**, saving most of its 25 seconds.
5. **The shell's tests run in parallel with each other**, each with a home and a scratch directory of its own.
6. **The catalogue's rejected programs are compiled in one node**, through `ern_cli:ern/2`, not a node each, saving most of the guide area's time.
