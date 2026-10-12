# Placement by push

Under discussion, begun 2026-10-13. Nothing here is decided. It reopens one question of `proposals/balancer/suggestion.md`, decided for MVP 3.25: how a node learns how busy its peers are. There, a node asks at the moment of the pick, `Placement.leastBusy(names, ms)` asking every name its utilisation at once. Here, each node tells its peers on an interval, and a node picks from what it holds.

## 1. What it is

Each node that lists peers tells each of them, on an interval its `ernest.conf` sets, how busy it is, on §8.7's scale and by the measure its `utilisation` names, the same number `Peer.utilisation` answers. A node holds, for each peer it has heard from, the last utilisation heard and the moment it came, and nothing of a peer it has not heard from.

`Peer.compute(f, ms)` runs `f` on the least loaded of the peers whose utilisation the node holds, and answers its value within `ms` milliseconds as `Peer.compute` answers today. `Peer.computeAt(name, f, ms)` is today's `Peer.compute`, on the named peer. `Peer.loads()` answers the loads the node holds, each peer's name with its utilisation and the milliseconds since it came, in the configuration's order, so that a program with a rule of its own writes it over the table as it writes one over `Peer.utilisation` today.

The table's rules. A peer not heard from is not chosen. A load older than two intervals is not used, since the peer has missed a telling and the carrier has not yet said it is lost (§8.7's 45 to 75 seconds). Two peers equally loaded: the first in the configuration's order. No peer with a load to use: `Left(Unreachable)`, no peer being reachable by what it has said. A peer's loss (§8.7) drops its load with its connection; a peer that connects is heard from within one interval.

The interval. `"utilisation-interval"` in `ernest.conf` (Appendix C), milliseconds between a node's tellings, 5000 where it is left out. It is the operator's time, as `utilisation` is the operator's measure, and the report states it as a configured value; the runtime still chooses no time of its own.

`Peer.spawn`, `Peer.spawnMonitored` and `Peer.find` keep their names and their peer. A process is placed by a deployment's decision, where the data is, where the service is to live, which a name says; a computation is work, placed where there is room. The asymmetry is stated, and section 7 names what would change it.

`libs/placement` goes with Appendix G.5, since a pull beside a push is two ways to one end (principle 2); `Peer.utilisation(name, ms)` stays, a measurement asked for now, which a program wanting a fresher number than the table's takes.

## 2. What a program sees

The normal case, a computation where there is room and its value back:

```ernest
match Peer.compute(fn() = render(scene), 5000) {
    Right(image) -> save(image)
  | Left(Unreachable) -> save(render(scene))
  | Left(error) -> Io.printError("render: " <> Io.show(error))
}
```

The one `Left` a program must think about is `Unreachable`, no peer having said its load, which the program answers by working here or by waiting; today the same arm is `Placement.leastBusy`'s `None`. The rest are `Peer.compute`'s today: `Timeout`, `NotLoaded`, `Other`.

A rule of the program's own, two choices drawn at random and the less loaded taken:

```ernest
fn placed(f : () -> a with m, ms : Int) : Either(Io.Error, a) with n+ =
    match Random.pair(Peer.loads()) {
        Some(#(#(first, load1, _), #(second, load2, _))) ->
            Peer.computeAt(if load1 <= load2 then first else second, f, ms)
      | None -> Peer.compute(f, ms)
    }
```

`Random.pair` is not in the library; the example shows the shape, a program's rule over the table in a few lines.

## 3. What it costs

**Frames.** One frame from each node to each of its peers every interval: for N nodes that all list one another, N(N − 1) frames per interval across the mesh, 90 every five seconds for ten nodes, about ten thousand for a hundred, each a few bytes. The host's own ticks between connected nodes run already, so a mesh pays periodic frames today; this adds one of Ernest's beside them. A node with peers pays it whether or not it ever picks, which principle 5 counts against the design and the number above says is small.

**Staleness.** A load is up to one interval old when it is read, and a burst of computes within one interval all see the same table. Under the rule of section 1 every compute of the burst goes to the same peer, until that peer's next telling shows it loaded. The pull of today sees the moment and spreads a burst over whichever peers answer first, though it too herds where every ask returns the same picture. The experiment of section 5 measures both, and the rule the burst asks for, the power of two choices, is a rule the program writes over `Peer.loads()`, or the standard's, which section 7 leaves open.

**Time.** No new time of the runtime's: the interval is the configuration's, and a compute's `ms` bounds the work alone, the pick costing a table read. Today's pick costs the asks' `ms` before the compute's.

