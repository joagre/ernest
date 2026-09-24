%% Plan 3.2: the MVP 1 programs compiled with bin/ernc and run with bin/ern
%% as a user would, output compared as a multiset of lines with
%% expected/<name>.out, since prints from different processes interleave
%% by scheduling. Run from this directory by its Makefile.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PROGRAMS, ["hello", "counter", "upgrade", "pingpong", "stack", "patterns",
                   "kvparser", "remote"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (pingpong),
%% §6.6 (counter), §6.7 (remote), §6.10 (upgrade), §5.10 (patterns),
%% §5.5 (kvparser), §4.4 (stack)
%% Each program is compiled and run apart from the others, so they run in
%% parallel (plan, MVP 2.6 checkpoint 4, step 3).
programs_test_() ->
    {inparallel, [{Name, {timeout, 60, fun() -> program(Name) end}} || Name <- ?PROGRAMS]}.

program(Name) ->
    {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/" ++ Name
                ++ ".ern"),
    {0, Out} = sh("../bin/ern build/" ++ Name ++ ".erc"),
    ?assertEqual(expected(Name), lines(Out)).

%% Plan, MVP 2.5 step 4: the paper programs that the doors of step 4 opened.
%% snake waits for a terminal, so it is only compiled here and ern_terminal_tests
%% plays it under a pseudo-terminal; echo is run by hand; the others run below.
-define(COMPILES, ["filesync", "repl", "snake", "echo", "webserver"]).

compiles_test_() ->
    {inparallel, [{Name, fun() ->
                {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/"
                            ++ Name ++ ".ern"),
                ?assert(filelib:is_regular("build/" ++ Name ++ ".erc"))
            end} || Name <- ?COMPILES]}.

%% Paper program 4 (plan, MVP 2.5 step 4): the REPL reads stdin and ends at
%% end of input, so its run is bounded by its input. The last two lines are
%% the point of the program: an expression that does not terminate is killed
%% after two seconds, and the next expression still works.
%% report §6.9 (monitor), §8.2 (Sys.stdin), §9.3 (Io.readLine)
repl_test_() ->
    {timeout, 60, fun repl/0}.

repl() ->
    {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/repl.ern"),
    {0, Out} = sh("../bin/ern build/repl.erc < input/repl.in"),
    ?assertEqual(expected("repl"), lines(Out)).

%% Paper program 2 (plan, MVP 2.5 step 4): the syncer runs until it is
%% stopped, so the harness gives it two prepared directories, lets it run,
%% stops it, and reads the directories back. One file on each side crosses,
%% and the pair that differs leaves a conflict beside the newer copy.
%% report §8.2 (Sys.fs), §6.6 (Address.call), Appendix E.17 (Fs.list)
filesync_test_() ->
    {timeout, 60, fun filesync/0}.

filesync() ->
    {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/filesync.ern"),
    Dir = "build/filesync",
    ok = reset(Dir),
    ok = file:write_file(Dir ++ "/a/greeting.txt", <<"hello from a\n">>),
    ok = file:write_file(Dir ++ "/b/other.txt", <<"only in b\n">>),
    ok = file:write_file(Dir ++ "/a/notes.txt", <<"old note\n">>),
    ok = file:write_file(Dir ++ "/b/notes.txt", <<"new note\n">>),
    Older = calendar:gregorian_seconds_to_datetime(
              calendar:datetime_to_gregorian_seconds(calendar:local_time()) - 7200),
    ok = file:change_time(Dir ++ "/a/notes.txt", Older),
    Out = run_for(Dir, "../../../bin/ern ../../build/filesync.erc", 4),
    %% report §8.6: the signal ends the program as returning from main does,
    %% so what was written is there and the runtime says nothing of its own
    ?assert(lists:member(<<"conflict: notes.txt">>, Out)),
    ?assertEqual([], [L || L <- Out, binary:match(L, <<"conflict: notes.txt">>) =:= nomatch]),
    ?assertEqual({ok, <<"hello from a\n">>}, file:read_file(Dir ++ "/b/greeting.txt")),
    ?assertEqual({ok, <<"only in b\n">>}, file:read_file(Dir ++ "/a/other.txt")),
    %% b's copy is the newer one, so a takes it and b keeps its own beside the conflict
    ?assertEqual({ok, <<"new note\n">>}, file:read_file(Dir ++ "/a/notes.txt")),
    ?assert(filelib:is_regular(Dir ++ "/b/notes.txt.conflict")).

reset(Dir) ->
    ok = del(Dir),
    ok = filelib:ensure_path(Dir ++ "/a"),
    ok = filelib:ensure_path(Dir ++ "/b").

del(Dir) ->
    case file:del_dir_r(Dir) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% A program that runs until it is stopped: started in Dir, stopped after
%% Seconds with the host's termination signal. Its output is returned whole.
run_for(Dir, Cmd, Seconds) ->
    %% sh -c, since open_port runs the command with exec and `cd` is a builtin
    {_, Out} = sh("sh -c 'cd " ++ Dir ++ " && { " ++ Cmd ++ " & p=$!; sleep "
                  ++ integer_to_list(Seconds) ++ "; kill $p 2>/dev/null; wait $p 2>/dev/null; }'"),
    lines(Out).

%% Paper program 1 (plan, MVP 2.5 step 4): the server serves until it is
%% stopped, so the harness starts it, makes two requests over one session,
%% and stops it. The second request carries the cookie the first set, and
%% the visit count proves the session store kept it between connections.
%% report §8.2 (Sys.tcp), Appendix E.18 (Tcp), §6.6 (the store's request-reply)
webserver_test_() ->
    {timeout, 60, fun webserver/0}.

webserver() ->
    {0, _} = sh("../bin/ernc --source-root ../examples --out-dir build ../examples/webserver.ern"),
    Port = open_port({spawn, "../bin/ern build/webserver.erc"},
                     [exit_status, stderr_to_stdout, binary]),
    {os_pid, Pid} = erlang:port_info(Port, os_pid),
    try
        ?assertEqual(ok, listening(8080, 100)),
        First = request([]),
        ?assertMatch({_, _}, binary:match(First, <<"HTTP/1.1 200 OK">>)),
        ?assertMatch({_, _}, binary:match(First, <<"set-cookie: sid=">>)),
        ?assertMatch({_, _}, binary:match(First, <<"Visit number 1">>)),
        Sid = cookie_of(First),
        Second = request([<<"cookie: sid=", Sid/binary, "\r\n">>]),
        ?assertMatch({_, _}, binary:match(Second, <<"Visit number 2">>))
    after
        os:cmd("kill " ++ integer_to_list(Pid)),
        try port_close(Port) catch _:_ -> true end
    end.

%% The server needs a moment to bind; a connection that is refused is retried.
listening(_, 0) ->
    {error, not_listening};
listening(TcpPort, Tries) ->
    case gen_tcp:connect("127.0.0.1", TcpPort, [binary, {active, false}], 100) of
        {ok, Sock} -> gen_tcp:close(Sock), ok;
        {error, _} -> timer:sleep(100), listening(TcpPort, Tries - 1)
    end.

request(Headers) ->
    {ok, Sock} = gen_tcp:connect("127.0.0.1", 8080, [binary, {active, false}], 1000),
    ok = gen_tcp:send(Sock, [<<"GET / HTTP/1.1\r\nhost: localhost\r\n">>, Headers, <<"\r\n">>]),
    Answer = recv_all(Sock, []),
    gen_tcp:close(Sock),
    Answer.

recv_all(Sock, Acc) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Bin} -> recv_all(Sock, [Bin | Acc]);
        {error, _} -> iolist_to_binary(lists:reverse(Acc))
    end.

cookie_of(Answer) ->
    [_, After] = binary:split(Answer, <<"set-cookie: sid=">>),
    [Sid | _] = binary:split(After, <<";">>),
    Sid.

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test() ->
    {0, _} = sh("../bin/ernc --out-dir build/modules ../examples/modules"),
    {0, Out} = sh("../bin/ern build/modules/main.erc"),
    ?assertEqual(expected("modules"), lines(Out)).

expected(Name) ->
    {ok, Bin} = file:read_file("expected/" ++ Name ++ ".out"),
    lines(Bin).

lines(Bin) ->
    lists:sort(binary:split(Bin, <<"\n">>, [global, trim])).

sh(Cmd) ->
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
