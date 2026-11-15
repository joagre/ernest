# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, an item of a milestone, or a line in the log saying it was dropped and why. An entry keeps its number, which the plan, the log and the code cite; the next is 254.

253. **Base 16 answers an `Optional` that is never `None`.** `Int.toStringBase(n, 16)` is written at three sites, the shell's `escapedChar` and `hexByte` and `Http`'s chunk size. The first two write a default for the `None` and the third a fault, and base 16 gives none. Found 2026-11-15 by item 49's read-back (the log's *A Refusal Holds No Control Character*); the plan's MVP 4.17, item 54.
