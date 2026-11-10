# ernest-httpd: the server owns both ends of its socket

What each file here is, and which is current. The proposal is decided and planned, as MVP 4.6, before the launch since 2026-11-10. Nothing in it is authoritative.

| File | What it is | Status |
|---|---|---|
| [`proposal.md`](proposal.md) | what Ernest asks of ernest-httpd, a client script the server ships, the limits it enforces, a client that is never stale and its own test, and what then changes in Ernest: `site.js`'s session, the generator, the shell's page, `make site`, the browser test and the site's design note; the order, after the launch and the server's part first; what it buys, what it costs, what stays, its six decisions, and what it meets | current; written 2026-11-09, each of its six decisions made with the user, and read against every owner it names; planned that day as MVP 4.6 |

The need: the site knows the server in three places, the wire in `site.js`, the configuration's form in `tools/site.ern` and a stub socket in the browser test, each a fact of the server's that stands a second time in Ernest.

The server's side is its own sessions' to design, in its own repository ([`docs/clean_room.md`](../../clean_room.md)). What Ernest asks of it stays here, under the program's name.
