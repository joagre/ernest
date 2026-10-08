# Nodes and code

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`mvp3.0.md`](mvp3.0.md) | what is proposed for MVP 3.0, peers: the plan's items for the milestone come from it, and the report's and the guide's peer text is rewritten from it | current, settled on 2026-10-07 after a read-back and changed on 2026-10-08 by the review of the three proposals and by the report's rewrite from it, which its status line lists; it changes only by a question raised against it |
| [`mvp3.1.md`](mvp3.1.md) | what is proposed for MVP 3.1, code by its hash: step C of `code.md`'s section 1 | current, settled on 2026-10-07 after a cross-check with `mvp3.0.md`, a fresh reader and a read-back, and changed on 2026-10-08 by the review, which its status line lists |
| [`nodes.md`](nodes.md) | the reasons for nodes as designed through MVP 3.1, by subject in the order of `mvp3.0.md`'s section 6, each paragraph saying where the two milestones differ | current, kept in sync with the latest proposal that touches nodes |
| [`code.md`](code.md) | the reasons for code as designed through MVP 3.1, by subject in the order of `mvp3.1.md`'s section 6, and in its part two the thinking for step D, a running process that takes new code, left as thought for the milestone after | current, kept in sync with the latest proposal that touches code |
| [`mvp3.2.md`](mvp3.2.md) | what is proposed for step D, the ordered rolling restart: the plan from the hashes, expand then contract enforced, `kept`, the planned stop that is termination and the node's restart inside its process, lockstep with a yes per node, the `Standing` library, the cache, the test | settled 2026-10-07, reviewed and changed 2026-10-08 |
| [`deploy.md`](deploy.md) | the reasons for `mvp3.2.md`, in the order of its section 6, each decision dated where it stands; section 15 says why nothing changes in place | decided whole 2026-10-07, synced 2026-10-08 |
| [`other_systems.md`](other_systems.md) | how Orleans, Akka, Erlang's ecosystem and the typed and capability systems treat the same questions, and what the experiment found | current |
| [`experiments/erlang_distribution/`](experiments/erlang_distribution/) | the experiment that tried the carrier, thirteen steps on real nodes on one machine; `run.sh` runs it | current, run after each decision it bears on |
| [`experiments/code_update/`](experiments/code_update/README.md) | six programs and the library they share, written twice, which showed what a change of code in place would cost; the record behind `deploy.md`'s section 15 | current, kept as the record |
| [`experiments/paper/`](experiments/paper/accounts.md) | the paper program of the review, an accounts system rolled through five builds and back, written against the three proposals | current, written 2026-10-08 |

The report's §8.7 and §10 were rewritten from `mvp3.0.md` on 2026-10-08, the first item of the milestone's build, and the guide's peer chapter from the report the same day, the milestone's last item; MVP 3.0 is built, and `mvp3.0.md` is kept as the record of its design. Until a proposal here is decided, all of it is tentative, as [`CLAUDE.md`](../../CLAUDE.md) says.
