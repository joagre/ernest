# Deadlock

What each file here is, and which is current. The proposal is under discussion: all of it is tentative, and nothing flows from it into the report, the plan or the log.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | what §8.6's check finds and what it cannot promise; the changes to the documents that follow; a report of who waits on whom, in the library and the shell, that states facts and never faults; the callee in a deadlock's report; the nine answers, what was weighed and not taken, and the three items | current; written 2026-11-06, its nine questions answered and the result read against its owners on 2026-11-09; not yet said to be ready |
| [`experiment.md`](experiment.md) | the programs run on 2026-11-09 with what each wrote, what a start time costs a call, and what the runtime already keeps of a call | the runs Part 1 and the answers rest on |
| `experiment/` | its code: the four programs, the fourth in three forms, with its host module `later.erl`, and the probe `since.erl` | the code `experiment.md` runs |

The need: the claim "a deadlock is found" promises more than the check gives. The check finds a program in which no process can ever go on, and a stuck part of a running server is not found.

It is no input for the plan until it is said to be ready. One edit reaches §3 to §9, a restated clause of §8.6 that Part 4 cuts. Two claims about other systems, Pony's collector and Go's work on leaked goroutines, are from memory and say so. The status premise is as read in OTP's source, and no program shows it.
