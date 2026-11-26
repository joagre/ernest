<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="../assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="../assets/ernest-combined-light.svg">
  <img src="../assets/ernest-combined-light.svg" alt="Ernest" width="256">
</picture>

# Running Ernest

This guide is for the operator: the person who runs Ernest programs as *nodes*, programs started so that they talk with one another (section 1), reads what they write on standard error, and decides when to restart one. It assumes nothing of the language beyond what a program's author tells the operator about it, and it teaches only what happens at the machine: directories, commands, lines, and the move each line asks for.

A node runs on the Erlang runtime, OTP, which this guide calls the host; the host picks a port, compiles and loads what a peer sends, and counts what it holds. `ern` is Ernest's one command, whose first word is its job: `ern build` compiles a program, `ern run` runs it, and `ern config`, `ern reload`, `ern stop` and `ern shell --attach` are this guide's. A *process* in what follows is one of the program's own, thousands of which run inside one node, which is one process of the operating system's, with a few helpers of the host's beneath it; a process's *address* is where the program sends it messages, and a `network-address` is a peer's on the wire.

How a program is written to be found, placed and upgraded across nodes is the language guide's chapter 8, [*Programming in Ernest*](language.md), which this guide points at and does not repeat. The rules themselves are [the report's](../report/README.md), Ernest's definition, §8.7, §11 and §12 above all, and every section here but section 8, which runs what the others teach, names the section that owns what it teaches.

The commands of sections 1, 6.3 and 8 and the shell sessions of sections 5, 6.3 and 8 are run as shown, with other directories and ports, each time Ernest is tested; the service manager's unit, the command that does without one, section 2.1's configuration and the `kill` lines are shown and not run. Each number quoted names the machine and the day it was measured on.

## 1. One node

A program becomes a node by being started with a configuration directory, and nothing else: `prog.erc` is the compiled program, which `ern build` writes; `ern run --config-dir dir prog.erc` is a node, and `ern run prog.erc` is not (report §8.3). A program is built by the `ern` that runs it: `ern run` refuses a compiled form that another build of `ern` wrote, a patch release's among them, so a new `ern` builds the program again (report §11.2). The directory is the node's identity, and it is made once.

### 1.1 The directory

```console
$ ern config --config-dir /etc/counter/b --listen 0.0.0.0:8654
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA...
-----END PUBLIC KEY-----
```

`ern config` creates the directory, which only its owner can open, and in it three files (report §11.3): `private-key.pem`, the node's ed25519 key, readable only by its owner; `certificate.pem`, which the node signs itself and whose dates mean nothing to a node; and `ernest.conf`, which lists nothing yet and listens where `--listen` says, here at port 8654 on every interface; section 1.2 says what goes in it. It prints the public key, which is what another node's configuration will list. Given a directory that exists and holds `private-key.pem`, it prints that key and changes nothing, and refuses `--listen` there; one that holds no key it refuses, `b exists and holds no private-key.pem`. Only `--peer-dir`, section 2.1, writes into a directory that exists. Where `certificate.pem` is missing, the node makes it from its key at its start and at a reload.

The directory is made for one machine and never copied: a copied key gives two nodes one identity, which a third node cannot tell apart. So it stays out of the program's repository and out of an archive of it. A node also refuses a configuration that lists its own key under `peers`, `a peer has this node's own key, and a node is no peer of itself`.

A node refuses to start from a directory, or an `ernest.conf`, that any but its owner may write, and from a private key any but its owner may read or write, and says why and how to mend it, `/etc/counter/b/ernest.conf may be written by others than its owner; chmod go-w /etc/counter/b/ernest.conf` (report §12.5).

### 1.2 The configuration

`ernest.conf` is JSON, and Appendix C of the report shows it whole. Its entries, in the order an operator meets them:

- `listen`: the address the node's listener binds to, what `ern config --listen` gave, an address of one interface, or `0.0.0.0` or `::` for every interface of its family, and a port, and none where it gave none. Port `0` lets the host pick one. At every start the node says on standard error the address and the port it listens on, `listening on 127.0.0.1:51204`. A node without `listen` does not listen and only dials; a bare node (section 3.4) must listen.
- `peers`: a list, each peer with a `name` the operator chooses, which the program uses, its `public-key`, and a `network-address`, `host:port`, which is left out where this node never dials that peer. A host name is resolved at each dial, not when the file is read. `peers` are to a node what `authorized_keys` is to ssh: a peer listed may run any code on the node.
- `services`: a service is a process a program offers under a name, which a program on another node looks up, a *find*, to get its address; under each service's name, the peers that may offer it, in the order a find asks them. A service not listed here is found nowhere from this node.
- `measures` and `utilization-interval`: what the node measures of itself, and how often it tells its peers how busy it is, section 3.
- `limits`: the most processes and ports the node holds, `processes` and `ports`, each rounded up to a power of two; a node left without them holds the host's own, a table for 1048576 processes and one for 65536 ports or more, reserved as it starts. A small node, one of many on a machine, states smaller ones: `"limits": {"processes": 65536, "ports": 4096}` (report §12.5).

Two words recur from here: a node *listens* for connections from its peers, and it *dials* a peer when it opens the connection itself, at the address its configuration lists for that peer (report §12.5).

The node runs over one family of addresses, IPv4 or IPv6, its listener's, or IPv4 where it has no listener; a peer's address of the other family is refused when the file is read, and a host name's family is checked at each dial, which fails where the name resolves only to the other.

The host's own settings come from `ernest.conf` and the command line alone: `ern` starts the host without the flags, the installation, the code path and the limit of ports the environment would give it, `ERL_AFLAGS`, `ERL_FLAGS`, `ERL_ZFLAGS`, `ERL_OTP29_FLAGS`, `ERL_ROOTDIR`, `ERL_LIBS` and `ERL_MAX_PORTS`, and the host writes no crash dump (report §11).

A file is refused before anything runs, with a line that names the fault. Report §12.5, *Its configuration*, lists every refusal; among them, a file is refused where it:

- is not JSON;
- names a field the node does not know;
- names a field twice;
- holds a whole number too large for the host to read;
- names a peer twice;
- gives two peers one key;
- lists this node's own key as a peer's;
- names a peer with an empty name;
- names a service twice;
- names under a service a peer it does not list;
- gives `utilization-interval` one that is no whole number of at least one;
- gives `limits` a field other than `processes` and `ports`, or one that is no whole number from 1024 to 67108864;
- stands beside a `certificate.pem` that certifies another key or names another host.

### 1.3 Starting, reloading and stopping

**Starting.** `ern run` with the directory and the program starts the node:

```console
$ ern run --config-dir /etc/counter/b --main serve /srv/counter/build/counter.erc
```

`--main serve` names the function the node runs first, its *entry point*, `serve` of the file's module `Counter`; without it the node runs the program's `main`, and the process that runs it is the *entry process*.

At its start a node computes the values of the program's top-level bindings, the named values a module declares outside any function, as any program does, and only once all have their values does it listen and dial (report §8.5, §8.7). It reads at its start every module of its *load path*, the directories it loads code from, the program's root and every directory beneath it among them, where `ern run` without a configuration reads the modules the program uses alone, and refuses to start where an `.erc` there holds a module of another namespace than its path gives, one built from another source root: `ern run: old/counter.erc holds Counter, not Old.Counter; remove it, or keep a build root outside the program's root` (report §11.2).

