# BEAM's own instructions

What each file here is, and which is current. Decided on 2026-10-30: no back end that writes BEAM's own instructions is built, which [`proposal.md`](proposal.md) states with what the experiment measured; the directory stays as the record of that measure.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | what the back end would have been, and why it is not built | current, decided |
| [`experiment.md`](experiment.md) | the experiment of 2026-10-27: what integer ranges and a value's shape buy, and a caller's saving of registers against a callee's, measured on three programs | the measure the decision rests on |
| `experiment/` | its code: each program in Erlang, in Ernest and as hand-written BEAM assembly, Ackermann and the mixer in both conventions, the mixer with non-negative ranges, and the tree with Ernest's knowledge, the assembler that skips the validator, the three benchmarks, and the probe of an obsolete opcode | the code `experiment.md` measures |
