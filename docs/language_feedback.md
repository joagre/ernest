# Language feedback

What writing Ernest has felt against the principles: the shell, the standard library,
`libs/markdown` and the guide. This file holds each entry until a plan item decides it,
and MVP 2.65 decides them, theme by theme (the plan's MVP 2.65); a few wait for a later
MVP, which the entry names. An entry ends in a report change, a "Later" entry in the log,
or a line saying it was weighed and left alone, and then it leaves this file.

The entries are grouped by the question they share, and keep the numbers they were found
under, since the plan, the log and the code cite them. Thirty-five have left: 1 (decided, report
§4.2, `Prelude.X`), 6 (done, E.5's `indexOf`), 10 (a defect of the shell, fixed), 12
(decided, report §9), 2, 4 and 43 (weighed and kept, the log's *Constructor Names Stay Unique
in a Module*, *Names Stay Qualified, Without Import or Alias* and *Two Visibilities Are
Enough*), 17 (decided, report §11.2), 51 (decided, report §3.5), 18 (weighed and kept out,
the log's *No Projection From a Tuple*), 19 (decided, report §5.9), 32 and 33 (decided,
report §4.4), 49 (decided with them: the editor's state and the region are abstract, and a
history type was weighed and left, since its one rule, the cap of a thousand inputs, a
session does not reach, and it would make the editor depend on `Shell.History`), 3 and 5
(weighed and kept, the log's *Constant Patterns Stay Out* and *`after` Stays Reserved*), 48
(decided, report §8.5, the mention rule kept), 36 (already decided, report §9.6), 39
(decided, report §4.7), 45 (decided, report Appendix E.0 rule 9), 52 (weighed and kept, the
log's *One Contract, Several Representations*), 9 (decided, the plan's MVP 2.65 step 5:
`ern` prints every fault to standard error), 53 (decided in the same step: no registry, a
service is a top-level binding, and a restart keeps the address), 24 (decided there too:
`Address.process` gives a `Process`, the identity with equality), 26 (decided there:
`stdlib/process.ern` lists the live processes, and the shell reads it), 28 (decided there:
`Process.faults` delivers every fault, and the shell keeps its own log), 50 (decided there:
a timed read, accept or connect takes its time limit into the request), 47 (decided there:
a system message type's constructors are its system module's), 37 (decided there:
`Tcp.port` answers a listener's port), 27 (decided there: `Terminal.subscribe` refuses
where standard input is not a terminal), and 11, 13, 42, 46 and 34 (decided in step 6's first
batch: a shim is only an operation that reaches the representation).

## 1. Names and namespaces

Decided on 2026-09-25, and no entry is left; the plan's MVP 2.65 names each decision, and
item 46 went to the standard library's theme.

## 2. Expressions, patterns and types

Decided on 2026-09-25 and 2026-09-26, and no entry is left; the plan's MVP 2.65 names each
decision.

## 3. Processes and the system

Decided on 2026-09-26; the plan's MVP 2.65 step 5 names each decision. Items 14 and 25 are
MVP 3.0's, and 16 is MVP 2.7's; they stay here because they are the same question.

14. **Is `remote` needed once the node protocol and code distribution exist?** Raised while
    the guide was being checked, with `docs/node_protocol.md` and `docs/code_distribution.md`
    in view. `remote(f)` (report §6.7, guide §8.1) runs a pure function on a peer the runtime
    chooses among those marked `"remote-peer": true`, and answers `Right(v)`,
    `Left(NoRemotePeer)` or `Left(PeerLost)`; a fault in `f` faults the caller.

    The case for removing it, on the principles. Once `spawn(Peer(name), f)` ships code and
    answers across nodes, `remote` is a second way to do what a spawned process that answers
    already does, `spawn` on a peer and `Address.call` for the value (principle 2). It
    brings a type of its own, `RemoteError`, a configuration flag, and a placement policy
    the runtime applies where the program cannot see it (principle 3). The guide's
    `inParallel` already spawns a local process per computation around it, so the
    primitive does not spare the program the processes it would otherwise write.

    What would be lost, and has to be answered before it goes. A pure computation shipped
    as a value is simpler to reason about than a process: no mailbox, no reply, a fault
    that reaches the caller as if the call were local. The runtime's choice of peer is a
    load-balancing policy that would become a library's or the program's. And `remote` is
    in the report's prelude, §9, and the guide's examples, so removing it is a report change
    with the log's *Remote Ergonomics* (2026-09-13) to revisit.

    Decided first in MVP 3.0, before `remote` is built over peers.
25. **`spawn(Remote, f)`, the asynchronous `remote`.** A process already starts on a named
    peer, `spawn(Peer(name), f)` (§6.2), and answers asynchronously; what only `remote(f)`
    has is the runtime's choice of peer, among those §11.3 marks as accepting remote
    computation, and it is synchronous. A third place, `type Where = Local | Peer(String) |
    Remote`, would give that choice to a process: a long computation no longer holds the
    caller, and it may send more than one answer. With it, `remote(f)` is `spawn(Remote,
    ...)` and a reply, a composition, which strengthens item 14's case against it by
    principle 2. To be answered: what `spawn(Remote, f)` does where no peer accepts remote
    computation, where `remote` answers `Left(NoRemotePeer)` and `spawn` has only an
    address to return, and a silent fall back to `Local` is what principle 3 refuses, so
    it faults; and that the flag in `ernest.conf` then admits any process a peer sends,
    where today it admits a pure function, so what a peer accepts widens and §11.3 says
    so. The placement stays the runtime's, as unseen by the program as `remote`'s is.
    Decided with item 14 in MVP 3.0.
16. **A program cannot read its command-line arguments.** An entry point takes no
    arguments (report §8.1), and neither the prelude nor a system module gives the command
    line, so a program's inputs are written into it or read from standard input. A reader
    new to the language asked for it at once. Planned since 2026-09-20 in MVP 2.7, which
    builds `Sys.args` report first and weighs an entry point `main(args : List(String))`
    against it.

## 4. The standard library under E.0

Each entry is weighed on E.0's admission rules, one by one, and most are small, so they can
be decided in batches. The first, where the line between a shim and Ernest runs, was
decided on 2026-09-26. Two groups are left: what a function is named and where it lives
(40, 41, 38), and functions the library lacks or has in a form that misleads (the rest).

40. **E.0 rule 3 and the `fromList`s.** The rule puts a conversion in the subject's module,
    yet `String.fromList`, `Map.fromList`, `Set.fromList` and `Either.fromOptional` live in
    the target's. The rule is reworded to say so, or the functions move.
41. **Naming inside modules.** `Set.intersect` is a verb beside the nouns `union` and
    `difference`; `String.contains` is a substring test where the container verb means
    membership, against rule 2's one verb for one operation.
38. **`Ets`'s verbs** are `insert`, `lookup`, `delete`, `member`, where E.0 names the
    container verbs `put`, `get`, `remove`, `contains`; and `drop` means another thing in
    `List`. Whether a library follows E.0's names.
8. **The width a grapheme takes on a terminal.** Since 2026-09-24 the unit a `String`
   counts is a grapheme (E.5). A wide glyph is one grapheme and two columns, and nothing in
   the runtime knows it; the shell's region counts one column a character, and
   `Shell.Region.expand` is the one function that would learn it. With item 23.
23. **The columns a styled row takes are counted twice.** `Shell.Region.columns` and the
    Markdown library's `columns` are one function, skipping `ESC [` sequences, written in
    two places. Neither owns the other; the question is whether what a row takes at a
    terminal belongs to `Terminal` in Appendix E, which is where the escape sequences come
    from.
7. **`String.lines` is not the split a text editor wants**: it drops the empty last line,
   so the region had to use `String.split(typed, "\n")` to show the empty row being typed
   on. Both are documented and correct; the obvious-looking one is the wrong one.
20. **No `String.trimStart` or `trimEnd`.** Only `trim` strips both ends. Dropping a line's
    indentation went through `List.span` over `String.toList` and a `String.slice`, and
    dropping a heading's closing `#`s reversed a list of characters. Erlang's
    `string:trim/3` takes a direction and Gleam has `trim_start` and `trim_end`; whether E.0
    admits them, one by one.
21. **No `String.drop`.** The rest of a string from a position is
    `String.slice(s, n, String.size(s) - n)`, written five times. E.0 rule 4 refuses a
    composition of two functions already there, which this is; the count is an argument
    and not the gate, and the verdict may be that it stays.
22. **`List.span` stands in for `dropWhile`.** `let #(_, rest) = List.span(xs, p)` four
    times, and the flattening of rows is `List.flatMap(xs, fn(x) = x)` as E.0 rule 4 says.
    Both are the rule working as written; decided with 21, since the three are one question
    about rule 4.
35. **No ASCII digit test.** `Char.isDigit` is Unicode's Nd, so a format parser, the Markdown
    library's list numbers and `String.toInt` among them, writes its own `0`-to-`9` test.
    Whether `Char` gains one, by E.0.
15. **No merge that combines the values of a key both maps hold.** `Map.merge` keeps the
    second map's value, so totalling two maps of counts is a fold,
    `Map.foldLeft(more, counts, add)` with `add(counts, word, n)`. The fold is ordinary
    Ernest and reads well once `add` has the fold's shape, so nothing was worked around;
    Erlang has `maps:merge_with/3` and Gleam `dict.combine`. Whether E.0's rules admit a
    `Map.mergeWith(m, other, f)`.
31. **An `IoError` has no text.** The shell writes `trouble(IoError)` for its messages, and
    every program that touches a file will write the same function; whether E.17 gives
    `IoError` a description, or E.0 rule 3 refuses it as a format policy.
44. **No function gives the text `Io.debug` prints**, so a test can only report a value by
    a text of its own making (the Markdown library's tests report "N blocks"). Whether E.1
    gains `Io.show`, or a test's failure prints a value by the same printer.

## 5. The toolchain and the shell

What the shell does that its own code, rather than the language, decides.

30. **`:load`'s completion restates the path-to-namespace rule** of §4.2 and §11.1
    (`isPathWord`, `capital` in `shell.ern`), which the compiler also owns. Whether the rule
    belongs to a function both use, in the front end or in Appendix E.
54. **Completion after a value's `.`.** Since fields are selected (§3.5), `state.` and
    `Tab` at the prompt could offer the fields of the value's type, as `List.` offers the
    module's names; §11.2's completion reads what is before the last `.` as a namespace,
    so it offers nothing. Whether completion reaches a value's fields, which needs the
    value's type where the parser stopped.
29. **The editor's words are split at spaces only**, so `M-b` over `List.map(xs` jumps it
    whole; Readline's words are alphanumeric runs. Which the shell should follow.
