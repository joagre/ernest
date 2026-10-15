# Findings: section 8's items 1, 2, 3 and 6

Read on 2026-10-14 against `0b287e8d` and the proposal's edit of that day, which made item 7 item 6. A probe is a scratch program given to `ern build` outside the repository.

## Item 1. What the checks have caught

**(a) Tests written to show a rule refuses.** The obligation (§6.6 and the not-reply-carrying restriction): 20 entries of `test/diagnostics.md` (line 2955, lines 3888 to 4224); about 49 refusals in 22 test functions of `erl/typer/test/ern_typecheck_tests.erl`, counted by message; `reply_programs_test_` in `test/ern_typed_programs_tests.erl`, 80 programs a run, each changed four times; 3 rejected programs in the guide (guide/language.md lines 73, 835, 1780), 1 in the report (report/language.md line 754), and a comment in `examples/typed_channels.ern` (line 31). Purity: 5 catalog entries (lines 1277, 1877, 3208, 3718, 4670); about 13 refusals in 11 test functions, `guards_are_pure_test` and `effect_placement_test` among them; 2 guide programs (lines 94, 272). The catalog's three on `receive` (lines 3736, 3755, 3774) stay under section 3.

**(b) A real program where a check caught someone's mistake: none found.** Searched: `docs/decisions.md` (reply, obligation, linear, pure, guard, caught, forgot, unanswered), the history of `docs/language_feedback.md`, and 2,031 commit messages. None records an example, the shell, a library or a test program refused for a dropped or doubled reply, or for an action in a function declared pure. A neighboring rule reads the same: the commit of §5.4's discard rule says "Nothing in the repository dropped a value this way". A refusal met while writing and fixed before a commit leaves no record.

**(c) Defects in the checker.** The obligation, 17: the ten holes the soundness argument found (the log's *The Type System Argued*, 2026-10-04; `receive_returns_test`, `restriction_reaches_values_test`, `skipped_path_test`, `hidden_name_test`, `selection_and_update_test`, `top_level_holds_no_reply_test`); five more holes in regression tests, `reply_through_bindings_test`, `reply_in_a_list_field_test`, `foreign_no_reply_test`, `reply_in_a_list_test`, `own_spawn_is_no_spawn_test`; and two wrong refusals, `reply_carrying_by_the_fields_test` and `peer_spawn_reply_test`. The shell's prompt dropped a reply too (§5.4's commit). Effects, 8: five wrong behaviors (`lone_effect_variable_test`, `phantom_type_argument_test`, `restarting_is_process_only_test`, the log's entries of 2026-09-15 and 2026-09-26 on effect variables) and three wrong diagnostics (`effect_mismatch_direction_test`, the two `effect_origin_` tests).

**(d) Correct programs the obligation refused:** the guide's counter that faults on a negative amount (feedback item 60, in the file's history), and three shapes the 2026-10-04 entry names.

**Judgment.** (b) is empty in the record: 25 recorded defects of the rules, no recorded catch in real code.

## Item 2. Three programs side by side

Files: `queue_today.ern` and `queue_after.ern`, `supervisor_today.ern` and `supervisor_after.ern`, `gather_after.ern` and `main_after.ern` beside the existing pair. The `_today` copies build and run with `ern build` as the guide shows.

| Pair | Code lines | Section 2 | Section 3 |
|---|---|---|---|
| queue | 37 | 0 | 3: `queueing`, `main` take `receiving`; `take` loses `with m` |
| supervisor | 27 | 0 | 3: `count` takes `receiving`; `add`, `main` lose theirs |
| gather and main | 33 + 5 | 0 | 4: `run`, `gather` take `receiving`; `gathered`, `main` lose theirs. `gather`'s line passes 100 columns and becomes three; `main` names `GatherAfter`, as the file's name forces |

Section 2 changes no code: the queue already holds its replies in a list (guide line 918). It changes the sentence at line 956.

