# Thinking for MVP 3.0 and 3.1

The thinking about peers, code distribution and code change, before MVP 3.0 decides any of it. Everything here is tentative: nothing is a decision, nothing is built, and nothing in the report changes because of it.

**A clean room.** This note stands on its own. It reads [`node_protocol.md`](node_protocol.md) and [`code_distribution.md`](code_distribution.md) as input, and their solutions are valuable, but it is not bound by them. Nothing flows from it into the report, the notes, the plan or the log until the thinking is covered. Then each decision goes to its owner, the report for a rule, the two notes for the design, the log for the why, in the plan's step *The distribution notes' rewrite*, and this note goes.

## 1. The aim

Unison names every definition by a hash of its content. Builds become incremental, two versions of a definition are two things and never conflict, a rename costs nothing, and code can move between machines because its identity is exact. Ernest takes that idea openly (the plan's MVP 3.1). The aim is to do what it promises soundly and realistically:

- **Sound.** What holds across nodes is argued, as [`soundness.md`](soundness.md) argues the core, before it is built (MVP 3.0's first item). Failure is part of the language: a peer's loss kills its processes with `Fault("peer lost")` and delivers their monitors (§10), a message is sent at most once, a call waits with a deadline, and a reply is checked.
- **Typed processes as the unit of distribution.** Shipping code is spawning a typed process on a peer, its protocol's hash checked.
- **Realistic.** Source stays text files under git, edited and reviewed as any code; the compiler computes the hashes. The runtime is the BEAM, with its decades of production behaviour, on machines a program's owner runs, listed in `ernest.conf` and authenticated by mutual TLS, with no platform to depend on. What hash modules cost on the BEAM, atoms and code memory, is measured before anything is promised.

Unison has shipped for years, and Ernest has a design, so "better" is true only when MVP 3.0 and 3.1 run and their numbers hold. Unison's codebase is a database rather than text files, and its distributed promise lives largely in its hosted cloud; what is said of its internals is said from the outside, and modestly.

## 2. Code change in running processes

**The objection.** A typed language, it is said, cannot have Erlang's code loading. Of the mechanism that is true. Erlang swaps a module under every process that runs it, a state takes a new shape in `code_change`, and messages of any shape keep arriving: the types of live data and of messages in flight change with nothing to check them against. Of what the mechanism is for it is not true. A running system upgraded without a stop, old and new code side by side, has a typed form, and §6.10 is a start of it: a process takes a message in its own type that carries the new loop, checked against its mailbox type before it arrives, and carries its state over by a typed function, Erlang's `code_change` checked. What a typed process cannot do is change its mailbox type in place, since its clients hold an address of the old type. In Erlang the same mismatch shows at run time, as messages nobody matches; Ernest would make a program say how old clients are served.

**Loading never disturbs running code.** A hash module never changes, so loading only adds. A process keeps the code it runs until its own upgrade case moves it, or until it ends, so loading new code is as safe as starting a process. BEAM's limit of two versions of a module, which kills a process still in the old one on a third load, does not arise. The cost moves to unloading: code stays loaded while any process, message or value refers to it, and memory no collection reclaims is a defect, so code is collected.

**The service that never ends.** A short-lived process ends on its old code, and its successor begins on the new. A long-serving service never ends, so it sees new code only through an upgrade case of its own; the runtime cannot migrate a state it cannot see, which lives in the loop's arguments. A change of logic behind the same protocol, the common case, upgrades in place with no outage: the address stays, and what arrives meanwhile waits in the mailbox. A change of protocol needs an overlap: a new service under its own binding, the state handed over by message, and the old service a forwarder that translates old messages for the clients still holding its address, until it may retire, which the runtime cannot tell.

**A discipline around upgrade types.** An upgrade case each service writes by hand is forgotten, or written in a shape of its own, and then nothing upgrades services alike. A fixed shape lets a supervisor, the shell or a tool upgrade any service, as OTP's system messages reach every behaviour, but visibly, in each protocol's type (principle 3). One form is a library type over the language's own: a service's mailbox `Service(Msg, State)`, its messages and an `Upgrade` that carries the new loop as `(State) -> Unit`, which adds no concept (principle 5). A rule of the language that every service binding holds one would be stronger, and would bind services that never change.

**The state as a schema.** In that form, the state's type at the switch is the service's contract with its later versions. A new loop may hold any state it likes inside, and hands over a `State` at its next upgrade; a change of `State` itself is a change of protocol.

**A restart after an upgrade.** `restarting(limit, f)` and a supervisor's child hold `f` by its hash. A service upgraded and then faulting would restart into the `f` it was spawned with, and the fix would vanish at the first fault. Erlang's restart calls the start function by name and finds the new module. An upgrade would have to replace what a restart runs, so the discipline reaches `restarting` and `Supervisor`, not the loop alone.

**Clients of two versions.** Clients that share a protocol type share its hash, and the service sees one type from all of them, whatever their own code's version. A client built against another version of the protocol holds an address of another type, and an address carries its mailbox type's hash: it cannot reach the old service by mistake, and the lookup of its binding fails at resolution, never by a message misread. The price is strictness. A type's hash covers what it refers to, so a change to a record deep in a protocol is a new protocol, and a change to a type many protocols share means replacing every service that carries it. So the discipline has a second half: a service's protocol types are small, stable and its own, not built from types shared across a program, and most changes are then changes of logic behind a stable protocol.

**Compatible evolution.** A second version that adds a constructor and is accepted where the first is, as protobuf's systems allow, would be an exception to "two versions of a type are two types". Principle 2 argues against it while a forwarder does the work; the inclination is to keep it out until a real service misses it.

## 3. In practice

Most production systems, Erlang's among them, do not upgrade in place. They start the new version beside the old, move the traffic and drain the old, with the state kept outside the processes. An upgrade in place serves where reconnecting costs: a telephone call, a chat or game server holding many connections, a trading gateway. So the thinking is to make the ordinary path excellent and the upgrade in place safe.

- **A deploy planned from the hashes.** For each process, comparing the old build's hashes with the new: protocol and code unchanged is nothing to do; code changed behind the same protocol is an upgrade in place; protocol changed is a replacement with an overlap. Erlang's `appup` files say this by hand. A tool that prints the plan before a deploy, and refuses what it cannot do safely, is worth more than a feature of the language.
- **A keeper.** A service built as a process that holds the state behind a small protocol that seldom changes, with the logic that changes often in processes cheap to replace, or in functions the keeper upgrades. Most deploys are then changes of logic. The guide would teach it as the ordinary way to build a service.
- **Rollback by default.** Where the new loop faults within a limit, the old loop resumes with the state it handed over.
- **A restart follows the upgrade**, as in section 2.
- **The code's hash in `Process.info`**, so that a deploy lists the processes still on old code.
- **A protocol change run by the tool.** The new service started, the state handed over, the old one a forwarder that counts the clients still using it, retired by the operator when the count is zero.
- **An upgrade tested.** Each build tested against the last release's: the old started, the plan applied, the state checked. A path that runs once a quarter decays unless a machine runs it on every commit.

The order the thinking suggests: the plan from the hashes and the code's hash in `Process.info`; then replacement with forwarders; then the upgrade in place with its rollback.

## 4. The story

Not "hot code loading, but typed": that promises the mechanism, the part that cannot be typed. The story is about deploys:

> Ernest knows exactly what changed between two builds, down to each process's protocol. Before a deploy, it tells you which services upgrade in place without a dropped connection, which need a replacement, and which are untouched. And the compiler guarantees that a client and a service of different protocol versions never exchange a message.

It is told only once it runs: a demo, a chat server holding many connections upgraded in place with none dropped, then a protocol change carried through a forwarder, with the plan printed before each step. Its limits are stated with it: a service cooperates, a protocol change needs an overlap, and strict hashes make a shared type ripple.

## 5. Open questions

1. Whether a protocol must hold an upgrade case, or is encouraged to.
2. What an upgrade in place may change: the state's type at the switch, the mailbox type.
3. How a restart after an upgrade runs the new function, in `restarting` and in `Supervisor`.
4. How a protocol change reaches clients that hold the old address: a forwarder, `via`, a new binding; and when a forwarder retires.
5. How a supervisor's tree is upgraded.
6. Whether handing a replacement its state is a library's work or each program's.
7. How code no process, message or value refers to is collected, and how the runtime learns that nothing does.
8. Compatible evolution: kept out, unless a real service misses it.
9. How an upgrade is made a test.
10. What hash modules cost on the BEAM, atoms and code memory, measured; and whether cold code is interpreted rather than loaded ([`code_distribution.md`](code_distribution.md)'s open question 2).
