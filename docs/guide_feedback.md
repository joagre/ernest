# Guide feedback

A pedagogical assessment of the guide, from a read on 2026-10-04 by a reader outside the
project, who compared it with the report and did not run its examples. MVP 2.99d's item 5
decides each point: taken into the guide, made a plan item, or dropped with its reason; a
point leaves this file when it is decided. Of its seven, three left on 2026-10-05: point 1,
the reader, decided with the user as one who has used a functional language, processes
taught from the start; point 2, which asks for nothing; and point 7, the accuracy issues,
each fixed. The reader's text is kept as written, in the reader's voice, under its own
number. Each point was checked against the guide and the report on 2026-10-04, and its
*Checked.* note says what was found.

For programmers already familiar with functional programming and message-passing concurrency, the guide's overall teaching order is appropriate. It progresses from values and functions to protocols, process lifetime, failure, modules and external boundaries.

The main improvements concern the presentation of Ernest-specific rules, the size of certain examples and a few accuracy issues. A broad restructuring is unnecessary.

This assessment is based on reading the guide and comparing relevant rules with the report. The examples have not been independently compiled.

## 3. Separate ordinary use from advanced restrictions

Some explanations introduce too many Ernest-specific rules together.

For example, the first explanation of `spawn` combines:

- The relationship between the callback's mailbox effect and the resulting address.
- Spawning pure callbacks.
- Unresolved mailbox types.
- Different treatment of local, top-level and shell bindings.
- Explicit selection of `Never`.

Teach the ordinary case first: spawning a function with `with CounterMsg` produces an `Address(CounterMsg)`. Then explain pure callbacks and unresolved mailbox types in a separate subsection.

Apply the same structure elsewhere:

| Topic | First explanation | Subsequent explanation |
|---|---|---|
| Replies | Answer once; forwarding transfers responsibility | Reply-carrying containers, captures and non-returning paths |
| Type inference | Types follow from usage; ambiguous operations need annotations | Generalization and unresolved-variable rules |
| Effects | No `with` means pure; `with M` identifies the mailbox | Effect polymorphism and process-only restrictions |
| Top-level bindings | Evaluation before `main` | Effectful initialization and service bindings |
| Shell | Evaluation, bindings, `:type` and `:doc` | Completion, reload lifecycle and startup behaviour |

Keep restrictions needed for correct ordinary use near their constructs. Put inference edge cases and advanced consequences after readers have used the basic mechanism.

*Checked.* Holds for `spawn`: §4.1 gives the ordinary case in one paragraph, and the next
takes pure callbacks, a mailbox type nothing settles, and `Never` at once. The table's other
rows were not checked one by one. The largest of the seven to act on.

## 4. Divide §7.3 into three focused lessons

§7.3 combines three distinct mechanisms:

| Purpose | Mechanism |
|---|---|
| Obtain a type's own operation in generic code | A requirement such as `needs a.compare` |
| Write an algorithm over different representations | An operations record |
| Put values of different representations in one collection | A record of closures |

Each deserves its own explanation and small example.

### Requirements

Use `unique` or a similarly small function to demonstrate:

- Where `needs a.compare` is written.
- How the body accesses the operation.
- How a concrete call supplies the type's member.
- How a generic caller propagates the requirement.
- What happens when the requirement is omitted.

The complete ordered-set implementation is unnecessary for this first explanation.

### Operations records

Declare a record containing only the operations one example algorithm needs. Show the same algorithm called with records built from two representation modules.

Explain what the representation parameter preserves: operations in one call work on the same representation type.

### Records of closures

Show values of different representations sharing one record type because their functions capture the representation. Circles and squares provide a small example; the recursive `Bag` can follow as a more advanced application.

Explain the consequences explicitly: the representation is hidden, the values contain functions, and operations requiring access to two underlying representations need additional design.

Move the full `OrderedSet` implementation to a linked example or an optional implementation walkthrough.

*Checked.* Holds. §7.3 is about 2,200 words and opens with the ordered set's implementation
before a requirement has been seen in a small function. The three lessons fit as three headed
parts of §7.3, so no section is renumbered. It reverses a choice of MVP 2.99b's, that
`ordered_set.ern` is the section's example, so it is decided with the user.

## 5. Reduce prose density

The guide sometimes places several independent rules in one sentence or paragraph. This is particularly noticeable in §2.9's system-module discussion and §6.6's supervision explanation.

Organize explanations around individual behaviours:

1. What the operation does.
2. A small example.
3. The important limitation.
4. Advanced consequences.

For supervision, distinguish restart strategy, restart timing, state loss, waiting calls, restart limits and shutdown order. These interact, but presenting them separately makes those interactions easier to understand.

Precision does not require compressed prose.

*Checked.* Holds, and CLAUDE.md's *Clear before short* says the same: one rule per sentence.
§3.3's bullet on what is polymorphic holds five rules in one item.

## 6. Focus exercises on Ernest-specific distinctions

Prediction exercises suit the intended audience. Their strongest subjects are rules readers cannot safely import from another language:

- Omitting an annotation versus explicitly declaring purity.
- Effect polymorphism versus a process-only effect.
- Answering a reply versus transferring its obligation.
- Timeout versus cancellation.
- Per-sender ordering versus ordering between senders.
- Stable addresses versus state lost during restart.
- A representation preserved by an operations record versus hidden by closures.

Replace elementary questions such as §2.11's “Does `p` change?” with questions about Ernest's own rules. For example, ask which field selections or updates compile for a type with several constructors.

Occasional modification exercises would also help: add a request to a protocol, repair a rejected reply path, or propagate a requirement through a generic function.

*Checked.* The list of distinctions stands whoever the reader is. Replacing §2.11's question
follows from point 1's narrower reader and is decided with it.

## Recommended scope of revision

Retain the chapter order and the developing word-counter example. State the prerequisites, correct the accuracy issues, divide §7.3, separate first-use explanations from advanced restrictions, and sharpen the exercises.

For the intended audience, the guide needs more deliberate staging of Ernest-specific knowledge, rather than more introductory material.
