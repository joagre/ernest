<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="../assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="../assets/ernest-combined-light.svg">
  <img src="../assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>

# Running Ernest

This guide is for the operator: the person who runs Ernest programs as nodes, reads what they write on standard error, and decides when to restart one. It assumes nothing of the language beyond what a program's author tells you about it, and it teaches only what happens at the machine: directories, commands, lines, and the move each line asks for.

A node runs on the Erlang runtime, OTP, which this guide calls the host; the host picks a port, compiles and loads what a peer sends, and counts what it holds.

How a program is written to be found, placed and upgraded across nodes is the language guide's chapter 8, [*Programming in Ernest*](language.md), which this guide points at and does not repeat. The rules themselves are [the report's](../report/language.md), Ernest's definition, §8.7 and §11 above all, and every section here names the section that owns what it teaches.

The commands of sections 1, 5.3 and 8 are run as shown, with other directories and ports, each time Ernest is tested; the service manager's unit, the `kill` lines and the shell session of section 6 are shown and not run. The numbers quoted were measured on one machine, eight cores, and across three machines wired on one LAN, and each says which.

## 1. One node

A program becomes a node by being started with a configuration directory, and nothing else: `prog.erc` is the compiled program, which `ern build` writes; `ern run --config-dir dir prog.erc` is a node, and `ern run prog.erc` is not (report §8.3). The directory is the node's identity, and it is made once.

### 1.1 The directory

```console
$ ern config --config-dir /etc/counter/b
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA...
-----END PUBLIC KEY-----
```

`ern config` creates the directory, which only its owner can open, and in it three files (report §11.3): `private-key.pem`, the node's ed25519 key, readable only by its owner; `certificate.pem`, which the node signs itself and whose dates mean nothing to a node; and `ernest.conf`, which lists nothing yet; section 1.2 says what goes in it. It prints the public key, which is what another node's configuration will list. It fails where the directory exists, empty or not.

The directory is made for one machine and never copied: a copied key gives two nodes one identity, which a third node cannot tell apart. A node also refuses a configuration that lists its own key under `peers`, `a peer has this node's own key, and a node is no peer of itself`.

The directory belongs to the user who runs the node. A node refuses to start from a directory that is not its user's own or the superuser's, from one whose files anyone beyond the owner and the owner's group may write, or whose private key others than its owner may read, and says so.

### 1.2 The configuration

`ernest.conf` is JSON, and Appendix C of the report shows it whole. Its entries, in the order you will meet them:

- `listen`: the address the node's listener binds to, `0.0.0.0:8654` as created, an address of one interface or `0.0.0.0` or `::` for all of them, and a port. Port `0` lets the host pick one, and the node then says `listening on port 51204` on standard error. Two words recur from here: a node *listens* for connections from its peers, and it *dials* a peer when it opens the connection itself, at the address its configuration lists for that peer (report Appendix F). A node without `listen` does not listen and only dials; a bare node (section 3.4) must listen.
- `public-key`: this node's, as `ern config` printed it. It cannot change while the node runs.
- `peers`: a list, each peer with a `name` you choose, which the program uses, its `public-key`, and a `network-address`, `host:port`, which is left out where this node never dials that peer. A host name is resolved at each dial, not when the file is read.
- `services`: a service is a process a program offers under a name, which a program on another node looks up, a *find*, to get its address; under each service's name, the peers that may offer it, in the order a find asks them. A service not listed here is found nowhere from this node.
- `measures`, `utilization` and `utilization-interval`: what the node measures of itself and tells its peers, section 3.
- The node runs over one family of addresses, IPv4 or IPv6, its listener's; a peer's address of the other family is refused when the file is read.

A file that is not JSON, names a field the node does not know or one twice, names a peer twice, gives two peers one key, or lists this node's own key as a peer's, is refused before anything runs, with a line that names the fault (report §8.7, *Its configuration*).

### 1.3 Starting, reloading and stopping

```console
$ ern run --config-dir /etc/counter/b --main Counter.serve /srv/counter/build/counter.erc
```

`--main Counter.serve` names the function the node runs first, its *entry point*, `serve` in the module `Counter`; without it the node runs the program's `main`, and the process that runs it is the *entry process*.