It writes its process number to `ernest.pid` in its directory and holds the file locked for its life; a second node started from the same directory finds the lock and refuses, and the `ern run` command, not a node, says `ern run: dir is the configuration directory of the running node N, which ernest.pid names`. The lock goes once the node's process has ended, however it ends, and the file is removed with it. A file left behind, as where the machine itself stopped, is overwritten at the next start.

A program that is no node faults with `deadlock` where every process waits and nothing can deliver. A node detects no deadlock, and in that state waits on until it is stopped (report §8.6).

**Reloading.** `ern reload --config-dir dir` sends the node the hangup signal, and the node reads `ernest.conf` again (report §12.5, *A reload*). A peer added is listed and nothing more happens until the program reaches for it, by a send, a call, a find, a spawn or a compute, or until it dials in. A send is a message to a process there, and a *call* a send that waits for its answer. A spawn starts a process there, and a compute runs a function there for its value.

What the reload finds changed holds as follows:

- A peer removed, or one whose key changed, has its connection ended, and both nodes treat it as lost; the node says the removal at once, and serves the peer until the host has closed the connection, which a peer that stands still puts off (section 2.3).
- A peer whose address changed keeps its connection, and the next dial uses the new address.
- A change to `measures` starts or stops the host's monitors it names, and one to `utilization-interval` holds from the node's next report to its peers (section 3).
- A change to `limits` holds from the node's next start, which the node says.

The node says `ernest.conf was read again` and a line for each peer added, removed or renamed.

`listen` and the node's key, `private-key.pem`'s, cannot change while the node runs: a reload that finds either changed, or that finds what the start refuses, a mode among it, is refused with `the reload was refused, and the configuration stays as it was: ...`, and the old configuration stays. `ern reload` first reads the directory as the node would, making no certificate, and refuses a configuration the node would refuse with status 1, before it signals, but for a changed `listen` or key, which it signals with status 0 and the node alone refuses, saying so on its standard error. `kill -HUP` by the number in `ernest.pid`, the form for a service manager that sends the signal itself, signals without reading, and the node then refuses such a file itself; the unit of section 1.5 runs `ern reload`.

**Stopping.** `ern stop --config-dir dir` sends the node the termination signal and returns once the node has ended, which it waits for on the lock (report §11.2). Termination is orderly: the processes that asked to be told of the end, its *subscribers*, are told and the end waits for each to answer, saying `the end waits for 1 subscriber: Keeper.main` while it waits, so that what a program keeps is written; then the node tells each connected peer that it ends and waits for each peer's answer, so that the peer says `ended` and not `lost`, and exits; a peer that has fallen silent holds the end until it is lost (section 2.3; report §8.7, §12.6).

A second `ern stop` while the first waits is a second termination, which ends the node at once. A node that ends still writes out what its standard output and standard error hold, and waits until they have taken it; a termination during that wait ends the node, and what was not written is lost (report §8.6). `kill -TERM` by the number in `ernest.pid`, the signal a service manager's stop sends, signals without waiting.

Both `ern stop` and `ern reload` fail where no node holds the file, `ern stop: dir/ernest.pid: no node holds it: no node runs from the directory`, or `no such file or directory` where the node's end removed it, so that no signal reaches a process whose number the file names by chance. Each refuses an `ernest.pid` that is not its user's own, the superuser being refused another user's too: `ern stop: dir/ernest.pid: is another user's, and names no node of this user's` (report §11.2).

### 1.4 Exit statuses and the two streams

A process *faults* when it meets an error it did not expect, a division by zero among them. A node exits with (report §11.8):

- 0 when its entry point returns;
- the status the program itself chose, where it calls `Os.exit`;
- 1 when its entry process faults or is killed, when the program exhausts the host's memory, when a load would pass one of the host's limits on code (section 4.2), and when it dials a peer with its table of processes full (report §12.5);
- the termination signal itself when termination ends it, which a shell shows as 143 and a service manager counts as a clean stop;
- 141 when its output, a pipe or a file, can no longer be written; the hangup signal itself, which a shell shows as 129, when its output is a terminal that has gone.

Standard output is the program's own, and the node never changes it. Standard error is the node's: every fault, as `the process of Counter.main:57 faulted: division by zero`, and every line of section 7. Where standard error is a file or a pipe, and not a terminal or a service manager's journal (section 1.5), each line begins with its time in UTC, `2026-10-13T14:22:11.836Z the peer a connected`, so that a file of them is a log (report §11.2). The two streams together are the node's record; keep both.

### 1.5 Under a service manager

A node is run in the foreground and left to the operating system's service manager, which starts it, restarts it and keeps what it writes; `ern` has no mode of its own for it. A unit for systemd, running the counter's node as the user `counter`, the owner of `/etc/counter/b`, saved as `/etc/systemd/system/counter-b.service`:

```ini
[Unit]
Description=The counter, node b

[Service]
User=counter
ExecStart=/usr/local/bin/ern run --config-dir /etc/counter/b --main serve /srv/counter/build/counter.erc
ExecReload=/usr/local/bin/ern reload --config-dir /etc/counter/b
WorkingDirectory=/srv/counter
Restart=on-failure
TimeoutStopSec=90

[Install]
WantedBy=multi-user.target
```

A program that names packages reads its manifest from the directory it is started in, here `WorkingDirectory`'s. Started from another, it is given that directory with `--package-dir /srv/counter` (the language guide's §9.6, report §11.9).

`ern` runs the `erl` it finds on the path, and systemd's path holds `/usr/local/bin` and `/usr/bin` and no directory of a version manager's. For an OTP installed elsewhere, as kerl installs it, `[Service]` names its `bin` first on the path: `Environment=PATH=dir/bin:/usr/local/bin:/usr/bin:/bin`, `dir` the directory OTP was installed in.

