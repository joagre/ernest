# Kill darlings

What each file here is, and which is current.

| File | What it is | Status |
|---|---|---|
| [`findings.md`](findings.md) | what the checks have caught, the three programs side by side, the signatures under section 3 and whether process-only survives, and the guide against section 7: the first checklist's items 1, 2, 3 and 6, read on 2026-10-14 | read, with the proposal |
| [`programs/`](programs/) | the three programs: `queue`, `supervisor` and `gather` with its `main`, each as `_today.ern`, which compiles and runs, and `_after.ern`, as sections 2 and 3 would have it, which nothing compiles | with the proposal |
| [`guide_passage.md`](guide_passage.md) | the guide's §4.4 passage *A library that waits*, section 7's, written against today's language and checked by `make test-guide` | ready, waits on the decision |
| [`proposal.md`](proposal.md) | three changes to the type system, each weighed on the principles, in the order they would be built: the reply's obligation goes, `Reply`, `answer`, `Address.call` and `callForever` staying; the mark on every function that acts goes, `with` becoming `receiving`; and receiving kept composing across a process, conversations weighed and set aside; with §0 read against them, what each costs to build, and what to find out first | tentative, under discussion since 2026-10-14 |
