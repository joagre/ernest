# The agents

How a session works with its agents: what a brief holds, where an agent's report goes, what is checked before agents start and after they end, and the model each job gets. What goes to an agent is [`CLAUDE.md`](../CLAUDE.md)'s *The work*, which has a session read this file before it starts its first agent, and that its report is a claim is its *Honest reports*.

## The brief

Code goes to an agent one build at a time, given its goal, the report's sections it builds and the check that proves it done. Where the user has said to go on (`CLAUDE.md`, *Who decides*), each item has an agent of its own, started once the item before it is closed and committed.

A diagnosis that needs experiments goes to one agent with the failing case and what is ruled out, never the session's guess, and that agent owns the loop to a passing test. A question about what the host or the code does is no diagnosis: the session reads and runs it itself (`CLAUDE.md`, *The work*).

Agents whose work is bound by the processor, a race's probe, a run under a sanitizer or a load test, run one at a time, and each runs its programs one after another: side by side is for work that waits or reads. The brief says so. The brief sorts the agent's runs by that test and names each kind: a race's probe and a run whose time is measured are bound by the processor, and a run that only waits, a test that fails by running out its deadline among them, goes side by side. A session reads the machine's load before it starts such an agent: a load another session makes is said to the user, who says whether the agent waits.

An agent follows `CLAUDE.md`, but a review's reader, whose brief stands in its place as [`reviews/full.md`](reviews/full.md)'s *How it runs* says. Every agent's brief tells it in one line to leave untracked files alone, and says which style document it reads first, as `CLAUDE.md`'s *Read when the job starts* has it.

## An agent's report

Its report comes back as the agent's answer: an agent cannot write a file of its report. The session keeps what it needs of it in a file under its scratchpad, which a compaction keeps whole. A step of many commands, a release's, keeps its checklist in such a file too.

An agent drafts its log paragraph in its report and never edits the log: the session places it, so that the log keeps one voice and two agents never edit one file at once.

## Before and after

`git status --short` is read before agents start and compared after they end, untracked files among it.

An agent that dies leaves its processes and its nodes running: they are looked for and killed by their process numbers, never by a pattern.

## The models

An agent is given its model and its effort when it is started.

The coding model runs at the stronger effort for a build in the checker, the emitter, the runtime or the nodes, for a diagnosis, and for a review's reader of the code or of what the toolchain does. It runs at the lesser effort for any other build from a settled brief, re-run once at the stronger from a brief naming the failure and then returned to the session.

The stronger model, at the session's own effort, reads the report, the guide or a document in a review, and report sentences cold. The smallest model runs a search or a digest of long output that asks no judgment. A test run or a probe needs no model: the session runs it.

The models' names and their efforts are the session's memory's, not this repository's.
