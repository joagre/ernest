# What Ernest's types buy on BEAM, and who saves a register

An experiment of 2026-10-27, for MVP 4.4: a back end that writes BEAM's own instructions, with the types Ernest's checker proves given to the JIT as typed registers.

## Why

Three questions decide the back end's shape.

**What do integer ranges buy?** BEAM's JIT has no unchecked arithmetic of its own. What it reads is the module's type chunk: an operand written `{tr, Register, Type}` with an integer range that fits a small integer lets it emit an addition without the tag test and the bignum fallback. OTP's compiler writes such a type only where its own inference proves it. Ernest's checker could prove more.

**What does a value's shape buy?** An exported function's argument is anything to OTP, so its code tests a tuple, dispatches on its arity, tests its tag and keeps a fallback for a value no clause matches. Ernest's checker knows the argument's type whole, so its emitter could leave those tests out.

**Who should save a register across a call?** BEAM's convention is the caller's: every `x` register is dead after a call, so a function keeps what it needs across one in its stack frame, the `y` registers, and moves it back after. The alternative is the callee's, common on real processors: a function preserves the registers it does not use, so a caller keeps its values in registers across calls to leaves that never touch them.

## No untyped fast opcodes

A `.beam` file names only BEAM's generic instructions, the compiler's opcode table. The fast instructions that do no type test, `i_increment` and its kind, are the loader's and the JIT's own, chosen as they load a module, and no file can name them.

The generic table still holds `m_plus`, `m_minus`, `m_times`, `int_band`, `int_bsl` and their kin, the arithmetic of the oldest BEAM before `gc_bif` replaced it. They are names alone: OTP 29's `beam_opcodes:opcode(m_plus, 4)` is commented out, so `beam_asm` cannot encode one, `experiment/obsolete_m_plus.S` failing with `badarg`, and the emulator's loader refuses an obsolete instruction. They were checked besides, each taking a failure label as `gc_bif` does.

So the one way a module asks for the fast track is the type chunk: a typed register, `{tr, Register, Type}`, on an operand, from which the JIT emits the operation with no test. *Typed* in the tables below is that fast track. MVP 4.4's back end cannot choose fast instructions, only prove types, and its value is what its checker proves beyond OTP's inference.

## How

Each program was written in Erlang, compiled by OTP 29's compiler, and its assembly taken with `erlc -S`. For Ackermann and the mixer, two variants were written by hand from that assembly:

- **Caller saves**: OTP's own code instruction for instruction, with typed registers added where OTP's inference left an operand untyped.
- **Callee saves**: the same, with the functions that make calls rewritten so that the caller's values stay in `x` registers that no callee touches.

For the expression tree, one variant was written with what Ernest's checker knows, below.

The callee-save variant is refused by `beam_validator`, Ackermann's with `{x,2},not_live` and the mixer's with `uninitialized_reg`, since the validator holds BEAM's convention. `experiment/asm_novalidate.erl` assembles it by handing the consulted assembly to `beam_asm:module` directly, the step after validation. It is not sound. A schedule-out keeps only a call's live `x` registers, so a value held beyond them is lost when another process runs on the scheduler: with one scheduler and a second busy process, the mixer's variant loops forever and Ackermann's crashes the emulator. The callee-save rows were measured with nothing else running, and every run gave the right value. A boxed value held so would be a dangling pointer after a collection besides.

Each program was written in Ernest too, `ack.ern` beside `ack.erl` and likewise for the others, and the two of a pair time themselves the same way, the same loop around the same work and the host's monotonic clock in microseconds, run alternately, twice each: so the Ernest rows compare with Erlang measured so. The BEAM variants were compared with Erlang under `timer:tc`, one harness for both. A table's ratios therefore compare rows of one harness. Every number is the median of eleven runs on an x86_64 laptop, the two rounds within a percent or two, the mixer's within 5%.

## Ackermann

One function, `ack(m, n)`, recursing, one value alive across its inner call. `experiment/ack.erl`, `ack.ern`, `ack_caller.S`, `ack_callee.S`, `ack_bench.erl`.

| Version | A(3, 11) | Against Erlang |
|---|---|---|
| Erlang, OTP's compiler, under `timer:tc` | 660 ms | 1.00 |
| BEAM, typed, caller saves | 524 ms | 0.79 |
| BEAM, typed, callee saves | 562 ms | 0.85 |
| Erlang, timing itself | 679 to 694 ms | 1.00 |
| Ernest, today's emitter, timing itself | 580 to 591 ms | 0.85 |

OTP's inference gives Ackermann's arguments no range, so every addition and subtraction carries its test. The typed caller-save variant, OTP's code with ranges asserted, is 21% faster: that is the JIT dropping the tests. Callee-save is slower here: both variants need a frame to hold the one value across the call, and callee-save adds a restore before its tail call. Ernest is 15% ahead of Erlang; why is not yet looked at.

## The mixer

