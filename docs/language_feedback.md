# Language feedback

What writing Ernest has felt against the principles, as CLAUDE.md's *Defects and gaps* says,
and what a coherence reader found that questions a rule of the language rather than showing a
defect (`coherence.md`, *Readers*). This file holds each entry until a plan item decides it. An
entry ends in a report change, a "Later" entry in the log, a move into the plan as a question a
milestone decides, or a line saying it was weighed and left alone, and then it leaves this
file.

An entry keeps the number it was found under, since the plan, the log and the code cite it.
Sixty-one have been decided or moved to the plan; the next entry is 63.

62. **A long namespace is written at every use.** Found 2026-09-27 reading back
    `shell/shell.ern` after the rewrite of its function heads. A name from another module is
    written with its whole namespace, and the shell writes `Shell.Complete.` 43 times:
    `Shell.Complete.Name(text = text, kind = Shell.Complete.Value, shown = text)` is read for
    its namespace more than for what it builds. Principle 1 is where it bites, since the
    reader's eye goes to the repetition. Principle 3 holds either way: a shorter name that
    appears at the use site is still visible. A module alias, declared once at the top of a
    file, would be a second name for the same module (principle 2). The alternatives are an
    alias, a verdict that it stays as it is, or a module split so that most uses fall inside
    the module they name.
