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

`:load` compiles a module from the file of its name in the directory the shell was started in, `:quit` ends the shell, and the guide's §1.2 has the rest of it.
