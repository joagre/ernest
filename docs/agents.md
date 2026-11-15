# The agents

How a session works with its agents: what a brief holds, where an agent's report goes, what is checked before agents start and after they end, and the model each job gets. What goes to an agent, and that its report is a claim, is [`CLAUDE.md`](../CLAUDE.md)'s *The repository*, which has a session read this file before it starts its first agent.

## The brief

Code goes to an agent one build at a time, given its goal, the report's sections it builds and the check that proves it done.

A diagnosis that needs experiments goes to one agent with the failing case and what is ruled out, never the session's guess, and that agent owns the loop to a passing test.

An agent follows `CLAUDE.md`. Its brief tells it in one line to leave untracked files alone, and says which style document it reads first, as `CLAUDE.md`'s *Style* has it.

## An agent's report

Its report comes back to the user and is written to a file under the session's scratchpad, which a compaction keeps whole. A step of many commands, a release's, keeps its checklist in such a file too.

An agent drafts its log paragraph in that file and never edits the log: the session places it, so that the log keeps one voice and two agents never edit one file at once.

## Before and after

`git status --short` is read before agents start and compared after they end, untracked files among it.

An agent that dies leaves its processes and its nodes running: they are looked for and killed by their process numbers, never by a pattern.

## The models

An agent is given its model and its effort when it is started.

The coding model runs at the stronger effort for a build in the checker, the emitter, the runtime or the nodes, for a diagnosis, and for a review's reader of the code or of what the toolchain does. It runs at the lesser effort for any other build from a settled brief, re-run once at the stronger from a brief naming the failure and then returned to the session.

The stronger model reads the report, the guide or a document in a review, and report sentences cold. The smallest model runs a search or a digest of long output that asks no judgment. A test run or a probe needs no model: the session runs it.

The models' names and their efforts are the session's memory's, not this repository's.
