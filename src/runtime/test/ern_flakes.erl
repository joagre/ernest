%% The flake hunt's host, which tools/flakes.ern starts for each part of
%% the split suites (docs/development.md, *Building*): the part's tests, as
%% make test gives them, run round after round in this one host until the
%% hunt's end, each round in a directory of its own, ERN_TEST_DIR, removed
%% when the round ends. An EUnit listener writes each test that fails, is
%% skipped or is canceled to the part's file as it is told of it, with its
%% reason and what it wrote, and names it in one line on standard output,
%% the record's first line.
%%
%% A cancel that ended a test's process leaves what that test started in
%% the host, which the hunt runs on. So each record that follows such a
%% cancel in the host names the host's first, the test and its round, on
%% its first line, and a failure there may not be its test's own. The
%% first cancel is the one value the host carries from round to round:
%% round/5 gives it to the round's listener and answers what the listener
%% ends with.
%%
%% EUnit keeps no output for a canceled test: the process that holds it is
%% ended with the test, so a canceled test's record has its reason alone,
%% which for a time limit is where the test was when the limit came.
-module(ern_flakes).

-behaviour(eunit_listener).

-export([hunt/1, round/5, start/1, init/1, handle_begin/3, handle_end/3, handle_cancel/3,
         terminate/2]).

%% The host's first cancel that ended a test's process, by the test's name
%% and its round, or none before one.
-type canceled() :: none | {string(), pos_integer()}.

%% Tests in rounds until the hunt's time is up: a round that has begun is
%% finished, and none begins once the time is up. What the hunt gives each
%% host is in its environment, set by tools/flakes.ern: the part's name,
%% ERN_FLAKES_PART; the records' directory, ERN_FLAKES_RECORDS, absolute;
%% the moment no round begins at or after, ERN_FLAKES_UNTIL, in
%% milliseconds since the epoch; and the directory each round's directory
%% stands in, ERN_FLAKES_ROUNDS.
%%
%% The part's file is Part.txt in the records' directory, and each round's
%% seconds are a line of Part.rounds there. A directory a round's tests
%% leave that cannot be removed is a record of its own.
-spec hunt([term()]) -> 0.
hunt(Tests) ->
    Until = list_to_integer(os:getenv("ERN_FLAKES_UNTIL")),
    hunt(Tests, Until, #{part => os:getenv("ERN_FLAKES_PART"),
                         records => os:getenv("ERN_FLAKES_RECORDS"),
                         rounds => os:getenv("ERN_FLAKES_ROUNDS")}, 1, none).

hunt(Tests, Until, #{part := Part, records := Records, rounds := Rounds} = Hunt, Round,
     Canceled) ->
    case os:system_time(millisecond) >= Until of
        true ->
            0;
        false ->
            Start = erlang:monotonic_time(second),
            File = filename:join(Records, Part ++ ".txt"),
            Directory = filename:join(Rounds, Part ++ "." ++ integer_to_list(Round)),
            ok = file:make_dir(Directory),
            true = os:putenv("ERN_TEST_DIR", Directory),
            {_, Answered} = round(Tests, Round, Part, File, Canceled),
            case file:del_dir_r(Directory) of
                ok -> ok;
                Error -> written(#{part => Part, round => Round, file => File},
                                 marked(Answered, "its directory not removed"),
                                 io_lib:format("~tp~n", [Error]), "")
            end,
            Seconds = erlang:monotonic_time(second) - Start,
            ok = file:write_file(filename:join(Records, Part ++ ".rounds"),
                                 [integer_to_list(Seconds), "\n"], [append]),
            hunt(Tests, Until, Hunt, Round + 1, Answered)
    end.

%% One round of Tests, each that does not pass written to File as its
%% listener is told of it, after the host's first cancel, Canceled, where
%% there was one; EUnit's answer, `error` where any did not pass, and the
%% host's first cancel once the round has ended.
%%
%% The listener sends that cancel as it ends, which eunit:test/2 waits for,
%% so it is here once the round has ended. There is none only where EUnit
%% could not start the round, which then ran no test.
-spec round([term()], pos_integer(), string(), file:filename(), canceled()) ->
          {ok | error, canceled()}.
