%% Plan, MVP 2.99b's item 10: the program of test/service run under the
%% host's service manager, as the guide's §9.5 says a program is run, by a
%% systemd unit on Linux and a launchd agent on macOS. The manager starts
%% it, stops it, and starts it again after it ends with a status that is
%% not 0; a stop asked for ends it by its signal (report §8.6, §11.8); and
%% a fault's line carries one time, the journal's under systemd and its own
%% in launchd's file (§11.2). `make service` runs the checks, before a
%% release (docs/release_review.md). They are no part of `make test`, which
%% a host without a service manager runs too. A stop is asked for only
%% once the program has said that it started: one that comes in the host's
%% first fraction of a second is the host's limit (§8.6).
-module(ern_service_tests).

-include_lib("eunit/include/eunit.hrl").

service_test_() ->
    case manager() of
        systemd ->
            [{"systemd stops", {timeout, 120, fun systemd_stops/0}},
             {"systemd restarts", {timeout, 120, fun systemd_restarts/0}}];
        launchd ->
            [{"launchd stops", {timeout, 120, fun launchd_stops/0}},
             {"launchd restarts", {timeout, 120, fun launchd_restarts/0}}];
        none ->
            [{"a service manager", fun() -> error(no_service_manager_here) end}]
    end.

%% The service manager that runs for this user: systemd's user instance,
%% launchd on macOS, or none.
manager() ->
    case os:type() of
        {unix, darwin} ->
            launchd;
        _ ->
            case os:find_executable("systemctl") =/= false
                andalso sh("systemctl --user show-environment") of
                {0, _} -> systemd;
                _ -> none
            end
    end.

%%
%% systemd
%%

%% report §8.6, §11.8, §11.2: under a systemd unit the program starts; its
%% fault's line is in the journal as `ern run` wrote it, with no time of
%% its own, since the journal stamps it; and a stop ends the program by the
%% termination signal, which systemd counts as a stop it asked for
systemd_stops() ->
    with_unit([], fun(Unit, Ended) ->
                      {0, _} = systemctl("start " ++ Unit),
                      ok = eventually(fun() -> lists:member(<<"started">>, journal(Unit)) end),
                      ok = eventually(fun() -> faults(journal(Unit)) =/= [] end),
                      [Fault] = faults(journal(Unit)),
                      ?assertMatch({match, _},
                                   re:run(Fault, "^Service\\.serve:[0-9]+ faulted: on purpose$")),
                      ?assertEqual(<<"active">>, shown(Unit, "ActiveState")),
                      {0, _} = systemctl("stop " ++ Unit),
                      ?assertEqual(<<"inactive">>, shown(Unit, "ActiveState")),
                      ?assertEqual({ok, <<"success killed TERM\n">>}, file:read_file(Ended))
                  end).

%% report Appendix E.23, §11.8: a program that ends with `Os.exit(1)` is
%% started again by `Restart=on-failure`, and one a stop ends is not
systemd_restarts() ->
    Marker = filename:absname(scratch() ++ "/marker"),
    with_unit(["once", Marker],
              fun(Unit, Ended) ->
                  {0, _} = systemctl("start " ++ Unit),
                  ok = eventually(fun() -> lists:member(<<"started">>, journal(Unit)) end),
                  ?assertEqual(<<"1">>, shown(Unit, "NRestarts")),
                  ?assertEqual(<<"active">>, shown(Unit, "ActiveState")),
                  {0, _} = systemctl("stop " ++ Unit),
                  ?assertEqual(<<"inactive">>, shown(Unit, "ActiveState")),
                  ?assertEqual({ok, <<"exit-code exited 1\nsuccess killed TERM\n">>},
                               file:read_file(Ended))
              end).