At its start a node computes the values of the program's top-level bindings, the named values a module declares outside any function, as any program does, and only once all have their values does it listen and dial (report §8.5, §8.7).

It writes its process number to `ernest.pid` in its directory and holds the file locked for its life; a second node started from the same directory finds the lock and refuses, and the `ern run` command, not a node, says `ern run: dir is the configuration directory of the running node N, which ernest.pid names`. The host releases the lock however the node ends, so a stale file from a crash is overwritten at the next start.

`ern reload --config-dir dir` sends the node the hangup signal, and the node reads `ernest.conf` again (report §8.7, *A reload*). A peer added is listed and nothing more happens until the program reaches for it: a send to a process there, a find of a service it offers, a spawn, which starts a process there, or a compute, which runs a function there for its value; or until it dials in.

A peer removed, or one whose key changed, has its connection ended, and both nodes treat it as lost (section 2.3); a peer whose address changed keeps its connection, and the next dial uses the new address; a change to `measures`, `utilization` or `utilization-interval` holds from the node's next measure of itself and its next report to its peers (section 3).

The node says `ernest.conf was read again` and a line for each peer added, removed or renamed.

`listen` and `public-key` cannot change while the node runs: a file that changes either, or breaks a rule of section 1.2, is refused with `the reload was refused, and the configuration stays as it was: ...`, and the old configuration stays. `kill -HUP` by the number in `ernest.pid` does the same, and so does the service manager's reload, section 1.5.

`ern stop --config-dir dir` sends the node the termination signal and returns once the node has ended, which it waits for on the lock (report §11.2). Termination is orderly: the processes that subscribed to it are told and the end waits for each to answer, saying `the end waits for 1 subscriber: Keeper.main` while it waits, so that what a program keeps is written; then the node tells each connected peer that it ends, so that the peer says `ended` and not `lost`, and exits.

A second `ern stop` while the first waits is a second termination, which ends the node at once. `kill -TERM` by the number in `ernest.pid` signals without waiting.

Both `ern stop` and `ern reload` fail where no node holds the file, `ern stop: dir/ernest.pid: no node holds it: no node runs from the directory`, or `no such file` where an orderly stop removed it, so that no signal reaches a process whose number the file names by chance.

A bare node, `ern run --config-dir dir` with no program, ends by termination alone, since it has no entry point to return (report §8.7); section 3.4 says what it is for.

### 1.4 Exit statuses and the two streams

A node exits with status 0 when its entry point returns, with the status an `Os.exit` gives, with 1 when its entry process faults or is killed or the program exhausts the host's memory, by the termination signal itself when termination ends it, which a shell shows as 143 and a service manager counts as a clean stop, and with 141 when its output can no longer be written, because what read it has ended (report §11.8).

A service manager that restarts on failure restarts every exit status but 0 and no clean stop, so a node stopped by `ern stop` is not restarted and one that crashed is.

Standard output is the program's own, and the node never changes it. Standard error is the node's: every fault, as `Counter.serve:14 faulted: division by zero`, and every line of section 7. Where standard error is a file or a pipe, and not a terminal or the journal, each line begins with its time in UTC, `2026-10-13T14:22:11.836Z the peer a connected`, so that a file of them is a log (report §11.2). The two streams together are the node's record; keep both.

### 1.5 Under a service manager

A node is run in the foreground and left to the operating system's service manager, which starts it, restarts it and keeps what it writes; `ern` has no mode of its own for it. A unit for systemd, running the counter's node, saved as `/etc/systemd/system/counter-b.service`:

