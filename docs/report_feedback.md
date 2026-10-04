# Report feedback

Six points of precision in the report's contracts, from a read of the report on 2026-10-04
by a reader outside the project. MVP 2.99d's item 4 decides each, read point by point as a
review's findings are: a sentence of the report, a plan item, or dropped with its reason; a
point leaves this file when it is decided. The reader's text is kept as written, in the
reader's voice. Each point was checked against the report and the code on 2026-10-04, and its
*Checked.* note says what was found.

**The useful enhancements are tighter semantic contracts, without changing the section order or making the report instructional.**

From this pass, I would prioritize the following. These are precision issues and clarification candidates, not a claim that the report needs redesign.

**1. Define foreign-definition compatibility — §8.7.**

Resolution can fail because a foreign definition is “incompatible”, but the compatibility test is not stated precisely.

Specify whether compatibility requires agreement on:

- Qualified name and host implementation identifier.
- Arity, parameter types, result type and mailbox effect.
- Inferred restrictions and foreign-type parameter constraints.
- ABI or runtime version.

Distinguish compatibility of the declared interface from trust that the foreign implementation fulfils its promises. Two implementations can have identical signatures and different behaviour.

*Checked.* Holds. §8.7 names "an incompatible foreign definition" as a resolution failure
and says nowhere what is compared. Not built; weighed against MVP 3.1, where the hash of a
`foreign fn` is defined.

**2. Complete the contract for peer-side initialization — §8.7, referring to §8.5.**

The report specifies initialization on first use, at most once per node per binding hash, and faults the process that first uses a failing initializer. The remaining cases need explicit outcomes:

- Two processes concurrently use an uninitialized binding.
- The initializer faults: is that failure cached, or can another use retry?
- The initiating process dies or restarts during initialization.
- An initializer accesses dependencies that have not been initialized.
- The initializer does not terminate.

Also state the execution context. Locally, initializers run in the entry process with mailbox type `Never`. On a peer, specify which process evaluates them and what `self()` identifies.

“At most once” settles duplicate evaluation, but does not settle what waiting readers observe.

*Checked.* Holds. §8.7 says "on first use, in the peer's environment, at most once per node
for each hash of its definition", and none of the five cases, nor the process that evaluates.
Not built; weighed against MVP 3.0.

**3. Define exactly what a request deadline bounds — §6.6.**

The clock starts at the call, but the call must also evaluate `request(r)` and potentially apply an adapted address’s conversion function. Both functions can run indefinitely.

Specify:

- Where the request callback runs.
- Whether expiry can interrupt request construction or address adaptation.
- Whether a request is sent if construction finishes after the deadline.
- Whether `ms` bounds the entire operation or only its waiting phase.

This matters because a pure callback is not necessarily terminating. The wording should not accidentally promise a bounded return when some preceding computation is unbounded.

*Checked.* Holds, and it is the one point about code that runs today. §6.6 says "The clock
starts at the call" and no more. `ern_rt:call/4` takes the deadline first, evaluates
`request(r)` in the caller, which nothing interrupts, sends the request whether or not the
deadline has passed, and waits until the deadline, at once where it has passed: `ms` bounds
the wait, counted from the call, and not the request's construction. An adapted address's
function is applied by the send, in the caller, as §6.5 says of every `send`, after the
deadline is taken and uninterrupted too. §6.6's sentence states that, or the code changes.

**4. State ordering laws and their consequences — §3.10 and the relevant library entries.**

The report specifies the shape of `compare`, but I did not find a contract for its ordering laws.

Define the properties required for sorting and ordered collections: reflexivity of `Equal`, reversal symmetry, transitivity, and consistency of the equivalence classes formed by `Equal`.

Then specify what guarantees remain when a user-supplied comparison violates those properties. The compiler need not prove the laws; the report should identify the premise behind the library’s guarantees.

Also make the relationship between comparison equality and structural equality explicit. Appendix E.25 already says that elements compared as `Equal` count as one element. Consequently, two sets can represent the same comparison classes while holding structurally different representatives. Their `==` need not be true.

*Checked.* Half holds. The report has no contract for `compare`'s laws; E.25 has only "Two
elements the order calls `Equal` are one element". The contract is written already, in
[`operations.md`](operations.md) under *What the types do not guarantee*: a total order,
`Equal` only where `==` holds, and what breaks otherwise. It goes to §3.10, with E.25 and
E.26 pointing at it.

**5. Resolve whether peer loss must have a distinguishable reason — §§9.3 and 10.**

Peer loss is represented as `Fault("peer lost")`. A program can produce the same reason with `fault("peer lost")`.

Your [node-protocol note](node_protocol.md#12-open-questions), question 6, already identifies this issue. The normative decision belongs in the report:

- Either peer loss has a distinct reason constructor.
- Or identical fault text deliberately makes the origins indistinguishable.

The report should make that choice explicit, particularly if clients are expected to choose different recovery actions.

*Checked.* Holds, and it is a contradiction rather than an omission: §10 requires that "`Down`
carries a reason distinguishable from every other", which a process calling
`fault("peer lost")` breaks as the report stands. The plan's MVP 3.0 names `Unreachable` for
it, which §9.3's `Reason` would gain; the decision changes §9.3 or §10.

**6. Make foreign-boundary checking qualifications consistent — §§4.7, 7.4 and 8.4.**

§8.4 carefully describes unchecked runtime boundaries and the limits of checking polymorphic foreign returns. Other passages describe mismatches as checked to the value’s whole depth.

Those statements should explicitly inherit §8.4’s exceptions. Otherwise, someone reading §7.4 alone can reasonably conclude that a polymorphic return is validated against its concrete instantiation, which the `weird` example explicitly disproves.

Keep the full rule in §8.4 and qualify the summaries through precise cross-references.

*Checked.* Holds. §7.4 says a foreign function's return and a reply are checked "to the
value's whole depth" and cites §8.4 for the reply alone. §8.4 exempts what passes between
the runtime's own modules and a program, and a type variable a parameter's type names, which
"matches any value". §7.4's sentence takes §8.4's exceptions by reference.

I would address **foreign compatibility, peer initialization and deadline scope first**. Those affect observable behaviour and permit materially different implementations under the current wording. All these changes fit within the existing sections.

*Checked.* The order differs here: points 3, 4 and 6 first, since they describe what runs or
is written today, and points 1, 2 and 5 with the peers they belong to, as the plan's item 4
says.
