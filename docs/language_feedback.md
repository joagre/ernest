# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, an item of a milestone, or a line in the log saying it was dropped and why. An entry keeps its number, which the plan, the log and the code cite; the next is 249.

237. **A byte's class is written by hand in every library** (2026-11-10, the release review before 0.10.0, C401's L1). A bitstring pattern binds an `Int`, and `Char.isAsciiDigit` and `Char.digitValue` take a `Char`, so `isDigit` in `libs/http` and `libs/json`, `isHexDigit` in `libs/json`, `digit` in `libs/uri`, `isCharacter` and `place` in `libs/base64` and `isBlank` in `libs/http` each test a range, seven over `src/libs/`. The log's *The Libraries' Shims Read Against E.0 Rule 1* counted two sites and found no repeat. Asked: a byte's class in `Bytes`, or `Char`'s predicates over a code point.

238. **A list of lists is joined by `flatMap` with the identity** (2026-11-10, the release review before 0.10.0, C501's C523). `List.flatMap(lines, fn(each) = each)` stands 13 times in the site's generator. The log's *What MVP 2.95 Takes From the Rest* refused `List.concat` as one call of `flatMap` under E.0 rule 4. Asked: whether a form at 13 sites of one program changes rule 4's verdict.

239. **A walk that may fail and keeps nothing has no form** (2026-11-10, the release review before 0.10.0, C501's C523). `let _ <- List.tryMap(...)` throws away the list it builds, five times in the generator, for want of a `List.tryForEach`.

240. **A message is built from its pieces by `<>`** (2026-11-10, the release review before 0.10.0, C501's C523). `"cannot read " <> Path.toString(path) <> ": " <> Io.show(error)` and its like stand eight times in the generator, and `ern format` lays a long one an operand a line. Asked: whether a text with its values in place belongs to the library, under CLAUDE.md's rule on a general-purpose engine.

241. **Text is walked by turning it into a list** (2026-11-10, the release review before 0.10.0, C501's C523). `String.toList` stands 17 times in the generator to read a text's characters in order, since `String` has no span, no `takeWhile` and no character at an index.

242. **A result that only reports is discarded by a binding** (2026-11-10, the release review before 0.10.0, N's L1). `Clock.cancel` answers a `Bool` and `Clock.alarm` a `Clock.Alarm`, so a call made for its effect is `let _ = ...; Unit` at each site that does not want the answer: a helper of six lines around one call in the newcomer's program, and five sites of the guide's own code. The rule is principle 3's; the count is what it costs.

243. **`Bool` has no `compare`** (2026-11-10, the release review before 0.10.0, N's L2). `List.sort([true, false])` is refused, `sort needs Bool.compare, and Bool has no compare`, and so is `derives compare` on a record with a `Bool` field, so a record of flags cannot be sorted or held in an `OrderedSet` without a type of its own. Every ML orders `false` before `true`. The log's *One Name for Every Order* gives the refusal's words.

244. **`Peer.offer`'s `Left` is no failure** (2026-11-10, the release review before 0.10.0, N's L5). `Peer.offer` answers `Either(Process, Unit)`, whose `Left` is the holder to monitor, where the guide's §2.9 has a function with a cause answer its cause as the `Left`.

245. **A local that hides its module's own name is silent** (2026-11-10, the release review before 0.10.0, C401's L2). A `let sized` in a test of `libs/http` hides its top-level `fn sized`, and a parameter `headers` hides the module's `headers`, so the module writes its own function by its qualified name. Asked: a warning where a local hides a top-level name of its module.

246. **A check that faults has no form of its own** (2026-11-10, the release review before 0.10.0, C401's L3). `if cond then fault(cause) else Unit;` stands as a statement, or a module writes four `check` functions around it, as `libs/http`'s renderers do.

247. **`Char` gives no Unicode category** (2026-11-10, the release review before 0.10.0, C501's C524). The site's generator refuses a heading whose GitHub anchor turns on a character's category, so no heading of *Why Ernest*, the questions, the installing page, the releases or the projects can hold an em dash, a curly apostrophe or a `§`. It sharpens feedback 219's verdict with what the gap now costs.
