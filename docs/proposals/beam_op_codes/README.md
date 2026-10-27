# BEAM's own instructions

What each file here is, and which is current. Nothing here is decided, as CLAUDE.md says of a proposal; it is the first experiment for MVP 4.4, a back end that writes BEAM's own instructions with Ernest's types as the loader's typed registers.

| File | What it is | Status |
|---|---|---|
| [`experiment.md`](experiment.md) | the experiment of 2026-10-27: typed registers, and a caller's saving of registers against a callee's, measured on two programs | current |
| `experiment/` | its code: each program in Erlang, in Ernest and as hand-written BEAM assembly in both conventions, the assembler that skips the validator, the two benchmarks, and the probe of an obsolete opcode | the code `experiment.md` measures |

The finding outside MVP 4.4's design, that today's emitter compiles a call of a host function's shim as a call, is the plan's MVP 3.96 item 9.
