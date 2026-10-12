# Placement by push

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`push.md`](push.md) | a proposal that each node tells its peers its utilisation on an interval the configuration sets, so that a node holds its peers' loads and places a computation by them without asking: `Peer.compute(f, ms)` on the least loaded peer beside `Peer.computeAt(name, f, ms)` on a named one, `Peer.loads()` for a program's own rule, and `libs/placement` gone; the rules the table needs, the costs, what other systems do, the experiment that decides the pick's rule, and what changes in the report | under discussion, begun 2026-10-13 |

Until the proposal is decided all of it is tentative, and nothing flows from it into the report, the plan or the log. It reopens what [`../balancer/`](../balancer/) decided for MVP 3.25, a pull of every peer's utilisation at the moment of the pick, on one question: whether the loads are pushed on an interval instead. If it is adopted it is a milestone of its own, MVP 3.26, built after MVP 3.2's item 7 and before its item 8, so that the deployment guide teaches whichever placement wins and the 0.4.0 release ships it.
