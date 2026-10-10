%% Report §8.7: a node's code table, from each definition's identity to the
%% unit that holds it, and report §11.2: the host's limits on what a
%% runtime loads, which the runtime says it nears. A unit is a compiled
%% module of the host's, whose '$code'/0, which the compiler writes from
%% the canonical forms' hashes (ern_emitter), lists what it holds; loaded/1
%% reads it into the table as the unit loads: each function by its hash,
%% with its function, its arity and its reach, each lambda and local
%% function a spawn on a peer starts by its identity, with its entry's
%% function and arity and its reach, each type by its hash, each top-level
%% binding by its identity, its qualified name with its hash, with the key
%% its value is kept under (§8.5), and each foreign declaration's
%% implementation and function by its qualified name. A unit loaded again
%% with other code replaces its rows, and one unloaded takes them with it,
%% so that the table holds what the host holds and no more
%% (docs/memory.md).
%%
%% The table is an ETS table, not a persistent term: it is written at each
%% load, which would make a persistent term collect every process each
%% time, and read where a definition is found by its identity, a spawn by
%% hash among them (§8.7), at the cost of one lookup, a fraction of the
%% spawn. Two definitions with one hash are one definition (§8.7), so a
%% hash may have rows in two units, and the table is a bag. It is made at
%% its first use, by a process of its own that holds it for the host's
%% life, since the units it describes stay loaded across every run of the
%% host: `ern test` over a directory runs many (§11.2).
-module(ern_code).

-export([loaded/1, unloaded/1, spawnable/1, value/1, foreign/1, present/1, nearing/0, nearing/1,
         nearing/2, line/3, counts/0]).

-export_type([host_table/0, reach/0]).

-define(TABLE, ern_code).

%% Report §11.2: the host's tables whose limits a load nears.
-type host_table() :: module_names | exports | lambdas | atoms.

%% Report §8.7: a function's reach as its unit lists it, the bindings by
%% their identities and the foreign declarations by their qualified names
%% (ern_canonical).
-type reach() :: {[{[atom()], binary()}], [[atom()]]}.

-type count() :: {host_table(), non_neg_integer(), pos_integer()}.

%%
%% A unit's load
%%

%% Report §8.7: a unit's definitions put in the table as it loads. A unit
%% whose code the table holds already is passed over, and one loaded again
%% with other code replaces its rows. A module that is no unit, the host's
%% or a foreign function's, holds nothing here.
-spec loaded(module()) -> ok.
loaded(Unit) ->
    case erlang:function_exported(Unit, '$code', 0) of
        true -> fill(Unit, Unit:module_info(md5));
        false -> ok
    end.

fill(Unit, Md5) ->
    ensure(),
    case ets:lookup(?TABLE, {unit, Unit}) of
        [{_, _, {Md5, _}}] ->
            ok;
        Previous ->
            forget(Unit, Previous),
            Rows = lists:append([rows(Unit, QualifiedName, Held)
                                 || {QualifiedName, Held} <- Unit:'$code'()]),
            Keys = lists:usort([Key || {Key, _, _} <- Rows]),
            true = ets:insert(?TABLE, [{{unit, Unit}, Unit, {Md5, Keys}} | Rows]),
            ok
    end.

%% A unit's rows for one of its declarations: a definition by its identity,
%% a lambda or a local function a spawn on a peer starts by its identity,
%% and a foreign declaration, which has no identity, by its qualified name
%% (Appendix H).
rows(Unit, _, {function, Hash, Function, Arity, Reach}) ->
    [{{hash, Hash}, Unit, {function, Function, Arity, Reach}}];
rows(Unit, _, {lambda, Hash, Position, Function, Arity, Reach}) ->
    [{{lambda, Hash, Position}, Unit, {function, Function, Arity, Reach}}];
rows(Unit, QualifiedName, {binding, Hash, Key}) ->
    [{{binding, QualifiedName, Hash}, Unit, {binding, Key}}];
rows(Unit, _, {type, Hash}) ->
    [{{hash, Hash}, Unit, type}];
