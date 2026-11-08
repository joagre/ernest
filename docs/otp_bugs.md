# Defects found in OTP

The defects of OTP that building Ernest has found, each written as a report for OTP's tracker, [github.com/erlang/otp/issues](https://github.com/erlang/otp/issues), ready to file, and reproduced with OTP alone. Filing is the user's. A report stays here until OTP has fixed its defect in a release Ernest requires. Where a defect still shows in Ernest, the code's comment at the place says how, and the decisions log why Ernest meets it as it does.

## 1. `erl_child_setup` prints a line when the emulator ends while a port starts

Not filed. Found on 2026-10-01; the log's *A Port Lost While It Starts*.

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

## 5. `memsup` closes its port while a collection is under way

Not filed. Found on 2026-10-09; `src/nodes/test/ern_node_tests.erl`'s `collected/0` says how Ernest meets it.

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

Not filed. Found on 2026-10-26; the log's *The Build's Cost per Function*.

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

Not filed. Found on 2026-10-26, measured on 2026-10-30; the log's *The Build's Cost per Function* and *One Function per Initializer*.

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

Not filed, and a misfeature rather than a bug: nothing in OTP's documentation promises otherwise, and a fixed process table is the emulator's design. Found on 2026-10-30; the log's *A Line-Mode Input's Cost*.

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

Not filed. Found on 2026-11-01, building TLS in `Tcp` (the log's *TLS in `Tcp` and a Terminal in `Os`*); `src/runtime/ern_tcp.erl`'s `file_error/2` reads the file and the reason from the term instead (the log's *Two Lines on TLS*).

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

Not filed. Found on 2026-11-01, building TLS in `Tcp` (the log's *TLS in `Tcp` and a Terminal in `Os`*, *The TLS linger bound*), and measured on 2026-11-02; `src/runtime/ern_tcp.erl`'s `close_socket/3` hands a socket over TLS to its closer, and Appendix E.18 states the host's bound, up to 10 seconds past the one it states for a plain socket.

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

Not filed. Found on 2026-11-02 by the release review before 0.9.0 (its finding E4-2); `src/libs/json/ern_json.erl`'s `broken_literal/2` reads the text for the byte that differs instead.

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

Not filed. Found on 2026-11-08 (the log's *A Node's Own Processes at a Full Table*), the dial on the same day (the log's *The Carrier's Acceptor at a Full Table*); a node's own acceptor over `inet_tls_dist` closes a connection it cannot serve (`ern_tls_dist`), and plan item 32 takes the dial, which no distribution module reaches.

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

Not filed. Found on 2026-11-08 (the log's *The Runtime at the Limit of Open Files*); Ernest loads what its runtime calls at a run's start (report §12), and the host's TLS whole at its first use, which meets this where the limit has been reached first.

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

Not filed. Found on 2026-11-08 (the log's *The Runtime at the Limit of Open Files*); `inet_tls_dist`'s acceptor does the same, and a node's own acceptor waits a dial's time instead (`ern_tls_dist`; the log's *The Carrier's Acceptor at a Full Table*).

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

Not filed. Found on 2026-11-08 (the log's *The Carrier's Acceptor at a Full Table*), the raises on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a node's acceptor reads the handshake's answer as the full table (`ern_tls_dist`), and a program's TLS reads the raise so (`ern_tcp`).

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

Not filed. Found on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a program's TLS writes such a reason as the host prints it (`ern_tcp`).

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

Not filed. Found on 2026-11-09 (the log's *A Program's TLS at a Full Table*); a program's first request over TLS starts the host's TLS, and plan item 35 takes it.

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
