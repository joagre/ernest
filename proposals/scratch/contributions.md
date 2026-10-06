# Ten significant contributions of Ernest to programming on BEAM

Ernest's contribution is the synthesis: Hindley–Milner inference, typed processes, explicit communication effects, checked reply ownership, a checked boundary to foreign code and a proposed model of code distribution. Most of the ingredients exist elsewhere, and each section names where. The significance lies in how they work together, and in bringing them to BEAM.

The first eight are built and tested. The last two, distribution and content addressing, are planned, and their runtime design is tentative. Each section ends with links to the sections of Ernest's language report that state its rules.

## 1. A typed mailbox as part of the process model

Each process has one mailbox type. `Address(M)` identifies an address accepting messages of type `M`, and `receive` patterns are checked against that type.

Typed actors are not new: Akka Typed has them, and Gleam provides typed message passing on BEAM through libraries. Ernest puts the mailbox into the core language and connects it directly to the functions running in the process.

The addition is the integration of process, address, receive operation and function effect around one protocol type.

In the report: [§6.1, The mailbox type](https://github.com/joagre/ernest/blob/main/report/language.md#61-the-mailbox-type), [§6.3, `receive`](https://github.com/joagre/ernest/blob/main/report/language.md#63-receive), [§6.5, Addresses](https://github.com/joagre/ernest/blob/main/report/language.md#65-addresses).

## 2. Compiler-enforced separation of pure computation and process actions

A function without `with` is pure. A function that acts through its process carries a mailbox effect, such as `(Int) -> Unit with CounterMsg`.

The compiler checks that separation. Printing, sending, receiving and spawning cannot be introduced into a function explicitly declared pure.

Purity here does not imply termination or freedom from faults. It identifies whether computation acts through its process.

In the report: [§6.1, The mailbox type](https://github.com/joagre/ernest/blob/main/report/language.md#61-the-mailbox-type), [§3.9, Type variables and polymorphism](https://github.com/joagre/ernest/blob/main/report/language.md#39-type-variables-and-polymorphism).

## 3. Higher-order functions that preserve communication effects

Effect polymorphism lets a higher-order function inherit the effect of its callback.

For example:

    ((a) -> b with e, a) -> b with e

The same function works with a pure callback or with one acting through a process. Effects compose without separate pure and effectful versions of ordinary higher-order operations.

Effect polymorphism is Koka's idea, among others'. Ernest has one effect, the mailbox, where Koka has rows of them, and that one effect is what connects Hindley–Milner-style inference to the typed process model.

In the report: [§3.9, Type variables and polymorphism](https://github.com/joagre/ernest/blob/main/report/language.md#39-type-variables-and-polymorphism).

## 4. Reply obligations checked across ownership transfers

`Reply(a)` is consumed exactly once along statically checked paths. Answering consumes it; passing, returning or placing it in another value transfers responsibility.

The discipline extends to reply-carrying messages, records, tuples and lists. It therefore covers deferred answers and forwarding, rather than requiring the first handler to answer immediately.

This is linear typing, the idea behind Rust's ownership, applied to one type only: every other value is copied and dropped freely. It is a static ownership guarantee. It does not guarantee successful delivery, eventual completion or exactly-once external effects.

In the report: [§6.6, Request-reply](https://github.com/joagre/ernest/blob/main/report/language.md#66-request-reply).

## 5. Typed address adaptation without a forwarding process

`via(target, convert)` exposes an address accepting one type while delivering converted messages to the target's mailbox.

A worker can report through a small protocol without knowing the application's complete mailbox type. The application adapts the address when connecting the components.

This provides typed protocol composition without adding a forwarding process. Adaptation also has explicit execution and fault-attribution rules.

In the report: [§6.5, Addresses](https://github.com/joagre/ernest/blob/main/report/language.md#65-addresses).

## 6. Restart in place while preserving addresses

`restarting` reruns a process's function after a fault while retaining its address. Supervised children likewise restart in place.

Clients can keep their existing addresses. Restart resets the process's execution state and mailbox, cancels its runtime subscriptions and ends calls waiting for its answer.

The addition is a recovery contract organized around stable addresses. Preserving an address does not preserve the service's state.

In the report: [§6.9, Death](https://github.com/joagre/ernest/blob/main/report/language.md#69-death).

## 7. A boundary to foreign code that is checked as values cross it

Erlang code enters through declared foreign functions, foreign types and foreign processes. What the foreign side gives is checked against the declared type where it crosses: a function's return when it returns, an answer when the call returns it, a message on delivery.

A breach is a fault in a named process, with a cause that names the declared type, and not a value of the wrong shape travelling on into typed code. Gleam's foreign functions, by contrast, are trusted at their declared types.

The check catches a foreign side's mistake and confines nothing. Purity declared on a foreign function is trusted, the standard library's own foreign code is not checked, and a value whose type the caller chose is taken as given.

In the report: [§4.7, Foreign declarations](https://github.com/joagre/ernest/blob/main/report/language.md#47-foreign-declarations), [§8.4, Foreign code](https://github.com/joagre/ernest/blob/main/report/language.md#84-foreign-code).

## 8. Failure handling with nothing silently discarded

Recoverable failures appear as values or messages; faults end or restart a process. A call to another process carries a deadline, so a missing answer is a case the program handles.

A result cannot disappear as a statement: a statement before a block's last expression has type `Unit`, so the program handles an error-bearing result or discards it in writing, with `let _ = ...`. Reply ownership adds the stronger rule where a response is owed.

Each rule has precedent, in Erlang's faults as messages, Rust's `must_use`, and Gleam's results as values. Together they make handling, forwarding and abandonment visible.

In the report: [§7, Errors](https://github.com/joagre/ernest/blob/main/report/language.md#7-errors), [§5.4, Blocks](https://github.com/joagre/ernest/blob/main/report/language.md#54-blocks), [§6.6, Request-reply](https://github.com/joagre/ernest/blob/main/report/language.md#66-request-reply).

## 9. Remote execution that brings its code dependencies

**Planned.** Spawning a process on a peer transfers the function, its captured values and the code dependencies the peer lacks. Dependencies resolve before the process starts.

This makes code availability part of remote execution's contract. The programmer names where work runs, while the runtime obtains the required definitions. The idea is Unison's; Ernest brings it to typed processes on BEAM, in place of Erlang's distribution of modules by name.

Foreign implementations and system facilities must still be available and compatible on the peer.

In the report: [§8.7, Code shipping](https://github.com/joagre/ernest/blob/main/report/language.md#87-code-shipping), [§8.3, Peers](https://github.com/joagre/ernest/blob/main/report/language.md#83-peers).

## 10. Content-based identity for code and types

**Planned.** Functions and types are identified by their normalized definitions and dependencies, as in Unison. A type's identity also includes its qualified name.

Different definitions under the same name remain distinct versions. An address carries its mailbox type's identity, so distributed communication depends on agreement about the actual protocol definition.

Code distribution and protocol compatibility therefore share one identity model.

In the report: [§8.7, Code shipping](https://github.com/joagre/ernest/blob/main/report/language.md#87-code-shipping).

## The combined proposition

Ernest combines inferred functional types with typed process protocols, communication effects, reply ownership and a checked foreign boundary. Its proposed distribution model extends that combination across nodes through code resolution and content-based type identity.

Some things need no mechanism of their own. Replacing a running process's behaviour is a message that carries the next loop and a function migrating the state, both checked as any function is; BEAM's hot code loading stays underneath, and the process chooses when to switch ([§6.10, Code replacement](https://github.com/joagre/ernest/blob/main/report/language.md#610-code-replacement)).

The strongest claim is that these mechanisms share one programming model. Static checks govern what can communicate and who owns a reply; explicit runtime contracts govern what happens when execution, recovery, foreign code or distribution fails.
