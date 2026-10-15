# The guide's passage, *A library that waits*

For the guide's §4.4, after the queue example's closing paragraph and before **Pacing.**, as section 7 says. Written on 2026-10-14 against today's language; `make test-guide` compiled and ran it, 391 examples passing. Under section 3, `gathered`'s `with m` goes.

---

**A library that waits.** A function that receives is tied to the mailbox type of the process it runs in, so a function that must wait on messages of its own, from whatever process calls it, is a process and a call. The library spawns a process whose mailbox is its own, and the caller gets the result by a call, which leaves the caller's mailbox as it was. `gathered` runs `f` on each number in a process of its own and collects the pieces as they come, in any process:

```ernest
// gather.ern
export type Piece(a) = Piece(n : Int, value : a)

type GatherMsg(a) = Collect(Reply(List(Piece(a)))) | Computed(Piece(a)) | Ended(Down)

export fn gathered(numbers : List(Int), f : (Int) -> a with e) : List(Piece(a)) with m = {
    let gatherer = spawn(fn() = run(numbers, f));
    Address.callForever(gatherer, Collect)
}

fn run(numbers : List(Int), f : (Int) -> a with e) : Unit with GatherMsg(a) =
    receive {
        Collect(reply) -> {
            let me = self();
            List.forEach(numbers, fn(n) = {
                let _ = spawnMonitored(fn() = send(me, Computed(Piece(n = n, value = f(n)))),
                                       Ended);
                Unit
            });
            answer(reply, gather(List.size(numbers), 0, []))
        }
    }

// A helper that returned has sent its piece, and its Down keeps no order with
// that message; owed counts the helpers that returned whose piece has not come.
fn gather(running : Int, owed : Int, pieces : List(Piece(a))) : List(Piece(a)) with GatherMsg(a) =
    if running == 0 && owed == 0 then
        pieces
    else receive {
        Computed(piece) -> gather(running, owed - 1, piece :: pieces)
      | Ended(Down(reason = Returned)) -> gather(running - 1, owed + 1, pieces)
      | Ended(_) -> gather(running - 1, owed, pieces)
    }
```

```ernest
// collect.ern
export fn main() : Unit with Never =
    Gather.gathered([3, 1, 2], fn(n) = n * n)
        |> List.sort(fn(a, b) = Int.compare(a.n, b.n))
        |> List.forEach(fn(piece) =
                            Io.println(Int.toString(piece.n) <> ": " <> Int.toString(piece.value)))
```

```console
$ ern run collect.erc
1: 1
2: 4
3: 9
```

`GatherMsg` is the library's own and stays private: the caller sees `gathered`'s signature and nothing of how it waits. `Collect` is a constructor, and a constructor is a function, so it stands where `Address.callForever` wants the function that builds the request. `gather` ends on what it waits for, each helper's end and each piece, and needs no deadline of its own. The helper whose `f` faults sends no piece, and its `Down` says so.

---

And in §8.1, after *Many at once*'s first sentence: "It is §4.4's `gathered` with a compute as each helper's work."
