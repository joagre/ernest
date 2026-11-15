%% The flake hunt's host, which tools/flakes.ern starts for each part of
%% the split suites (docs/development.md, *Building*): the part's tests, as
%% make test gives them, run round after round in this one host until the
%% hunt's end, each round in a directory of its own, ERN_TEST_DIR, removed
%% when the round ends. An EUnit listener writes each test that fails, is
%% skipped or is canceled to the part's file as it is told of it, with its
%% reason and what it wrote, and names it in one line on standard output.
%%
%% EUnit keeps no output for a canceled test: the process that holds it is
%% ended with the test, so a canceled test's record has its reason alone,
%% which for a time limit is where the test was when the limit came.
-module(ern_flakes).

-behaviour(eunit_listener).

-export([hunt/1, round/4, start/1, init/1, handle_begin/3, handle_end/3, handle_cancel/3,
         terminate/2]).

%% Tests in rounds until the hunt's time is up: a round that has begun is
%% finished, and none begins once the time is up. What the hunt gives each
%% host is in its environment, set by tools/flakes.ern: the part's name,
%% ERN_FLAKES_PART; the records' directory, ERN_FLAKES_RECORDS, absolute;
%% the moment no round begins at or after, ERN_FLAKES_UNTIL, in
%% milliseconds since the epoch; and the directory each round's directory
%% stands in, ERN_FLAKES_ROUNDS.
%%
%% Each round begins in the directory the hunt began in, as a run begins in
%% the repository's root, since a test ended at its limit may leave the
%% host in a directory of its own. The part's file is Part.txt in the
%% records' directory, and each round's seconds are a line of Part.rounds
%% there. A directory a round's tests leave that cannot be removed is a
%% record of its own.
-spec hunt([term()]) -> 0.
hunt(Tests) ->
    {ok, Cwd} = file:get_cwd(),
    Until = list_to_integer(os:getenv("ERN_FLAKES_UNTIL")),
    hunt(Tests, Until, #{part => os:getenv("ERN_FLAKES_PART"),
                         records => os:getenv("ERN_FLAKES_RECORDS"),
                         rounds => os:getenv("ERN_FLAKES_ROUNDS"), cwd => Cwd}, 1).

hunt(Tests, Until, #{part := Part, records := Records, rounds := Rounds, cwd := Cwd} = Hunt,
     Round) ->
    case os:system_time(millisecond) >= Until of
        true ->
            0;
        false ->
            Start = erlang:monotonic_time(second),
            File = filename:join(Records, Part ++ ".txt"),
            Dir = filename:join(Rounds, Part ++ "." ++ integer_to_list(Round)),
            ok = file:set_cwd(Cwd),
            ok = file:make_dir(Dir),
            true = os:putenv("ERN_TEST_DIR", Dir),
            _ = round(Tests, Round, Part, File),
            case file:del_dir_r(Dir) of
                ok -> ok;
                Error -> written(File, Part, Round, "its directory not removed",
                                 io_lib:format("~tp~n", [Error]), "")
            end,
            Seconds = erlang:monotonic_time(second) - Start,
            ok = file:write_file(filename:join(Records, Part ++ ".rounds"),
                                 [integer_to_list(Seconds), "\n"], [append]),
            hunt(Tests, Until, Hunt, Round + 1)
    end.

%% One round of Tests, each that does not pass written to File as its
%% listener is told of it; EUnit's answer, `error` where any did not pass.
-spec round([term()], pos_integer(), string(), file:filename()) -> ok | error.
round(Tests, Round, Part, File) ->
    eunit:test(Tests, [no_tty, {report, {?MODULE, [{round, Round}, {part, Part}, {file, File}]}}]).

%% The listener, which EUnit starts with the options round/4 gives it, a
%% list as EUnit's listeners take them.
-spec start(proplists:proplist()) -> pid().
start(Options) ->
    eunit_listener:start(?MODULE, Options).

-spec init(proplists:proplist()) -> map().
init(Options) ->
    maps:from_list(Options).

-spec handle_begin(group | test, list(), map()) -> map().
handle_begin(_, _, Options) ->
    Options.

-spec handle_end(group | test, list(), map()) -> map().
handle_end(test, Data, Options) ->
    case proplists:get_value(status, Data) of
        ok ->
            Options;
        {error, {Class, Reason, Stack}} ->
            told(Options, Data, "failed", erl_error:format_exception(Class, Reason, Stack));
        {skipped, Reason} ->
            told(Options, Data, "skipped", io_lib:format("~tp", [Reason]))
    end;
handle_end(group, _, Options) ->
    Options.

%% A group is canceled with no reason where its tests were skipped, each
%% told of on its own, and with a test's blame where that test was canceled:
%% EUnit then runs none of the group's tests after it and counts them
%% nowhere, the round being one group, so the record says so. Any other
%% cancel of a group is its own record.
-spec handle_cancel(group | test, list(), map()) -> map().
handle_cancel(group, Data, Options) ->
    case proplists:get_value(reason, Data) of
        undefined -> Options;
        {blame, _} -> unrun(Options, Data);
        Reason -> told(Options, Data, "canceled", io_lib:format("~tp", [Reason]))
    end;
handle_cancel(test, Data, Options) ->
    told(Options, Data, "canceled", io_lib:format("~tp", [proplists:get_value(reason, Data)])).

-spec terminate(term(), map()) -> ok.
terminate(_, _) ->
    ok.

told(#{round := Round, part := Part, file := File} = Options, Data, What, Reason) ->
    Name = name(Data),
    io:format("make flakes: ~ts, round ~B: ~ts ~ts~n", [Part, Round, Name, What]),
    Output = case proplists:get_value(output, Data) of
                 undefined -> "nothing EUnit keeps: it keeps no output of what it cancels\n";
                 Written -> Written
             end,
    written(File, Part, Round, [Name, " ", What], [Reason, "\n-- what it wrote:\n"], Output),
    Options.

unrun(#{round := Round, part := Part, file := File} = Options, Data) ->
    Header = [name(Data), " did not run its tests after the canceled one"],
    io:format("make flakes: ~ts, round ~B: ~ts~n", [Part, Round, Header]),
    written(File, Part, Round, Header, "", ""),
    Options.

%% A record of the part's file: a line that names the part, the round and
%% what did not pass, which the hunt's summary counts, then its text, what
%% the test wrote as its bytes, and a blank line.
written(File, Part, Round, Header, Text, Output) ->
    Line = io_lib:format("== ~ts, round ~B: ~ts~n~ts", [Part, Round, Header, Text]),
    ok = file:write_file(File, [unicode:characters_to_binary(Line), Output, "\n"], [append]).

%% A test by its function, `module:function/arity`, a fun's as the host
%% names it, with its description where it has one; a group by its
%% description, or by its place among the tests, the round itself by none.
name(Data) ->
    Id = proplists:get_value(id, Data),
    Described = case proplists:get_value(desc, Data) of
                    undefined -> "";
                    Desc -> io_lib:format(" \"~ts\"", [Desc])
                end,
    case proplists:get_value(source, Data) of
        {Module, Function, Arity} ->
            io_lib:format("~w:~tw/~B~ts", [Module, Function, Arity, Described]);
        _ when Described =/= "" ->
            io_lib:format("the group~ts", [Described]);
        _ when Id =:= [] ->
            "the round";
        _ ->
            io_lib:format("the group ~w", [Id])
    end.
