# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 136.

135. **Two modules of one library cannot share a private function** (2026-10-20, `ernest-epx`, `Epx.Gc` beside `Epx`). A declaration is private to its module or exported to every program (§4.2), so `Epx.Gc`, which checks a width and a color by the same rules and causes as `Epx`, writes the four checks again rather than export from `Epx` functions no caller should see; and since `Epx` cannot name a module that names it (§4.1), the tests of `Epx`'s drawing functions live in `Epx.Gc`, the one module that can make a context. Principle 2.
