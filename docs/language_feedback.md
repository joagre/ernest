# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 117.

1. **A request with named fields is not a function.** Every `Address.call` of one writes `fn(reply) = Subscribe(topic = topic, name = name, subscriber = address, reply = reply)`, six lines once laid out, and the pattern repeats each field; a writer makes requests positional so that the call reads short, so the call chooses the messages' shape. The newcomer of 0.4.0's review, `pubsub`.
2. **`receiving M` spreads up the chain.** A helper that starts a monitored process on another's behalf must declare that process's mailbox type, and so must every function up to the one whose mailbox it is. The same newcomer.
3. **Addresses have no equality**, so a broker keeps two maps that must agree, name to address for delivery and `Process` to name for a `Down`, where one map keyed by the process would do. The same newcomer.
4. **A receive guard may not call `Process.fromAddress`**, and a precondition is `if c then fault(...) else Unit`, since `if` has no form without `else`. The same newcomer, minor.
5. **A call to many processes at once** is §4.4's `gathered`, thirty-five lines a use; a publication delivered by one call after another lets a slow subscriber hold the sender a deadline each time. The same newcomer.

114. **A function type written as Gleam writes one** (2026-10-20, the programs written to try every fault's trace), `fn(Int) -> Int`, is refused with "`fn` is a reserved word, and names nothing", which does not name the type's form, `(Int) -> Int`. Principle 1.

115. **The unit value written `()`** (2026-10-20, the same programs), as Gleam, OCaml and Haskell write it, is refused with "expected an expression instead of `)`", which does not name `Unit`. Principle 1.

116. **A constructor of several fields matched by position** (2026-10-20, the same programs), `Down(_, _)`, is refused by the parser with "expected `)` instead of `,`", where the same shape in a declaration has "a constructor has exactly one positional field" and its help. Principle 1.
