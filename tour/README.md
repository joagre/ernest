# The tour

Ernest in an evening: one program, a counter, grown through eight chapters from a process with a typed mailbox to the same counter on a node that holds none of its code, moved to new code there. It is for the programmer who has used a functional language and will read neither the report nor the guide first. Every rule the tour meets is the guide's, [*Programming in Ernest*](../guide/language.md), and the tour names the section; what the program has just done that your language cannot, the tour says in one line of its own, naming the claim of [*Why Ernest*](../guide/why.md) it meets.

An hour to read, and about three to do along, with `ern` installed as the [README](../README.md) says and four terminals: your own, the shell's, and from chapter 2 one for each of two nodes. Each chapter is a change to the program, then what was typed and what was printed, then a few sentences. The directories `tour/1/` to `tour/8/` hold the program as it stands at the end of each chapter, each a program of its own. Work in a directory of your own, copy a chapter's files into it as the chapter begins, and from chapter 2 on the shell you started runs to the end.

## 1. The counter

`counter.ern`, the whole program:

```ernest
export type CounterMsg = Inc(Int) | Get(Reply(Int))

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

In the directory that holds it:

```console
$ ern shell
> :load Counter
Counter, compiled from counter.ern
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> send(counter, Counter.Inc(5))
> Address.call(counter, Counter.Get, 1000)
Some(5) : Optional(Int)
> send(counter, "five")
input 5:1:15: the argument does not fit send: expected Counter.CounterMsg, found String
1 | send(counter, "five")
  | ---- send : (Address(a), a) -> Unit
  |               ^^^^^^
```

A counter is a process that holds a number, and `count` is its loop: it takes one message, `Inc` or `Get`, does what the message says, and calls itself with the total. Its type says what it takes, `receiving CounterMsg`; the type is exported so that the prompt can name `Counter.Inc` (the guide's §4.1). `spawn` starts a process on the loop and answers its address, whose type comes from the loop's. `send` puts a message in the mailbox and answers nothing. `Address.call` makes a `Reply`, gives it to `Get`, sends the request and waits up to 1000 milliseconds for the answer, `Some(5)`; `None` would be an answer that did not come (§4.4).

The last input never runs: the address carries the mailbox's type, and a `String` is not a `CounterMsg`. That is the first claim of *Why Ernest*. The mailbox type is in the function's type, so a wrong send is refused before the program runs, and `count` runs only in a process of that type.

`:load` puts a module in scope, compiling it from its source in the directory the shell was started in where nothing compiled is as new, and its line says which it did; `:quit` ends the shell. The guide's §1.2 has the rest of it.

## 2. Two bare nodes

The program does not change. In your own terminal, seven commands:

```console
$ ern config --config-dir a
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA6UybIOO9Cx/+QIRHGqSce3mvI+1v/B3pmkxPHm+wLCk=
-----END PUBLIC KEY-----
$ ern config --config-dir foo --listen 127.0.0.1:8655
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAt0us/x3+136OtVNkAwklPbf6lv1ZhqfVLwyncvrF3Qw=
-----END PUBLIC KEY-----
$ ern config --config-dir bar --listen 127.0.0.1:8656
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEANy/2jjlu+c2WNavTjSFQAoHBb9F3IXodXnpM//xyrdI=
-----END PUBLIC KEY-----
$ ern config --config-dir a --peer-dir foo
$ ern config --config-dir a --peer-dir bar
$ ern config --config-dir foo --peer-dir a
$ ern config --config-dir bar --peer-dir a
```

`a/ernest.conf` now reads:

```json
{
  "listen": "0.0.0.0:8654",
  "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA6UybIOO9Cx/+QIRHGqSce3mvI+1v/B3pmkxPHm+wLCk=\n-----END PUBLIC KEY-----\n",
  "peers": [
    {
      "name": "foo",
      "network-address": "127.0.0.1:8655",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAt0us/x3+136OtVNkAwklPbf6lv1ZhqfVLwyncvrF3Qw=\n-----END PUBLIC KEY-----\n"
    },
    {
      "name": "bar",
      "network-address": "127.0.0.1:8656",
      "public-key": "-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEANy/2jjlu+c2WNavTjSFQAoHBb9F3IXodXnpM//xyrdI=\n-----END PUBLIC KEY-----\n"
    }
  ],
  "services": {}
}
```

In a second terminal `ern run --config-dir foo`, in a third `ern run --config-dir bar`; each waits, saying nothing. Then the shell, started again in your directory as a node:

```console
$ ern shell --config-dir a
> :load Counter
Counter, compiled from counter.ern
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> let far = match Peer.spawn("foo", fn() = Counter.count(0), 5000) { Right(address) -> address | Left(error) -> fault(Io.show(error)) }
the peer foo connected
far : Address(Counter.CounterMsg)
> send(far, Counter.Inc(5))
> Address.call(far, Counter.Get, 1000)
Some(5) : Optional(Int)
```

`foo`'s terminal says `the peer a connected`. A node's line, there and in the shell, begins with the time; the tour leaves it out.

A node is a program, or a shell, started with a configuration directory, and `ern config` makes one: a key, a certificate, and `ernest.conf` with the port the node listens on. `--listen` gives `foo` and `bar` ports of their own, since three nodes on one machine cannot share one, and `--peer-dir` lists one node in another's file by the name of its directory, its key and its address, read from the directory. A node accepts a connection from a listed key alone, and nothing else is set up: two nodes are two files each naming the other, with no cluster to join and no shared secret, the third claim of *Why Ernest* (the deployment guide's §2). `foo` and `bar` are *bare nodes*, started with no program: they hold nothing of the counter's and wait for work.

`Peer.spawn` starts `count` on `foo` and answers its address, or `Left` with the reason it could not; the `match` takes the address and faults on anything else, the shortest way to a `Right` at a prompt (the guide's §2.7). The shell connected to `foo` as the spawn needed it, and `count` crossed with the spawn, since `foo` had no code of it. The counter there is then the counter of chapter 1: the same `send`, the same call, the same answer. That is the second claim of *Why Ernest*: a process started on another node brings its code along, and nothing was installed first.

Chapter 1's counter ended with its shell; this shell runs to the end of the tour. A shell started with `--config-dir` is a node like any other (the guide's §9.2 and §8.1).

## 3. The client

`counter.ern` gains a function that reads a line and does what it says, answering what to print:

```ernest
export fn apply(counter : Address(CounterMsg), line : String) : String =
    match String.words(line) {
        ["inc", text] ->
            match String.toInt(text) {
                Some(amount) -> {
                    send(counter, Inc(amount));
                    "ok"
                }
              | None ->
                    "not a number: " <> text
            }
      | ["get"] ->
            match Address.call(counter, Get, 1000) {
                Some(total) -> Int.toString(total)
              | None -> "no answer"
            }
      | _ ->
            "unknown: " <> line
    }