%% Runs Check with a unit of the user's service manager that runs the
%% program with Arguments, and the file its runs' ends are noted in. The
%% unit is a runtime unit, under a name of this run's own, so that nothing
%% of the user's is touched and its journal holds this run alone; it is
%% stopped and removed after.
with_unit(Arguments, Check) ->
    Runtime = os:getenv("XDG_RUNTIME_DIR"),
    true = is_list(Runtime),
    Unit = "ernest-check-" ++ os:getpid() ++ "-"
        ++ integer_to_list(erlang:unique_integer([positive])) ++ ".service",
    File = filename:join([Runtime, "systemd", "user", Unit]),
    Ended = filename:absname(scratch() ++ "/ended"),
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, unit(Arguments, Ended)),
    {0, _} = systemctl("daemon-reload"),
    try
        Check(Unit, Ended)
    after
        _ = systemctl("stop " ++ Unit),
        _ = systemctl("reset-failed " ++ Unit),
        ok = file:delete(File),
        {0, _} = systemctl("daemon-reload")
    end.

%% The unit the guide's §9.5 writes, for the checks' program, and one line
%% more, which notes how each run ended: the manager's result, how the
%% process ended, and its status or its signal.
unit(Arguments, Ended) ->
    ["[Unit]\n"
     "Description=Ernest's service check\n"
     "\n"
     "[Service]\n"
     "ExecStart=\"", filename:absname("../bin/ern"), "\" run \"",
     filename:absname("build/service/service.erc"), "\"",
     [[" \"", Argument, "\""] || Argument <- Arguments], "\n"
     "WorkingDirectory=", filename:absname("."), "\n"
     "Restart=on-failure\n"
     "ExecStopPost=/bin/sh -c 'echo \"$$SERVICE_RESULT $$EXIT_CODE $$EXIT_STATUS\" >> \"",
     Ended, "\"'\n"].

systemctl(Command) ->
    sh("systemctl --user " ++ Command).

%% A property of the unit as the manager holds it.
shown(Unit, Property) ->
    {0, Value} = systemctl("show " ++ Unit ++ " --property " ++ Property ++ " --value"),
    string:trim(Value).

%% What the unit's runs have written, a line each, as the journal holds it
%% without the journal's own stamp.
journal(Unit) ->
    {0, Output} = sh("journalctl --user --unit " ++ Unit ++ " --output cat --no-pager"),
    binary:split(Output, <<"\n">>, [global]).

