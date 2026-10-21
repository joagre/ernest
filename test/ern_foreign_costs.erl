%% `make bench`'s sixth part (docs/development.md): what each piece of a
%% program's foreign call adds to the host's call (report §8.4, §8.6, §7.4;
%% plan, MVP 3.28). The emitter writes a `foreign fn` as a function of the
%% unit that calls the implementation inside `ern_rt:in_foreign/1`, which
%% counts the process as in foreign code while the call runs, so that a
%% deadlock is not found where foreign code can still deliver (§8.6), in a
%% try whose handler makes a raise a fault (`ern_boundary:raised/6`, §7.4),
%% and checks the return against the declared result type: a word's in
%% place, the prelude's `Unit` taking the host's `ok`, any other through
%% `ern_boundary` with its descriptor (§8.4; ern_emitter's foreign_body/6,
%% foreign_call/6 and check_form/6).
%%
%% Measured, in foreign.txt: the host's call of `erlang:abs/1` and a foreign
%% fn of it; the host's call of a function of this module's that answers at
%% once, and a foreign fn of it for each kind of result: a word, `Int`, a
%% constructor, `Ordering`, `Unit`, a `String`, and a value of a type with
%% fields, `Optional(Int)`; a model of the foreign fn, a piece added on each
%% row, so that its multiple of the host's call is accounted for piece by
%% piece; and each operation of the model's alone, in a loop of its own.
%% Every row runs in a launch of the runtime, as `ern run` starts one, where
%% the entry process has the row `in_foreign/1` counts in. Each row is the
%% median of seven runs, in nanoseconds an iteration, the loop's own cost
%% included, with their range, as ern_spawn_costs measures them. It
%% measures and asserts nothing, so it is not part of `make test-full`.
-module(ern_foreign_costs).

-export([main/1, word/1, ordering/1, nothing/1, text/1, some/1, called/1, tried/1, counted/1,
         checked/1]).

%% Each loop's iterations.
-define(COUNT, 1000000).
%% The module the foreign fns are compiled into.
-define(NAMESPACE, ['ForeignCosts']).

%% The program's foreign fns, one for each implementation measured.
-define(SOURCE,
        <<"export foreign fn absolute(n : Int) : Int = \"erlang:abs/1\"\n"
          "export foreign fn word(n : Int) : Int = \"ern_foreign_costs:word/1\"\n"
          "export foreign fn ordering(n : Int) : Ordering = \"ern_foreign_costs:ordering/1\"\n"
          "export foreign fn nothing(n : Int) : Unit = \"ern_foreign_costs:nothing/1\"\n"
          "export foreign fn text(n : Int) : String = \"ern_foreign_costs:text/1\"\n"
          "export foreign fn some(n : Int) : Optional(Int) = \"ern_foreign_costs:some/1\"\n">>).

%% Prints the tables, writes them to foreign.txt in Directory, and halts.
-spec main([string()]) -> no_return().
main([Directory]) ->
    Unit = compiled(),
    Host = fun(Implementation) -> ern_spawn_costs:launched(host_calls(Implementation)) end,
    Ernest = fun(Name) -> ern_spawn_costs:launched(ernest_calls(Unit, Name)) end,
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
             {"+ counted as in foreign code, in_foreign/1", Host(fun ?MODULE:counted/1)},
             {"+ its return checked, an Int in place", Host(fun ?MODULE:checked/1)}],
    Text = unicode:characters_to_binary(
             [ern_spawn_costs:table("a foreign call of a host function, ns an iteration",
                                    ern_spawn_costs:measured(Abs, ?COUNT), ratio),
              ern_spawn_costs:table("a foreign call by the type of its result, ns an iteration",
                                    ern_spawn_costs:measured(Kinds, ?COUNT), ratio),
              ern_spawn_costs:table("a model of a foreign fn, a piece added on each row",
                                    ern_spawn_costs:measured(Model, ?COUNT), added),
              ern_spawn_costs:table("its operations, each alone, ns an operation",
                                    ern_spawn_costs:measured(operations(), ?COUNT), none)]),
    io:format("~ts", [Text]),
    ok = file:write_file(filename:join(Directory, "foreign.txt"), Text),
    halt(0).

