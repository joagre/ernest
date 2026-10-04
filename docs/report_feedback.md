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

**2. Complete the contract for peer-side initialization — §8.7, referring to §8.5.**

The report specifies initialization on first use, at most once per node per binding hash, and faults the process that first uses a failing initializer. The remaining cases need explicit outcomes:

- Two processes concurrently use an uninitialized binding.
- The initializer faults: is that failure cached, or can another use retry?
- The initiating process dies or restarts during initialization.
- An initializer accesses dependencies that have not been initialized.
- The initializer does not terminate.

Also state the execution context. Locally, initializers run in the entry process with mailbox type `Never`. On a peer, specify which process evaluates them and what `self()` identifies.

“At most once” settles duplicate evaluation, but does not settle what waiting readers observe.

**3. Define exactly what a request deadline bounds — §6.6.**

The clock starts at the call, but the call must also evaluate `request(r)` and potentially apply an adapted address’s conversion function. Both functions can run indefinitely.

Specify:

- Where the request callback runs.
- Whether expiry can interrupt request construction or address adaptation.
- Whether a request is sent if construction finishes after the deadline.
- Whether `ms` bounds the entire operation or only its waiting phase.

This matters because a pure callback is not necessarily terminating. The wording should not accidentally promise a bounded return when some preceding computation is unbounded.

**4. State ordering laws and their consequences — §3.10 and the relevant library entries.**

The report specifies the shape of `compare`, but I did not find a contract for its ordering laws.

Define the properties required for sorting and ordered collections: reflexivity of `Equal`, reversal symmetry, transitivity, and consistency of the equivalence classes formed by `Equal`.

Then specify what guarantees remain when a user-supplied comparison violates those properties. The compiler need not prove the laws; the report should identify the premise behind the library’s guarantees.

Also make the relationship between comparison equality and structural equality explicit. Appendix E.25 already says that elements compared as `Equal` count as one element. Consequently, two sets can represent the same comparison classes while holding structurally different representatives. Their `==` need not be true.

**5. Resolve whether peer loss must have a distinguishable reason — §§9.3 and 10.**

Peer loss is represented as `Fault("peer lost")`. A program can produce the same reason with `fault("peer lost")`.

Your [node-protocol note](https://github.com/joagre/ernest/blob/main/docs/node_protocol.md#12-open-questions), question 6, already identifies this issue. The normative decision belongs in the report:

- Either peer loss has a distinct reason constructor.
- Or identical fault text deliberately makes the origins indistinguishable.

The report should make that choice explicit, particularly if clients are expected to choose different recovery actions.

**6. Make foreign-boundary checking qualifications consistent — §§4.7, 7.4 and 8.4.**

§8.4 carefully describes unchecked runtime boundaries and the limits of checking polymorphic foreign returns. Other passages describe mismatches as checked to the value’s whole depth.

Those statements should explicitly inherit §8.4’s exceptions. Otherwise, someone reading §7.4 alone can reasonably conclude that a polymorphic return is validated against its concrete instantiation, which the `weird` example explicitly disproves.

Keep the full rule in §8.4 and qualify the summaries through precise cross-references.

I would address **foreign compatibility, peer initialization and deadline scope first**. Those affect observable behaviour and permit materially different implementations under the current wording. All these changes fit within the existing sections.