A loop carrying five values, a counter, three state words and an accumulator, across four calls an iteration: three to leaves, an LCG step, a mix, `(x + y * 8) rem 2^24`, and a stand-in for a rotate, `(x * (s + 1) + (24 - s)) rem 2^24` with `s` the counter's remainder by 8, and one to `mix3`, which calls `mix` twice. Every value is a non-negative integer kept below 2^24 by `rem`, Ernest's `%`, and no operation is bitwise, so that Ernest's version is its arithmetic operators alone. `experiment/mixer.erl`, `mixer.ern`, `mixer_caller.S`, `mixer_callee.S`, `mixer_unsigned.S`, `mixer_bench.erl`.

The register layout under callee-save follows what each leaf touches: `lcg` uses `x0`, `mix` `x0` and `x1`, `rot` `x0` to `x2`. So `mix3` keeps its third argument in `x2` across both calls of `mix` and saves nothing, and the loop keeps its values in `x3` to `x8` with a frame that holds only the return address, where OTP's frame holds five values and moves them around every call.

| Version | Ten million iterations | Against Erlang |
|---|---|---|
| Erlang, OTP's compiler, under `timer:tc` | 322 to 337 ms | 1.00 |
| BEAM, typed, caller saves | 329 to 332 ms | 0.99 to 1.02 |
| BEAM, typed, callee saves | 321 to 331 ms | 0.98 to 1.00 |
| Erlang, timing itself | 319 to 330 ms | 1.00 |
| Ernest, timing itself | 331 to 335 ms | 1.00 to 1.05 |

Each ratio is a round's against the same round's Erlang.

OTP's inference types every value but the counter. Its ranges are signed, though every value is non-negative, so the JIT compiles each `rem` by 2^24 as a signed remainder, not as the single mask it uses where a range starts at zero. Typing the counter adds nothing.

With every range's lower bound set to zero, which the values allow, the caller-save variant, `mixer_unsigned.S`, takes 299 to 301 ms against 336 to 338 for Erlang and the caller-save variant in a round of its own, about 11% faster.

Callee-save is 0 to 2% faster, in the case built to favor it, within a spread between rounds of up to 5%.

Ernest compiles `%` to `rem` with no call, and its loop and leaves to Erlang's instructions, the counter's type aside. Its row is level with Erlang's within the spread, 0 to 5% slower in the two rounds.

## The expression tree

An interpreter for a tree of four constructors, `Num`, `Add`, `Mul` and `Neg`, its arithmetic masked by `rem` so that integers are not what is measured and Ernest's version uses no shim. `eval` is exported, as every call between Ernest's separately compiled units is, so OTP's inference knows nothing of its argument. The program is matching on constructors and reading their fields, which Ernest's checker knows whole. `experiment/tree.erl`, `tree.ern`, `tree_typed.S`, `tree_bench.erl`.

OTP's `eval` tests `is_tuple`, dispatches on the arity with `select_tuple_arity`, reads the fields, dispatches on the tag with `select_val` and keeps a `function_clause` fallback; it types `eval`'s result as `t_number`, since an exported function may answer a float. The variant with Ernest's knowledge reads the tag and dispatches once over the four, with `Num` as the fallback since the match is exhaustive, reads a clause's fields within it, and types the result `Int`. It is assembled past the validator, which cannot know that every argument is an `Expr`.

| Version | A thousand evaluations of a depth-22 tree | Against Erlang |
|---|---|---|
| Erlang, OTP's compiler, under `timer:tc` | 839 to 874 ms | 1.00 |
| BEAM with Ernest's knowledge | 778 to 791 ms | 0.92 |
| Erlang, timing itself | 957 to 961 ms | 1.00 |
| Ernest, today's emitter, timing itself | 858 to 864 ms | 0.90 |

The tree's Erlang is slower timing itself than under `timer:tc`, since its loop of evaluations is a recursive function where the benchmark's is a `lists:foldl`, which is why each comparison stays within one harness.

Type knowledge pays outside integers too, about 8%, from the tests and the fallback it removes. It is less than integer ranges gave Ackermann, and broader: nearly every Ernest program matches on its own types, and this needs no range analysis, only what the checker already knows.

## The outcome

- **Keep BEAM's convention, the caller's.** Callee-save buys at most a few percent where its case is strongest and loses where a frame is needed anyway. It is not sound on BEAM, since a schedule-out keeps only the live `x` registers, so it would need the emulator changed as well as the validator, and it costs the debugger's reading of a frame.
- **Type knowledge is where the gain is**, in two kinds. Integer ranges bought a fifth on Ackermann, where OTP's inference proves none, and a tenth on the mixer, where it proves only signed ranges and a non-negative one turns each `rem` into a mask, though Ernest's checker proves no range of an arbitrary-precision `Int` today either, so that gain waits for a range analysis. A value's shape bought about 8% on the tree, from tests and a fallback the checker's knowledge removes, and it needs nothing the checker lacks. MVP 4.4's back end is worth its cost by the second kind first, broad and available, and by the first where ranges are proved.
