# Kill darlings

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`programs/gather_today.ern`](programs/gather_today.ern), [`programs/main_today.ern`](programs/main_today.ern) | section 4's program: `gathered` as a library under today's language, its receiving in a process of its own and the caller getting the result by a call, and a `main` that runs it | compiles and runs today |
| [`guide_passage.md`](guide_passage.md) | the guide's §4.4 passage *A library that waits*, section 7's, written against today's language and checked by `make test-guide` | ready, waits on the decision |
| [`proposal.md`](proposal.md) | three changes to the type system, each weighed on the principles, in the order they would be built: the reply's obligation goes, `Reply`, `answer`, `Address.call` and `callForever` staying; the mark on every function that acts goes, `with` becoming `receiving`; and receiving kept composing across a process, conversations weighed and set aside; with §0 read against them, what each costs to build, and what to find out first | tentative, under discussion since 2026-10-14 |