%% The program's foreign fns compiled and loaded, as `ern build` and `ern
%% run` would make and load them (report §11.1, §11.2): their unit.
compiled() ->
    {ok, Declarations} = ern_parser:parse_string(?SOURCE),
    {ok, Typed, Interface, Env} = ern_typecheck:check(?NAMESPACE, Declarations, []),
    {ok, Unit, Beam} = ern_compile:compile(?NAMESPACE, Typed, Interface, Env),
    {module, Unit} = code:load_binary(Unit, "foreign costs", Beam),
    {ok, Recorded} = ern_canonical:read(Beam),
    ok = ern_code:loaded(Unit, Beam, Recorded),
    Unit.

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

%%
%% The host's, and the program's
%%

%% Count calls of Implementation, as the host makes them.
host_calls(Implementation) ->
    fun(Count) ->
        ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                         Loop(Left) -> _ = Implementation(Left), Loop(Left - 1)
                                     end)
    end.

%% Count calls of the program's foreign fn Name, as a dependent's code
%% calls it, by its position in its unit (report §11.1).
ernest_calls(Unit, Name) ->
    {Function, 1} = ern_code:function(Unit, ?NAMESPACE ++ [Name]),
    fun(Count) ->
        ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                         Loop(Left) -> _ = Unit:Function(Left), Loop(Left - 1)
                                     end)
    end.

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

-spec counted(integer()) -> integer().
counted(N) ->
    try ern_rt:in_foreign(fun() -> ?MODULE:word(N) end)
    catch Class:Error:Trace -> ern_boundary:raised(?MODULE, word, 1, Class, Error, Trace)
    end.

-spec checked(integer()) -> integer().
checked(N) ->
    case counted(N) of
        Checked when is_integer(Checked) -> Checked;
        _ -> ern_rt:fault(<<"foreign return does not match Int">>)
    end.

%%
%% The operations, each alone
%%

%% Each operation of the model's alone in a loop, in a launch: the loop
%% alone, the remote call, a fun made and called, a try around a call, the
%% process's row's count of foreign calls raised and lowered as
%% in_foreign/1 does, a mark put and erased in the process's dictionary
%% beside it, and the checks of a return: an integer in place, a
%% constructor's, a string's, and a value with fields through ern_boundary.
operations() ->
    %% the descriptors ern_descriptor gives the two types
    Ordering = {con, [{'Less', []}, {'Equal', []}, {'Greater', []}]},
    Some = {con, [{'None', []}, {'Some', [int]}]},
    [{Name, ern_spawn_costs:launched(fun(Count) -> operated(Operation, Count) end)}
     || {Name, Operation} <-
            [{"the loop alone", fun(_) -> ok end},
             {"the host's call", fun(N) -> ?MODULE:word(N) end},
             {"a fun made and called", fun(N) -> (fun() -> N end)() end},
             {"a try around a call", fun(N) -> try ?MODULE:word(N) catch _:_ -> error end end},
             {"the row's count raised and lowered",
              fun(_) ->
                  ets:update_counter(ern_processes, self(), {4, 1}),
                  ets:update_counter(ern_processes, self(), {4, -1})
              end},
             {"  a mark put and erased in the dictionary",
              fun(_) -> put('$ern_foreign', 1), erase('$ern_foreign') end},
             {"an Int checked in place", fun(N) -> is_integer(N) end},
             {"an Ordering checked, ern_boundary:check/3",
              fun(_) -> ern_boundary:check(Ordering, 'Less', <<"no">>) end},
             {"a String checked, ern_boundary:check/3",
              fun(_) -> ern_boundary:check(string, <<"text">>, <<"no">>) end},
             {"an Optional(Int) checked, ern_boundary:check/3",
              fun(N) -> ern_boundary:check(Some, {'Some', N}, <<"no">>) end}]].

%% Count iterations of Operation.
operated(Operation, Count) ->
    ern_spawn_costs:timed(Count, fun Loop(0) -> ok;
                                     Loop(Left) -> _ = Operation(Left), Loop(Left - 1)
                                 end).
