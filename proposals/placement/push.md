# Placement by push

Decided on 2026-10-13, with the user, every question of section 7; built as MVP 3.2's item 8, before the deployment guide, so that the guide teaches the placement that ships; `Peer.load` and `Peer.loads` were renamed `Peer.setUtilisation` and `Peer.utilisations` as it was built, the number told being the utilisation, and this page keeps the names it was written with. Begun the same day, it reopened one question of `proposals/balancer/suggestion.md`, decided for MVP 3.25: how a node learns how busy its peers are. There, a node asks at the moment of the pick, `Placement.leastBusy(names, ms)` asking every name its utilisation at once. Here, each node tells its peers on an interval, and a node picks from what it holds. Once built, the report owns the rules and this page is the record of the design.

## 1. What it is

Each node that lists peers tells each of them, on an interval its `ernest.conf` sets, how busy it is, on §8.7's scale and by the measure its `utilisation` names, the same number `Peer.utilisation` answers. A node holds, for each peer it has heard from, the last utilisation heard and the moment it came, and nothing of a peer it has not heard from.

`Peer.compute(f, ms)` draws two of the peers whose utilisation the node holds, at random, and runs `f` on the less loaded of the two, a single peer taken as it is, and answers `f`'s value within `ms` milliseconds as `Peer.compute` answers today. `Peer.computeAt(name, f, ms)` is today's `Peer.compute`, on the named peer. `Peer.loads()` answers the loads the node holds, each peer's name with its utilisation and the milliseconds since it came, in the configuration's order, so that a program with a rule of its own writes it over the table as it writes one over `Peer.utilisation` today.

The table's rules. A peer not heard from is not chosen. A load older than two intervals is not used, since the peer has missed a telling and the carrier has not yet said it is lost (§8.7's 45 to 75 seconds). Two drawn peers equally loaded: the first in the configuration's order. No peer with a load to use where peers are listed: `Left(Unreachable)`, no peer being reachable by what it has said; no peer listed at all: `Left(NotListed)`, as today's compute answers a name not listed. A peer's loss (§8.7) drops its load with its connection; a peer that connects is heard from within one interval.

The interval. `"utilisation-interval"` in `ernest.conf` (Appendix C), milliseconds between a node's tellings, 5000 where it is left out. It is the operator's time, as `utilisation` is the operator's measure, and the report states it as a configured value; the runtime still chooses no time of its own.

The number a node tells is its own to design. By default it is the measure `utilisation` names, as `Peer.utilisation` answers it today; a program that knows its load better, a queue's depth, a store's fill, work it has promised, tells the node the number itself, `Peer.load(x)`, `x` from 0.0 to 1.0, and from then on the node tells that number at each interval and `Peer.utilisation` answers it to a peer, until the program sets it again. The scale stays §8.7's, 0.0 idle and 1.0 full, so that nodes of different programs are compared on one scale; what the number means is the program's.

`Peer.spawn`, `Peer.spawnMonitored` and `Peer.find` keep their names and their peer. A process is placed by a deployment's decision, where the data is, where the service is to live, which a name says; a computation is work, placed where there is room. The asymmetry is stated, and section 7 names what would change it.

The `Placement` library goes with Appendix G.5, since a pull beside a push is two ways to one end (principle 2); `Peer.utilisation(name, ms)` stays, a measurement asked for now, which a program wanting a fresher number than the table's takes.

## 2. What a program sees

The normal case, a computation where there is room and its value back:

```ernest
match Peer.compute(fn() = render(scene), 5000) {
    Right(image) -> save(image)
  | Left(Unreachable) -> save(render(scene))
  | Left(error) -> Io.printError("render: " <> Io.show(error))
}
```

The one `Left` a program must think about is `Unreachable`, no peer having said its load, which the program answers by working here or by waiting; before this, the same arm was `Placement.leastBusy`'s `None`. The rest are `Peer.compute`'s today: `Timeout`, `NotLoaded`, `Other`.

A rule of the program's own, the least loaded of every peer, the compute written where the lambda is, since §3.11 admits no function that came as a parameter (`docs/language_feedback.md` 106):

```ernest
fn computed(n : Int) : Either(Io.Error, Int) with m =
    match List.sort(Peer.loads(), fn(#(_, a, _), #(_, b, _)) = Float.compare(a, b)) {
        #(name, _, _) :: _ -> Peer.computeAt(name, fn() = heavy(n), 5000)
      | [] -> Left(Io.Unreachable)
    }
```

Another rule is a function beside it, as this one is; no rule is a line of `ernest.conf`.

## 3. What it costs

**Frames.** One frame from each node to each of its peers every interval: for N nodes that all list one another, N(N − 1) frames per interval across the mesh, 90 every five seconds for ten nodes, about ten thousand for a hundred, each a few bytes. The host's own ticks between connected nodes run already, about 0.1 packets a second on a connection as MVP 3.2's item 7 measured, so a mesh pays periodic frames today; this adds one of Ernest's beside them. A node with peers pays it whether or not it ever picks, which principle 5 counts against the design and the number above says is small.

**Staleness.** A load is up to one interval old when it is read, and a burst of computes within one interval all see the same table. Under the least loaded, every compute of the burst goes to the same peer until that peer's next telling shows it loaded; under two choices the draw spreads the choosers before the comparison does, which is why the rule is the default: Mitzenmacher's result on old information is that the least loaded herds under stale loads while two choices barely degrades. MVP 3.27 measures both across machines.

