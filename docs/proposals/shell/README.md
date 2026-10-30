# The shell

What each file here is, and which is current.

The shell's design as built, which stood here, is [`docs/design/shell.md`](../../design/shell.md) since 2026-10-16.

| File | What it is | Status |
|---|---|---|
| [`attached.md`](attached.md) | a shell attached to a running node, `ern shell --config-dir ops --attach name`, for the operator: the two uses, the cut between the operator's machine and the node, attaching by a listed name, the session on the node, what other systems do, and the report sentences the build writes first | decided 2026-10-13 in what it settles, the name and that no sandbox of the language's is built; rewritten 2026-10-30 over the cut, every question closed, read back before MVP 4.0's build |

`attached.md`'s section 6 is MVP 4.0's first item once the proposal is ready; the sandboxed session weighed on 2026-10-13 is set aside, and the log records why. The visitor's shell, its container and its measured numbers are the web server's, `../httpd/proposal.md`, since 2026-10-27.