```ini
[Unit]
Description=The counter, node b

[Service]
ExecStart=/usr/local/bin/ern run --config-dir /etc/counter/b --main Counter.serve /srv/counter/build/counter.erc
ExecReload=/usr/local/bin/ern reload --config-dir /etc/counter/b
WorkingDirectory=/srv/counter
Restart=on-failure
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

systemd keeps both streams in its journal, which stamps every line, and `journalctl -u counter-b` reads them. `systemctl reload counter-b` runs the reload, and `systemctl stop counter-b` sends the termination signal and waits `TimeoutStopSec` for the orderly end, after which it kills what still runs; set it longer than the slowest subscriber's answer. `Restart=on-failure` starts the node again after a crash and after an `Os.exit` with a status other than 0, and not after `ern stop`.

Without a service manager, `nohup ern run --config-dir b ... >> b.log 2>&1 &` keeps a node running once its terminal has closed, with the two streams in one file, stamped.

## 2. Two nodes

### 2.1 Listing each other

Each node is made on its own machine with `ern config`, and the two then list each other: node `a`'s `ernest.conf` names `b` with `b`'s public key and `b`'s address, and `b`'s names `a` with `a`'s key, and `a`'s address only where `b` is ever to dial `a`. A peer listed without an address is never dialed, and is out of reach until it dials in; a node that is to be reached must listen. Nothing is shared but the keys, by whatever means you move text between machines; the directories are never copied.

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "<a's key>",
  "peers": [
    { "name": "b", "network-address": "b.example:8654", "public-key": "<b's key>" }
  ],
  "services": { "counter": ["b"] }
}
```

### 2.2 The connection

Two nodes hold at most one connection, opened by the first operation that needs it and over TLS 1.3 with a certificate on each side (report §8.7, *Connections*).

A node accepts a connection only from a peer whose key its configuration lists, and only under the name that key gives it: a node's name on the wire holds a digest of its key and its certificate carries that name, so a certificate that names another than its key gives is refused, and so is a dialed node that answers with another listed peer's key, which a listed key beside the wrong address makes: the dialing node says `the peer c was refused: it answered the dial of the peer b`, and the answering node nothing. Two nodes started from one copied directory have one key, and are one node to their peers (section 7's `replaced` row).

The refusing node says why, `a node with the key ... was refused: no peer has its key`, naming an unlisted node by its key's digest since it has no name here.

Connections are not transitive: that `a` knows `b` and `b` knows `c` connects `a` and `c` in no way, and each pair lists each other.

Two nodes connect only where they stand on one *floor*: one major and minor release of `ern` on one major release of OTP, which the handshake proves before anything passes (report §8.7). A patch release stands on the floor of its minor, so `0.4.0` and `0.4.1` connect, and `0.4.x` and `0.5.0` do not, each saying `the peer b was refused: it stands on another floor, another release or build of ern or another major release of OTP`.

A build of `ern` that is no release stands on the floor of its own code's digest, so two development builds connect only where they are the same build. Nodes of different builds of the *program* connect, and agree on the code they share by a hash of each definition (section 5).

The node says `the peer b connected` as the connection opens, `the peer b ended` when `b` stopped in order, and `the peer b's connection was replaced by another from the same node` where `b` dialed anew while the old connection was alive, as after `b`'s restart.

### 2.3 A lost peer

A connection is lost when the network breaks it, when the detector finds it silent, or when a faulty frame arrives (report §8.7, *A loss*). Any traffic is a sign of life; where nothing else was sent for 15 seconds a tick goes, and a peer from which nothing came in four such intervals is lost, so a silence is found between 45 and 75 seconds after the last traffic, as the host states it, while a peer that closes is found at once.

The node says `the peer b was lost: it fell silent` or `the peer b was lost: it closed`.

What the program sees is the loss run on this node: every process here that watches one of `b`'s processes, through a monitor, is told so, a `Down` message with the reason `Unreachable` (the language guide's §5.2), every call waiting on one of them ends, and a process waiting forever on one faults. Nothing else ends.

The connection is opened again by the next operation that needs it, never in the background: a node that is lost stays lost until an operation that needs it reaches for it, a send, a find, a spawn, a compute or an ask of its utilization (section 3.2), or until it dials in, and a dial that nothing answers is given up after 7 seconds. A peer that cannot be dialed, listed without an address, is reached again only when it dials in.

The move: look at `b`'s machine. If `b` stopped in order you would have read `ended`; `lost` means the network or the process. `b` restarting shows as `connected` again on `a`, or as `replaced` where `a` still believed the old connection alive.

## 3. Services and placement, as the configuration sees them

