# Comparison: The Web Server in Ernest and in Erlang

The same program, the same structure, the same error handling: a session process, a sweeper, one handler per connection, an acceptor, parsing with three failing steps, timeouts on the client and on the session lookup. The Ernest version is the process version that [`examples/webserver.ern`](../examples/webserver.ern) had at the time; that document has since moved the session store to an ETS table, which the Erlang version below also could, and the comparison is of the two process versions. The Erlang version below uses `gen_tcp` directly where Ernest assumes `net`.

Counted: lines without blank lines and comments, and characters without indentation. Only the parts fully written in both.

| Part | Ernest lines | Erlang lines | Ernest chars | Erlang chars |
|---|---|---|---|---|
| Processes (sessions, sweeper, handler, acceptor, main) | 61 | 59 | 2022 | 1464 |
| of which type signatures and type declarations | 11 | 0 | 473 | 0 |
| Processes without signatures | 50 | 59 | 1549 | 1464 |
| parse + parseLines | 10 | 8 | 342 | 231 |
| handler alone | 31 | 32 | 971 | 768 |

## Where the Difference Lies

The same number of lines. More characters in Ernest, and they can be pointed out:

1. **Type signatures and type declarations: 473 characters.** Erlang has none. That is not verbosity, it is the language; an Erlang programmer writing `-spec` and `-type` for the same thing lands on the same figure. Without them Ernest is six percent longer than Erlang in the process part.
2. **The filter in selective receive: about 45 characters each time, twice.** `(m -> match m { Data b -> Some b | _ -> None })` against Erlang's pattern directly in `receive`. That is the only per-use cost that is large. Data, not decision.
3. **`Got` and `Timeout`: four lines.** Erlang's `after` is one line. The same number of clauses; Ernest's carry one more word.
4. **`Sys { clock = clock, net = net }`: one line, 35 characters.** Erlang has `gen_tcp` as a global name.
5. **`via X self`: twice, ten characters in total.** Erlang sends `self()`.
6. **`StatusCode.notFound`, `SessionId.fresh seq`: longer names.** Erlang has `status_not_found()`; about equal.

What Erlang lacks and therefore does not pay for: the encapsulation of `SessionId` is a convention in Erlang (`session_parse` can be bypassed), and `{found_session, S}` in `receive` accepts anything with that tag. Ernest's characters buy that the compiler knows what `S` is.

## Conclusion

Afterwards: `receive` was made a form with clauses and `after`, like Erlang's `receive`, and the syntax switched to n-ary functions with parentheses (revision 3). The table is from before both; with parentheses in types and calls the Ernest version is a few percent longer in characters than then, and the same number of lines.

### The conclusion that led there

Without type signatures: six percent more characters, the same number of lines, and almost the whole difference is the filter lambda in `recvFor`. None of the five suspects (`via`, `sys`, match instead of `=`, one function per failing step, field functions) shows up in the figures as more than a line each. What shows is what was not on the list: the filter. If anything is to get shorter it is there.

## The Two Versions

The Ernest version is [`examples/webserver.ern`](../examples/webserver.ern); the Erlang version is [`examples/webserver.erl`](../examples/webserver.erl).
