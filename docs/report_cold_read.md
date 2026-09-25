# The report read cold

On 2026-09-25 a reader who had never seen Ernest read `ernest_report.md` alone, as its
implementer, and opened nothing else in the repository (the plan's MVP 2.65, step 2). This
file holds what they found until MVP 2.65 decides each: a report change, a line saying it
was weighed and is right as written, or a plain fix where it asks no decision. A finding
leaves the file when it is decided. Findings are numbered by rank and place, 1.1 to 3.30,
and keep their numbers. Line numbers are the report's on that day.

The ranks: **1**, two honest implementations would give a program different meanings, or
one would accept what the other refuses; **2**, an implementer has to invent a rule; **3**,
terminology, cross-references, wording, and examples. The reader's own guesses are kept,
marked as theirs; they are not decisions. The reader thought 1.9, 2.30 and 3.14 might be
settled by a convention the report does not state.

Where a finding belongs to a theme of the feedback list, it is decided with that theme:
2.7, 2.8, 2.9, 2.12 and 3.9 with names and namespaces; 1.1, 1.3, 1.9, 1.10, 1.11,
1.12, 2.1 to 2.6, 2.31 and 2.32 with expressions, patterns and types; 1.8, 1.16, 2.18,
2.19, 2.20, 2.28, 2.29 and 3.29 with processes and the system; 1.7, 1.14, 1.15, 2.24 to
2.27 and 3.10, 3.11 with the standard library; 2.33, 3.12 and 3.30 with the toolchain. The
rest are the report's own, decided in a batch of their own.

Already decided: 3.1, a cross-reference to §11.1 written the same day, removed; and 2.10,
2.11 and 3.13 with an abstract type's boundary (report §4.4, 2026-09-25): an abstract type's
fields may name a private type, and there is no signature to leave a definition out of.

## Rank 1

1.1. **Whether a pure function stands where `with M` is expected.** §3.9 (L209, L215),
§6.1 (L462), §6.2 (L484). "At a call site an effect variable binds to a mailbox type or to
pure"; "Pure is the absence of `with`; it is not a type"; "Two callbacks with different
concrete effects are a type error". Nothing says whether pure is compatible with an effect
already bound to M: `fn both(f, g) = { f(1); g(2) }` called with one pure and one
`send`ing callback; a pure function stored in `Upgrade(next : (Int) -> Unit with
CounterMsg)`; `spawn(Local, fn() = Unit)`. §11.5 (L889) accepts `fn k() -> Int with m = 5`,
which suggests pure fits a variable, not a concrete M. Reading A, subeffecting; reading B,
plain unification, each case a type error. The reader's guess: A.

1.2. **The evaluation order of a callee and of a pipe.** §5.1 (L370): "Strict, left to
right, arguments before the call." Whether `x` in `x |> f(a)` is evaluated before `f` and
`a` or after; whether `g(1)` is evaluated before `h()` in `g(1)(h())`. Visible when either
part sends or receives. The reader's guess: source order.

1.3. **What pins a block binding's type variable.** §4.6 (L309): "a later use of the
binding in the block pins it … A variable resolved in none of these ways is a type error at
the binding." Any later use, or only one that makes it concrete? Under the second,
`{ let xs = []; List.size(xs) }` is an error, and so is `let a = spawn(Local, fn() =
ping(p, 3)); monitor(a, W)` with `ping` `with m`. The reader's guess: the second, with the
`monitor` consequence unintended.

1.4. **Bitstring defaults for byte order and sign.** §5.11 (L428–440) says only that a bare
segment is "`int` of size 8". The byte order of `<<x:size(16)>>`, whether `<<-1>>` faults
with "segment overflow" or is 0xFF, and whether the pattern `<<x>>` binds 255 or -1 are
unstated. The reader's guess: Erlang's, big-endian and unsigned.

1.5. **A `bytes` segment without a size, in construction.** L438: "A `bytes` segment without
a size takes the rest of the value and is the last segment." Whether that holds when
building, and so whether `<<a:bytes, b:bytes>>` compiles. The reader's guess: patterns
only.

1.6. **`C(..p, f = v)` when the type has several constructors.** §5.6 (L394). `p` may have
been built by another constructor of the type: a type error unless the type has one
constructor, a fault §7.4 does not list, or a flow-sensitive check. No guess.

1.7. **String semantics.** The order of `String.compare` and `Char.compare` (§3.10 L221,
§9.6 L796, E.5): code point, UTF-8 byte, or grapheme. Whether `contains`, `startsWith`,
`endsWith`, `replace`, `split` and `indexOf` match code points or grapheme clusters, and
what index a match inside a cluster has (E.5 L1269; feedback item 34). What whitespace
`trim` strips (L1284), §2.1's four or Unicode's White_Space. Full or simple case mapping
for `toLower` and `toUpper`. The reader's guesses: code points, code points, White_Space,
full mapping.

1.8. **Whether `send(Sys.stdout, "x")` is legal.** §8.2 (L622) "A program uses each through
the standard library"; §9 (L693) "a program does not send to a system reference (E.0 rule
8)"; E.0 rule 8, a rule on the library's shape, "never by `send`"; E.1 (L1161) "A string
goes to any other `Address(String)` by `send`". A compile error or a convention? The
reader's guess: a convention.

1.9. **Which operand resolves an operator, and where its type may come from.** §4.8 (L321):
"`+` is `Int.+` when `a : Int` … An operand whose type comes from no annotation, literal,
pattern, or call in the same definition is a type error." The left operand only, so that
`fn f(a, b : Int) = a + b` fails? `[]`, `<<>>`, a tuple and a constructor are not a
`literal` (§2.6 L112), so `fn g(xs) = xs <> []` is undecided. What "same definition" means
in a mutually recursive group. §3.10 defines `a < b` by `T.compare` but not that `<` needs a
determined operand type. The reader's guess: resolved after the definition is inferred,
from either operand, `<` alike.

1.10. **A pure result annotation on an effect-polymorphic function.** §4.5 (L299): "A pure
annotation on a function that calls process code is a type error." Does `fn apply(f, x) ->
Int = f(x)` force `f`'s effect to pure, or is it an error? The reader's guess: it forces
pure.

1.11. **Polymorphic recursion under a full signature.** §3.9 (L207): "polymorphic recursion
is not" allowed. Refused even with the whole signature written, which Haskell and OCaml
accept? The literal reading says yes.

1.12. **Whether a `receive` with only `after` is pure.** §6.1 (L462): "a function none of
whose calls determines an effect is pure." A `receive` is no call, and an after-only one
fixes no mailbox, so `fn sleep(ms) = receive { after ms -> Unit }` would be pure, callable
from pure code and inside `remote`. §6.8 implies process code. The reader's guess:
process-only.

1.13. **An initialization cycle: a mention or a call?** §8.5 (L669): "A binding that
references another, directly or through the functions it calls … A cycle is a compile-time
error." `let handlers = [f]; fn f() = List.size(handlers)` is a cycle if a mention counts
and none if only a call does (feedback item 48). Whether a top-level `let` may name itself
inside a lambda, `let a = fn() = a`; §4.6's "does not see its own name" is a block's.

1.14. **Where `Int.toFloat` overflows.** §3.1 (L162): it faults "on a magnitude beyond the
largest finite `Float`". An integer just above it rounds down to it under IEEE: a fault for
any such value, or only where rounding overflows?

1.15. **What `String.toFloat` accepts.** E.5 (L1293): "the float literal form of §2.5",
which allows `_` grouping, so whether `"3.141_592"` parses; whether `"1.0e400"` is `None` or
a fault.

1.16. **When a bad foreign return faults, and which process dies.** §7.4 (L610): "faults the
receiving Ernest process on first observation"; §4.7 (L317): "a value of another shape … is
a fault". "Observation" is undefined: a match, a primitive, or passing the value on? Whether
a bad `List(Int)` handed to another process kills the caller or its later user, and how deep
the check at the return goes.

## Rank 2

2.1. **A gap in the reply rule.** §3.9 (L217), §6.6 (L540–542). The not-reply-carrying
restriction falls only on parameters duplicated or discarded, and is lifted for a
container's element visible in a parameter or result type; so `Stack.push(r, s)` of §4.4
with `r : Reply(Int)` passes, though its body puts `r` in a `List`, which L542 forbids, and
nothing checks inside a generic body. Likewise whether `Box(Reply(Int))` is legal for
`type Box(a) = Box(List(a))`.

2.2. **"Duplicates or discards" is undefined** (L217): a use in one branch only, a use in a
guard, a parameter passed on.

2.3. **A reply captured by a local `fn`.** L522 covers lambdas; a local `fn` may be
recursive and called many times.

2.4. **Returning a reply: the declared or the inferred result type?** L521 says "whose
result type is reply-carrying", L542 "whose *declared* result type". Must it be annotated?

2.5. **A lambda against "by type".** L540: "It is by type, not by constructor", yet a lambda
is reply-carrying by what it captures and no function type is reply-carrying. How such a
value is typed across a `let` is left open.

2.6. **Effect variables as type parameters.** A type argument is a value position (L211),
so in `type H(e) = H(f : (Int) -> Unit with e)` the `e` of `H(e)` can never be pure, and no
pure callback could be stored, unless 1.1's subeffecting holds.

2.7. **How the standard library declares a built-in type's operators.** §4.8 (L321):
"`Float.+` in `float.ern`". But `DeclName = ident | typename "." (ident | userop)` (L912),
and §4.6 (L311) wants the prefix to be a type of the same module, so `fn Float.+` in
`float.ern` would export `Float.Float.+`, and a bare `fn +` does not parse.

2.8. **"The type's namespace" for `compare`** (§3.10 L221): for a user type, the member
`fn Distance.compare`? For a prelude-declared type, `Optional` or `Path`, which namespace?
What signature and purity a user `compare` must have, and what a `with m` or wrongly typed
one does. Whether "both operands have the same type" (§4.8) makes `fn Vec.*(Vec, Float)` a
declaration error.

2.9. **Duplicate private top-level names.** §4.2 (L259) forbids only two exported
declarations of one qualified name: nothing on two private `fn f`, a `fn f` beside a
`let f`, or a local `fn` and a `let` of one name in a block.

2.12. **Taken namespaces and the prelude's types.** §4.2 (L261) forbids coinciding with "a
namespace of the prelude". Whether `Event`, `Size`, `Entry`, `Test`, `Down`, `Address` and
`Sys` count, and so whether `event.ern`, `test.ern`, `address.ern` or `sys.ern` at the root
is an error.

2.13. **A redundant or unreachable clause**: an error, a warning, or nothing? The report
never mentions warnings.

2.14. **Coverage of a nested bitstring.** L452 speaks of "a `match` whose patterns are
bitstrings"; what of `Some(<<x>>) | None`?

2.15. **Bitstring cases no rule covers** (§5.11, §7.4 L606): a `bytes` value longer or
shorter than its `size(N)`; a negative size in construction; a float narrowed to 16 or 32
bits beyond its range, "segment overflow" or rounding; a pattern that leaves a rest not
aligned to a byte; a `float` pattern over the bytes of a NaN or an infinity, a failed match
or a fault (§3.1 says only that there is no NaN).

2.16. **Variables in a pattern's `size(Expr)`.** L440: "a variable bound by an earlier
segment or by the enclosing function". A block `let`'s? A captured one?

2.17. **What a receive guard may hold.** §6.3 (L490): "a comparison of the pattern's
variables, the enclosing function's variables, literals, and nullary constructors".
`when flag`? `when !flag`? `-1` is `Int.negate(1)`, a call, so `when x > -1`? §3.10 defines
`<` as a call to `T.compare`, yet the guard "calls nothing".

2.18. **A fault in a callback other than `via`'s.** `via`'s rule is explicit (L500); for
`monitor`'s wrap and the callbacks of `Clock.alarm` and `Terminal.subscribe`, where the
callback runs and who dies if it faults.

2.19. **How a program ends otherwise.** §8.6 (L673) covers `main` returning or faulting,
§11.2 (L851) the statuses of those two. Unstated: whether the program ends if `main` is
killed; the status and what is printed for a faulting initializer (§8.5); the status after
an external signal.

2.20. **Deadlock and a blocked call.** §8.6 (L675) counts processes that "wait in
`receive` without `after`"; a process in `Address.callForever` is not covered.

2.21. **Which top-level `let`s run before `main`**, §8.5's "every top-level `let`": of every
loaded module, or of those the entry module reaches? It matters where an unused module's
initializer faults.

2.22. **A pure entry point.** §8.1 asks for "a `fn () -> Unit with m`"; is `fn main() ->
Unit` accepted?

2.23. **A float literal out of range.** Is `1.0e400` a compile error, and does `1.0e-400`
become `0.0`?

2.24. **Standard input's details** (§8.2 L626, "without its line feed"): the CR of a CR LF;
invalid UTF-8; a last line with no line feed.

2.25. **`Io.debug`** (E.1 L1169): which stream, whether it adds a newline, and how a
`String` is escaped.

2.26. **`Float.toString`'s form** (E.9 L1352, "shortest decimal that reads back"): when the
exponent form is used, and whether it always reads back by `String.toFloat`'s form.

2.27. **Library edge cases:** `Int.shiftLeft` and `shiftRight` with a negative count;
`Int.pow(0, 0)`; `Random.next` with a negative bound; `List.get` with a negative index;
`String.split("", ",")` and `String.lines("")`.

2.28. **Who faults when a foreign value crosses nodes** (§3.8 L203): the peer or the caller
for `remote`'s result, and which process for `answer`.

2.29. **`Down`'s `function` field** (§6.9 L563, "the qualified name of the function that
called `spawn`") when `spawn` is called from a lambda or a local `fn`.

2.30. **Local variables in name lookup.** §4.2 (L272) begins "in the module's
declarations" and leaves them out; whether a private declaration may be named by its
qualified name in its own module.

2.31. **A type variable named only in a block `let`'s annotation**: rigid, flexible, or
scoped? §3.9 (L207) covers a function's signature and a lambda.

2.32. **A foreign type's equality.** §3.8 (L201) "Its equality is §3.10's", §3.10 (L221)
"they compare identity (§3.8)", circular; "identity" is undefined, and whether `Foreign`
counts as a foreign type for `==`.

2.33. **The shell's commands** (§11.2): `:browse`, `:forget`, `:type`, `:doc` and `:set`,
with its depth, length and output, are named and not defined; no help command is named, and
nothing says how a session ends.

## Rank 3

3.1. Fixed on 2026-09-25: §11.2 cited §11.1 for how `ern` loads.

3.2. **An unsupported citation.** Appendix D (L1130) cites "(§10, E.0 rule 1)" for the
standard library holding no shared state; §10 says nothing of the standard library.

3.3. **An example that does not compile.** §3.5 (L186) uses `Mtime`, declared nowhere.

3.4. **Appendix A against §2.3.** L960: "a lowercase final is a function or operator", but
§2.3 (L53) makes an operator final a `userop`, which is not lowercase.

3.5. **The grammar against the prose on `_`.** §2.3 (L45) `ident = ( lower | "_" ) {…}`
admits `_` alone, which the prose (L51) excludes, so Appendix A's `AtomPat = "_" | ident`
is ambiguous from the grammar alone.

3.6. **"The one place" is not.** §3.9 (L211): "Operator resolution … is the one place
inference asks for an annotation"; §4.6 asks for one for an unresolved binding, and so do
the shell's refusals and `<-` over a sum type still open.

3.7. **An incomplete list.** §3.1 (L162) omits `Float.truncate` (E.9) from the conversions.

3.8. **The prelude's boundary.** §9 (L691): "The prelude is what this report names";
Appendix E is part of the report.

3.9. **No module for `Address.call`.** §9 says an operation in a type's namespace "is
provided by that type's standard library module", and Appendix E has no `address.ern`.

3.10. **E.0 rule 5 against the library.** Rule 5 (L1151): "Every function that takes a
function is effect-polymorphic"; `Clock.alarm` and `Terminal.subscribe` take pure
callbacks.

3.11. **E.0 rule 8's exceptions** leave out `Terminal.size` and `Terminal.subscribe`, which
wait for a reply and take no milliseconds.

3.12. **The configuration directory.** `--config-dir dir` names the `.ernest` directory
itself (default `./.ernest`, L873), but `--create-config-dir dir` creates `dir/.ernest`
(L877).

3.14. **"Appears … as well".** §4.2 (L259) "The qualified name appears at use sites, in the
module itself as well" reads as mandatory, against unqualified lookup.

3.15. **"Ended" against "faults".** §6.10 (L582) says a process is "ended (§7.4)"; §7.4 and
§11.2 say it faults with "its code was unloaded".

3.16. **The glossary is not complete**, though it claims every technical term:
"generalization" leaves out the top-level `let`; missing are effect and value position,
type member, not-reply-carrying, inferred restriction, entry point and entry process, source
root, and taken namespace.

3.17. **§2.2's comments.** Whether `////` is a doc comment; whether a `*/` inside a string
inside a block comment ends it; whether an end of line is LF only.

3.18. **An unexplained case rule.** "Type names that differ only in case are permitted"
(L270): its purpose and scope.

3.19. **Bitstring specifier names**, "ordinary identifiers outside a bitstring" (L438):
whether a segment's value may be a variable named `size`.

3.20. **`<-` patterns.** §5.5 does not say whether `let p <- e`'s pattern must be
irrefutable.

3.21. **The lambda's delimiters.** §5.3 (L378) leaves out `{`, `->`, `:` and `when`; the
grammar decides them anyway.

3.22. **Two unclear sentences of the shell's**: "A `let` at the prompt is a block `let`,
where §4.6 is a module's" (L857), and ":set … 0 being neither" (L859).

3.23. **Network formats.** The hash, the normal form, node authentication and the wire
format are left open (§8.3, §8.7, §10), and the report does not say they are the
implementation's.

3.24. **The largest `after t`**: no limit is given, and the host caps it.

3.25. **A foreign function's name**: what happens when its arity differs from the
parameters, or its module or function is missing at the call; whether that is a raise.

3.26. **`Never` as a result type**: usable as a result or in a statement, or only `todo`'s?

3.27. **A `Map` over a type without equality** "is rejected at its first operation" (L223);
is an annotation alone, `Map((Int) -> Int, Int)`, legal?

3.28. **When a missing `Sys.*` name is reported**: a "name-resolution error" (§8.2), at
compile time or at load?

3.29. **`kill`'s edge cases**: a dead process, a `Sys.*` address; and a fault in `via`'s `f`
kills the target (L500), which may be a system process.

3.30. **`ern --test`'s order**: tests concurrently or in sequence, and the output's order.