How a program offers a service, finds one, places a computation and sets its own utilization is the language guide's §8.1 and §8.2. Here is the operator's half: the entries that govern them.

### 3.1 Services

`services` lists, under a name, the peers that may offer it, in the order a find asks them (report §8.7). A find asks the first; where it holds the service the address comes back; where it does not, or is unreachable, the next is asked, and so on within the find's time; a name not listed answers `NotListed` without asking anyone. The order is the preference you give the program, and a reload changes it live.

A service carries a hash of its message type, the type of the messages its process takes. A peer that offers the name at another type answers `OtherType`: two builds of the program disagree on the protocol, and no retry mends it. The move is to align the builds (section 5), or to let the program's author know the type changed under a service that peers still find by its old shape.

### 3.2 How busy a node is

A node measures how busy it is on one scale, 1.0 being every scheduler busy, a scheduler one of the host's threads that run processes, one for each core as a rule, below it room and above it work waiting (report §8.7, *A utilization*). `utilization` in `ernest.conf` says how: `"run-queue"`, the default, divides the processes running or ready by the number of schedulers, an instant reading and not an average; `"schedulers"` gives the fraction of the schedulers' time spent running since the number was last read, which never passes 1.0 and smooths a spiky load.

A program may set the number itself, when it knows its load better than the host does; then this entry is the default it starts from.

A node that lists peers tells each of them its utilization every `utilization-interval` milliseconds, 5000 where the entry is absent, and once as a peer connects. Each node holds the last number heard from each peer, and a program's `Peer.compute` picks the less busy of two peers drawn from them; a number older than twice the interval of the peer that sent it is not used, and a peer never heard from is not chosen. Where a program places work by its own rule, the language guide's §8.1 shows it over `Peer.utilizations()`.

The cost of the telling is one small frame per peer per interval, which replaces the host's own idle ticks rather than adding to them: three idle nodes exchanged about 1.2 packets a second at the default interval, on one machine and across machines alike, each connection carrying two packets a telling. A shorter interval buys fresher numbers for more frames; a longer one the reverse.

### 3.3 The host's measures

`measures` turns on the host's own monitors of the machine, `cpu`, `memory` and `disk`, each with the host's parameters under it, `check-interval` and `almost-full`; a program reads them through the `Utilization` library (report Appendix G.4), and they change nothing of section 3.2's number. None runs where the section is absent, and a reload starts or stops them. They cost what the host's monitors cost and nothing of Ernest's.

### 3.4 A bare node

`ern run --config-dir dir` with no `.erc` starts a bare node (report §8.7): it holds no program of its own, evaluates the standard library and waits, listening for what its peers spawn and compute on it. The code it needs crosses with the first spawn or compute of each function (section 4), and it offers what the processes spawned on it offer, so a bare node is a worker that any program on the floor can give work to by its name.

It must listen, since it never dials, and it ends by termination alone. Its first spawn is the slow one: about 250 milliseconds on a machine of eight cores and 650 on one of two, most of it the host's compiler starting, against the exchange's own cost for every spawn after (section 4.1).

## 4. Code across nodes, as the operator meets it

### 4.1 What crosses, and when

Code crosses between nodes with a spawn and a compute, and nowhere else: not with a message, not with a find, not with a shell's load (report §8.7, *The exchange*). When a program spawns a function on a peer that lacks it, the peer asks for the definitions it lacks among the function and everything the function uses, directly or through others, each known by the hash of its definition, verifies each as it arrives, compiles them together as one module of the host's and loads it whole before the process starts. Nothing compiled ever crosses, and nothing of it runs before all of it is loaded.

A definition that arrived is kept, so the second spawn of the same function ships nothing. On one machine, a spawn whose code crosses costs about 7 milliseconds for one definition, 9 for five and 23 for twenty, against a third of a millisecond for a function the peer already holds; across a wire to a machine of two cores, 17, 27 and 72, most of it that machine's compiler, against about a millisecond and a half, the wire's round trip, for a function it holds.

Two things never cross: a top-level binding's value, which each node computes from its own program at its start, and a module of the host's that the program calls directly, through a foreign declaration, which a node finds on its load path (section 4.3). A spawn whose function needs either on a node that lacks it is not started, and the node says so (section 4.3).

