# Language feedback

What writing Ernest has felt against the principles: a workaround that should not be needed,
a second way, something invisible, a function the standard library lacks, or code that is a
library's work (CLAUDE.md's *Defects and gaps*). This file holds each entry until a plan item
decides it. An entry ends in a report change, a "Later" entry in the log, a move into the plan
as a question a milestone decides, or a line saying it was weighed and left alone, and then it
leaves this file.

An entry keeps the number it was found under, since the plan, the log and the code cite it.
Sixty have been decided or moved to the plan; the next entry is 62.

61. **A client cannot tell when a group's restart is over.** Found 2026-09-27 writing
    `examples/services.ern` (MVP 2.66). After a service faults, its supervisor asks its
    siblings to restart, and each restarts at its next wait. A call made meanwhile to a
    sibling is answered from its old state, ends (a `callForever` faults with `callee was
    restarted`, a `call` answers `None`, report §6.6), or is answered from its new state,
    and nothing tells which. The example and the guide's §6.6 pause 500 ms before they ask
    again, which is a guess at a timing. Erlang has the same
    window, where a call to a name between death and re-registration fails. Options to
    weigh: nothing, since a robust client uses `Address.call` and asks again; a
    `Supervisor` function that answers once no child has a restart pending; or a
    subscription to the group's restarts.