**Time.** No new time of the runtime's: the interval is the configuration's, and a compute's `ms` bounds the work alone, the pick costing a table read and a draw. The pull's pick cost the asks' `ms` before the compute's, measured on one machine at 453 µs over two peers and 600 over three, against 166 for the compute alone.

**Names.** `Peer` gains `computeAt`, `loads` and `load` and keeps `compute` with a new meaning, four names for two before, and the library loses one; the standard library's count goes up by two. Principle 5 counts names in the language and the prelude, not the standard library, which E.0 bounds; E.0's admission asks whether a reader who knows the type looks for the function here, and a reader with a computation and no peer in mind looks for `Peer.compute`.

**Memory.** A row per peer, bounded by the configuration.

## 4. What other systems do

- **Kubernetes.** Each node's kubelet posts its status on an interval, ten seconds by default, and the scheduler places a pod by reading the stored statuses; nothing asks a node at the moment of a placement. Push with a configured interval and a stale table, at scale, for a decade.
- **Akka Cluster.** The cluster metrics extension gossips each node's load, heap and CPU on an interval, and the adaptive load-balancing router picks by the gossiped metrics with a weighted random choice, so that a burst spreads. Push, with randomness against the herd.
- **The power of two choices.** Mitzenmacher, 2001: choosing the less loaded of two peers drawn at random spreads load nearly as well as choosing the least loaded of all, and far better than one at random; and under old information two choices holds up where the least loaded herds. The standard answer to the herd, and the rule here.
- **Erlang/OTP.** Nothing of its own: `rpc` names a node, and placement is the program's. The balancer proposal's choice of a pull was Erlang's instinct, measure when you need to know.
- **Riak Core.** Gossip of ring state, not load; placement by consistent hashing, which asks no one.
- **Nginx `least_conn`.** A local count of connections per upstream, no messages at all, since the balancer sees every request it sends. The shape a single front node has and a mesh does not.

## 5. The experiment

Run by MVP 3.27 across the user's four machines, one on a separate LAN, once the push is built: from one node, a burst of a hundred computes of a hundred milliseconds' work, sent as fast as the node can, then a steady stream, one every fifty milliseconds for a minute; measured, how they fall over the peers under two choices and under the least loaded written over `Peer.loads()`; beside them, the frames per second and the nodes' idle CPU at an interval of five seconds. MVP 3.2's item 7 measured the pull on one machine, 2026-10-13: `Peer.utilisation` 144 µs a round trip, `Placement.leastBusy` 233 µs over one peer, 453 over two and 600 over three, a pick over two and the compute after it 814 µs against 166 for the compute alone; the asks of different peers did not overlap, and plain Erlang over the host's distribution showed the same on one machine, so no number of a pick's that crosses a wire is taken as measured until MVP 3.27 has it. Three idle nodes exchanged the host's ticks alone, about 0.3 packets a second across the three and no frame of Ernest's.

## 6. What changes in the report

- §8.7: the telling, one frame more among the runtime's own, the table and its rules, `compute` by two choices and `computeAt` on a name, `load`, the loss dropping a load.
- §10: the frames' cost per interval, stated.
- Appendix C: `"utilisation-interval"`, its default.
- E.27: `compute`, `computeAt`, `loads`, `load`; the guide's §8.1 taught over them.
- G.5 goes, and the `Placement` library with it; its tests move to `Peer`'s.
- The log's *Placing Work by Name* gains the reversal and why; `proposals/balancer/README.md` points here.
- `docs/soundness.md`: nothing, since no type changes; a load is a number.

## 7. Decided

1. **The pick's rule.** Two choices, drawn at random among the peers with a usable load, the less loaded taken, a single one taken as it is: under stale information the least loaded herds and two choices does not, and the table is stale by design. The least loaded of all is a program's own rule over `Peer.loads()`, three lines, and not a line of `ernest.conf`: with two or three peers the two rules coincide, the gain of the least loaded shows only with many peers under a sparse steady load, and a configured rule would change where a program's work runs behind a call whose text does not show it (principle 3), where the `utilisation` key changes a number and not a destination. What would change it: an operator with a case the three lines do not serve.
2. **Spawn.** `Peer.spawn` keeps its name and its peer: a process's place is a deployment's decision, and four names in place of two were not worth a worker pool spawned where there is room, which a program writes over `Peer.loads()` and `Peer.spawn` in two lines. What would change it: programs that write those two lines everywhere.
3. **The default interval.** Five seconds, Kubernetes' order; MVP 3.27's steady stream shows where the knee is, and the key is the operator's to move.
4. **A bare node.** Tells its load as any node does, and holds its peers'; a compute from it picks as any does.
5. **The number's design.** `Peer.load(x)` sets a value the node tells until it is set again, the plainest shape; a function the node would call at each telling would run the program's code in a process of the runtime's on the runtime's interval, which §0's paragraph on time and principle 3 count against. A program that wants a fresh number sets it when its own state changes.
6. **A node that lists no peers.** Tells no one, holds nothing, and `Peer.compute` answers `Left(NotListed)`, there being no peer to reach; `Left(Unreachable)` is for peers listed and none with a usable load.

## 8. Built as MVP 3.2's item 8

The report's sentences first, then the frame, the table and the four functions, the `Placement` library removed, the guide's §8.1 taught over the new names, the nodes tests over the rules, `make test` green, the measurements of the pick's cost in the log; MVP 3.27 measures it across machines, and the deployment guide, item 8, teaches it.