### 4.2 What a node keeps, and when to restart

A node keeps every unit of code it loads, its build's modules, the ones it was sent and the ones a program loaded, for its life (report §11.2, *What a node holds*). The host counts what they add, module names, export entries, function entries and atoms, and never gives one back, so a node that is sent new code without end slowly uses the counts up.

The limits are the host's, 65,536 module names, 524,288 export entries, 524,288 function entries and 1,048,576 atoms, and a node says once, at four fifths of one, `the host has used 52429 of its 65536 module names, which it never gives back`. Past a limit the node runs on and serves what it holds; a spawn or a load that would pass it fails, and the program is given the error `Other` as a `Left`, Ernest's failed result.

How fast the counts move is a question of how much new code a node is sent, not of how long it runs or how much work it does. A node that runs the same build as its peers is sent almost nothing.

One that developers spawn their edits onto, or whose program loads new code into itself often, with `Code.load` (section 5.3), moves them: on one machine, a small definition spawned costs one module name, about five exports, a function entry per lambda and an atom, so two hundred such spawns a day reach four fifths of module names after about 260 such days; a program of twenty modules upgraded whole through `Code.load` reaches four fifths of function entries after about 416 upgrades.

The move is a restart at a time of your choosing: a restarted node holds its build and is sent the rest again as its peers need it, and nothing is lost but what was in its memory, which a node never promises to keep.

### 4.3 The lines a spawn can leave

A spawn or a compute a peer asked for that this node did not start is said on this node's standard error, naming the peer, the site in the program where the spawn is written, and what was lacking (report §8.7, *What it says*):

- `the peer a's spawn at Counter.main:13 was not loaded: the binding Counter.config has no value here`: the function reads a top-level binding whose value lives only where the program that declares it was started. Run that program on this node, or place the work with a compute on a node that runs it.
- `the peer a's spawn at Counter.main:15 was not loaded: the module counter_host, which Counter.tick calls, is not here`, or `has no function tick/0 here`: the program calls a module of the host's directly, through a foreign declaration, and this node finds no such module among the directories it loads code from, its load path, `--load-path` or `--libs-dir`. Install the module there, or the right version of it.
- `the peer a's spawn at Counter.main:17 was not loaded: this node could not take the code it received: ...`: the host refused to compile or load what arrived, a count of section 4.2 passed among the reasons. Restart the node.
- `the peer a's spawn at Counter.main:19 was not loaded: the spawner's node no longer holds the function's reach`: the spawning side let go of the code between asking and sending, as Ernest's shell, `ern shell`, does when a spawn typed at it gave up waiting. Nothing to do here; the spawner sees `Other`.

The program on the spawning side sees each of these as a failed result, a `Left`, with `NotLoaded` for the first two and `Other` for the rest.

## 5. Builds

### 5.1 Several builds on one floor

Nodes of different builds of a program connect, as long as they stand on one floor of `ern` (section 2.2), and they agree on what they share by hash: a service names its message type by the hash of its definition, a spawn names its function by the hash of its definition, and a definition that did not change hashes the same in both builds.

A definition's hash covers the hashes of the definitions it uses, so a fix to one function changes its hash and the hashes of the functions that use it; those cross to a node at the old build, and nothing else; two versions of a type are two types, and a service offered at one is not found at the other, which `OtherType` says (section 3.1).

A build written into a running node's build directory reaches the node at its next start and nothing before; the one way code reaches a running node from disk is `Code.load`, below (report §11.1). Put each build in a directory of its own, and point the service manager's unit at the one you mean.

### 5.2 A fix from a shell

Ernest's shell, `ern shell`, is a prompt that loads a program's modules and evaluates what is typed at it; started with a configuration directory it is a node, `ern shell --config-dir dir prog.erc`, and what it loads or types it can spawn on a peer, the code crossing as any spawn's does (report §11.2).

An operator with a one-line fix loads the fixed module with `:load` and spawns the function that applies it on each peer; the peer keeps the code for its life, and a restart from the old build is the old build again. The language guide's §8.1 shows the spawn; the shell's own commands are its `:help`.

