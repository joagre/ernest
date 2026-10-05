# Defects found in OTP

The defects of OTP that building Ernest has found, each written as a report for OTP's tracker, [github.com/erlang/otp/issues](https://github.com/erlang/otp/issues), ready to file, and reproduced with OTP alone. Filing is the user's. A report stays here until OTP has fixed its defect in a release Ernest requires. Where a defect still shows in Ernest, the plan's *Standing gaps* says how, and the decisions log why Ernest meets it as it does.

## 1. `erl_child_setup` prints a line when the emulator ends while a port starts

Not filed. Found on 2026-10-01; the log's *A Port Lost While It Starts*.

**Title:** erl_child_setup: "failed with error 32 on line 284" when the emulator dies while a port is starting

**Describe the bug**

When the emulator ends abruptly while it starts a port, by `SIGKILL` or by `SIGINT` under `+B`, the line `erl_child_setup: failed with error 32 on line 284` can appear on standard error. The forked child reads the port's command from the emulator, then waits for the emulator's acknowledgement; an emulator that is gone leaves the child with a broken pipe, which it reports. The helper itself exits silently when it loses the emulator, and the child does not. A program whose output is read by another, or that is meant to end quietly when it is killed, gets a line it did not write.

**To Reproduce**

A loop that starts ports, killed after a second, forty times:

```sh
for i in $(seq 1 40); do
    erl +B -noshell -eval 'L = fun F() ->
        P = open_port({spawn_executable, "/bin/true"}, [exit_status]),
        receive {P, {exit_status, _}} -> ok end,
        F() end, L().' 2> err$i.txt &
    pid=$!; sleep 1; kill -INT $pid; wait $pid
done
grep -l erl_child_setup err*.txt | wc -l
```

On an idle machine 7 of the 40 runs printed:

```
erl_child_setup: failed with error 32 on line 284
```

With `kill -KILL` in place of `kill -INT`, and without `+B`, 9 runs of 30 printed it.

**Expected behavior**

Nothing on standard error: the child exits silently when the emulator is gone, as `erl_child_setup` itself does.

**Affected versions**

OTP 29, erts 17.1, on Linux x86_64.

**Additional context**

Every emulator that looks up its host name at start, as the kernel application does on Linux when no domain is set, starts a port before any user code runs, so a program killed early can print the line though it starts no port of its own.

## 2. A termination signal sent while the emulator starts is lost

Not filed. Found on 2026-10-02; the log's *MVP 2.99b's Questions, One by One*, item 6's second question.

**Title:** SIGTERM sent in the emulator's first ~250 ms is silently ignored

**Describe the bug**

`erl` ends on `SIGTERM` once its signal server runs, with `SIGTERM received - shutting down` and status 0. A `SIGTERM` that arrives earlier is dropped, after the first few milliseconds in which it still kills the process: the node runs on as if nothing came. A service manager that stops a service just after starting it, or a test that does, waits for a program that will never end by the signal.

**To Reproduce**

```sh
for delay in 0.02 0.05 0.1 0.15 0.2 0.3 0.5; do
    erl -noshell -eval 'timer:sleep(3000), io:format("ran to the end~n"), halt(0).' &
    pid=$!; sleep $delay; kill -TERM $pid; wait $pid; echo "delay $delay: status $?"
done
```

On an idle machine:

| Delay | What happened |
|---|---|
| 0.02 s | killed by the signal, status 143 |
| 0.05 to 0.2 s | the signal lost: `ran to the end` after 3 s, status 0 |
| 0.3 s and later | `SIGTERM received - shutting down`, status 0 at once |

**Expected behavior**

A `SIGTERM` sent at any moment ends the node: one that arrives before the signal server runs is held, and handled when it starts.

**Affected versions**

OTP 29, erts 17.1, on Linux x86_64.

**Additional context**

Blocking `SIGTERM` in the parent before it starts `erl` does not help: the emulator never unblocks it, and a signal sent at 1.5 s is lost too.

## 3. The compiler's validator refuses what its type pass made, through `rem`

Not filed. Found on 2026-10-05; the log's *OTP's Compiler, Worked Around*.