**Names.** `Peer` gains `computeAt` and `loads` and keeps `compute` with a new meaning, three names for two today, and the library loses one; the standard library's count goes up by one. Principle 5 counts names in the language and the prelude, not the standard library, which E.0 bounds; E.0's admission asks whether a reader who knows the type looks for the function here, and a reader with a computation and no peer in mind looks for `Peer.compute`.

**Memory.** A row per peer, bounded by the configuration.

## 4. What other systems do

- **Kubernetes.** Each node's kubelet posts its status on an interval, ten seconds by default, and the scheduler places a pod by reading the stored statuses; nothing asks a node at the moment of a placement. Push with a configured interval and a stale table, at scale, for a decade.
- **Akka Cluster.** The cluster metrics extension gossips each node's load, heap and CPU on an interval, and the adaptive load-balancing router picks by the gossiped metrics with a weighted random choice, so that a burst spreads. Push, with randomness against the herd.
- **The power of two choices.** Mitzenmacher, 2001: choosing the less loaded of two peers drawn at random spreads load nearly as well as choosing the least loaded of all, and far better than one at random, and does so under stale information too. The standard answer to the herd.
- **Erlang/OTP.** Nothing of its own: `rpc` names a node, and placement is the program's. The balancer proposal's choice of a pull was Erlang's instinct, measure when you need to know.
- **Riak Core.** Gossip of ring state, not load; placement by consistent hashing, which asks no one.
- **Nginx `least_conn`.** A local count of connections per upstream, no messages at all, since the balancer sees every request it sends. The shape a single front node has and a mesh does not.

## 5. The experiment

Three nodes on one machine, `a`, `b` and `c`, each listing the others; from `a`, a burst of a hundred computes of a hundred milliseconds' work, sent as fast as `a` can; then a steady stream, one every fifty milliseconds for a minute. Measured: how the hundred fall over `b` and `c`, and the stream's, under three rules: today's pull, `Placement.leastBusy` before each compute; push by the least loaded; push by two choices over `Peer.loads()`. Beside them, the cost: frames per second and the nodes' idle CPU at an interval of five seconds, for three nodes and, by configuration alone, for ten. The nodes harness of `test/ern_nodes_tests.erl` runs such programs today, and `Peer.utilisation` gives the number the push would carry, so the push can be measured before it is built, by a program that tells and reads its own table in Ernest.

The experiment decides the pick's rule, section 7's first question, and gives item 7 of MVP 3.2 its numbers for the utilisation path.

## 6. What changes in the report

- §8.7: the telling, one frame more among the runtime's own, the table and its four rules, `compute` on the least loaded and `computeAt` on a name, the loss dropping a load.
- §10: the frames' cost per interval, stated.
- Appendix C: `"utilisation-interval"`, its default.
- E.27: `compute`, `computeAt`, `loads`; the guide's §8.1 taught over them.
- G.5 goes, and `libs/placement` with it; its tests move to `Peer`'s.
- The log's *Placing Work by Name* gains the reversal and why; `proposals/balancer/README.md` points here.
- `docs/soundness.md`: nothing, since no type changes; a load is a number.

## 7. Open

1. **The pick's rule.** Least loaded, which a reader predicts and the experiment may show herding; or two choices, which spreads a burst and puts a draw into where work runs. Decided by section 5.
2. **Spawn.** Whether `Peer.spawn` gains a nameless form too. Against: a process's place is a deployment's decision, and four names in place of two. For: a worker pool spawned where there is room, which today's program writes over `Peer.loads()` and `Peer.spawn` in two lines. What would change it: programs that write those two lines everywhere.
3. **The default interval.** Five seconds is Kubernetes' order; a shorter one costs frames, a longer one staleness. The experiment's steady stream shows where the knee is.
4. **A bare node.** It tells its load as any node does, and holds its peers'; a compute from it picks as any does. Nothing special, stated for completeness.
5. **A node that lists no peers.** Tells no one, holds nothing, and `Peer.compute` answers `Left(NotListed)` as today's does for a name not listed, since there is no peer to reach, not `Unreachable`. Stated.

## 8. If adopted

A milestone of its own, MVP 3.26, *Placement by push*: the proposal's rules into the report first, then the frame, the table and the two functions, `libs/placement` removed, the guide's §8.1 and the nodes tests over the experiment's programs, the measurements into the log. Built after MVP 3.2's item 7 and before its item 8, so that the deployment guide teaches the placement that ships and 0.4.0 ships it.
