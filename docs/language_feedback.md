# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 64.

62. **A long namespace is written at every use** (2026-09-27). The shell writes `Shell.Complete.` over fifty times, as in `Shell.Complete.Name(text = text, kind = Shell.Complete.Value, shown = text)`, and the formatter aligns a bracket's items after the qualified name, at column 60 and more. It bites principle 1; principle 3 holds either way. A module alias would be a second name for the module (principle 2). The choices: an alias, a split so that most uses fall inside the module they name, or a verdict that it stays.

63. **A list with a separator between its elements has no function** (2026-09-28). `libs/markdown`'s `roff` puts `.br` between a paragraph's lines, and `List.intersperse(lines, ".br")` was reached for first; E.0 rule 2's sequence vocabulary has none, while text has `String.join`. Rules 2 and 3 would weigh it as a general operation of a sequence, as Haskell's `intersperse` and Gleam's `list.intersperse`.
