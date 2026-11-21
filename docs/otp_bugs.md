# Defects found in OTP

The defects of OTP that building Ernest has found, each written as a report for OTP's tracker, [github.com/erlang/otp/issues](https://github.com/erlang/otp/issues), and reproduced with OTP alone. Filing is the user's, and a report's first line names its issue once it is filed. A report stays here until OTP has fixed its defect in a release Ernest requires, and one OTP will not fix stays; the release review reads OTP's release notes and the issues' states against the reports ([`reviews/release.md`](reviews/release.md), step 6). Where a defect still shows in Ernest, the code's comment at the place says how, and the decisions log why Ernest meets it as it does.

## 1. `erl_child_setup` prints a line when the emulator ends while a port starts

Filed 2026-11-15 as [erlang/otp#12203](https://github.com/erlang/otp/issues/12203). Found on 2026-10-01; the log's *A Port Lost While It Starts*.

**Title:** erl_child_setup: "failed with error 32 on line 284" when the emulator dies while a port is starting

**Describe the bug**

When the emulator ends abruptly while it starts a port, by `SIGKILL` or by `SIGINT` under `+B`, the line `erl_child_setup: failed with error 32 on line 284` can appear on standard error. The forked child reads the port's command from the emulator, then waits for the emulator's acknowledgment; an emulator that is gone leaves the child with a broken pipe, which it reports. The helper itself exits silently when it loses the emulator, and the child does not. A program whose output is read by another, or that is meant to end quietly when it is killed, gets a line it did not write.

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

Filed 2026-11-15 as [erlang/otp#12204](https://github.com/erlang/otp/issues/12204). Found on 2026-10-02; the log's *MVP 2.99b's Questions, One by One*, item 6's second question.

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

Filed 2026-11-15 as [erlang/otp#12205](https://github.com/erlang/otp/issues/12205). Closed on 2026-11-16 as fixed in OTP's `master`, for OTP 30, and not in OTP 29: "The fix is too complex to backport to OTP 29." The report stays until Ernest requires a release that holds the fix. The answer was acknowledged with a thumbs-up on 2026-11-17. Found on 2026-10-05; the log's *OTP's Compiler, Worked Around*.

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

Filed 2026-11-15 as [erlang/otp#12206](https://github.com/erlang/otp/issues/12206). Found on 2026-10-05; the log's *String Stands on the Host*.

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

## 5. `memsup` closes its port while a collection is under way

Filed 2026-11-15 as [erlang/otp#12207](https://github.com/erlang/otp/issues/12207). Found on 2026-10-09; `src/nodes/test/ern_node_tests.erl`'s `collected/0` says how Ernest meets it.

**Title:** memsup: "Error writing to pipe: Broken pipe" when os_mon is stopped during a memory collection

**Describe the bug**

When `memsup` is stopped while its port program is answering a request for memory data, the line `Error writing to pipe: Broken pipe` appears on standard error. On a stop, the process that owns the port sends the program `EXIT` and closes the port at once, whatever the program is doing (`port_shutdown/1` in `memsup.erl`, called from `get_memory_usage/3` and the other waiting loops on `close`). A program that is writing its answer then writes to a pipe whose other end is gone, and `send` and `send_tag` in `memsup.c` report the failed `write` with `perror` and exit. `memsup` asks for a collection as soon as it starts, so stopping `os_mon` just after starting it meets this nearly every time. A program that starts and stops its measures, or reloads their parameters, gets a line it did not write.

**To Reproduce**

`os_mon` started with `memsup` alone and stopped at once, twenty times in one emulator:

```sh
erl -noshell -eval '
    application:load(os_mon),
    ok = application:set_env(os_mon, start_cpu_sup, false),
    ok = application:set_env(os_mon, start_disksup, false),
    Run = fun() ->
        {ok, _} = application:ensure_all_started(os_mon),
        ok = application:stop(os_mon)
    end,
    [Run() || _ <- lists:seq(1, 20)],
    halt().' > /dev/null
```

On an idle machine three runs printed the line 20, 19 and 20 times:

```
Error writing to pipe: Broken pipe
```

With `_ = memsup:get_system_memory_data()` between the start and the stop, so that the stop comes once a collection has ended, three runs printed nothing.

**Expected behavior**

Nothing on standard error: a stop during a collection waits for the program's answer, or tells the program to end without the program reporting the closed pipe as an error.

**Affected versions**

OTP 29.1, erts 17.1, os_mon 2.12, on Linux x86_64.

**Additional context**

The line comes from the port program, not from the emulator, so no logger filter removes it. A program that stops `os_mon` can avoid it only by finishing a collection first, `memsup:get_system_memory_data/0` among the ways, which costs a collection at every stop.

## 6. `erl_lint`'s check of unused functions costs the square of the module

Filed 2026-11-15 as [erlang/otp#12208](https://github.com/erlang/otp/issues/12208). Found on 2026-10-26; the log's *The Build's Cost per Function*.

**Title:** erl_lint: check_unused_functions is quadratic in the number of unused functions

**Describe the bug**

A module of N functions that are not exported and not called compiles in time that grows with N squared: `check_unused_functions` in `erl_lint.erl` (stdlib 8.1, line 1772) costs unused × functions. With `+nowarn_unused_function` the same module compiles in linear time.

**To Reproduce**

A module of N functions none of which is exported or called:

```
$ python3 -c "n=8000; print('-module(unused_%d).' % n); print('-export([main/0]).'); print('main() -> ok.')
for i in range(n): print('f%d(X) -> X + %d.' % (i, i))" > unused_8000.erl
```

```
$ time erlc unused_2000.erl    # 2.3 s
$ time erlc unused_4000.erl    # 9.1 s
$ time erlc unused_8000.erl    # 41.2 s
$ time erlc unused_16000.erl   # 198.7 s
$ time erlc +nowarn_unused_function unused_8000.erl    # 0.8 s
```

**Expected behavior**

The check costs what the module's size costs: 8,000 functions in well under a second, as with the warning off.

**Affected versions**

OTP 29, erts 17.1, stdlib 8.1, on Linux x86_64.

**Additional context**

Found by measuring a compiler that emits Erlang, whose test module of 7,000 unexported functions compiles through the host in 3.3 s where the warning is off; a module that is linted with the warning on pays the square.


## 7. The type pass types a function again after each local function it calls

Filed 2026-11-15 as [erlang/otp#12209](https://github.com/erlang/otp/issues/12209). Closed on 2026-11-16 as one OTP will not fix: "This is well-known, and is how success typing works." The report stays. The answer was acknowledged with a thumbs-up on 2026-11-17. Found on 2026-10-26, measured on 2026-10-30; the log's *The Build's Cost per Function* and *One Function per Initializer*.

**Title:** beam_ssa_type: signatures/2 is quadratic in the number of distinct local functions one function calls in sequence

**Describe the bug**

A function that calls N distinct local functions one after another compiles in time that grows with N squared. The signature pass in `beam_ssa_type.erl` (compiler 10.0.5) takes a local function it has not yet typed for one that never returns: `sig_local_return/4` (line 365) finds no success types, `return_type/2` (line 1947) answers `none`, and the code after the call is unreachable. The caller is typed up to the first such call, the callee is typed, and its new return type puts the caller back on the work list (`do_sig_function/4`, line 197). Each of the N callees costs one more pass over the caller.

**To Reproduce**

A module whose `main/0` calls `f0/0` to `fN-1/0` in turn, each a function of its own, and the same module with each call written `?MODULE:fK()`, every function exported:

```
$ python3 -c "
import sys
n=int(sys.argv[1])
print('-module(calls_%d).' % n)
print('-export([main/0]).')
print('main() ->')
for i in range(n): print('    f%d(),' % i)
print('    ok.')
for i in range(n): print('f%d() -> erlang:put(%d, %d).' % (i, i, i))
" 4000 > calls_4000.erl
```

```
$ time erlc calls_1000.erl     # 2.8 s
$ time erlc calls_2000.erl     # 9.2 s
$ time erlc calls_4000.erl     # 41.4 s
$ time erlc +no_type_opt calls_4000.erl    # 2.0 s
$ time erlc remote_4000.erl    # 2.4 s, each call ?MODULE:fK()
```

**Expected behavior**

The pass costs what the module's size costs, as with remote calls or with `no_type_opt`. Typing each callee before going on with the caller, or going on past a callee not yet typed instead of taking its call as one that never returns, would make each callee cost one pass.

**Affected versions**

OTP 29, erts 17.1, compiler 10.0.5, on Linux x86_64.

**Additional context**

Found by a compiler that emits Erlang, whose module initialization calls one function for each top-level binding: 2,000 bindings took 11.3 s to build called locally and 4.05 s called by the module's name, which the compiler writes until this is fixed.

## 8. A module's purge costs the process limit, not the processes alive

Filed 2026-11-15 as [erlang/otp#12210](https://github.com/erlang/otp/issues/12210), and a misfeature rather than a bug: nothing in OTP's documentation promises otherwise, and a fixed process table is the emulator's design. Found on 2026-10-30; the log's *A Line-Mode Input's Cost*.

**Title:** code:purge/1 walks the whole process table, so its cost follows +P and not the number of live processes

**Describe the misfeature**

Purging a module costs time proportional to the emulator's process limit, `+P`, whatever the number of processes alive: the code purger's check of each process for the old code, and the literal area collector's, walk every slot of the process table. A program that loads, deletes and purges small modules often, a shell compiling each input to a module of its own, pays 5 ms a cycle at the default limit and 270 ms at the largest, with the same 43 processes alive.

**To Reproduce**

A module of one function, loaded from its binary, deleted and purged a hundred times, the cycle timed, at three process limits:

```erlang
-module(run).
-export([main/0]).
main() ->
    {ok, Bin} = file:read_file("one.beam"),
    Cycle = fun() -> {module, one} = code:load_binary(one, "one.beam", Bin),
                     true = code:delete(one), false = code:purge(one) end,
    Cycle(), Cycle(),
    {T, _} = timer:tc(fun() -> [Cycle() || _ <- lists:seq(1, 100)] end),
    io:format("~p processes allowed, ~p alive: ~.2f ms a cycle~n",
              [erlang:system_info(process_limit), erlang:system_info(process_count), T / 100000]),
    halt().
```

```
$ erl +P 1024 -noshell -s run main
1024 processes allowed, 43 alive: 0.92 ms a cycle
$ erl +P 1048576 -noshell -s run main
1048576 processes allowed, 43 alive: 5.47 ms a cycle
$ erl +P 134217727 -noshell -s run main
134217727 processes allowed, 43 alive: 274.27 ms a cycle
```

**Expected behavior**

A purge costs what the processes alive cost, a fraction of a millisecond with 43 of them, at any limit.

**Affected versions**

OTP 29, erts 17.1, on Linux x86_64.

**Additional context**

Found by measuring a shell that compiles each input to a module of its own and purges it afterward, where the purge was a third of an input's cost; the shell's answer was to purge less.

## 9. `ssl:format_error` does not describe the file errors `ssl:listen` returns

Filed 2026-11-15 as [erlang/otp#12211](https://github.com/erlang/otp/issues/12211). Answered on 2026-11-16: the function is little used at OTP, a pull request is welcome, and OTP will not give it time now. The answer was acknowledged with a thumbs-up on 2026-11-17. Found on 2026-11-01, building TLS in `Tcp` (the log's *TLS in `Tcp` and a Terminal in `Os`*); `src/runtime/ern_tcp.erl`'s `file_error/2` reads the file and the reason from the term instead (the log's *Two Lines on TLS*).

**Title:** ssl:format_error/1 gives "Invalid TLS option" for a certfile or keyfile ssl:listen cannot read

**Describe the bug**

`ssl:listen/2` reads its certificate and key files as it listens, and for a file it cannot read answers `{error, {options, {keyfile, {File, Reason}}}}`, `Reason` a POSIX code (`validate_cert_keys_pems/2` in `ssl_config.erl`, ssl 11.7.6). `ssl:format_error/1` describes a file error only in the form the connection's own reading raises, `{options, {FileType, File, {error, Reason}}}`, which `ssl:connect/4` answers for a CA file it cannot read. The listen's form falls to the clause for any option, so its text names no file error and prints the term, path and code as Erlang writes them, pretty-printed across lines where the path is long.

**To Reproduce**

```sh
touch unreadable.key && chmod 000 unreadable.key
erl -noshell -eval '
    {ok, _} = application:ensure_all_started(ssl),
    Show = fun(R) -> io:format("~p~n~s~n~n", [R, ssl:format_error(R)]) end,
    {error, A} = ssl:listen(0, [{certfile, "missing.pem"}, {keyfile, "missing.key"}]), Show(A),
    {error, B} = ssl:listen(0, [{certfile, "cert.pem"}, {keyfile, "unreadable.key"}]), Show(B),
    {ok, L} = gen_tcp:listen(0, []), {ok, P} = inet:port(L),
    {error, C} = ssl:connect("localhost", P, [{verify, verify_peer},
                                              {cacertfile, "missing_ca.pem"}], 1000), Show(C),
    halt().'
```

`cert.pem` is any certificate in PEM. The output, the CA file's path shortened:

```
{options,{certfile,{"missing.pem",enoent}}}
Invalid TLS option: {certfile,{"missing.pem",enoent}}

{options,{keyfile,{"unreadable.key",eacces}}}
Invalid TLS option: {keyfile,{"unreadable.key",eacces}}

{options,{cacertfile,"/tmp/missing_ca.pem",{error,enoent}}}
Invalid CA certificate file /tmp/missing_ca.pem: no such file or directory
```

**Expected behavior**

The listen's errors are described as the connect's is: `Invalid certificate file missing.pem: no such file or directory` and `Invalid key file unreadable.key: permission denied`. Either `ssl:listen` answers the form `format_error/1` describes, or `format_error/1` describes both.

**Affected versions**

OTP 29, erts 17.1, ssl 11.7.6, on Linux x86_64.

**Additional context**

`format_error/1`'s file clause would not describe the listen's code alone either: given `{options, {keyfile, "missing.key", enoent}}` it answers `Invalid key file missing.key: decoding error`, since `file_error_format/1` takes `{error, Reason}`.

## 10. `ssl:close/2` ignores the time it is given

Filed 2026-11-15 as [erlang/otp#12212](https://github.com/erlang/otp/issues/12212). Answered on 2026-11-16: the two waits come of "a very old work around", and OTP will look at whether it can be removed. The answer was acknowledged with a thumbs-up on 2026-11-17. Answered again on 2026-11-18: the workaround is needed on no supported platform, and OTP proposes [#12237](https://github.com/erlang/otp/pull/12237), against `maint` and open on 2026-11-21, by which a close no longer waits for the peer's close, the alert's wait takes the time `close/2` is given and `close/1` 5000 ms, and `alert_timeout` defaults to 0. That answer was acknowledged with a thumbs-up on 2026-11-22.

Found on 2026-11-01, building TLS in `Tcp` (the log's *TLS in `Tcp` and a Terminal in `Os`*, *The TLS linger bound*), and measured on 2026-11-02; `src/runtime/ern_tcp.erl`'s `close_socket/3` hands a socket over TLS to its closer, and Appendix E.18 states the host's bound, up to 10 seconds past the one it states for a plain socket.

**Title:** ssl:close/2 closes a TLS connection in its own two 5-second waits whatever Timeout it is given

**Describe the bug**

`ssl:close(SslSocket, Timeout)` accepts a timeout for a connection (`close/2` in `ssl.erl`, ssl 11.7.6, the clause guarded by `?IS_TIMEOUT(Timeout)`), and `ssl_gen_statem:close/2` carries it as `{close, Timeout}`. The connection's `handle_call({close, _} = Close, ...)` calls `terminate(Close, StateName, State)`, and `terminate/3`'s clause for the `connection` state reads nothing of its reason: it sends the close alert through `tls_sender:send_and_ack_alert/2`, a `gen_statem:call` with `?DEFAULT_TIMEOUT`, 5000 ms, whose failure a `catch` swallows, and then calls `Connection:close({close, ?DEFAULT_TIMEOUT}, ...)`, which shuts the socket's write side and waits in `Transport:recv(Socket, 0, 5000)` for the far end.

Where the far end takes nothing, the sender is behind the full socket and cannot write the alert, and the far end answers no close, so a close takes 10 seconds, the same with `ssl:close/1`, with a timeout of 1000 and with one of 100. Only the downgrade form, `{NewController, Timeout}`, and the `{shutdown, own_alert}` path, which reads the application's `alert_timeout`, honor a time.

**To Reproduce**

```sh
erl -noshell -eval '
    {ok, _} = application:ensure_all_started(ssl),
    Key = [{key, {rsa, 2048, 65537}}],
    #{server_config := S, client_config := C} =
        public_key:pkix_test_data(#{server_chain => #{root => Key, intermediates => [], peer => Key},
                                    client_chain => #{root => Key, intermediates => [], peer => Key}}),
    Run = fun(How) ->
        {ok, L} = ssl:listen(0, [binary, {active, false} | S]),
        {ok, {_, Port}} = ssl:sockname(L),
        Self = self(),
        spawn(fun() -> {ok, Cl} = ssl:connect("localhost", Port,
                                              [binary, {active, false}, {verify, verify_none} | C], 5000),
                       Self ! connected, receive done -> ssl:close(Cl) end end),
        {ok, T} = ssl:transport_accept(L, 5000), {ok, Srv} = ssl:handshake(T, 5000),
        receive connected -> ok end,
        %% fill the far end, which reads nothing, until a write hangs
        Fill = fun Fill() -> P = self(),
                             W = spawn(fun() -> P ! {sent, ssl:send(Srv, binary:copy(<<0>>, 65536))} end),
                             receive {sent, ok} -> Fill() after 2000 -> exit(W, kill) end end,
        Fill(),
        T0 = erlang:monotonic_time(millisecond),
        R = case How of none -> ssl:close(Srv); Ms -> ssl:close(Srv, Ms) end,
        io:format("close ~p: ~p in ~p ms~n", [How, R, erlang:monotonic_time(millisecond) - T0]),
        ssl:close(L)
    end,
    [Run(How) || How <- [none, 1000, 100]],
    halt().'
```

The output:

```
close none: ok in 10002 ms
close 1000: ok in 10002 ms
close 100: ok in 10002 ms
```

**Expected behavior**

A close given a timeout returns within it, the alert's write and the wait for the far end's close bounded by it together, as `close/2`'s type promises; or the documentation of `close/2` says that the timeout bounds the downgrade alone and a plain close waits up to 10 seconds.

**Affected versions**

OTP 29, erts 17.1, ssl 11.7.6, on Linux x86_64.

**Additional context**

The two waits are `?DEFAULT_TIMEOUT` of `ssl_internal.hrl`. A program that closes a connection whose far end has stopped reading, a server dropping a stalled client, holds the closing process for 10 seconds per connection, which it can escape only by closing from another process or by `ssl:shutdown/2` and a close of the transport socket behind ssl's back.

## 11. `json:decode` answers a broken literal by the count of bytes after it, not by the byte that differs

Filed 2026-11-15 as [erlang/otp#12213](https://github.com/erlang/otp/issues/12213). Found on 2026-11-02 by the release review before 0.9.0 (its finding E4-2); `src/libs/json/ern_json.erl`'s `broken_literal/2` reads the text for the byte that differs instead.

**Title:** json:decode/1,3: a broken `true`, `false` or `null` raises unexpected_end, or invalid_byte at the byte after its first, whichever byte differs

**Describe the bug**

A value that begins with `t`, `f` or `n` but is not the literal is answered by how many bytes follow its first byte, not by which byte differs. Where fewer bytes follow than the rest of the literal has, `true/6`, `false/6` and `null/6` hand `unexpected/8` the literal's length, and it answers as if the input were cut short, which `decode/1` and `decode/3` raise as `unexpected_end` though the input holds the byte that differs. Where more follow, it raises `{invalid_byte, Byte}` at the byte after the literal's first, which may be a byte of the literal itself. The position is wrong in the second case and missing in the first, and a program that reports where a document is broken points at the wrong place.

**To Reproduce**

```sh
erl -noshell -eval '
    Show = fun(Text) ->
        try json:decode(Text) of Value -> io:format("~s: ~p~n", [Text, Value])
        catch error:Error:Stack ->
            [{json, _, _, Info} | _] = Stack,
            Where = case proplists:get_value(error_info, Info) of
                        #{cause := #{position := Position}} -> [{position, Position}];
                        undefined -> []
                    end,
            io:format("~s: ~p ~p~n", [Text, Error, Where])
        end
    end,
    [Show(Text) || Text <- [<<"[t]">>, <<"[nul]">>, <<"trux">>, <<"[tru, 1]">>, <<"[falsy]">>,
                            <<"[true]">>]],
    halt().'
```

The output:

```
[t]: unexpected_end []
[nul]: unexpected_end []
trux: unexpected_end []
[tru, 1]: {invalid_byte,114} [{position,2}]
[falsy]: {invalid_byte,97} [{position,2}]
[true]: [true]
```

**Expected behavior**

The first byte that differs from the literal is the invalid one, at its own position: `{invalid_byte, $]}` at 2 for `[t]`, at 4 for `[nul]`, `{invalid_byte, $x}` at 3 for `trux`, `{invalid_byte, $,}` at 4 for `[tru, 1]` and `{invalid_byte, $y}` at 5 for `[falsy]`; `unexpected_end` only where the input ends inside the literal, `[tru` or `fals`. `decode_start/3` may still answer `continue` where the bytes it has match the literal so far.

**Affected versions**

OTP 29, erts 17.1, stdlib 8.1, on Linux x86_64.

**Additional context**

An escape meets the same rule: `["\u12"]` raises `{unexpected_sequence, <<"\\u12\"]">>}`, the six bytes from the backslash, past the string's end, and `["\u1"]` raises `unexpected_end`, where the escape's first byte that is no hexadecimal digit is the one that cannot stand.

## 12. A connection accepted or dialed at a full table of processes ends the distribution

Filed 2026-11-15 as [erlang/otp#12214](https://github.com/erlang/otp/issues/12214). Found on 2026-11-08 (the log's *A Node's Own Processes at a Full Table*), the dial on the same day (the log's *The Carrier's Acceptor at a Full Table*); a node's own acceptor over `inet_tls_dist` closes a connection it cannot serve (`ern_tls_dist`), and report §12.5 states that the dial, which no distribution module reaches, ends the node (the log's *A Full Table's Answers, Built*).

**Title:** net_kernel terminates, and with it the emulator, when a connection is accepted or dialed while the process table is full

**Describe the bug**

When a node's process table is full and another node connects, `net_kernel:handle_info({accept, ...})` calls `inet_tcp_dist:gen_accept_connection/6`, whose `spawn_opt` raises `system_limit`. Nothing catches it, so `net_kernel` terminates, `kernel` shuts down and the emulator halts with a crash dump. A full table is a condition a node recovers from once processes end; here the node is gone.

Over `inet_tls_dist` the acceptor's loop dies on its `spawn_link` instead, printing its own error report, and the node never accepts a connection again. Where processes are being spawned beside it, `net_kernel`'s handling of the acceptor's exit raises within `catch`, `handle_info/2` returns the `{'EXIT', ...}` term, and `net_kernel` terminates with `bad_return_value`.

A node whose table is full and that dials another, by a send to a process there, meets the same in `net_kernel:setup_check/5`, whose `spawn_link` of the check raises in `handle_info({auto_connect, ...})`, before any distribution module is called.

**To Reproduce**

A node whose table holds 1024 processes, filled, and a second node that pings it:

```sh
erl -sname full_a -setcookie c +P 1024 -noshell -eval '
    Fill = fun F(N) -> try spawn(fun() -> receive _ -> ok end end) of
                           _ -> F(N + 1)
                       catch error:system_limit -> N end end,
    io:format("filled ~p~n", [Fill(0)]),
    timer:sleep(4000),
    halt().' > a.txt 2>&1 &
sleep 1
erl -sname dial_b -setcookie c -noshell -eval '
    {ok, H} = inet:gethostname(),
    io:format("ping ~p~n", [net_adm:ping(list_to_atom("full_a@" ++ H))]),
    halt().'
wait
cat a.txt
```

The dialing node prints `ping pang`, and the full node:

```
** Generic server net_kernel terminating
** Last message in was {accept,<0.67.0>,#Port<0.5>,inet,tcp}
** Reason for termination ==
** {system_limit,[{erlang,spawn_opt,
                          [inet_tcp_dist,do_accept, ...],
                          [link,{priority,max}]], ...},
                  {inet_tcp_dist,gen_accept_connection,6,
                                 [{file,"inet_tcp_dist.erl"},{line,339}]},
                  {net_kernel,handle_info,2,
                              [{file,"net_kernel.erl"},{line,1430}]}, ...]}
Kernel pid terminated (application_controller) ("{application_terminated,kernel,shutdown}")
```

The dial, from a node whose table is full to one that waits:

```sh
erl -sname dial_b -setcookie c -noshell -eval 'receive after 6000 -> halt() end.' &
sleep 1
erl -sname full_a -setcookie c +P 1024 -noshell -eval '
    Fill = fun F(N) -> try spawn(fun() -> receive _ -> ok end end) of
                           _ -> F(N + 1)
                       catch error:system_limit -> N end end,
    io:format("filled ~p~n", [Fill(0)]),
    {ok, H} = inet:gethostname(),
    {x, list_to_atom("dial_b@" ++ H)} ! hi,
    receive after 1000 -> ok end,
    halt().'
wait
```

The full node prints:

```
** Generic server net_kernel terminating
** Last message in was {auto_connect,dial_b@nike, ...}
** Reason for termination ==
** {system_limit,[{erlang,spawn_link, ...},
                  {erlang,spawn_link,1,[]},
                  {net_kernel,setup_check,5,
                              [{file,"net_kernel.erl"},{line,2348}]},
                  {net_kernel,do_auto_connect_2,5,
                              [{file,"net_kernel.erl"},{line,1100}]}, ...]}
```

**Expected behavior**

A connection the node has no room to serve is closed, its refusal logged once, and `net_kernel` and the acceptor live on, so that the node accepts again once processes have ended, as `gen_tcp:accept` answers `{error, system_limit}` and its caller decides. A dial the node has no room for fails as a refused one does, `net_kernel` living on, as `do_spawn/3` already catches its own spawn.

**Affected versions**

OTP 29, erts 17.1.1, kernel 11.0.4, ssl 11.7.8, on Linux x86_64.

**Additional context**

The emulator's own `Too many processes` report is printed for each refused spawn as well. A node can refuse an accepted connection itself only where its distribution module catches the limit in `accept_connection`, which the stock modules leave to `net_kernel`; the dial's check is `net_kernel`'s alone.

## 13. At the limit of open files the code server answers `nofile`, and the application controller "no such file or directory"

Filed 2026-11-15 as [erlang/otp#12215](https://github.com/erlang/otp/issues/12215). Found on 2026-11-08 (the log's *The Runtime at the Limit of Open Files*); Ernest loads what its runtime calls at a run's start (report §12), and the host's TLS as the host loads it, so a handshake at the limit fails (report E.18; the log's *Lean at the Limits*).

**Title:** code:ensure_loaded/1 answers {error,nofile} and application:load/1 "no such file or directory" when the process has no file descriptor left

**Describe the bug**

When the process holds as many files as the operating system lets it, `file:read_file/1` answers `{error, emfile}`, but `code:ensure_loaded/1` of a module on the code path answers `{error, nofile}`, as for a module that does not exist. The code server then lists every directory of the code path again, each listing failing with `emfile` and each logged as its own error report. `application:load/1` answers `{error, {"no such file or directory", "ssl.app"}}` where `erl_posix_msg` is loaded, and `{error, {undef, [{erl_posix_msg, message, [enoent], []} | _]}}` where it is not, so that the reason it gives is neither the right one nor its own. A caller cannot tell a missing module from a full table of descriptors, and cannot tell its own caller why the load failed.

**To Reproduce**

A shell whose limit of open files is 64, listeners opened until the limit, then a load:

```sh
(ulimit -n 64; erl -noshell -eval '
    Fill = fun F(Held) -> case gen_tcp:listen(0, []) of
                              {ok, S} -> F([S | Held]);
                              {error, Why} -> {Why, Held}
                          end end,
    {Why, Held} = Fill([]),
    Loaded = code:ensure_loaded(calendar),
    App = application:load(ssl),
    Read = file:read_file("/etc/hostname"),
    [gen_tcp:close(S) || S <- Held],
    io:format("listen: ~p~nensure_loaded: ~p~napplication:load: ~p~nread_file: ~p~n",
              [Why, Loaded, App, Read]),
    halt().')
```

It prints an error report for `calendar.beam`, one for each directory of the code path, `File operation error: emfile. Target: .../lib/ssl-11.7.8/ebin. Function: list_dir. Process: code_server.`, and one for `erl_posix_msg.beam` from the application controller, and then:

```
listen: emfile
ensure_loaded: {error,nofile}
application:load: {error,
                      {undef,
                          [{erl_posix_msg,message,[enoent],[]},
                           {application_controller,make_appl,1, ...}, ...]}}
read_file: {error,emfile}
```

**Expected behavior**

`code:ensure_loaded/1` answers `{error, emfile}`, as `file:read_file/1` does, and does not list the code path again for a read that failed for a reason other than a missing file; `application:load/1` answers the read's reason, `emfile`, without describing it as `enoent`.

**Affected versions**

OTP 29, erts 17.1.1, kernel 11.0.4, stdlib 8.1.1, on Linux x86_64.

**Additional context**

`erl_prim_loader:check_file_result/3` logs the read's reason and answers `error`, which the code server turns into `nofile`, and the application controller's `make_appl/1` describes any failed read of an `.app` file as `enoent`.

## 14. `net_kernel` spins while a connection waits at the limit of open files

Filed 2026-11-15 as [erlang/otp#12216](https://github.com/erlang/otp/issues/12216). Found on 2026-11-08 (the log's *The Runtime at the Limit of Open Files*); `inet_tls_dist`'s acceptor does the same, and a node's own acceptor waits a dial's time instead (`ern_tls_dist`; the log's *The Carrier's Acceptor at a Full Table*).

**Title:** net_kernel restarts the acceptor at once after an accept fails with emfile, and spins on a scheduler while the connection waits

**Describe the bug**

When a node holds as many files as the operating system lets it and another node connects, the acceptor's `inet_tcp:accept/1` answers `{error, emfile}`, `inet_tcp_dist:accept_loop/3` exits with it, and `net_kernel`'s `accept_exit/3` starts a new acceptor at once, which meets the same error. The connection stays in the listener's queue, so the loop runs until a descriptor is free, on a scheduler of its own: the node spends most of a processor doing nothing, and nothing says why.

**To Reproduce**

A node whose limit of open files is 64, listeners opened until the limit and held for three seconds, and a second node that pings it:

```sh
(ulimit -n 64; erl -sname spin_a -setcookie c -noshell -eval '
    Fill = fun F(Held) -> case gen_tcp:listen(0, []) of
                              {ok, S} -> F([S | Held]);
                              {error, _} -> Held
                          end end,
    Held = Fill([]),
    {_, _} = erlang:statistics(runtime),
    receive after 3000 -> ok end,
    {_, Busy} = erlang:statistics(runtime),
    [gen_tcp:close(S) || S <- Held],
    io:format("cpu over 3 s at the limit: ~p ms~n", [Busy]),
    halt().' > a.txt 2>&1) &
sleep 1
erl -sname spin_b -setcookie c -noshell -eval '
    {ok, H} = inet:gethostname(),
    io:format("ping ~p~n", [net_adm:ping(list_to_atom("spin_a@" ++ H))]),
    halt().'
wait
cat a.txt
```

The full node prints `cpu over 3 s at the limit: 1935 ms`; without the second node it prints `4 ms`. The ping answers `pong` once the listeners are closed.

**Expected behavior**

An accept that fails for want of a descriptor is retried after a wait, or once a descriptor is freed, and the failure is logged once, so that a node at its limit stays idle while the connection waits.

**Affected versions**

OTP 29, erts 17.1.1, kernel 11.0.4, on Linux x86_64.

**Additional context**

`inet_tls_dist`'s acceptor exits on the same error, and `net_kernel` restarts it the same way.

## 15. `ssl` raises a failed match, or answers `{dtls_upgrade, notsup}`, when the process table is full

Filed 2026-11-15 as [erlang/otp#12217](https://github.com/erlang/otp/issues/12217). Found on 2026-11-08 (the log's *The Carrier's Acceptor at a Full Table*), the raises on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a node's acceptor reads the handshake's answer as the full table (`ern_tls_dist`), and a program's TLS reads the raise so and answers the full table as a value (`ern_tcp`, the log's *The Shell at a Full Table*).

**Title:** ssl:connect/4, ssl:listen/2 and ssl:transport_accept/2 raise badmatch, and ssl:handshake/3 answers {error,{dtls_upgrade,notsup}}, when the process table is full

**Describe the bug**

`ssl` matches `{ok, _}` on each start of a process of its own. A connection's processes are started by `{ok, DynSup} = start_connection_tree(...)` in `tls_gen_connection:start_fsm/6,7`, and a listener's trackers by `{ok, _} = session_tickets_tracker(...)`, `session_id_tracker(...)` and `inherit_tracker(...)` in `tls_socket:listen/3`. Where the process table is full, the start answers `{error, Reason}`, `Reason` holding the refused spawn's `system_limit`, and the match fails.

`ssl:connect/4`, `ssl:listen/2` and `ssl:transport_accept/2` let `error:{badmatch, {error, Reason}}` out to their caller, which none of their specs gives. `ssl:handshake/3` given a `gen_tcp` socket catches every `error:{badmatch, _}` in `tls_socket:upgrade/4` and answers `{error, {dtls_upgrade, notsup}}`, which the caller never asked for; `ssl:connect/3` on a socket does the same. Either way the caller cannot tell a full table from another failed match but by the form of `Reason`.

**To Reproduce**

A certificate, a node whose table holds 1024 processes, a TCP connection accepted, a TLS listener with a TCP connection waiting on it, the table filled, then each call:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 1 -subj /CN=x
erl +P 1024 -noshell -eval '
    {ok, _} = application:ensure_all_started(ssl),
    [code:ensure_loaded(M) || A <- [ssl, crypto, public_key, asn1],
                              {ok, Ms} <- [application:get_key(A, modules)], M <- Ms],
    Files = [{certfile, "cert.pem"}, {keyfile, "key.pem"}],
    {ok, L} = gen_tcp:listen(0, [{active, false}]),
    {ok, Port} = inet:port(L),
    {ok, _C} = gen_tcp:connect({127, 0, 0, 1}, Port, []),
    {ok, S} = gen_tcp:accept(L),
    {ok, TL} = ssl:listen(0, Files),
    {ok, {_, TlsPort}} = ssl:sockname(TL),
    {ok, _T} = gen_tcp:connect({127, 0, 0, 1}, TlsPort, []),
    Fill = fun F(N) -> try spawn(fun() -> receive _ -> ok end end) of
                           _ -> F(N + 1)
                       catch error:system_limit -> N end end,
    Fill(0),
    Show = fun(Name, Call) ->
               Answer = try Call() catch error:Reason -> {raised, Reason} end,
               io:format("~s: ~P~n", [Name, Answer, 7])
           end,
    Show("handshake", fun() -> ssl:handshake(S, [{versions, ['\''tlsv1.3'\'']} | Files], 1000) end),
    Show("connect", fun() -> ssl:connect({127, 0, 0, 1}, Port, [{verify, verify_none}], 1000) end),
    Show("transport_accept", fun() -> ssl:transport_accept(TL, 1000) end),
    Show("listen", fun() -> ssl:listen(0, Files) end),
    halt().'
```

It prints:

```
handshake: {error,{dtls_upgrade,notsup}}
connect: {raised,{badmatch,{error,{...}}}}
transport_accept: {raised,{badmatch,{error,{...}}}}
listen: {raised,{badmatch,{error,{...}}}}
```

The modules are loaded first, since a load at the full table fails before the calls do.

**Expected behavior**

Each call answers the start's own reason, `{error, system_limit}` or the supervisor's `{error, {system_limit, _}}`, and `{dtls_upgrade, notsup}` only where a DTLS socket was given.

**Affected versions**

OTP 29, erts 17.1.1, ssl 11.7.8, on Linux x86_64.

**Additional context**

Where the connection's supervisor is started but one of its children is not, the supervisor also writes a `start_error` report for the child. Under TLS 1.2 the session tracker's start fails first and raises a `case_clause` out of `ssl:handshake/3` instead.

## 16. `ssl:format_error/1` raises `badarg` for a reason it does not name

Filed 2026-11-15 as [erlang/otp#12218](https://github.com/erlang/otp/issues/12218). Found on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a program's TLS writes such a reason as the host prints it (`ern_tcp`).

**Title:** ssl:format_error/1 raises badarg for a reason that is neither an atom nor a form it names

**Describe the bug**

`ssl:format_error/1` takes any `reason()`, which its spec gives as `term()`. A reason none of its clauses names falls to `do_format_error/1`'s last clause, which calls `inet:format_error/1`, and that takes an atom alone: `erl_posix_msg:message/1` raises `badarg` on any other term. So the function meant to describe an error raises for a tuple, where its own `unexpected_format/1`, "Unexpected error: ~p", is reached only for an atom.

**To Reproduce**

```sh
erl -noshell -eval 'io:format("~p~n", [catch ssl:format_error({a, b})]), halt().'
```

It prints `{'EXIT',{badarg,[{erlang,atom_to_binary,[{a,b}],...`.

**Expected behavior**

`"Unexpected error: {a,b}"`, as for an atom it does not name.

**Affected versions**

OTP 29, erts 17.1.1, ssl 11.7.8, on Linux x86_64.

**Additional context**

The reasons `ssl:connect/4` and its kin give a caller who catches their raise (15) are such terms.

## 17. An application started at a full process table ends the emulator, or never answers

Filed 2026-11-15 as [erlang/otp#12219](https://github.com/erlang/otp/issues/12219). Found on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a program's first request over TLS starts the host's TLS, and report E.18 states that the start may end the run or never answer (the log's *Lean at the Limits*).

**Title:** application:ensure_all_started/1 at a full process table terminates the application controller or the logger, or hangs

**Describe the bug**

Starting an application spawns its application master from the application controller, the master spawns its own loop, and `ssl`'s start adds a logger handler, whose call the logger server answers through a process it spawns. None of the three spawns is caught. So a start where the table has room for no process, or for one or two, ends differently each time:

- With no process free, the application controller's `spawn_link` of the master raises, the controller terminates, and the emulator halts: `Kernel pid terminated (application_controller) ({system_limit,...})`.
- With one free, the master is made and its spawn of its loop raises. The master dies, the controller never learns of it, and `application:ensure_all_started/1` never answers.
- With two free, the logger server's spawn in `logger_server:call_h_async/4` raises as `ssl_app:start_logger/0` adds its handler, the logger terminates, and the emulator halts: `Kernel pid terminated (logger) ({system_limit,...})`.
- With three free, the start answers `{error, {ssl, {{shutdown, {failed_to_start_child, ...}}, ...}}}`, as expected.

A full table is a condition a node recovers from once processes end; here the node is gone, or the caller waits for ever.

**To Reproduce**

```sh
for free in 0 1 2 3; do
    timeout 10 erl +P 1024 -noshell -eval '
        Room = fun() -> erlang:system_info(process_limit) - erlang:system_info(process_count) end,
        [spawn(fun() -> receive _ -> ok end end) || _ <- lists:seq(1, Room() - '$free')],
        Free = Room(),
        io:format("~p free: ~P~n", [Free, application:ensure_all_started(ssl), 6]),
        halt().'
    echo "status $?"
done
```

It prints `Kernel pid terminated (application_controller)` and `status 1`, then `status 124` from the timeout, then `Kernel pid terminated (logger)` and `status 1`, then `3 free: {error,{ssl,{{...},...}}}` and `status 0`.

**Expected behavior**

Each start answers `{error, Reason}`, `Reason` holding the refused spawn's `system_limit`, and the application controller, the logger and the caller live on.

**Affected versions**

OTP 29, erts 17.1.1, kernel 11.0.4, ssl 11.7.8, on Linux x86_64.

## 18. `beam_lib:chunks/2,3` raises, and `beam_lib:md5/1` answers `{'EXIT', _}`, for a module whose atom chunk it cannot read

Filed 2026-11-15 as [erlang/otp#12220](https://github.com/erlang/otp/issues/12220). Found on 2026-11-09 (the log's *A Compiled Module the Host Cannot Read*); Ernest reads a chunk and a digest through `ern_chunk`, which takes both answers as the error.

**Title:** beam_lib:chunks/2,3 raises badmatch, and beam_lib:md5/1 returns {'EXIT', ...}, for a malformed atom chunk

**Describe the bug**

`beam_lib:chunks/2,3` and `beam_lib:md5/1` are specified to answer `{ok, _}` or `{error, beam_lib, Reason}`. For bytes whose atom chunk does not parse, `extract_module/2` raises: an `AtU8` chunk of no bytes, a name in it that is not UTF-8, or a name longer than the chunk. `scan_beam1/2` catches the raise with `catch` and passes on only a tuple tagged `error`, so it returns the `'EXIT'` tuple as a result. `read_chunk_data/3`'s match `{ok, Module, Chunks} = scan_beam(...)` then raises `badmatch`. `read_chunk_data/2` catches throws alone, so `chunks/2` raises, and `md5/1`, which calls under `catch`, returns the `'EXIT'` tuple.

**To Reproduce**

```sh
erl -noshell -eval '
    Bad = <<"FOR1", 12:32, "BEAM", "AtU8", 0:32>>,
    io:format("~P~n", [try beam_lib:chunks(Bad, [atoms]) catch C:R -> {raised, C, R} end, 7]),
    io:format("~P~n", [beam_lib:md5(Bad), 7]),
    halt().'
```

It prints `{raised,error,{badmatch,{'EXIT',...}}}` and `{'EXIT',{{badmatch,{'EXIT',...}},[...]}}`.

**Expected behavior**

Both answer `{error, beam_lib, {invalid_chunk, File, "AtU8"}}`, a reason the spec names.

**Affected versions**

OTP 29, erts 17.1.1, stdlib 8.1.1, on Linux x86_64.

**Additional context**

A file cut short at any length is answered with an error. Of the 10,384 copies of a compiled module of 2,596 bytes with one byte set to 0, 127, 128 or 255, 19 raised, each in the atom chunk.

## 19. A load past the module, export or fun table's limit ends the emulator, and the system limits page names none of the three

Filed 2026-11-15 as [erlang/otp#12221](https://github.com/erlang/otp/issues/12221). Found on 2026-11-10 (the log's *A Load Past the Host's Limits*); Ernest's report states the end (§11.2), and the runtime says a limit's four fifths before it.

**Title:** Loading code past the module, export or fun table's limit terminates the emulator, and the system limits page names none of the three limits

**Describe the bug**

The emulator holds at most 65,536 module names, 524,288 export entries and 524,288 fun entries, and gives none back. A load that would pass one of them terminates the emulator with status 1, `no more index entries in module_code (max=65536)`, `export_staged_index (max=524288)` or `fun_staged_index (max=524288)`. `erlang:load_module/2` and `code:load_binary/3` do not answer an error.

The Efficiency Guide's *System Limits* names neither the three limits nor the termination. The atom table's limit is named there, and *Common Caveats* says the emulator terminates when it is reached, so a reader is warned of the atoms alone.

**To Reproduce**

```sh
erl +S 1 -noshell -eval '
    {ok, m0000000, Beam} = compile:forms([{attribute, 1, module, m0000000}], [binary]),
    Load = fun Load(N) ->
                   Name = iolist_to_binary(io_lib:format("m~7..0B", [N])),
                   Module = binary_to_atom(Name),
                   {module, Module} =
                       erlang:load_module(Module, binary:replace(Beam, <<"m0000000">>, Name)),
                   Load(N + 1)
           end,
    Load(1).'
echo "status $?"
```

After about two minutes it prints `no more index entries in module_code (max=65536)` and `status 1`.

**Expected behavior**

A load that would pass a table's limit answers `{error, system_limit}`, as `spawn` raises `system_limit` at the process limit. Failing that, *System Limits* names the three limits and says the emulator terminates past each, as *Common Caveats* says of the atoms.

**Affected versions**

OTP 29, erts 17.1.1, on Linux x86_64.

**Additional context**

Modules of 2,000 exported functions each, loaded one after another, end it at the export table, and modules of 2,000 funs each at the fun table, each with its own line above and status 1.

## 20. `gen_tcp:listen/2` keeps a backlog's low 16 bits

Filed 2026-11-15 as [erlang/otp#12222](https://github.com/erlang/otp/issues/12222). Found on 2026-11-10 (the log's *A Listener's Backlog*); Ernest gives the host 65535, the largest it keeps whole (E.18).

**Title:** gen_tcp:listen/2 silently takes the {backlog, N} option modulo 65536, so 65536 listens with a backlog of 0

**Describe the bug**

The `backlog` option is documented as a non-negative integer. A value past 65535 is not refused and not lowered to the system's limit: its low 16 bits are passed to `listen(2)`. On Linux, which lowers a larger backlog to `net.core.somaxconn` itself, `{backlog, 65536}` listens with a backlog of 0 and `{backlog, 65541}` with 5, where `{backlog, 65535}` listens with the system's 4096.

**To Reproduce**

```sh
erl -noshell -eval '
    [begin
         {ok, L} = gen_tcp:listen(0, [{backlog, B}, {ip, {127,0,0,1}}]),
         {ok, P} = inet:port(L),
         io:format("~p -> ~s", [B, os:cmd("ss -Hltn sport = :" ++ integer_to_list(P))]),
         gen_tcp:close(L)
     end || B <- [65535, 65536, 65541]],
    halt().'
```

It prints the listening sockets' backlogs, `ss`'s third column: 4096, 0 and 5.

**Expected behavior**

A backlog past what the option can carry is refused with `{error, einval}`, or passed whole for the system to lower, as `listen(2)` does with any larger value.

**Affected versions**

OTP 29, erts 17.1.1, on Linux x86_64.

## 21. `string:prefix/2` disagrees with `string:to_graphemes/1` on where a prefix may end

Filed 2026-11-15 as [erlang/otp#12223](https://github.com/erlang/otp/issues/12223). Found on 2026-11-10 by the release review's bench (the log's *The Release Review Before 0.10.0*); Ernest keeps `String.stripPrefix` in Ernest over its own graphemes (E.5).

**Title:** string:prefix/2 answers nomatch for a prefix that is a whole grapheme cluster, and matches a prefix that ends inside one

**Describe the bug**

`string:prefix/2` is documented as grapheme-aware: it matches the prefix against the string's grapheme clusters, as `string:to_graphemes/1` splits them. It disagrees with `to_graphemes/1` both ways. A pair of regional indicators is one cluster to `to_graphemes/1`, and `prefix/2` answers `nomatch` for a prefix that is exactly that pair. A consonant, a virama and a consonant are one cluster to `to_graphemes/1`, and `prefix/2` matches a prefix that ends after the virama, inside the cluster. Over 1,000,000 random texts and prefixes from an alphabet of combining marks, ZWJ, regional indicators, Hangul jamo and Devanagari, the two disagreed on 135.

**To Reproduce**

```sh
erl -noshell -eval '
    io:format("~p ~p~n", [string:prefix(<<"\x{1F1EA}\x{1F1EA}\x{1F1F8}"/utf8>>, <<"\x{1F1EA}\x{1F1EA}"/utf8>>),
                          string:to_graphemes(<<"\x{1F1EA}\x{1F1EA}\x{1F1F8}"/utf8>>)]),
    io:format("~p ~p~n", [string:prefix(<<"\x{915}\x{94D}\x{915}"/utf8>>, <<"\x{915}\x{94D}"/utf8>>),
                          string:to_graphemes(<<"\x{915}\x{94D}\x{915}"/utf8>>)]),
    halt().'
```

It prints `nomatch [[127466,127466],127480]`, where the prefix is the first cluster whole, and `<<224,164,149>> [[2325,2381,2325]]`, where the prefix ends inside the one cluster.

**Expected behavior**

`prefix/2` matches a prefix exactly where it is a run of the string's leading grapheme clusters as `to_graphemes/1` gives them: the first case answers `<<"\x{1F1F8}"/utf8>>`, and the second `nomatch`.

**Affected versions**

OTP 29, erts 17.1.1, on Linux x86_64.

## 22. A termination signal sent to a port's program before it runs is lost

Filed 2026-11-17 as [erlang/otp#12234](https://github.com/erlang/otp/issues/12234). Found on 2026-11-15 by the flake hunt of MVP 4.16's item 62; the log's *A Program Named Before It Runs*. `src/toolchain/cli/test/ern_cli_tests.erl`'s `signal_jobs_take_any_mode_test` says how Ernest's tests meet it.

**Title:** SIGTERM sent to a port program's os_pid right after open_port/2 returns is silently discarded

**Describe the bug**

`erl_child_setup` ignores `SIGTERM`, and the process it forks for a port's program ignores it too until its first act sets it back to the default. The forker writes the child's number to the emulator as soon as `fork()` returns, and `open_port/2` returns once the emulator has read it. So `erlang:port_info(Port, os_pid)` can answer before the child has run. A `SIGTERM` sent to that number in between is discarded, as an ignored signal is, and the program runs on with nothing pending. A supervisor or a test that stops a program it has just started waits for an end that never comes.

**To Reproduce**

```sh
erl -noshell -eval '
    process_flag(trap_exit, true),
    Kill = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", "while read n; do kill -TERM $n; echo; done"]}]),
    Round = fun() ->
        Cat = open_port({spawn_executable, "/bin/cat"}, [exit_status]),
        {os_pid, N} = erlang:port_info(Cat, os_pid),
        port_command(Kill, integer_to_list(N) ++ "\n"),
        receive {Kill, {data, _}} -> ok end,
        try port_command(Cat, "alive") catch error:badarg -> ok end,
        receive
            {Cat, {data, _}} -> port_close(Cat), lived;
            {Cat, {exit_status, 143}} -> ended;
            {'\''EXIT'\'', Cat, epipe} -> ended
        end
    end,
    Lived = length([x || _ <- lists:seq(1, 1000), Round() =:= lived]),
    io:format("~b of 1000 lived on after SIGTERM~n", [Lived]),
    halt().'
```

A shell reads each `cat`'s number, sends it `kill -TERM` and answers once `kill` has returned. The `cat` is then written to, and one that echoes ran past the signal. A `cat` the signal ended reports status 143, or ends its port with `epipe` where the write finds it gone before its status arrives (23).

On an idle machine of 24 hardware threads, 20 runs printed between 199 and 932. Pinned to one processor with `taskset -c 5`, 3 runs printed 11, 24 and 60. Beside 24 busy loops, 5 runs printed between 102 and 397. With the number taken once the `cat` has echoed, by a `port_command(Cat, "running")` and its `{data, _}` before `port_info/2`, none of 5,000 lived on idle, and none of 2,000 beside the loops.

Each `cat` that lived on held no pending signal, by `SigPnd` and `ShdPnd` in `/proc/N/status`, no longer ignored `SIGTERM`, and ended with status 143 at a second `SIGTERM`.

**Expected behavior**

A `SIGTERM` sent to the number `port_info/2` gives ends the program, however soon it is sent. The forker could keep `SIGTERM` blocked across `fork()`, as it already keeps `SIGCHLD`, and the child unblock it once it has set the default: one sent in between then stays pending, and ends the child.

**Affected versions**

OTP 29, erts 17.1.1, on Linux x86_64.

**Additional context**

The lines are the same at OTP-29.1.2 and at master (c25c17d). In `erl_child_setup.c`, `main` ignores `SIGTERM` (lines 520 to 527), forks (line 588) and writes the child's number to the port's pipe at once (line 599). The child's `start_new_child` sets the default as its first act (lines 200 to 208). In `sys_drivers.c`, `ready_input` reads the number, sets `os_pid` and acknowledges the open (lines 1296 to 1332). The forker blocks `SIGCHLD` across the fork at line 584, and the child releases it at line 359. `erl_child_setup` has ignored `SIGTERM` since #1730, which fixed #3574.

POSIX leaves it to the system whether a signal that is blocked and ignored stays pending. Linux 6.12 keeps it: a copy of the forker's pattern in C lost between 9,970 and 9,999 of each 10,000 signals without the block, and none of 30,000 with it.

Under load the window can outlast a `kill` that forks a shell. With `os:cmd("kill -TERM " ++ integer_to_list(N))` in place of the shell that reads the numbers, 2 runs beside 24 busy loops printed 3 and 13, and 3 runs on an idle machine printed 0.

## 23. A write to a port whose program has ended loses the program's exit status

Filed 2026-11-17 as [erlang/otp#12233](https://github.com/erlang/otp/issues/12233). Found on 2026-11-17 by the probe of MVP 4.16's item 69, beside 22; the log's *A Termination Lost With OTP Alone*. Nothing of Ernest's meets it, since the runtime's helper keeps its input open until the runtime closes it (the log's *The Hangup's Order*).

**Title:** A port opened with exit_status closes with epipe and never sends {exit_status, N} when a write finds its program gone

**Describe the bug**

`open_port/2`'s `exit_status` option sends `{Port, {exit_status, Status}}` when the external program exits. Where the program has exited and the port is written to before the status has arrived, the write fails with `EPIPE`, the port closes with `{'EXIT', Port, epipe}`, and the status is never sent. The documentation of `open_port/2` says that errors arising when sending to such a port are reported as `{'EXIT', Port, PosixCode}`, and nothing says that the error takes the status with it. A program that asks for the status and writes to its program cannot tell one that exited 0 from one that failed, and one that waits for the status waits for ever.

**To Reproduce**

```sh
erl -noshell -eval '
    process_flag(trap_exit, true),
    Round = fun() ->
        P = open_port({spawn_executable, "/bin/sh"},
                      [exit_status, {args, ["-c", "echo; exit 3"]}]),
        receive {P, {data, _}} -> ok end,
        try port_command(P, "x") of
            true -> receive
                        {P, {exit_status, 3}} -> status;
                        {'\''EXIT'\'', P, epipe} -> {epipe, P}
                    end
        catch error:badarg -> closed
        end
    end,
    Rounds = [Round() || _ <- lists:seq(1, 1000)],
    True = open_port({spawn_executable, "/bin/true"}, [exit_status]),
    receive {True, {exit_status, 0}} -> ok end,
    Lost = [P || {epipe, P} <- Rounds,
                 receive {P, {exit_status, _}} -> false after 0 -> true end],
    io:format("~b of 1000 never sent exit_status~n", [length(Lost)]),
    halt().'
```

Each round's `sh` writes a line and exits with status 3, and the port is written to once the line has come. A write that comes before the program has exited is taken, and the status follows. One that comes after fails with `epipe`. Once the rounds are done, a `/bin/true` port's status is awaited: it takes the same path through `erl_child_setup` behind every status of the rounds, so a status still on its way has come by then.

On a machine of 24 hardware threads, at a load average near 1.3, 10 runs printed between 190 and 511. Pinned to one processor with `taskset -c 5`, 3 runs printed 686, 753 and 741. In no run did a status come after an `epipe`. The same rounds without the write sent every status, in 4 runs of 1,000. Each program whose status was lost had been reaped by the end of its run, none left in `/proc`.

**Expected behavior**

`{Port, {exit_status, 3}}` is sent in every round. A port opened with `exit_status` whose write fails could wait for the status before it closes, as it already waits at the end of the program's output, and then close with `epipe`. Failing that, the documentation of `exit_status` says that a write's error closes the port without the status.

**Affected versions**

OTP 29, erts 17.1.1, on Linux x86_64.

**Additional context**

The lines are the same at OTP-29.1.2 and at master (c25c17d). In `sys_drivers.c`, `output` writes to the program at once, and on an error other than `EINTR` and `EAGAIN` calls `driver_failure_posix` (lines 1177 to 1185), which closes the port. `ready_output` does the same for a write it had queued (lines 1482 to 1490).

The status is reported in one place, `port_inp_failure`, at the end of the program's output (lines 1242 to 1252). There the port waits where the status has not come (line 1233), until `spawn_control` has it from `erl_child_setup` (lines 743 to 753). A write's error does not wait. `erl_child_setup` reaps the program and sends its status (lines 612 to 634), and `forker_sigchld` hands it to the port as a control (lines 1713 to 1726), which `erts_port_task_schedule` aborts once the port is gone (`erl_port_task.c`, lines 1472 and 1624 to 1639). This reading of the code was not traced.

A program ended by a signal meets the same. A `cat` named once it has echoed, so that 22 does not apply, and written to once a `kill -TERM` of it has returned, lost its status in 1,406 of the 6,375 writes that found its port open, over 10 runs of 1,000 rounds.

The tracker's other reports of a lost `exit_status`, #11278 (fixed by #11285 and #11298) and #10411, involve no write.

## 24. A TLS distribution connection given up by the tick goes down 10 s later while its socket is full

Filed 2026-11-17 as [erlang/otp#12235](https://github.com/erlang/otp/issues/12235). Found on 2026-11-17 by the diagnosis of MVP 4.16's item 98; the log's *A Connection That Cannot Drain*. Ernest's nodes meet it: §12.6 says that the loss is run once the host has closed the connection, and `docs/design/nodes.md`'s *A loss* says when the host does.

Answered on 2026-11-18 as a likely duplicate of #12212, with #12237 as its fix, and the answer acknowledged with a thumbs-up on 2026-11-22. It is half of one: the receiver stops with `{shutdown, net_tick_timeout}`, which #12237's `close_timeout/1` answers with 5000, so the alert's wait stays and only the wait for the peer's close goes. With #12237's source changes applied to ssl 11.7.8, this report's `sh repro.sh tls full 8` printed `nodedown` 5.001 s after the owner's end, and 10.002 s without them, on 2026-11-21. Replied so on the issue the same day, asking whether the distribution's close can take a timeout of 0.

**Title:** nodedown comes 10 s after net_tick_timeout on a TLS distribution connection whose socket is full

**Describe the bug**

With `-proto_dist inet_tls`, a connection whose peer has fallen silent is given up on time: its owner, the ticker, exits with `net_tick_timeout`. The node is told only when the connection's controller, its `tls_sender`, ends. Where the socket's queue is full, that is 10 s later, and `net_kernel:monitor_nodes/2`'s `nodedown` comes then.

The sender is linked to the ticker and traps exits, so the ticker's end reaches it as an `'EXIT'` message. With the socket's queue full, the sender is in `gen_tcp:send/2`, in `prim_inet:send/4`'s receive for the port's reply, and reads no other message.

The ssl receiver monitors the ticker and stops at its end. Its `terminate/3` first asks the sender for a close alert by `tls_sender:send_and_ack_alert/2`, which the sender cannot answer, and which gives up after 5 s. It then shuts the socket's write side and waits 5 s in `gen_tcp:recv/3` for the peer's close, which a silent peer never sends. Only the receiver's end closes the socket's port. The sender's send then returns, the sender reads the `'EXIT'` and stops, and `nodedown` follows.

The 10 s are the same at a `net_ticktime` of 8 and of 60. Over plain TCP with the socket as full, and over TLS with nothing queued, `nodedown` comes within 1 ms of the ticker's end. The two waits are those of #12212, reached here from the ticker's end instead of from `ssl:close/2`.

**To Reproduce**

```sh
#!/bin/sh
# Usage: sh repro.sh tls|tcp full|idle [net_ticktime]
PROTO=$1 FILL=$2 TICK=$3
D=$(mktemp -d)
cd "$D" || exit 1
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=repro \
    -keyout key.pem -out cert.pem 2>/dev/null
cat > dist.conf <<EOF
[{server, [{certfile, "$D/cert.pem"}, {keyfile, "$D/key.pem"}]},
 {client, [{verify, verify_none}]}].
EOF
cat > a.erl <<'EOF'
-module(a).
-export([main/1]).

main([Fill]) ->
    [_, Host] = string:split(atom_to_list(node()), "@"),
    B = list_to_atom("repro_b@" ++ Host),
    connect(B),
    ok = global:sync(),
    BPid = erpc:call(B, os, getpid, []),
    ok = net_kernel:monitor_nodes(true, [nodedown_reason]),
    {ok, Info} = net_kernel:node_info(B),
    monitor(process, proplists:get_value(owner, Info)),
    Ctrl = proplists:get_value(B, erlang:system_info(dist_ctrl)),
    os:cmd("kill -STOP " ++ BPid),
    T0 = erlang:monotonic_time(millisecond),
    S = fun() -> (erlang:monotonic_time(millisecond) - T0) / 1000 end,
    Fill =:= "full" andalso
        spawn(fun() -> fill({nobody, B}, binary:copy(<<0>>, 1 bsl 20)) end),
    receive {'DOWN', _, process, _, R1} ->
        io:format("~6.3f s  the connection's owner ended: ~p~n", [S(), R1]),
        io:format("          its controller: ~p~n", [info(Ctrl)])
    end,
    receive {nodedown, B, R2} ->
        io:format("~6.3f s  nodedown: ~p~n", [S(), R2])
    end,
    os:cmd("kill -KILL " ++ BPid),
    halt().

connect(B) ->
    case net_kernel:connect_node(B) of
        true -> ok;
        false -> receive after 100 -> connect(B) end
    end.

fill(To, Bin) ->
    case erlang:send(To, Bin, [noconnect]) of
        noconnect -> ok;
        _ -> fill(To, Bin)
    end.

info(Pid) when is_pid(Pid) ->
    erlang:process_info(Pid, [status, current_function]);
info(Port) ->
    erlang:port_info(Port, queue_size).
EOF
erlc a.erl || exit 1
[ "$PROTO" = tls ] && DIST="-proto_dist inet_tls -ssl_dist_optfile $D/dist.conf"
FLAGS="$DIST -setcookie repro ${TICK:+-kernel net_ticktime $TICK} -noshell"
erl -sname repro_b $FLAGS &
B=$!
erl -sname repro_a $FLAGS -run a main "$FILL"
kill -KILL $B 2>/dev/null
wait
```

The script makes a certificate and starts two nodes on one machine. Node a connects to b and lets `global` finish with it. It then stops b with `SIGSTOP`, and with `full` sends it 1 MB messages until the connection is lost. It prints when the connection's owner ends and when `nodedown` comes, in seconds after the stop, with the controller's state at the owner's end. a kills b before it halts, since a halt flushes the socket's queue, which a stopped b never takes.

On a machine of 24 hardware threads, `sh repro.sh tls full 8` printed this, the node's own "not responding" report left out:

```
 9.601 s  the connection's owner ended: net_tick_timeout
          its controller: [{status,waiting},
                           {current_function,{prim_inet,send,4}}]
19.604 s  nodedown: [{nodedown_reason,net_tick_timeout}]
```

- Three runs printed `nodedown` 10.003, 10.002 and 10.002 s after the owner's end, with the controller in `prim_inet:send/4` in each.
- With `net_ticktime` left at its default of 60, a run printed 74.621 s and 84.623 s.
- `sh repro.sh tls idle 8` printed 9.621 s for both.
- `sh repro.sh tcp full 8` printed 9.748 s and 9.749 s, the controller port holding 66,541 bytes.

A call trace in one run, of a fuller version of the script, showed the waits:

- The receiver called `tls_sender:send_and_ack_alert/2` at the owner's end, 9.565 s.
- It called `tls_gen_connection:close/4` at 14.566 s, then `gen_tcp:shutdown/2` and `gen_tcp:recv/3`.
- `recv` returned `{error,timeout}` at 19.567 s, and `nodedown` came at 19.568 s.

**Expected behavior**

`nodedown` comes at the ticker's end, as it does over plain TCP. Where the owner ended with `net_tick_timeout`, the peer has answered nothing for the tick's whole time, so neither the alert nor the peer's close can be expected. The receiver could close the socket at once. The sender's send would then return at once, and the sender would stop on the owner's reason.

**Affected versions**

OTP 29.1.2, erts 17.1.1, ssl 11.7.8, on Linux x86_64.

**Additional context**

The lines are the same at OTP-29.1.2 and at master (1d0578e). Master's line numbers are given in parentheses where they differ.

- In `inet_tls_dist.erl`, `hs_data_ssl/2` links the ticker to the sender, the connection's controller (line 120).
- In `tls_sender.erl`, an `'EXIT'` from a linked process stops the sender with `{shutdown, Reason}` (lines 522 to 535; 526 to 539). Its distribution data goes through `tls_socket:send/4` to `gen_tcp:send/2` (`tls_socket.erl`, lines 84 and 85), and so to `prim_inet:send/4`'s selective receive (`prim_inet.erl`, lines 587 to 619).
- In `ssl_gen_statem.erl`, the receiver stops at its user's `'DOWN'` under `erl_dist` (lines 900 to 903; 904 to 907). `terminate/3`'s clause for the `connection` state sends the close alert, then calls `close({close, ?DEFAULT_TIMEOUT}, ...)` (lines 1240 to 1251; 1244 to 1255).
- In `tls_gen_connection.erl`, `send_sync_alert/2` calls `tls_sender:send_and_ack_alert/2` (lines 522 to 529; 526 to 533). That is a `gen_statem:call` with `?DEFAULT_TIMEOUT`, 5000 (`tls_sender.erl`, lines 156 and 157; `ssl_internal.hrl`, line 58). `close/4` shuts the write side and calls `recv(Socket, 0, Timeout)` (lines 532 to 544; 536 to 548).
- Over plain TCP the socket's port is the controller. `erts_deliver_port_exit` takes the connection down at the owner's exit signal, before it flushes the port (`io.c`, line 3915; 3921).

#11730 also stopped a TLS distribution peer mid-send, on the 27 branch. It reported a crash of `tls_sender`, fixed in 27.3.4.19, and nothing of a delay.

## 25. A `'DOWN'` overtakes the message its process was sending to another node, where the exit's reason is an immediate term

Filed 2026-11-22 as [erlang/otp#12265](https://github.com/erlang/otp/issues/12265). Found on 2026-11-18 by the probe of MVP 4.16's item 121; the log's *A Down Follows the Send*. Nothing of Ernest's runtime meets it, since every end it gives a program's process has a tuple for its reason but a return's `normal`, and a process that returns waits in no send. Foreign code that ends an Ernest process with the host's own exit and an immediate reason meets it, and such an end is the host's (§6.9, §12.2).

**Title:** A process killed while its send to another node waits at a busy buffer has its 'DOWN' arrive before the message, when the exit reason is an immediate term

**Describe the bug**

A process whose send to another node waits at a busy distribution buffer can be ended by an exit signal before the send is done. Where the exit's reason is an immediate term, such as `kill`, `shutdown`, any other atom, a small integer, `[]` or a local pid, a process on that node that monitors it receives the `'DOWN'` before the message. Where the reason is a tuple, a big integer or a binary, it receives the message first. The message arrives in both cases.

The message and the `'DOWN'` are signals from the same process to the same process, and the message is sent first. The Reference Manual's *Processes* (`system/doc/reference_manual/ref_man_processes.md`, *Delivery of Signals*) says: "The only signal ordering guarantee given is the following: if an entity sends multiple signals to the same destination entity, the order is preserved; that is, if `A` sends a signal `S1` to `B`, and later sends signal `S2` to `B`, `S1` is guaranteed not to arrive after `S2`." The same page says that the `down` signal is "Sent by a monitored process or port that terminates".

A `gen_server:call` from another node meets it where the reply waits so. A server ended by `exit(Pid, kill)`, or by a supervisor's `shutdown` while it does not trap exits, makes the call exit with `killed` or `shutdown` though the reply was sent, and the reply is dropped. A server that traps exits ends only once its send is done, so a supervisor's `shutdown` keeps the order until its time runs out and the supervisor kills the child.

**To Reproduce**

```sh
#!/bin/sh
# Usage: sh repro.sh large|small|call REASON, where REASON is tuple or an atom
KIND=$1 WHY=$2
D=$(mktemp -d)
cd "$D" || exit 1
cat > a.erl <<'EOF'
-module(a).
-export([main/1, sink/0, caller/2, init/1, handle_call/3, handle_cast/2]).

main([Kind, Why]) ->
    [_, Host] = string:split(atom_to_list(node()), "@"),
    B = list_to_atom("repro_b@" ++ Host),
    connect(B),
    BPid = erpc:call(B, os, getpid, []),
    erlang:system_monitor(self(), [busy_dist_port]),
    Reason = case Why of "tuple" -> {shutdown, repro}; _ -> list_to_atom(Why) end,
    Big = binary:copy(<<0>>, 64 bsl 20),
    Sender = held(Kind, B, BPid, Big),
    io:format("sender at its end: ~p~n",
              [erlang:process_info(Sender, [status, current_function])]),
    Ref = monitor(process, Sender),
    exit(Sender, Reason),
    receive {'DOWN', Ref, process, Sender, _} -> ok end,
    os:cmd("kill -CONT " ++ BPid),
    receive {seen, Seen} -> io:format("on b: ~p~n", [Seen]) end,
    halt().

%% The sender, held at the busy buffer in its send to b, which is stopped.
held("large", B, BPid, Big) ->
    Sender = sender(B),
    os:cmd("kill -STOP " ++ BPid),
    Sender ! {send, {message, Big}},
    busy(Sender),
    Sender;
held("small", B, BPid, Big) ->
    Sender = sender(B),
    os:cmd("kill -STOP " ++ BPid),
    Ctrl = proplists:get_value(B, erlang:system_info(dist_ctrl)),
    {ok, [{high_watermark, High}]} = inet:getopts(Ctrl, [high_watermark]),
    Filler = spawn(fun() -> {nobody, B} ! Big end),
    full(Filler, Ctrl, High),
    Second = spawn(fun() -> {nobody, B} ! Big end),
    busy(Second),
    Sender ! {send, {message, <<"small">>}},
    receive
        {monitor, Sender, busy_dist_port, _} -> Sender;
        {sent, Sender} ->
            os:cmd("kill -CONT " ++ BPid),
            io:format("not held: the queue took it~n"),
            halt()
    end;
held("call", B, BPid, Big) ->
    {ok, Server} = gen_server:start(?MODULE, {self(), Big}, []),
    spawn(B, ?MODULE, caller, [Server, self()]),
    receive {called, Server} -> ok end,
    os:cmd("kill -STOP " ++ BPid),
    Server ! reply,
    busy(Server),
    Server.

sender(B) ->
    Sink = spawn(B, ?MODULE, sink, []),
    Main = self(),
    Sender = spawn(fun() -> receive {send, M} -> Sink ! M end,
                            Main ! {sent, self()},
                            receive after infinity -> ok end end),
    Sink ! {watch, Sender, self()},
    receive {watching, Sink} -> Sender end.

busy(Pid) ->
    receive {monitor, Pid, busy_dist_port, _} -> ok end.

%% The connection's port holds what the socket refuses, and b, stopped,
%% takes nothing, so a port past its high watermark stays busy.
full(Filler, Ctrl, High) ->
    busy(Filler),
    case erlang:port_info(Ctrl, queue_size) of
        {queue_size, N} when N >= High -> ok;
        _ -> full(Filler, Ctrl, High)
    end.

%% b may not be up yet.
connect(B) ->
    case net_kernel:connect_node(B) of
        true -> ok;
        false -> receive after 100 -> connect(B) end
    end.

%% On b: what comes from the sender, in the order it comes.
sink() ->
    receive {watch, Pid, From} -> monitor(process, Pid), From ! {watching, self()} end,
    From ! {seen, [receive {message, Bin} -> {message, byte_size(Bin)};
                           {'DOWN', _, process, _, R} -> {'DOWN', R} end
                   || _ <- [1, 2]]}.

%% On b: a call to the server on a.
caller(Server, Driver) ->
    Driver ! {seen, try gen_server:call(Server, get, infinity) of
                        Reply -> {reply, byte_size(Reply)}
                    catch exit:{R, _} -> {exit, R}
                    end}.

init(State) -> {ok, State}.
handle_call(get, _From, {Driver, Big} = State) ->
    Driver ! {called, self()},
    receive reply -> ok end,
    {reply, Big, State}.
handle_cast(_, State) -> {noreply, State}.
EOF
erlc a.erl || exit 1
FLAGS="-setcookie repro -noshell -pa $D"
erl -sname repro_b $FLAGS &
B=$!
erl -sname repro_a $FLAGS -run a main "$KIND" "$WHY"
kill -KILL $B 2>/dev/null
wait
```

The script starts two nodes on one machine. Node a connects to b, starts a sender and a process on b that monitors it, and stops b with `SIGSTOP`. It ends the sender with `exit(Sender, Reason)` once the system monitor has reported `busy_dist_port` for it, waits for its own monitor's `'DOWN'`, and runs b again with `SIGCONT`. It prints what b's process received, in the order it came.

- With `large`, the sender sends b's process 64 MB.
- With `small`, the sender sends 5 bytes, below a fragment's 64 KB. Two other processes first send 64 MB each to b. The first fills the socket until the connection's port holds its high watermark, and the second then fills the queue to its busy limit, so that the 5 bytes are not queued when the sender is held.
- With `call`, a `gen_server` on a answers a call from a process on b with 64 MB, and is ended while the reply waits. The caller's result is printed.

On a machine of 24 hardware threads, `sh repro.sh large kill` printed:

```
sender at its end: [{status,running},
                    {current_function,{erts_internal,dsend_continue_trap,1}}]
on b: [{'DOWN',killed},{message,67108864}]
```

- `large` and `small` each printed the `'DOWN'` first in 5 runs of 5 with `kill` and in 5 of 5 with `repro_stop`, an atom of the script's own. With `tuple` each printed the message first, `[{message,67108864},{'DOWN',{shutdown,repro}}]`, in 5 of 5.
- `call shutdown` printed `on b: {exit,shutdown}` and `call kill` printed `on b: {exit,killed}`, each in 3 runs of 3. `call tuple` printed `on b: {reply,67108864}` in 3 of 3.
- With `small`'s first filler alone, the 5 bytes were queued at once and arrived before the `'DOWN'` with `kill`, in 10 runs of 10. The sender was in `erlang:bif_return_trap/2` at its end.

**Expected behavior**

The `'DOWN'` arrives after the whole message, whatever the exit's reason, as it does with a tuple. The exit could tell the monitors on other nodes once it has finished the send it took over, for an immediate reason as it does for any other.

**Affected versions**

OTP 29.1.2, erts 17.1.1, on Linux x86_64.

**Additional context**

The lines are the same at OTP-29.1.2 and at master (6324707). Master's line numbers are given in parentheses.

- In `erl_process.c`, `erts_proc_exit_handle_monitor` (line 13798; 13795) runs in the exit's phase `ERTS_CONTINUE_EXIT_MONITORS` (line 14560; 14557). Where `is_immed(reason)`, it sends the `'DOWN'` of a monitor from another node at once (line 13847; 13844), through `erts_dsig_prepare` with no process, which ignores the busy state (`dist.c`, line 3274; 3296). Otherwise it puts the monitor in `dist_monitors` (line 13881; 13878).
- A process ended in a fragmented send has `F_FRAGMENTED_SEND`, and the exit takes over the send's state (lines 14522 to 14532; 14519 to 14529). The phase `ERTS_CONTINUE_EXIT_DIST_SEND` finishes the send (lines 14601 to 14637; 14598 to 14634), and only then does `ERTS_CONTINUE_EXIT_DIST_MONITORS` tell the monitors in `dist_monitors` (lines 14657 to 14671; 14654 to 14668).
- In `dist.c`, `erts_dsig_send` queues a message's fragments only while the queue holds less than the busy limit, 1 MB by default (lines 3625 to 3644; 3647 to 3666). Where fragments remain it sets `F_FRAGMENTED_SEND` and yields with them held (lines 3743 to 3750; 3765 to 3772). A message of one fragment sent while the queue holds its limit is held whole so. One sent below the limit is queued before its sender is suspended (lines 3673 to 3693; 3695 to 3715), and keeps its order.
- `erts_proc_exit_handle_link` takes the same branch on `is_immed(reason)` (line 14115; 14112), so an exit signal through a link to another node can overtake the message too. This was read and not shown.

No earlier report of this was found on the tracker.

## 26. `erlang:disconnect_node/1` holds `net_kernel`, and every connection's tick, while the connection's controller cannot take its exit

Filed 2026-11-22 as [erlang/otp#12266](https://github.com/erlang/otp/issues/12266). Found on 2026-11-19 by the reading of MVP 4.16's item 108; the log's *What a Peer's Worker Waits On*. Ernest's nodes no longer meet it: a reload that removes a peer, a frame a node cannot read and the gateway's refusal at a full table of processes end the connection by `net_kernel:async_disconnect/1`, which does not wait (§12.5, §12.6), and the code's comment at each says why.

**Title:** erlang:disconnect_node/1 blocks net_kernel, and every tick and connection with it, until the connection's controller handles its exit

**Describe the bug**

`erlang:disconnect_node/1` calls `net_kernel:disconnect/1`, a `gen_server` call with no timeout. `net_kernel` sends the connection's controller the exit signal `disconnect`, and then waits in a selective receive for the controller's `'EXIT'`, with no timeout. While it waits it handles no other message.

A controller that traps exits takes the signal as a message, and ends only once it reads it. Over TLS the controller is ssl's `tls_sender`, which traps exits. Where the peer reads nothing and the socket's queue is full, the sender waits in `prim_inet:send/4`'s receive for the port's reply, and reads no other message (#12235). The disconnect then lasts until the peer reads again.

Meanwhile:

- `net_kernel` passes no `tick` to the connections. No peer is ticked, and none is given up for its silence: not the one whose connection is being ended, so that nothing ends the wait but that peer reading again. Every other peer that hears nothing else from the node gives the node up after `net_ticktime`.
- Every call to `net_kernel` waits, `connect_node/1`, `get_net_ticktime/0`, another `disconnect_node/1` and another node's `net_adm:ping/1` among them. A new connection's setup waits in `dist_util`, which asks `net_kernel` to mark it pending.
- The caller of `erlang:disconnect_node/1` waits too.

`net_kernel:async_disconnect/1`, which `global` uses, sends the same signal and returns at once; `net_kernel` handles the `'EXIT'` when it comes. Its documentation is hidden.

**To Reproduce**

```sh
#!/bin/sh
# Usage: sh repro.sh sync|async [net_ticktime]
MODE=$1 TICK=${2:-8}
D=$(mktemp -d)
cd "$D" || exit 1
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=repro \
    -keyout key.pem -out cert.pem 2>/dev/null
cat > dist.conf <<EOF
[{server, [{certfile, "$D/cert.pem"}, {keyfile, "$D/key.pem"}]},
 {client, [{verify, verify_none}]}].
EOF
cat > a.erl <<'EOF'
-module(a).
-export([main/1, c/0]).

main([Mode, Tick]) ->
    [_, Host] = string:split(atom_to_list(node()), "@"),
    [B, C] = [list_to_atom(Name ++ "@" ++ Host) || Name <- ["repro_b", "repro_c"]],
    connect(B),
    connect(C),
    BPid = erpc:call(B, os, getpid, []),
    Ctrl = proplists:get_value(B, erlang:system_info(dist_ctrl)),
    os:cmd("kill -STOP " ++ BPid),
    spawn(fun() -> fill({nobody, B}, binary:copy(<<0>>, 1 bsl 20)) end),
    sending(Ctrl),
    Wait = 3 * list_to_integer(Tick) * 1000,
    T0 = erlang:monotonic_time(millisecond),
    S = fun() -> (erlang:monotonic_time(millisecond) - T0) / 1000 end,
    {repro_c, C} ! {t0, self(), erlang:system_time(millisecond)},
    Self = self(),
    Disconnecting = spawn(fun() ->
                              R = case Mode of
                                      "sync" -> erlang:disconnect_node(B);
                                      "async" -> net_kernel:async_disconnect(B)
                                  end,
                              Self ! {disconnected, R}
                          end),
    io:format("~6.3f s  ~s disconnect of b sent; b's controller: ~p~n",
              [S(), Mode, erlang:process_info(Ctrl, [status, current_function])]),
    Asking = spawn(fun() -> Self ! {ticktime, net_kernel:get_net_ticktime()} end),
    receive
        {disconnected, R1} -> io:format("~6.3f s  the disconnect returned ~p~n", [S(), R1])
    after 1000 -> ok
    end,
    receive
        {ticktime, T1} -> io:format("~6.3f s  get_net_ticktime/0 returned ~p~n", [S(), T1])
    after 1000 -> ok
    end,
    receive after Wait -> ok end,
    io:format("~6.3f s  connected: ~p~n", [S(), nodes(connected)]),
    io:format("          net_kernel: ~p~n", [info(whereis(net_kernel))]),
    io:format("          the disconnect's caller: ~p~n", [info(Disconnecting)]),
    io:format("          get_net_ticktime/0's caller: ~p~n", [info(Asking)]),
    os:cmd("kill -CONT " ++ BPid),
    io:format("~6.3f s  b continued~n", [S()]),
    receive
        {disconnected, R2} -> io:format("~6.3f s  the disconnect returned ~p~n", [S(), R2])
    after 5000 -> ok
    end,
    os:cmd("kill -KILL " ++ BPid),
    halt().

%% Run on c: when a's connection goes down, in seconds after a's disconnect.
c() ->
    register(repro_c, self()),
    ok = net_kernel:monitor_nodes(true, [nodedown_reason]),
    receive {t0, A, T0} ->
        receive {nodedown, Node, Why} when Node =:= node(A) ->
            io:format("~6.3f s  on c, nodedown of a: ~p~n",
                      [(erlang:system_time(millisecond) - T0) / 1000, Why])
        end
    end,
    receive after infinity -> ok end.

connect(Node) ->
    case net_kernel:connect_node(Node) of
        true -> ok;
        false -> receive after 100 -> connect(Node) end
    end.

fill(To, Bin) ->
    case erlang:send(To, Bin, [noconnect]) of
        noconnect -> ok;
        _ -> fill(To, Bin)
    end.

%% Until the controller waits in its send to the socket, whose queue is full.
sending(Ctrl) ->
    case info(Ctrl) of
        [{status, waiting}, {current_function, {prim_inet, send, 4}}, _] -> ok;
        _ -> receive after 10 -> sending(Ctrl) end
    end.

info(Pid) ->
    erlang:process_info(Pid, [status, current_function, messages]).
EOF
erlc a.erl || exit 1
FLAGS="-proto_dist inet_tls -ssl_dist_optfile $D/dist.conf -setcookie repro -connect_all false
       -kernel net_ticktime $TICK -noshell"
erl -sname repro_b $FLAGS &
B=$!
erl -sname repro_c $FLAGS -s a c &
C=$!
erl -sname repro_a $FLAGS -run a main "$MODE" "$TICK"
kill -KILL $B $C 2>/dev/null
wait
```

The script makes a certificate and starts three nodes on one machine, with `net_ticktime` 8 and `global`'s mesh off. Node a connects to b and c. It stops b with `SIGSTOP`, sends it 1 MB messages until b's controller waits in its send, and then ends b's connection with `erlang:disconnect_node/1`, or with `net_kernel:async_disconnect/1` given `async`. It asks `net_kernel:get_net_ticktime/0` once. Three ticktimes later it prints the nodes it is connected to and the state of `net_kernel` and of the two callers, continues b, and prints when the disconnect returns. Node c prints when its connection to a goes down. Times are in seconds after the disconnect.

On a machine of 24 hardware threads, `sh repro.sh sync` printed this, c's own "not responding" report left out:

```
 0.000 s  sync disconnect of b sent; b's controller: [{status,waiting},
                                                      {current_function,
                                                       {prim_inet,send,4}}]
 9.671 s  on c, nodedown of a: [{nodedown_reason,net_tick_timeout}]
26.006 s  connected: [repro_b@nike]
          net_kernel: [{status,waiting},
                       {current_function,{net_kernel,disconnect_ctrlr,3}},
                       {messages,
                           [{'$gen_call',
                                {<0.118.0>,#Ref<0.769519162.3919052808.11084>},
                                ticktime},
                            tick,tick,tick,tick,tick,
                            {'EXIT',<0.114.0>,shutdown},
                            {'EXIT',<0.111.0>,shutdown},
                            tick,tick,tick,tick,tick,tick,tick,tick]}]
          the disconnect's caller: [{status,waiting},
                                    {current_function,{gen,do_call,4}},
                                    {messages,[]}]
          get_net_ticktime/0's caller: [{status,waiting},
                                        {current_function,{gen,do_call,4}},
                                        {messages,[]}]
26.009 s  b continued
26.016 s  the disconnect returned true
```

- Three runs of `sync` printed c's `nodedown` of a at 9.671, 9.694 and 9.661 s, a sound connection given up for the ticks a held back, and the disconnect returned 7, 2 and 4 ms after b continued, 26 s after it was sent. `get_net_ticktime/0` returned in none of them while b was stopped.
- Three runs of `async` printed the disconnect returning at 0.003, 0.004 and 0.004 s and `get_net_ticktime/0` returning 8 at the same moment. By 24 s a was connected to c alone, the tick having given b up, and c's connection to a went down only at a's halt, with `shutdown`.
- That a dial and another node's ping wait too was read, and not shown here.

**Expected behavior**

`erlang:disconnect_node/1` does not hold `net_kernel` while the controller has not ended: `net_kernel` handles the controller's `'EXIT'` when it comes, as it does for `async_disconnect/1`, and replies to the caller then, or the caller waits outside `net_kernel`. A connection that cannot take its exit then holds no other, and the tick gives it up as it gives up any silent peer.

**Affected versions**

OTP 29.1.2, erts 17.1.1, kernel 11.0.4, ssl 11.7.8, on Linux x86_64.

**Additional context**

The lines are the same at OTP-29.1.2 and at master (c81e92f). Master's line numbers are given in parentheses.

- In `erlang.erl`, `disconnect_node/1` calls `net_kernel:disconnect/1` (line 11658; 11879).
- In `net_kernel.erl`, `disconnect/1` is `request({disconnect, Node})` (line 696; 697), a `gen_server:call` with `infinity` (line 745; 746). `handle_call({disconnect, Node}, ...)` calls `do_disconnect(Node, State, false)` (lines 1186 to 1189; 1187 to 1190). `disconnect_ctrlr/3` sends `exit(Ctrlr, disconnect)` and, where it is not asked to be asynchronous, receives `{'EXIT', Ctrlr, Reason}` with no `after` (lines 2135 to 2147; 2136 to 2148).
- `handle_info(tick, State)` sends `{self(), tick}` to each connection's owner (lines 1638 to 1644; 1639 to 1645), whose loop in `dist_util.erl` checks the peer's silence and ticks it at that message (line 651; 653).
- `async_disconnect/1` casts `{async_disconnect, Node}` (lines 699 and 700; 700 and 701), which calls `do_disconnect(Node, State, true)` (lines 1355 to 1358; 1356 to 1359). `global.erl` calls it (lines 1115, 1521 and 1568; 1117, 1523 and 1570).

#5708 met the same wait from another side: a `tls_sender` that ignored the exit while its handshake was not done held `net_kernel` until the connection closed. Its fix, #5711, has the sender assert the distribution's mode by another reference, and leaves `net_kernel`'s wait without a limit. #4931 met another of `net_kernel`'s waits for an `'EXIT'` with no limit, at an `accept_pending` whose old owner had ended already; its fix, #4934, skips that wait for an owner `net_kernel` no longer holds.

## 27. The destructive update pass appends in place to a literal binary

Filed 2026-11-22 as [erlang/otp#12267](https://github.com/erlang/otp/issues/12267). Found on 2026-11-20 by `make test-typed`; the log's *A Literal Binary Grown in Place*. Ernest no longer meets it: the emitter compiles every module with `no_ssa_opt_destructive_update`, and the code's comment at `ern_compile:compiled/2` says why.

**Title:** Segfault: an append rewritten to `private_append` on a literal `<<>>` taken from a literal tuple

**Describe the bug**

The destructive update pass rewrites a `bs_create_bin` `append` to `private_append` when its first fragment is a unique, appendable variable that dies with the instruction. It then tracks that variable back to where it was made, to replace a literal there by a writable binary. Where the variable is `get_tuple_element` of a literal tuple, the tracking stops without patching anything, and the append stays rewritten. The emulator then runs `private_append` on the literal `<<>>`, reads it as a sub-binary of a writable binary, and ends with a segmentation fault.

**To Reproduce**

`t.erl`:

```erlang
-module(t).
-export([f/1]).

f(B) ->
    <<(element(1, case B of true -> {<<>>} end))/binary>>.
```

```
$ erlc t.erl && erl -noshell -eval 'io:format("~p~n", [t:f(true)]), halt().'
Segmentation fault
$ erlc +no_ssa_opt_destructive_update t.erl && erl -noshell -eval 'io:format("~p~n", [t:f(true)]), halt().'
<<>>
```

`erlc -S t.erl` shows the literal given to `private_append`:

```
{bs_create_bin,{f,0},0,0,256,{x,0},
               {list,[{atom,private_append},1,8,nil,{literal,<<>>},{atom,all}]}}.
```

The `case` is needed: without it `sys_core_fold` turns the fragment into the literal `<<>>` itself, which the pass replaces by a `bs_init_writable`, and the module runs. The binary must be empty: `{<<"a">>}` compiles to `append`, since only an empty binary's type is appendable. A second segment is not needed, and with one the module still faults.

**Expected behavior**

`t:f(true)` returns `<<>>`.

**Affected versions**

OTP 29.1.2, erts 17.1.1, compiler 10.0.7, on Linux x86_64. The clauses named below are the same in OTP 27.3.4.19 and 28.5.0.8, and on `maint` and `master`, which were read and not run.

**Additional context**

In `beam_ssa_destructive_update.erl`, `fai_i/4` accepts the append: its first fragment, `_3 = get_tuple_element {<<>>}, 0`, is unique and dies with it, and its type is appendable. `fiv_track_value_in_fun/6` then follows `_3`, but its `get_tuple_element` clause matches a variable tuple only, `[#b_var{}=Tuple,#b_literal{val=Idx}]`. The literal tuple falls to the catch-all clause, whose comment holds such a path unreachable for an appendable bitstring, so no literal is patched, and `patch_is/5` rewrites the append all the same.

In the emulator, `erts_bs_private_append_checked` (`erl_bits.c`) checks that its binary is a sub-binary of a writable one by `ASSERT` alone, and reads the `BinRef` from the words that follow the literal. What ends the emulator therefore depends on those words: a larger module with the same instruction ended with `binary_alloc: Cannot allocate 21050432664586 bytes of memory (of type "binary")` instead.

The same shape through a list's head makes the compiler fail instead, since the `get_hd` clause matches the literal list and finds no type annotation:

```erlang
f(B) -> <<(hd(case B of true -> [<<>>] end))/binary>>.
```

```
Sub pass ssa_opt_destructive_update
t.erl: internal error in pass beam_ssa_opt:
exception error: no match of right hand side value #{location => {"t.erl",4},arg_types => #{}}
  in function  beam_ssa_destructive_update:fiv_track_value_in_fun/6 (beam_ssa_destructive_update.erl:390)
```

#6851 met the same rewrite by another path, a fragment that could be other than a bitstring, and its fix has the pass rewrite only a fragment typed as a bitstring alone, which an empty literal is. #12249, open, is another fault of the pass at a literal tuple, which the compiler meets in `patch_literal_tuple/6` for a tuple a function returns; the module here compiles, and faults when it runs.

Found by a generator of random well-typed programs in a compiler that emits Erlang, where a field selected from a record that a conditional builds became `element/2` of a `case` the compiler reduced to one literal tuple.
