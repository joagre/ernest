# The shell

What each file here is, and which is current.

The shell's design as built, which stood here, is [`docs/design/shell.md`](../../design/shell.md) since 2026-10-16.

| File | What it is | Status |
|---|---|---|
| [`attached.md`](attached.md) | a shell attached to a running node, `ern shell --attach`, for the operator: the two uses, attaching by a listed name, what a session is on the node and the sessions' namespaces; what other systems do; and the questions open for MVP 4.0's design | decided 2026-10-13 in what it settles, the name and that no sandbox of the language's is built; its open questions are MVP 4.0's design |

`attached.md`'s section 2 flows into MVP 4.0's design when that milestone opens; the sandboxed session weighed on 2026-10-13 is set aside, and the log records why. The visitor's shell, its container and its measured numbers are the web server's, `../httpd/proposal.md`, since 2026-10-27.