systemd keeps both streams in its journal, which stamps every line, and `journalctl -u counter-b` reads them. `systemctl reload counter-b` runs the reload, and `systemctl stop counter-b` sends the termination signal and waits `TimeoutStopSec` for the orderly end, after which it kills what still runs. The unit's 90 seconds are above the time a silent peer was measured to hold the end (section 2.3); where the host takes longer, or a subscriber answers later, systemd kills the node before its end is done, its peers say `lost` and what a subscriber had not written is lost, so a node whose subscribers are slow is given more. `Restart=on-failure` starts the node again after a crash and after an `Os.exit` with a status other than 0, and not after `ern stop`.

Without a service manager, `ern run --config-dir b ... >> b.log 2>&1 &` keeps the two streams in one file, the node's own lines alone stamped. The node runs on once its terminal has closed, since the hangup a close sends is a reload to a node (report §8.6).

## 2. Two nodes

### 2.1 Listing each other

Each node is made on its own machine with `ern config`, and the two then list each other: node `a`'s `ernest.conf` names `b` with `b`'s public key and `b`'s address, and `b`'s names `a` with `a`'s key, and `a`'s address only where `b` is ever to dial `a`. A peer listed without an address is never dialed, and is out of reach until it dials in; a node that is to be reached must listen. Nothing is shared but the keys, by whatever means the operator moves text between machines; the directories are never copied.

```json
{
  "listen": "0.0.0.0:8654",
  "peers": [
    { "name": "b", "network-address": "b.example:8654", "public-key": "<b's key>" }
  ],
  "services": { "counter": ["b"] }
}
```

Two nodes on one machine list each other without an edit. `ern config --config-dir b --listen 127.0.0.1:8655` makes `b` on a port of its own, since the two cannot share one, and `ern config --config-dir a --peer-dir b` lists `b` in `a`'s file under the name `b`, with the key `b`'s certificate holds and `b`'s `listen` as its address, `127.0.0.1` for `0.0.0.0` (report §11.3); `--peer-dir a` does the same the other way. `services` is written by hand, on one machine or two.

Where one node runs as a service's user and the other as the operator, as the node an attached shell starts from does (section 5), neither can open the other's directory, so the superuser makes both, lists each in the other with `--peer-dir`, and gives each directory with its files to its user, `chown -R`. A later `--peer-dir` into either directory is then that directory's user's or the superuser's. An `ern reload` or an `ern stop` of the service's node is the user's who runs it (section 1.3).

### 2.2 The connection

Two nodes hold at most one connection, opened by the first operation that needs it and over TLS 1.3 with a certificate on each side (report §12.5, *Connections*).

A node accepts a connection only from a peer whose key its configuration lists, and only under the name that key gives it: a node's name on the wire holds a digest of its key and its certificate carries that name, so a certificate that names another host than its key gives is refused. So is a dialed node that answers with another listed peer's key, as a listed key beside the wrong address makes one do. The dialing node then says `the peer c was refused: it answered the dial of the peer b`, and the answering node nothing. Two nodes started from one copied directory have one key, and are one node to their peers (section 7's `replaced` row).

The refusing node says why, `a node with the key ... was refused: no peer has its key`, naming an unlisted node by its key's digest since it has no name here.

Connections are not transitive: that `a` knows `b` and `b` knows `c` connects `a` and `c` in no way, and each pair lists each other.

Two nodes connect only where they stand on one *floor*: one major and minor release of `ern` on one major release of OTP, which the handshake proves before anything passes (report §12.5). A patch release stands on the floor of its minor, so `0.11.0` and `0.11.1` connect, and `0.11.x` and `0.12.0` do not, each saying `the peer b was refused: it stands on another floor, another release or build of ern or another major release of OTP`.

A build of `ern` that is no release stands on the floor of its own code's digest, so two development builds connect only where they are the same build. Nodes of different builds of the *program* connect, and agree on the code they share by a hash of each definition (section 6): a *definition* is one function or type of the program, and its *hash* a number computed from the definition's name with its module's, from what it does and from what it uses; a changed comment or layout leaves it as it was, and a moved or renamed module is new code (report §8.7).

The handshake proves the floor by its *cookie*, the digest of the protocol's version, the form's version (report Appendix H), `ern`'s major and minor and OTP's major release, or of a development build's own code (report §12.5). Every node's command line carries it, `-setcookie` and the digest, which `ps` shows, and it is the same on every node of one floor. It is no secret and grants nothing: a connection is accepted by its key alone (report §12.5).

The node says `the peer b connected` as the connection opens, `the peer b ended` when `b` stopped in order, and `the peer b's connection was replaced by another from the same node` where `b` dialed anew while the old connection was alive, as after `b`'s restart.

### 2.3 A lost peer

A connection is lost when the network breaks it, when the node's own detector finds the peer silent, or when a faulty *frame*, one unit of what two nodes send each other, arrives (report §8.7, *A loss*). Any traffic is a sign of life; where nothing else was sent for 15 seconds a tick goes, and a peer from which nothing came in four such intervals is found silent, between 45 and 75 seconds after the last traffic, as the host states it, while a peer that closes is found at once.

The node says the loss once the host has closed the connection. That follows at once, but where the node had sent the silent peer more than its connection took, the host closes later, by a time of its own and no bound: measured, the loss came 84.9 seconds after the last traffic (a machine of twelve cores, 2026-11-17).

The node says `the peer b was lost: it fell silent` or `the peer b was lost: it closed`.

What the program sees is the loss run on this node: every process here that watches one of `b`'s processes, through a monitor, is told so, a `Down` message with the reason `Unreachable`, where a peer that stopped in order gives `ProgramEnd` instead (the language guide's §5.2), every call waiting on one of them ends, and a process waiting forever on one faults. Nothing else ends.

The connection is opened again by the next operation that needs it, never in the background: a node that is lost stays lost until an operation that needs it reaches for it, a send, a find, a spawn, a compute or an ask of its utilization (section 3.2), or until it dials in, and a dial that nothing answers is given up after 7 seconds. A peer that cannot be dialed, listed without an address, is reached again only when it dials in.

A restart here of a process that one of `b`'s processes monitors or calls waits for `b`'s answer, at the latest until the loss or `b`'s end (report §6.9, §8.7). While `b` is silent that service is down: its fault's line says `restarted` at once, and its new run begins at `the peer b was lost`. The window is the protocol's and fixed, since no setting of `ernest.conf` changes it (report §12.6, Appendix C), and nothing at this node shortens it; meanwhile the operator looks at the network and at `b`'s machine, as section 7's table says.

