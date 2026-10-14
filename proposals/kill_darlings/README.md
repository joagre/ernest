# Kill darlings

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | three darlings of the type system, each weighed: that a function type names its process's mailbox only where the function's own mailbox is involved, written `receiving M` in place of `with M`, and that sending and every other action carry no mark, as in ML and Erlang; the reply mark `!`; and the reply's obligation, which goes while `Reply`, `answer`, `Address.call` and `Address.callForever` stay; Gleam's answers set beside Ernest's; conversations, the middle design between folding where a message is sent and where it is received, with `Reply` a conversation of one answer, `adapted` the one fold, the question whether wraps go, and the proxy; what building each part costs, and in what order; the three designs of the mailbox weighed, the principles, what it gives up, whether §0 must change with it, what other systems do, and what to find out before deciding | tentative, under discussion since 2026-10-14 |
