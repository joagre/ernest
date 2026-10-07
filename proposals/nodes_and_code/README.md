# Nodes and code

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`mvp3.0.md`](mvp3.0.md) | what is proposed for MVP 3.0, peers: the plan's items for the milestone come from it, and the report's and the guide's peer text is rewritten from it | current, settled on 2026-10-07 after a read-back; it changes only by a question raised against it |
| [`mvp3.1.md`](mvp3.1.md) | what is proposed for MVP 3.1, code by its hash: step C of `mvp3.0.md`'s section 11 | being written, one question at a time, from `code.md`; its section 9 lists the questions |
| [`nodes.md`](nodes.md) | the reasons for nodes as designed through MVP 3.1, by subject in the order of `mvp3.0.md`'s section 6, each paragraph saying where the two milestones differ | current, kept in sync with the latest proposal that touches nodes |
| [`code.md`](code.md) | the thinking for MVP 3.1 and after, code by its hash and code change in running processes, from before the peer design was settled | raw material for `mvp3.1.md`; becomes its reasons as the questions are decided, and keeps step D's thinking for the milestone after |
| [`other_systems.md`](other_systems.md) | how Orleans, Akka, Erlang's ecosystem and the typed and capability systems treat the same questions, and what the experiment found | current |
| [`experiments/erlang_distribution/`](experiments/erlang_distribution/) | the experiment that tried the carrier, thirteen steps on real nodes on one machine; `run.sh` runs it | current, run after each decision it bears on |

The report's §8.7 and §10 and the guide's peer chapter describe the design before `mvp3.0.md`, and are rewritten from it as the first item of the milestone's build; nothing is built from them until then. Until a proposal here is decided, all of it is tentative, as [`CLAUDE.md`](../../CLAUDE.md) says.
