# Agent orchestration: competing projects worth studying

Everything below is from knowledge up to mid-2026. Anything newer would need checking
directly, which a side question can't do.

---

## Why Ernest is a plausible language for this

The pitch is not "another actor language". It is that the things an agent fleet gets wrong
at runtime are things Ernest refuses at compile time.

**The protocol between agents is a type.** A process has one mailbox of one type (§6.1,
§9.3). An agent's protocol is therefore not a JSON schema checked at the boundary and hoped
for thereafter — it is the mailbox type, and a message that does not fit is a type error in
the sender. In every Python framework, and in Erlang and Elixir, the protocol lives in
documentation and in runtime validation.

**"Answer exactly once" is checked.** `Reply(a)` is linear (§6.6): every path from the
binding consumes it exactly once, by `answer`, by passing it on, by placing it in a message.
A tool call that silently never replies — the most common hang in an orchestration layer —
is a compile error here, not a timeout in a log three hours later. I know of no other
production language that checks this.

**A signature says whether a function can talk.** The mailbox effect is part of the arrow
(§3.9): `(A) -> B` cannot send, `(A) -> B with M` can. Reviewing an agent's pure planning
code and its effectful tool-calling code is a matter of reading types, not auditing bodies.

**Failure is ordinary and typed.** `monitor` delivers a `Down` carrying the cause and the
spawn site with its line (§6.9); there are no links, no supervision trees imposed, no
registry (§6.3). A dead subagent is a message the parent pattern-matches on, and
exhaustiveness makes forgetting a case a compile error. Fifteen lines of `spawn` and
`monitor` is a supervisor — the plan says so explicitly, and for a fleet whose topology
changes every minute, that is a better fit than a static tree.

**Work can move to where it should run.** §8.7's code shipping with content-addressed
identity means "run this closure on the node with the GPU, the private data, or the right
network position" without a deployment step. Ray has placement; Unison has content
addressing; nothing has both with typed mailboxes.

**Deadlock is a verdict, not a mystery.** §8.6 ends a program that cannot progress, and the
runtime says so. In a fleet where a hundred processes wait on each other, that is a real
debugging feature.

**It is BEAM underneath.** Cheap processes, preemptive scheduling, hot code replacement
(§6.10), and an existing story for long-running services — the operational base is proven,
and the language is the new part.

### What is missing before the claim is honest

- **Durability and replay.** The largest gap, and the whole point of the category below.
  Ernest notifies on failure; it does not resume. There is no journal, no replay, no
  checkpoint, and `ProgramEnd` kills local processes outright. No MVP names a unit of
  durability.
- **Distribution is unbuilt.** `spawn(Peer(...))` and `remote` are MVP 3.0; content
  addressing proper is 3.1. Today `remote` answers `Left(NoRemotePeer)`.
- **Backpressure is convention.** `Slot(a)` is a sketch in the decisions log, deliberately
  not built. A fleet hammering a rate-limited endpoint is the bug everyone actually has.
- **Streaming.** §5.1 is strict; a token stream is a process, which is workable but unproven
  at size.
- **The stack.** HTTP, TLS and JSON are MVP 2.7–2.8; without them there is no talking to a
  model provider or an MCP server at all.
- **Observability.** `:processes` and `:faults` in the shell, and nothing else — no tracing,
  no metrics, no history of a fleet's run.
- **Nobody has written a large Ernest program.** The shell is the first, and it is the
  toolchain's own.

The honest summary: Ernest's *concurrency and protocol* story is ahead of the field; its
*durability, distribution and library* story does not exist yet. A killer app in this space
is therefore a forcing function, not a victory lap — and it argues for pulling MVP 3.0
forward.

---

Worth splitting the competition into three families, because Ernest competes with each on a
different axis.

## 1. Typed actors — the closest relatives

### Gleam + `gleam_otp`

The sharpest comparison: statically typed on BEAM, `Subject(msg)` as a typed address, typed
supervisors, selectors for receiving from several subjects.