A `send` to a process of a lost peer returns at once, unless more than 1 MB then waits for that peer, its own message counted, when the sender waits until it drains or the dial fails (report §8.7). A `send` to a peer that is silent and not yet lost waits the same way, until the loss. While a send waits so, a call, a find, a spawn, a compute or a utilization towards that peer waits with it and answers only when that wait ends, even where its time ran out long before (report §6.6, Appendix E.27). The message waits behind the dial, and is sent where the connection opens and dropped where it does not.

A silent peer can delay a `Down` for another node too. A process killed while its send to the silent peer waits is reported to watchers on other nodes only once the peer takes again or is lost. The same may hold of any death that a process of the silent peer monitors while 1 MB waits for that peer. A call from another node on such a process ends as late. Watchers and callers on the dead process's own node wait on no peer (report §6.6, §8.7).

The move: look at `b`'s machine. If `b` stopped in order the line was `ended`, unless `a` connected while `b` was stopping; otherwise `lost` means the network or the process. `b` restarting shows as `connected` again on `a`, or as `replaced` where `a` still believed the old connection alive.

## 3. Services and placement

How a program offers a service, finds one, places a computation and sets its own utilization is the language guide's §8.1 and §8.2. Here is the operator's half: the entries that govern them.

### 3.1 Services

`services` lists, under a name, the peers that may offer it, in the order a find asks them (report §8.7). A find asks the first; where it holds the service the address comes back; where it does not, or is unreachable, the next is asked, and so on within the find's time; a name not listed answers `Io.NotListed` without asking anyone. The order is the preference the operator gives the program, and a reload changes it live.

A service carries a hash of its message type, the type of the messages its process takes. A peer that offers the name at another type answers `Io.OtherType`: two builds of the program disagree on the protocol, and no retry mends it. The move is to align the builds (section 6), or to let the program's author know the type changed under a service that peers still find by its old shape. A find answers the last failure it met, so a later peer's `Io.NotOffered` or `Io.Unreachable` hides an earlier `Io.OtherType` (report Appendix E.27).

### 3.2 How busy a node is

A node measures how busy it is on one scale: 1.0 is every scheduler busy, below it room and above it work waiting (report §12.8). A scheduler is one of the host's threads that run processes, one for each core as a rule. The measure divides the processes running or ready by the number of schedulers, an instant reading and not an average.

A program may set the number itself, with `Peer.setUtilization`, when it knows its load better than the host does (the language guide's §8.1).

A node that lists peers tells each of them its utilization, a *telling*, every `utilization-interval` milliseconds, 5000 where the entry is absent, and once as a peer connects; an attached shell's own node tells none, so that no compute that names no node runs on it (report §11.2, *The attached shell*). The first telling is read as the connection opens, while the processes that open it run, so a peer just connected may read busy; its next telling reads what it does.

Each node holds the last number heard from each peer, and `Peer.computeAnywhere`, the function a program runs a compute with when it names no peer, picks the less busy of two peers drawn from them; a number older than twice the interval of the peer that sent it is not used, and a peer never heard from is not chosen. Where a program places work by its own rule, the language guide's §8.1 shows it over `Peer.utilizations()`.

The cost of the telling is one small frame per peer per interval, which replaces the host's own idle ticks rather than adding to them: three idle nodes exchanged about 1.2 packets a second at the default interval, on one machine of eight cores and across machines alike (2026-10-20), each connection carrying two packets a telling. A shorter interval buys fresher numbers for more frames; a longer one the reverse.

### 3.3 The host's measures

`measures` turns on the host's own monitors of the machine, `cpu`, `memory` and `disk`. `memory` and `disk` each take the host's parameters under it, `check-interval` in milliseconds and `almost-full`; `memory`'s interval is a whole number of minutes, and `cpu` takes none (report §12.5). A program reads them through the `Utilization` library (report Appendix G.4), and they change nothing of section 3.2's number. None runs where the section is absent, and a reload starts or stops them. They cost what the host's monitors cost and nothing of Ernest's.

### 3.4 A bare node

`ern run --config-dir dir` with no `.erc` starts a bare node (report §8.7): it holds no program of its own, evaluates the standard library, the modules every Ernest program has and a node holds from its start, and waits, listening for what its peers spawn and compute on it. The code it needs crosses with the first spawn or compute of each function (section 4), and it offers what the processes spawned on it offer, so a bare node is a worker that any listed peer on its floor can give work to by its name.

It must listen, or no peer could reach it, and it ends by termination alone, since it has no entry point to return. Its first spawn is the slow one: about 250 milliseconds on a machine of eight cores and 650 on one of two (2026-10-20), most of it the host's compiler starting, against the exchange's own cost for every spawn after (section 4.1).

## 4. Code across nodes

### 4.1 What crosses, and when

Code crosses between nodes with a spawn and a compute, and nowhere else: not with a message and not with a find; the report calls the crossing *the exchange* (report §8.7, *The exchange*). When a program spawns a function on a peer that lacks it, the peer asks for the definitions it lacks among the function and everything the function uses, directly or through others, its *reach*, each known by the hash of its definition, verifies each as it arrives, compiles them together as one module of the host's and loads it whole before the process starts. Nothing compiled ever crosses, and nothing of it runs before all of it is loaded.

A definition that arrived is kept, so the second spawn of the same function ships nothing. On one machine of eight cores, a spawn whose code crosses costs about 7 milliseconds for one definition, 9 for five and 23 for twenty, against a third of a millisecond for a function the peer already holds (2026-10-13); across a wire to a machine of two cores, 17, 27 and 72, most of it that machine's compiler, against about a millisecond and a half, the wire's round trip, for a function it holds (2026-10-20).

Two things never cross: the value of a top-level binding a node evaluates, which each node computes from its own program at its start, and a module of the host's that the program calls directly, through a foreign declaration, which a node finds on its load path. A spawn whose function needs either on a node that lacks it is not started, and the node says so (section 4.3). A binding whose initializer is a *constant* (the language guide's §2.2) is evaluated nowhere, and crosses with the code that names it (report §4.6).

A shell attached to a node sends it a module's source as text, which the node compiles as its own (section 6.2); there too nothing compiled crosses.

### 4.2 What a node keeps, and when to restart

