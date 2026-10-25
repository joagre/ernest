%% `make bench`'s part `foreign` (docs/development.md): what each piece of a
%% program's foreign call adds to the host's call (report §8.4, §8.6, §12.3;
%% plan, MVP 3.28, 3.29). The emitter writes a `foreign fn` as a function of
%% the unit that calls the implementation in a try whose handler makes a
%% raise a fault (`ern_boundary:raised/6`, §12.3), and checks the return
%% against the declared result type: a word's in place, the prelude's
%% `Unit` taking the host's `ok`, any other through `ern_boundary` with its
%% descriptor (§8.4; ern_emitter's foreign_body/6, foreign_call/6 and
%% check_form/5). The call writes nothing for the deadlock look, which
%% reads the process's top frame; a function given to foreign code keeps
%% the look's key while foreign code calls it, in the wrapper that checks
%% its arguments (ern_emitter's called/2, §8.6).
%%
%% Measured, in foreign.txt: the host's call of `erlang:abs/1` and a foreign
%% fn of it; the host's call of a function of this module's that answers at
%% once, and a foreign fn of it for each kind of result: a word, `Int`, a
%% constructor, `Ordering`, `Unit`, a `String`, and a value of a type with
%% fields, `Optional(Int)`; a model of the foreign fn, a piece added on each
%% row, so that its multiple of the host's call is accounted for piece by
%% piece; a function called back by foreign code, the host's and a
%% program's; each operation of the models' alone, in a loop of its own;
%% and the host's call, the foreign fn and the look's key alone, by one
%% process and by eight at once, each a process with its row. Every row
%% runs in a launch of the runtime, as `ern run` starts one. Each row is
%% the median of seven runs, in nanoseconds an iteration, the loop's own
%% cost included, or a call over all processes, with their range, as
%% ern_costs measures them. It measures and asserts nothing, so it is not
%% part of `make test-full`.
-module(ern_foreign_costs).

-export([main/1, word/1, ordering/1, nothing/1, text/1, some/1, applied/2, called/1, tried/1,
         checked/1]).

%% Each loop's iterations, and each process's where several run at once,
%% and how many do.
-define(COUNT, 1000000).
-define(CONTENDED, 100000).
-define(AT_ONCE, 8).
%% The module the foreign fns are compiled into.
-define(NAMESPACE, ['ForeignCosts']).

%% The program's foreign fns, one for each implementation measured.
-define(SOURCE,
        <<"export foreign fn absolute(n : Int) : Int = \"erlang:abs/1\"\n"
          "export foreign fn word(n : Int) : Int = \"ern_foreign_costs:word/1\"\n"
          "export foreign fn ordering(n : Int) : Ordering = \"ern_foreign_costs:ordering/1\"\n"
          "export foreign fn nothing(n : Int) : Unit = \"ern_foreign_costs:nothing/1\"\n"
          "export foreign fn text(n : Int) : String = \"ern_foreign_costs:text/1\"\n"
          "export foreign fn some(n : Int) : Optional(Int) = \"ern_foreign_costs:some/1\"\n"
          "foreign fn applied(f : (Int) -> Int, n : Int) : Int = \"ern_foreign_costs:applied/2\"\n"
          "export fn calledBack(n : Int) : Int = applied(fn(k : Int) : Int = k, n)\n">>).

%% Prints the tables, writes them to foreign.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Unit = ern_costs:compiled(?NAMESPACE, ?SOURCE),
    Host = fun(Implementation) -> ern_costs:launched(host_calls(Implementation)) end,
    Ernest = fun(Name) -> ern_costs:launched(ernest_calls(Unit, Name)) end,
    Abs = [{"the host's call of erlang:abs/1", Host(fun erlang:abs/1)},
           {"a foreign fn of it, its result Int", Ernest(absolute)}],
    Kinds = [{"the host's call of a function that answers at once", Host(fun ?MODULE:word/1)},
             {"a foreign fn of it, its result Int", Ernest(word)},
             {"  one answering Less, its result Ordering", Ernest(ordering)},
             {"  one answering ok, its result Unit", Ernest(nothing)},
             {"  one answering \"text\", its result String", Ernest(text)},
             {"  one answering Some(n), its result Optional(Int)", Ernest(some)}],
    Model = [{"the host's call", Host(fun ?MODULE:word/1)},
             {"+ in a function of its own, as the unit's", Host(fun ?MODULE:called/1)},
             {"+ in a try, a raise made a fault", Host(fun ?MODULE:tried/1)},
             {"+ its return checked, an Int in place", Host(fun ?MODULE:checked/1)}],
    Back = [{"the host's call of a function that calls a fun back",
             Host(fun(N) -> ?MODULE:applied(fun(K) -> K end, N) end)},
            {"a foreign fn of it, an Ernest function called back", Ernest(calledBack)}],
    Text = unicode:characters_to_binary(
             [ern_costs:table("a foreign call of a host function, ns an iteration",
                              ern_costs:measured(Abs, ?COUNT), ratio),
              ern_costs:table("a foreign call by the type of its result, ns an iteration",
                              ern_costs:measured(Kinds, ?COUNT), ratio),
              ern_costs:table("a model of a foreign fn, a piece added on each row",
                              ern_costs:measured(Model, ?COUNT), added),
              ern_costs:table("a function called back by foreign code, ns an iteration",
                              ern_costs:measured(Back, ?COUNT), ratio),
              ern_costs:table("its operations, each alone, ns an operation",
                              ern_costs:measured(operations(), ?COUNT), none),
              ern_costs:table("eight processes at once against one, "
                              "ns a call over all processes",
                              ern_costs:measured(contended(Unit), ?CONTENDED),
                              none)]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "foreign.txt"), Text),
    halt(0).