%%
%% launchd. Written with the unit and not yet run: its checks wait for a
%% Mac (plan, MVP 2.99b's item 10).
%%

%% report §8.6, §11.8, §11.2: under a launchd agent the program starts; its
%% fault's line in the file launchd writes standard error to begins with
%% its time, once; and a stop ends the program by the termination signal,
%% well before launchd would kill it
launchd_stops() ->
    with_agent([], fun(Service, Out, Err) ->
                       ok = eventually(fun() -> lists:member(<<"started">>, lines(Out)) end),
                       ok = eventually(fun() -> faults(lines(Err)) =/= [] end),
                       [Fault] = faults(lines(Err)),
                       Stamped = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z"
                                 " Service\\.serve:[0-9]+ faulted: on purpose$",
                       ?assertMatch({match, _}, re:run(Fault, Stamped)),
                       Pid = agent_pid(Service),
                       {0, _} = sh("launchctl bootout " ++ Service),
                       ?assertEqual(ok, eventually(fun() -> not is_running(Pid) end, 50))
                   end).

%% report Appendix E.23, §11.8: a program that ends with `Os.exit(1)` is
%% started again by an agent kept alive unless it ends with status 0
launchd_restarts() ->
    Marker = filename:absname(scratch() ++ "/marker"),
    with_agent(["once", Marker],
               fun(Service, Out, _Err) ->
                   ok = eventually(fun() -> lists:member(<<"started">>, lines(Out)) end),
                   ?assert(filelib:is_regular(Marker)),
                   Pid = agent_pid(Service),
                   {0, _} = sh("launchctl bootout " ++ Service),
                   ?assertEqual(ok, eventually(fun() -> not is_running(Pid) end, 50))
               end).

%% Runs Check with an agent of this user that runs the program with
%% Arguments, named as launchctl names it, and the files its two streams go
%% to. The agent is under a label of this run's own, and is removed after.
with_agent(Arguments, Check) ->
    Dir = filename:absname(scratch()),
    Label = "org.ernest.check." ++ os:getpid() ++ "."
        ++ integer_to_list(erlang:unique_integer([positive])),
    Plist = filename:join(Dir, Label ++ ".plist"),
    Out = filename:join(Dir, "out"),
    Err = filename:join(Dir, "err"),
    ok = file:write_file(Plist, plist(Label, Arguments, Dir, Out, Err)),
    {0, User} = sh("id -u"),
    Domain = "gui/" ++ string:trim(binary_to_list(User)),
    Service = Domain ++ "/" ++ Label,
    {0, _} = sh("launchctl bootstrap " ++ Domain ++ " " ++ Plist),
    try
        Check(Service, Out, Err)
    after
        _ = sh("launchctl bootout " ++ Service)
    end.

%% An agent for launchd: the program run in the foreground, started when
%% the agent is loaded and again whenever it ends with a status that is not
%% 0, a second after; its two streams to files, since launchd keeps no
%% journal; and the `PATH` this run has, since launchd's own does not hold
%% the host's `erl`.
plist(Label, Arguments, Dir, Out, Err) ->
    Words = [filename:absname("../bin/ern"), "run",
             filename:absname("build/service/service.erc") | Arguments],
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
     "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\""
     " \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
     "<plist version=\"1.0\">\n"
     "<dict>\n"
     "    <key>Label</key>\n"
     "    <string>", Label, "</string>\n"
     "    <key>ProgramArguments</key>\n"
     "    <array>\n",
     [["        <string>", Word, "</string>\n"] || Word <- Words],
     "    </array>\n"
     "    <key>WorkingDirectory</key>\n"
     "    <string>", Dir, "</string>\n"
     "    <key>EnvironmentVariables</key>\n"
     "    <dict>\n"
     "        <key>PATH</key>\n"
     "        <string>", os:getenv("PATH"), "</string>\n"
     "    </dict>\n"
     "    <key>RunAtLoad</key>\n"
     "    <true/>\n"
     "    <key>KeepAlive</key>\n"
     "    <dict>\n"
     "        <key>SuccessfulExit</key>\n"
     "        <false/>\n"
     "    </dict>\n"
     "    <key>ThrottleInterval</key>\n"
     "    <integer>1</integer>\n"
     "    <key>StandardOutPath</key>\n"
     "    <string>", Out, "</string>\n"
     "    <key>StandardErrorPath</key>\n"
     "    <string>", Err, "</string>\n"
     "</dict>\n"
     "</plist>\n"].

%% The agent's process, as `launchctl print` says it.
agent_pid(Service) ->
    {0, Printed} = sh("launchctl print " ++ Service),
    {match, [Pid]} = re:run(Printed, "\\bpid = ([0-9]+)", [{capture, all_but_first, list}]),
    Pid.

is_running(Pid) ->
    {Status, _} = sh("sh -c 'kill -0 " ++ Pid ++ "'"),
    Status =:= 0.

lines(File) ->
    case file:read_file(File) of
        {ok, Text} -> binary:split(Text, <<"\n">>, [global]);
        {error, enoent} -> []
    end.

%%
%% Both
%%

%% The lines that report the fault the program makes on purpose.
faults(Lines) ->
    [Line || Line <- Lines, binary:match(Line, <<"faulted: on purpose">>) =/= nomatch].

%% A directory of this run's own under build/service.
scratch() ->
    Dir = "build/service/run-" ++ os:getpid() ++ "-"
        ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_path(Dir),
    Dir.

%% Asks ten times a second until the answer is yes, for ten seconds, or for
%% Tries times.
eventually(Ask) ->
    eventually(Ask, 100).

eventually(Ask, Tries) ->
    case Ask() of
        true ->
            ok;
        false when Tries > 0 ->
            timer:sleep(100),
            eventually(Ask, Tries - 1);
        false ->
            timeout
    end.

sh(Command) ->
    Program = open_port({spawn, Command}, [exit_status, stderr_to_stdout, binary]),
    collect(Program, []).

collect(Program, Acc) ->
    receive
        {Program, {data, Data}} -> collect(Program, [Data | Acc]);
        {Program, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.