A node keeps every *unit* of code it loads, one module as the host counts them, its build's modules, the ones it was sent and the ones a program or a shell attached to it loaded, for its life (report §11.2, *What a node holds*). An input's unit at an attached prompt goes as section 5 says; what it added to the counts stays. The host counts what they add, in four tables it fills and never empties, module names, exported functions, defined functions and *atoms*, its interned names, which every new name in received code adds to, and never gives one back, so a node that is sent new code without end slowly uses the counts up.

The limits are the host's, 65,536 module names, 524,288 export entries, 524,288 function entries and 1,048,576 atoms, and a node says once, at four fifths of one, `the host has used 52429 of its 65536 module names, which it never gives back`. A load or a spawn of new code that would pass a limit ends the node at once, every process with it, as running out of memory does: it exits with status 1, and the host writes its own line, `no more index entries in atom_tab (max=1048576)`. The line at four fifths is the time to plan the restart below.

How fast the counts move is a question of how much new code a node is sent, not of how long it runs or how much work it does. A node that runs the same build as its peers is sent almost nothing.

One that developers spawn their edits onto, whose program loads new code into itself often, with `Code.load` (the language guide's §8.4), or at whose prompt an operator types often, each input a unit (section 5), moves them: counted on one machine (2026-10-13), a small definition spawned costs one module name, about five exports, a function entry per *lambda*, a function written in place without a name, and an atom, so two hundred such spawns a day reach four fifths of module names after about 260 such days; a program of twenty modules upgraded whole through `Code.load` reaches four fifths of function entries after about 416 upgrades.

The move is a restart at a time the operator chooses: a restarted node holds its build and is sent the rest again as its peers need it, and nothing is lost but what was in its memory, which a node never promises to keep.

### 4.3 The lines a spawn can leave

A spawn or a compute a peer asked for that this node did not start is said on this node's standard error, naming the peer, the site in the program where the spawn is written, and what was lacking (report §12.5, *What it says*). Section 7's `was not loaded` rows give each line, what happened and the move.

The program on the spawning side sees each of these as a failed result, a `Left`, with `Io.NotLoaded(text)` for a binding or a host module that is lacking, `text` the words after `was not loaded:`, and `Io.Other` for the rest (report Appendix E.1).

The rows are a selection: report §12.5, *What it says*, names every line a spawn or a compute can leave, a compute's lines beside these and the exchange's time run out among them.

## 5. Looking in

**Attaching.** A shell attached to a node is the operator's window: `ern shell --config-dir ops --attach b` runs a session on `b`, each input checked against `b`'s modules, compiled on `b` and run in a process there, while the terminal, the history and the files the session reads stay with `ops`, the node the shell starts from (report §11.2, *The attached shell*). Every module of `b`'s build is in scope at the prompt. A file, `--main`, `--load-path`, `--libs-dir` and `--package-dir` are refused with `--attach`, since the program and the load path are the node's.

`ops` is a directory of its own, made with `ern config` and no `--listen`, since the shell dials in. It lists `b` with its address, and `b` lists it without one, and on one machine `ern config --peer-dir` lists each in the other (section 2.1). Every peer `b` lists may attach to it, as every one may spawn on it. Where `b` runs as another user than the operator, section 2.1 says who makes the two directories.

**A session.** On section 8's `b`, whose counter `--main serve` started:

```
$ ern shell --config-dir ops --attach b
the peer b connected
Ernest 0.11.0, session 1. :help for help.
> :processes
Counter.serve receiving 3120 bytes
> List.map(Process.live(), Process.status)
[Some(Process.Status(site = "Counter.serve", queued = 0, activity = Process.Receiving, memory = 3120))] : List(Optional(Process.Status))
> Peer.peers()
["a", "ops"] : List(String)
> :browse Counter
Counter.serve() : Unit receiving Counter.CounterMsg
> :quit
```

`the peer b connected` is said by `ops` as the shell dials, and `b` says `the peer ops connected`. The shell prints each value with its type. `Peer.peers()` is `b`'s configuration, and a binding of the program read at the prompt is `b`'s value, as a function of the program called there runs on `b`.

**The processes.** `:processes` lists `b`'s live processes, each by its spawn site, what it does, `running`, `receiving`, `calling` or `suspended`, and the bytes it holds, a figure of the run's own, here the counter waiting for a message; a process in `Clock.sleep` is `receiving` too (report Appendix E.21). After `calling` come the callee's site, or the peer it is on, `without limit` where no time ends the wait, and the seconds it has waited, and a line after the processes names each cycle of calls without limit (report §11.2).

A process is `running` while the host works in it. The host works for a moment in every process of `b` when code is let go there, so a process that waits can show `running` once. A process at work is `running` in listing after listing. A process the host holds is `suspended`, one whose `send` waits for a peer that takes no more among them (report §8.7, Appendix E.21).

`Process.live()` and `Process.status` answer for `b` at its prompt, and `Process.live()`, as `:processes`, leaves out every session's own processes, this one's and another's (report Appendix E.21).

No line of the node's standard error says how much memory a process holds, and `:processes` shows each process's bytes (report §10). A process that waits holds what it no longer uses until it runs again or ends, so a server's idle connections can hold their last responses. A waiting process that references a value the host lets go, as a shell lets go an input's, is collected then, so its bytes can fall after an input ran while it waited.

**A site and its version.** A process's site is the declaration its spawn is written in, with the spawn's line, `Counter.main:57` for the counter the second build's tool spawns (section 6.3). The entry process, which no spawn starts, has the entry point's name and no line, `Counter.serve` above (report §6.9). A site carries the number of the version that spawned it, fixed at the spawn: plain for the build and the first load, and with the version's number for a reload's, `Counter$2.main:57` for that spawn in the module's first reload. A site of a process a session started carries the session, `$Session2.input 3:1`, in every shell's lines and on the node's standard error alike (report §11.2, *Faults*). A type carries its version's number too, where that version is no longer current (report §11.2, *Loading and reloading*).

**Output and faults.** What a process the session started writes is shown at the prompt, and what the node's program writes stays on the node's standard output. Every fault on `b`, the program's among them, is said at the prompt of each shell attached to it and on `b`'s standard error, and `:faults` lists those said since the session attached; a fault of an input's own process is said at its prompt alone. A fault's trace names each function by the name its program gives it, code that arrived from a peer among it, and the fault's line says `, spawned by the peer a` where a peer spawned the process (report §11.2).

**Leaving, and a node that ends.** `:quit` leaves, as `C-d` on an empty input does, and the shell exits with status 0. What the session started stays on `b`: a process an input spawned runs on, and writes to `b`'s standard output from then on. Once the session has ended, an `Os.exit` in such a process ends the node; while the session runs, it faults its caller (report §11.2). `b` says `the peer ops ended`. Several shells may attach to one node at once, each from a directory of its own, each a session of its own.

A session ends with its node: where `b` ends, by `ern stop` or by its program's end, the shell says `the node b ended` under its last prompt and exits with status 0, as section 8's stop shows, and where the connection is lost, it says `the node b is lost` and exits with status 1 (report §11.8).

**An attach that fails.** It is refused with status 1 and a line that names why: `ern shell: the peer b is unreachable` where no connection opens, `ern shell: the peer b did not answer in time` where a connection opens and no session starts within twice a dial's 7 seconds, `ern shell: the peer b is not listed` where `ops` lists no `b`, and `ern shell: the node b could not start the shell:` followed by the reason where the session's root on `b` ends before the session starts.

**Another release, and what an attach costs.** The shell's code crosses to the node as a program's does, so a node of another release of `ern` on the shell's floor runs it (report §11.2, *The attached shell*). The start line then names the node's release after the shell's own: a shell of `0.11.1` attached to a node of `0.11.0` says `Ernest 0.11.1, session 1 on ern 0.11.0. :help for help.` (report §11.2). A node that could not compile or load that code answers `ern shell: the node b could not load the shell:` followed by its reason, and one on another floor refuses the connection, as section 2.2 says.

An attach takes about half a second on an idle machine of twelve cores, and longer under load, as a shell that is a node takes to start (2026-11-08). A node holds the shell of its own build of `ern` from its start, so a shell of that build ships nothing to it. A shell of another build sends what the node lacks of its code, which the node compiles as it compiles any code that crosses (section 4.1) and holds for its life. The first attach of that build takes up to about three seconds on that machine and eleven on one of two cores. The shell waits twice a dial's 7 seconds for it, so on a machine of two cores under load that attach may be refused as one that `did not answer in time`, as above. A later attach of that build ships nothing.

Each input after an attach is a unit `b` compiles and loads, which the counts of section 4.2 count. `b` lets an input's code go as report §11.2 says: once its answer is in, where the input neither declares nor builds a function value; when a later expression replaces `it`; and at the session's end. A unit a process still runs is kept while it does, and one that declares a function or builds a function value is kept for the node's life. The host never gives its counts back.

## 6. Builds

### 6.1 Several builds on one floor

Nodes of different builds of a program connect, as long as they stand on one floor of `ern` (section 2.2), and they agree on what they share by hash: a service names its message type by the hash of its definition, a spawn names its function by the hash of its definition, and a definition that did not change hashes the same in both builds (report §8.7).

A definition's hash covers the hashes of the definitions it uses, so a fix to one function changes its hash and the hashes of the functions that use it; those cross to a node at the old build, and nothing else; two versions of a type are two types, and a service offered at one is not found at the other, which `Io.OtherType` says (section 3.1, report Appendix H).

Nodes on two floors never connect (section 2.2). A fleet moves to a new minor release of `ern`, or a new major release of OTP, whole, every node stopped and started again on the new floor, or as a second fleet beside the first, with directories of their own, its programs found or placed there and the first fleet stopped once nothing needs it.

A build written into the directory a running node was started from, where `ern build` put its `.erc`, reaches the node at its next start and nothing before; code reaches a running node from disk through `Code.load` (the language guide's §8.4), or through `:load` at a shell attached to it, which takes the node's own compiled form where its load path holds one (section 6.2). Put each build in a directory of its own, outside every other build's root, since a node refuses to start where its program's root holds an `.erc` of another namespace (section 1.3), and point the service manager's unit at the one meant.

### 6.2 A fix from a shell

A fix reaches a running node from a shell attached to it (section 5). At the node's prompt, `:load` reads a module's source under the shell's source root, its working directory or the directory `--source-root` names, and sends it to the node as text; the node compiles it as its own, or takes its own compiled form where its load path holds one built from that source. A module of the node's own build is refused by `:load` and compiled again by `:reload` where its source has changed, and the module's next version is the one the node's prompts use from then on (report §11.2). A reload evaluates the module's bindings again, so it starts the module's services again beside the old (section 6.3).

A running process keeps its code until a message of its own type hands it the new, so a fix reaches only a service written to take that message, which section 6.3 sends at the node's prompt. The node keeps the code for its life (section 4.2), and a restart from the old build is the old build again. The shell's own commands are its `:help`.

### 6.3 A service moved to new code

A running service is moved to new code by the program's own message, never by the runtime: the service is written to take a message that hands it its new function, and a function of the new build lists the processes running the old function and sends each of them that message (report §6.10, Appendix E.28). How a service is written to take it is the language guide's §8.4; the operator calls the function at the node's prompt.

The example `examples/upgrade/` is one module, `Counter`, in two builds: the first, [`v1/counter.ern`](../examples/upgrade/v1/counter.ern), is the counter alone, which section 8 starts on the peers, and the second, [`v2/counter.ern`](../examples/upgrade/v2/counter.ern), the counter with a new loop, `countAloud`, a function `moved` that moves its node's counters to the new loop and answers how many it moved, and a tool. Run from `examples/`, with a counter of the first build on `b` as section 8 starts it, a shell attached to `b` from `ops` (section 5), its source root the second build's directory, moves it:

```
$ ern shell --config-dir ops --attach b --source-root upgrade/v2
the peer b connected
Ernest 0.11.0, session 1. :help for help.
> :reload
Counter, compiled again
> Counter.moved()
1 : Int
> Counter.moved()
0 : Int
> :quit
```

`:reload` finds that the source of `b`'s `Counter` has changed, and `b` compiles the second build from the text the shell sends. `Counter.moved()` runs on `b`, and the shell prints its value with its type: `Code.running` lists the processes running the old loop, `count`, by its name and its message type, which both builds write alike, here the counter `serve` started, and `moved` sends each the `Upgrade` that hands it `countAloud`. Asked again once the counter has taken its `Upgrade`, it finds none.

The tool, the second build's `main`, makes the move from a node of its own, for every peer at once: it moves a counter of its own first, then spawns on each peer a process that moves the peer's counters and tells it how many, one line a peer; the spawn carries `countAloud` to a peer at the first build, which lacks it and keeps it. Section 8 runs it, and a peer it could not start on is a line with the failure, `c: Io.Unreachable`.

A service under `restarting`, started so that the runtime restarts it at a fault, is moved so only until its next fault, when the restart runs the function the service was started with, the old code (report §6.9). Such a service takes new code as a new service, started when the new build's binding is evaluated, by `Code.load`, the program loading a build into itself (the language guide's §8.4), or a shell's `:reload`, which loads a module's new source in place of the old, and the old service runs on beside it (report §11.2, Appendix E.28).

So a reload starts the module's services again beside the old, unless the binding offers its service and, finding it held, waits for the holder to end (report Appendix E.27). The old version's processes are listed by `:processes`, each under the site its version gave it (section 5), and each is ended by `kill`; what finds and moves them is the language guide's §8.4.

## 7. What a node says, and what to do

Every line below is written once, on the node's standard error, with its time where that is a file or a pipe. The lines that begin `ern run:` or `ern stop:` are written by the command instead of a node, and name the directory by its path from the working directory, or by its whole path where it lies outside that directory (report §11). The table is a selection: report §12.5, *What it says*, and §11.2 name every line a node writes, the end's lines, a frame it cannot read and a dial refused for its family among them.

The first column is the line as it is written, with the peer's name from `ernest.conf`, or `the node` and its key's digest where it is not listed; `Site` stands for a place in the program, `Module.function:line`, `Q` for a name in the program, `Module.name`, `M` for a module and `N` for a number.

| The line | What happened | The move |
|---|---|---|
| `listening on 127.0.0.1:51204` | The node listens; the port is the host's where `listen` had port 0. | Tell the peers that dial it, where they do not know the port. |
| `the peer b connected` | A connection opened, dialed by either side. | None. |
| `the peer b ended` | `b` stopped in order; a process here that monitored one of `b`'s was told `ProgramEnd`, or `Unreachable` where `b`'s end dropped the `Down` (report §8.7). | None; expected at `b`'s stop. |
| `the peer b was lost: it closed` | The connection broke at once: `b`'s process died or its machine closed the socket, or this node connected while `b` stopped in order. | Look at `b`'s machine and journal. |
| `the peer b was lost: it fell silent` | `b` was found silent in 45 to 75 seconds and lost when the host closed the connection (section 2.3): network, or a frozen machine. A restart here of a process that `b` monitored or called waited until this line, and so did this node's own end, where it had begun. | Look at the network between them; `b` reconnects at the next operation. |
| `the peer b's connection was replaced by another from the same node` | `b` dialed anew while the old connection was believed alive, as after a restart; or two nodes were started from one copied directory, which have one key and are one node to their peers. | None after a restart; where the line repeats, look for a second node started from a copy of `b`'s directory. |
| `a node with the key ... was refused: no peer has its key` | A node dialed in whose key this node's `peers` does not list, named by its key's digest; or this node's own dial of a listed address reached a stranger, named the same way. | Add its key under `peers`, then `ern reload`; or ignore a stranger. |
| `a node named ... was refused: its key gives another name` | A node dialed in under a name that is not the one its key gives, named as it named itself. | Check which key is listed beside which address on the dialing node. |
| `the peer c was refused: it answered the dial of the peer b` | This node dialed the address listed for `b`, and the node there holds `c`'s key. | Check which address is listed beside which key on this node. |
| `the peer b was refused: its certificate names another host than its key gives` | A certificate signed by `b`'s key names another host than that key gives. A node does not start from such a directory (report §12.5), so `b`'s key is used by something that is no node started from `b`'s directory. | Make `b`'s directory again with `ern config` on `b`'s machine, and give its peers the new key. |
| `the peer b was refused: it stands on another floor, another release or build of ern or another major release of OTP` | The two run different minor releases of `ern`, different development builds, or different major releases of OTP. | Install one release of each on both. |
| `the peer b was refused: this node's table of processes is full` | `b` dialed in while this node's table of processes was full, and the connection was closed; the node runs on, and accepts `b` once there is room. Where the node refused it before the TLS handshake gave the key, the line names the address it came from instead, `a connection from 10.0.0.7:53114`. | Find what holds the processes, `:processes` from an attached shell (section 5); or raise `processes` under `limits`, which holds from the node's next start. |
| The same for ports, `a connection was refused: this node's table of ports is full` | A peer dialed in while this node's table of ports was full. | Find what holds the ports; or raise `ports` under `limits`, which holds from the node's next start. |
| The host's own line, then status 1 | The node dialed a peer while its own table of processes had no room, and ended: it may first say that it lost a peer, and its peers say that they lost it (section 1.4). | Raise `processes` under `limits`, and start it again. |
| `a connection waits: too many open files` | The node's process holds as many files as the operating system lets it open, and a peer's connection waits unaccepted; the node tries again every 7 seconds, and says so once while it waits. `file table overflow` in its place is the machine's own table full. | Find what holds the files, or raise the limit of the node's process: `ulimit -n` in the shell that starts it, or `LimitNOFILE=` in its unit (section 1.5). |
| `ernest.conf was read again` | A reload succeeded. | None; the peer lines that follow say what changed. |
| `the peer b was added` / `was removed` / `is now named c` | What the reload changed. | None. |
| `the reload was refused, and the configuration stays as it was: ...` | The directory breaks a rule, a mode among it, or changes `listen` or the key in `private-key.pem`. | Mend what the line names and reload again; for `listen` or the key, restart. |
| `the peer a's spawn at Site was not loaded: the binding Q has no value here` | The spawned function reads a top-level binding whose value lives only where the program that declares it was started. | Run that program on this node, or place the work with a compute on a node that runs it. |
| `the peer a's spawn at Site was not loaded: the module M, which Q calls, is not here`, or `has no function f/0 here` | The program calls a module of the host's directly, through a foreign declaration, and this node finds no such module, or no such function in it, on its load path, to which `--load-path` adds a directory and `--libs-dir` the `ebin` of each of the host's applications under one. | Install the module there, or the right version of it. |
| `the peer a's spawn at Site was not loaded: this node could not take the code it received: ...` | The host refused to compile or load what arrived, a count among the reasons. | Restart the node when convenient. |
| `the peer a's spawn at Site was not loaded: the spawner's node no longer holds the function's reach` | The spawning side let go of the code between asking and sending. | None here; the spawner sees `Io.Other`. |
| `the host has used N of its M module names, which it never gives back` | Four fifths of a host count, from the code the node was sent or loaded. | Plan a restart at a quiet time; the node runs on meanwhile. |
| `the process of Counter.moving:106 faulted: division by zero, spawned by the peer a` | A process a peer spawned here faulted; its trace follows. | The program's author's; the site says where. |
| `the end waits for 1 subscriber: Keeper.main` | Termination has told a subscriber and waits for its answer. | Wait, or a second `ern stop` ends at once, losing what it was writing. |
| `the subscriber Keeper.main answered` | The subscriber has done its work, and the end goes on. Both lines are written at every orderly end of a program with a subscriber, however short the wait. | None. |
| `ern run: dir is the configuration directory of the running node N, which ernest.pid names` | A second start from a directory whose `ernest.pid` a running node holds; the `ern run` command writes it, not a node. | Stop the first, or start from the directory meant. |
| `ern run: a node needs pidfd_open, of Linux 5.3 and later, which this host, Linux 4.15.0-213-generic, does not have` | The operating system cannot say when a process has ended, which a node's lock on `ernest.pid` needs; the `ern run` command writes it. | Run the node on Linux 5.3 or later; in a container, allow the call. |
| `ern stop: dir/ernest.pid: no node holds it: no node runs from the directory` | `ern stop` or `ern reload` with no running node there; `no such file or directory` where the node's end removed the file. The command writes it. | None; the node is already down. |
| `ern run: prog.erc: compiled by another build of ern` | Another release of `ern`, or another build of the same, wrote the `.erc`; the `ern run` command writes it. | Build the program again with the `ern` that runs it. |
| `ern run: the node's carrier did not start: ...` | The part of the node that listens for and dials its peers could not start, its port taken among the reasons; the node ended before its program ran, with status 1, as a job that cannot start, `ern shell:` for a shell's own node. | Free the port or change `listen`, and start again. |

Lines that name a process by its site and say it `faulted`, with no peer named, are the program's own faults, as on one node, and so is one with `, on the peer b` after the cause: a compute this node ran on `b` faulted there, and faulted its caller here with its cause, the trace that crossed beneath it and the caller's frame last. The language guide's §6 and §8.1 teach what they mean to the program's author.

## 8. A deployment, end to end

Three nodes on one machine, a counter served on two of them and a tool that moves both to new code while they run, all from the two builds of section 6.3's example, `upgrade/v1`, whose `serve` is the counter's old loop, and `upgrade/v2`, whose `main` is the tool. Every step is run from `examples/` and shows the command and what each node says; the move when a step fails is in section 7.

**Make the directories.** On one machine `b` and `c` take ports of their own, since two nodes on one machine cannot share one; across machines each may listen on the same port on its own machine.

```console
$ ern config --config-dir a
$ ern config --config-dir b --listen 127.0.0.1:8655
$ ern config --config-dir c --listen 127.0.0.1:8656
```

Each prints its key. Make a fourth, `ops`, for the shell a later step attaches, as `a` was made, with no `--listen`, since `a` and `ops` only dial.

Then `--peer-dir` lists each node where it is to be known (section 2.1):

```console
$ ern config --config-dir a --peer-dir b
$ ern config --config-dir a --peer-dir c
$ ern config --config-dir ops --peer-dir b
$ ern config --config-dir ops --peer-dir c
$ ern config --config-dir b --peer-dir a
$ ern config --config-dir b --peer-dir ops
$ ern config --config-dir c --peer-dir a
$ ern config --config-dir c --peer-dir ops
```

`a`'s and `ops`'s files list `b` and `c` with their keys and addresses, and `b`'s and `c`'s list `a` and `ops` with their keys and no address, since neither listens. Each node then lists exactly who may connect to it and whom it may reach.

**Build and start the counters.** The first build is the counter alone, and its `serve` runs the counter's loop, `count`, as the node's own process:

```console
$ ern build upgrade/v1
$ ern run --config-dir b --main serve upgrade/v1/counter.erc &
$ ern run --config-dir c --main serve upgrade/v1/counter.erc &
```

Each says the address and the port it listens on, `listening on 127.0.0.1:8655` from `b`, and nothing more until a peer connects. The counters wait.

**Check from a shell.** In a terminal of its own, attach a shell to `b` from `ops`, which lists `b` and `c` with their addresses and which they list without one (section 5), and look at `b`:

```
$ ern shell --config-dir ops --attach b
the peer b connected
Ernest 0.11.0, session 1. :help for help.
> :processes
Counter.serve receiving 3120 bytes
```

`b` says `the peer ops connected` as the shell dials it, and `:processes` lists the counter by its site, the entry point `--main` named, waiting for a message. Leave the shell attached.

**Reload a configuration.** Make a directory `d` as `ops` was made, with no `--listen`, list it in `b`'s file with `ern config --config-dir b --peer-dir d`, and reload:

```console
$ ern reload --config-dir b
```

`b` says `ernest.conf was read again` and `the peer d was added`. Nothing connects until `d` dials in.

**Move the counters to new code.** Build the second, which adds the new loop, `countAloud`, `moved` and the tool, and run the tool on `a`:

```console
$ ern build upgrade/v2
$ ern run --config-dir a upgrade/v2/counter.erc
here: 1 moved
inc 3
total: Some(5)
b: 1 moved
c: 1 moved
```

`a` moves a counter of its own first, which on its new loop says each increment message it takes, an `Inc`, as `inc 3`, and answers its total when asked, `total: Some(5)`, `Some` being how Ernest prints a value that is there; then it dials `b` and `c`, each saying `the peer a connected`, and says `the peer b connected` and `the peer c connected` itself, on its standard error, which the block leaves out; on each it spawns a process that lists the counters on the old loop and sends each its message, and the spawn carries `countAloud`, which the peers at the first build lack, with it. The two peers' lines come in the order they answer, each saying that it moved its one counter to the new code, and `a` ends with status 0, each peer saying `the peer a ended`.

**Stop in order.**

```console
$ ern stop --config-dir b
$ ern stop --config-dir c
```

Neither writes a `the end waits for` line, since the counter subscribed to no termination; each tells every connected peer that it ends and exits by the termination signal, status 143 in a shell. The shell attached to `b` ends with it and exits with status 0 (section 5), its last prompt left as it stood and the shell's line under it:

```
> 
the node b ended
```

`b` and `c` never connected to each other, and `a` has ended, so no node hears `c`'s end.

**When a step fails.** A `refused` line at the first connection is a key or a floor, section 7's `refused` rows; a `not loaded` line at the tool's spawn is a binding or a host module the peer lacks, section 7's `not loaded` rows; a peer's line that shows a failure in place of a count, `c: Io.Unreachable`, is a peer the tool could not start on, and its reason. Nothing of the above changes the nodes' directories: a deployment that goes wrong is stopped, the files fixed, and started again.