**Better.** `take`, `add`, `gathered` read as ML and Erlang read, `take : (Address(QueueMsg)) -> Int`, and a `main` that only acts loses `with Never`. `gathered`'s `f : (Int) -> a` takes a compute under section 3, and today does not: a probe passing a `with m` function is refused, "a function that runs in a process where a pure one is needed". Today's fix, `with e` on `f` in `gathered` and `run`, compiles.

**Worse.** `take` waits for ever, and `gathered` spawns a process per number and waits; neither type says so, and a guard may call both. `receiving` is five characters longer than `with`, and one signature splits.

**Undecided.** Whether `gathered`'s `f` is `(Int) -> a receiving e`; it runs in a helper. The lambdas stay: `Take` and `Add` have named fields, so section 2's `Address.call(counter, Get, 1000)` cannot be written for them; nor is the form section 2's, since `gather_today.ern` line 10 writes it today. An unannotated service binding waits on item 3's point 4.

## Item 3. The signatures under section 3

**Method.** The standard library and libraries by the pages `ern doc` writes from `main`, the same counts as `man/stdlib/`; the shell and examples by every top-level `fn` and `foreign fn` of their sources. A function receives where its body has `receive`, `self()` or a wrap-taker outside what a spawn or compute runs, directly or through its callees, or where its own effect variable stands in a value position.

| | Functions | `with` | Receives itself | Callback's variable | Parameter or result type only | `self()` for identity only | Timed wait only | Loses all |
|---|---|---|---|---|---|---|---|---|
| Standard library, prelude in | 359 | 135 | 9 | 56 | 7 | 5 | 0 | 58 |
| `libs/`, exported | 28 | 15 | 0 | 0 | 0 | 1 | 1 | 13 |
| `shell/`, all | 281 | 89 | 23 | 0 | 0 | 0 | 0 | 66 |
| `shell/`, exported | 44 | 5 | 1 | 0 | 0 | 0 | 0 | 4 |
| `examples/`, all | 114 | 53 | 26 | 0 | 0 | 5 | 0 | 22 |
| `examples/`, exported | 14 | 14 | 6 | 0 | 0 | 2 | 0 | 6 |

**The standard library's that keep `receiving`.** Receiving themselves: `self`, `monitor`, `spawnMonitored`, `Clock.alarm`, `Clock.alarmAt`, `Os.termination`, `Process.faults`, `Terminal.subscribe`, `Peer.spawnMonitored`. In a parameter's or result's type only: `spawn`, `restarting`, `Peer.spawn`, `Peer.compute`, `Peer.computeAt`, `Supervisor.group`, `Supervisor.child`. Through a callback: `map`, `filter`, `fold`, `forEach`, `find`, `sort` and their kind in `List` 15, `Map` 10, `OrderedMap` 10, `Set` 8, `OrderedSet` 8, `Either` 3, `Optional` 2. By `Process.fromAddress(self())` alone: `Tcp.listen`, `Tcp.accept`, `Tcp.connect`, `Os.start`, and `Os.run` through it (`stdlib/tcp.ern` lines 154, 208, 224; `stdlib/os.ern` line 296).

**Process-only.** No mailbox type needs it: a function that takes from or delivers into its mailbox names the type in a value position, a wrap's `-> m` or `Address(m)`, which §3.9 already keeps from pure. Four places need it, or a rule the proposal does not state:

