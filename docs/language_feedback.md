# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 114.

1. **A request with named fields is not a function.** Every `Address.call` of one writes `fn(reply) = Subscribe(topic = topic, name = name, subscriber = address, reply = reply)`, six lines once laid out, and the pattern repeats each field; a writer makes requests positional so that the call reads short, so the call chooses the messages' shape. The newcomer of 0.4.0's review, `pubsub`.
2. **`receiving M` spreads up the chain.** A helper that starts a monitored process on another's behalf must declare that process's mailbox type, and so must every function up to the one whose mailbox it is. The same newcomer.
3. **Addresses have no equality**, so a broker keeps two maps that must agree, name to address for delivery and `Process` to name for a `Down`, where one map keyed by the process would do. The same newcomer.
4. **A receive guard may not call `Process.fromAddress`**, and a precondition is `if c then fault(...) else Unit`, since `if` has no form without `else`. The same newcomer, minor.
5. **A call to many processes at once** is §4.4's `gathered`, thirty-five lines a use; a publication delivered by one call after another lets a slow subscriber hold the sender a deadline each time. The same newcomer.