### 5.3 A service moved to new code

A running service is moved to new code by the program's own message, never by the runtime: the service is written to take a message that hands it its new function, and a tool, a program of the author's own, lists the processes running the old function and sends each of them that message (report §6.10, Appendix E.28). How a service is written to take it is the language guide's §8.9; the operator runs the tool.

A service under `restarting` is not moved so: a restart runs the function the service was started with, the old code, at its next fault (report §6.9). Such a service takes new code as a new service, started when the new build's binding is evaluated, by a `Code.load` of the build or a shell's `:reload`, and the old service runs on beside it (report §11.2, Appendix E.28).

The example `examples/upgrade/` is one module, `Counter`, in two builds: the first, [`v1/counter.ern`](../examples/upgrade/v1/counter.ern), is the counter alone, which section 8 starts on the peers, and the second, [`v2/counter.ern`](../examples/upgrade/v2/counter.ern), the counter with a new loop and the tool. Run from `examples/`, with counters of the first build on the peers, the second runs on a node of its own and spawns on every peer a process that moves the peer's counters and says how many it moved.

```console
$ ern build upgrade/v2
$ ern run --config-dir a upgrade/v2/counter.erc
here: 1 moved
inc 3
total: Some(5)
b: 1 moved
```

The tool moves a counter of its own first, which on its new loop says each increment message it takes, an `Inc`, as `inc 3`, and answers its total when asked, `total: Some(5)`, then spawns on each peer a process that moves the peer's and reports, one line a peer; a peer it could not start on is a line with the failure, `c: Unreachable`. The spawn carries `count2`, the new loop, to a peer at the first build, which lacks it and keeps it.

A program may also load a build itself at run time, `Code.load` from its own load path, and list what runs an old function with `Code.running`, which the tool uses (report Appendix E.28).

## 6. Looking in

A shell started beside the nodes is the operator's window, and every look through it is a compute on the node. Start it from a directory of its own that lists the nodes and that they list, with no `listen`, since this shell need only dial, and with the program's build on its load path, so that the shell knows the program's types and checks what it sends; a file given to `ern shell` would run its `main` beside the prompt, which is not wanted here, so the module is loaded at the prompt instead:

The session is abridged: the shell prints each value with its type, and `:load` answers with what it put in scope; `Counter.config` is a binding the program is taken to export.

```
$ ern shell --config-dir ops --load-path /srv/counter/build
> :load Counter
```

Then:

```
> Peer.utilizations()
[#("b", 0.12, 1830), #("c", 0.41, 2210)]
> Peer.computeAt("b", fn() = Process.live(), 5000)
Right([...])
> Peer.computeAt("b", fn() = Counter.config, 5000)
Right(Config(limit = 500))
```

The lambda is written at the shell and runs on `b` with `b`'s own values, as any compute does (report §8.7); `Right(...)` is a successful answer and `Left(...)` a failed one, and `5000` is how many milliseconds the shell waits for it.

The first look at a node pays the dial, the lambda's crossing and the node's first compile, close to a second on a loaded machine, so its time is given generously; the looks after it cost a compute's few hundred microseconds. A binding of the program read this way is the node's, the processes listed are those on the node, and a function of the program called this way runs there.

`Peer.utilization(name, ms)` asks a node now rather than reading the last telling; `Peer.utilizations()` reads what the shell's node holds of its peers, each with how many milliseconds ago it was told. `Process.status(p)` on a process the list gave names the site it was spawned at, a snapshot (report Appendix E.21).

A fault's trace, printed beneath the fault on the node's standard error, names the function by the name its program gives it, and names a received unit `ern$3`, which tells you the code arrived from a peer (report §11.2). Looking costs what one compute costs and changes nothing on the node.

What a shell cannot do yet is attach to a running node: run its inputs there without the wrapping compute, list the node's processes with `:processes`, and load or reload code on the node with `:load` and `:reload`, as `erl -remsh` attaches to an Erlang node. A shell does not attach, and the wrapped compute is the way in; the shell's `:processes` lists the shell's own.

## 7. What a node says, and what to do