1. **A timed wait.** `Utilization.schedulers` (`libs/utilization/utilization.ern` line 63) waits in its caller by `receive { after ... }`, its `m` after `with` alone; today that wait is process-only (`effect_placement_test`). If a timed wait receives, the restriction survives; if not, a guard may wait.
2. **`self()` for identity**: the five above, `Proxy.start` (`libs/proxy/proxy.ern` line 71), and through them the mains of `shout.ern` and `web_server.ern`. Their variable stands after `receiving` alone, so the mark means something only with the restriction. Without it, `self()` must mark only where its address escapes, or the caller's `Process` needs a name of its own.
3. **`restarting` and `Supervisor.child`**, process-only today because a restart empties the mailbox (`restarting_is_process_only_test`). Without the restriction a pure `f` makes a pure result.
4. **§3.9's generalization**: no top-level `let` "whose initializer calls a process-only function" is generalized. Probe: `let shared = spawn(fn() = cell(None))` is refused today, "the type of shared is not determined (Address(CellMsg(a!)))". Generalized, a `String` put and an `Int` read of one cell type-check, the hole `effectful_initializer_test` guards. With no action setting an effect the rule needs ML's value restriction, which a block `let` has, or an unprinted flag, process-only by another name. *What stays sound* does not name it.

So §3.9 keeps one restriction, equality, only if all four are decided otherwise.

**Two numbers more.** Section 2's "89 of 517" is not reproduced: the pages give 111 of 359 with `!`, and 8 of 28 in the libraries. §3.11 refuses `Code.running` of a pure function (catalog line 4670), which under section 3 a worker that only sends is.

## Item 6. The guide against section 7

Lines are guide/language.md's. Its code blocks write `with` on 109 lines, 33 in chapters 0 to 4.

**Wrong or imprecise in section 7.**

1. The `send` example (L65) and *Work through a process* (L92) are in the guide's §0, not the guide's §1.
2. "one that only sends ... `with m`" is in the guide's §1.1 (L165), not the guide's §2.
3. The dropped-reply exercise is the guide's §6.7(b) (L1778 to L1794). The guide's §4.8(b) (L1173) is a reply answered twice, whose `answer(reply, 0)` compiles under section 2. Both answers in the guide's §13 change (L2930, L2934).
4. `Address.call(counter, Get, 1000)` needs `Get(Reply(Int))`; the guide declares `Get(reply : Reply(Int))` seven times (L43, L74, L799, L836, L1014, L1056, L1158), and a named constructor is no function (L373).
5. Four `:type` consoles carry a mark (L902, L1233, L1235, L1304) and five console lines quote one; section 7 names neither the 90 source lines nor the 28 `main() : Unit with Never`.
6. The prediction that flips is the guide's §1.4: (b) compiles under section 3 (L272, answer L2924).
7. `guide_passage.md`'s "does not wait on sections 2 and 3" is false today for the guide's §8.1 sentence it adds (item 2's probe).

**Changes section 7 does not mention.**

- The guide's §0: "A pure function ... says so in its type" (L36); *A request left unanswered* compiles (L71 to L90), so with the area example "Four follow" (L38) becomes two; `with` among the names taught (L69); *Checked replies* and *Purity in the type* leave *What Ernest adds* (L132, L133), with `README.md` lines 14 and 15 (`what_ernest_adds_test`).
- The guide's §1.1: the paragraph on `with Never` (L163); `Io.debug` "cannot hide in a pure function", `Io.show` "is pure" (L169).
- The guide's §2.2: `with` a reserved word (L310). The guide's §2.6: "A guard is a pure `Bool` expression" (L527). The guide's §2.9: "The function that makes the message is pure" (L590), and the `m+` half of *Marks in a printed type* (L594).
- The guide's §3.3: the top-level `let` rule (L703), item 3's point 4. The guide's §3.4: "The `with` says only that a function acts" (L726). The guide's §3.5: `apply`'s type, "pure when `f` is" (L735), "or for pure" (L737).
- The guide's §4.1: *A process that receives nothing* (L817). The guide's §4.3: a timed wait in a `Never` process (L888), item 3's point 1. The guide's §4.6: `next : (Int) -> Unit with CounterMsg` (L1057).
- The guide's §5.1: "it must be a real one" (L1221). The guide's §5.2: `worker` calls `self()` for its identity (L1254). The guide's §6.3: "`average` is pure" (L1600). The guide's §6.5: "and need not" (L1699).
