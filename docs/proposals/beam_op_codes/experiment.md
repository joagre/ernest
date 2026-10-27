# Typed registers, and who saves a register

An experiment of 2026-10-27, for MVP 4.4: a back end that writes BEAM's own instructions, with the types Ernest's checker proves given to the JIT as typed registers.

## Why

Two questions decide the back end's shape.

**What do typed registers buy?** BEAM's JIT has no unchecked arithmetic of its own. What it reads is the module's type chunk: an operand written `{tr, Register, Type}` with an integer range that fits a small integer lets it emit an addition without the tag test and the bignum fallback. OTP's compiler writes such a type only where its own inference proves it. Ernest's checker could prove more.

**Who should save a register across a call?** BEAM's convention is the caller's: every `x` register is dead after a call, so a function keeps what it needs across one in its stack frame, the `y` registers, and moves it back after. The alternative is the callee's, common on real processors: a function preserves the registers it does not use, so a caller keeps its values in registers across calls to leaves that never touch them.

## No untyped fast opcodes

A `.beam` file names only BEAM's generic instructions, the compiler's opcode table. The fast instructions that do no type test, `i_increment` and its kind, are the loader's and the JIT's own, chosen as they load a module, and no file can name them.

The generic table still holds `m_plus`, `m_minus`, `m_times`, `int_band`, `int_bsl` and their kin, the arithmetic of the oldest BEAM before `gc_bif` replaced it. They are names alone: OTP 29's `beam_opcodes:opcode(m_plus, 4)` is commented out, so `beam_asm` cannot encode one, `experiment/obsolete_m_plus.S` failing with `badarg`, and the emulator's loader refuses an obsolete instruction. They were checked besides, each taking a failure label as `gc_bif` does.

So the one way a module asks for the fast track is the type chunk: a typed register, `{tr, Register, Type}`, on an operand, from which the JIT emits the operation with no test. *Typed* in the tables below is that fast track. MVP 4.4's back end cannot choose fast instructions, only prove types, and its value is what its checker proves beyond OTP's inference.

## How

Each program was written in Erlang, compiled by OTP 29's compiler, and its assembly taken with `erlc -S`. Two variants were written by hand from that assembly:

- **Caller saves**: OTP's own code instruction for instruction, with typed registers added where OTP's inference left an operand untyped.
- **Callee saves**: the same, with the functions that make calls rewritten so that the caller's values stay in `x` registers that no callee touches.

The callee-save variant is refused by `beam_validator`, `{x,2},not_live`, since the validator holds BEAM's convention. `experiment/asm_novalidate.erl` assembles it by handing the consulted assembly to `beam_asm:module` directly, the step after validation. It is sound only because every value it keeps in an `x` register across a call is a small integer, an immediate that no garbage collection moves; a boxed value there would be a dangling pointer after the first collection.

Each program was written in Ernest too, and timed inside itself by `Clock.monotonicMicros`. The BEAM variants were timed by `timer:tc`. Every number is the median of eleven runs on an x86_64 laptop, each benchmark run twice, the two rounds within a percent or two.

## Ackermann

One function, `ack(m, n)`, recursing, one value alive across its inner call. `experiment/ack.erl`, `ack_caller.S`, `ack_callee.S`, `ack_ern.ern`, `ack_bench.erl`.

| Version | A(3, 11) | Against Erlang |
|---|---|---|
| Erlang, OTP's compiler | 660 ms | 1.00 |
| Ernest, today's emitter | 597 ms | 0.90 |
| BEAM, typed, caller saves | 524 ms | 0.79 |
| BEAM, typed, callee saves | 562 ms | 0.85 |

OTP's inference gives Ackermann's arguments no range, so every addition and subtraction carries its test. The typed caller-save variant, OTP's code with ranges asserted, is 21% faster: that is the JIT dropping the tests. Callee-save is slower here: both variants need a frame to hold the one value across the call, and callee-save adds a restore before its tail call. Ernest is 10% ahead of Erlang; why is not yet looked at.

## The mixer

A loop carrying five values, a counter, three state words and an accumulator, across four calls an iteration: three to leaves, an LCG step, a mix by shift and xor and a rotate, and one to `mix3`, which calls `mix` twice. Every value is masked to 24 bits. `experiment/mixer.erl`, `mixer_caller.S`, `mixer_callee.S`, `mixer_ern.ern`, `mixer_bench.erl`.

The register layout under callee-save follows what each leaf touches: `lcg` uses `x0`, `mix` `x0` and `x1`, `rot` `x0` to `x2`. So `mix3` keeps its third argument in `x2` across both calls of `mix` and saves nothing, and the loop keeps its values in `x3` to `x8` with a frame that holds only the return address, where OTP's frame holds five values and moves them around every call.

| Version | Ten million iterations | Against Erlang |
|---|---|---|
| Erlang, OTP's compiler | 292 ms | 1.00 |
| BEAM, typed, caller saves | 291 ms | 1.00 |
| BEAM, typed, callee saves | 283 ms | 0.97 |
| Ernest, today's emitter | 1,197 ms | 4.10 |

OTP's inference already types every masked value, so typing the one untyped operand, the counter, adds nothing. Callee-save is 2 to 4% faster, in the case built to favor it, with the spread between runs nearly as large.

## The outcome

- **Keep BEAM's convention, the caller's.** Callee-save buys at most a few percent where its case is strongest and loses where a frame is needed anyway, and it costs the validator, the soundness of the garbage collector for any boxed value and the debugger's reading of a frame.
- **Typed registers are where the gain is**, a fifth on integer recursion, and only where OTP's own inference cannot prove a range and Ernest's checker could. MVP 4.4's back end is worth its cost to the degree such programs are Ernest's.
- **Today's emitter is four times slower than Erlang on the mixer**, a defect and not MVP 4.4's. `Int.bitAnd`, `bitOr` and `bitXor` are `foreign fn` shims over `erlang:band/2` and its kin, and the shifts Ernest functions over a helper, and the emitter compiles a call of each as a call into the `Int` unit, where Erlang's compiler makes one instruction. CLAUDE.md says a shim that is exactly a host function runs at the host's speed. MVP 3.96's item 9 fixes it, with a survey of what else the emitter writes as a call that the host writes as an instruction.