Every line below is written once, on the node's standard error, with its time where that is a file or a pipe. Two are written by the `ern run` or `ern stop` command instead of a node, and name the directory as the command line gave it.

The first column is the line as it is written, with the peer's name from `ernest.conf`, or `the node` and its key's digest where it is not listed; `Site` stands for a place in the program, `Module.function:line`, `Q` for a name in the program, `Module.name`, `M` for a module and `N` for a number.

| The line | What happened | The move |
|---|---|---|
| `listening on port 51204` | `listen` had port 0, and the host chose one. | Tell the peers that dial it. |
| `the peer b connected` | A connection opened, dialed by either side. | None. |
| `the peer b ended` | `b` stopped in order; a process here that monitored one of `b`'s was told `ProgramEnd`. | None; expected at `b`'s stop. |
| `the peer b was lost: it closed` | The connection broke at once: `b`'s process died or its machine closed the socket. | Look at `b`'s machine and journal. |
| `the peer b was lost: it fell silent` | Nothing came from `b` for 45 to 75 seconds: network, or a frozen machine. | Look at the network between them; `b` reconnects at the next operation. |
| `the peer b's connection was replaced by another from the same node` | `b` dialed anew while the old connection was believed alive, as after a restart. | None. |
| `a node with the key ... was refused: no peer has its key` | A node dialed in whose key this node's `peers` does not list, named by its key's digest. | Add its key under `peers`, then `ern reload`; or ignore a stranger. |
| `a node named ... was refused: its key gives another name` | A node dialed in under a name that is not the one its key gives, named as it named itself. | Check which key is listed beside which address on the dialing node; a copied directory is not the cause, since a copy has the same key and shows as `replaced`. |
| `the peer c was refused: it answered the dial of the peer b` | This node dialed the address listed for `b`, and the node there holds `c`'s key. | Check which address is listed beside which key on this node; a copied directory is not the cause, since a copy has the same key and shows as `replaced`. |
| `the peer b was refused: its certificate names another host than its key gives` | `b`'s certificate and key disagree: a copied or edited directory. | Make `b`'s directory again with `ern config` on `b`'s machine. |
| `the peer b was refused: it stands on another floor, another release or build of ern or another major release of OTP` | The two run different minor releases of `ern`, different development builds, or different major releases of OTP. | Install one release of each on both. |
| `ernest.conf was read again` | A reload succeeded. | None; the peer lines that follow say what changed. |
| `the peer b was added` / `was removed` / `is now named c` | What the reload changed. | None. |
| `the reload was refused, and the configuration stays as it was: ...` | The new file breaks a rule, or changes `listen` or `public-key`. | Fix the file and reload again; for `listen` or the key, restart. |
| `the peer a's spawn at Site was not loaded: the binding Q has no value here` | A spawned function needs a binding only the declaring program evaluates. | Run that program here, or compute on a node that does. |
| `the peer a's spawn at Site was not loaded: the module M, which Q calls, is not here` | A foreign declaration's host module is missing on this node. | Install the module on the load path. |
| `the peer a's spawn at Site was not loaded: this node could not take the code it received: ...` | The host refused to compile or load the arrival, a count among the reasons. | Restart the node when convenient. |
| `the host has used N of its M module names, which it never gives back` | Four fifths of a host count, from the code the node was sent or loaded. | Plan a restart at a quiet time; the node runs on meanwhile. |
| `Counter.serve:14 faulted: division by zero, spawned by the peer a` | A process a peer spawned here faulted; its trace follows. | The program's author's; the site says where. |
| `the end waits for 1 subscriber: Keeper.main` | Termination has told a subscriber and waits for its answer. | Wait, or a second `ern stop` ends at once, losing what it was writing. |
| `ern run: dir is the configuration directory of the running node N, which ernest.pid names` | A second start from a directory whose `ernest.pid` a running node holds; the `ern run` command writes it, not a node. | Stop the first, or you meant another directory. |
| `ern stop: dir/ernest.pid: no node holds it: no node runs from the directory` | `ern stop` or `ern reload` with no running node there; `no such file` where an orderly stop removed the file. The command writes it. | None; the node is already down. |
| `Site faulted: the node's carrier did not start: ...` | The part of the node that listens for and dials its peers could not start, its port taken among the reasons; the node ended with the fault, named by its entry point's site. | Free the port or change `listen`, and start again. |

