# Nodes and code

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`mvp3.0.md`](mvp3.0.md) | what is proposed for MVP 3.0, peers: the plan's items for the milestone come from it, and the report's and the guide's peer text is rewritten from it | current, settled on 2026-10-07 after a read-back; it changes only by a question raised against it |
| [`mvp3.1.md`](mvp3.1.md) | what is proposed for MVP 3.1, code by its hash: step C of `code.md`'s section 1 | current, settled on 2026-10-07 after a cross-check with `mvp3.0.md`, a fresh reader and a read-back |
| [`nodes.md`](nodes.md) | the reasons for nodes as designed through MVP 3.1, by subject in the order of `mvp3.0.md`'s section 6, each paragraph saying where the two milestones differ | current, kept in sync with the latest proposal that touches nodes |
| [`code.md`](code.md) | the reasons for code as designed through MVP 3.1, by subject in the order of `mvp3.1.md`'s section 6, and in its part two the thinking for step D, a running process that takes new code, left as thought for the milestone after | current, kept in sync with the latest proposal that touches code |
| [`code_update.md`](code_update.md) | the thinking for step D, a running system that takes new code: one recovery path, the matrix of what changed against what kind of process meets it, what the tool computes, what is to hold, what was read, and in its section 9 the concept from the survey, a service as a step function the library runs; part two of `code.md` moves into it when its shape is agreed | begun 2026-10-07; section 9 governs sections 2 to 4 until they are rewritten under it |
| [`other_systems.md`](other_systems.md) | how Orleans, Akka, Erlang's ecosystem and the typed and capability systems treat the same questions, and what the experiment found | current |
| [`experiments/erlang_distribution/`](experiments/erlang_distribution/) | the experiment that tried the carrier, thirteen steps on real nodes on one machine; `run.sh` runs it | current, run after each decision it bears on |

The report's §8.7 and §10 and the guide's peer chapter describe the design before `mvp3.0.md`, and are rewritten from it as the first item of the milestone's build; nothing is built from them until then. Until a proposal here is decided, all of it is tentative, as [`CLAUDE.md`](../../CLAUDE.md) says.