%%
%% The implementations the foreign fns call, each answering at once
%%

-spec word(integer()) -> integer().
word(N) -> N.

-spec ordering(integer()) -> 'Less'.
ordering(_) -> 'Less'.

-spec nothing(integer()) -> ok.
nothing(_) -> ok.

-spec text(integer()) -> binary().
text(_) -> <<"text">>.

-spec some(integer()) -> {'Some', integer()}.
some(N) -> {'Some', N}.

-spec applied(fun((integer()) -> integer()), integer()) -> integer().
applied(Function, N) -> Function(N) + 0.

%%
%% The host's, and the program's
%%

%% Count calls of Implementation, as the host makes them.
host_calls(Implementation) ->
    fun(Count) -> ern_costs:timed(Count, ern_costs:looped(Implementation)) end.

%% Count calls of the program's foreign fn Name, as a dependent's code
%% calls it, by its position in its unit (report §11.1).
ernest_calls(Unit, Name) ->
    {Function, 1} = ern_code:function(Unit, ?NAMESPACE ++ [Name]),
    fun(Count) -> ern_costs:timed(Count, ern_costs:looped(fun Unit:Function/1)) end.

%%
%% The model, each row a function of its own, the code the emitter writes
%% for `foreign fn word(n : Int) : Int = "ern_foreign_costs:word/1"` a piece
%% at a time
%%

-spec called(integer()) -> integer().
called(N) ->
    ?MODULE:word(N).

-spec tried(integer()) -> integer().
tried(N) ->
    try ?MODULE:word(N)
    catch Class:Error:Trace -> ern_boundary:raised(?MODULE, word, 1, Class, Error, Trace)
    end.

-spec checked(integer()) -> integer().
checked(N) ->
    case tried(N) of
        Checked when is_integer(Checked) -> Checked;
        _ -> ern_rt:fault(<<"the return of foreign function ern_foreign_costs:word/1 does not"
                            " match Int">>)
    end.

%%
%% The operations, each alone
%%

%% Each operation of the models' alone in a loop, in a launch: the loop
%% alone, the remote call, a fun made and called, a try around a call, the
%% look's key put and taken as a function called back by foreign code
%% keeps it, and the checks of a return: an integer in place, a
%% constructor's, a string's, and a value with fields through ern_boundary.
operations() ->
    %% the descriptors ern_descriptor gives the two types
    Ordering = {con, [{'Less', []}, {'Equal', []}, {'Greater', []}]},
    Some = {con, [{'None', []}, {'Some', [int]}]},
    [{Name, ern_costs:launched(fun(Count) -> operated(Operation, Count) end)}
     || {Name, Operation} <-
            [{"the loop alone", fun(_) -> ok end},
             {"the host's call", fun(N) -> ?MODULE:word(N) end},
             {"a fun made and called", fun(N) -> (fun() -> N end)() end},
             {"a try around a call", fun(N) -> try ?MODULE:word(N) catch _:_ -> error end end},
             {"the look's key put and taken, entered_foreign/0 and left_foreign/0",
              fun(_) -> ern_rt:entered_foreign(), ern_rt:left_foreign() end},
             {"an Int checked in place", fun(N) -> is_integer(N) end},
             {"an Ordering checked, ern_boundary:check/3",
              fun(_) -> ern_boundary:check(Ordering, 'Less', <<"no">>) end},
             {"a String checked, ern_boundary:check/3",
              fun(_) -> ern_boundary:check(string, <<"text">>, <<"no">>) end},
             {"an Optional(Int) checked, ern_boundary:check/3",
              fun(N) -> ern_boundary:check(Some, {'Some', N}, <<"no">>) end}]].

%% The call and the key with one process and with ?AT_ONCE at once, each a
%% process the runtime spawns, with its row (ern_costs:at_once/2):
%% the host's call of a function that answers at once, a foreign fn of it,
%% and the look's key put and taken.
contended(Unit) ->
    {Word, 1} = ern_code:function(Unit, ?NAMESPACE ++ [word]),
    [{Name ++ Processes,
      ern_costs:launched(
        fun(Count) ->
            ern_costs:at_once(Count, lists:duplicate(Many, ern_costs:looped(Operation)))
        end)}
     || {Name, Operation} <-
            [{"the host's call", fun(N) -> ?MODULE:word(N) end},
             {"a foreign fn of it, its result Int", fun(N) -> Unit:Word(N) end},
             {"the look's key put and taken",
              fun(_) -> ern_rt:entered_foreign(), ern_rt:left_foreign() end}],
        {Many, Processes} <- [{1, ", one process"}, {?AT_ONCE, ", eight at once"}]].

%% Count iterations of Operation.
operated(Operation, Count) ->
    ern_costs:timed(Count, ern_costs:looped(Operation)).
