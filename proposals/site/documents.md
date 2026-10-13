# The documents

A discussion note, begun 2026-10-13, beside [`site.md`](site.md). The set of
documents, where each lives and the order of writing are
[`decisions.md`](decisions.md)'s. This note keeps the outlines of the two
documents still to write, Why and Features, and what is open about them.

## Open

- **Why's pieces.** They are the guide's §0 list, "What Ernest adds"
  ([`decisions.md`](decisions.md)), so what that list holds is open. The
  outline below has failure as messages and code by content; the guide has
  purity in the type and one build on every node, stale since code crosses
  with a spawn; the draft `but_why.md` has six sections.

## `but_why.md`

Answers "why another language on BEAM" with one argument, the synthesis: every
piece has a parent elsewhere, and no runtime has had them together. The
pieces, from the log's own sentence on what Ernest adds, the mailbox in the
function's type, checked replies, purity in the type, and distribution by
content on the Erlang runtime, and from the guide's two ideas:

1. **The mailbox in the function's type.** Hindley-Milner typing with the
   mailbox in the signature, purity as the absence of a mailbox, what a value
   may be used for, requirements, operators as members, one `compare` per type.
   Precedent: ML for the types, Erlang for the mailbox; nobody for the two in
   one signature.
2. **Checked replies.** A reply answered exactly once on every path, or the
   program does not compile; a callee's death ends the call with its cause.
   Precedent: linear types, which Rust made ordinary; nobody applied them to a
   request's reply on a mailbox.
3. **Code by content on the runtime.** A definition has an identity by hash and
   a node holds what it has received. Three consequences, each a subsection:
   any number of revisions at once, code traveling with a spawn to peers that
   lack it, bare nodes included, and work placed where there is room. The
   paragraph that makes it safe: code moves only between peers that list each
   other, by key, over TLS, never a mesh. Precedent: Unison, which has no
   runtime of Erlang's kind.
4. **Failure as messages, in the type.** A monitor's `Down` arrives as a
   message of the mailbox's type; a call ends with the callee's cause; §7.4's
   four kinds of failure; the runtime chooses no time of its own and retries
   nothing. Precedent: Erlang for faults as messages; nobody for them in the
   type.

Around the four: an opener stating the synthesis and naming the parents; a
chapter on the five principles and what they refuse, since it answers every
"why not X" at once; a chapter on how the language is made, the report, the
grammar that wins, a test per section, the soundness argument, the memory
loads, the log; a status chapter, plainly; and a FAQ: why not Erlang with
Dialyzer, why not Elixir, why not Gleam, why no type classes, why one mailbox
per process, why is the compiler so strict. The toolchain and the operator's
day stay as evidence, one paragraph each, not a tour.

The form of a section, settled on 2026-10-13 while the typing section was
drafted: state the rule, name its price before its gain, then a program and
the compiler's line about it, compiled before it is quoted, and a pointer to
the guide and the report. No sentence describes another language; no
superiority claim; no sentence answers an objection the text did not raise.
Everything a reader would look up rather than be persuaded by, the library,
the border to Erlang, the cost numbers, the formatter, the shell's commands,
goes to `features.md` with one link from here.

The test for adding a piece later: it has a precedent and a thing it adds, and
the synthesis weakens without it.

## `features.md`

The inventory. One line a feature, grouped by the language, the library, the
toolchain, the runtime and the operator, each with its pointer into the guide
or the report, and nothing argued. The README's list today is its seed.
