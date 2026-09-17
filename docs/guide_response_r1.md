# Response to guide review

## Structural change (UG12)

The guide is reorganized as a seven-stage crash course, each stage ending with a prediction exercise:

1. **Run a program** — hello-world, `ernc`/`ern` beside it, config prerequisite noted.
2. **Compute with immutable values** — bindings, scalars, sums, wrappers, named-field records with `..` update, lists, tuples, maps/sets, patterns and irrefutability, guards, `if`, `<-`, pipe.
3. **Pass behavior** — arity, lambdas and closures, inference boundaries, pure vs mailbox-effect, higher-order and effect polymorphism, spawn's pure-callback restriction.
4. **Run a protocol** — counter with message types, reply ownership, six consumption forms, selective receive with `after`, four `Address.call` rules, and the explicit code-replacement (`Upgrade`) demonstration.
5. **Manage process lifetime** — ping-pong with monitor, `monitor`/`Down`, `kill`, `via`, one-shot clock with re-arming.
6. **Organize code** — modules and namespaces; abstract types with signature-listed access, plus rejected/accepted helper examples.
7. **Cross boundaries** — `remote`/`parallelRemote`, code shipping consequences, foreign types and functions, node-local values, the shim pattern (with correct `ok`/`error` decoding under the §8.4 ABI), bitstrings with alignment rules and precondition.

Followed by FAQ (six questions, all rewritten to be concrete) and reading further.

Word count dropped from ~9,800 to ~5,600 while adding selective receive, higher-order effect polymorphism with `apply`, the `Upgrade` example, and the coverage gaps you flagged.

## Correctness fixes (UG01–UG10)

- **UG01** — Removed the false "reveals whether a call can send/receive/fault" claim. §3.4 states pure functions cannot perform process operations but can still fault or fail to terminate; the error model is introduced alongside (values, protocol messages, faults + monitoring). §5.2 notes `main`-fault as the exception to "one process's fault doesn't affect another". §1.2 no longer claims all external effect requires messaging — `foreign fn` is the other explicit boundary.

- **UG02** — `Reply(a)` is no longer grouped with wrapper types like `UserId(Int)`. Constructor-as-function rule restated: only single-positional constructors are function values. §4.2 lists all six consumption forms (constructor placement and function return added), extends the discipline to reply-carrying types, states pattern-match ownership transfer and nullary-case discharge, and shows the `twice` counter-example as an intentional error.

- **UG03** — `hypotenuse` → `hypotenuseSquared`. `Point(x, y)` → `Rectangle(width = w, height = h)` with named fields. `let (e, rest) <-` → `let #(e, rest) <-`. Tuple and single-constructor irrefutability made recursive. Pattern rules added: identifiers are fresh binders (comparison via guard), no repeated names within one pattern, guards are pure `Bool` (a faulting guard faults the process).

