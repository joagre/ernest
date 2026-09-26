%% Plan, MVP 1: the programs compiled with bin/ern build and run with bin/ern
%% as a user would, output compared as a multiset of lines with
%% expected/<name>.out, since prints from different processes interleave
%% by scheduling. Run from this directory by its Makefile.
-module(ern_integration_tests).

-include_lib("eunit/include/eunit.hrl").

%% Report §11.1: an example compiled into test/build.
-define(BUILD, "../bin/ern build --source-root ../examples --build-root build ").

-define(PROGRAMS, ["hello", "counter", "upgrade", "pingpong", "stack", "patterns",
                   "kvparser", "remote"]).

%% report §8.1, §8.6, §11.1, §11.2, and per program: §6.4 (pingpong),
%% §6.6 (counter), §6.7 (remote), §6.10 (upgrade), §5.10 (patterns),
%% §5.5 (kvparser), §4.4 (stack)
%% Each program is compiled and run apart from the others, so they run in
%% parallel (plan, MVP 2.6).
programs_test_() ->
    {inparallel, [{Name, {timeout, 60, fun() -> program(Name) end}} || Name <- ?PROGRAMS]}.

program(Name) ->
    {0, _} = sh(?BUILD ++ "../examples/" ++ Name
                ++ ".ern"),
    {0, Out} = sh("../bin/ern run build/" ++ Name ++ ".erc"),
    ?assertEqual(expected(Name), lines(Out)).

%% Plan, MVP 2.5: the paper programs that the doors of step 4 opened.
%% snake waits for a terminal, so it is only compiled here and ern_terminal_tests
%% plays it under a pseudo-terminal; echo is run by hand; the others run below.
-define(COMPILES, ["filesync", "repl", "snake", "echo", "webserver"]).

compiles_test_() ->
    {inparallel, [{Name, fun() ->
                {0, _} = sh(?BUILD ++ "../examples/"
                            ++ Name ++ ".ern"),
                ?assert(filelib:is_regular("build/" ++ Name ++ ".erc"))
            end} || Name <- ?COMPILES]}.

