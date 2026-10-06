# An experiment: Erlang's distribution as a carrier

Tried on 6 October 2026, on OTP 29 (ERTS 17.1), with OpenSSL 3.0.

**What it asks.** Whether a node protocol of Ernest's can ride on Erlang's own distribution with what hurts in it turned off: the mesh, the port-mapper daemon, the cookie as the only proof of who a peer is, and a sender made to wait. `proposals/nodes_and_code/other_systems.md` holds what was found, beside what other systems do.

**How it is run.** `./run.sh`, from any directory. It needs `erl` and `openssl`. It makes a key and a self-signed certificate for each of three nodes in a directory of its own, starts the nodes on this machine, prints what it finds, and removes the directory. A run takes about half a minute.

**The three nodes.** Node `a` lists `b`. Node `b` lists `a` and `c`. Node `c` lists `b`. A node accepts a peer whose public key it lists, and no other.

## What each step tries, and what it found

| Step | Tried | Found |
|---|---|---|
| 1 | TLS between two nodes that list each other, with no port-mapper daemon | `a` reaches `b`. A table from a node's name to its port stands in for the daemon |
| 1 | A node that is not listed | `a` to `c` is refused in the TLS handshake, with the reason `not_listed` |
| 2 | No mesh | With `a` and `b` connected, and `b` and `c`, `a` and `c` stay unconnected. A connection opens at the first send |
| 3 | A sender that does not wait | With the peer stopped and the buffer's limit at 1 kB, a send with `nosuspend` is refused at once. The node then ends the connection itself, and both nodes are told |
| 3 | A send that does not connect | With no connection open, a send with `noconnect` answers `noconnect` and dials nothing |
| 4 | A silent peer, with the tick time at 4 seconds | `a` finds `b` lost after 4.6 to 4.8 seconds, with the reason `net_tick_timeout`. Its monitor on a process of `b` gives `noconnection` |
| 4 | The peer wakes | `b` is told within a fraction of a second, of every peer that gave it up meanwhile |
| 4 | An address after a loss | The same pid reaches the same process, and the connection opens again by itself |
| 5 | Monitors with Ernest's reasons | A kill arrives as `{ern, killed}`, and a fault as `{ern, fault, Cause}` |
| 5 | A reply that takes one answer | The first answer through an alias arrives, and a second is dropped |
| 6 | A node started again under its name | A monitor on a process of the earlier start gives `noproc`, and a send to it is dropped |

## What it took

- `-proto_dist inet_tls`, with an options file that names a rule of ours as the `verify_fun`. The host refuses a self-signed certificate by itself, and the rule accepts one by its listed public key. In the file the rule is written `{fun ern_probe_pin:verify/3, State}`; in another form the host refuses the option, and says so only on the accepting node.
- `-start_epmd false` and `-epmd_module`, with a module that answers a port for a name.
- `-connect_all false`, for no mesh.
- `-kernel net_ticktime`, for how long a silence is.
- `+zdbbl`, for how much may wait to be sent before a send with `nosuspend` is refused.
- A cookie, which the host still requires. It was a constant.

## What it does not show

- All three nodes ran on one machine. A stopped process stood in for a silent peer. A network that parts, and one where only one side can dial, were not tried.
- A certificate that names another host was not tried.
- Nothing was timed but the finding of a silence.
- A connected node could do anything on the other: the experiment itself spawned processes there and ended them. Nothing turns that off.
