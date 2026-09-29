# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 68.

64. **A record of operations cannot hold a polymorphic operation** (2026-09-28). An operations record, `SetOps(s, a)`, cannot hold `Set.foldLeft`: the field `fold : (s, b, (b, a) -> b) -> b` is refused, `type variable b is not a parameter of the type`. An effect variable may be a parameter of the record, but one record value then fixes one effect for all its operations. A Haskell class method and a Java generic method are polymorphic in such a variable, and nine of `Set`'s twenty functions mention one besides the set and its element, so it bites principle 1 where the contract is to stand for a library type. The choices: a field's type quantifies the variables the type does not take, as OCaml's polymorphic record fields do, checked where the record is built and instantiated where a field is selected, so that inference stays Hindley-Milner's; or the verdict that a contract holds what its types close over, the rest written over its `toList`. The first is much smaller than type classes, with no instance resolution, no constraint in an inferred type and no hidden argument, and it still puts a type scheme inside a type declaration, where the log's *Dropped from Unison* drops rank-n types. A field's own variable carries no inferred restriction, since none is written, so a value that needs one, `==` on it, does not fit the field. `map` and `filterMap` need a representation for the result's element, which neither choice gives, as neither Haskell's `Data.Set` nor Java's `Set` has one. MVP 2.99b takes it first, after the first release; [`operations.md`](operations.md) proposes the second choice, a record of the primitives.

68. **A restart keeps the old run's messages (2026-09-28)**. restarting and a Supervisor's restart run f() again in the same process, which keeps its address and its mailbox (§6.9). What waits in that mailbox belongs to the run that faulted:
      - Requests whose callers were ended with "callee was restarted" (§6.6). The new run answers them to replies no one waits for, or acts on them twice when the caller asks again.
      - What the old run asked the runtime for: alarms, Downs and events (Clock.alarm, monitor, Terminal.subscribe). They arrive wrapped in the mailbox type, and the new run cannot tell them from its own.
      - Plain sends, the only ones that still mean what they meant.

      A reader who knows that a restart begins f() afresh would predict an empty mailbox (principle 1). A message from a run that no longer exists acts unseen (principle 3). In Erlang, a restarted process is a new one with an empty mailbox.

      The same invisibility loses a service's subscribers: the new run has forgotten them, and no monitor tells them (§6.9).

      The choices:
      - the mailbox emptied at a restart, and what the old run set up with the runtime (its alarms, monitors and subscriptions) cancelled with it, so that a restart is a new run in all but its address;
      - the rule as it stands, stated in §6.9, and taught with RestForOne for subscribers;
      - a restart made visible to the process's watchers, so that a subscriber can subscribe again.

      Maybe: the first. Plain sends are lost as Erlang loses them, and a sender that needs delivery uses a call.
