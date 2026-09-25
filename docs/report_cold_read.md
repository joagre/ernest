# The report read cold

On 2026-09-25 a reader who had never seen Ernest read `ernest_report.md` alone, as its
implementer, and opened nothing else in the repository (the plan's MVP 2.65, step 2). They
found 79 places where the report did not suffice. Each was then checked against the
implementation, and those with one clear reading were written into the report the same day,
with a test where none held them: 1.3 to 1.5, 1.9 to 1.12, 1.14 to 1.16, 2.3 to 2.5, the
first halves of 2.8 and 2.9, 2.7, 2.12, 2.14 to 2.16, 2.20 to 2.23, 2.25, 2.27 to 2.32, 3.1 to
3.11, 3.14 to 3.16, 3.18 to 3.28, and halves of 3.17 and 3.29; 2.10, 2.11 and 3.13 went with
an abstract type's boundary (§4.4). 2.1 and 2.2 were decided with the reply rule on 2026-09-25
(§3.9, the log's *Not-Reply-Carrying by What the Body Does*); 1.2, 1.6, 1.13, 2.6, the
second halves of 2.8 and 2.9, 2.17 and 2.34 the same day (the log's *An Initializer Depends
on What It Names* and *The Cold Read's Smaller Rules*), and 1.1 and 2.13 on 2026-09-26 (the log's
*A Pure Function Stands for One With a Mailbox* and *A Redundant Clause Is an Error*).

This file holds the rest until MVP 2.65 decides each, under the theme of the feedback list
that takes it; a finding leaves the file when it is decided. Each keeps its number and the
reader's text, and says what the implementation does today and what the check recommended.
Line numbers are the report's on 2026-09-25.

## Processes and the system

1.8. **Whether `send(Sys.stdout, "x")` is legal.** §8.2 (L622) "A program uses each through
the standard library"; §9 (L693) "a program does not send to a system reference (E.0 rule
8)"; E.0 rule 8, a rule on the library's shape, "never by `send`"; E.1 (L1161) "A string
goes to any other `Address(String)` by `send`". A compile error or a convention? The
reader's guess: a convention.

*Checked.* Today: legal, directly and through a variable. Recommended: legal, E.0 rule 8
being the library's shape and not a prohibition, since an address has no identity to check
it by.

2.18. **A fault in a callback other than `via`'s.** `via`'s rule is explicit (L500); for
`monitor`'s wrap and the callbacks of `Clock.alarm` and `Terminal.subscribe`, where the
callback runs and who dies if it faults.

*Checked.* Today: a `monitor` wrap that faults kills the runtime's reaper, and every later
`spawn` hangs; a wrap that never terminates, given to `Clock.alarm`, freezes the clock for
every process. Recommended: a wrap that faults faults the caller, and one that does not
terminate delays no other delivery.

2.19. **How a program ends otherwise.** §8.6 (L673) covers `main` returning or faulting,
§11.2 (L851) the statuses of those two. Unstated: whether the program ends if `main` is
killed; the status and what is printed for a faulting initializer (§8.5); the status after
an external signal.

*Checked.* Today: a killed entry process prints `fault: 'Killed'` and exits 1; SIGHUP is
ignored; SIGINT ends the node abruptly with status 130. Recommended: the program ends when
the entry process dies; a killed one prints `killed` and exits 1; a signal from outside
exits 128 plus its number and prints nothing.

3.29. **`kill`'s edge cases**: a dead process, a `Sys.*` address; and a fault in `via`'s `f`
kills the target (L500), which may be a system process.

*Checked.* The system-process half; `kill` on a dead process is in §6.9 since 2026-09-25.
Today: `kill(Sys.stdout)`, or a faulting `via` function aimed at it, silently loses all
output, what was sent before included. Recommended: `kill` on a system reference faults the
caller, and a faulting `via` function aimed at a system process faults the sender.

## The standard library

1.7. **String semantics.** The order of `String.compare` and `Char.compare` (§3.10 L221,
§9.6 L796, E.5): code point, UTF-8 byte, or grapheme. Whether `contains`, `startsWith`,
`endsWith`, `replace`, `split` and `indexOf` match code points or grapheme clusters, and
what index a match inside a cluster has (E.5 L1269; feedback item 34). What whitespace
`trim` strips (L1284), §2.1's four or Unicode's White_Space. Full or simple case mapping
for `toLower` and `toUpper`. The reader's guesses: code points, code points, White_Space,
full mapping.

*Checked.* Today: the functions mix grapheme, code-point and byte matching; `compare` orders
by code point; `trim` strips neither §2.1's four nor `Char.isSpace`'s; case mapping is full
without its conditional mappings. Recommended: code points for matching and graphemes for
counting, `compare` by code point, `trim` by `Char.isSpace`, stated in E.5 (with feedback
item 34).

2.24. **Standard input's details** (§8.2 L626, "without its line feed"): the CR of a CR LF;
invalid UTF-8; a last line with no line feed.

*Checked.* Today: standard input and output follow the host's locale, and invalid UTF-8 on
stdin corrupts every later non-ASCII output. Recommended: a line is UTF-8 whatever the
locale, and reading bytes from stdin goes to the feedback list as a gap; `String.lines`
drops one carriage return before a line feed.

2.26. **`Float.toString`'s form** (E.9 L1352, "shortest decimal that reads back"): when the
exponent form is used, and whether it always reads back by `String.toFloat`'s form.

*Checked.* Recommended: the shortest digits that read back, plain from 0.0001 to below
1.0e16 in magnitude and otherwise `d.ddde±n`.

## The toolchain

2.33. **The shell's commands** (§11.2): `:browse`, `:forget`, `:type`, `:doc` and `:set`,
with its depth, length and output, are named and not defined; no help command is named, and
nothing says how a session ends.

*Checked.* Recommended: a Commands paragraph in §11.2, about 190 words, one sentence a
command, reversing the log's choice to leave them to `:help`.

3.12. **The configuration directory.** `--config-dir dir` names the `.ernest` directory
itself (default `./.ernest`, L873), but `--create-config-dir dir` creates `dir/.ernest`
(L877).

*Checked.* Recommended: both options name the configuration directory itself. With the
toolchain's option names.

3.17. **§2.2's comments.** Whether `////` is a doc comment; whether a `*/` inside a string
inside a block comment ends it; whether an end of line is LF only.

*Checked.* The `////` half; a block comment and the end of a line are in §2.2 since
2026-09-25. Today: `////` begins a doc line whose text starts with `/`. Recommended: a doc
comment is exactly `///` followed by something other than `/`, as Rust's is.

3.30. **`ern --test`'s order**: tests concurrently or in sequence, and the output's order.

*Checked.* Today: tests run one at a time in source order and their lines are printed at the
end; a deadlock in one test ends the whole run with nothing reported. Recommended: a line
printed as each test ends, and a deadlock the running test's fault, the run going on.