**Title:** Internal consistency check failed: bad_arg_type after `rem` in a recursive call

**Describe the bug**

A tail call whose argument is `X rem (X - 3)` makes the compiler fail its own consistency check: `beam_validator` refuses the code the type optimization made. Compiling with `+no_type_opt` succeeds, and the module computes the right answer.

**To Reproduce**

`rem_bug.erl`:

```erlang
-module(rem_bug).
-export([main/0]).

main() -> h([10, -1], 0).

h([], Acc) -> Acc;
h([X | Rest], _) -> h(Rest, X rem (X - 3)).
```

```
$ erlc rem_bug.erl
rem_bug:1: function h/2+14:
  Internal consistency check failed - please report this bug.
  Instruction: {call_only,2,{f,4}}
  Error:       {bad_arg_type,{x,1},{t_integer,{-6,6}},{t_integer,{-1,10}}}:

$ erlc +no_type_opt rem_bug.erl && erl -noshell -eval 'io:format("~p~n", [rem_bug:main()]), halt().'
-1
```

The list needs two elements: with `[5]` alone the module compiles. A constant divisor, `X rem 7`, compiles too, and so does `X div (X - 3)`.

**Expected behavior**

The module compiles, and `rem_bug:main()` returns `-1`.

**Affected versions**

OTP 29, erts 17.1, compiler 10.0.5, on Linux x86_64.

**Additional context**

Found by a generator of random well-typed programs in a compiler that emits Erlang, which compiles a module the validator refuses again with `no_type_opt` until this is fixed.

## 4. `string`'s searches match from inside a grapheme cluster

Not filed. Found on 2026-10-05; the log's *String Stands on the Host*.

**Title:** string:find/split/replace/trim can match inside a grapheme cluster

**Describe the bug**

The `string` module's documentation says it operates on grapheme clusters, and names one exception: clusters of `prepend` code points and of non-modern or decomposed Hangul are not handled in `find/3`, `replace/3`, `split/2`, `split/3` and `trim/3`. But those functions also find a match that begins inside an ordinary grapheme cluster, so long as it ends where a cluster ends. `"\r\n"`, which the documentation of `trim/3` and `lexemes/2` itself calls one grapheme cluster, is cut by a search for `"\n"`; a combining mark is found apart from the letter it belongs to. A search that would end inside a cluster is refused, so the check is made at a match's end and not at its start.

**To Reproduce**

```erlang
1> string:length(<<"a\r\nb">>).
3
2> string:next_grapheme(<<"\r\nb">>).
["\r\n"|<<"b">>]
3> string:find(<<"a\r\nb">>, <<"\n">>).
<<"\nb">>
4> string:split(<<"a\r\nb">>, <<"\n">>, all).
[<<"a\r">>,<<"b">>]
5> string:split("a\r\nb", "\n", all).
["a\r","b"]
6> string:replace(<<"a\r\nb">>, <<"\n">>, <<"-">>, all).
[<<"a\r">>,<<"-">>,<<"b">>]
7> string:trim(<<"a\r\n">>, trailing, [$\n]).
<<"a\r">>
8> string:find(<<"a\x{301}"/utf8>>, <<"\x{301}"/utf8>>).
<<204,129>>
9> string:find(<<"e\x{301}x"/utf8>>, <<"e">>).
nomatch
```

Lines 1 and 2 count and step `"\r\n"` as one grapheme cluster; lines 3 to 7 cut it. Line 8 finds a combining mark apart from its letter, where line 9 refuses a match that would end before one.

**Expected behavior**

Either the functions match whole grapheme clusters, as the module's documentation says, so that line 3 answers `nomatch`, line 4 `[<<"a\r\nb">>]`, and line 7 `<<"a\r\n">>`; or the documentation states that a match may begin inside a grapheme cluster.

**Affected versions**

OTP 29, erts 17.1, on Linux x86_64.

**Additional context**

The same holds of a list argument, line 5. Splitting text at `"\n"` that has Windows line ends is where a program meets it: the parts keep a trailing `"\r"`, or lose it, by whether the cluster is cut.