Lines that begin with a site and `faulted`, with no peer named, are the program's own faults, as on one node; the language guide's §6 teaches what they mean to its author.

## 8. A deployment, end to end

Three nodes on one machine, a counter served on two of them and a tool that moves both to new code while they run, all from the two builds of section 5.3's example, `upgrade/v1`, whose `serve` is the counter's old loop, and `upgrade/v2`, whose `main` is the tool. Every step is run from `examples/` and shows the command and what each node says; the move when a step fails is in section 7.

**Make the three directories.** On one machine they take three ports; across machines each would be `8654` on its own machine.

```console
$ ern config --config-dir a
$ ern config --config-dir b
$ ern config --config-dir c
```

Each prints its key. Make a fourth, `ops`, for the shell of a later step. Edit `a/ernest.conf` and `ops/ernest.conf` to list `b` and `c` with their keys and addresses, `127.0.0.1:8655` and `127.0.0.1:8656`, and set `b`'s and `c`'s `listen` to those ports, since on one machine the three cannot share `8654`; edit `b/ernest.conf` and `c/ernest.conf` to list `a` and `ops` with their keys and no address, since those two dial them and they never dial back; and remove `listen` from `ops/ernest.conf`, since this shell need only dial. Each node then lists exactly who may connect to it and whom it may reach.

**Build and start the counters.** The first build is the counter alone, and its `serve` runs the counter's loop, `count`, as the node's own process:

```console
$ ern build upgrade/v1
$ ern run --config-dir b --main Counter.serve upgrade/v1/counter.erc &
$ ern run --config-dir c --main Counter.serve upgrade/v1/counter.erc &
```

Each says nothing until a peer connects, since `listen` has a fixed port. The counters wait.

**Check from a shell.** From `ops`, which lists `b` and `c` with their addresses and which they list, start a shell with no file, since a file's `main` would run beside the prompt, and look at `b`:

```
$ ern shell --config-dir ops
> Peer.computeAt("b", fn() = Process.live(), 5000)
```

`b` says `the peer ops connected` as the shell dials it, and the list holds the counter's process, whose `Process.status` names its site in `Counter.serve`.

**Reload a configuration.** Add a peer `d` to `b`'s file, with the key of a directory made with `ern config` as before and no address, and reload:

```console
$ ern reload --config-dir b
```

`b` says `ernest.conf was read again` and `the peer d was added`. Nothing connects until an operation reaches for `d`.

**Move the counters to new code.** Build the second, which adds the new loop, `count2`, and the tool, and run the tool on `a`:

```console
$ ern build upgrade/v2
$ ern run --config-dir a upgrade/v2/counter.erc
here: 1 moved
inc 3
total: Some(5)
b: 1 moved
c: 1 moved
```

`a` moves a counter of its own first, then dials `b` and `c`, each saying `the peer a connected`; on each it spawns a process that lists the counters on the old loop and sends each its message, and the spawn carries `count2`, which the peers at the first build lack, with it. The two peers' lines come in the order they answer. The counters go on with their totals, on the new code, and `a` ends with status 0, each peer saying `the peer a ended`.

**Stop in order.**

```console
$ ern stop --config-dir b
$ ern stop --config-dir c
```

Neither writes a `the end waits for` line, since the counter subscribed to no termination; each tells every connected peer that it ends and exits by the termination signal, status 143 in a shell. `b` and `c` never connected to each other, so the one that hears it is the shell, connected to `b` alone, since it computed on `b` and never dialed `c`, which says `the peer b ended`; no node hears `c`'s end. A monitor it held on a counter gives `ProgramEnd`.

**When a step fails.** A `refused` line at the first connection is a key or a floor, section 7's `refused` rows; a `not loaded` line at the tool's spawn is a binding or a host module the peer lacks, section 4.3; a peer's line that shows a failure in place of a count, `c: Unreachable`, is a peer the tool could not start on, and its reason. Nothing of the above changes the nodes' directories: a deployment that goes wrong is stopped, the files fixed, and started again.