round(Tests, Round, Part, File, Canceled) ->
    Ref = make_ref(),
    Options = [{round, Round}, {part, Part}, {file, File}, {canceled, Canceled},
               {answer, {self(), Ref}}],
    Result = eunit:test(Tests, [no_tty, {report, {?MODULE, Options}}]),
    receive
        {Ref, Answered} -> {Result, Answered}
    after 0 ->
        {Result, Canceled}
    end.

%% The listener, which EUnit starts with the options round/5 gives it, a
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

%% A group is canceled with no reason where its tests were skipped, and with
%% a test's blame where that test was canceled, each test told of on its
%% own: the group blamed is the canceled test's alone (ern_eunit), or a
%% generator's, whose tests after it EUnit runs none of, which the canceled
%% test's record stands for. Any other cancel of a group is its own record.
-spec handle_cancel(group | test, list(), map()) -> map().
handle_cancel(group, Data, Options) ->
    case proplists:get_value(reason, Data) of
        undefined -> Options;
        {blame, _} -> Options;
        Reason -> canceled(Options, Data, Reason)
    end;
handle_cancel(test, Data, Options) ->
    canceled(Options, Data, proplists:get_value(reason, Data)).

%% The round's end: the host's first cancel, sent to round/5.
-spec terminate(term(), map()) -> ok.
terminate(_, #{answer := {Hunter, Ref}, canceled := Canceled}) ->
    Hunter ! {Ref, Canceled},
    ok.

%% A cancel's record, and the host's first cancel where none came before
%% and this one ended its test's process.
canceled(Options, Data, Reason) ->
    #{canceled := Canceled, round := Round} = Told =
        told(Options, Data, "canceled", io_lib:format("~tp", [Reason])),
    case Canceled =:= none andalso ended(Reason) of
        true -> Told#{canceled := {lists:flatten(name(Data)), Round}};
        false -> Told
    end.

%% Whether a cancel's reason says it ended its test's process: EUnit killed
%% it at its time limit, a test's or a group's, `{timeout, _}`, or an exit
%% signal it did not trap ended it, `exit`. An abort, a setup or a
%% generator that raised, ended none, since the raise ran the process's own
%% cleanup.
ended({timeout, _}) -> true;
ended({exit, _}) -> true;
ended(_) -> false.

%% A record, and its first line on standard output in the record's words.
told(#{round := Round, part := Part, canceled := Canceled} = Options, Data, What, Reason) ->
    Header = marked(Canceled, [name(Data), " ", What]),
    io:format("make flakes: ~ts, round ~B: ~ts~n", [Part, Round, Header]),
    Output = case proplists:get_value(output, Data) of
                 undefined -> "nothing EUnit keeps: it keeps no output of what it cancels\n";
                 Written -> Written
             end,
    written(Options, Header, [Reason, "\n-- what it wrote:\n"], Output),
    Options.

%% What did not pass, and the host's first cancel where the record follows
%% one.
marked(none, What) ->
    What;
marked({Name, Round}, What) ->
    [What, io_lib:format(", after ~ts was canceled in round ~B", [Name, Round])].

%% A record of the part's file: a line that names the part, the round and
%% what did not pass, marked, which the hunt's summary counts; then its
%% text, what the test wrote as its bytes, and a blank line.
written(#{part := Part, round := Round, file := File}, Header, Text, Output) ->
    Line = io_lib:format("== ~ts, round ~B: ~ts~n~ts", [Part, Round, Header, Text]),
    ok = file:write_file(File, [unicode:characters_to_binary(Line), Output, "\n"], [append]).

%% A test by its function, `module:function/arity`, a fun's as the host
%% names it, with its description where it has one; a group by its
%% description, or by its place among the tests, the round itself by none.
name(Data) ->
    Id = proplists:get_value(id, Data),
    Described = case proplists:get_value(desc, Data) of
                    undefined -> "";
                    Description -> io_lib:format(" \"~ts\"", [Description])
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
