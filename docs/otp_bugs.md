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

Not filed. Found on 2026-10-09; `erl/cli/test/ern_node_tests.erl`'s `collected/0` says how Ernest meets it.

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

Not filed. Found on 2026-11-01, building TLS in `Tcp` (the log's *TLS in `Tcp` and a Terminal in `Os`*); `erl/runtime/src/ern_tcp.erl`'s `file_error/2` reads the file and the reason from the term instead (the log's *Two Lines on TLS*).

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
