# Language feedback

Let us discuss all this.

Field selection is the biggest issue, and the shell has now given it three witnesses (the screen's record, then `Shell.Editor.State` twice — `fn text(editing) = match editing { State(text = text) -> text }` exists only to read one field). The others, roughly strongest first:

## Language proper

1. **Decided 2026-09-24: `Prelude.Close` reaches past it (report §4.2).**
   **A local constructor name hides the prelude's, with no way to reach past it.** Four
   witnesses now: `Outcome.Failed` against `TestResult.Failed`, and, on 2026-09-21, a
   `Last = Other | Tabbed | Documented` in the shell that hid `IoError.Other` in a function
   twenty lines away, which the compiler caught as "Other takes no fields". The rename was
   again an improvement, and again the rule offered no way out but a rename. §4.2 says a module may declare a constructor with a prelude name and the name then means the local one *throughout the module*. Types have namespaces, but prelude constructors have none, so there is no `TestResult.Failed` to fall back on. That is what made the region's tests impossible inside `shell.ern` until `Outcome.Failed` became `Faulted`. The rename was an improvement, so nothing was lost this time — but the rule has no escape hatch, and the next collision may not have a better name waiting.

2. **Constructor names unique across a module's types.** Felt three times: the `Output2` dodge, the editor's `Typing`/`Clear`/`Cancel` wanting names the screen had, and the `Failed` case above. Each time the right answer was to split a module, which is a good outcome — but it means the namespace rule, not the design, is doing the pushing.

3. **No constant patterns.** `let ctrlW = '\u{17}'` cannot appear in a `match` arm; an identifier there binds. So Readline's key table is bare literals with trailing comments (`'\u{17}' -> … // C-w`). A guard (`c == ctrlW`) is the alternative and reads worse. I would still not add them — it is a real cost honestly paid for one-way pattern semantics.

4. **Qualified constructors are heavy at use sites**, and there is no import or alias (§4.2 is explicit: no export list, no `import`). The reader loop matches five `Shell.Editor.*` constructors in one `match`. Explicit and correct; also the main argument anyone will make for aliases later.

5. **`after` is reserved**, so a natural helper name for "the rest of a string from here" had to become `from`. Trivial, but the kind of thing that accumulates. Felt again on 2026-09-25 in `libs/markdown`, where `after` was the name every scanning function wanted for what follows a match; it became `later` throughout.

## Standard library, not language

6. **`String.indexOf` was missing** (found writing the incremental search; now in E.5 with `lastIndexOf`).

7. **`String.lines` is not the split a text editor wants** — it drops the empty last line, so the region had to use `String.split(typed, "\n")` to show the empty row you are typing on. Both are documented and correct; the obvious-looking one is the wrong one.

8. **What a "character" is** — the report said code points, the code counts extended grapheme clusters, and `toList` gives code points. Settled in favour of the code, and since 2026-09-24 the unit is named a grapheme, so the word "character" no longer means a `Char` in one place and a grapheme in another (report E.5). Display width is still open: a wide glyph is one grapheme and two columns, and nothing in the runtime knows it.

## Neither — worth separating out

The `Shell.Editor.fresh` resolution failure and the three runtime races were implementation defects, not language warts; they only showed that the report was silent on a consequence (§4.2 gained one sentence).

What I would actually put to you as candidate language changes: field selection (planned for MVP 2.65) and, much more tentatively, some way to name a prelude constructor a module has shadowed, decided on 2026-09-24 as `Prelude.X`. The rest I would record and leave alone.

## Found while writing completion, 2026-09-21

9. **A fault in a foreign function's *return* is silent to the caller's caller.** `fields_of`
   answered Erlang strings where the ABI wants binaries, so §8.4's boundary faulted the
   reader — correctly — and the shell became a zombie that painted but never read a key. The
   fault was right; nothing said it. The shell now monitors its reader and says so, but the
   general shape is worth a thought: a process that dies of a boundary fault takes its
   silence with it unless someone monitors it.

10. **Fixed 2026-09-24: typing ahead lost the second input (plan, MVP 2.6).** Found by a
    test that sent a second input before the first had finished; the second never produced a
    result. The session, awaiting the first input's result, took the second out of its mailbox
    and dropped it. The shell's own defect, not the language's.

## The standard library's shims, 2026-09-23

11. **Does the standard library follow a different rule from the rest of the Ernest we
    write, and should it?** Where it is written: E.0 rule 1 in the report is the normative
    one; CLAUDE.md states the rule for everything else and points at E.0 as the other side
    of the same line; the log has *Shims Where the Runtime Owns the Representation*
    (2026-09-20) and *Where `foreign` Stops* (2026-09-21).

    They are one principle, not two: a shim exists only where the **runtime owns the
    representation**. The counts bear that out. `list.ern` has none in thirty-two
    exports; `io.ern` one in six. The shim-heavy modules are `String` (20 of 28), `Float`
    (18 of 25), `Map` (16 of 20), `Set` (14 of 19), `Int` (12 of 22) and `Char` (10 of 11) —
    binaries, doubles, Erlang maps and sets, bignums and Unicode tables, none of which
    Ernest can build or fold case on.

    Two places where the rule is looser than it should be, and both should go the way of
    "write it in Ernest, measure later":

    - **Done 2026-09-23.** E.0 rule 1's second clause, "or the runtime's implementation is
      the one to trust", was the only opening in the library for an argument from
      performance, and it covered exactly one function: `List.sort`. `sort` is a merge sort
      in Ernest now, twenty lines, stable by taking the left element when two compare
      `Equal`; `ern_list.erl` is deleted, and rule 1 says one thing only, with "speed is not
      a reason for a shim" added. Measured after: twenty thousand elements in 17 ms.
    - **`path.ern` is seven shims of eight exports** over `filename:`, and the reason is in
      the report: E.14 opens with "a `Path` is in the runtime's syntax", so what a segment,
      a parent and a root are is the host's, and rule 1 admits the shims. That is a real
      host dependency, unlike `sort`'s: a separator is `/` here and `\` with drive letters
      elsewhere. What it does not justify is the surgery built on those facts. The rewrite
      to aim for keeps **two** shims, the host's separator and whether a path is absolute,
      which drive letters make more than a leading separator, and writes `join`, `split`,
      `parent`, `name`, `extension` and `withExtension` in Ernest over `String.split`,
      `String.lastIndexOf` and `String.slice`. Five shims go, and the host dependency is
      named in two functions instead of spread through seven. It is left for this item
      rather than done beside `sort`, since E.14's contracts have edge cases — a trailing
      separator, an absolute second operand, an empty extension — that want tests written
      with care rather than a quick rewrite.

    Performance is not a reason for a shim. If a measurement ever demands one, it comes back
    as a decision with numbers beside it, as `Tcp`'s socket processes did at 1.8 times raw
    Erlang and were kept.

12. **Decided 2026-09-24: §9 states the rule (report §9).**
    **Should `Map` be in the prelude at all?** It is, with `Set` and `List`, in
    `ern_prelude:builtin_types/0`, and the answer is yes — but the rule that decides it has
    never been written down. `Map` has no syntax: no literal, no pattern, nothing in the
    grammar. What keeps it in the prelude is that **its module is named after it**. A
    standard library type whose module is not — `Random.Seed` — is declared by its module
    and read from the compiled interface, so the machinery is there. Moving `Map` out
    would make it `Map.Map(String, Int)` in every annotation, which is the wart the rule
    avoids.

    So: a type whose module is named after it is the language's, and a type a module merely
    provides is the module's. Worth a sentence in §9 or E.0, since it is the rule behind
    `Int`, `Float`, `Char`, `String`, `Bytes`, `Bool`, `List`, `Map` and `Set` being built
    in, and nothing states it.

    The worry underneath the question is the shims, and that is entry 11: the operations
    being the runtime's is the representation decision, not a prelude decision.

13. **The rest of the shims, audited 2026-09-23.** Against the one rule — a shim only where
    Ernest cannot express the work given the modules beneath it — the library divides three
    ways.

    **Gone the same day:** `Int.abs`, `Int.min`, `Int.max`, `Float.abs`, `Float.min`,
    `Float.max`, six one-line shims over `erlang:abs/1`, `min/2` and `max/2` where the
    language already has `<`, `>` and prefix `-` on both types.

    **Should go, and are for MVP 2.65 with `path`:** `String.startsWith`, `endsWith`,
    `contains`, `parts`, `copy` and `replace`, all of which are `indexOf`, `slice` and
    `size` away from being Ernest, those three staying shims because they count extended
    grapheme clusters and nothing beneath `String` can. `Bytes.at`, `toList` and `pack` are
    a weaker case of the same: the bit syntax of §5.11 is beneath them, so they can be
    written, and only `size` and `part` need the runtime.

    **Staying, and why:** the `Map` and `Set` operations (the representation is Erlang's,
    which is its own decision); `Char`'s predicates and case, `String.compare`, `toLower`,
    `toUpper`, `trim` (Unicode tables); `Float`'s mathematics and `Int`'s bit operations
    (no primitives beneath them); every conversion `toString`, `inBase`, `toFloat`,
    `toUtf`, `fromUtf`, `toList`, `fromList` (rule 1 names them); `Random` (the generator's
    state is the runtime's); `Foreign` (the boundary itself);
    `Io.debug` (the runtime's printer and the compiler's descriptor).

## Distribution, 2026-09-24

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

    Planned: decided first in MVP 3.0, before `remote` is built over peers (the plan's
    MVP 3.0 section).

## Found while writing the guide's running example, 2026-09-24

15. **No merge that combines the values of a key both maps hold.** `Map.merge` keeps the
    second map's value, so totalling two maps of counts is a fold,
    `Map.foldLeft(more, counts, add)` with `add(counts, word, n)`. The fold is ordinary
    Ernest and reads well once `add` has the fold's shape, so nothing was worked around;
    Erlang has `maps:merge_with/3` and Gleam `dict.combine`, and whether E.0's rules admit
    a `Map.mergeWith(m, other, f)` is weighed in MVP 2.65's read-back of the standard
    library.

## Found by the guide's cold read, 2026-09-24

16. **A program cannot read its command-line arguments.** An entry point takes no
    arguments (report §8.1), and neither the prelude nor a system module gives the command
    line, so a program's inputs are written into it or read from standard input. A reader
    new to the language asked for it at once. Planned since 2026-09-20 in MVP 2.7, which
    builds `Sys.args` report first and weighs an entry point `main(args : List(String))`
    against it.

17. **At the prompt, a type's members come in the same input as the type.** A type's
    members belong to the module that declares it, and each input is a module of its own
    (report §11.2), so `type Money = Money(Int)` and then `fn Money.compare(...)` in the
    next input is refused with "Money is not a type declared in this module". Consistent
    with the module rule, and surprising at a prompt, where a person adds to what is there.
    Judged in MVP 2.65: whether the session may add members to a type it declared, or the
    message says to declare them together.

## Found writing `libs/markdown`, 2026-09-25

The first parser of size in Ernest, about five hundred lines over `List(Char)`. Reading
characters as a list with patterns, `'#' :: rest`, and a guard where a set of characters is
meant, read well; the entries are what did not.

18. **No projection from a tuple.** `List.span` answers a pair, and twice the half wanted was
    reached for as `.0` or `.1`, which Ernest does not have; `let #(_, rest) = ...` is the
    one way, a line longer. Principle 2 is for it staying so; recorded because it was felt.
19. **A `match` is not an operand.** `indent(line) < 4 && match markerOf(s) { ... }` is a
    parse error that asks for parentheses, three times in the library. The rule keeps the
    grammar simple (principle 4), and the error's help says what to write; the cost is
    parentheses that read as noise around a `match` that already has braces.
20. **No `String.trimStart` or `trimEnd`.** Only `trim` strips both ends. Dropping a line's
    indentation went through `List.span` over `String.toList` and a `String.slice`, and
    dropping a heading's closing `#`s reversed a list of characters. Erlang's
    `string:trim/3` takes a direction and Gleam has `trim_start` and `trim_end`; whether E.0
    admits them, one by one, is 2.65's.
21. **No `String.drop`.** The rest of a string from a position is
    `String.slice(s, n, String.size(s) - n)`, written five times. E.0 rule 4 refuses a
    composition of two functions already there, which this is; the count is an argument
    and not the gate, and the verdict may be that it stays.
22. **`List.span` stands in for `dropWhile`.** `let #(_, rest) = List.span(xs, p)` four
    times, and the flattening of rows is `List.flatMap(xs, fn(x) = x)` as E.0 rule 4 says.
    Both are the rule working as written; recorded with 21, since the three are one
    question about rule 4.
23. **The columns a styled row takes are counted twice.** `Shell.Region.columns` and the
    library's `columns` are one function, skipping `ESC [` sequences, written in two
    places. Neither owns the other; the question is whether what a row takes at a terminal
    belongs to `Terminal` in Appendix E, which is where the escape sequences come from.

## Found by `:processes`, 2026-09-25

24. **A process has an identity no one can see.** `:processes` lists three processes spawned
    by three inputs as `input:1` three times, and nothing tells them apart: an address prints
    as `<address>` (E.1) and has no equality (§3.10), because `via(f, a) == a` was held to
    have no right answer. Weighed on the principles: §6.3 says an address *identifies* a
    process, and hiding which one is what principle 3 refuses for communication; dropping
    the address half of §3.10's exception makes the language smaller (principle 5); a
    subscriber list that removes a subscriber carries an id in its protocol beside the
    address it already holds, two ways to say which process (principle 2); and a reader who
    knows Erlang, or who has seen everything else compare structurally, predicts `a == b`
    to mean the same process (principle 1). Principle 4 is untouched. The obstacle has an
    answer: equality as *reaches the same process*, so `via(f, a) == a`. Its cost is in the
    runtime: an adapted address is `{via, F, Target}`, and Erlang's `==`, which `Map`, `Set`
    and `List.contains` use, compares `F`, so equal addresses need a representation that is
    equal as a term, or an equality of the runtime's own. Across nodes the identity names
    the node, as a pid does. Decided in MVP 2.65 with the registry, since unregistering
    needs it; the plan states what each outcome changes.

## Asked beside item 14, 2026-09-25

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

## Asked beside item 24, 2026-09-25

26. **`:processes` as a function rather than a command.** The shell's `:processes` reads
    the runtime's record of every process it started, a door §11.2 opens for the shell
    alone; a program learns of a process only by holding its address, and of a death only
    through `monitor` (§6.9). Erlang's `processes()` is a function, and what it answers is
    a value a program filters, sends to, and monitors. A prelude or standard library
    function, `Process.live() : List(#(String, Address(...)))` or the like, would make the
    record a value like any other, and `:processes` would be that function printed, one
    way where there are two (principle 2), and nothing the shell sees that a program may
    not (principle 3). Against it: a program that can enumerate processes can reach one it
    was never handed an address to, which is the capability discipline the language keeps
    by making an address the only way to reach a process; the element type needs the
    mailbox type of every process, which is no one type, so the value would hold an
    address of unknown protocol that can only be monitored; and E.0's admission rules
    weigh a standard library function on its own. It turns on item 24, since a list of
    addresses is only useful where addresses can be told apart. Decided with items 24 and
    the registry in MVP 2.65.

## Found by the review of the Ernest code, 2026-09-25

Two readers reviewed every line of `shell/`, `stdlib/` and `libs/` against §0, E.0 and
CLAUDE.md. What was plainly wrong was fixed in the same pass; these are the questions it
raised, for MVP 2.65.

27. **Nothing in Appendix E says whether keys can be read.** The shell asks the host
    (`ern_shell:is_terminal/0`), a `foreign fn` for a fact `Terminal` owns; `Terminal.size`
    answers only whether output is a terminal. Whether E.16 should answer the question.
28. **The fault log is the host's.** `:faults` reads a list the front end keeps, where the
    session already receives every fault as a `Died` message and could keep the last
    hundred itself in Ernest. §11.2 calls it "the runtime's record", so moving it is a
    report question.
29. **The editor's words are split at spaces only**, so `M-b` over `List.map(xs` jumps it
    whole; Readline's words are alphanumeric runs. Which the shell should follow.
30. **`:load`'s completion restates the path-to-namespace rule** of §4.2 and §11.1
    (`isPathWord`, `capital` in `shell.ern`), which the compiler also owns. Whether the rule
    belongs to a function both use, in the front end or in Appendix E.
31. **An `IoError` has no text.** The shell writes `trouble(IoError)` for its messages, and
    every program that touches a file will write the same function; whether E.17 gives
    `IoError` a description, or E.0 rule 3 refuses it as a format policy.
32. **Where §4.4 draws an abstract type's boundary.** At the signature, not at the module:
    only the definitions its signature names may use the constructor, the module's private
    helpers and tests included. Gleam's `opaque` and ML's signatures hide the constructor
    only outside the declaring module. So a type with many internal helpers, the shell's
    editor state, pays heavily for its invariant (`0 <= at <= size(text)`), and a test at
    the foot of its file cannot match on it. Whether the boundary moves to the module.
33. **Three-segment member names.** A module named after its main type (`shell/editor.ern`
    holding `State`) makes a member `Shell.Editor.State.edit`, which leans on item 4.
34. **What a string search matches.** `String.contains`, `indexOf` and `startsWith` match
    whole graphemes, `split` and `endsWith` bytes, so `String.split("e\u{301}", "e")` finds
    an `e` that `contains` does not. E.5 says what a character is and not what a search
    matches; the sentence goes in E.5, and the code follows it.
35. **No ASCII digit test.** `Char.isDigit` is Unicode's Nd, so a format parser, the Markdown
    library's list numbers and `String.toInt` among them, writes its own `0`-to-`9` test.
    Whether `Char` gains one, by E.0.
36. **The built-in types' operators read as endless recursion.** `export fn Int.+(a, b) =
    a + b`, `List.<>`, and `Int.compare` written with `<`, which §3.10 defines through
    `compare`. The emitter uses the host's operators; §9.6 does not say so. One sentence
    there, that on the built-in types the operators are the runtime's.
37. **`Tcp.listen(0)` cannot say which port it got**, so a program that asks for a free port
    cannot tell a peer where to connect, and E.18's example uses a fixed port.
38. **`Ets`'s verbs** are `insert`, `lookup`, `delete`, `member`, where E.0 names the
    container verbs `put`, `get`, `remove`, `contains`; and `drop` means another thing in
    `List`. Whether a library follows E.0's names.
39. **A library cannot ask for equality on its type variable.** §3.9's equality constraint
    is inferred and never written, so `Ets.Table(k, v)` keyed by functions type-checks, and
    the runtime compares those keys by identity. Whether a declaration can state it.
40. **E.0 rule 3 and the `fromList`s.** The rule puts a conversion in the subject's module,
    yet `String.fromList`, `Map.fromList`, `Set.fromList` and `Either.fromOptional` live in
    the target's. The rule is reworded to say so, or the functions move.
41. **Naming inside modules.** `Set.intersect` is a verb beside the nouns `union` and
    `difference`; `String.contains` is a substring test where the container verb means
    membership, against rule 2's one verb for one operation.
42. **Where `Map` and `Set` draw the shim line.** `Set.map` is Ernest over `toList` and
    `fromList` but `Set.filter` a shim; `Map.map`, `filter`, `filterMap` and `foreach` are
    shims but `Map.any`, `all` and `find` Ernest. Only the operations on the representation
    need the host; item 13 kept the modules as shims without this line.
43. **Standard library modules cannot share a private helper**: `Fs` and `Tcp` each write
    the same `answered`. Whether a module may keep helpers for its siblings.
44. **No function gives the text `Io.debug` prints**, so a test can only report a value by
    a text of its own making (the Markdown library's tests report "N blocks"). Whether E.1
    gains `Io.show`, or a test's failure prints a value by the same printer.
45. **A Bool argument reads as nothing at the call.** `Markdown.render(doc, 80, false)`:
    the `false` says colour off only to someone who knows the signature. Named arguments
    are refused (the log's *Labeled Arguments*); whether a two-constructor type, `Plain |
    Styled`, is the library's idiom instead.
46. **Abstract types in the standard library.** `Random.Seed` could be written in Ernest,
    SplitMix64 over `Int`'s bit operations, as an abstract type: three shims go, a seed can
    cross nodes, and the sequence is the same on every runtime; against it, E.13's names
    change to `Random.Seed.next` (§4.4), and item 13 kept `Random` a shim. `Path` could be
    abstract with an invariant, no trailing separator, which the defects of `Path.parent`
    fell through; against it, E.14 made the constructor the way in and the prelude's
    `FsMsg` carries `Path`. `Markdown`'s `Block` and `Inline` stay transparent, being what a
    caller matches on; a Tcp socket stays an address, since `monitor` and `kill` are why it
    is one. Weighed with items 11 and 13.
47. **A socket's protocol is not for programs.** `send(sock, Close)` stands beside
    `Tcp.close`; E.0 rule 8 says a system reference is used only through its module, and
    E.18 does not say the same of `SockMsg`.
48. **A `let` of functions that call back to it is refused.** `let starts = [headingStart,
    ...]`, the Markdown library's table of block starts, is refused as an initializer
    that depends on itself, since `quoteStart` reaches `blocks`, which reads `starts`.
    Building the list calls none of them; the dependency is a call's, made later. §8.5
    orders initializers by what they reference, and a function value referenced is not a
    function called. The library writes `fn starts()`; whether §8.5 should count only what
    an initializer can call while it runs.