rows(Unit, QualifiedName, {foreign, HostModule, HostFunction, Function, Arity}) ->
    [{{foreign, QualifiedName}, Unit, {foreign, HostModule, HostFunction, Function, Arity}}].

%% Report §8.7: a unit unloaded, its rows gone with it.
-spec unloaded(module()) -> ok.
unloaded(Unit) ->
    forget(Unit, lookup({unit, Unit})).

%% The rows of a unit as the table holds them, each found by its key and
%% taken whole, since a key may name another unit's row beside it.
forget(Unit, UnitRows) ->
    [true = ets:delete_object(?TABLE, Row)
     || {_, _, {_, Keys}} <- UnitRows, Key <- Keys,
        {_, Holder, _} = Row <- ets:lookup(?TABLE, Key), Holder =:= Unit],
    [true = ets:delete_object(?TABLE, UnitRow) || UnitRow <- UnitRows],
    ok.

%%
%% The lookups, report §8.7
%%

%% Report §8.7: what a spawn on a peer names, by its identity: a function by
%% its hash, a lambda or a local function by its definition's hash and its
%% position, or a foreign function by its qualified name; the unit and the
%% function that run it, its arity, which is how many values it captured,
%% and its reach, the bindings and the foreign declarations it names, or
%% none where no unit of this node holds it. Where units hold it, the one
%% that runs it is answering/1's.
-spec spawnable({hash, binary()} | {lambda, binary(), pos_integer()} | {foreign, [atom()]}) ->
          {module(), atom(), arity(), reach()} | none.
spawnable({foreign, QualifiedName} = Key) ->
    case answering(lookup(Key)) of
        {_, Unit, {foreign, _, _, Function, Arity}} ->
            {Unit, Function, Arity, {[], [QualifiedName]}};
        none ->
            none
    end;
spawnable(Key) ->
    case answering([Row || {_, _, {function, _, _, _}} = Row <- lookup(Key)]) of
        {_, Unit, {function, Function, Arity, Reach}} -> {Unit, Function, Arity, Reach};
        none -> none
    end.

%% A top-level binding's value by its identity, in the run in progress
%% (§8.5, §11.2): the value the latest loaded of the units that hold it
%% and whose initializers have run gave it, where that unit has one;
%% absent where no unit that holds it has been initialized, or where a
%% binding before it faulted; none where no unit of this node holds it.
-spec value({[atom()], binary()}) -> {value, term()} | absent | none.
value({QualifiedName, Hash}) ->
    case lookup({binding, QualifiedName, Hash}) of
        [] ->
            none;
        Rows ->
            case [Row || {_, Unit, _} = Row <- Rows, ern_rt:is_initialized(Unit)] of
                [] ->
                    absent;
                Initialized ->
                    {_, Unit, {binding, Key}} = lists:last(Initialized),
                    ern_rt:binding_value(Unit, Key)
            end
    end.

%% A foreign declaration's implementation by its qualified name, the host's
%% module and function it names (§8.4), in the unit answering/1 takes, or
%% none.
-spec foreign([atom()]) -> {module(), atom()} | none.
foreign(QualifiedName) ->
    case answering(lookup({foreign, QualifiedName})) of
        {_, _, {foreign, HostModule, HostFunction, _, _}} -> {HostModule, HostFunction};
        none -> none
    end.

%% Report §8.7, §11.2: the row, among one identity's, of the unit that
%% answers a peer for it. A node holds one identity in several units where
%% a shell that is a node holds its build's, loaded at its start and never
%% evaluated, beside the units its loads and its reloads brought, each
%% evaluated. A function's code reads its own unit's bindings, so the unit
%% that answers is one whose initializers have run, the latest loaded of
%% them, as the session uses its latest version; where none has run, the
%% latest loaded, since a function whose reach names no binding runs from
%% any unit, and the reach's check (value/1) refuses one that names a
%% binding. The table is a bag, which keeps one key's rows in the order
%% they were inserted, so the last row is the latest unit loaded.
answering([]) ->
    none;
answering(Rows) ->
    case [Row || {_, Unit, _} = Row <- Rows, ern_rt:is_initialized(Unit)] of
        [] -> lists:last(Rows);
        Initialized -> lists:last(Initialized)
    end.