- **Study it for:** what a typed actor API costs in ergonomics.
- **What Ernest has that it doesn't:** the mailbox effect in the function type (in Gleam
  *any* function may send), `Reply(a)` linearity, exhaustiveness on message handling.

### Akka Typed

The most mature typed-mailbox system anywhere. The scars are the interesting part.

- Protocol evolution across versions.
- Message adapters between actor protocols — Ernest's `via` is the same idea, but a value
  rather than a wrapper actor.
- The Receptionist: a registry, which Ernest refuses (§6.3). **Read it for *why* they needed
  one.**

### Orleans / Dapr virtual actors

Identity-based activation: actors addressed by name, re-activated on demand. Directly
opposed to §6.3's no-registry rule.

- **The question it forces:** if an agent must be reachable by id after a restart, this is
  the model Ernest has to answer.

---

## 2. Durable execution — where Ernest is genuinely behind

This is the category to read hardest, because it is what "agent orchestration" means
commercially in 2026.

**Projects:** Temporal (workflows as replayable code, activities, timers, signals), Restate,
DBOS, Inngest, Golem Cloud (durable WASM actors, invocation-level persistence).

**The problem they solve:** an agent runs for hours, the node dies, and the work must resume
with state intact.

**Where Ernest stands:** failure *notification* only — `Down` with the spawn site. No state
recovery, no replay, no journal.

> **The uncomfortable question:** if a process is the unit of concurrency, and processes are
> cheap and mortal, what is the unit of *durability*? Temporal answers "the workflow"; Golem
> answers "the actor invocation". Ernest has no answer yet.

---

## 3. Agent frameworks proper

| Project | What to take from it |
|---|---|
| **LangGraph** | The one to dissect: a graph of typed state transitions with pluggable checkpointers and human-in-the-loop interrupts. Steal the checkpointer and interrupt/resume *semantics*, not the Python plumbing. |
| **OpenAI Agents SDK**, **AutoGen / Microsoft agent framework**, **CrewAI** | Patterns for handoff between agents, tool calls, conversation state. All lack any compile-time guarantee about the protocol between agents — precisely Ernest's pitch. |
| **Ray** | Distributed actors plus tasks, with real placement control (GPU, data locality). The closest existing thing to §8.7's "ship the closure to the right node". |
| **MCP** | If tools are typed request/reply protocols in Ernest, an MCP bridge is the obvious interop story — and a good forcing function for `Foreign`, JSON and TLS. |

---

## 4. Unison — the philosophical competitor

Content-addressed code and distributed execution; Ernest already borrowed from it. Read
**Unison Cloud** for what shipping code across nodes feels like in practice.

- **Ernest's differentiator:** processes with typed mailboxes instead of an ability system —
  simpler and more Erlang-shaped.
- **Unison's advantage:** abilities give it durable and remote handlers that Ernest would
  need to express some other way.

---

## What the comparison suggests Ernest can do better

1. **The protocol is a type, and the compiler checks it** — no Python framework has this;
   Akka and Gleam have part of it.
2. **`Reply(a)` linearity** — "answered exactly once" as a compile error rather than a
   timeout log.
3. **The mailbox effect in the type** — you can tell from a signature that a function can
   send.
4. **Code shipping with content-addressed identity** — Unison's ground, with typed mailboxes
   added.
5. **`Deadlock` as a runtime verdict** — genuinely rare, and a real debugging feature for a
   fleet.

---

## What to fix before claiming the category

- **Durability / replay** — the big one.
- **Distribution** — MVP 3.0 and 3.1, unbuilt.
- **Observability** beyond `:processes` and `:faults`.
- **Backpressure** past the sketched `Slot(a)`.
- **Streaming** — Ernest is strict; a token stream is a process.
- **The HTTP / TLS / JSON stack** — still MVP 2.7–2.8.

---

## If you read one thing first

**Temporal's workflow determinism rules.** They constrain what code may do so it can be
replayed, and that constraint interacts with Ernest's purity/effect split in a way that
could be either a beautiful fit or a fundamental mismatch. Knowing which would shape MVP 3.
