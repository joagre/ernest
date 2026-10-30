# No back end to BEAM's own instructions

Decided on 2026-10-30: the back end is not built. This page holds what MVP 4.4 would have been, as the plan held it until that day, and why it was dropped; [`experiment.md`](experiment.md) is the measure the decision rests on, and the log's *No Back End to BEAM's Own Instructions* its argument.

## What it would have been

A second back end beside the emitter's Erlang abstract format, writing the BEAM's own instructions, its generic opcodes (`genop.tab`, format 0, additions only, OTP 29's record instructions among them), with Ernest's proven types written as the loader's typed registers, so that the JIT emits code without the run-time type tests the Erlang compiler must keep.

It would have changed no rule of the language, and it would have made the soundness argument load-bearing for the VM's memory safety: a value from outside, a peer's message, foreign code's return, is fully checked before its register is typed, which §8.4's checks and the argument's section 7 would then be read as carrying.

Its conditions were the language held still, OTP pinned for the long term, and `make bench`'s numbers for what the type tests cost, which would decide whether it was worth its cost. Its first, safe step, to measure against, was a type guard at each function's entry, from which the Erlang compiler's own inference types the body.

## Why it is not built

What it gives back is the experiment's measure. A value's shape known whole buys about 8% on the tree interpreter, the tests and the fallback the checker's knowledge removes, and needs nothing the checker lacks. Integer ranges buy a fifth on Ackermann and a tenth on the mixer, but only where ranges are proved, and Ernest's checker proves no range of an arbitrary-precision `Int`. The callee-save convention is unsound on BEAM and buys at most a few percent. No fast opcode can be named in a file: the type chunk is the one door, so the back end could prove types and choose nothing else.

What it costs is a second back end, every rule of §11.1 written twice; the validator bypassed, since it cannot know an argument's type; the soundness argument carrying the VM's memory safety; and the language held still and OTP pinned before anything is built.

Too little for its cost. The emitter's plain form, Erlang's abstract format compiled by the host's compiler, runs the experiment's programs within 5% of Erlang's own and ahead on two of the three, and it stays. The type guard at each function's entry is a change to the emitter and no back end; it is kept here as the one step the experiment leaves, to be measured if a program ever asks for the speed, and is on no plan.
