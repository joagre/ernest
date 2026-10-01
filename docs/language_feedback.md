# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 89.

86. **`Test.` on every test** (2026-10-01, C-16). `Test` leaving the prelude puts `Test.Case`, `Test.Passed`, `Test.Failed` and `Test.Result` into every test, three qualified names a test, 68 in the shell's editor alone, with no way to bring one module's names in unqualified (principle 3, the log's *Names Stay Qualified, Without Import or Alias*).

87. **`NotUtf8` carries the whole file** (2026-10-01, C-17). `Io.NotUtf8(bytes)` was shaped for a name or a link's target, so a history file that is not UTF-8 is answered as `Left(NotUtf8(bytes))` with the whole file in it, which the shell reduces to one sentence.

88. **One budget over several waits** (2026-10-01, C-18). Shape rule 8 bounds one request by its milliseconds, so `Os.run`, which holds one time over several reads and writes, computes `deadline - Clock.monotonic()` by hand before each, as every function that composes requests under one time will.
