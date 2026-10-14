# Kill darlings

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`programs/gather.ern`](programs/gather.ern), [`programs/cache.ern`](programs/cache.ern) | section 4's programs under conversations, `gathered` as a library and a cache that answers later and calls a backend from its loop, written as the design would have them; nothing compiles them | tentative, with the proposal |
| [`proposal.md`](proposal.md) | three changes to the type system, each weighed on the principles, in the order they would be built: the reply's obligation goes, `Reply`, `answer`, `Address.call` and `callForever` staying; the mark on every function that acts goes, `with` becoming `receiving`; and a process receives on conversations beside its mailbox, `Reply` one of them; with §0 read against them, what each costs to build, and what to find out first | tentative, under discussion since 2026-10-14 |
