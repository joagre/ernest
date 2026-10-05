# Report feedback

Three points of precision in the report's contracts, of six from a read of the report on
2026-10-04 by a reader outside the project. The other three, what a call's time bounds, an
order's laws, and the foreign boundary's summaries, were taken into the report on
2026-10-05 (the log's *The Report's Feedback, Three Points*). These three are of peers, and
any answer to one is a rule of the language: MVP 2.99d's item 4 reads each with the user and
weighs it against MVP 3.0 and 3.1, which build them, and a point leaves this file when it is
decided. The reader's text is kept as written, in the reader's voice, under its own number.
Each point was checked against the report and the code on 2026-10-04, and its *Checked.*
note says what was found.

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
