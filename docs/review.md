# The review before a release

What a release adds to [`coherence.md`](coherence.md). A review begins on a clean tree with `make test` green, once that document's rows have passed, run whole as it says for a release; the rows below belong to a release alone and repeat none of its. The plan says when a review runs and holds its ledger; the log records what its findings decided. A reader follows `coherence.md`'s rules for readers, and every finding is decided as they say. What the review before 1.0 adds is the plan's MVP 3.9.

## The machines

| | What | Passes when |
|---|---|---|
| R1 | the numbers the next release compares against: the report's measure and each section's length; what `coherence.md`'s C1 printed; the count of tests by suite, of prelude names, of standard library functions by module, of primitives, and of the concepts and reserved words C4 counts; the lines of Erlang and of Ernest by application; the memory, atoms and processes of the loads of `memory.md` and how long each takes, an echo server's round trip, and a compile of the standard library | recorded in the plan's ledger beside the last release's, of which the first release has none; a count that changed, or a measured number that moved by more than a fifth, without a plan item that moved it is a finding |
| R2 | the whole suite under the emulator's most modified timing, `+T 9`, and three times in a row while every core of the machine runs a busy loop | green every time; a failure on any run is a finding, since a race shows only now and then |
| R3 | `make load`, and the reading, as [`memory.md`](memory.md) says | every load flat by its bounds, and what the reading found decided; a growth is a finding, fixed as CLAUDE.md's *Defects and gaps* says |
| R4 | the commands of the README and of `docs/development.md`, in a fresh clone on a machine with only what they say is needed | each does what they say |
| R5 | the installation, on Linux and on macOS: installed into a temporary prefix, moved to another, run from there (`ern run`, `ern shell`, `ern doc`, a manual page), and uninstalled, as `make test`'s `install_test_` does ([`install.md`](install.md)) | each works, and nothing of Ernest's is left |
| R6 | the suite on Linux and on macOS under the OTP version the README names, once under `LANG=C`, and the shell once each in a plain terminal, in `tmux`, and with `NO_COLOR` set | green, and the shell colours as §11.2's *Colour* says |
| R7 | every declaration added to an existing module since the last release, and the modules the last release compiled, of which the first release has none | each declaration carries a `since` line with the new version (E.0 shape rule 6), and the current toolchain, given the old `.erc` beside its source, builds it again rather than loading it (§11.1) |

## The readers

| | Reader | Brief |
|---|---|---|
| R8 | the boundaries reader | "Read the foreign boundary's checks, the configuration directory and its key, a path from the network, a socket's input, a program's arguments and environment, the host programs `Os` starts and what they write back, and the shell's history file. Report each place where untrusted input reaches something it should not." |
| R9 | a person who did not write the shell | "Use `ern shell` at a terminal for an hour, on programs of your own. Report everything that went wrong or surprised you." |

## Done

The review is done when every row of `coherence.md` and of this document has passed, and the release notes are written: what changed since the last release, from the plan's milestones and the log's entries, each change with the report section that states it. The release is then tagged.
