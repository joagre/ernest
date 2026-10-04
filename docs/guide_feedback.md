# Pedagogical assessment of the Ernest guide

For programmers already familiar with functional programming and message-passing concurrency, the guide's overall teaching order is appropriate. It progresses from values and functions to protocols, process lifetime, failure, modules and external boundaries.

The main improvements concern the presentation of Ernest-specific rules, the size of certain examples and a few accuracy issues. A broad restructuring is unnecessary.

This assessment is based on reading the guide and comparing relevant rules with the report. The examples have not been independently compiled.

## 1. State the prerequisites explicitly

The introduction should identify the knowledge the guide assumes:

> This guide teaches Ernest to programmers familiar with functional programming and message-passing concurrency. It assumes familiarity with immutable values, algebraic data types, pattern matching, higher-order functions and recursive process loops. No prior knowledge of Ernest or its report is required.

With this audience, the guide need not teach ordinary functions, recursion or immutability from first principles. It should explain where Ernest differs from familiar models.

## 2. Preserve the teaching backbone

Several features provide useful continuity:

- Complete programs with compilation commands and expected output.
- The word counter developed across §§2–5.
- Rejected programs and compiler diagnostics that explain language restrictions.
- Prediction exercises with answers.
- Explicit discussion of timeouts, message ordering and failure.

The rejected programs in §0 are appropriate for this audience. They demonstrate the practical consequences of typed mailboxes, checked replies, purity and explicit failure handling before the detailed explanations begin.

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

## 5. Reduce prose density

The guide sometimes places several independent rules in one sentence or paragraph. This is particularly noticeable in §2.9's system-module discussion and §6.6's supervision explanation.

Organize explanations around individual behaviours:

1. What the operation does.
2. A small example.
3. The important limitation.
4. Advanced consequences.

For supervision, distinguish restart strategy, restart timing, state loss, waiting calls, restart limits and shutdown order. These interact, but presenting them separately makes those interactions easier to understand.

Precision does not require compressed prose.

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

## 7. Correct accuracy issues

### §3.3: Generalization of block bindings

The statement that a `let` in a block is not polymorphic is too broad. Report §3.9 explicitly generalizes a block `let` whose value is a lambda.

State the exception and demonstrate it with a small example.

### §5.2: Worker results and monitor notifications

The worker example's `waitFor` returns `None` if `Down` arrives before `Result`. The following explanation permits that ordering, so the successful output shown is not guaranteed.

Either present the example as a demonstration of the race or use request-reply when successful result delivery is the intended lesson.

### §6.2: What a deadline establishes

A deadline does not distinguish a slow process from one that will never answer. It bounds the caller's wait.

Use wording such as:

> A deadline bounds how long the caller waits. `None` means no answer was obtained; it does not establish whether the recipient performed the work.

### Opening: Executable-example promise

Qualify the claim that every complete program compiles and prints the shown output.

Distinguish:

- Runnable examples supported by the current toolchain.
- Illustrative examples involving planned peer functionality.
- Rejected examples with expected diagnostics.
- Concurrent examples whose output order or success may vary.

Chapter 8 already acknowledges the implementation status of peers; the opening should be consistent with that qualification.

## Recommended scope of revision

Retain the chapter order and the developing word-counter example. State the prerequisites, correct the accuracy issues, divide §7.3, separate first-use explanations from advanced restrictions, and sharpen the exercises.

For the intended audience, the guide needs more deliberate staging of Ernest-specific knowledge, rather than more introductory material.
