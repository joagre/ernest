# Language feedback

What writing Ernest has felt against the principles: the shell, the standard library,
`libs/markdown` and the guide. This file holds each entry until a plan item decides it,
and MVP 2.65 decides them, theme by theme (the plan's MVP 2.65); a few wait for a later
MVP, which the entry names. An entry ends in a report change, a "Later" entry in the log,
or a line saying it was weighed and left alone, and then it leaves this file.

The entries are grouped by the question they share, and keep the numbers they were found
under, since the plan, the log and the code cite them. Eight have left: 1 (decided, report
§4.2, `Prelude.X`), 6 (done, E.5's `indexOf`), 10 (a defect of the shell, fixed), 12
(decided, report §9), 2 and 4 (weighed and kept, the log's *Constructor Names Stay Unique
in a Module* and *Names Stay Qualified, Without Import or Alias*), 32 and 33 (decided, report §4.4), and 49 (decided with them: the
editor's state and the region are abstract, and a history type was weighed and left, since
its one rule, the cap of a thousand inputs, a session does not reach, and it would make the
editor depend on `Shell.History`).

## 1. Names and namespaces

How a name reaches a declaration, and what that costs to write. A module is a namespace,
a type's members are a namespace inside it, a constructor's name is unique across the
module, and nothing is imported or aliased (§4.2). Each entry here is one cost of those
four rules. The entries are one decision, since changing one rule moves the others'
costs. The first, where an abstract type's boundary lies (items 32 and 33), was decided on
2026-09-25: it is its module (report §4.4), so a function no longer has to be a member to
see a representation.

46. **Abstract types in the standard library.** `Random.Seed` could be written in Ernest,
    SplitMix64 over `Int`'s bit operations, as an abstract type: three shims go, a seed can
    cross nodes, and the sequence is the same on every runtime; against it, item 13 kept
    `Random` a shim. Its functions keep their names under the module boundary. `Path` could be
    abstract with an invariant, no trailing separator, which the defects of `Path.parent`
    fell through; against it, E.14 made the constructor the way in and the prelude's
    `FsMsg` carries `Path`. `Markdown`'s `Block` and `Inline` stay transparent, being what a
    caller matches on; a Tcp socket stays an address, since `monitor` and `kill` are why it
    is one. Weighed with items 11 and 13.
43. **Standard library modules cannot share a private helper**: `Fs` and `Tcp` each write
    the same `answered`. Whether a module may keep helpers for its siblings.
17. **At the prompt, a type's members come in the same input as the type.** A type's
    members belong to the module that declares it, and each input is a module of its own
    (report §11.2), so `type Money = Money(Int)` and then `fn Money.compare(...)` in the
    next input is refused with "Money is not a type declared in this module". Consistent
    with the module rule, and surprising at a prompt, where a person adds to what is there.
    Whether the session may add members to a type it declared, or the message says to
    declare them together.

## 2. Expressions, patterns and types

How a part of a value is read, and the smaller rules of the grammar and the checker that
writing Ernest ran into. Field selection leads, since it is the one candidate for new
syntax and the shell has three witnesses for it; tuple projection and `match` as an
operand are the same question asked of other forms. The rest stand alone, and one contract
over several representations (52) is the largest of them.

51. **Field selection**, `s.upper`. The shell read one field through a whole pattern three
    times: the screen's record, then `Shell.Editor.State` twice, `fn text(editing) = match
    editing { State(text = text) -> text }` existing only to read one field. Gleam's rule
    is there to copy: a field is read with a dot when every constructor of the type has a
    field of that name and type. Against it is principle 2, a pattern already reading a
    field; for it, that Ernest took `..` for update from the family whose readers expect
    `.` for read. The plan's MVP 2.65 says which sections change if it is taken.
18. **No projection from a tuple.** `List.span` answers a pair, and twice the half wanted was
    reached for as `.0` or `.1`, which Ernest does not have; `let #(_, rest) = ...` is the
    one way, a line longer. Principle 2 is for it staying so; recorded because it was felt.
19. **A `match` is not an operand.** `indent(line) < 4 && match markerOf(s) { ... }` is a
    parse error that asks for parentheses, three times in the library. The rule keeps the
    grammar simple (principle 4), and the error's help says what to write; the cost is
    parentheses that read as noise around a `match` that already has braces.
3. **No constant patterns.** `let ctrlW = '\u{17}'` cannot appear in a `match` arm; an
   identifier there binds. So Readline's key table is bare literals with trailing comments
   (`'\u{17}' -> … // C-w`). A guard (`c == ctrlW`) is the alternative and reads worse. The
   leaning is to leave it: a real cost honestly paid for one-way pattern semantics.
45. **A Bool argument reads as nothing at the call.** `Markdown.render(doc, 80, false)`:
    the `false` says colour off only to someone who knows the signature. Named arguments
    are refused (the log's *Labeled Arguments*); whether a two-constructor type, `Plain |
    Styled`, is the library's idiom instead.
48. **A `let` of functions that call back to it is refused.** `let starts = [headingStart,
    ...]`, the Markdown library's table of block starts, is refused as an initializer
    that depends on itself, since `quoteStart` reaches `blocks`, which reads `starts`.
    Building the list calls none of them; the dependency is a call's, made later. §8.5
    orders initializers by what they reference, and a function value referenced is not a
    function called. The library writes `fn starts()`; whether §8.5 should count only what
    an initializer can call while it runs.
39. **A library cannot ask for equality on its type variable.** §3.9's equality constraint
    is inferred and never written, so `Ets.Table(k, v)` keyed by functions type-checks, and
    the runtime compares those keys by identity. Whether a declaration can state it.
36. **The built-in types' operators read as endless recursion.** `export fn Int.+(a, b) =
    a + b`, `List.<>`, and `Int.compare` written with `<`, which §3.10 defines through
    `compare`. The emitter uses the host's operators; §9.6 does not say so. One sentence
    there, that on the built-in types the operators are the runtime's.
52. **One contract, several representations.** An abstract type hides one representation;
    what it does not give is Java's interface or ML's signature, one API that several
    representations provide at once, chosen per use: Erlang's `sets` and `gb_sets` share
    their function names by convention, and a caller switches by changing the module name.
    Ernest has three answers without a new concept: E.0 rule 2's shared verbs, the same
    convention unchecked; a record of functions passed as a value, checked by the types and
    verbose, which is Gleam's and Elm's answer; and, for a stateful service, a mailbox type,
    which two processes of different representation both accept behind an `Address(M)`.
    The gap is a pure data structure written once against "a set" and run over either
    representation; closing it takes ML's signatures and functors or type classes, each a
    new concept against principles 5 and 3. Whether the record of functions suffices.
5. **`after` is reserved**, so a natural helper name for "the rest of a string from here"
   had to become `from`. Trivial, but the kind of thing that accumulates. Felt again in
   `libs/markdown`, where `after` was the name every scanning function wanted for what
   follows a match; it became `later` throughout.

## 3. Processes and the system

What a process is to the program that holds its address, and what the system modules
give. The registry (53) leads: address identity (24) is decided with it, since
unregistering needs it, and `:processes` as a function (26) turns on both. The rest are the system modules' contracts, one by one.
Items 14 and 25 are MVP 3.0's, and 16 is MVP 2.7's; they are here because they are the
same question.

53. **A registry, or the argument that none is needed.** §6.5 refuses one, the node
    protocol note asks for one (its open question 8), and a restarted service's new address
    has no other way to reach those who held the old one (MVP 2.66, the guide's §6.4). A
    table per node from name to address, or the argument that addresses handed on in
    messages suffice. Unregistering needs address equality, so item 24 is decided with it.
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
    the node, as a pid does. Decided with the registry (53). Either outcome changes the
    shell: with equality, §3.10 loses the address half of its exception, `Io.debug` prints
    the identity (E.1), `<address 3>`, and `:processes` and a fault line show the same one;
    without it, `Io.debug` keeps `<address>`, and `:processes` and a fault line number each
    process for the shell alone.
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
    addresses is only useful where addresses can be told apart.
28. **The fault log is the host's.** `:faults` reads a list the front end keeps, where the
    session already receives every fault as a `Died` message and could keep the last
    hundred itself in Ernest. §11.2 calls it "the runtime's record", so moving it is a
    report question, and one with item 26.
9. **A fault in a foreign function's *return* is silent to the caller's caller.** `fields_of`
   answered Erlang strings where the ABI wants binaries, so §8.4's boundary faulted the
   reader, correctly, and the shell became a zombie that painted but never read a key. The
   fault was right; nothing said it. The shell now monitors its reader and says so, but
   the general shape is worth a thought: a process that dies of a boundary fault takes its
   silence with it unless someone monitors it.
50. **A read that timed out loses what arrives after it.** `Tcp.read(sock, 100)` answers
    `Left(Timeout)`, and the bytes that arrive next go to the reply nobody waits for, which
    §6.6 discards; the next read waits for the bytes after them. Right for a reply, wrong
    for a stream. Found by the review of the runtime. Whether E.18's read keeps what came
    late for the next read, or a timed read is not offered on a stream at all.
47. **A socket's protocol is not for programs.** `send(sock, Close)` stands beside
    `Tcp.close`; E.0 rule 8 says a system reference is used only through its module, and
    E.18 does not say the same of `SockMsg`.
37. **`Tcp.listen(0)` cannot say which port it got**, so a program that asks for a free port
    cannot tell a peer where to connect, and E.18's example uses a fixed port.
27. **Nothing in Appendix E says whether keys can be read.** The shell asks the host
    (`ern_shell:is_terminal/0`), a `foreign fn` for a fact `Terminal` owns; `Terminal.size`
    answers only whether output is a terminal. Whether E.16 should answer the question.
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
be decided in batches. They fall into three groups: where the line between a shim and
Ernest runs (11, 13, 42), what a function is named and where it lives (40, 41, 38), and
functions the library lacks or has in a form that misleads (the rest).

11. **`path.ern`'s shims over string surgery.** A shim exists only where the runtime owns
    the representation, and the library's counts bear that out, but `path.ern` is six
    shims behind eight exports, over `filename:`. E.14 opens with "a `Path` is in the
    runtime's syntax", so what a separator and a root are is the host's, a real host
    dependency: `/` here, `\` with drive letters elsewhere. What it does not justify is the
    surgery built on those facts. The rewrite to aim for keeps **two** shims, the host's
    separator and whether a path is absolute, and writes `join`, `split`, `name`,
    `extension` and `withExtension` in Ernest over `String.split`, `String.lastIndexOf` and
    `String.slice`; `parent` already is, since 2026-09-25. E.14's contracts have edge cases,
    a trailing separator, an absolute second operand, an empty extension, that want tests
    written with care. Performance is not a reason for a shim; if a measurement ever
    demands one, it comes back as a decision with the numbers beside it.
13. **The rest of the shims, audited 2026-09-23.** Against the one rule, a shim only where
    Ernest cannot express the work given the modules beneath it.

    **Should go:** `String.startsWith`, `endsWith`, `contains`, `parts`, `copy` and
    `replace`, all of which are `indexOf`, `slice` and `size` away from being Ernest, those
    three staying shims because they count extended grapheme clusters and nothing beneath
    `String` can. `Bytes.at`, `toList` and `pack` are a weaker case of the same: the bit
    syntax of §5.11 is beneath them, so they can be written, and only `size` and `part`
    need the runtime.

    **Staying, and why:** the `Map` and `Set` operations (the representation is Erlang's,
    which is its own decision, but see item 42); `Char`'s predicates and case, `toLower`,
    `toUpper`, `trim` (Unicode tables); `Float`'s mathematics and `Int`'s bit operations
    (no primitives beneath them); every conversion `toString`, `inBase`, `toFloat`,
    `toUtf`, `fromUtf`, `toList`, `fromList` (rule 1 names them); `Random` (the generator's
    state is the runtime's, but see item 46); `Foreign` (the boundary itself); `Io.debug`
    (the runtime's printer and the compiler's descriptor).
42. **Where `Map` and `Set` draw the shim line.** `Set.map` is Ernest over `toList` and
    `fromList` but `Set.filter` a shim; `Map.map`, `filter`, `filterMap` and `foreach` are
    shims but `Map.any`, `all` and `find` Ernest. Only the operations on the representation
    need the host; item 13 kept the modules as shims without this line.
40. **E.0 rule 3 and the `fromList`s.** The rule puts a conversion in the subject's module,
    yet `String.fromList`, `Map.fromList`, `Set.fromList` and `Either.fromOptional` live in
    the target's. The rule is reworded to say so, or the functions move.
41. **Naming inside modules.** `Set.intersect` is a verb beside the nouns `union` and
    `difference`; `String.contains` is a substring test where the container verb means
    membership, against rule 2's one verb for one operation.
38. **`Ets`'s verbs** are `insert`, `lookup`, `delete`, `member`, where E.0 names the
    container verbs `put`, `get`, `remove`, `contains`; and `drop` means another thing in
    `List`. Whether a library follows E.0's names.
34. **What a string search matches.** `String.contains`, `indexOf` and `startsWith` match
    whole graphemes, `split` and `endsWith` bytes, so `String.split("e\u{301}", "e")` finds
    an `e` that `contains` does not. E.5 says what a character is and not what a search
    matches; the sentence goes in E.5, and the code follows it.
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
29. **The editor's words are split at spaces only**, so `M-b` over `List.map(xs` jumps it
    whole; Readline's words are alphanumeric runs. Which the shell should follow.
