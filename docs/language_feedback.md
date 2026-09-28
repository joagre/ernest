# Language feedback

What writing Ernest has felt against the principles, as CLAUDE.md's *Defects and gaps* says,
and what a reader found that questions a rule of the language rather than showing a
defect. This file holds each entry until a plan item decides it. An
entry ends in a report change, a "Later" entry in the log, a move into the plan as a question a
milestone decides, or a line saying it was weighed and left alone, and then it leaves this
file.

An entry keeps the number it was found under, since the plan, the log and the code cite it.
Sixty-one have been decided or moved to the plan; the next entry is 64.

62. **A long namespace is written at every use.** Found 2026-09-27 reading back
    `shell/shell.ern` after the rewrite of its function heads. A name from another module is
    written with its whole namespace, and the shell writes `Shell.Complete.` 43 times:
    `Shell.Complete.Name(text = text, kind = Shell.Complete.Value, shown = text)` is read for
    its namespace more than for what it builds. Principle 1 is where it bites, since the
    reader's eye goes to the repetition. Principle 3 holds either way: a shorter name that
    appears at the use site is still visible. A module alias, declared once at the top of a
    file, would be a second name for the same module (principle 2). The alternatives are an
    alias, a verdict that it stays as it is, or a module split so that most uses fall inside
    the module they name. The formatter's first run (MVP 2.8) made it cost columns as well: a
    bracket's items align after the qualified name, so `Shell.Complete.Name(` puts its fields
    at column 60 and more, and the shell's `"timing"` arm had no layout within 100 columns
    until the writer named a value.

63. **A list with a separator between its elements has no function.** Found 2026-09-28
    writing `libs/markdown`'s `roff`, where a paragraph's lines stand with roff's `.br`
    between them. `List.intersperse(lines, ".br")` was reached for first, and Appendix E.0
    rule 2's sequence vocabulary has no such function, while text has `String.join` for the
    same shape. The code reads `first :: List.flatMap(rest, fn(line) = [".br", line])`,
    which says it less directly. Rule 4 does not refuse it, since it is no pipe of two
    functions already there, so rules 2 and 3 would weigh it as a general operation of a
    sequence, Haskell's `intersperse` and Gleam's `list.intersperse`.