- **UG04** — §3.3 gained inference boundaries: `twice(n)` needs an annotation; block `let` is monomorphic; arity is strict; local-fn use before capture initialization is rejected. §3.5 covers effect polymorphism with `apply`, distinguishing empty-capable `e` from process-constrained `m` (like ping's non-empty polymorphic mailbox). §3.6 states the spawn pure-callback restriction. §2.8 includes the parenthesized-lambda-after-pipe rule.

- **UG05** — §4.3 introduces selective receive with `after` syntax, contrasted with exhaustive `match`. §4.4 states four `Address.call` rules: deadline starts at invocation, `None` does not cancel recipient work, late answers silently discarded with no tiebreak, private reply mechanism separate from declared mailbox (explains why `Address.call` works in a `Never` mailbox).

- **UG06** — Counter output is now stated deterministically as `count is 8`. Ping-pong stdout output labelled as *one possible successful trace*, with cross-sender scheduling explained. Clock example fixed as one-shot with re-arming shown explicitly. `kill` described through termination reason plus monitor notification, no "immediately" implication.

- **UG07** — §6.2 abstract-type access is centered on the signature. Rejected `Stack.size` (unlisted, mentions constructor) and accepted `Stack.isEmpty` (uses public operations) examples added. Representation-change note qualified to require preserving each operation's observable contract.

- **UG08** — §7.1 restated `remote`'s pure-callback reason as "compute-and-return by design". "Also pure" removed for `parallelRemote`. §7.2 covers code-shipping consequences: `NoRemotePeer` vs `PeerLost` (latter includes resolution failure and callback fault), `Sys.*` peer resolution, captured-address values retained, top-level bindings peer-local, remote-send async fault, foreign compat requirement.

- **UG09** — §7.3 "wrong message from a foreign process" clarified as destination's mailbox type. Foreign fault delivered to the receiving Ernest process on first observation. §7.5 shim pattern shows why `{ok, V}` doesn't auto-adapt to `Either` under the new §8.4 ABI — raw return decoded with `match`, or Erlang-side helper produces the quoted-atom form. `Sys.fs` and ETS marked as example-specific dependencies.

- **UG10** — §7.6 specifiers now include `unit(N)`. Alignment rules stated: total 8-bit alignment; `bits`/`bytes` segments binding `Bytes` must be byte-multiple; sub-octet fields use `int`. Compile-time-constant violations are compile-time errors; dynamic violations fault in construction, fail matching in patterns. `size(Expr)` purity and fault propagation stated. `frame`/`parseFrame` precondition (`len` = body byte count) explained with what `parseFrame(frame(1, <<65, 66>>))` actually returns. "Native speed" replaced with "compiles to BEAM's bit syntax".

## UG11 Upgrade demonstration

Added to §4.6. The counter's declaration is explicitly extended with an `Upgrade` constructor carrying `migrate : (Int) -> Int` and `next : (Int) -> Void with CounterMsg`. The receive clause `Upgrade(migrate = m, next = k) -> k(m(n))` is a tail call into the new loop with migrated state. The note "this replaces both the type and the function above" makes the extension explicit.

## Editorial repairs

- "That's the whole vocabulary" → "these are the two organizing ideas".
- `:` for types / `=` for values distinction qualified with function result types using `->`.
- FAQ's `x -> ...` currying claim replaced with the concrete "makes arity visible at the definition site" reasoning.
- "under ten pages" and unverified implementation-duration claims removed.
- `via`'s arguments listed in signature order (converter, target).
- `todo` explained at first use.
- "Remote spawning, which we won't cover here" replaced with an actual §7 pointer.

## Related report edit (UG09 inherited inconsistency)

Appendix D's intro claimed Erlang's `{ok, V} | {error, R}` auto-maps to an Ernest sum with lowercase-atom tags, contradicting §8.4's quoted-atom rule. Rewrote the paragraph: `Bool` and `List(#(k, v))` still line up without adaptation, but shims that want `Either` from `{ok, _} | {error, _}` APIs must decode with a `match` or use an Erlang-side helper. The `ets` calls in the appendix don't use that convention, so no adapter is needed there.

## Coverage-table gaps

Every row of the coverage table you listed now has a concrete example or an explicit rule in the guide, including:

- Persistent `..` update (§2.4).
- Blocks with sequential `let` and local-function capture initialization (§2.2, §3.3).
- Function-values-before-callbacks, closures, arity, explicit adaptation (§3.1–3.2).
- Recursive irrefutability, fresh binders, pure guards (§2.6).
- `Either(e, a)` definition and `<-` single-block-type constraint (§2.7).
- Selective receive with `after` (§4.3).
- Explicit code replacement (§4.6).
- Two-file module example and abstract-type access rule (§6).
- Build/run beside hello-world (§1).

## Cost

Guide dropped 40 % in word count while adding selective receive, higher-order effects, the `Upgrade` example, and every coverage-table row you flagged. No new keyword, syntax, or language mechanism. One paragraph in the report (Appendix D intro).

Full rationale, rejected alternatives, and reorganization decisions: `decisions.md` (entry dated 2026-09-15 titled "Guide Rewrite: Crash-Course Structure").
