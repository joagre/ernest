# Known issues

What is known to be wrong or missing and not planned: a corner that must be built on purpose to be met, one line each, with how it was met and when. A line becomes an item of [`plan.md`](plan.md) when the user takes it up, and goes when it is fixed. A defect of OTP's that Ernest meets is [`otp_bugs.md`](otp_bugs.md)'s, and what writing Ernest has felt is [`language_feedback.md`](language_feedback.md)'s.

- Two processes that close one socket at the same moment: the second `Tcp.close`, its request in the socket's mailbox when the first ends the socket, answers at the socket's end and before the bytes are sent. Read from `ern_tcp:socket_loop/1`, 2026-11-21.
- The host's `ssl:shutdown(Socket, write)` writes no record that ends the connection, so a strict far end reads the connection cut short. Ernest does not call it. Shown against Python's `ssl` and curl on OTP 29.1.2, 2026-11-21.
- `ssl`'s `internal_active_n` is set to 1 for the whole node (`ern_tcp.erl`), so a TLS client of the host's own run inside an Ernest node, as a test may, reads one packet at a time and can miss a close. Shown by a trace of `prim_inet:setopts`, 2026-11-21.
- `ern_os_tests:unopened_node_file_test` fails with `einval` where `TMPDIR` is so long that the test's own Unix socket path passes 108 bytes. Met in a scratch run, 2026-11-21.
