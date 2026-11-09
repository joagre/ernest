# Deadlock

What each file here is, and which is current. The proposal is under discussion: all of it is tentative, and nothing flows from it into the report, the plan or the log.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | what §8.6's check finds and what it cannot promise; the changes to the documents that follow, none to a rule of the report; a report of who waits on whom, in the library and the shell, that states facts and never faults; the four programs a design session runs first, and its nine questions, each with a recommendation | current; written 2026-11-06, one thing decided, that a stuck part of a running program gets a report and never a fault |

The need: the claim "a deadlock is found" promises more than the check gives. The check finds a program in which no process can ever go on, and a stuck part of a running server is not found.

It is no input for the plan yet. Its four programs are not run, so Part 1 is argued from the report and not observed, and its nine questions are not decided. Two claims about other systems, Pony's collector and Go's work on leaked goroutines, are from memory and say so.
