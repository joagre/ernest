# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 89.

88. **One budget over several waits** (2026-10-01, C-18). Shape rule 8 bounds one request by its milliseconds, so `Os.run`, which holds one time over several reads and writes, computes `deadline - Clock.monotonic()` by hand before each, as every function that composes requests under one time will.
