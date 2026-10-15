# Placement by push

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`push.md`](push.md) | a proposal that each node tells its peers its utilisation on an interval the configuration sets, so that a node holds its peers' loads and places a computation by them without asking: `Peer.compute(f, ms)` on the least loaded peer beside `Peer.computeAt(name, f, ms)` on a named one, `Peer.loads()` for a program's own rule, `Peer.load(x)` for a program that designs the number its node tells, and the `Placement` library gone; the rules the table needs, the costs, what other systems do, the experiment that decides the pick's rule, and what changes in the report | decided 2026-10-13 with the user, every question of its section 7; built as MVP 3.2's item 8, the record of the design once built; its `Peer.load` and `Peer.loads` are `Peer.setUtilisation` and `Peer.utilisations` in the library |

It reopened what [`../balancer/`](../balancer/) decided for MVP 3.25, a pull of every peer's utilisation at the moment of the pick, on one question, whether the loads are pushed on an interval instead, and decided for the push. It is built as MVP 3.2's item 8, after item 7 and before the deployment guide, so that the guide teaches the placement that ships and the 0.4.0 release ships it; MVP 3.27 measures it across machines. Once built, the report owns the rules.
