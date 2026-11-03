# The homepage's example

The counter the homepage shows, typed into the shell and spawned on `foo`, the second node of a visitor's container, and the session that does it, which `ern_tour_tests` runs on two nodes as the page shows it.

```ernest
type CounterMsg = Inc(Int) | Get(Reply(Int))

fn count(total : Int) : Unit receiving CounterMsg =
    receive {
        Inc(amount) ->
            count(total + amount)
      | Get(reply) -> {
            answer(reply, total);
            count(total)
        }
    }
```

```console
$ ern shell --config-dir a
Ernest 0.10.0, session 1. :help for help.
> let far <- Peer.spawn("foo", fn() = count(0), 5000)
the peer foo connected
far : Address(CounterMsg)
> send(far, Inc(5))
> Address.call(far, Get, 1000)
Some(5) : Optional(Int)
```