```

```console
> :reload
Counter, compiled again
> Counter.apply(counter, "inc 3")
"ok" : String
> Counter.apply(far, "get")
"5" : String
```

`apply` is the plain language by the way: a `match` over the list of words, with a pattern for each shape of line; `Optional`, `Some(amount)` or `None`, for a number that may not parse; strings joined with `<>` (the guide's §2.3, §2.5 and §2.6). It sends an `Inc` without waiting and answers `"ok"`, and asks for the total with the call of chapter 1.

`:reload` compiles again every loaded module whose source changed, and says so and nothing more: no type changed, so every binding of the session stands as it was (the guide's §9.3). The counter `apply` is given is a value like any other, so the same function serves the counter here and the one on `foo`, which still holds its 5.

## 4. A fault

`count` refuses a negative amount, and `watch` hears a counter's end:

```ernest
type WatchMsg = Ended(Down)

export fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) -> {
            if amount < 0 then fault("a negative amount") else Unit;
            count(total + amount)
        }
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }

export fn watch(counter : Address(CounterMsg)) : Unit receiving WatchMsg = {
    monitor(Process.fromAddress(counter), Ended);
    receive {
        Ended(Down(reason = reason)) -> Io.println("the counter ended: " <> Io.show(reason))
    }
}
```

```console
> :reload
Counter, compiled again
> kill(counter)
> let counter = spawn(fn() = Counter.count(0))
counter : Address(Counter.CounterMsg)
> Counter.apply(counter, "inc -1")
"ok" : String
input 11:1 faulted: a negative amount
    Counter$3.count:8
> Counter.apply(counter, "get")
"no answer" : String
> let counter = spawn(restarting(RestartLimit(restarts = 1, within = 5000), fn() = Counter.count(0)))
counter : Address(Counter.CounterMsg)
> let watcher = spawn(fn() = Counter.watch(counter))
watcher : Address(Counter.WatchMsg)
> Counter.apply(counter, "inc 2")
"ok" : String
> Counter.apply(counter, "inc -1")
"ok" : String
input 14:1 faulted, restarted: a negative amount
    Counter$3.count:8
> Counter.apply(counter, "get")
"0" : String
> Counter.apply(counter, "inc -1")
"ok" : String
input 14:1 faulted: a negative amount
    Counter$3.count:8
the counter ended: Fault("a negative amount")
```

The precondition is written as the guide's §6.3 writes one: `fault` ends the process with its cause, and nothing catches it. The counter of chapter 3 keeps the loop it was started with, so it is killed and a new one spawned on the new loop (the guide's §4.6). The `inc -1` answers `"ok"`, since a send does not wait, and the fault is reported as the counter meets it, under the input that spawned the process and the place it faulted, `Counter$3.count:8`; the `$3` numbers the module's versions in this session, which chapter 5 comes to. The next `get` has no one to answer it.

A process started under `restarting` runs its function again from the start after a fault, its mailbox emptied and its address kept, so `counter` is still good and the count is gone: `"0"` (§6.5). `RestartLimit(restarts = 1, within = 5000)` allows one restart in five seconds, and the second fault ends the process. `watch` monitors it, so the end arrives as a message of the watcher's own type, `Ended(Down(...))`, with the fault as its reason (§5.2, §6.4). The fault's report and the watcher's line are written as each happens, and in no fixed order.

A program binds such an address at the top of a module and sends to it by name, and the restart is what keeps the binding good; that is Ernest's service, the guide's §6.5, which the tour's counters at the prompt do not need. The counter on `foo` has felt nothing of this.
