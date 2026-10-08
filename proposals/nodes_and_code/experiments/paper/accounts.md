# The accounts system, on paper

Written on 2026-10-08 by a reader of the three proposals, `mvp3.0.md`, `mvp3.1.md` and `mvp3.2.md`, in Ernest as the report defines it plus what the three add: a small web service of two nodes with an accounts store behind it, a bare node as the store's second, a one-shot client and a coordinator, deployed through a fix of logic, a change of protocol, a change of the state's type and a rollback. Where a proposal left a form unsaid the writer wrote the smallest form that let the program go on, marked `// ASSUMED`, and recorded the gap; the gaps were section W of the review's findings, every one of which was decided with the user on 2026-10-08 and is in the proposals as they now stand (the log's *The Three Proposals Reviewed Before Anything Is Built*); the program is kept as written against the proposals of that morning. Nothing here is built or runs.

## The system

Six configuration directories, five of them nodes that run: `store` (the accounts service), `backup` (a bare node, the key's second node), `web1` and `web2` (the HTTP front), `desk` (a one-shot client), and `deploy` (the coordinator, a node like the shell). One source tree, `src/`, built once per build into `build1`, `build2`, and so on. Each node runs its own entry module of the one build.

### Build 1

`src/accounts.ern`, the protocol and the key, shared by the store and its clients:

```ernest
/// The accounts service's protocol and its key.
export type Msg =
    Deposit(account : String, amount : Int)
  | Balance(account : String, reply : Reply(Int))

export let key : Peer.Key(Msg) = Peer.key("accounts")
```

`src/store.ern`, the service, the store node's entry module:

```ernest
/// The accounts store: one service holding every balance, offered under
/// Accounts.key. Its state is the service's, so a planned stop can hand it on.
// ASSUMED: Service.start(key, init, step) is the library's loop, which offers
// the key, holds the state, reads state/<key> at its start and hands the
// state to the planned stop. No proposal says how a service is declared for
// that (finding W1).
export let accounts : Service.Handle(Accounts.Msg, Map(String, Int)) =
    Service.start(Accounts.key, fn() = Map.empty, step)

fn step(balances : Map(String, Int), message : Accounts.Msg) : Map(String, Int) with n =
    match message {
        Accounts.Deposit(account = account, amount = amount) ->
            Map.put(balances, account, balanceOf(balances, account) + amount)
      | Accounts.Balance(account = account, reply = reply) -> {
            answer(reply, balanceOf(balances, account));
            balances
        }
    }

fn balanceOf(balances : Map(String, Int), account : String) : Int =
    Optional.withDefault(Map.get(balances, account), 0)

export fn main() : Unit with Never = wait()

fn wait() : Unit with Never =
    receive {
        after 60000 -> wait()
    }
```

`src/web.ern`, the HTTP front, `web1`'s and `web2`'s entry module:

```ernest
/// The web front: GET /balance/<account> and POST /deposit/<account>/<amount>.
/// It reaches the store through a standing address, which finds the store
/// again on whichever of the key's nodes offers it after a restart.
export fn main() : Unit with Never =
    match Tcp.listen("0.0.0.0", 8080) {
        Right(listener) -> acceptor(standing(), listener)
      | Left(_) -> Io.println("cannot listen")
    }

// The store's standing address, asked for until some node offers the key.
fn standing() : Address(Accounts.Msg) with Never =
    match Peer.standing(Accounts.key, 5000) {
        Right(accounts) -> accounts
      | Left(_) -> receive {
            after 1000 -> standing()
        }
    }

fn acceptor(accounts : Address(Accounts.Msg),
            listener : Address(Tcp.ListenerMsg)) : Unit with Never =
    match Tcp.accept(listener, 60000) {
        Right(socket) -> {
            let handler = spawn(fn() = handle(accounts, socket));
            Tcp.give(socket, Process.fromAddress(handler));
            acceptor(accounts, listener)
        }
      | Left(Io.Timeout) -> acceptor(accounts, listener)
      | Left(_) -> Io.println("cannot accept")
    }

// One process per connection: a request, a response, the close.
fn handle(accounts : Address(Accounts.Msg), socket : Address(Tcp.SocketMsg)) : Unit with m = {
    let response = match Tcp.read(socket, 5000) {
        Right(bytes) -> match requestLine(bytes) {
            Some(#("GET", ["balance", account])) -> {
                let request = fn(reply) = Accounts.Balance(account = account, reply = reply);
                match Address.call(accounts, request, 2000) {
                    Some(balance) -> #(200, Int.toString(balance))
                  | None -> #(503, "the store is away")
                }
            }
          | Some(#("POST", ["deposit", account, text])) -> match String.toInt(text) {
                Some(amount) -> {
                    send(accounts, Accounts.Deposit(account = account, amount = amount));
                    #(202, "")
                }
              | None -> #(400, "")
            }
          | _ -> #(404, "")
        }
      | Left(_) -> #(408, "")
    };
    let _ = Tcp.write(socket, render(response), 5000);
    Tcp.close(socket)
}

// "GET /balance/ada HTTP/1.1": the method and the path's segments.
fn requestLine(bytes : Bytes) : Optional(#(String, List(String))) = {
    let text <- String.fromUtf8(bytes);
    match String.split(text, " ") {
        method :: path :: _ ->
            Some(#(method, List.filter(String.split(path, "/"), fn(segment) = segment != "")))
      | _ -> None
    }
}

fn render(#(status, body) : #(Int, String)) : Bytes = {
    let payload = String.toUtf8(body);
    String.toUtf8("HTTP/1.1 "
                      <> Int.toString(status)
                      <> " \r\ncontent-length: "
                      <> Int.toString(Bytes.size(payload))
                      <> "\r\n\r\n")
        <> payload
}
```

`src/desk.ern`, the client node's one-shot program:

```ernest
/// `ern run --config-dir /etc/ernest/desk desk.erc ada 50` deposits 50 on
/// ada's account and prints her balance.
export fn main() : Unit with Never =
    match #(Os.arguments, Peer.find(Accounts.key, 5000)) {
        #([account, text], Right(accounts)) -> {
            let amount = Optional.withDefault(String.toInt(text), 0);
            send(accounts, Accounts.Deposit(account = account, amount = amount));
            let request = fn(reply) = Accounts.Balance(account = account, reply = reply);
            match Address.call(accounts, request, 2000) {
                Some(balance) -> Io.println(account <> ": " <> Int.toString(balance))
              | None -> Io.println("no answer")
            }
        }
      | #(_, Left(Peer.Timeout)) -> Io.println("the store did not answer")
      | #(_, Left(_)) -> Io.println("the store is not there")
      | _ -> Io.println("usage: desk account amount")
    }
```

### The configuration

`/etc/ernest/web1/ernest.conf` (`web2`'s is the same but for its own key and the alias `web2` swapped for `web1` under `peers`):

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "<web1's public key>",
  "peers": [
    { "name": "store",  "network-address": "store.example:8654",  "public-key": "<store's>" },
    { "name": "backup", "network-address": "backup.example:8654", "public-key": "<backup's>" },
    { "name": "web2",   "network-address": "web2.example:8654",   "public-key": "<web2's>" },
    { "name": "deploy", "public-key": "<deploy's>" }
  ],
  "keys": { "accounts": ["store", "backup"] }
}
```

`/etc/ernest/store/ernest.conf`:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "<store's public key>",
  "peers": [
    { "name": "backup", "network-address": "backup.example:8654", "public-key": "<backup's>" },
    { "name": "web1",   "network-address": "web1.example:8654",   "public-key": "<web1's>" },
    { "name": "web2",   "network-address": "web2.example:8654",   "public-key": "<web2's>" },
    { "name": "desk",   "public-key": "<desk's>" },
    { "name": "deploy", "public-key": "<deploy's>" }
  ],
  "keys": { "accounts": ["backup"] }
}
```

The store cannot list itself under `keys`, the running node being no peer of itself, so its own file says only that `backup` may offer the key too (finding W8). `backup`'s file mirrors the store's. `desk`'s has no `listen`, lists `store` and `backup` with addresses, and `"keys": { "accounts": ["store", "backup"] }`. `/etc/ernest/deploy/ernest.conf` lists all five nodes with addresses and the same `keys`. The `keys` shape, an object from a key's name to a list of aliases, is the writer's, since no proposal gives the JSON (§11.3 is owed, mvp3.2.md §9).

### The first installation

```
ern config --config-dir /etc/ernest/store      # on each machine; prints the public key
ern config --config-dir /etc/ernest/deploy     # on the operator's machine
# the keys printed are pasted into the other files' "peers"
ern build --source-root src --build-root build1 src
# build1 copied to every machine once, this one time: later builds travel by hash
ern run --config-dir /etc/ernest/store  /srv/ernest/build1/store.erc
ern run --config-dir /etc/ernest/backup                                 # a bare node
ern run --config-dir /etc/ernest/web1   /srv/ernest/build1/web.erc
ern run --config-dir /etc/ernest/web2   /srv/ernest/build1/web.erc
ern run --config-dir /etc/ernest/desk   /srv/ernest/build1/desk.erc ada 50
curl -X POST http://web1.example:8080/deposit/ada/25
curl http://web2.example:8080/balance/ada                               # 75
```

### Build 2: a fix of logic

A deposit of a non-positive amount was accepted. `store.ern`'s `Deposit` clause becomes:

```ernest
        Accounts.Deposit(account = account, amount = amount) ->
            if amount <= 0 then
                balances
            else
                Map.put(balances, account, balanceOf(balances, account) + amount)
```

```
ern build --source-root src --build-root build2 src
ern deploy build2 --config-dir /etc/ernest/deploy
```

prints

```
plan: build 1 to build 2
  Accounts.key   logic changed              nothing to write
order: store, backup, web1, web2
```

The operator says yes. The store withdraws its key; the web nodes' standing addresses ask `backup`, which offers nothing yet, so a call through them answers `None` and the front answers 503 for those seconds; the store drains, moves the service to `backup` by `Peer.spawn` from build 2's code with the balances as a captured value, closes, restarts into build 2 from its cache, and is checked; `backup` then stops in its turn, moving the service to the store; then `web1`, then `web2`. `desk` is not in the order, since it is not a running node (finding W10).

### Build 3: a change of protocol

`src/accounts2.ern`, a module of its own, the old `accounts.ern` kept unchanged:

```ernest
/// The accounts protocol of build 3: `Transfer` added, `Balance` retired for
/// `Lookup`, which tells an unknown account from an empty one. `Accounts.Msg`
/// stays in its module while a node of build 2 may still speak it, and
/// `forward` serves it.
export type Msg =
    Deposit(account : String, amount : Int)
  | Transfer(from : String, to : String, amount : Int, reply : Reply(Bool))
  | Lookup(account : String, reply : Reply(Optional(Int)))

export let key : Peer.Key(Msg) = Peer.key("accounts")

/// A message of build 2's protocol to the new service; the retired `Balance`
/// answered here, an unknown account as 0, as build 2 answered it.
export fn forward(message : Accounts.Msg, to : Address(Msg)) : Unit with n =
    match message {
        Accounts.Deposit(account = account, amount = amount) ->
            send(to, Deposit(account = account, amount = amount))
      | Accounts.Balance(account = account, reply = reply) -> {
            let found = Address.callForever(to, fn(asked) = Lookup(account = account, reply = asked));
            answer(reply, Optional.withDefault(found, 0))
        }
    }
```

`store.ern` at build 3: the handle is `Service.Handle(Accounts2.Msg, Map(String, Int))`, started with `Accounts2.key`; `step` takes `Accounts2.Msg`, its `Deposit` as in build 2, `Lookup` answering `Map.get(balances, account)`, and

```ernest
      | Accounts2.Transfer(from = from, to = to, amount = amount, reply = reply) ->
            if amount <= 0 || balanceOf(balances, from) < amount then {
                answer(reply, false);
                balances
            } else {
                answer(reply, true);
                balances
                    |> Map.put(from, balanceOf(balances, from) - amount)
                    |> Map.put(to, balanceOf(balances, to) + amount)
            }
```

Nothing in `store.ern` offers `Accounts.key`: the plan says the old key is "served through Accounts2.forward", so the writer had to assume the runtime or the library spawns the forwarder when a service starts under `Accounts2.key` and a `forward` from `Accounts.Msg` exists in the key's module (finding W3). `web.ern` at build 3 holds `Address(Accounts2.Msg)`, asks `Lookup` (`Some(None)` is 404, `None` is 503) and takes `POST /transfer/<from>/<to>/<amount>`, answered 200 or 409 by the `Bool`. `desk.ern` is unchanged in source and keeps build 2's hashes, since `Accounts.Msg` is unchanged.

```
ern build --source-root src --build-root build3 src
ern deploy build3 --config-dir /etc/ernest/deploy
```

```
plan: build 2 to build 3
  Accounts2.key  protocol added Transfer, retired Balance for Lookup   Accounts2.forward, written
  Accounts.key   served through Accounts2.forward until build 4 drops it
order: store, backup, web1, web2
```

A web node still at build 2 finds `Accounts.key` on the build 3 store and is served through the forward; once at build 3 it finds `Accounts2.key`. `desk` at build 2 is served through the forward for as long as the forward is in the build.

Build 4 deletes `accounts.ern` and `Accounts2.forward`; `desk.ern` moves to `Accounts2`. `ern deploy build4` prints `Accounts: Msg dropped and web2 runs build 2, which speaks Accounts.Msg` and refuses while any node runs build 2, and accepts when none does:

```
plan: build 3 to build 4
  Accounts.key   dropped: no node runs build 2
order: store, backup, web1, web2
```

### Build 5: a change of the state's type

`src/ledger.ern`, a module of its own:

```ernest
/// The store's state of build 5: the balances and a count of the deposits.
/// Build 4's state is `Map(String, Int)`; `migrate` carries it over, and
/// `migrateBack` is the way back.
export type Ledger = Ledger(balances : Map(String, Int), deposits : Int)

export fn migrate(balances : Map(String, Int)) : Ledger =
    Ledger(balances = balances, deposits = 0)

// ASSUMED name: the proposal prints "migrate back" and names no function (finding W7).
export fn migrateBack(ledger : Ledger) : Map(String, Int) =
    ledger.balances
```

`store.ern` at build 5: `Service.Handle(Accounts2.Msg, Ledger.Ledger)`, started with `fn() = Ledger.Ledger(balances = Map.empty, deposits = 0)`, and `step` over the record, `Deposit` giving `Ledger.Ledger(balances = ..., deposits = ledger.deposits + 1)`.

```
ern build --source-root src --build-root build5 src
ern deploy build5 --config-dir /etc/ernest/deploy
```

```
plan: build 4 to build 5
  Accounts2.key  state changed: Ledger.Ledger    Ledger.migrate, written
                 the way back                    Ledger.migrateBack, written
order: store, backup, web1, web2
```

Both lines say `written`, not `derived`: the old state is a `Map`, not a record, and the derivation rule as stated has nothing to match (finding W6). The move from the store to `backup` runs the balances through `migrate` on the successor's side; had `backup` not been listed, the store would have written `state/accounts` with the hash of `Map(String, Int)`'s identity and the value, and build 5's service would have read it through `migrate` at its start.

### The rollback of build 5

```
ern deploy build4 --config-dir /etc/ernest/deploy
```

```
plan: build 5 to build 4
  Accounts2.key  state changed back: Map(String, Int)   Ledger.migrateBack of build 5, written
order: store, backup, web1, web2
```

Accepted, since every protocol build 4 speaks is still served. The stopping store, at build 5, applies `migrateBack` before the state moves or is written, and `deposits` is lost, which is right. By hand, a planned stop of the backup for maintenance is `ern stop --config-dir /etc/ernest/backup --drain 10000`.