%% Whether a module a foreign declaration names is on this node: loaded, or
%% where the host loads it from, the host's own or a `.beam` of the load
%% path (§11.2).
-spec present(module()) -> boolean().
present(HostModule) ->
    erlang:module_loaded(HostModule) orelse code:which(HostModule) =/= non_existing.

lookup(Key) ->
    try ets:lookup(?TABLE, Key) catch error:badarg -> [] end.

%%
%% The host's limits, report §11.2
%%

%% The lines a load gives of the host's limits: one for each limit the
%% host's use has reached four fifths of, said once in the runtime's life.
-spec nearing() -> [binary()].
nearing() ->
    nearing(counts()).

-spec nearing([count()]) -> [binary()].
nearing(Counts) ->
    ensure(),
    Said = [HostTable || {HostTable, _, _} <- Counts, ets:member(?TABLE, {said, HostTable})],
    Near = nearing(Counts, Said),
    true = ets:insert(?TABLE, [{{said, HostTable}} || HostTable <- Near]),
    [line(HostTable, Entries, Limit) || {HostTable, Entries, Limit} <- Counts,
                                         lists:member(HostTable, Near)].

%% The limits of Counts the host's use has reached four fifths of, but
%% those Said already.
-spec nearing([count()], [host_table()]) -> [host_table()].
nearing(Counts, Said) ->
    [HostTable || {HostTable, Entries, Limit} <- Counts, 5 * Entries >= 4 * Limit,
                  not lists:member(HostTable, Said)].

-spec line(host_table(), non_neg_integer(), pos_integer()) -> binary().
line(HostTable, Entries, Limit) ->
    iolist_to_binary(io_lib:format("the host has used ~B of its ~B ~s, which it never gives back",
                                   [Entries, Limit, text(HostTable)])).

text(module_names) -> "module names";
text(exports) -> "export entries";
text(lambdas) -> "lambdas";
text(atoms) -> "atoms".

%% Each of the host's limits with how much of it the host has used. The
%% atoms the host counts in functions of its own; the module names, the
%% export entries and the lambdas it reports only in its system
%% information, each an index table, as its crash dumps show them, with
%% its `limit` and its `entries`. The information is read once for the
%% three.
-spec counts() -> [count()].
counts() ->
    Information = erlang:system_info(info),
    [indexed(module_names, <<"module_code">>, Information),
     indexed(exports, <<"export_staged_index">>, Information),
     indexed(lambdas, <<"fun_staged_index">>, Information),
     {atoms, erlang:system_info(atom_count), erlang:system_info(atom_limit)}].

indexed(HostTable, Name, Information) ->
    [_, After] = binary:split(Information, <<"=index_table:", Name/binary, "\n">>),
    [Section | _] = binary:split(After, <<"\n=">>),
    Fields = maps:from_list([{Field, Value}
                             || Line <- binary:split(Section, <<"\n">>, [global, trim]),
                                [Field, Value] <- [binary:split(Line, <<": ">>)]]),
    #{<<"entries">> := Entries, <<"limit">> := Limit} = Fields,
    {HostTable, binary_to_integer(Entries), binary_to_integer(Limit)}.

%%
%% The table
%%

%% The table, made at its first use by a process of its own that holds it
%% for the host's life; where two make it at once, the second finds it
%% made.
ensure() ->
    case ets:whereis(?TABLE) of
        undefined -> made();
        _ -> ok
    end.

made() ->
    Caller = erlang:self(),
    {Holder, MonitorRef} = erlang:spawn_monitor(fun() -> hold(Caller) end),
    receive
        {Holder, made} -> erlang:demonitor(MonitorRef, [flush]), ok;
        {'DOWN', MonitorRef, process, Holder, _} -> ok
    end.

%% The holder waits for nothing: the table is its owner's, and lives as
%% long as it does, which is the host's life.
hold(Caller) ->
    try ets:new(?TABLE, [named_table, public, bag, {read_concurrency, true}]) of
        ?TABLE ->
            Caller ! {erlang:self(), made},
            receive after infinity -> ok end
    catch
        error:badarg -> ok
    end.
