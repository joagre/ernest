# The outlines

The outlines of the two documents still to write, Why and Features, begun
2026-10-13. The set of documents, where each lives, the order of writing and
Why's pieces are [`decisions.md`](decisions.md)'s. Once both documents are
begun, each outline is its document's skeleton, and this file goes.

## Why

It answers "why another language on BEAM" with one argument, the synthesis:
every piece has a parent elsewhere, and no runtime has had them together. The
pieces' names, their order and the fourth's subsections are
[`decisions.md`](decisions.md)'s; what each holds:

1. **The mailbox in the function's type.** Hindley-Milner typing with the
   mailbox in the signature, what a value may be used for, requirements,
   operators as members, one `compare` per type. Failure arrives in it: a
   monitor's `Down` is a message of the mailbox's type, and §7 tells value
   errors, message errors and faults apart. Precedent: ML for the types, Erlang for the mailbox and
   for faults as messages; nobody for the two in one signature.
2. **Checked replies.** A reply answered exactly once on every path, or the
   program does not compile; a callee's death ends the call with its cause.
   Precedent: linear types, which Rust made ordinary; nobody applied them to a
   request's reply on a mailbox.
3. **Purity in the type.** A function without `with` neither sends nor
   receives, and the compiler holds it to that. Precedent: Haskell, whose types
   keep the pure apart from IO; what Ernest adds is that the mark is the
   mailbox itself, the one mark a function type carries.
4. **Code by its hash, across nodes.** A definition has an identity by hash and
   a node holds what it has received. Bare nodes take code with a spawn too.
   Code moves only between peers that list each other, by key, over TLS, never
   a mesh. Precedent: Unison, which has no runtime of Erlang's kind.

Around the four: an opener stating the synthesis and naming the parents; a
chapter on the five principles and what they refuse, since it answers every
"why not X" at once, and holds §0's *Time*, that the runtime chooses no time of
its own and retries nothing; a chapter on how the language is made, the report,
the grammar that wins, a test per section, the soundness argument, the memory
loads, the log; a status chapter, plainly; and a FAQ: why not Erlang with
Dialyzer, why not Elixir, why not Gleam, why no type classes, why one mailbox
per process, why is the compiler so strict. The toolchain and the operator's
day stay as evidence, one paragraph each, not a tour.

A section's form is [`decisions.md`](decisions.md)'s. Everything a reader would
look up rather than be persuaded by, the library, the border to Erlang, the cost
numbers, the formatter, the shell's commands, goes to Features with one link
from here.

The test for adding a piece later: it has a precedent and a thing it adds, and
the synthesis weakens without it.

## Features

The inventory. One line a feature, grouped by the language, the library, the
toolchain, the runtime and the operator, each with its pointer into the guide
or the report, and nothing argued. The README's list today is its seed.
