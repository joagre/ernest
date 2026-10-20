# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 133.

1. **A request with named fields is not a function.** Every `Address.call` of one writes `fn(reply) = Subscribe(topic = topic, name = name, subscriber = address, reply = reply)`, six lines once laid out, and the pattern repeats each field; a writer makes requests positional so that the call reads short, so the call chooses the messages' shape. The newcomer of 0.4.0's review, `pubsub`.
2. **`receiving M` spreads up the chain.** A helper that starts a monitored process on another's behalf must declare that process's mailbox type, and so must every function up to the one whose mailbox it is. The same newcomer.
3. **Addresses have no equality**, so a broker keeps two maps that must agree, name to address for delivery and `Process` to name for a `Down`, where one map keyed by the process would do. The same newcomer.
4. **A receive guard may not call `Process.fromAddress`**, and a precondition is `if c then fault(...) else Unit`, since `if` has no form without `else`. The same newcomer, minor.
117. **Where `Peer.compute` ran is invisible** (2026-10-20, MVP 3.27's measuring program for the push's experiment, `test/fixtures/bench/pick.ern`). The answer is `f`'s value alone, and `f` cannot name the node it runs on, since a node has no name for itself (§8.7). A program that would say or count where its work went writes its own pick over `Peer.utilizations()` and `Peer.computeAt`, or, as the measuring program does, calls a foreign function for the host's name of the node. Principle 3.

121. **A program cannot know its own version** (2026-10-20, the same). `VERSION` names the release, and a program that prints `--version` keeps the same text in a `let`, which a test holds equal to the file, two owners of one fact. Principle 4.

122. **A dependency is a directory, and nothing resolves one** (2026-10-20, the same). The template lists each dependency's release archive by its URL, unpacks it under `lib/`, builds it with the consumer's `ern` and puts `lib/*/build` on the load path, and a dependency's own dependencies are the consumer's to list, since the load path is all §11.2 has. Whether Ernest decides how a library is fetched, pinned and resolved is a decision of its own; until then the template follows the load path. Principle 2.

126. **No labeled arguments** (2026-10-20, the same). `blendArea(source, target, alpha, sourceX, sourceY, targetX, targetY, width, height)` is nine positional arguments, seven of them `Int`, and a swapped pair type-checks; the cold reader wrote a call by counting against the signature and called it the hardest part of the program. Principle 1.

128. **A nullary constructor crosses as its quoted spelling**, `'Argb'` (2026-10-20, the same). Every enumeration epx names by atom needs a hand-written match each way, `formatAtom` and `operationAtom` spelling twenty-three atoms, and the inverse scans a hand-kept list of the constructors, since a sum type's constructors cannot be enumerated. Principle 2.

129. **A record crosses as a tagged tuple**, `{'Color', A, R, G, B}` (2026-10-20, the same), so epx's `{A, R, G, B}` is converted on every call, in by a function and out by a match. Principle 2.

130. **A foreign declaration has one result type** (2026-10-20, the same), so `epx:pixmap_info_/2`, whose result's type depends on its key, is declared twice, at `Int` and at `Foreign.Term`. Principle 1.

132. **A deadline at the call is a bare number** (2026-10-20, the same). In `Fs.write(path, bytes, 5000)` nothing at the call says the `5000` is milliseconds to wait; both examples carry it and a reader looks it up in E.17. Principle 3.
