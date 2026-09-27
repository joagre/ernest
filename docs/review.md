# The review before a release

What a release adds to [`coherence.md`](coherence.md). A review begins on a clean tree with `make test` green, once that document's rows have passed, run whole as it says for a release; the rows below belong to a release alone and repeat none of its. The plan says when a review runs and holds its ledger, and any question the review leaves open is a row of it; the log records what its findings decided. A reader follows `coherence.md`'s rules for readers, and every finding is decided as they say. What the review before 1.0 adds is the plan's MVP 3.9.

## The machines

| | What | Passes when |
|---|---|---|
| R1 | the numbers the next release compares against: the report's measure and each section's length; what `coherence.md`'s C1 printed; the count of tests by suite, of prelude names, of standard library functions by module, of primitives, and of the concepts and reserved words C4 counts; the lines of Erlang and of Ernest by application; the memory, atoms, processes and speed of the load programs, an echo server's round trip, and a compile of the standard library | recorded in the plan's ledger beside the last release's, of which the first release has none; a number that moved without a plan item that moved it is a finding |
| R2 | the whole suite under the emulator's modified timing, `+T`, and the terminal tests while every core of the machine runs a busy loop | green |
| R3 | the load programs MVP 2.7's memory item names, run as it states | memory, atoms and processes within the growth it states; growth that no collection reclaims is fixed at its cause (CLAUDE.md, *Defects and gaps*) |
| R4 | the README's commands, in a fresh clone on a machine with only what the README says is needed | each does what the README says |
| R5 | the installation: installed into a temporary prefix, moved to another, run from there (`ern run`, `ern shell`, `ern doc`, a manual page), and uninstalled | each works, and nothing is left |
| R6 | the suite on the OTP versions and the operating systems the README names, under `LANG=C`, and the shell in a plain terminal, in `tmux`, and with `NO_COLOR` set | green, and the shell colours as §11.2's *Colour* says |
| R7 | every declaration added since the last release, and the last release's compiled modules, of which the first release has none | each declaration carries a `since` line with the new version (E.0 shape rule 6), and the current toolchain recompiles the old `.erc` (§11.1) |

## The readers

| | Reader | Brief |
|---|---|---|
| R8 | the boundaries reader | "Read the foreign boundary's checks, the configuration directory and its key, a path from the network, a socket's input, and the shell's history file. Report each place where untrusted input reaches something it should not." |
| R9 | a person who did not write the shell | "Use `ern shell` at a terminal for an hour, on programs of your own. Report everything that went wrong or surprised you." |

## Done

The review is done when every row of `coherence.md` and of this document has passed, and the release notes are written: what changed since the last release, from the plan's milestones and the log's entries, each change with the report section that states it. The release is then tagged.
