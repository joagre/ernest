# Ten significant contributions of Ernest to programming on BEAM

Ernest's contribution is the synthesis: Hindley–Milner inference, typed processes, explicit communication effects, checked reply ownership and a proposed model of code distribution. Some ingredients already exist elsewhere. The significance lies in how they work together.

The order below leads with the proposed distributed model, then the language mechanisms supporting it. Distribution and content addressing remain planned; their runtime design is tentative.

## 1. Remote execution that brings its code dependencies

**Planned.** Spawning a process on a peer transfers the function, its captured values and the code dependencies the peer lacks. Dependencies resolve before the process starts.

This makes code availability part of remote execution's contract. The programmer names where work runs, while the runtime obtains the required definitions.

Foreign implementations and system facilities must still be available and compatible on the peer.

## 2. Content-based identity for code and types

**Planned.** Functions and types are identified by their normalized definitions and dependencies. Type identity also includes the qualified name.

Different definitions under the same name remain distinct versions. An address carries its mailbox type's identity, so distributed communication depends on agreement about the actual protocol definition.

Code distribution and protocol compatibility therefore share one identity model.

## 3. A typed mailbox as part of the process model

Each process has one mailbox type. `Address(M)` identifies an address accepting messages of type `M`, and `receive` patterns are checked against that type.

Gleam already provides typed message passing through libraries. Ernest puts the mailbox into the core language and connects it directly to the functions running in the process.

The addition is the integration of process, address, receive operation and function effect around one protocol type.

## 4. Compiler-enforced separation of pure computation and process actions

A function without `with` is pure. A function that acts through its process carries a mailbox effect, such as `(Int) -> Unit with CounterMsg`.

The compiler checks that separation. Printing, sending, receiving and spawning cannot be introduced into a function explicitly declared pure.

Purity here does not imply termination or freedom from faults. It identifies whether computation acts through its process.

## 5. Higher-order functions that preserve communication effects

Effect polymorphism lets a higher-order function inherit the effect of its callback.

For example:

    ((a) -> b with e, a) -> b with e

The same function works with a pure callback or with one acting through a process. Effects compose without separate pure and effectful versions of ordinary higher-order operations.

This connects Hindley–Milner-style inference to the typed process model.

## 6. Reply obligations checked across ownership transfers

`Reply(a)` is consumed exactly once along statically checked paths. Answering consumes it; passing, returning or placing it in another value transfers responsibility.

The discipline extends to reply-carrying messages, records, tuples and lists. It therefore covers deferred answers and forwarding, rather than requiring the first handler to answer immediately.

This is a static ownership guarantee. It does not guarantee successful delivery, eventual completion or exactly-once external effects.

## 7. Typed address adaptation without a forwarding process

`via(target, convert)` exposes an address accepting one type while delivering converted messages to the target's mailbox.

A worker can report through a small protocol without knowing the application's complete mailbox type. The application adapts the address when connecting the components.

This provides typed protocol composition without adding a forwarding process. Adaptation also has explicit execution and fault-attribution rules.

## 8. Restart in place while preserving addresses

`restarting` reruns a process's function after a fault while retaining its address. Supervised children likewise restart in place.

Clients can keep their existing addresses. Restart resets the process's execution state and mailbox, cancels its runtime subscriptions and ends calls waiting for its answer.

The addition is a recovery contract organized around stable addresses. Preserving an address does not preserve the service's state.

## 9. Explicit, typed replacement of a running process's behaviour

A protocol can carry a replacement loop and a state-migration function. The process handles that message and tail-calls the replacement with the migrated state.

Code replacement becomes an ordinary protocol operation whose function types are checked. The process explicitly chooses when to switch.

BEAM already supports hot code loading. Ernest adds a typed application-level mechanism for changing behaviour within the declared state and mailbox contract.

## 10. Failure handling reinforced by rules against silent discard

Recoverable failures appear as values or messages; faults end or restart a process. Request calls expose missing answers through a deadline.

A block statement before the final expression must have type `Unit`. Consequently, an error-bearing result cannot simply disappear as an expression statement: the program must handle it or explicitly discard it with `let _ = ...`.

Reply ownership adds a stronger rule where a response obligation is involved. Together, these mechanisms make handling, forwarding and abandonment visible.

## The combined proposition

Ernest combines inferred functional types with typed process protocols, communication effects and reply ownership. Its proposed distribution model extends that combination across nodes through code resolution and content-based type identity.

The strongest claim is that these mechanisms share one programming model. Static checks govern what can communicate and who owns a reply; explicit runtime contracts govern what happens when execution, recovery or distribution fails.
