# The review before a release

What a release adds to [`coherence.md`](coherence.md): the review runs every row of that document whole, then the rows below, which belong to a release alone. The plan says when a review runs and holds its ledger; the log records what its findings decided. A reader follows `coherence.md`'s rules for readers, and every finding is decided as they say.

## The machines

| | What | Done when |
|---|---|---|
| R1 | the numbers the next release compares against: the report's measure and each section's length, `make sections` and `make coverage`, the count of tests by suite, of prelude names, of standard library functions by module and of primitives, the lines of Erlang and of Ernest by application, and the memory, atoms, processes and speed of the load programs | recorded in the plan's ledger beside the last release's; a number that moved without a plan item that moved it is a finding |
| R2 | the whole suite under the emulator's modified timing, `+T` | green |
| R3 | the load programs, the examples as servers and the shell over a long scripted session, run for the number of iterations MVP 2.7's memory item states | memory, atoms and processes flat; growth no collection reclaims is fixed at its cause, never by a cap |
| R4 | the README's commands, in a fresh clone on a machine with only what the README says is needed | each does what the README says |
| R5 | the installation: installed into a temporary prefix, moved to another, run from there (`ern run`, `ern shell`, `ern doc`, a manual page), and uninstalled | each works, and nothing is left |
| R6 | the suite on the OTP versions the README names, on Linux and on macOS, under `LANG=C`, and the shell in a plain terminal, in `tmux`, and without colour | green, and the shell as §11.2 says |
| R7 | every vendored file and every table built from another's data | listed in `THIRD_PARTY_LICENSES` with its licence, its upstream header kept |
| R8 | every declaration added since the last release, and the last release's compiled modules | each carries a `since` line with the new version (E.0 shape rule 6), and the current toolchain recompiles the old `.erc` (§11.1) |

## The readers

| | Lens | Hands in |
|---|---|---|
| R9 | the trust boundaries: the foreign boundary's checks, the configuration directory and its key, a path from the network, a socket's input, the shell's history file | each place where untrusted input reaches something it should not |
| R10 | the diagnostics: a catalogue of one small program for every error the checker gives | each message against §11.5's shape, and whether a reader who made the mistake understands the fix |
| R11 | newcomers, who know only the guide, each writing one program: a chat server, a tool over files, and a pipeline over standard input | where the language, the library or a message stopped them; a program that shows what no example does joins `examples/` |
| R12 | the shell in a person's hour of real use | what went wrong, as MVP 2.6 closed with |

## Done

The review is done when every row of `coherence.md` and of this document has passed, every finding in the ledger is fixed, planned in a named milestone, or weighed and kept, and the release notes are written: what changed since the last release, from the plan's milestones and the log's entries, each change with the report section that states it. The release is then tagged.
