# Findings of the first review

The findings of the twelve readers of 2026-09-28 still open, one line each, by area; each is planned in MVP 2.98. The readers: the report's principles (P), the cold reader (K), the register (G), the guide (U), the newcomer (N), the documents (D), the code (C), the Ernest code (E), the tools (T), the diagnostics (X), security (S), the shell's README (H). The 143 lines done by 2026-09-29, each with what was done, are at commit b7d34c0. Each reader's whole list, as it was handed in, stands below the lines, since a line is too short to fix from ([`full_review.md`](full_review.md)); the lists keep the paths and line numbers of the tree they read. This file goes when every line is done or in the plan.

## The report

- 2.98 — `Int.div` and `Int.mod` are prelude variants of `/` and `%`, and `mod` is a remainder (P17, K-B6)
- 2.98 — `Address.callForever` beside `Address.call` is a second way (P18)
- 2.98 — every prelude type takes a module namespace, `Test` and `Path` among them (P19)
- 2.98 — an unresolved block variable is an error though nothing depends on it (P20)
- 2.98 — `C` and `C()` both match any value of a named constructor; `Some()` and `None()` are grammatical (P21, K19)
- 2.98 — `unit(N)` is a second way to scale a size (P22)
- 2.98 — rules that buy little, to weigh: `true`/`false` reserved, prefix `!`, `abstract` with `export` only, the 255-character limit, `Path` in the prelude (P-C)

## The guide and the README

- 2.98 — `Tcp` is never taught, though §9.5 shows a chat server's unit (N1)
- 2.98 — §4.4 does not cover a broadcast to a consumer that stalls (N4)
- 2.98 — the language: sockets pull-only, mandatory timeouts, slow standard library calls, no bounded mailbox (N-L1..L6)

## The toolchain

- 2.98 — `--build-root` does not find modules outside the source root, against §11.1 (T2)
- 2.98 — a stale dependent runs against a changed interface and faults (T3)
- 2.98 — a single-file build takes its namespace from the working directory and rewrites a module as another (T4)
- 2.98 — a repeated option takes the first; `--name=value` undocumented; empty values accepted (T8)
- 2.98 — the checker reports one error per function; a directory build stops at the first failing module (T10)
- 2.98 — `:load` of a dependent cannot use a module already loaded (T12)
- 2.98 — a faulting top-level binding: three behaviours and the wrong name (T14)
- 2.98 — the shell cannot show the prelude (T19)
- 2.98 — a large paste is scanned again as it grows, a cost of `ern_tty`'s (shell_design.md's rewrite)

## The runtime

- 2.98 — sockets, listeners and programs are missing from `Process.live`, `info` and faults (C10)
- 2.98 — hardening: unchecked casts through `Foreign`, `Erl.atom` on received text, `stty` from `PATH`, the host's flags from the environment, a relative `HOME`, unbounded reads, the key in the working tree, a dangling `--config-dir` (S-H)
- 2.98 — the history decoder is quadratic (S11)

## The standard library, the libraries, the examples

- 2.98 — `Bytes` has no search or split (N-L), and gains the functions of Erlang's `binary` that `String` has, named as `String`'s are: `contains`, `indexOf`, `startsWith` and `endsWith` from `match`, `split`, `replace`, `join`, `repeat` from `copy/2`, and `toHex` and `fromHex` from `encode_hex` and `decode_hex`. Not taken: `at`, `part`, `bin_to_list` and `list_to_bin`, which are `get`, `slice`, `toList` and `fromList`; `first` and `last`, which `get` is; `encode_unsigned` and `decode_unsigned`, which are bitstrings' (§5.11); `longest_common_prefix` and `longest_common_suffix`, words `String` has not; and `compile_pattern`, `copy/1` and `referenced_byte_size`, which are the host's representation
- 2.98 — the language: a list of functions as a binding, `kill` and `monitor` on `Process`, "no limit" unnamed, `Io.debug` a shim, every program's `errorText`, no word of a restart's end, `Tcp.close` and `closeListener`, `Bytes.slice` a shim (E-C1..C8)

## The documents

- 2.98 — the tightened documents were checked by their writers against the code and by `make test-docs`, and read back whole only in part: the plan's MVP 2.95, 3.0 and 3.1, `style.md`, `install.md` and the shell note's opening. `architecture.md`, `shell_design.md`, the two distribution notes, `memory.md`, `development.md` and `emacs_mode.md` are read back against the code, and D5..D31 checked one by one (the documents' rewrite)
- 2.98 — `Clock.monotonic` and `Udp` stand in the plan's "Not in any MVP" as waiting for "a later MVP", with no milestone and no verdict (CLAUDE.md, *No decision is left pending*): each is judged on E.0 and placed (the documents' rewrite)

## The readers' lists

The lists of the readers whose findings are still open, each as its reader handed it in on 2026-09-28. A finding's number is its place in its reader's list: P10 is the principles reader's tenth.

### P, the principles

Reader report: whole `ernest_report.md` against §0's five principles. I edited nothing in the repository. Every program marked "run" was compiled and run with `bin/ern` (0.1.0). They are under `/tmp/claude-1001/-home-jocke-projects-ernest/5878ddea-cb10-40c7-a354-3f491e030515/scratchpad/readers/c4/t1`…`t14`. The programs below are shortened: a `main` that prints the result is left out.

#### A. Defects (most serious first)

**1. §6.6 / §3.9: a Reply can be dropped through any foreign-implemented polymorphic function (P3, P1).**
- **Quote:** §6.6 "A `Reply` is answered exactly once". §3.9 says not-reply-carrying falls on a variable "when the body … would break §6.6".
- **What is wrong:** a `foreign fn` has no body, so it never gets the restriction.
- **Program (run):**
  ```
  type Msg = Get(reply : Reply(Int))
  fn server() -> Unit with Msg =
      receive { Get(reply = r) -> { let _ = Foreign.from(r); server() } }
  ```
  It is accepted, and the caller's `Address.call` prints "no answer". `let _ = Io.show(r)` is also accepted.
- **Prediction:** a reader expects it refused, as `let _ = #(r, 1)` is ("`_` would discard a reply-carrying value").
- **Fix:** the type variables of a `foreign fn`'s parameters are not-reply-carrying (`a!`) unless the declaration says otherwise.

**2. E.1: `Io.show` and `Io.debug` depend on the static type at the call (P1, P3, P5).**
- **Quote:** "writes a value by the argument's type at the call … Where the argument's type is a type variable … a `Char` as its `Int`".
- **Program (run):**
  ```
  fn wrap(x) = Io.show(x)
  Io.show('a')   // 'a'
  wrap('a')      // 97
  ```
  `Some('a')` against `Some(97)` behaves the same way.
- **Prediction:** a reader expects `wrap` to be `Io.show`. In Hindley-Milner a function of type `(a) -> String` cannot look at `a`.
- **Why this matters:**
  - The type does not show the dependence.
  - It is neither Ernest nor a shim (E.0), so it is a primitive outside §9's count.
  - It makes §3.9's "This is the one exception to principle 3" false.
- **Fix:** either print by runtime representation everywhere, or make it a prelude primitive with a stated elaboration rule and list it as an exception.

**3. §3.10 / §6.5: functions and addresses can be compared (P2, contradiction).**
- **Quote:** "`==` … except those containing functions or addresses, on which they are a type error". §6.5: "Addresses have no equality".
- **Program (run):**
  - `Foreign.from(inc) == Foreign.from(dec)` gives `false`, and `Foreign.from(inc) == Foreign.from(inc)` gives `true`.
  - `Foreign.from(self()) == Foreign.from(self())` gives `true`.
  - `Io.show(a) == Io.show(b)` gives `true`, because an address prints its process number.
