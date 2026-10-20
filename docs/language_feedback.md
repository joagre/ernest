# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 125.

1. **A request with named fields is not a function.** Every `Address.call` of one writes `fn(reply) = Subscribe(topic = topic, name = name, subscriber = address, reply = reply)`, six lines once laid out, and the pattern repeats each field; a writer makes requests positional so that the call reads short, so the call chooses the messages' shape. The newcomer of 0.4.0's review, `pubsub`.
2. **`receiving M` spreads up the chain.** A helper that starts a monitored process on another's behalf must declare that process's mailbox type, and so must every function up to the one whose mailbox it is. The same newcomer.
3. **Addresses have no equality**, so a broker keeps two maps that must agree, name to address for delivery and `Process` to name for a `Down`, where one map keyed by the process would do. The same newcomer.
4. **A receive guard may not call `Process.fromAddress`**, and a precondition is `if c then fault(...) else Unit`, since `if` has no form without `else`. The same newcomer, minor.
5. **A call to many processes at once** is §4.4's `gathered`, thirty-five lines a use; a publication delivered by one call after another lets a slow subscriber hold the sender a deadline each time. The same newcomer.

114. **A function type written as Gleam writes one** (2026-10-20, the programs written to try every fault's trace), `fn(Int) -> Int`, is refused with "`fn` is a reserved word, and names nothing", which does not name the type's form, `(Int) -> Int`. Principle 1.

115. **The unit value written `()`** (2026-10-20, the same programs), as Gleam, OCaml and Haskell write it, is refused with "expected an expression instead of `)`", which does not name `Unit`. Principle 1.

116. **A constructor of several fields matched by position** (2026-10-20, the same programs), `Down(_, _)`, is refused by the parser with "expected `)` instead of `,`", where the same shape in a declaration has "a constructor has exactly one positional field" and its help. Principle 1.

117. **Where `Peer.compute` ran is invisible** (2026-10-20, MVP 3.27's measuring program for the push's experiment, `test/fixtures/bench/pick.ern`). The answer is `f`'s value alone, and `f` cannot name the node it runs on, since a node has no name for itself (§8.7). A program that would say or count where its work went writes its own pick over `Peer.utilizations()` and `Peer.computeAt`, or, as the measuring program does, calls a foreign function for the host's name of the node. Principle 3.


119. **The rules an Ernest program is written by are not installed** (2026-10-20, `ernest-template`, whose `TEMPLATE.md` at https://github.com/joagre/ernest-template records its design). `docs/style.md`'s *Every language*, *Ernest* and the glossary's *Ernest* part bind every Ernest program, and an installation holds the report and the guide but not them, so the template carries a verbatim copy, refreshed by hand. Were the file split into the rules of Ernest programs and the rules of this repository, and the first installed under `share/doc/ernest/`, a program's `CLAUDE.md` would import it there. Principle 4.

120. **A program cannot ask where Ernest's libraries are** (2026-10-20, the same). The template's `make lib` guesses from where `ern` is, `../lib/ernest/build/libs` and then `../build/libs`, which the installation and the checkout each lay out otherwise. A way for `ern` to say its library root, as the shell knows it, would make the guess a fact. Principle 3.

121. **A program cannot know its own version** (2026-10-20, the same). `VERSION` names the release, and a program that prints `--version` keeps the same text in a `let`, which a test holds equal to the file, two owners of one fact. Principle 4.

122. **A dependency is a directory, and nothing resolves one** (2026-10-20, the same). The template lists each dependency's release archive by its URL, unpacks it under `lib/`, builds it with the consumer's `ern` and puts `lib/*/build` on the load path, and a dependency's own dependencies are the consumer's to list, since the load path is all §11.2 has. Whether Ernest decides how a library is fetched, pinned and resolved is a decision of its own; until then the template follows the load path. Principle 2.

123. **An Erlang function that answers `ok` cannot be declared to answer `Unit`** (2026-10-20, `ernest-epx`, the shims over epx). `Unit` crosses as the atom `'Unit'`, so `foreign fn flip(pixmap : Pixmap) : Unit = "epx:pixmap_flip/1"` faults at its return with `foreign return does not match Unit`, and a shim over such a function is declared at `Foreign.Term` and its answer dropped, `let _ = rawFlip(pixmap); Unit`, thirteen times in one module. Principle 1.

124. **A test that a function faults is a process, a monitor and a receive** (2026-10-20, the same). `Test` has `equal` and nothing for a fault, so a library writes its own helper that spawns the call under a monitor and reads the cause from the `Down`, and `ern test` then reports each expected fault on standard error with its trace among the passes, nine in one run, as it reports one no test expected. Principle 1.
