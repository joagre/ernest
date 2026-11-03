# The tour

*A subtitle, which the description passes over.*

The tour's fixture, a book whose opening lists its chapters, each with a line of its own, which its contents page gives the chapter. A bare §5.4 is the report's, and the guide's §1.1 the guide's.

- [1. The first](#1-the-first): a module and the session that loads it
- [2. The second](#2-the-second): a node's session, with `code` in its line

## 1. The first

`counter.ern`, a file of the reader's, and the session that loads it, which have Copy alone:

```ernest
fn double(value : Int) : Int =
    value * 2
```

```console
$ ern shell
> :load Counter
Counter, compiled from counter.ern
```

The [second chapter](#2-the-second) follows.

## 2. The second

```console
$ ern shell --config-dir a
> Peer.utilizations()
[] : List(#(String, Float))
```