- **What is wrong:** besides contradicting the two sections, this is a second way to compare processes next to `Process.fromAddress`.
- **Fix:** give `Foreign.from` the equality constraint, `(a=) -> Foreign`, which already excludes functions and addresses, and so replies (this also closes #1 for it). Have `Io.show` print an address without its number.

**4. §8.5 and §8.7: top-level initializers run without their names appearing, and eagerly here but lazily on a peer (P3, P1).**
- **Quote:** "every top-level `let` of the entry point's module and of every module it depends on". §8.7: "evaluated on the peer on first use".
- **Program (run):**
  ```
  // logs.ern
  export let banner : Unit = Io.println("banner initializer ran")
  export let service : Address(Never) = spawn(Local, logger)
  export fn format(s : String) -> String = "[" <> s <> "]"
  // main.ern
  export fn main() -> Unit with m = Io.println(Logs.format("hello"))
  ```
  It prints the banner, starts the logger, then prints `[hello]`.
- **Prediction:** a reader expects only `[hello]`. §0 says "A top-level binding is visible when its name appears at the use site", and neither name appears.
- **The peer half:** on a peer the same binding runs at first use, and a fault there goes to the first user instead of ending the program. That is two evaluation strategies for one construct.
- **Fix:** evaluate only the lets the entry point reaches by §8.5's dependency relation, before `main`. On a peer, evaluate those the shipped function reaches, before it runs.

**5. §4.2: unqualified lookup names a type-member step that the compiler does not implement, and that would shadow badly if it did (P1, P3).**
- **Quote:** "then in the module's declarations … then in the type-member namespace of the enclosing declaration".
- **Program (run):**
  ```
  type Box = Box(Int)
  let Box.empty : Box = Box(0)
  fn Box.fresh() -> Box = empty
  ```
  `ern build` answers "unknown name empty".
- **The shadowing half:** with a module-level `fn describe` next to `fn Box.describe`, inside `Box.show` the call `describe(b)` gives "module". So by the rule as written, adding a module function silently changes a member's meaning.
- **Fix:** drop the type-member step from §4.2 and from §11.2's *Scope*. A member is written `T.f` everywhere, as the compiler already requires.

**6. §6.6 / §3.9: `Optional` and `Either` refuse reply-carrying elements, while user sum types allow them (P1; each rule exists for the other).**
- **Quote:** "in particular as an element of `List`, `Map`, `Set`, `Optional`, or `Either`". §3.9: "It does not fall on a variable that is also an element of … `Optional`, or `Either`".
- **Program (run):**
  ```
  type Maybe(a) = Nothing | Just(a)
  fn user(m : Msg) -> Maybe(Reply(Int)) = match m { Get(reply = r) -> Just(r) }       // accepted
  fn pre(m : Msg) -> Optional(Reply(Int)) = match m { Get(reply = r) -> Some(r) }     // refused
  ```
- **Prediction:** a reader expects both accepted. §9.3 declares `Optional` like any sum type, and §6.6 says `Box(Reply(Int))` is reply-carrying.
- **Consequence:** a parser cannot return `Either(Error, Request)` for a reply-carrying `Request`.
- **Fix:** treat both as declared types in §6.6 and drop them from §3.9's exemption. `Optional.withDefault` then prints with `a!`.

**7. §6.3: a `receive` guard is a second, smaller expression language (P2, P1).**
- **Quote:** "the variables the enclosing function binds, which exclude top-level bindings" and "A guard expression calls nothing".
- **Program (run):**
  ```
  let limit = 10
  receive { Tick(n) when n > limit -> Unit | Tick(_) -> loop() }
  ```
  It is refused ("limit is bound at top level…"). `match n { k when k > limit -> … }` compiles. `when valid(n)` and `when n + 1 > 5` are also refused, and `<` on a user type with `compare` is not allowed.
- **Why this matters:** a top-level binding is a value evaluated before `main` and cannot fault when read, so its exclusion is the host's guard rule showing through.
- **Fix:** admit top-level bindings as guard operands, and state in §6.3 why the remaining restriction exists.

**8. §3.9: one annotation text, two meanings (P1, P2).**
- **Quote:** "A variable named only in a lambda's annotation is the lambda's own and is not rigid."
- **Program (run):**
  - `fn g(x : a) -> a = x + 1` is refused ("type variable a … is used as Int").
  - `{ let g = fn(x : a) -> a = x + 1; g(2) }` is accepted and gives 3.
- **Prediction:** a reader reads `(x : a) -> a` as "for every a" in both places.
- **Fix:** a type variable named only in a lambda's or a block `let`'s annotation is an error, since the binding is not generalized.

**9. §3.9 / §4.6 / §4.8: several ways to name a function, each typed differently (P2).**
- **Program (run):**
  - `{ let id = fn(x) = x; #(id(1), id("a")) }` is refused.
  - `{ fn id(x) = x; #(id(1), id("a")) }` is accepted.
  - A top-level `let id = fn(x) = x` is polymorphic, which makes it a second `fn id`.
- **Sign of the overlap:** §4.8's "`let T.op` is an error" exists only to close one of these doubles.
- **Fix:** generalize a block `let` whose initializer is a lambda, as the top-level one is (the syntactic value restriction). The forms then differ only in recursion.

**10. §6.9 ¶3 / E.0 rule 1: the supervisor's restart-on-request is a language mechanism with no prelude entry (P5, P3, P2).**
- **Quote:** "It runs on until it next waits, in a `receive` or for a call's answer, and there runs `f()` again". It is reachable only through a Supervisor shim.
- **What is wrong:**
  - It is not counted in §9.
  - Every `receive` and every `Address.call` in a child is an unwritten exit point.
  - `Supervisor.child` "runs `f` again in place, as `restarting` does", which is a second restart-on-fault mechanism.
- **Program (not run):**
  ```
  fn w() -> Unit with M = { let x = step1(); receive { Go -> step2(x) } }
  ```
  Under `OneForAll`, a sibling's fault restarts `w` at its `receive`.
- **Prediction:** a reader expects a restart only on `w`'s own fault.
- **Fix:** name the request in §9.5 with its type, and define the child's own fault restart as `restarting`.

**11. §6.5: a `via` function runs in the sender, but its fault kills the target (P1, P3).**
- **Quote:** "by the send, in the sender … A fault in `f` is the target's".
- **Program (run):**
  ```
  fn boom(x : Int) -> Msg = Num(100 / x)
  send(via(boom, t), 0)
  ```
  It prints "sender goes on", and `t` dies with `Fault("division by zero")`.
- **Prediction:** a reader expects the process that evaluated `100 / x` to fault. §3.8 puts a transport fault on "the transporting process's, at the operation".
- **Fix:** always apply `f` on delivery, in the target, as `monitor`'s wrap is applied.

**12. §8.2 / §7.4: claiming the terminal twice faults the entry process, not the caller (P1, P3). Not run: it needs a terminal.**
- **Quote:** "A program that claims it both ways faults its entry process".
- **The inconsistency:** by contrast, a non-UTF-8 line "faults the process that asked for it", and under a shell "faults that process".
- **Program:** `main` reads a line, then a spawned worker calls `Terminal.subscribe`. The entry process dies.
- **Fix:** fault the calling process. Keep the entry process only for keys that arrive with no caller.

**13. E.18 / E.23: failed writes are silent (P3). Not run.**
- **Quote:** "a connection that fails shows as `Left(Closed)` from the next `Tcp.read`". `Os.write` "…is dropped".
- **Program:** a sender that only calls `Tcp.write(s, b)` never learns that the far end is gone.
- **Fix:** `Tcp.write` and `Os.write` answer `Either(Io.Error, Unit)`.

**14. E.0 shape rule 8 contradicts the module listings.**
- **Quote:** "A function of a system module … that waits takes the milliseconds as its last argument". The rule then lists its exceptions.
- **What is wrong:** these functions wait but take no milliseconds and are not listed:
  - `Io.print`, `println`, `printError`, `printlnError` and `write` ("waits while the stream is behind", §8.2)
  - `Tcp.write`
  - `Os.read`
  - `Os.write`
- **Fix:** add them to the rule's list with the reason, or give them the milliseconds.

**15. §6.9: `within = 0` is a sentinel that turns off `restarts`, and the stated rule contradicts itself at `restarts = 0` (P1).**
- **Quote:** "A time of 0 sets no limit".
- **Program (run):**
  - `restarting(RestartLimit(restarts = 3, within = 0), work)`, with `work` faulting every 20 ms, restarted 15 times in 300 ms.
  - `restarts = 0, within = 0` never restarted.
- **Prediction:** a reader expects at most 3 restarts.
- **Fix:** `within = 0` counts restarts over the process's life, and §6.9 states that `restarts = 0` never restarts.

**16. §5.11: bitstring sizes cannot name a top-level constant or a variable bound to their left (P1; the host's rule showing through).**
- **Quote:** "is in scope where the pattern stands and is not bound at top level" and "A variable bound elsewhere in the same pattern is not in scope in its sizes".
- **Program (run):**
  - `let headerSize = 2`, then `<<h:size(headerSize)-bytes, _:bytes>>` is refused.
  - `#(n, <<h:size(n)-bytes, _:bytes>>)` is refused with "unknown name n".
- **Fix:** admit top-level bindings, and variables bound to the left in the same pattern.

**17. §9.6: `Int.div` and `Int.mod` are prelude variants of `/` and `%` (P2), and `mod` is a remainder (P1).**
- **Quote:** "Int.div, Int.mod … // §7.4: / and % fault on zero; these do not". §3.1: "`Int.mod(-7, 3)` is `Some(-1)`".
- **What is wrong:** no language rule needs them, yet §9.6 is titled "required by the language". A reader who knows `mod` expects `Some(2)`.
- **Fix:** move them to E.8, where pairs are allowed, and rename `mod` to `rem`.

**18. §9.5: `Address.callForever` is a variant of `Address.call` (P2).**
- **What is wrong:** it is the same request, unbounded, answering `a` or a fault instead of `Optional(a)`.
- **What it buys:** §8.6's deadlock detection counts it, and it propagates the callee's cause.
- **Fix:** state in §6.6 that the pair is a deliberate exception to principle 2, and why.

**19. §4.2: every prelude type takes a module namespace (P1, P5).**
- **Quote:** "The prelude's namespaces are `Prelude` and the name of every type §9 lists".
- **Program (run):** `test.ern`, `where.ern` and `reason.ern` are all refused ("takes the prelude namespace Test").
- **Why this matters:** `Test` and `TestResult` are in the prelude only for `ern test`, and `Path` only because its module is named after it.
- **Fix:** a prelude type with no members takes no namespace.

**20. §4.6: an unresolved block variable is an error though nothing depends on it (little benefit, P1).**
- **Quote:** "in `{ let xs = []; List.size(xs) }` … the binding is a type error".
- **Program (run):** the compiler answers "the type of xs is not determined".
- **Fix:** leave the variable free and generalize it away. Keep the error where it matters: operators, selection, `<-`, and a spawned mailbox (whose hash §8.7 may need).

**21. §5.10: two spellings of "any value of a named-field constructor" (P2). The report says nothing about the bare form.**
- **Program (run):**
  ```
  type Shape = Circle(r : Int) | Square(side : Int)
  match s { Circle -> true | Square() -> false }
  ```
  Both spellings are accepted. Yet §5.6 says a bare named constructor is not an expression.
- **Fix:** accept only `C()` (an empty `FieldPats`) and say so in §5.10.

**22. §5.11: `unit(N)` is a second way to scale a size (P2).**
- **Program (run):** with n = 2, `<<x:size(n)-unit(8), y:size(n * 8), z:size(16)>>` gives `#(258, 258, 258)`.
- **Fix:** drop `unit`. Sizes are bits for `int` and `float`, and octets for `bytes`.

**23. §9.6 ¶2 and §4.8: `fn Int.+(a, b) = a + b` "is not a recursive call" (P1; a rule that exists only for the standard library).**
- **What is wrong:** the body says the opposite of what it does.
- **Fix:** declare these as `foreign fn Int.+(a : Int, b : Int) -> Int = "erlang:'+'/2"`, which E.0 rule 1 already admits, and drop both rules.

**Principle 4: no finding.** I found no backtracking. Every lookahead is bounded and named in Appendix A's paragraph:
- `fn` followed by a name, against `fn` followed by `(`;
- `=` or `:` after a constructor's first identifier;
- `->` after the `)` of a parenthesized type list (left-factored, so no backtracking);
- `| after` in a `receive`;
- `.` after an uppercase segment.

#### B. Clarity

1. **§2.1 and §2.2 disagree about whitespace.** §2.1 says whitespace "has no other meaning", but in §2.2 a blank line decides where a doc block attaches. §2.1 should name that exception.
2. **§6.3: the operand sentence misparses.** "…which exclude top-level bindings, literals, negative numeric literals, and nullary constructors" reads as if literals were excluded too. Split it into two sentences.
3. **§2.6 gives only `-`'s binding.** "Prefix `-` … binds tighter" says nothing of `!`; only `Unary` in the grammar covers it.
4. **§5.5 does not say the `<-` pattern is irrefutable.** The compiler requires it: `let [x] <- o` gives "a `let` pattern must be irrefutable".
5. **§6.6's "a second answer … discarded silently" cannot happen under the rule,** except through #1. Either drop it or say it concerns foreign code.
6. **§6.6's "`restarting(limit, f)` with such an f is a type error"** already follows from "may appear nowhere else".
7. **§3.9's "This is the one exception to principle 3"** is false given A2, A4 and A10.
8. **§11.5's printed `a=` and `a!` cannot be written back.** `fn equal(a : x=, b : x=)` gives "expected `)` instead of `=`". Say that a printed type is not an annotation.
9. **One written signature, two behaviours.** `fn h(a : Int) -> Unit with e = Unit` and the same signature with body `Io.println("")` are one text, but only the first is callable from pure code (the second gives "needs a process"). Only §11.5's printing tells them apart; §3.9 should say so.
10. **§5.3's delimiter list** includes `{` and `:` without saying where they occur (a `match` scrutinee, a bitstring segment).
11. **The glossary is missing terms** that a concept count needs: `kill`, the call and `answer` (request-reply), code replacement, record update `..`, or-pattern, `as`, `after`, `Where`.

#### C. What each rule buys

**Rules that buy little:**
- `unit` (A22).
- `true` and `false` as reserved words. `type Bool = False | True` in §9.3 would save 2 words and the `bool` literal category; only §8.4's atom mapping would change.
- Prefix `!`, since `Bool.not` exists. It is kept mainly because receive guards cannot call.
- `abstract` must always be written with `export` (§4.4); the only use of `abstract` alone is an error.
- The `within = 0` sentinel (A15).
- The unresolved-variable error on block bindings (A20).
- The 255-character identifier limit (§2.3), which is the host's atom limit.
- `Path` in the prelude.
- `Int.div` and `Int.mod` in the prelude.
- B5's second-answer rule.

**Rules that exist only for another:**
- §9.6 ¶2 and §4.8's rule for the prefix in a built-in type's module: they exist only for the stdlib's operator declarations (A23).
- §6.6's ban on reply-carrying elements of `Optional` and `Either`, and §3.9's exemption: each exists for the other (A6).
- "`let T.op` is an error": it closes a double of `fn` (A9).
- `spawnMonitored`, the `Unknown` reason and the empty `site`: they exist because a `monitor` made after the end knows nothing. They are worth keeping.
- `Test` and `TestResult`: they are in the prelude for `ern test` (A19).
- The exclusion of top-level bindings from receive guards and bitstring sizes: it exists for the host's rules (A7, A16).
- `callForever`: it exists for deadlock detection (A18).

**The heaviest cluster** is Reply, `call`, `callForever`, `answer`, §6.6's rule, the not-reply-carrying inference, `a!` printing, and the container bans. It buys a private reply channel, a call that ends when the callee dies, and a static answered-once check. A1 shows the foreign boundary breaks that check. It is not a "little" rule, but it is the largest one.

#### D. Counts (first release, for the next to compare)

- **Reserved words: 18.** §2.4's table: types 4, pattern matching 6, control flow 3, bindings 2, visibility 1, literals 2.
  - Also 12 contextual words, the bit-specifier names: size, unit, bytes, int, float, utf8, utf16, utf32, big, little, signed, unsigned.
  - Also `Prelude`, a name no module or type may take.
  - Also 35 taken top-level namespaces: `Prelude`, plus the 25 prelude types and the 23 standard library namespaces, which share 14 names (25 + 23 − 14 = 34, plus `Prelude`).
- **Primitives: 32 prelude functions.**
  - §9.4: 4 (self, send, spawn, spawnMonitored).
  - §9.5: 7 (via, call, callForever, answer, restarting, monitor, kill).
  - §9.6: 21 (Int + − * / % and negate, Float + − * / and negate, three `<>`, div, mod, four `compare`, `fault`).
  - 25 prelude types (§9.1: 11, §9.2: 3, §9.3: 11) and 21 prelude constructors.
  - Hidden primitives outside §9: 3. They are `Io.show`/`Io.debug`'s type-directed printing, the supervisor's restart request and restart cause, and the 8 system references in 6 system modules (§8.2).
  - Operators: 17 operator tokens (§2.6 line 2), of which 16 are binary and 2 prefix (`-` is both), and 6 are user-definable (plus the `negate` and `compare` members). Punctuation tokens: 19 (§2.6 line 1). Grammar nonterminals: 48 (Appendix A).
- **Concepts.**
  - §0 claims 2 (functions and processes).
  - Appendix F has 90 entries. Removing the 11 that name the document, toolchain or library leaves 79 language concepts. The 11 removed are: doc block, doc comment, source root, standard library, primitive, supervisor, system module, reserved word, precedence, runtime, Hindley-Milner.
  - At least 8 concepts the report defines are missing from the glossary (B11).

### K, the cold reader

Cold read of `ernest_report.md` (whole report, revision of 28 September 2026). I read only that file and edited nothing. The grammar fragments in §3, §4 and §5 match Appendix A token for token (checked mechanically), and every § and E.n reference points at a section that exists. Everything below is what the rules as written leave wrong or open.

#### A. Defects (contradictions, unreachable rules, silent cases, wrong examples and references)

1. **§3.9 / §4.7 / E.12: a foreign function gets no inferred restrictions, so the §3.10 and §6.6 checks can be bypassed.**
   - Quote: §3.9 says "Three restrictions are inferred from the body"; a `foreign fn` has no body, and E.12 gives `Foreign.from : (a) -> Foreign`.
   - Problem: `Foreign.from` accepts a function, an `Address` or a `Reply`, and §3.10 gives `Foreign` exact equality. So `Foreign.from(a1) == Foreign.from(a2)` compares addresses, which §6.5 forbids ("Addresses have no equality"). `Foreign.from(r)` drops a reply's obligation, and the `Foreign` result is not reply-carrying, so it can be copied freely.
   - Problem, second case: §6.6 makes a type reply-carrying only through fields or components, and a foreign type has neither. So `Ets.put(t, k, request)` in App. D stores a reply in a table and nothing consumes it.
   - Fix: say what a foreign fn's type variables carry (not-reply-carrying by default, equality where foreign code compares), and count a foreign type's arguments as reply-carrying.

2. **§6.5 against §6.9: where `via`'s function runs.**
   - Quote: §6.5 says "by the `send`, in the sender, when the sender is on that node … A fault in `f` is the target's … and the sender goes on". §6.9 says "A `wrap` is applied as `via`'s function is (§6.5), by the delivery … a `wrap` that does not finish holds up no other delivery".
   - Problem: if `f` runs in the sender, an `f` that never finishes hangs the sender, so the sender does not "go on". The builder also has to guess how a fault raised in the sender becomes the target's fault, and whether `restarting` then restarts the target or it dies.
   - Fix: choose one place (delivery, in or for the target) and state it in §6.5.

3. **E.0 shape rule 8 against the signatures.**
   - Quote: "A function of a system module (§8.2) that waits takes the milliseconds as its last argument and answers `Left(Timeout)`; `Clock.now`, … `Io.readLine`, and `Io.read` take none".
   - Problem: these functions all wait but take no milliseconds and are not in that exception list: `Tcp.write` ("waits while the connection is behind"), `Os.write`, `Os.read` (waits for output and answers `Left(Timeout)` from `start`'s time), and `Io.print`, `println`, `printError`, `printlnError` and `write` (§8.2: "waits while the stream is behind").
   - Fix: add them to the list, with the reason (they are paced writes, or timed by `start`).

4. **E.1 `Io.show` against §0 and its own type.**
   - Quote: "`Io.show` writes a value by the argument's type at the call … Where the argument's type is a type variable … a `Char` as its `Int`".
   - Problem: with `fn s(x) = Io.show(x)`, `s('a')` gives `97` while `Io.show('a')` gives `'a'`. That breaks "its result depends only on its arguments" (§0), and `(a) -> String` gives no hint of it. No rule in §3.9 or §9 lets a function see its instantiation. For `let g = Io.show; g('a')` it is unclear which occurrence's type decides.
   - Fix: either define `Io.show` by the runtime representation alone, or add an explicit type-directed rule and list it as a second exception to principle 3.

5. **§3.9 misses a fourth place where inference needs an annotation.**
   - Quote: "Inference asks for an annotation in three places".
   - Problem: field selection also needs its operand type fixed (§3.5: "found as an operator's operand type is"; §4.8: "resolved in the same way"). So `fn name(p) = p.name` is a type error that none of the three places covers. §11.5 has no diagnostic for it either.
   - Fix: add the selection case to §3.9 and §11.5.

6. **§5.5 and App. A `Binding`: what the annotation on a `<-` binding annotates.**
   - Quote: `Binding = "let" Pattern [ ":" Type ] ( "=" | "<-" ) Expr`; §5.5 says "Where both are open it is a type error, which asks for an annotation."
   - Problem: it is not said whether `T` in `let p : T <- e` is the type of `p` or of `e`. If it is `p`'s, it cannot settle the sum type the error asks about.
   - Fix: state which one, and name where the requested annotation goes.

7. **§4.2: how the first segment of a dotted name is resolved.**
   - Quote: "A module may declare a type or constructor with a prelude name, and the name then means the local one throughout the module. … `Prelude` … takes one name the prelude declares."
   - Problem: in a module that declares `type List` or `type Address`, `List.map` and `Address.call` either refer to the local type's members or become unreachable, since `Prelude.List.map` is not allowed (it has more than one name).
   - Problem, second case: a relative member reference such as `Stack.push` from a non-member function of `main.ern` is never stated as legal.
   - Fix: state the lookup for a first segment (local type, then root namespace), and allow `Prelude.T.member`.

8. **§4.2 against §4.8: type-member export rule versus the built-in types' modules.**
   - Quote: §4.2 says members "are exported at `Module.T.member`" and "A declaration never writes its own name qualified"; §4.8 says "`fn Float.+` in `float.ern` declares `Float.+`".
   - Problem: by §4.2 that declaration would export `Float.Float.+`, and it writes its own qualified name.
   - Fix: state §4.8's exception in §4.2.

9. **§8.5 against §7.4 and E.23: what "faults the binding" means.**
   - Quote: §7.4 says "faults the binding `Os.workingDirectory`"; §8.5 says "An initializer that faults … ends the program … before `main` runs"; §8.5 also says "the system modules' bindings are evaluated first".
   - Problem: it is not clear whether a lost working directory ends every program before `main`, or only those depending on `Os` (and `Fs`?). "Faults the binding" suggests readers fault later, which contradicts §8.5. It is also unclear whether "system modules' bindings" means only the `reference` bindings or `Os.arguments` and `Os.environment` too.
   - Fix: define the phrase, and scope "evaluated first" against "a module the program does not depend on is not initialized".

10. **§6.9: `restarting` with `restarts = 0` and `within = 0` contradicts itself.**
    - Quote: "When `n` restarts have happened within the last `t` milliseconds, the next fault is not restarted … A time of 0 sets no limit".
    - Problem: with n = 0 and t = 0, both sentences apply and they disagree.
    - Fix: say which one wins.

11. **E.0 rule 4 against E.10 and E.11.**
    - Quote: "A function that is one pipe of two functions already here is not added".
    - Problem: `Optional.isNone` is `Optional.isSome |> Bool.not`, and `Either.isRight` is `Either.isLeft |> Bool.not`. Rule 4 refuses both, yet both are listed.
    - Fix: remove them, or name them as kept pairs as `Io.debug` and `String.trim` are.

12. **E.0 shape rule 2 against E.5.**
    - Quote: rule 2 says "`contains` on text finds a substring, one grapheme long or longer"; E.5 says `String.contains` "an empty second is always there".
    - Fix: change rule 2 to "a substring of any length".

13. **E.0 rule 1: the promised primitives lists are missing.**
    - Quote: "the operations that reach it are the runtime's, a few that the module's section names as its *primitives*", with `Float` among the representations the runtime owns.
    - Problem: E.6 (Char, Unicode predicates), E.8 (Int: `toString`, bit operations) and E.9 (Float: `toString`, `sqrt`, trigonometry) name no primitives.
    - Fix: add a primitives sentence to each of those sections.

14. **§3.11 against §3.8 and §8.7.**
    - Quote: §3.11 says "The function `spawn(Peer(name), f)` starts crosses with its code". §3.8 and §8.7 also count `spawnMonitored(Peer(...), f, wrap)` as a spawn that ships code.
    - Fix: add `spawnMonitored` to §3.11, and say that `wrap` stays on the calling node.

15. **App. D and G.1 against shape rule 2.**
    - Problem: shape rule 2's container verb for the empty container is `empty`, and the preamble says rule 2 holds in App. D. Yet D uses `Ets.new`. G.1 also says "Each follows Appendix E.0's shape rules" and lists `Ets.new`.
    - Fix: rename it to `empty`, or argue in the text why `new` does something `empty` does not.

16. **G.2: `parse` reads images, but `Inline` cannot hold one.**
    - Quote: "`parse` reads … links, images, and hard line breaks".
    - Problem: `Inline` has no image constructor.
    - Fix: add `Image(...)`, or say images stay as text.

17. **§7.4's opening sentence misfiles its bullets.**
    - Quote: "Partial operations in the prelude return `Optional` or `Either`, except the following".
    - Problem: the list includes `Int.toFloat`, which is in E.8 and not in §9.6, and language-level faults (bitstrings, transport). Shape rule 4 also says a partial operation returns `Optional`, yet `Int.toFloat` faults.
    - Fix: move those bullets to the "no prelude operation" paragraph, and name `Int.toFloat` as an exception to shape rule 4.

18. **§5.11: the bitstring specifier rules leave combinations open.**
    - Problem: nothing says what happens with conflicting specifiers (`int-float`, `big-little`), duplicate ones (`size(8)-size(16)`), or `unit` without `size` (`x:unit(8)`: is the default "8-bit", or 8 units?).
    - Problem: nothing says whether a negative literal (`-1`, which is `AtomPat` "-" int rather than `literal`) counts as "a literal of the segment's type".
    - Fix: one sentence each.

19. **§5.10 and App. A `FieldPats`: an empty field list on a positional or nullary constructor.**
    - Problem: `FieldPats` may be empty, so `Some()` and `None()` are grammatical patterns. Only `Get()` on a named constructor is given a meaning (§6.6). As expressions, `Get()` is a syntax error.
    - Fix: allow `C()` only on named constructors.

20. **§8.5: initialization order across dependent modules.**
    - Quote: "A binding is evaluated after those it depends on, and otherwise in the order its module declares it."
    - Problem: when module A depends on module B but no binding of A depends on one of B, the order of A's and B's initializers (and so what they print) is unstated.
    - Fix: say that a module's bindings run after those of the modules it depends on, or say the order is unspecified.

21. **§8.4: the ABI for `Map` and `Set` is unclear.**
    - Quote: "`Map(k, v)`, `Set(a)` → opaque handles over BEAM maps".
    - Problem: it is not said whether foreign code (including the `Map` primitives) gets a raw map, or what a `Set`'s map values are.
    - Fix: give the exact terms.

22. **§11.6: the formatter's layout is not in the normative document.**
    - Quote: "in the one layout of the style guide that comes with Ernest, `docs/style.md`".
    - Problem: someone building a conforming `ern format` from the report alone has to guess.
    - Fix: bring the layout rules into §11.6.

23. **§11.5: how columns are counted.**
    - Quote: "`file:line:column`".
    - Problem: the unit is not given (bytes, code points or graphemes), nor how a tab counts.
    - Fix: state the unit.

24. **E.5: padding with a character that does not start a grapheme.**
    - Problem: `String.padStart` and `String.padEnd` pad with a `Char` until the grapheme count is reached. With a combining mark (`'\u{301}'`) the count never grows.
    - Fix: say what happens (refuse the character, or pad by code points).

25. **E.9: overflow in the elementary functions.**
    - Problem: `Float.exp(1000.0)` and `Float.pow(10.0, 400.0)` go out of range. It is unclear whether they fault with §3.1's "float arithmetic error" or give `None`; shape rule 4 needs one or the other.
    - Fix: say which, in E.9.

26. **§6.5 and §7.4: missing fault cause.**
    - Quote: an adapted address whose `addr` is remote "otherwise it faults".
    - Problem: §7.4 lists no cause for this fault.
    - Fix: name it.

27. **§9.6 and E.8: the "not a recursive call" exemption covers operators only.**
    - Problem: `int.ern`'s `fn negate(a) = -a` would call itself. `Int.compare` cannot be written with `<`, which is defined through `compare`, so it must be a shim, and E.0 rule 1 does not admit it.
    - Fix: extend the exemption to `negate` and `compare`.

28. **Silent cases, smaller.**
    - §5.9: whether `true` and `false` together cover `Bool` (a built-in type, not a sum type).
    - §5.7: forms the grammar allows on a pipe's right-hand side but the prose excludes (`x |> s.f`, `x |> [f]`): syntax error or type error?
    - §3.5: "they have one type" for a selector over constructors of a parameterized type: identical, or unifiable?
    - §10: whether the right operand of `&&` and `||`, and a pipe's call, are in tail position.
    - §6.9: the `site` of a `spawnMonitored` spawn, and whether the entry process's site has `:line`.
    - §11.2: whether an `abstract type` at the prompt, where "export adds nothing", is an error under §4.4.
    - §11.2 against §7.4: which cause `Os.exit(300)` gives in the shell.

29. **Wrong or weak references.**
    - §6.6: "the fault ends the process and every call waiting on it (§7.2)". §7.2 is message errors; §6.6 itself or §7.3 is meant.
    - Glossary: "arity … §4.5" should be §3.4.
    - Glossary: "node … §8.3" should be §6.2, where node is defined.
    - The glossary claims "Every technical term", but lacks: adapted address, transport, selector, shim, raw string, grapheme, admission rule, shape rule.

30. **Names used before they are defined.**
    - Used earlier than their definition, with no pointer: `Box` (§3.9, defined in §6.6), `Ordering` and `Less` (§3.10), `Path` and `Map` (§3.5), `Down` (§6.2), `RestartLimit` (§6.5), `NotATerminal` (§8.2).
    - Never declared anywhere: `Distance`, `Vec`, `Player`.

#### B. Clarity

1. **§6.6.** "The lambda … may appear nowhere else" is contradicted by the next example, where `let f = fn() = worker(r)` is legal. Name the `let` as an allowed place.
2. **§11.2 `ern test`.** In "…initializers (§8.5), which run in the process that runs the tests, its entry process, one at a time … each in a process of its own", the antecedents are unclear. Split it: initializers in the entry process; tests one at a time, each in its own process.
3. **§6.3.** In "the variables the enclosing function binds, which exclude top-level bindings, literals, …", literals read as if they were excluded. Also say whether a lambda's captures count as variables the enclosing function binds.
4. **§7.4.** In "`Os.exit` with a status outside 0 to 255 faults … and in the shell or under `ern test` with `Fault("exited with status n")`", it is unclear whether the shell clause applies to every status. It does, per §11.2; say so.
5. **E.2.** `List.get`'s "None for a negative index and one past the end" reads as if only that single index is excluded. Say "at or past the end".
6. **§3.1 and E.8.** `Int.mod` truncates, but readers who know Haskell or ML expect `mod` to floor, which is a principle-1 surprise. Rename it to `rem`, or add a sentence warning of it.
7. **§5.11.** `<<-1>>` "faults", even though the compiler can see the overflow in a literal.
8. **App. B.** The introduction describes only the counter; the ping-pong and `WorkerMsg` examples have no prose.
9. **Appendix E listings.** They omit the `a=` and `a!` marks that §11.5 says the compiler prints (for example `List.contains`), so `ern doc` output will differ from Appendix E.
10. **§8.4.** `C(f1 = v1, ..., fn = vn)` uses the reserved word `fn` as a field placeholder.
11. **§8.7.** "a program obtains one only through `self`, a spawn, a message, or a binding" leaves out `via` and addresses returned by foreign code.
12. **§5.3.** Listing `{` as a delimiter that ends a lambda reads as if `fn() = { … }` stopped before its block. Say "a delimiter that belongs to the enclosing form".
13. **§6.10.** The inline `spawn(Peer(name), fn() = send(c, Upgrade(…)))` is not valid as a statement: its type is not `Unit` and its mailbox is unresolved. Show it as `let _ = spawn(…)`.
14. **§7.3.** "out of memory among them" is illustrated with `Fault("error:badarg")`. On the BEAM, running out of memory ends the node, not one process. Pick an example that can actually happen.

### N, the newcomer

Reader c10 (newcomer; README, then the guide alone; program: a TCP chat server)

I did the guide's exercises and ran its programs with `bin/ern`: hello and the §1.4 pair, greet, upper, the shell inputs of §1–§4, counter, queue, resend, message, ping-pong, jobs, the counter service, first([]), the two modules of §7.1, and `ern test`. Each one behaved as the guide says, and the §13 answers matched what I saw. I then wrote the chat server. It works: two `nc` clients see each other's lines, and it also held up under the load tests below. All my files are under `.../scratchpad/readers/c10/`, and the program is `.../readers/c10/chat/chat.ern`. I edited nothing in the checkout. `git status` there shows `ernest_report.md` and `test/ern_docs_tests.erl` as modified, and neither change is mine.

#### Findings on the README and the guide, most serious first

1. **Guide: `Tcp` is never taught, although a server needs it.** §2.9 only lists it ("the system modules `Io`, `Clock`, `Terminal`, `Fs`, and `Tcp`"). §14 points at `webserver.ern`. §9.5 even shows a systemd unit for "The chat server" and a log line `Chat.room:31 faulted`, but no chat server appears anywhere. I learned the module from `:browse Tcp` and `:doc Tcp.*`, which the guide does teach, and those docs are good.
   - **Fix:** add a short worked section on a TCP server: a listen/accept loop, a process per connection, and reading and writing.

2. **Guide §5.5 leads you to expect the wrong I/O model.** It says "the system modules take one [a wrap] wherever something arrives later: `Clock.alarm` … `Terminal.subscribe`." So I expected socket data to arrive in my mailbox. It doesn't: `Tcp.read(sock, ms)` is a blocking pull. That means one process cannot wait for its socket and its mailbox at once, and every connection needs a reader process and a writer process. The guide never says this, and it shapes the whole program. It also never says whether two processes may use one socket at the same time (one blocked in `Tcp.read`, the other calling `Tcp.write`), or what a pending read sees when another process calls `Tcp.close`. I had to try both. Both work: the concurrent use is fine, and the pending read gets `Left(Closed)`.
   - **Fix:** in §5.5, say that `Tcp` is the exception and is pulled by blocking calls. State that a socket may be read and written by different processes.

3. **Guide §8.6 points to a slow way of reading bytes.** It says "A `Bytes` value is read with the `Bytes` module: `Bytes.size`, `Bytes.get` for one octet". My first newline scan used `Bytes.get` and took 16.1 s for 10 MB. The same scan written as a bitstring pattern (`<<10, _:bytes>>` / `<<_, rest:bytes>>`) took 0.13 s. With the first version the server topped out near 3,000 lines/s; with the pattern it reached 23,000 lines/s. (The cause is the per-call overhead in language finding 4.) The guide also says nothing about framing lines over a byte stream.
   - **Fix:** recommend bitstring patterns for scanning, and show a line splitter.

4. **Guide §4.4 "Pacing" does not cover a broadcast to a consumer that stalls.** I found and fixed two unbounded mailboxes:
   - **The room's own mailbox.** At first each reader `send`s its lines to the room. Three clients flooding it built a room mailbox of 123,555 messages. `:processes` then showed about 190 leftover writers, which looked like a leak until `Process.info` showed they were only waiting in that backlog. §4.4's own sentence "A call paces its caller" fixed it: each line became an `Address.callForever`.
   - **A writer's mailbox.** A client that never reads made its writer's mailbox grow from 7,718 to 19,340 queued messages in 4 s. Credits do not apply to a TCP peer. I drop the client when `Process.info(p).queued > 1000`. But §5.2 presents `Process.info` as "for seeing what runs, and a program is still written with the addresses it was given", so I don't know whether this is the intended way.
   - **Fix:** add a paragraph on fan-out to a consumer that may stall, either dropping it or counting acknowledgements.

5. **A compiler message I didn't understand.** `type RoomMsg = Join(Process, Member) | …` gives:
   ```
   chat.ern:9:28: expected `)` instead of `,`
   ```
   The guide does state the rule, but only in one clause of a bullet in §2.3. A programmer from Gleam, Haskell or Rust writes this form first.
   - **Fix:** the message should say "a constructor takes one positional value; name its fields, or carry a tuple `Join(#(Process, Member))`".

6. **Guide §2.9 gives no way to wait indefinitely.** It says "A function that waits takes a timeout in milliseconds last" and that stdin reads wait without a limit. It does not say how a server waits for connections with no limit. In practice `Tcp.accept(l, -1)` and `Tcp.accept(l, 0)` both return `Left(Timeout)` at once, so the accept loop and the read loop must repeat on `Left(Io.Timeout)`.
   - **Fix:** one sentence saying so.

7. **Error text for a user is not covered.** A port already in use prints `chat: cannot listen on port 7440: Other("eaddrinuse")`. The only way I found to show an `Io.Error` was `Io.show`, and the guide doesn't say how to report one.
   - **Fix:** name the idiom, or add a function that turns an `Io.Error` into text.

8. **Guide §9.5: fault lines on a pipe carry a timestamp too.** It says "Where standard error is a file instead, each fault line begins with its time". A pipe also gets the stamp: `ern run jobs.erc 2>&1 | cat` prints `2026-09-28T…Z Jobs.supervise:9 faulted…`. So the §6 transcripts do not match what a reader sees through `| less`.
   - **Fix:** "where standard error is not a terminal or the journal".

9. **README: what put me off.**
   - It has no code at all.
   - The longest of the four "what Ernest adds" bullets is about distribution, which is "planned and not yet built".
   - It assumes you know Gleam and Unison ("Gleam types the channel a message travels on").
   - It gives no clone URL for "a checkout of this repository".
   - **Fix:** a five-line program, and the unbuilt bullet moved last or shortened.

10. **Minor points.**
    - `ern format` re-joined my deliberately split `type RoomMsg` (one constructor per line) into a 97-character line plus a lone `| Gone(Process)`. It follows the style rule, but it reads worse.
    - `Clock.now` is never taught; I only used it for timing.
    - The guide doesn't say that `ern shell prog.erc` cannot pass `Os.arguments`. `:doc Os.arguments` says so.

#### Where the language itself made the program harder than I expected

1. **Sockets are pull-only.** There is no way to wait on a socket and a mailbox together (Erlang has `{active, once}`). So each connection costs two processes, and each member carries a `Process` as its key plus two addresses: its writer and its socket.
2. **Timeouts are mandatory on `accept` and `read`.** Every server writes a loop that repeats on `Left(Io.Timeout)`.
3. **`Bytes` has no search or split.** `String` has `split`, `lines` and `indexOf`, but a chunk can end in the middle of a UTF-8 character, so converting chunks to `String` is unsafe. I wrote the line framing by hand.
4. **Standard library calls are slow.** Measured per call in a loop of 100,000: `Bytes.get` about 1.2 µs, `Bytes.size` about 0.4 µs, `Bytes.slice` about 1.5 µs, `Map.get` about 0.6 µs. An equivalent bitstring pattern costs about 20 ns. So the obvious code is up to 120 times slower than code written with patterns.
5. **No bounded mailbox and no send with a limit.** Protecting a server from a slow client needs `Process.info` polling or hand-written acknowledgements.
6. **Small things I expected from the guide but still found awkward.** With no `if` without `else`, I wrote `if who == from then Unit else send(…)`. Because addresses have no equality, I keep a `Process` beside each address. Named fields are forced as soon as a constructor carries two values.

#### The program: `.../readers/c10/chat/chat.ern`, after `ern format`

```ernest
// A chat server: every line a client sends goes to the other clients.
//
//     ern run chat.erc [port]

type WriterMsg = Out(Bytes) | Close

type Member = Member(name : String, out : Address(WriterMsg), sock : Address(Tcp.SockMsg))

// A client's line is a request, answered once the room has passed it on, so
// that no client sends faster than the room can take its lines.
type RoomMsg =
    Join(who : Process, member : Member) | Said(who : Process, line : Bytes, reply : Reply(Unit))
  | Gone(Process)

// A member whose writer has this many lines waiting reads too slowly to keep.
let backlog : Int = 1000

// The longest line a client may send, in bytes.
let longestLine : Int = 65536

// The room: who is connected, and where each one's lines go.
let room : Address(RoomMsg) = spawn(Local, fn() = roomLoop(Map.empty))

fn roomLoop(members : Map(Process, Member)) -> Unit with RoomMsg =
    receive {
        Join(who = w, member = m) -> {
            broadcast(members, w, String.toUtf8("* " <> m.name <> " joined"));
            roomLoop(Map.put(members, w, m))
        }
      | Said(who = w, line = l, reply = r) -> {
            match Map.get(members, w) {
                Some(m) -> broadcast(members, w, String.toUtf8(m.name <> ": ") <> l)
              | None -> Unit
            };
            answer(r, Unit);
            roomLoop(dropSlow(members))
        }
      | Gone(w) -> match Map.get(members, w) {
            Some(m) -> {
                send(m.out, Close);
                let rest = Map.remove(members, w);
                broadcast(rest, w, String.toUtf8("* " <> m.name <> " left"));
                roomLoop(rest)
            }
          | None -> roomLoop(members)
        }
    }

// Sends the line to every member but the one who said it.
fn broadcast(members : Map(Process, Member), from : Process, line : Bytes) -> Unit with m =
    Map.foreach(members,
                fn(who, member) = if who == from then
                    Unit
                else
                    send(member.out, Out(line <> <<10>>)))

// Disconnects every member whose writer is too far behind, and answers the
// members kept.
fn dropSlow(members : Map(Process, Member)) -> Map(Process, Member) with m = {
    let slow = Map.filter(members, fn(who, _) = lagging(who));
    let kept = Map.filter(members, fn(who, _) = !Map.contains(slow, who));
    Map.foreach(slow, fn(who, member) = {
        kill(member.out);
        Tcp.close(member.sock);
        broadcast(kept, who, String.toUtf8("* " <> member.name <> " was too slow, and left"))
    });
    kept
}

fn lagging(who : Process) -> Bool with m =
    match Process.info(who) {
        Some(info) -> info.queued > backlog
      | None -> false
    }

export fn main() -> Unit with Never =
    match port(Os.arguments) {
        Some(p) -> match Tcp.listen(p) {
            Right(listener) -> {
                Io.println("chat: listening on port " <> Int.toString(p));
                accept(listener)
            }
          | Left(reason) -> {
                Io.printlnError("chat: cannot listen on port "
                                    <> Int.toString(p)
                                    <> ": "
                                    <> Io.show(reason));
                Os.exit(1)
            }
        }
      | None -> {
            Io.printlnError("usage: ern run chat.erc [port]");
            Os.exit(2)
        }
    }

fn port(arguments : List(String)) -> Optional(Int) =
    match arguments {
        [] -> Some(7000)
      | [text] -> String.toInt(text)
      | _ -> None
    }

// Takes each connection as it comes, and gives it a process of its own.
fn accept(listener : Address(Tcp.ListenerMsg)) -> Unit with m =
    match Tcp.accept(listener, 60000) {
        Right(sock) -> {
            let _ = spawn(Local, fn() -> Unit with Never = client(sock));
            accept(listener)
        }
      | Left(Io.Timeout) -> accept(listener)
      | Left(reason) -> Io.printlnError("chat: accept failed: " <> Io.show(reason))
    }

// A client: joins the room, then reads its socket line by line until it
// closes. Its lines go to the room; the room's go to its writer.
fn client(sock : Address(Tcp.SockMsg)) -> Unit with Never = {
    let out = spawn(Local, fn() -> Unit with WriterMsg = writer(sock));
    let who = Process.fromAddress(out);
    let name = match Tcp.peer(sock) {
        Right(end) -> end.host <> ":" <> Int.toString(end.port)
      | Left(_) -> "someone"
    };
    send(room, Join(who = who, member = Member(name = name, out = out, sock = sock)));
    readLines(sock, who, <<>>)
}

// A client's writer: the only process that writes to its socket, and the
// one that closes it.
fn writer(sock : Address(Tcp.SockMsg)) -> Unit with WriterMsg =
    receive {
        Out(bytes) -> {
            Tcp.write(sock, bytes);
            writer(sock)
        }
      | Close -> Tcp.close(sock)
    }

// Reads until the connection closes, or the client sends a line longer than
// `longestLine`; `pending` is what came after the last newline.
fn readLines(sock : Address(Tcp.SockMsg), who : Process, pending : Bytes) -> Unit with m =
    match Tcp.read(sock, 60000) {
        Right(chunk) -> {
            let rest = sayLines(who, pending <> chunk, Bytes.size(pending));
            if Bytes.size(rest) > longestLine then
                send(room, Gone(who))
            else
                readLines(sock, who, rest)
        }
      | Left(Io.Timeout) -> readLines(sock, who, pending)
      | Left(_) -> {
            if Bytes.isEmpty(pending) then Unit else say(who, pending);
            send(room, Gone(who))
        }
    }

// Sends each whole line of `buffer` to the room, and answers what is left
// after the last newline. No newline comes before `from`.
fn sayLines(who : Process, buffer : Bytes, from : Int) -> Bytes with m =
    match newline(Bytes.slice(buffer, from, Bytes.size(buffer)), from) {
        Some(at) -> {
            say(who, Bytes.slice(buffer, 0, at));
            sayLines(who, Bytes.slice(buffer, at + 1, Bytes.size(buffer)), 0)
        }
      | None -> buffer
    }

fn say(who : Process, line : Bytes) -> Unit with m =
    Address.callForever(room, fn(r) = Said(who = who, line = line, reply = r))

// Where the first newline of `bytes` is, counting from `at`.
fn newline(bytes : Bytes, at : Int) -> Optional(Int) =
    match bytes {
        <<10, _:bytes>> -> Some(at)
      | <<_, rest:bytes>> -> newline(rest, at + 1)
      | _ -> None
    }
```

#### Did it work

Yes. It built with `ern build chat.ern` (the first version compiled first time), and `ern format --check` is clean.

- **Two clients with `nc`:** each saw the other's lines, prefixed `host:port:`, plus "joined" and "left" notices.
- **Python clients:** a line sent in two TCP writes arrived joined up, and UTF-8 (`snö och é`) came through intact. 50,000 lines were relayed in 2.2 s.
- **A client that never reads** was dropped as "too slow" and its connection closed, while a reading client still got all 43.6 MB.
- **A line of 100,000 bytes with no newline** made the server close that connection.
- **300 connections opened and closed, half of them with a reset, while three clients flooded the room:** no faults, and `:processes` afterwards shows only `Chat.main` and `Chat.room`.
- **Bad arguments:** a bad port argument exits 2 with a usage line, and a port in use exits 1.

The only thing I took from outside the guide's own text was the `Tcp` API, read through the shell's `:browse` and `:doc`, which the guide teaches.

### C, the toolchain's code, its five parts in one list

I reviewed the erl/ changes from b4278aa to HEAD with four parallel readers: the ern_rt reader, the other runtime files including c_src, cli, and typer/emitter. I read format, lexer and parser myself and checked what each reader reported. Findings marked "verified" were reproduced against the built beams or bin/ern, all run from the scratchpad. I edited nothing in the repository.

**Housekeeping you should know about**
- The cli reader wrote two stray files by mistake, `aa.ern` and `bb.ern`, in the repo root. It confirmed they were its own and I deleted them.
- One of my probes and one reader's each left an `erl_crash.dump` in the root. Both were gitignored and are deleted.
- Another session committed a71d64a during the review; it touched ern_cli.erl and ern_signals.erl. The cli line numbers below are for that tree; all other line numbers are for HEAD.
- The working tree now has someone else's uncommitted edits to `ernest_report.md` and `test/ern_docs_tests.erl`. They are not ours.

#### Defects (most serious first)

1. **erl/runtime/src/ern_tcp.erl:52, :66** — `gen_tcp:listen(Port, Options)` / `gen_tcp:connect(...)`.
   - A port outside 0..65535, or a host holding U+0000, makes the worker raise without answering, so `Tcp.listen` and `Tcp.connect` hang for ever. Verified.
   - Connect's `source_begin(Worker)` (:39) is never ended, so deadlock detection is off for the rest of the run.
   - E.18 is silent on the port's range.
   - Fix: check the range and NUL in `serve/1` and answer `Left(Other(..))`; add the sentence to E.18; wrap each worker in try/after so the reply and `source_end` always happen.

2. **erl/runtime/src/ern_rt.erl:1381** — `lists:foreach(... exit(Pid, {ern, program_end}) ..., live_rows())` runs before the reaper stops at :1395.
   - A spawn the reaper handles after `live_rows()` is read is never killed. Verified: five runs left 176 processes in one node.
   - This breaks §8.6 and the CLAUDE.md rule on memory nothing reclaims.
   - Fix: stop the reaper, or make it refuse spawns, before reading `live_rows()`.

3. **ern_tcp.erl:157** — `Sent = State =:= open andalso gen_tcp:send(Socket, Bytes)`.
   - The socket's own process blocks in send, so reads and read timers stall. Verified: a Recv with a 200 ms limit was answered after 9113 ms, with `Left(Closed)`.
   - This breaks E.18's time limit, and two peers that write a lot before reading can deadlock.
   - Fix: one linked sender process per socket, which answers the writer.

4. **erl/cli/src/ern_shell.erl:1401, :1417** — `:reload` initializes the changed modules in `lists:sort(maps:to_list(Modules))` order, not in dependency order (§8.5, §11.2).
   - Verified: `Aa.x` stays 2 after `Bb.y` becomes 10.
   - Fix: order by `'$deps'`, as `ern_rt:init_modules/1` does.

5. **ern_shell.erl:1298, :1423** — a failed `:load` or `:reload` calls `unload/1` (`code:delete` plus `soft_purge`), which leaves the processes its bindings spawned and the unpurged code. Verified:
   - `:processes` still lists `Svc.server` after "nothing was loaded".
   - The next `:load` prints the host's `=ERROR REPORT==== Module 'ern@svc' must be purged before deleting`.
   - A third attempt kills the first server.
   - Fix: end the module's processes as `end_previous/2` does, then purge; never call `code:delete` while old code exists.

6. **erl/emitter/src/ern_emitter.erl:785-794 with erl/runtime/src/ern_boundary.erl:59** — `arm({'fun', _, _, _, Make}, V, _) -> Make(V)` drops the binding map, and the wrapper checks R through `value/3` with an empty one.
   - So a foreign function value inside a recursive type faults at its call with `error:{badkey,1}` (§7.4). Verified with `type Stream = Stream(head : Int, next : () -> Stream)`.
   - Fix: pass B to `Make`, and seed `chk`/`arm` with it (a `value/4`).

7. **ern_rt.erl:135-138, :166-169** — `{Alias, Mon, Row} = pending(Addr), deliver(Addr, Mk(Alias))`.
   - Under `restarting`, a faulting `Mk` leaves the row, the monitor and the alias behind. Ernest code reaches this: `fn(r) = Get(n = 1 / zero, reply = r)`.
   - Then `info` answers `Calling`, and the callee's death puts a raw `{'DOWN',...}` into the Ernest mailbox, where a catch-all clause takes it.
   - The same leak is latent at :155: `{Alias, fault, Cause} -> fault(Cause)` raises before `untimed()`/`settled()`.
   - Fix: evaluate `Mk(Alias)` before the monitor and row are made; have `await` return the fault and raise it after cleanup.

8. **erl/runtime/c_src/ern_exec.c:294-300** — `} else { frame('a', NULL, 0); }`.
   - An 'i' that arrives after 'e', while input still drains, is acknowledged ahead of the queued ones.
   - ern_os.erl:115-118 answers writes in order, so the oldest writer is released before the program has taken its bytes (E.23). Verified.
   - Fix: when `program_in >= 0`, queue the ack with `push_end` and no bytes; ack at once only when `program_in < 0`.

9. **erl/runtime/src/ern_os.erl:110, :113, :120** — `erlang:port_command(Port, ...)` in `running/2`.
   - A Read, Write or CloseInput queued ahead of the exit raises badarg on the closed port. The program's process crashes, and the reader waiting for `Exited` gets a fault instead.
   - Fix: a `command/2` that catches badarg, as `stop/1` does.

10. **ern_rt.erl:405-409** — `processes() -> [Pid || {Pid, _} <- live()]`, with `info/1` (:415-433) and `died/3` (:479-485).
    - Sockets, listeners and `Os.start` programs are never in the reaper's table. So `Process.live` omits them, `Process.info` answers None for a live socket, and their faults are never reported.
    - E.18 says "`Process.live` and `Process.faults` include them"; E.23 says the same for programs.
    - Fix: cover `opened()` in all three (the site a socket reports is a report gap to decide), or amend E.18 and E.23.

11. **erl/format/src/ern_format.erl:146-148, :171-172** — `trivium/2` takes a doc token's whole source line.
    - `let x = 1 /// note` crashes `ern format` with function_clause in `doc_content/1`, exit 70. Verified with `bin/ern format -`.
    - Such a doc block is an ordinary comment (§2.2), so it must stay trailing, but `lead/2` would move it to a line of its own.
    - Fix: cut the first line from the token's column, and let `trailing/3` take a doc that begins on a token's line.

12. **ern_cli.erl:1370-1381, `write_whole/3`** — it sets the kept mode on the empty temp file before writing.
    - For a 0444 target the write gets `eacces` and the `ok =` fails. Verified: `ern format ro.ern` exits 70 and leaves an empty 0444 `.ro.ern.new`, which then breaks every later attempt.
    - Fix: keep owner write until just before the rename, or refuse the file with an ordinary error.

13. **ern_cli.erl:78-81, :151** — a non-UTF-8 command-line word, the `{error|incomplete,_,_}` form of `word()`, crashes every job except `ern run`'s program arguments.
    - Verified: `ern $'caf\xe9'` and `ern build $'caf\xe9.ern'` exit 70.
    - Fix: refuse such a word in dispatch/job with status 1.

14. **ern_cli.erl:688, :826, and `io:format(Err, "~ts~n", ...)` at :155, :274, :805, :841** — output depends on the host's locale.
    - Verified: under `LC_ALL=C`, `ern format -` writes "café •" as Latin-1 0xE9 and `\x{2022}`, against §11.6. `ern doc`, `--man` and the source lines in diagnostics are mangled too.
    - Fix: write bytes, as `ern_rt:bytes_out/0` arranges for a run.

15. **erl/typer/src/ern_typecheck.erl:1514-1519** — `try resolve_select(0, F, T, Env) ... catch throw:_ -> false`.
    - When constructors share a field name at different types, `ern_diag:span(0)` raises function_clause, which the throw clause does not catch. The shell's `.` completion (ern_shell.erl:900) crashes. Verified with `type T = A(x : Int, y : Int) | B(x : String, y : Int)`.
    - Fix: pass a real span, `{1, 1, {1, 1}}`.

16. **ern_format.erl:77-89, `fence/1`** — a body example is wrapped in `fn f() = {…}` without indenting it, then every laid-out line is dedented by 4.
    - A raw string's continuation line loses 4 spaces: `` let s = `a\n    b`; `` becomes `` `a\nb` ``, in `markdown/1` and in doc examples. This breaks §11.6, "every token is written as it was written". Verified.
    - Fix: indent each body line by 4 before wrapping.

17. **ern_format.erl:146 `string:trim(...)` with erl/format/src/ern_pretty.erl:173** — two trailing spaces on a doc line are dropped.
    - They are a CommonMark hard line break, which libs/markdown and so `ern doc` honour: `/// First line  ` loses its break. §11.6 says a doc block is kept as written. Verified.
    - Fix: keep doc lines' trailing spaces, or say in §11.6 that they go.

18. **ern_os.erl:90-93** — `over -> stop(Run), answered(Reply, {'Left', 'Timeout'})`.
    - `Os.start` can answer `Left(Timeout)`, but E.23 and os.ern give start only NotFound, Denied and Other. Verified.
    - Fix: add Timeout to E.23 and os.ern, or answer Right and let the first read time out.

19. **ern_exec.c:174-180** — `if (pipe(in) < 0 || ...) return 1;` and `if (program < 0) return 1;`.
    - The helper ends with no frame, so start answers "the runtime's helper ern_exec failed" instead of the host's reason E.23 requires (EMFILE, EAGAIN).
    - Fix: `frame('f', strerror(errno))` and return 0, as a failed exec does.

20. **erl/runtime/src/ern_tty.erl:251-256** — `stty(["sane"])` under "the terminal is the one the program found" (§8.6).
    - `sane` resets to stty's defaults, so the user's erase character and flags such as `-ixon` are lost.
    - Fix: save `stty -g` before `raw_mode/0` and restore it.

21. **ern_shell.erl:1767, `collected/2`** — it erases stored values for every dead module, including the Held ones a process still runs.
    - Such a process then gets the false fault "the binding has no value, since one before it faulted". Found by reading.
    - Fix: erase only for the Purged and InputsPurged modules.

22. **ern_rt.erl:139-140** — `timed(), Answer = await(Alias, Mon, deadline(Ms))`.
    - The deadline is taken after `deliver/2`, which runs via functions, but §6.6 says "The clock starts at the call".
    - Fix: make `Deadline = deadline(Ms)` the first statement.

23. **ern_rt.erl:915, :925** — `own_terminal(lines),` ignores `taken`.
    - After keys were granted, stdin still opens a port on fd 0 beside the tty's reader.
    - Fix: serve the request only on `ok`, as ern_tty.erl:201 does.

24. **ern_format.erl:330-332, `alternatives([C])`** — `type T = // c\n    A` is written `type T = // c\nA`, the constructor at column 0. Verified.
    - Fix: take the nested form also when the `=` carries a trailing comment.

25. **ern_format.erl:710-718, `blank_before`** — a comment does not update `prev`.
    - So the blank line in `{\n // setup\n\n let a = 1;` is dropped, though §11.6 drops only one right after the bracket; the mirror case before `}` is kept. Verified.
    - Fix: set `prev` in `lead/2` and `trailing/3` when a comment is written.

26. **ern_format.erl:60-75, `fences`** — a block that fails to parse is not left as it is.
    - `fence/1` returns the dedented lines and `fences` re-pads them, so an under-indented line in an indented fence gains spaces (` x +` becomes `   x +`). An empty ```ernest block gains a blank line. Verified.
    - Fix: keep `Body` when `fence/1` returns its input unchanged, as `doc_lines/1` does.

27. **ern_rt.erl:836-839, `gone/1`** — after `{gone, Run, Name}` the stream process exits normally.
    - Writers blocked in `callForever` then fault "callee returned without answering", and the fault stays unreported only if the launcher's kill wins the race. Latent: not seen in 20 runs.
    - Fix: keep looping after `gone`, dropping writes and answering flush, until `end_program`.

28. **ern_rt.erl:1479-1488, `flush_run/1`** — it misses `{signal, Run, _}`, which `await_main` leaves behind when `main_down` comes first; the message stays in the launcher's mailbox. Two readers found this.
    - Fix: add the clause.

29. **ern_rt.erl:950, :958-961** — a final line ending in `\r` at end of input loses the `\r`. §8.2 strips only a carriage return before a line feed.
    - Fix: strip only before a line feed, or state the rule in §8.2.

30. **ern_os.erl:238-242, `variable/2`** — when a name's first value is not UTF-8 it is skipped and a later one kept, which is not "keeps its first value" (E.23).
    - Fix: mark the name as seen even when its value is dropped.

31. **ern_tty.erl:31-32, :109-116, `PASTE_PAUSE`** — after the pause a pending paste is waited on again, for ever. A lost `\e[201~` swallows every later key. This part is unchanged since b4278aa.
    - Fix: after a pause with nothing new, flush what came as `Pasted`.

32. **ern_typecheck.erl:174-175, `within/2`** — `{L, C} =< {EL, EC}` treats the span's end as inside, but the end is exclusive (ern_diag.erl:13).
    - Fix: use `<`.

33. **ern_typecheck.erl:169-172, `note_text`** — "…`Local` here is this module's constructor; the prelude's is `Prelude.Local`" differs from §11.5's "…, and the prelude's is…". The test at ern_typecheck_tests.erl:350 pins the code's wording.
    - Fix: make the code, the test and the report agree.

34. **ern_cli.erl:46** — `"ern: internal error: ~ts"` has no newline, so the last stack line runs into the next output.
    - Fix: `~ts~n`.

35. **ern_rt.erl:275-277 against :288** — the comment says `Watching` exists "so that a waiter's death takes its waits with it", but a `spawnMonitored` caller's wait is never entered.
    - Fix: add the spawn's waiters to `Watching`, or narrow the comment to `monitor/2`.

36. **ern_shell.erl:585, :530** — `collected/2` runs in the input's own process.
    - An interrupt between deleting a shadowed holder and `Done` leaves the session naming a deleted holder, such as the old `it`, and a later use fails with undef. Found by reading.
    - Fix: collect in the shell's process when the answer arrives.

37. **erl/runtime/test/ern_rt_tests.erl:136** — `timer:sleep(100)` in `fault_reports_test` is not counted, so the reaper's idle check can call a deadlock.
    - It failed 4 of 40 runs with `{badmatch,{fault,<<"deadlock">>}}`. `process_info_test` at :102 and :107 is exposed the same way.
    - Fix: use the file's counted `nap()`.

38. **erl/emitter/test/ern_emitter_tests.erl:686, `restart_limit_test`** — `count()` restarts at `loop(1)`, so every fault's cause is "1", and limits of 1, 0 and -2 all print `ended 1`.
    - Fix: carry a start count in the cause.

39. **ern_emitter_tests.erl:2656 (`system_reference_private_test`) and :1524 (`todo_is_unknown_test`)** — both assert only `{error, _}`; the first passes even if `Io.stdout` were public.
    - Fix: assert the messages, such as "unknown name Io.stdout" and "unknown name todo".

40. **erl/runtime/test/ern_tcp_tests.erl:32** — "the bytes that came after the timeout wait for the next read" is not what happens: the peer sends only once the next read already waits, so the buffered path (ern_tcp.erl:196-198) is untested.
    - Fix: send before the read, or reword the comment.

41. **ern_emitter_tests.erl:1751** — `['Sys', _] -> {ern_rt, sys, 1}` in `prelude_target` is stale; the prelude binds no `Sys.*` (§9.7).
    - Fix: delete the clause.

42. **erl/cli/src/ern_signals.erl:62-78** — the exported `init/1`, `handle_event/2` and `handle_call/2` have no `-spec`.
    - Fix: add them.

43. **Export lists out of definition order** (docs/style.md):
    - ern_rt.erl:26-36: `reason/1`, `input_not_utf8/0`, `read_input/1`, `binding/1`, `signal/1`, `arguments/0`, `exit_program/1`.
    - ern_tty.erl:29: `restore/0` and `is_terminal/1` are defined before `decode/1` and `flush/1`.
    - ern_typecheck.erl:18-21: `let_order/1` and `fields/2`.
    - erl/typer/src/ern_prelude.erl: `builtin_types/0` and `equality_params/1`.
    - erl/cli/src/ern_page.erl: `module_head/1` is defined before `manual/1`.
    - Fix: reorder each list.

44. **erl/typer/src/ern_iface.erl:17-19** — `chunk()` lists `source => binary()`, which ern_emitter.erl:57 strips before encoding.
    - Fix: drop the key.

45. **Comments that no longer hold:**
    - ern_rt.erl:19-23 (header): sources are now in `ern_held` and calls in `ern_calls`, and `ern_processes` also holds faults, restart and deadlock_target rows. The deadlock summary at :16-19 omits calls to system processes and held sources.
    - ern_rt.erl:1041: the clock messages are now `After(ms, reply, to)` and `At(at, reply, to)`.
    - ern_rt.erl:1272-1274: "Only a fault restarts" is wrong; a `'$ern_restart'` request (:1339) restarts too.
    - ern_tty.erl:186-187: the size is answered without a subscription now; say "None where standard output is not a terminal".
    - ern_tty.erl:24 says `loop/1`; it is `loop/2`.
    - ern_tty.erl:5 says "answers Size"; the message is `Measure`.
    - ern_tty.erl:372 and ern_tty_tests.erl:206: the reader no longer reads "a character at a time".
    - ern_tty.erl:154-158: "counted here for every subscription after the first" is wrong; only one returning after all had ended is counted.
    - ern_typecheck.erl:50-52: `effect_origin` calls a top-level `let` pure; it is now a body of mailbox `Never` (§4.6, :1173).
    - erl/emitter/src/ern_descriptor.erl:3 and ern_boundary.erl:17 name only `Io.debug`; `Io.show` uses descriptors too.
    - ern_shell.erl:705-706: `forget/2` says "nothing is unloaded", but `collected/2` unloads.
    - ern_shell.erl:36 says `collected/1`; it is `collected/2`.
    - ern_shell.erl:873-879: `signature/1`'s doc comment stands above `fields/1`, cut off from `signature` at :909.
    - ern_cli.erl:4: "The entry point returns the exit status", but `start/0` is no_return.
    - erl/lexer/src/ern_lexer.erl:6-9: the header's token list omits `{comment, Pos, Text}`.

46. **Misplaced test comments:**
    - ern_typecheck_tests.erl:1202-1204 belongs to `reply_lambda_restarting_test` (:1247), which has none.
    - ern_tty_tests.erl:97-98 belongs above `subscribe/1`.
    - erl/runtime/test/ern_stdlib_tests.erl:123 belongs to `string_test` (:150), and :529 to `random_test` (:547).
    - ern_stdlib_tests.erl:644: `todo_test` now tests `ern_rt:fault/1`; rename it `fault_test`.

#### Clarity

1. ern_format.erl:42 — `[D || D <- Decls, not is_record(D, module_doc)]` never filters anything, since `split/2` has already removed every doc token. Drop it.
2. ern_format.erl:45-46 — a check of two conditions written with andalso/orelse over two lines; docs/style.md asks for a `case`.
3. ern_format.erl:158 — `IsClose` is true for a line that does *not* close; rename it or invert it.
4. ern_lexer.erl, the `"/*"` clause — `Text = lists:sublist(S, length(S) - length(Rest))` runs for every block comment even without `comments`, and takes the length of the rest of the file each time, so it is quadratic. Compute it only when Keep, or have `block_comment` return its text.
5. ern_format.erl:698 — a block comment's layout `[sp(), Text]` glues the next token: `- /* neg */1`, `( /* f */x`.
6. ern_pretty.erl:182-189 — the `fits` comment was not reflowed; one 97-column line stands among short ones. The same goes for ern_cli.erl:1-4, the `mvp_refusals_listed_test` comment, and ern_rt.erl:1092.
7. In ern_rt:
   - The system names list is written twice (:538, :552) and again in `sys/1`'s spec; use one helper.
   - Ad hoc `try … catch _:_` for a missing table appears in `live/0`, `faults/1` (:447), `report/4` (:468), `opened/0` and `proxy_forget/2`, though `ets_lookup/2` and `ets_match/2` exist for this.
   - The `alive` column never changes; drop it.
   - At :459, `Stack` should be `Trace`.
   - At :1087-1108, `run_main`'s paragraph omits `{fault, Msg, Trace}` and the flush of stderr, and has the type between the comment and the spec.
   - At :1222-1225, `io:setopts` runs as a side effect inside a comprehension filter.
8. In ern_exec.c:
   - `runtime_open` is always 1 (:233, :242, :378); remove it.
   - At :151, `pending = realloc(pending, …)` loses the pointer on failure; use `push_end`'s `grown` pattern.
   - At :363-388, the helper polls every 50 ms once the outputs close; a SIGCHLD self-pipe would avoid it.
9. ern_tcp.erl:64-84 and :107-125 — `connect` and `accept` repeat the same deadline, retry and answer shape; one helper would do.
10. ern_boundary.erl:117 and erl/runtime/src/ern_show.erl:55 — `when element(1, F) =:= 'fun'` hides that function descriptors have two shapes; match both, and list both in ern_boundary's header.
11. erl/runtime/src/ern_string.erl `trim_start/1` re-checks the whole rest with `characters_to_binary` at every leading space; recurse on the rest directly.
12. Two comment fixes: at ern_os.erl:100-101, say "for every piece and for the status"; ern_tty_tests.erl:1 names E.16 twice.
13. In ern_typecheck:
    - At :2012, the origin is recognized by its display text "a top-level `let`"; tag it with an atom.
    - At :130, `hidden_uses` is recomputed for every error.
    - At :967-968, use the report's "calls a process-only function".
14. ern_emitter.erl:790, :793 — `desc_form(R)` is emitted twice per level, so a curried result's form doubles at each level.
15. In ern_cli:
    - At :69-70, `ern/2` only forwards to `dispatch/2`.
    - At :55, `ern_signals:ended()` is called twice.
    - At :907-915, the second UTF-8 check is always true.
    - At :990 and :1194, the runtime's lines are sent two ways.
    - At :740-771, `markdown_dir` and `man_dir` duplicate the path-and-read code.
16. ern_signals.erl:12-21 — the `install/0` comment is hard to parse; split it into plain sentences.
17. erl/*/src/Makefile:33 — "since make calls counts their calls"; write it as "since `make calls` counts".
18. ern_shell.erl:1334 — `initialize/3` spawns and then monitors, leaving a gap in which the cause could come back as noproc; monitor at the spawn.
19. Nits:
    - ern_emitter_tests.erl:2463 has an unused `me`.
    - ern_emitter_tests.erl:2540 writes "%% Report" with a capital.
    - ern_prelude.erl:527 closes a list with `].` alone at column 0.
    - erl/typer/test/ern_prelude_tests.erl:144 ends its section at "## Appendix H", a heading that does not exist.

Checked and found clean:
- ern_page and the new cli tests.
- ern_grammar_tests and the parser changes (`declaration_start`, the diag refactor).
- ern_exec.c compiles warning-free with `-std=c99 -pedantic -Wall -Wextra`.
- A killed run leaves no zombie and kills the program's group.
- No changed file has a line over 100 columns or a tab.
- Every export has a `-spec` except those in item 42.

### E, the Ernest code

C14 reader: the Ernest changed since b4278aa (50 .ern files, ~11,500 lines)

The fork agents could not start because the concurrent-subagent limit was reached, so I read every file myself, rendered the module pages, and ran each doubtful behaviour. The repository is unchanged. My scratch programs are in /tmp/claude-1001/-home-jocke-projects-ernest/5878ddea-cb10-40c7-a354-3f491e030515/scratchpad/readers/c14/.

#### A. Defects, most serious first

1. **String searches match inside a grapheme, and `split` and `replace` lose text.**
   - Where: /home/jocke/projects/ernest/stdlib/string.ern:117 (`indexOf`, which is `ern_string:index_of/2` over `string:find`, /home/jocke/projects/ernest/erl/runtime/src/ern_string.erl:19-35). `split` (290-301), `replace` (160), `contains` and `lines` are built on it.
   - What I ran:
     - `String.split("e\u{301}x", "\u{301}")` gives `["", "x"]`. The `e` is lost.
     - `String.replace("a\r\nb", "\n", "X")` gives `"aXb"`. The CR is lost.
     - `String.indexOf("a\r\nb", "\n")` gives `Some(1)`, but `indexOf(..., "\r")` gives `None`.
     - `String.contains("e\u{301}", "\u{301}")` gives `true`.
   - What is wrong: E.5 says "every search matches whole graphemes".
   - Fix: accept a match only where it starts and ends on a grapheme boundary of the first string, and add these cases as tests.

2. **The Supervisor's restart limit does not limit restarts.**
   - Where: /home/jocke/projects/ernest/stdlib/supervisor.ern:232-244 and 134-141.
   - Cause: a child restarts itself at once through `restarting(unlimited)`, and only afterwards tells the supervisor with an asynchronous `send(sup, Faulted(p))`.
   - What I ran: `OneForOne` with `RestartLimit(restarts = 2, within = 5000)`, and a child that prints and then faults. It printed "child starts" about 200 times, with about 200 "faulted, restarted" lines, before "supervisor restart limit reached". The report's rule allows 3 starts.
   - Second fault in the same code: the count is kept by one alarm per fault, so `within = 0`, which §6.9 says "sets no limit", still gives up. Three children faulting together under `RestartLimit(restarts = 1, within = 0)` ended with "supervisor restart limit reached".
   - Fix: make a fault a call that the supervisor answers (restart or give up) before `f` runs again, and count the window by time the way `restarting` does.

3. **The shell's live region keeps an unfinished line whole, so a line without a line feed costs quadratic time and memory that is never reclaimed.**
   - Where: /home/jocke/projects/ernest/shell/shell/region.ern:80-83 (`wrote` keeps all of `writing`; `split` and `clip` scan it on every write).
   - What I measured:
     - 2000, 4000 and 8000 calls of `Shell.Region.wrote(r, ".")` took 3.2 s, 13.2 s and 54.5 s.
     - At a 24x80 pseudo-terminal, `List.foreach(List.range(1, 6000), fn(_) = Io.print("."))` held up the next answer for about 38 s.
   - Fix: commit the rows of `writing` that are wider than the window as the terminal wraps them, and keep only the last part-row.

4. **`Fs.list` fails for the whole directory when one entry cannot be stat'ed.**
   - Where: /home/jocke/projects/ernest/erl/runtime/src/ern_fs.erl:88-104, behind /home/jocke/projects/ernest/stdlib/fs.ern:96.
   - What I ran: a directory that exists and holds one dangling symlink gives `Fs.list(Path("dangling"), 1000)` = `Left(NotFound)`. A file removed between the listing and its stat does the same.
   - Consequence: it breaks `:load` completion (/home/jocke/projects/ernest/shell/shell.ern:1076) and filesync.
   - Fix: stat each entry with lstat as a fallback, or leave out an entry that has vanished.

5. **Styled Markdown rows leave a terminal style open, and the shell's listing cut then leaks it.**
   - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:751-831; /home/jocke/projects/ernest/shell/shell/region.ern:190-203.
   - What I ran:
     - `render(parse("# A long heading here"), 8, Styled)` gives `["\e[1mA long", "heading", "here\e[22m"]`: bold is switched on in the first row and off only in the last.
     - `Shell.Region.typing` with those rows in a 4-row window wrote `"\e[1mA long\nheading\nand 5 more..."`. Bold is never closed, so the prompt and input painted afterwards are bold.
   - Fix: `render` should close and reopen each open style on every row, as `region.ern`'s `wrapped` does.

6. **The editor's cursor counts Chars inserted, while the text is indexed by graphemes.**
   - Where: /home/jocke/projects/ernest/shell/shell/editor.ern:334-339 (`at = at + String.size(what)`, once per key).
   - What I ran:
     - Keys `e` then `U+0301` give text `"é"` with the cursor at 2.
     - Keys 👍, `U+1F3FD`, `x` give two graphemes with the cursor at 3. Backspace then deletes nothing.
   - Fix: set `at` to the size of `slice(text, 0, at) <> what`.

7. **filesync never settles.**
   - Where: /home/jocke/projects/ernest/examples/filesync.ern:64-66 and 89-91.
   - Cause: after storing a file it records the peer's mtime, but the file's own mtime is now the write time. The next tick sees it as changed and sends it back.
   - What I ran: a/f.txt and b/f.txt were rewritten alternately every 5 s for as long as the program ran. The header says "Two directories are kept identical".
   - Fix: record the stored file's own mtime (stat it after writing).

8. **Markdown turns inline HTML at the start of a line into a Raw block, and that line ends the paragraph before it.**
   - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:190-201 and 452-460.
   - What I ran:
     - `parse("Some text\n<b>bold</b> more")` gives `[Paragraph([Text("Some text")]), Raw(["<b>bold</b> more"])]`.
     - `parse("<em>hi</em> there")` gives `[Raw(...)]`.
   - What is wrong: G.2 says inline HTML stays in the text. In CommonMark this kind of HTML block (type 7) needs the tag alone on its line, and cannot interrupt a paragraph.
   - Fix: only a tag alone on its line begins an HTML block, and such a line does not interrupt a paragraph.

9. **An unreadable history file is reported twice, and the second report garbles the transcript.**
   - Where: /home/jocke/projects/ernest/shell/shell.ern:267-279 and 838-842 (the reader always starts with `keeping = true`), and 1246-1259 (`remember` reports through `say`/`Said`, which takes the prompt with it).
   - What I ran, at a pseudo-terminal with ~/.ernest/history a directory:
     - `the history could not be read: eisdir`
     - `> the history is not kept: eisdir`
     - `1 + 1`, on a row with no prompt.
   - What is wrong: §11.2 says such a file is "reported once".
   - Fix: start the reader with `keeping = false` when the read failed, and write the note with `Noted`.

10. **Startup files.** Where: /home/jocke/projects/ernest/shell/shell.ern:340-392.
    - (a) When the working directory is $HOME, `$HOME/.ernest/startup` and `./.ernest/startup` are the same file, and every line runs twice. I saw the diagnostic twice and the `let`s run twice; a service in the file would be spawned twice.
    - (b) A command that fails in a startup file is refused without its file and line: `:set depth x` gives only ":set depth takes a number". §11.2 says a failure is reported with the file and line.
    - (c) A startup file that is not UTF-8 is read as empty and nothing is said (line 353).
    - (d) The same file is named by its absolute path in one report and by a relative path in the other; §11.5 wants the path from the working directory.
    - Fix: run a file once by its real path; report command refusals with file:line; say "is not UTF-8".

11. **`List.partition` calls its predicate from the last element first.**
    - Where: /home/jocke/projects/ernest/stdlib/list.ern:304-311.
    - What I ran: `List.partition([1,2,3], fn(n) = { Io.println(Int.toString(n)); n > 1 })` prints 3, 2, 1. `filter`, `span`, `any`, `all` and `find` call it left to right, and the callback may have effects.
    - Fix: evaluate `p(y)` before the recursive call.

12. **`Path.withExtension` on dot-files and on the root.**
    - Where: /home/jocke/projects/ernest/stdlib/path.ern:100-127.
    - What I ran:
      - `withExtension(Path(".bashrc"), "")` gives `Path("")`.
      - `withExtension(Path("dir/.bashrc"), "txt")` gives `Path("dir/.txt")`.
      - `withExtension(Path("/"), "txt")` gives `Path("/.txt")`.
      - `extension(Path(".bashrc"))` gives `Some("bashrc")`.
    - Fix: a name whose only dot is its first character has no extension, and neither does the root. State this in E.14 and on the page.

13. **`Fs.Entry.mtime` is whole seconds.**
    - Where: /home/jocke/projects/ernest/erl/runtime/src/ern_fs.erl:99-101 (`Mtime * 1000` from `{time, posix}`).
    - What is wrong: E.17 and the page say "milliseconds since the epoch, as Clock.now". I saw `1790590774000`, and two writes within one second get equal mtimes.
    - Fix: read millisecond time, or state the resolution.

14. **`String.padStart` and `padEnd` break their promise when the Char joins its neighbours.**
    - Where: /home/jocke/projects/ernest/stdlib/string.ern:188-197.
    - What I ran:
      - `String.size(String.padStart("", 2, '\u{1F1F8}'))` gives 1 (two regional indicators make one flag).
      - `padStart("\u{301}", 2, 'e')` gives `"é"`, of size 1.
    - What is wrong: the page promises "at least that many graphemes long".
    - Fix: pad until the size is reached, or state which Chars the promise excludes.

15. **`Terminal.size`'s page example does not compile where a programmer writes it.**
    - Where: /home/jocke/projects/ernest/stdlib/terminal.ern:88, `Some(Size(rows = rows))`.
    - What I ran: outside the module this gives "unknown constructor Size".
    - Cause: /home/jocke/projects/ernest/erl/runtime/test/ern_doc_tests.erl:55-62 type-checks each example inside the module's own source, so an unqualified or private name passes.
    - I type-checked all 231 standard-library examples from outside their modules; this is the only one that fails.
    - Fix: write `Terminal.Size`, and check examples as a module that depends on this one.

16. **The history trim rewrites the file in place.**
    - Where: /home/jocke/projects/ernest/shell/shell/history.ern:40-48 (`Fs.write`, which is `file:write_file` and not atomic).
    - What is wrong: §11 says "A file a job writes is written whole or not at all." A signal during the trim leaves a truncated history.
    - Fix: write a sibling file and `Fs.rename` it into place.

17. **webserver answers a request it cannot parse with 404.**
    - Where: /home/jocke/projects/ernest/examples/webserver.ern:91-95.
    - What I ran: `"garbage\r\n\r\n"` and a malformed header line both got `HTTP/1.1 404 Not Found`. The right answer is 400 Bad Request.
    - Fix: add `StatusCode.badRequest`.

18. **services: stale line number and a sleep race.**
    - Where: /home/jocke/projects/ernest/examples/services.ern:9-10 says `Services.store:26`, but the run prints `Services.store:24 faulted, restarted: ...`.
    - Also: 62-66 sleep 500 ms so that `callForever` does not meet the restart. Under load it can still fault with "callee was restarted" (see C6).
    - Fix: change the header to 24.

19. **echo monitors a server it never watches.**
    - Where: /home/jocke/projects/ernest/examples/echo.ern:57 and 64 (`spawnMonitored(..., Served)`).
    - What is wrong: the `Down` is never received and `server` is unused. The header says "accepts one connection at a time", but the server accepts exactly one.
    - Fix: use `spawn`, or receive `Served` after closing; correct the header.

20. **repl's header promises recursion.**
    - Where: /home/jocke/projects/ernest/examples/repl.ern:4-6, "functions of one argument, and recursion".
    - What I ran: `let f = fun n -> f n` then `f 1` gives "error: unbound f".
    - Fix: drop the claim, or bind the name in the closure's environment.

21. **Markdown puts a lazy line after a heading into the quote.**
    - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:337-354.
    - What I ran: `parse("> # Heading\nlazy")` gives `Quote([Heading, Paragraph("lazy")])`. In CommonMark the paragraph is outside the quote.
    - Fix: `continues` must require that the line before was paragraph text.

22. **Markdown expands tabs inside code content.**
    - Where: /home/jocke/projects/ernest/libs/markdown/markdown.ern:213-220, applied to every line.
    - What I ran: a fenced block containing `"\tx"` gives the line `"    x"`. CommonMark keeps tabs in code content, so a Makefile snippet is changed.
    - Fix: expand tabs only where they decide the block structure.

#### B. Clarity, surprise, and page gaps

1. **Tcp page.**
   - /home/jocke/projects/ernest/stdlib/tcp.ern:3-4 says "after its connection closes, from either end, each read answers Left(Closed)". After the program's own `Tcp.close`, a read faults instead (I saw "faulted: callee returned without answering").
   - `read`, `accept`, `port`, `peer` and `local` fault on an ended socket or listener (E.18) but have no Errors section; only `write` has one.
   - `ListenerMsg`'s example `Either.map(Tcp.listen(0), fn(l) = l)` is the identity and leaks a listener.

2. **Fs page.** /home/jocke/projects/ernest/stdlib/fs.ern:1-5 leaves out:
   - the U+0000 rule;
   - that a name that is not UTF-8 is left out of `list`;
   - that a relative path is resolved against `Os.workingDirectory`;
   - that a write, rename or remove that times out may still happen;
   - what `Other(text)` holds: the host's errno name, such as `"eexist"` for a directory that is not empty, `"eisdir"` or `"enotdir"`.

3. **Os page.** /home/jocke/projects/ernest/stdlib/os.ern:169-173, 201-204 and 273-277 put `Left` answers in Errors sections. Shape rule 6 keeps Errors for faults, and Fs puts its `Left`s in the prose. `start`'s list also lacks E.23's `Left(Other(text))`.

4. **Shape rule 6 gaps elsewhere.**
   - No Ets function has an Errors section, though every one faults on a table that is gone.
   - `Ets.Table`, `Random.Seed` and `Supervisor.Msg` have no Examples section.

5. **String page.**
   - The module doc's list of primitives leaves out `graphemes`, which E.5 names.
   - `toFloat` says "the float literal form of report §2.5". §2.5 allows `_`, but `toFloat("1_0.5")` is `None`. E.5's "without _", the finite-range rule and the subnormal rule are missing from the page.
   - `lines` does not say that `""` has no lines.

6. **Map and Set pages.**
   - `Map.toList`, `keys` and `values` do not state their order, so `:doc Map.toList` never says it is unspecified.
   - The order in which `map`, `filter`, `filterMap`, `any`, `all` and `mergeWith` call their callbacks is unstated.
   - Set's examples show a definite order (`union` gives `// => [1, 2]`) for results the page calls unordered.

7. **Wrong citation in Either.** /home/jocke/projects/ernest/stdlib/either.ern:96 cites "Appendix E.0 rule 4", which is admission rule 4 (compositions). The rule meant is shape rule 4.

8. **Page and report disagree on `Erl.atom`.** /home/jocke/projects/ernest/stdlib/erl.ern:77-80 shows `// => ready`. E.1 says a representation that reads as nothing in Ernest prints as `<foreign>`. One of them is wrong.

9. **`Process.faults` doc.** /home/jocke/projects/ernest/stdlib/process.ern:107-109, "It is no source that can deliver (report §8.6)". Say instead: "a subscription does not keep a deadlock from being detected".

10. **Supervisor page.**
    - The module example (supervisor.ern:35-38) uses a mailbox of bare `Reply(Int)`. A reader expects `Get(reply : ...)`.
    - `child`'s Errors section tells users about "MVP 3.0".

11. **`compare` is written with `<`.** /home/jocke/projects/ernest/stdlib/string.ern:89, char.ern:117, int.ern:178 and float.ern:82 define `compare` with `<`, and §3.10 defines `<` through `T.compare`. §9.6's "names the runtime's operation" covers operators only, so the report is silent here. There are also two spellings: `== then Equal` in String, `> then Greater` in the others.

12. **Tcp.write and others wait with no timeout, which shape rule 8's exceptions do not name.** `Tcp.write`, `Os.write`, `Os.read` and `Io.print` all wait. A `Tcp.write` to a client that stops reading blocks its handler forever, which leaks it in the webserver.

13. **`:type` of a declaration.** /home/jocke/projects/ernest/shell/shell.ern:613-621: `:type fn f() = 1` prints `fn f() = 1 : Unit`, and `:type type T = A | B` prints `: Unit`.

14. **NO_COLOR.** /home/jocke/projects/ernest/shell/shell.ern:301 colours when NO_COLOR is set to `""` (the no-color.org rule). §11.2 says "where the environment does not set NO_COLOR", and the comment says "to anything". Pick one rule and state it.

15. **The shell's colour choice is a Bool.** /home/jocke/projects/ernest/shell/shell/style.ern:10-45 (`fault(on : Bool, ...)` and the rest) is the `render(doc, false)` form that shape rule 9 refuses. The shell then converts it to `Markdown.Style` with `styleOf`; one type would do.

16. **"tail" versus "live region".** /home/jocke/projects/ernest/shell/shell/command.ern:68 and the `:output` answer say "the tail"; §11.2 says "the live region".

17. **The shell's module pages are bare.** Its exported declarations are documented with `//` comments, so `ern doc` renders signatures with no prose. Use `///`.

18. **template.** /home/jocke/projects/ernest/examples/template.ern: `checked(diameter)` computes a radius, not a check. The private `half` is rendered as `## ...Template.half` with nothing saying a caller cannot call it.

19. **webserver.** /home/jocke/projects/ernest/examples/webserver.ern:195 has the banner "Abstract-type definitions" over two private types that are not abstract, and `SessionId.parse("")` accepts an empty id.

20. **snake.** /home/jocke/projects/ernest/examples/snake.ern:56-77: without a terminal it says it needs one, then draws a frame with clear-screen escapes to stdout and exits 0. `Interrupt` (C-c) is ignored (line 111). The header says "multiplayer" but the program has one player.

21. **tools/manual.ern.** /home/jocke/projects/ernest/tools/manual.ern:73-88 builds Markdown text (`"**" <> n <> "**(3ern)"`) only to parse it back. It can build the blocks directly.

#### C. Where the language made the code harder

1. **A list of functions cannot be a top-level binding.** /home/jocke/projects/ernest/libs/markdown/markdown.ern:166-169: the block-starter list is `fn starts()` because a `let` naming functions that refer back to it is a §8.5 cycle. The list is rebuilt for every line.

2. **`kill` and `monitor` take `Address(a)`, not `Process`.** So the supervisor's watcher carries two closures per child, `stop` and `watch` (/home/jocke/projects/ernest/stdlib/supervisor.ern:63-80 and 236), as a way to hold children of different mailbox types.

3. **"No limit" has no name.** It is spelled `RestartLimit(restarts = 1, within = 0)` (supervisor.ern:246-248), a meaning that is invisible at the use site.

4. **`Io.show` depends on the type at the call.** So `Io.debug` cannot be written in Ernest and is a shim that builds Io's private `Write` message in Erlang (/home/jocke/projects/ernest/erl/runtime/src/ern_io.erl:19-23). A generic `fn f(x) = Io.show(x)` prints a Char as its Int.

5. **Every program writes its own `Io.Error` text table.** The same `errorText` is in filesync.ern:159-168 and webserver.ern:184-193, and the shell has a third (`trouble`, shell.ern:366-375). `Other` carries raw errno names, so none of them can word those cases.

6. **Nothing tells a program that a supervisor's restart has finished.** services.ern:62-66 sleeps 500 ms instead.

7. **No overloading, so one operation gets two verbs.** `Tcp.close` and `Tcp.closeListener` (shape rule 2).

8. **`Bytes.slice` is a shim though the bit syntax can express it.** /home/jocke/projects/ernest/stdlib/bytes.ern:68-74 uses `binary:part/3`, but `<<_:size(s)-bytes, p:size(n)-bytes, _:bytes>>` does the same job. E.20 names it a primitive, while CLAUDE.md admits a shim only where Ernest cannot express the work. `Bytes.get` is the same case.

### T, the tools

Reader c19: a user's review of `bin/ern`'s jobs, options, messages and the shell's commands before the first release.

Work dir: /tmp/claude-1001/-home-jocke-projects-ernest/5878ddea-cb10-40c7-a354-3f491e030515/scratchpad/readers/c19/. Nothing under the repo was edited.

Caveat: while I worked, `erl/cli/src/ern_cli.erl` and `ern_signals.erl` had uncommitted changes, and `build/stdlib` was rebuilt twice (12:13:5x and 12:15:15). One build failed once during a rebuild with "unknown name Io.println". I left that failure out; every finding below reproduced on a second run.

#### Defects

1. **The directory-mode sweep deletes files no build wrote.**
   - Commands and results:
     - `ern build --build-root build lib`, then `ern build --build-root build --load-path build app`: `app/main.ern` uses `Util.Math`. The build compiled `main.erc` against `build/util/math.erc`, then deleted that file. `ern run build/main.erc` then says "cannot find module Util.Math", and the next build fails.
     - `ern build --build-root . src`: deleted `./lib.erc`, `./lib/two.erc` and the empty `./emptydir`.
     - `ern build src` (build root defaults to the source root): deleted the user's empty `src/todo`, `src/assets/img` and `src/.git`, although §11.1 says dot-names are passed over.
   - Expected: only `.erc` files this build had written for sources now gone, and only directories the build had emptied ("left empty").
   - Principle 3, and data loss.
   - Fix: keep a record of what each build wrote, and sweep only that.

2. **`--build-root` does not find modules outside the source root, contrary to §11.1.**
   - Command: `ern build --build-root build app`, with `build/util/math.erc` present.
   - Did: `unknown name Util.Math.twice`. It works only with `--load-path build`, which then triggers the deletion in item 1.
   - Principle 1.
   - Fix: look up `.erc` files under the build root before the load path, as §11.1 says.

3. **A stale dependent runs against a changed interface, so a type error becomes a runtime fault.**
   - Commands: change `Geo.Shape.area` from `-> Int` to `-> String`, run `ern build --source-root src src/geo/shape.ern`, then `ern run src/main.erc`. In the shell the same happens after `:reload` followed by `Main.main()`.
   - Did: `Main.main faulted: foreign function erlang:integer_to_binary/1 raised error:badarg`, with a host stack.
   - Expected: a refusal at load ("Main was compiled against another Geo.Shape"), or `:reload` recompiling the dependents of a changed interface.
   - Principles 1 and 3.
   - Fix: record the hash of each dependency's interface in the `.erc`, and check it when loading and when reloading.

4. **A single-file build takes its namespace from the working directory, so the same file becomes a different module.**
   - Commands: `ern build src`, then `ern build src/geo/shape.ern`, then `ern run src/main.erc`.
   - Did: the second build silently rewrote `shape.erc` as `Src.Geo.Shape`. The run then printed a raw `=ERROR REPORT==== … beam/beam_load.c(186) … module name in object code is 'ern@src@geo@shape'` and exited 1. The run already checks this for the entry module ("fake.erc is not at the path of its namespace Bool") but not for dependencies.
   - Principle 1.
   - Fix: apply the namespace check to every module loaded, and refuse to overwrite a `.erc` that holds another namespace.

5. **A closed pipe is treated as a crash in every job but `run`.**
   - Commands and results:
     - `ern build bad.ern 2>&1 | head -1`, or `ern build --foo x 2>&1 | head -1`: the VM crashes, leaves a 2 MB `erl_crash.dump` in the working directory, and exits 1. This happened five times in my session.
     - `ern format - < big.ern | head -1`: "ern: internal error … the device has terminated", with a stack, status 70.
     - `ern shell | head -3`: "Failed to write log message to stdout… =ERROR REPORT==== Writer crashed (epipe)", status 0.
   - Expected: status 141 with nothing printed, as `ern run` does.
   - Principles 3 and 1.
   - Fix: handle EPIPE on both streams in every job, as `run` does.

6. **Internal errors (status 70) on ordinary input.**
   - Commands and results:
     - `ern build emptydir` and `ern doc emptydir`: `no match … {error,einval} in ern_cli:remove_empty/2`.
     - `ern build ok/`, where the only file has a non-UTF-8 name: four host `=WARNING REPORT==== Non-unicode filename … ignored`, then the same crash.
     - `ern doc junk.erc`: badmatch in `ern_page:page/1`. `run`, `test` and `shell` give a message for the same file instead.
     - A module with about 1100 `Test` lets: `emitted_erlang_does_not_compile … beam_validator … limit`. 1000 compile.
   - Principle 1.
   - Fix: never sweep the root itself; refuse non-UTF-8 names with a message; give `doc` the loader's message; split the generated `$tests` function.

7. **Refusals of old spellings recommend what the job then refuses.**
   - Commands and results:
     - `ern run --out-dir x` says "--out-dir is now --build-root", but `ern run --build-root x` gives "invalid option". The same happens in test, shell, config, format and doc.
     - `--errors short` → "is now --short-errors" in run, test, shell and config, none of which takes it.
     - `ern run --emit erl` names `--emit-erl`, which only build takes.
     - `ern build --emit-erl=x` gets "--emit erl is now --emit-erl", although the user wrote `--emit-erl`.
     - `ern --version --help`, `ern --version --version` and `ern -v` say "comes after the job: ern <job> --version", but `ern build --version` is refused.
   - Principle 1.
   - Fix: map each old spelling per job, and match whole option names rather than prefixes.

8. **Option parsing has hidden rules.**
   - A repeated single-value option silently takes the first value: `ern build --build-root a --build-root b` writes to `a`, and `ern run --main Two.other --main Two.third` runs `other`.
   - `--name=value` is accepted everywhere but documented nowhere. This is a second spelling beside `--name value` (§11).
   - `--build-root=` and `--config-dir=` (empty) are accepted.
   - Principles 2 and 3.
   - Fix: refuse a repeated option, the `=` form and empty values.

9. **`ern shell --main Foo.bar` with no file is silently ignored.** With a file, the same option is checked ("cannot find module Foo").
   - Principle 3.
   - Fix: refuse `--main` without a file.

10. **The checker reports one error per function, and a directory build stops at the first failing module.**
    - Commands and results:
      - `bad3.ern` has `Io.println(1); Io.println(2)` and `bad4.ern` has two bad annotated lets: only the first error is reported.
      - `ern build src` with `c.ern` and `e.ern` both broken and independent: only `c.ern`'s error appears.
    - Expected, per §11.5: "every error that does not follow from another".
    - Principle 1.
    - Fix: keep checking after an independent error, and build every module that does not depend on a failed one.

11. **`ern format` rewrites files that `ern build` refuses.**
    - Commands: `ern format code.txt` rewrote a `.txt` file in place. `ern format Bad.ern` and `ern format --check d` (which lists `d/Y.ern`) accept paths that `ern build` refuses: "path component `Bad` must be lowercase".
    - Expected, per §11.6: modules "as `ern build` finds them".
    - Principle 1.
    - Fix: apply build's extension and path-shape checks.

12. **`:load` compiles a module but its dependents cannot use it.**
    - Commands: `ern shell --source-root src`, then `:load Geo.Shape` ("compiled from geo/shape.ern"), then `:load Main`.
    - Did: "compile Geo.Shape first: …/src/geo/shape.erc: no such file or directory".
    - Principle 1.
    - Fix: let `:load` of a dependent use modules already loaded in the session, or compile them from source.

13. **`:reload` says "no source has changed" when it found no source at all.**
    - Commands: `ern shell src/main.erc` (no `--source-root`), `:load Geo.Shape`, then edit `src/geo/shape.ern` and `:reload`. The `:load` reply had said ":reload compiles it again when its source has changed".
    - Did: "no source has changed", and the old code keeps running.
    - Principles 1 and 3.
    - Fix: say "Geo.Shape has no source under the source root …".

14. **A faulting top-level binding is handled three ways and reported under the wrong name.**
    - `ern shell init.erc` prints "fault: division by zero" and exits 1 before the prompt. `:load Init` reports the fault and carries on.
    - `ern run init.erc` says "Init.main faulted", although main never ran. With `--main Hello.main` it says "Hello.main faulted".
    - `ern test init.erc` says "Init.$tests faulted", an internal name.
    - Principles 1 and 3.
    - Fix: name the binding (`Init.bad:3`), and make `ern shell file` behave as `:load` does.

15. **Failures in a startup file lack the file and line that §11.2 requires.** With `:set depth x`, `:load Nope`, `:bogus`, `:b` or `1/0` in `.ernest/startup`, each is printed bare. Only compile diagnostics carry the path. The fix is to prefix every failure with `file:line:`.

16. **Shell diagnostics use absolute paths.** `:load Bad` or `:reload`, even in the directory holding `bad.ern`, prints `/tmp/…/rl/src/bad.ern:2:5`. §11.5 asks for the path relative to the working directory. Principle 1. The fix is to use build's rule.

17. **`ern doc src` leaves a stale page behind, and also does a build's work.** After removing `main.ern`, it swept `main.erc` but left `main.md`, now missing from the index. It also writes `.erc` files into the tree, which `ern doc file.ern` does not.
    - Principles 1 and 2.
    - Fix: sweep the pages `ern doc` wrote, and either write no `.erc` or say that it does.

18. **The history failure is reported twice.** With `history` unreadable (mode 000), at a pty the shell says "could not be read: permission was denied" at start and "is not kept: permission was denied" at the first input. §11.2 says once. The fix is one message.

19. **The shell cannot show the prelude.** `:browse Prelude` gives "no module Prelude is in scope", and `:doc Prelude` and `:doc Prelude.spawn` find nothing. Yet `Prelude.Local` evaluates, and `ern doc` lists Prelude first in its index. Principle 1. The fix is to make Prelude browsable and documented in the shell.

20. **A corrupt `.erc` gets a host message.** `ern run junk.erc` prints `junk.erc: <<"junk\n">>: Not a BEAM file`. The fix is "junk.erc is not a compiled Ernest module".

#### Clarity

21. **Configuration options that do nothing yet say nothing.** `ern run` and `ern test` accept `--config-dir` (even `/nonexistent`) and a broken `ernest.conf`, and ignore them. `spawn(Peer("foo"))` says "peer unreachable" whatever the cause. `--help` and `ern(1)` do not say the configuration is not read yet; only guide §8 does. Fix: say it in `--help`, or refuse the option until MVP 3.0.

22. **The working directory's `./.ernest/startup` runs silently.** Mine bound `secret` and wrote `touched-by-startup.txt`, and the banner said nothing. Principle 3. Fix: print a line naming each startup file run.

23. **`ern build` in directory mode says nothing** about what it compiled, skipped or removed. The fix is a line per removal at least.

24. **`ern test` is silent when there is nothing to report.** A module with no tests prints nothing and exits 0. Two tests named "adds two" are accepted. Fix: print "no tests"; refuse duplicate names.

25. **`:set timing on` times the compile as well as the run.** `1` takes 13–15 ms, and the first input 264 ms. Fix: time the run alone, or say "compile and run".

26. **Every shell spawn site is `input:1`.** Two inputs' processes cannot be told apart in `:processes` or in fault lines, although types are numbered `$Input2`. Fix: number the inputs (`input 2:1`).

27. **Type names are qualified inconsistently.**
    - `:browse Geo.Shape` prints `type Geo.Shape.Shape`, then `area : (Shape) -> Int`.
    - `:browse Fs` prints `List(Entry)` beside `Io.Error`.
    - Values print as `Circle(r = 1) : Geo.Shape.Shape`, which cannot be pasted back.
    - Fix: print as the session writes the names.

28. **Terms and formats differ between messages.**
    - `:help` and `:output` say "the tail"; the report and guide say "live region".
    - `ern run` prints `killed`, the shell `Killed`. Only `killed` lacks the timestamp and site when stderr is a file.
    - `:help` mentions GHCi.

29. **Piped code in the layout `ern format` writes does not parse.** The line-mode shell reads one line per input, and the formatter puts every function body on the next line. Fix: accept an unfinished input across lines in line mode too.

30. **Two messages leave out what the user needs.** `ern build ../x.ern` gives "not under the source root <cwd>" with no hint to use `--source-root`. "path component `Y` must be lowercase" does not name the file.

31. **Usage text disagrees with `ern(1)`.** The man page's synopses leave out `--emit-erl`, `--short-errors` and `--man`, and it has no SYNOPSIS, OPTIONS or EXIT STATUS sections. `ern config --help` has a trailing space in its usage line.

32. **The shell's exit status and streams are unspecified.** When not at a terminal, the shell writes programs' stderr to its stdout, and exits 0 whatever failed. The report is silent on both.

33. **`ern config` writes JSON that is hard to edit.** It writes one line with keys in alphabetical order and the PEM escaped. Appendix C, which the user is told to edit, is pretty-printed in another key order.

34. **Smaller shell and diagnostic oddities.**
    - `:type let a = 1` is accepted, though `:type` takes an expression.
    - `:doc it` finds nothing, while `:doc k` works for a `let`.
    - A diagnostic excerpt jumps from line 4 to line 6 with no elision mark (`bad2.ern`).

### X, the diagnostics

Review of test/diagnostics.md (197 entries) against report §11.5. I read only the catalogue and the report, and edited nothing.

I found problems with 57 entries: 46 are defects (the message misleads or breaks §11.5) and 11 are clarity matters. The other **140 entries are clear**: having made that mistake, I would know the fix. Columns below are 1-based and I counted them from the programs as printed.

#### Defects, most serious first

1. **"`==` reached through a function's type variable (§3.10)"**
   - Message: `3:18: () -> Int does not support equality (it contains a function or an address), but it is compared here`, underlining `same`.
   - Problem: this breaks §11.5's rule that an error at a rejected call site "names the parameter and the origin of its restriction". It names neither `same`'s parameter nor the `a == b` on line 1. "Compared here" also points at the call, which compares nothing.
   - Fix: `3:23: same compares its parameter a with ==, and () -> Int, a function, has no equality`, underlining the argument, with `-` under `a == b` on line 1 (or show `same : (a=, a=) -> Bool`).

2. **"A reply passed where a function discards its argument (§3.9, §6.6)"**
   - Message: `3:39: a reply-carrying value, Reply(Int), passed where the function duplicates or discards its argument`, underlining `drop`.
   - Problem: the same §11.5 rule is broken. It says "the function" instead of `drop`, gives neither the parameter nor where it is discarded, and underlines the callee instead of `r`.
   - Fix: `3:44: drop discards its parameter x, so it cannot take r, a Reply(Int)`, with `-` on line 1's body (or show `drop : (a!) -> Unit`).

3. **"A recursive call at another type than the definition's (§4.5)"** and **"A recursive use at another type than the `let`'s (§4.6)"**
   - Message: `1:1: recursive use does not match the definition: expected (Int) -> Int, found (Bool) -> Int`, underlining the whole declaration.
   - Problem 1: it is at the wrong position. §11.5 puts a mismatch at the innermost expression, here the argument `1`.
   - Problem 2: expected and found are reversed against the message's own wording. The definition is `(Bool) -> Int`, yet it is printed as "found".
   - Problem 3: there is no label.
   - Fix (fn form): `1:23: the argument does not fit f: expected Bool, found Int`, with `-` under the `x` of `if x` (col 14), "x is a Bool here".
   - The let form's second error, `the initializer of f depends on itself`, has no help. Reading the first error, one would fix the argument and still be refused.
   - Fix (let form): add `= help: a recursive function is declared with fn f(x) = ...` and `-` under the inner `f` (col 27).

4. **"A `let` pattern that does not fit the value (§4.6)"** and **"A `<-` pattern that does not fit the value inside (§5.5)"**
   - Messages: `expected #(a, b), found Int` and `expected #(Int, a), found Int`.
   - Problem: expected and found are reversed. In the `let` entry, the label marks the value ("the value has type Int"). §11.5 says the label marks what fixed the expectation, so Int is the expected type. The `match` entry does this correctly: `expected Int, found String` beside the value-matched label.
   - The `<-` entry is also at the wrong position (2:5, the `let`, rather than the pattern at 2:9) and has no label on `o`.
   - Fixes:
     - `let`: `2:9: the pattern does not fit the value: expected Int, found #(a, b)`
     - `<-`: `2:9: the pattern does not fit the value inside o: expected Int, found #(Int, a)`, with `-` under `o`.

5. **"A `compare` that returns no Ordering, used as it is declared (§4.8)"**
   - Message: `3:52: Money.compare must return an Ordering: expected Ordering, found Int`, underlining `a < b`.
   - Problem: the underlined span is a Bool, not an Int. §4.8 also says "A member of another shape is an error at its declaration", and nothing labels the `-> Int` that has to change.
   - Fix: `3:43: Money.compare must return an Ordering: expected Ordering, found Int`, underlining `Int`, with `-` under `a < b`, "`<` on Money calls Money.compare".

6. **"A character literal of two characters (§2.5)"**
   - Message: `unterminated char literal`.
   - Problem: the literal *is* terminated. The message names the wrong thing and sends the reader looking for a missing quote.
   - Fix: `1:30: a char literal holds one character; a string is written "ab"`.

7. **"A field of two types (§3.5)"**
   - Message: `3:26: the field r in every constructor: expected Int, found Float`.
   - Problem: it does not name Circle or Square, and has no label on the declaration. "Expected Int" reads as coming from the function's `-> Int`. With `-> Float` the message would be identical and baffling.
   - Fix: `3:28: Shape has no field r of one type: r is Int in Circle and Float in Square`, with `-` on line 1.

8. **"A foreign implementation of the wrong arity (§8.4)"** and **"A foreign implementation that is no `module:function/arity` (§8.4)"**
   - Problem: both are reported at 1:1 and show only line 1. The string at fault, on line 2, is neither underlined nor shown.
   - Fix: `2:5: the implementation names arity 2, and size has 1 parameter` (and likewise for the second), underlining the string.
   - The second one's example, `"ets:new/2"`, is also unrelated to the code.

9. **"A field named twice in a constructor (§3.5)"**
   - Message: `1:20: field names must be unique within a constructor`.
   - Problem: it underlines the *first* `x : Int` and does not name the field.
   - Fix: `1:29: field x is declared twice in Point`, with `-` under the first.

10. **"A type variable of an annotation used as a type (§3.9)"** and **"Two type variables of an annotation used as one (§3.9)"**
    - Problem: both are reported at 1:1 over the whole declaration, not at the body. The second shows neither variable nor any type, and §11.5 says "The message shows both whole types".
    - Fixes:
      - `1:21: the body does not have the declared return type: expected a, found Int`, with `-` under `a` at col 17.
      - `1:27: ... expected a, found b`, with `-` under `a` at col 23.

11. **Type mismatches without the §11.5 label** ("The label marks the span that fixed the expectation"):
    - **"A parameter pattern that does not fit its annotation"**: underline `#(a, b)`, with `-` under `Int`.
    - **"A field read at another type than its own"**: add `-` under `String`.
    - **"An operator whose result is used at another type"**: add `-` under `String`. The Int comes from line 3, which is never shown. The help `the types differ at String and Int` only restates the two types.
    - **"An operator member used at a type it was not declared for"**: add `-` on the declaration of `Vec.+` (line 3).
    - **"A field of the wrong type"**: add `-` under `x : Int` on line 1.
    - **"`..` from a value of another type"**: underline `5` (3:27), not the whole construction.
    - **"A block after `<-` of another sum type"**: add `-` under the return annotation `Either(String, Int)`. The message also uses `p` and `e`, which are not in the program; write `after let x <- o`.
    - **"A list pattern of two types"**: underline `"two"` (3:13) and label `1`, as the list-expression entry does.
    - **"A `::` pattern whose tail is no list of the head's type"**: underline `1` (3:14), not `:: 1`. "Expected List(a)" should be `List(Int)`.
    - **"Alternatives of two types"**: add `-` under `1`.
    - **"Alternatives that bind a variable at two types"**: add `-` under the first `x`. The help only restates the two types.

12. **A second span the message depends on, not shown** (§11.5: "any second span the message depends on, underlined with `-` and labelled"):
    - The duplicate declarations are:
      - "A function written in two clauses"
      - "A type declared twice"
      - "A constructor declared twice"
      - "A value declared twice"
      - "A local function declared twice"
      - "A variable twice in one pattern"
      - "A reply answered twice"
    - Also "A local function used before the `let` it reads".
    - Fix for each: `-` under the first occurrence ("first declared here" or "consumed here"), or under `let x`.
    - **"A field given twice"** and **"A field matched twice"** also do not name the field and underline the whole constructor.
    - Fix for those two: `field x is given twice`, underlining the second `x = ...`.

13. **Selector errors not reported at the selector** (§11.5: "reported at the selector", and §3.5 calls `f` the selector). These underline from the operand: "A field of a type that has none", "A field of a tuple", "A field the type lacks", "A field one constructor lacks", "A field of another module's abstract type". For example, `p.y` should be `3:28: Point has no field y`, underlining `y`.

14. **"A block that ends with `;` (§5.4)"**
    - Problem: the caret is on `}` (3:1), but the error, and what the help tells you to remove, is the `;`.
    - Fix: `2:6: a block ends with an expression`, underlining `;`.

15. **"`receive` in a function of mailbox Never"** and **"`receive` in a top-level initializer"**
    - Problem: these effect errors do not name `f` or `n`, and the first does not label `with Never`. Its pure-function sibling does both, as §11.5 asks.
    - Fixes:
      - `f is declared with Never and cannot receive`, with `-` under `with Never`.
      - `the initializer of n runs with mailbox Never ...`

16. **Short spans**
    - "A function's name where a pattern's constructor stands" underlines `List` only; underline `List.map`.
    - "A qualified type that ends in a lowercase name" underlines `List` while the fault is `a`; underline `List.a` and add `help: type arguments are written List(a)`.

17. **"A unit beyond 256"**
    - Problem: "on this runtime" makes a language rule (§5.11 "`unit` is 1 to 256") sound like a limit of this machine.
    - Fix: `unit is 1 to 256`, underlining `unit(300)`.

#### Clarity (the message is correct, but I would not know the fix)

1. **"Parenthesized types that are no function type"**: `expected -> after a parameter list instead of )`. Nothing says tuples are `#(...)`. Add `help: a tuple type is written #(Int, Int)`.
2. **"`<-` on an Optional that would contain itself"** and **"`<-` on an Either that would contain itself"**: the line that makes `o` and `y` one type (line 3's branches) is not shown. Add `-` under `Some(o)` or `Right(o)` on line 3: "o and y are given one type here".
3. **"A function applied to itself"**: `not a function: a type that would contain itself` — the `not a function` prefix is wrong, since g is called. Use `g is applied to itself, which needs a type that contains itself (a against (a) -> b)`.
4. **"Empty parentheses where a type stands"**: add `help: the type of no value is Unit`.
5. **"Empty parentheses after a nullary constructor"**: the first line, `a constructor's fields are listed inside the parentheses`, says to add fields, the opposite of the help. Under `--short-errors` only that first line prints. Use `1:31: empty parentheses after None`, with `help: a nullary constructor is written without them: None`.
6. **"A refutable parameter pattern"**: this has no help, unlike its `let` twin. Add `help: take the value whole and match on it in the body`.
7. **"A reply captured by a local function"**: it states the fact, not the rule. Add `help: a local fn cannot capture a reply; pass r to g as a parameter`.
8. **"A reply answered on one path only"**: it does not say which path. Use `1:81: r is not consumed on this path`, underlining the `else`'s `Unit`, with `-` under `answer(r, 1)`.
9. **"An `if` without its `else`"**: the caret sits on an empty line 2 and the `if` is not marked. In a real file it would land on the next declaration. Use `1:36: if needs an else`, with `-` under `if` (col 25).
10. **"A lowercase name where a type's name stands"**: add `help: a type name begins with an uppercase letter: Point`.

"A field one constructor lacks" also belongs here, alongside its position fault in defect 13. `Shape has no field r in every constructor` reads as "no constructor has r". Use `not every constructor of Shape has the field r: Dot has none`.

#### Not covered by any entry

No entry shows three things §11.5 requires:
- the label with the prelude's qualified name for a shadowed prelude name (`Prelude.Local`);
- the `a=` / `a!` restriction printing at a rejected call site (the two entries that should show it, defects 1 and 2, don't);
- an effect error on a pure `let` or guard.

### S, security

R8 security reader: I found 11 real exposures and 8 hardening points. Each finding marked "verified" was reproduced with bin/ern under scratchpad/readers/r8/ (t1 to t16). Nothing in the repository was edited.

#### Real exposures, most serious first

**1. `ern shell` runs code from the working directory's `.ernest/startup`.**
- Where: erl/cli/src/ern_cli.erl:1058 `Config = proplists:get_value(config_dir, Opts, ".ernest")` and :1063 `Home ++ [filename:join(Config, "startup")]`. Report §11.2 specifies it.
- What reaches what: a directory's contents (a cloned repo, an unpacked tarball) reach arbitrary host commands.
- How (verified, t4): `.ernest/startup` holding `let _ = Os.run(Os.Command(program = "sh", arguments = ["-c", "id > pwned.txt"], input = String.toUtf8("")), 5000)`, then `ern shell` in that directory writes pwned.txt.
- Side effect: run from `$HOME`, both startup paths are the same file, so every input runs twice (verified, t15).
- Fix: read the node's startup only under an explicit `--config-dir` (or default the configuration directory away from the cwd), and drop the duplicate path. This is a report change.

**2. The working directory is on the host's code path, ahead of the load path.**
- Where: bin/ern:35 (`erl ... -pa ...`, interactive mode, which keeps `"."` last on the path) and ern_cli.erl:1042 `ok = code:add_pathsz(Roots)`, which appends the load path after `"."`.
- What reaches what: a `.beam` in the cwd reaches any Erlang module a `foreign fn` names that OTP lacks. This contradicts §11.2 ("the host's own or a .beam … in a directory of the load path").
- How (verified, t3): the program's `r8shim.beam` sits in its module root and says "good". From a cwd holding another `r8shim.beam`, `ern run ../app/main.erc` prints "EVIL, from the working directory".
- Fix: `code:del_path(".")` first thing in `ern_cli:start/0`.

**3. One `Fs.read`/`write`/`append` of a FIFO blocks every file operation in the node, forever.**
- Where: erl/runtime/src/ern_fs.erl:33 `file:read_file(text(Path))`, and :35 and :37 likewise. Non-raw `file:` calls go through OTP's single `file_server_2`.
- What reaches what: a path from the network, or a FIFO a local user leaves in a directory the program lists, stops all file I/O.
- How (verified, t8): after one `Fs.read(Path("t8/fifo"), 200)` times out, `Fs.read` of a plain file with 3000 ms answers `Left(Timeout)`. In Erlang, `read_file`, `read_file_info` and `list_dir_all` all stall, while `read_file(_, [raw])` still works. The workers never end.
- Fix: use raw file operations in the ern_fs workers, and refuse a file that is not a regular file before opening it.

**4. `Tcp.listen`/`Tcp.connect` hang forever on a bad port or host, whatever `ms` says.**
- Where: erl/runtime/src/ern_tcp.erl:25 `erlang:spawn(fun() -> listen(...))`, :52 `gen_tcp:listen(Port, Options)`, :66 `gen_tcp:connect(unicode:characters_to_list(Host), Port, ...)`.
- What happens: gen_tcp raises instead of returning an error, the worker dies silently, and the reply never comes. For connect, the source counted by `counted/1` never ends, so deadlock detection is disabled for the whole run.
- How (verified, t2): `Tcp.listen(70000)`, `Tcp.connect("localhost", 70000, 1000)` and `Tcp.connect("local\u{0}host", 80, 1000)` each hang (timeout 10 s kills them). A non-ASCII (IDN) host name makes gen_tcp raise the same way (tested directly in erl, not through Ernest).
- Fix: wrap the gen_tcp calls in try/catch that answers `Left(Other(...))` and ends the source. Reject a port outside 0..65535 and a host holding U+0000 or non-ASCII.

**5. `Tcp.listen` binds every interface, and there is no way to bind loopback.**
- Where: ern_tcp.erl:51 `Options = [binary, {active, false}, {reuseaddr, true}, {packet, raw}]` has no `{ip, _}`. E.18 says "There are no options".
- What reaches what: any listening program, including examples/webserver.ern on 8080, is open to the LAN.
- How (verified, t1): `ss -ltn` shows `0.0.0.0:44139`.
- Fix: give `listen` an address, or default to 127.0.0.1. This is an E.18 change.

**6. Fs follows symlinks everywhere and cannot see one.**
- Where: ern_fs.erl:99 `file:read_file_info(Name, ...)` (for list and stat) and :50 `filelib:is_dir(Name)` (for remove).
- What happens (verified, t9):
  - A link to `/etc` is listed as `dir`.
  - `Fs.remove` of that link answers `enotdir`.
  - One dangling link makes `Fs.list` of the whole directory answer `Left(NotFound)`.
- Consequence: a recursive walker or deleter over a directory another user can write descends out of the tree and deletes the link target's files. A single dangling link blocks listing entirely.
- Fix: use `read_link_info` in list, stat and remove, and add `isLink` to `Fs.Entry`. This is an E.17 change.

**7. `Path` gives no way to confine a path from the network.**
- Where: stdlib/path.ern:36-37 `if isAbsolute(under) then under else Path(written(split(p) <> split(under)))`.
- What happens (verified, t1): `Path.join(Path("/srv/www"), Path("/etc/passwd"))` is `/etc/passwd`, and `Path.join(Path("/srv/www"), Path("../../etc/passwd"))` is `/srv/www/../../etc/passwd`. E.14 has no normalize.
- In the examples: examples/filesync.ern:103-104 trusts a comment ("p is the peer's bare name") with `let here = Path.join(dir, p)`. A peer's `Put(path = Path("/home/u/.bashrc"), ...)` goes straight to `Fs.write`.
- Fix: in filesync, accept only `Path.split(p) == [Path.name(p)]` with the name not `.` or `..`. Add a normalize or within function to E.14.

**8. The shell history is world-readable.**
- Where: shell/shell/history.ern:65 `Fs.append(path, ...)` and :72 `Fs.makeDir(dir, wait)`, which reach ern_fs.erl:37 and :47 with the umask's default modes.
- What reaches what: every typed input reaches other local users.
- How (verified, t5, umask 022): `~/.ernest` is `drwxr-xr-x`, and `history` is `-rw-r--r--` and holds `let secret = "hunter2"`.
- Fix: this cannot be done in Ernest today because E.17 has no file mode or exclusive create. That gap goes to E.17 and the plan; the history should then be 0600 in a 0700 directory.

**9. `ern config` has a race that can leak the private key.**
- Where: ern_cli.erl:1323 `ok = filelib:ensure_path(Conf)` (the directory gets 0755), :1370 `ok = file:write_file(New, <<>>)` (the file gets 0644), then :1378 `file:change_mode(New, Kept)`.
- What happens: between creating `.private-key.pem.new` and the chmod, a local user who opens it (inotify makes the window easy to hit) keeps a descriptor. That descriptor reads the key once it is written, and the later chmod does not revoke it.
- A second gap: `is_file` (:1312) then `ensure_path` accepts a directory an attacker creates in between.
- Fix: create the leaf with `file:make_dir` (which fails if it exists), `change_mode(Conf, 8#700)` before writing any file, and create the key file exclusively.

**10. Control characters in fault causes, doc text and printed values reach the terminal and the log.**
- Where:
  - ern_cli.erl:990 `iolist_to_binary([Time, Site, Faulted, Cause, "\n", Trace])`
  - shell/shell.ern:429, :442 and :531 (`"fault: " <> ...`)
  - ern_show.erl:158, which escapes only `C < 16#20; C =:= 16#7F`
  - doc comments pass through unchanged
- How (verified, t13 and t14):
  - A fault cause holding `\u{1b}]52;c;…\u{7}` (an OSC 52 clipboard write) is written raw by the shell.
  - A cause holding `"\n2026-01-01T00:00:00.000Z Admin.main faulted: forged"` prints as a separate, well-formed fault line under `ern run`.
  - A `///` doc containing ESC]0;…BEL comes out raw from both `ern doc` and `:doc`.
  - The string `"x\u{9b}2J"` (the one-character C1 control sequence introducer, U+009B) prints raw.
- Fix: escape C0 and C1 controls (and newlines) in fault lines, in the shell's fault and doc text, and in the value printer's U+0080..U+009F range. The report is silent on control characters in source (§2.1), so it needs a sentence or a lexer refusal.

**11. Decoding the history takes quadratic time, so a large paste slows every later shell start.**
- Where: shell/shell/history.ern:88-103 (`undo`, `done <> head`, and `from(rest, n)` re-slicing the rest for each character).
- How (verified, t12, through `Shell.History.read`): 2k chars take 0.55 s, 32k take 3.6 s and 64k take 16.2 s. Pasting a large blob once slows every later start.
- Fix: decode in one pass, for example by splitting on `\\` and replacing `n` pieces, instead of per-character slicing.

#### Hardening that would be nice (not exposures today)

- **Foreign boundary (ern_descriptor.erl:26 `desc({tvar, _}, ...) -> {any, ...}`, :48 Foreign gives `any`).**
  - `foreign fn cast(x : Foreign) -> a = "ern_foreign:from/1"` compiles and is an unchecked cast (verified, t10: it faults later inside `string:length`).
  - Arguments that foreign code passes into an Ernest function value are never checked; only returns and messages are.
  - §8.4 is silent on both. Refuse a result type variable not bound by a parameter, and state the callback-argument case.
- **Atom creation.** `Erl.atom` (stdlib/erl.ern:23, `erlang:binary_to_atom/1`) exhausts the atom table if fed received text. It is documented; `binary_to_existing_atom` would suit most shims.
- **stty from PATH.** `os:find_executable("stty")` (ern_tty.erl:274) runs whatever `stty` PATH finds at every terminal start. Use `/bin/stty` or `/usr/bin/stty`.
- **Host flags from the environment.** bin/ern lets `ERL_AFLAGS`, `ERL_FLAGS`, `ERL_ZFLAGS` and `ERL_LIBS` reach `erl` (for example `-eval`). This is the same trust as the environment, but worth clearing for service use.
- **Relative HOME.** An empty or relative `HOME` makes the history `.ernest/history` under the cwd (history.ern:21-23; found by reading, not run). Require an absolute HOME.
- **Unbounded reads.** `Io.readLine` (ern_rt.erl `line/3`) and `Fs.read` have no size bound, so a line without a newline on stdin, or a huge file, grows memory without limit.
- **Key in the working tree.** The private key defaults into `./.ernest` in the working tree, so it can be committed (git does not keep 0600). It matters once peers exist; today nothing reads the key.
- **Dangling link at `--config-dir`.** `ern config --config-dir <dangling link>` ends with "internal error", status 70, instead of "exists" (verified, t6).

#### Checked and found sound

- ern_exec.c: no shell anywhere, argv passed as given, and U+0000 refused (ern_os.erl:43). The child inherits no descriptors of the node (verified, t7). Output is framed by length, so what a program writes cannot forge a frame.
- Os.arguments and the environment are checked as UTF-8.
- ern_boundary's checks on strings, chars and floats.
- Fs refuses U+0000.
- The only fixed `os:cmd` (ern_signals.erl:58) is safe.

#### Report conformance

- Sections applied: §8.4, §11.2, §11.3, Appendix C, E.14, E.17, E.18, E.23.
- Where the report is silent:
  - control characters in source (§2.1)
  - arguments foreign code passes to Ernest callbacks (§8.4)
  - Tcp port range and host validation (E.18)
  - the listen address (E.18)
  - symlinks in Fs (E.17)
  - file modes (E.17)
- Finding 2 is a deviation from §11.2.
- Deliberate omissions: none. No code was changed.