%% Paper program 4 (plan, MVP 2.5): the REPL reads stdin and ends at
%% end of input, so its run is bounded by its input. The last two lines are
%% the point of the program: an expression that does not terminate is killed
%% after two seconds, and the next expression still works.
%% report §6.9 (monitor), §8.2 (Io's stdin), §9.3 (Io.readLine)
repl_test_() ->
    {timeout, 60, fun repl/0}.

repl() ->
    {0, _} = sh(?BUILD ++ "../examples/repl.ern"),
    {0, Out} = sh("../bin/ern run build/repl.erc < input/repl.in"),
    ?assertEqual(expected("repl"), lines(Out)).

%% Paper program 2 (plan, MVP 2.5): the syncer runs until it is
%% stopped, so the harness gives it two prepared directories, lets it run,
%% stops it, and reads the directories back. One file on each side crosses,
%% and the pair that differs leaves a conflict beside the newer copy.
%% report §8.2 (Fs's reference), §6.6 (Address.call), Appendix E.17 (Fs.list)
filesync_test_() ->
    {timeout, 60, fun filesync/0}.

filesync() ->
    {0, _} = sh(?BUILD ++ "../examples/filesync.ern"),
    Dir = "build/filesync",
    ok = reset(Dir),
    ok = file:write_file(Dir ++ "/a/greeting.txt", <<"hello from a\n">>),
    ok = file:write_file(Dir ++ "/b/other.txt", <<"only in b\n">>),
    ok = file:write_file(Dir ++ "/a/notes.txt", <<"old note\n">>),
    ok = file:write_file(Dir ++ "/b/notes.txt", <<"new note\n">>),
    Older = calendar:gregorian_seconds_to_datetime(
              calendar:datetime_to_gregorian_seconds(calendar:local_time()) - 7200),
    ok = file:change_time(Dir ++ "/a/notes.txt", Older),
    {Status, Out} = run_for(Dir, "../../../bin/ern run ../../build/filesync.erc", 4, "TERM"),
    %% report §8.6, §11.2: the signal ends the program as returning from main
    %% does, so what was written is there and the runtime says nothing of its
    %% own, and the status is 128 plus the signal's number
    ?assertEqual(143, Status),
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
%% Seconds with the signal named. Its status and its output are returned,
%% standard error with standard output.
run_for(Dir, Cmd, Seconds, Signal) ->
    %% sh -c, since open_port runs the command with exec and `cd` is a builtin
    {_, Out} = sh("sh -c 'cd " ++ Dir ++ " && { " ++ Cmd ++ " & p=$!; sleep "
                  ++ integer_to_list(Seconds) ++ "; kill -" ++ Signal
                  ++ " $p 2>/dev/null; wait $p; echo status $?; }'"),
    [<<"status ", S/binary>> | Rest] = lists:reverse(lines(Out)),
    {binary_to_integer(S), lists:reverse(Rest)}.

%% report §8.6, §11.2: the host's hangup ends a program as its termination
%% does, printing nothing, with status 128 plus the signal's number. A
%% regression test: the hangup was ignored, and the program ran on.
hangup_test_() ->
    {timeout, 60, fun hangup/0}.

hangup() ->
    Dir = "build/hangup",
    ok = filelib:ensure_path(Dir),
    ok = file:write_file(Dir ++ "/waits.ern",
                         "export fn main() -> Unit with Never =\n"
                         "    receive { after 60000 -> Io.println(\"late\") }\n"),
    {0, _} = sh("../bin/ern build --source-root " ++ Dir ++ " " ++ Dir ++ "/waits.ern"),
    ?assertEqual({129, []}, run_for(Dir, "../../../bin/ern run waits.erc", 2, "HUP")).

%% Paper program 1 (plan, MVP 2.5): the server serves until it is
%% stopped, so the harness starts it, makes two requests over one session,
%% and stops it. The second request carries the cookie the first set, and
%% the visit count proves the session store kept it between connections.
%% report §8.2 (Tcp's reference), Appendix E.18 (Tcp), §6.6 (the store's request-reply)
webserver_test_() ->
    {timeout, 60, fun webserver/0}.

webserver() ->
    {0, _} = sh(?BUILD ++ "../examples/webserver.ern"),
    Port = open_port({spawn, "../bin/ern run build/webserver.erc"},
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

%% report §9.3, plan MVP 3.2: every library's own tests, run by `ern test`
%% over its compiled modules, as the shell's are
libs_test_() ->
    {timeout, 60, fun libs/0}.

libs() ->
    Modules = filelib:wildcard("../build/libs/*/**/*.erc"),
    ?assert(lists:any(fun(M) -> filename:basename(M) =:= "markdown.erc" end, Modules)),
    Runs = ["../bin/ern test " ++ M || M <- Modules],
    {Status, Out} = sh(lists:flatten(lists:join(" && ", Runs))),
    Lines = [L || L <- binary:split(Out, <<"\n">>, [global]), L =/= <<>>],
    ?assertEqual([], [L || L <- Lines, binary:match(L, <<": passed">>) =:= nomatch]),
    ?assertEqual(0, Status).

%% report §8.2, §7.4, Appendix E.1: standard input is UTF-8 whatever the
%% host's locale, a line without its line feed or the carriage return
%% before it, a last line without a line feed; a line that is not UTF-8
%% faults; lines and bytes are one stream, and bytes go out as they are
stdin_test_() ->
    {timeout, 60, fun stdin/0}.

stdin() ->
    [{0, _} = sh("../bin/ern build --source-root stdin --build-root build/stdin stdin/"
                 ++ P ++ ".ern") || P <- ["lines", "stream", "chunks"]],
    Run = fun(Input, Program) ->
                  sh("printf '" ++ Input ++ "' | LANG=C ../bin/ern run build/stdin/"
                     ++ Program ++ ".erc")
          end,
    ?assertEqual({0, <<"[h", 16#e9/utf8, "] 2\n[zw", 16#4e2d/utf8, "] 3\n[] 0\n[last] 4\nend\n">>},
                 Run("h\\303\\251\\r\\nzw\\344\\270\\255\\n\\nlast", "lines")),
    ?assertEqual({1, <<"[ok] 2\nfault: the standard input is not UTF-8\n">>},
                 Run("ok\\n\\377\\nnext\\n", "lines")),
    ?assertEqual({0, <<"head\n", 255, 16#e9/utf8, "tail\nbytes 8\n">>},
                 Run("head\\n\\377\\303\\251tail\\n", "stream")),
    %% a read does not wait for more than has arrived
    ?assertEqual({0, <<"1\n1\nend\n">>},
                 sh("sh -c 'printf a; sleep 1; printf b' | ../bin/ern run build/stdin/chunks.erc")).

%% report §4.2, §11.1: the two-module pair in directory mode
modules_test() ->
    {0, _} = sh("../bin/ern build --build-root build/modules ../examples/modules"),
    {0, Out} = sh("../bin/ern run build/modules/main.erc"),
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
