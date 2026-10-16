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
%% its value is kept under (§8.5), each foreign declaration's
%% implementation and function by its qualified name as text, as a spawn
%% frame names it, and, in the unit's own row, the units its code calls. A
%% unit loaded again with other code replaces its rows, and one unloaded
%% takes them with it, so that the table holds what the host holds and no
%% more (docs/memory.md).
%%
%% Report §11.2: the canonical forms of a unit's definitions are kept
%% beside its code, with their names, the lines of their source and the
%% unit's foreign declarations (#recorded{}), which the exchange ships
%% onward (§8.7, forms/1), in a row of the unit's own here, taken with its
%% other rows, so that the forms live as long as the code they describe:
%% a unit no file holds, a load's or an input's of the shell, or an
%% exchange's, has them written as it loads (loaded/3); a unit the build
%% compiled has them in the `.erc` it was loaded from, which is read once,
%% at the first request that needs them, and kept from then on.
%%
%% Report §11.2: the host's counts of what a runtime loads, which the
%% runtime says it nears, are kept as sums of what each unit it loads
%% adds, from the host's own read at the first load, in a second table
%% (nearing/0).
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

-export([loaded/1, loaded/2, loaded/3, unloaded/1, spawnable/1, holders/1, linkable/1, valued/1,
         forms/1, called/1, absent_binding/1, absent_binding/2, foreign/2, declared/1, declared/2,
         present/1, function/2, function_text/2, is_free/1, is_held/2, fresh_unit/1, unit_beside/2,
         placement/4, running/1, hashes/1, binding_keys/1, nearing/0, nearing/1, nearing/2, line/3,
         counts/0]).

-include_lib("checker/include/ern_canonical.hrl").

-export_type([host_table/0, reach/0]).

%% Report §8.6: Code.hashes reads its file through the host's file server,
%% so the emitter counts it as foreign code while it runs; Code.running
%% reads the host's stacks and waits on no process.
-waits([hashes/1]).

-define(TABLE, ern_code).
%% Report §11.2: the sums of the host's counts, one row a count.
-define(SUMS, ern_code_sums).

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
%% or a foreign function's, holds nothing here. The unit's own row holds
%% its code's digest, the keys of its rows, and the units its code calls,
%% none for a unit whose '$code'/0 lists none, as a shell's holder of
%% values. What the unit adds to the host's counts is added to their sums
%% (summed/1), read from its compiled form. A unit the host loaded from the
%% code path, as the runtime loads one on demand, its compiled form read
%% from the path.
-spec loaded(module()) -> ok.
loaded(Unit) ->
    case erlang:function_exported(Unit, '$code', 0) andalso code:get_object_code(Unit) of
        {Unit, Beam, _} -> loaded(Unit, Beam);
        _ -> ok
    end.

%% The same, for a unit the host loaded from its compiled form Beam, which
%% a file holds: the build's, whose forms the file holds.
-spec loaded(module(), binary()) -> ok.
loaded(Unit, Beam) ->
    loaded(Unit, Beam, none).

%% Report §11.2: the same, for a unit no file holds, with what its
%% compiled form records of its definitions, their canonical forms among
%% it, which is kept in a row of its own.
-spec loaded(module(), binary(), #recorded{} | none) -> ok.
loaded(Unit, Beam, Recorded) ->
    case erlang:function_exported(Unit, '$code', 0) of
        true -> fill(Unit, Unit:module_info(md5), Beam, Recorded);
        false -> ok
    end.

fill(Unit, Md5, Beam, Recorded) ->
    ensure(),
    case ets:lookup(?TABLE, {unit, Unit}) of
        [{_, _, {Md5, _, _}}] ->
            ok;
        Previous ->
            forget(Unit, Previous),
            Code = Unit:'$code'(),
            Rows = lists:append([rows(Unit, QualifiedName, Held)
                                 || {QualifiedName, Held} <- Code])
                ++ [{{forms, Unit}, Unit, Recorded} || Recorded =/= none]
                ++ declared_rows(Unit, Recorded),
            Keys = lists:usort([Key || {Key, _, _} <- Rows]),
            Calls = lists:append([Units || {_, {calls, Units}} <- Code]),
            true = ets:insert(?TABLE, [{{unit, Unit}, Unit, {Md5, Keys, Calls}} | Rows]),
            summed(Beam)
    end.

%% Report §8.7, §11.2: each foreign declaration a unit no file holds
%% records, by its qualified name as text, which declared/1,2 read: an
%% arrival's every one, those it linked to a fault among them, which no
%% other row names (ern_arrival).
declared_rows(_Unit, none) ->
    [];
declared_rows(Unit, #recorded{foreign = Foreign}) ->
    [{{declared, texts(QualifiedName)}, Unit, Declaration}
     || {QualifiedName, _, _, _, _} = Declaration <- Foreign].

%% A unit's rows for one of its declarations: a definition by its identity,
%% a lambda or a local function a spawn on a peer starts by its identity,
%% and a foreign declaration, which has no identity, by its qualified name
%% (Appendix H) as text, as a peer's frame and an exchange's unit name it,
%% whatever atoms the node has (§8.7).
rows(Unit, _, {function, Hash, Function, Arity, Reach}) ->
    [{{hash, Hash}, Unit, {function, Function, Arity, Reach}}];
rows(Unit, _, {lambda, Hash, Position, Function, Arity, Reach}) ->
    [{{lambda, Hash, Position}, Unit, {function, Function, Arity, Reach}}];
rows(Unit, QualifiedName, {binding, Hash, Key}) ->
    [{{binding, QualifiedName, Hash}, Unit, {binding, Key}}];
rows(Unit, _, {type, Hash}) ->
    [{{hash, Hash}, Unit, type}];
rows(Unit, QualifiedName, {foreign, HostModule, HostFunction, Function, Arity}) ->
    [{{foreign, texts(QualifiedName)}, Unit,
      {foreign, HostModule, HostFunction, Function, Arity}}];
rows(_, _, {calls, _}) ->
    [].

%% Report §8.7: a unit unloaded, its rows gone with it.
-spec unloaded(module()) -> ok.
unloaded(Unit) ->
    forget(Unit, lookup({unit, Unit})).

%% The rows of a unit as the table holds them, each found by its key and
%% taken whole, since a key may name another unit's row beside it.
forget(Unit, UnitRows) ->
    [true = ets:delete_object(?TABLE, Row)
     || {_, _, {_, Keys, _}} <- UnitRows, Key <- Keys,
        {_, Holder, _} = Row <- ets:lookup(?TABLE, Key), Holder =:= Unit],
    [true = ets:delete_object(?TABLE, UnitRow) || UnitRow <- UnitRows],
    ok.

%%
%% The lookups, report §8.7
%%

%% Report §8.7: what a spawn on a peer names, by its identity: a function by
%% its hash, a lambda or a local function by its definition's hash and its
%% position, or a foreign function by its qualified name, its segments
%% atoms or text; the unit and the function that run it, its arity, which
%% is how many values it captured, and its reach, the bindings and the
%% foreign declarations it names, or none where no unit of this node holds
%% it. Where units hold it, the one that runs it is answering/1's.
-spec spawnable({hash, binary()} | {lambda, binary(), pos_integer()}
                | {foreign, [atom() | binary()]}) ->
          {module(), atom(), arity(), reach()} | none.
spawnable({foreign, QualifiedName}) ->
    case answering(lookup({foreign, texts(QualifiedName)})) of
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

%% Report §8.7: the units that hold an identity, a function's or a type's
%% by `{hash, Hash}` or a binding's by `{binding, QualifiedName, Hash}`, in
%% the order they were loaded; none where this node holds it nowhere.
-spec holders({hash, binary()} | {binding, [atom()], binary()}) -> [module()].
holders(Key) ->
    lists:uniq([Unit || {_, Unit, _} <- lookup(Key)]).

%% Report §8.7, §11.1: a definition of this node that another unit's code
%% can reach by its hash: a type, which has no function, in the first unit
%% loaded that holds it, or a function in a unit that exports it, the one
%% whose initializers have run, the latest loaded, as a peer's spawn is
%% answered (answering/1), with its reach; none where no unit holds it so.
%% A build's unit exports the functions its module exports, and an
%% exchange's every function it holds (§11.1), so a definition a unit
%% holds unexported is no definition another unit's code can call: a
%% peer's exchange counts it lacked and receives it (§8.7).
-spec linkable(binary()) -> {type, module()} | {function, module(), atom(), arity(), reach()}
                                | none.
linkable(Hash) ->
    Rows = lookup({hash, Hash}),
    case [Unit || {_, Unit, type} <- Rows] of
        [Unit | _] ->
            {type, Unit};
        [] ->
            Exported = [Row || {_, Unit, {function, Function, Arity, _}} = Row <- Rows,
                               erlang:function_exported(Unit, Function, Arity)],
            case answering(Exported) of
                {_, Unit, {function, Function, Arity, Reach}} ->
                    {function, Unit, Function, Arity, Reach};
                none ->
                    none
            end
    end.

%% Report §8.7, §11.1: a top-level binding by its identity, as a unit an
%% exchange makes reads it: the unit that holds it with its value in the
%% run in progress, the latest loaded of those, and its getter, which
%% every unit exports (ern_emitter); none where no unit holds it with its
%% value, which the exchange's `NotLoaded` answers first.
-spec valued({binding, [atom()], binary()}) -> {module(), atom()} | none.
valued(Key) ->
    case [{Unit, Getter} || {_, Unit, {binding, {_, Getter} = Kept}} <- lookup(Key),
                            ern_rt:binding_value(Unit, Kept) =/= absent] of
        [] -> none;
        Valued -> lists:last(Valued)
    end.

%% Report §11.2, §8.7: what the unit Unit's compiled form records of its
%% definitions (#recorded{}): what is kept beside its code, or what the
%% `.erc` the host loaded it from holds, read as it is asked for, where the
%% file holds the unit's code still; none where neither is there, a file
%% changed or gone among the ways, as a build written under a running node
%% changes it, so that a unit is never described by forms its code was not
%% compiled from.
-spec forms(module()) -> {ok, #recorded{}} | none.
forms(Unit) ->
    case lookup({forms, Unit}) of
        [{_, _, Recorded}] ->
            {ok, Recorded};
        [] ->
            File = code:which(Unit),
            case is_list(File) andalso file:read_file(File) of
                {ok, Bytes} ->
                    case holds_code(Unit, Bytes) andalso ern_canonical:read(Bytes) of
                        {ok, Recorded} -> {ok, kept(Unit, Recorded)};
                        _ -> none
                    end;
                _ ->
                    none
            end
    end.

%% Whether Bytes, a file's, are the code of the loaded Unit, as the host
%% digests it.
holds_code(Unit, Bytes) ->
    case beam_lib:md5(Bytes) of
        {ok, {_, Md5}} -> erlang:module_loaded(Unit) andalso Unit:module_info(md5) =:= Md5;
        {error, _, _} -> false
    end.

%% Report §11.2: a build's unit's forms, read from its `.erc` at the first
%% request that needs them, kept in a row of the unit's own from then on,
%% as every other unit's are, the row among the keys its other rows go
%% with (forget/2), so that a request never reads the file again; the
%% forms of all the units a build's requests reach are held so for the
%% node's life, as their units are (docs/memory.md). A module the table
%% holds no unit of keeps nothing.
kept(Unit, Recorded) ->
    case lookup({unit, Unit}) of
        [{_, _, {Md5, Keys, Calls}} = UnitRow] ->
            true = ets:insert(?TABLE, {{forms, Unit}, Unit, Recorded}),
            true = ets:delete_object(?TABLE, UnitRow),
            true = ets:insert(?TABLE, {{unit, Unit}, Unit,
                                       {Md5, lists:usort([{forms, Unit} | Keys]), Calls}});
        _ ->
            ok
    end,
    Recorded.

%% Report §8.7, §11.2: the units the code of Unit calls, Unit among them:
%% those its row names (loaded/1), and those theirs name, each once. A
%% binding or a foreign declaration a function's reach names is read in
%% one of them, the unit of its module the calling code was compiled
%% against, which is not always the latest a node holds: a shell's build
%% calls its own units, though the session has loaded another version.
-spec called(module()) -> #{module() => true}.
called(Unit) ->
    called([Unit], #{}).

called([], Called) ->
    Called;
called([Unit | Units], Called) when is_map_key(Unit, Called) ->
    called(Units, Called);
called([Unit | Units], Called) ->
    Calls = case lookup({unit, Unit}) of
                [{_, _, {_, _, UnitCalls}}] -> UnitCalls;
                [] -> []
            end,
    called(Calls ++ Units, Called#{Unit => true}).

%% Report §8.7: the first of a reach's bindings, each by its identity,
%% without its value in the run in progress in every unit that holds it,
%% or none: what a peer that lacks a function asks of the bindings its
%% reach names before any of its code crosses (§8.7, The exchange), where
%% no unit of this node runs the function yet.
-spec absent_binding([{[atom()], binary()}]) -> {[atom()], binary()} | none.
absent_binding(Bindings) ->
    case [Binding || {QualifiedName, Hash} = Binding <- Bindings,
                     not lists:any(fun({_, Holder, {binding, Key}}) ->
                                           ern_rt:binding_value(Holder, Key) =/= absent
                                   end, lookup({binding, QualifiedName, Hash}))] of
        [] -> none;
        [Absent | _] -> Absent
    end.

%% Report §8.7, §11.2: the first of a reach's bindings, each by its
%% identity, without its value in the run in progress as the code of Unit
%% reads it, or none. It is read in the units Unit's code calls (called/1)
%% that hold it, and has its value where each of them has been initialized
%% and gave it one (§8.5); one no such unit holds has none here. Nothing is
%% initialized because a peer asked.
-spec absent_binding(module(), [{[atom()], binary()}]) -> {[atom()], binary()} | none.
absent_binding(_Unit, []) ->
    none;
absent_binding(Unit, Bindings) ->
    Called = called(Unit),
    case [Binding || Binding <- Bindings, not has_value(Binding, Called)] of
        [] -> none;
        [Absent | _] -> Absent
    end.

has_value({QualifiedName, Hash}, Called) ->
    case [Row || {_, Holder, _} = Row <- lookup({binding, QualifiedName, Hash}),
                 is_map_key(Holder, Called)] of
        [] -> false;
        Read -> lists:all(fun({_, Holder, {binding, Key}}) ->
                                  ern_rt:binding_value(Holder, Key) =/= absent
                          end, Read)
    end.

%% A foreign declaration's implementations by its qualified name, its
%% segments atoms or text, each the unit of Called that holds it
%% (called/1) with the host's module and function it names (§8.4); none
%% where none of them does.
-spec foreign(#{module() => true}, [atom() | binary()]) -> [{module(), module(), atom()}].
foreign(Called, QualifiedName) ->
    [{Holder, HostModule, HostFunction}
     || {_, Holder, {foreign, HostModule, HostFunction, _, _}}
            <- lookup({foreign, texts(QualifiedName)}),
        is_map_key(Holder, Called)].

%% Report §8.7, §11.2: the declarations of a foreign function by its
%% qualified name, its segments atoms or text, that the units this node
%% keeps a record of record, each with the unit, {QualifiedName, Scheme,
%% HostModule, HostFunction, Printing}, the module and the function atoms,
%% or text where the node had no atom of them as the unit's code arrived
%% and linked the call to a fault (ern_arrival), in the order the units
%% were loaded. A unit a file holds has none here: its code holds every
%% declaration it records, which foreign/2 finds.
-spec declared([atom() | binary()]) ->
          [{module(), {[atom() | binary()], term(), atom() | binary(), atom() | binary(),
                       term()}}].
declared(QualifiedName) ->
    [{Holder, Declaration} || {_, Holder, Declaration} <- lookup({declared, texts(QualifiedName)})].

%% The same, of the units of Called (called/1).
-spec declared(#{module() => true}, [atom() | binary()]) ->
          [{module(), {[atom() | binary()], term(), atom() | binary(), atom() | binary(),
                       term()}}].
declared(Called, QualifiedName) ->
    [Declared || {Holder, _} = Declared <- declared(QualifiedName), is_map_key(Holder, Called)].

%% A qualified name as text, which a peer gives and atoms the node has
%% name alike.
texts(QualifiedName) ->
    [case Segment of
         _ when is_atom(Segment) -> atom_to_binary(Segment);
         _ -> Segment
     end || Segment <- QualifiedName].

%% Report §8.7, §11.2: the row, among one identity's, of the unit that
%% answers a peer for it. A node holds one identity in several units where
%% a shell that is a node holds its build's, loaded at its start and never
%% evaluated, beside the units its loads and its reloads brought, each
%% evaluated. A function's code reads its own unit's bindings, so the unit
%% that answers is one whose initializers have run, the latest loaded of
%% them, as the session uses its latest version; where none has run, the
%% latest loaded, since a function whose reach names no binding runs from
%% any unit, and the reach's check (absent_binding/2) refuses one whose
%% code reads a binding without its value. No other unit is tried where it
%% does. The table is a bag, which keeps one key's rows in the order they
%% were inserted, so the last row is the latest unit loaded.
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
%% A unit's functions by their names, report §11.1 and §11.2
%%

%% Report §11.1: the function of Unit, and its arity, that holds the
%% definition or the foreign function its qualified name names, as the
%% forms write it (Appendix H), which the unit's '$code'/0 lists, a
%% binding's its getter; none where Unit holds none of that name. A unit's
%% functions are named by their position in it (ern_emitter), so every caller
%% from Erlang by a name finds its function here: the entry point, the
%% shell's input and its program, and a library's function the toolchain
%% calls, `Markdown`'s for `ern doc`. A unit an exchange made names its
%% definitions by their names as text (§8.7), which no caller names: a
%% peer's spawn finds its function by its identity (spawnable/1).
-spec function(module(), [atom()]) -> {atom(), arity()} | none.
function(Unit, QualifiedName) ->
    case code:ensure_loaded(Unit) =:= {module, Unit}
         andalso erlang:function_exported(Unit, '$code', 0) of
        true ->
            case [{Function, Arity} || {Named, Held} <- Unit:'$code'(), Named =:= QualifiedName,
                                       {Function, Arity} <- held_function(Held)] of
                [Found | _] -> Found;
                [] -> none
            end;
        false ->
            none
    end.

held_function({function, _, Function, Arity, _}) -> [{Function, Arity}];
held_function({binding, _, {_, Function}}) -> [{Function, 0}];
held_function({foreign, _, _, Function, Arity}) -> [{Function, Arity}];
held_function(_) -> [].

%% Report §11.2: a function of a loaded Unit as a fault's trace and the
%% shell show it, by the name the unit's build gives the definition that
%% holds it, read back from its '$code'/0: a definition's or a foreign
%% function's function, '$3', by its own name, `area` or `Vec.+`; a local
%% function lifted to its own function, '$3.2', by its definition's and its
%% position, `area$2`; the entry a spawn on a peer starts a lambda or a
%% local function by, '$3.2.entry', `area$spawn$2`; and a fun the host
%% names after the function it is written in, `-'$3'/1-fun-0-`, after that
%% function's name, `-area/1-fun-0-`. A unit an exchange made shows each
%% by the name its code frame gave it, as text, the sender's, after no
%% module's namespace, `Counter.worker` (§8.7). None for any other function
%% and for a module that is no unit, which keep the host's names.
-spec function_text(module(), atom()) -> string() | none.
function_text(Unit, Function) ->
    case erlang:module_loaded(Unit) andalso erlang:function_exported(Unit, '$code', 0) of
        true -> named_function(atom_to_list(Function), Unit:'$code'());
        false -> none
    end.

named_function("-" ++ Fun, Code) ->
    %% the host's name of a fun: -Function/Arity-fun-Index-
    case string:split(Fun, "/", trailing) of
        [Enclosing, Rest] ->
            case named_function(Enclosing, Code) of
                none -> none;
                Named -> "-" ++ Named ++ "/" ++ Rest
            end;
        _ ->
            none
    end;
named_function("$" ++ Numbered, Code) ->
    case string:split(Numbered, ".", all) of
        [Number] ->
            declared_name("$" ++ Number, Code);
        [Number, Position] ->
            suffixed(declared_name("$" ++ Number, Code), "$" ++ Position);
        [Number, Position, "entry"] ->
            suffixed(declared_name("$" ++ Number, Code), "$spawn$" ++ Position);
        _ ->
            none
    end;
named_function(_, _) ->
    none.

suffixed(none, _) -> none;
suffixed(Name, Suffix) -> Name ++ Suffix.

%% The name a definition or a foreign function is declared by, its own,
%% after its module's namespace, `area` or `Vec.+`, where the unit holds it
%% in the function Function.
declared_name(Function, Code) ->
    Namespaces = [Namespace || {Namespace, {calls, _}} <- Code],
    case [QualifiedName || {QualifiedName, Held} <- Code, {Held1, _} <- held_function(Held),
                           atom_to_list(Held1) =:= Function] of
        [QualifiedName | _] ->
            Declared = case [Namespace || Namespace <- Namespaces,
                                          lists:prefix(Namespace, QualifiedName)] of
                           [Namespace | _] -> lists:nthtail(length(Namespace), QualifiedName);
                           [] -> tl(QualifiedName)
                       end,
            lists:append(lists:join(".", [ern_namespace:segment_text(Name)
                                          || Name <- Declared]));
        [] ->
            none
    end.

%%
%% A unit's name, report §11.2
%%

%% Report §11.2: whether the host holds no code of a unit's name, current
%% or old.
-spec is_free(module()) -> boolean().
is_free(Unit) ->
    not erlang:module_loaded(Unit) andalso not erlang:check_old_code(Unit).

%% Report §11.2: whether the host holds this very code as the unit's
%% current code.
-spec is_held(module(), binary()) -> boolean().
is_held(Unit, Beam) ->
    {ok, {_, Md5}} = beam_lib:md5(Beam),
    erlang:module_loaded(Unit) andalso Unit:module_info(md5) =:= Md5.

%% Report §11.2: a unit of a name of its own, for a module whose Erlang
%% name the node holds code of, as a reload's version and a compiled module
%% loaded beside another are: the name and `$` and a number,
%% `ern@counter$2`, the first the host holds no code of. The name is
%% measured against the host's limit before it is made an atom (§11.1).
-spec fresh_unit([atom()]) -> {ok, module()} | {error, binary()}.
fresh_unit(Namespace) ->
    case unit_beside(Namespace, fun(_) -> false end) of
        {free, Unit} -> {ok, Unit};
        {error, _} = Error -> Error
    end.

%% Report §11.2, Appendix E.28: the same, where a unit the node holds under
%% one of those names may be the one wanted, as Wanted says of it, a unit an
%% earlier load made from the same forms: the first name, in their order,
%% of a unit Wanted takes, held, or the host holds no code of, free. The
%% names are a module's versions, walked as a fresh name is.
-spec unit_beside([atom()], fun((module()) -> boolean())) ->
          {free, module()} | {held, module()} | {error, binary()}.
unit_beside(Namespace, Wanted) ->
    unit_beside(Namespace, Wanted, 2).

unit_beside(Namespace, Wanted, Number) ->
    Text = ern_namespace:erlang_module_text(Namespace) ++ "$" ++ integer_to_list(Number),
    case length(Text) =< ern_namespace:host_name_limit() of
        true ->
            Unit = list_to_atom(Text),
            case is_free(Unit) of
                true ->
                    {free, Unit};
                false ->
                    case erlang:module_loaded(Unit) andalso Wanted(Unit) of
                        true -> {held, Unit};
                        false -> unit_beside(Namespace, Wanted, Number + 1)
                    end
            end;
        false ->
            What = ["the name of ", ern_namespace:text(Namespace), "'s new unit, `", Text, "`,"],
            {error, unicode:characters_to_binary(
                      ern_namespace:host_name_text(lists:flatten(What), Text))}
    end.

%% Report §8.7, §11.2, Appendix E.28: the unit a module whose compiled form
%% is Beam, which records Recorded, is placed as on this node, and how it
%% comes, Dependencies being each module it uses with the unit placed for
%% it, in the order its compiled form lists them, or `unknown` where none
%% is placed yet. held: the node holds the unit, under the module's Erlang
%% name with this very code and each module it uses under its own, or a
%% unit an earlier load made from these very forms linked to the same
%% units, a refused load's among them, which stays loaded (§11.2), so that
%% a module loaded again, unchanged, makes no unit. file: its compiled form
%% loaded as it is, under its Erlang name, where the host holds no code of
%% the name and each module it uses is under its own Erlang name. forms: a
%% unit made from its forms by the back end, linked to the units of the
%% modules it uses, under its Erlang name where the host holds no code of
%% it, and else under a name of its own, `ern@counter$2` (unit_beside/2).
%% Or the refusal of a name the host does not hold. Code.load places the
%% modules of its reach so (ern_code_load), and the shell the compiled
%% forms it loads (ern_shell).
-spec placement([atom()], binary(), #recorded{}, [{[atom()], module() | unknown}]) ->
          {held | file | forms, module()} | {error, binary()}.
placement(Namespace, Beam, Recorded, Dependencies) ->
    Plain = ern_namespace:erlang_module(Namespace),
    Linked = lists:all(fun({Dependency, Unit}) -> Unit =:= ern_namespace:erlang_module(Dependency)
                       end, Dependencies),
    DependencyUnits = [Unit || {_, Unit} <- Dependencies],
    Made = fun(Unit) ->
                   forms(Unit) =:= {ok, Recorded} andalso dependencies(Unit) =:= DependencyUnits
           end,
    case {Linked andalso is_held(Plain, Beam), is_free(Plain)} of
        {true, _} ->
            {held, Plain};
        {false, true} when Linked ->
            {file, Plain};
        {false, true} ->
            {forms, Plain};
        {false, false} ->
            case erlang:module_loaded(Plain) andalso Made(Plain) of
                true ->
                    {held, Plain};
                false ->
                    case unit_beside(Namespace, Made) of
                        {held, Unit} -> {held, Unit};
                        {free, Unit} -> {forms, Unit};
                        {error, _} = Error -> Error
                    end
            end
    end.

%% Report §8.5: the units a unit's code depends on, which its '$deps'/0
%% lists, none where it lists none.
dependencies(Unit) ->
    case erlang:function_exported(Unit, '$deps', 0) of
        true -> Unit:'$deps'();
        false -> []
    end.

%%
%% Appendix E.28: the Code module's running and hashes
%%

%% Appendix E.28, report §3.11: Code.running, the processes of this node,
%% the system processes excepted (Appendix E.21), whose stack holds a frame
%% of the definition of Hash itself: of the function each unit that holds it
%% runs it by, which its row in the table names (loaded/1), so that a unit
%% the build loaded and one an arrival or a load made of the same definition
%% count alike (§8.7). A lambda's and a local function's frames are their
%% own functions', '$N.P' or a fun, and no definition's. The scan reads each
%% process's stack once, its input being the node's processes.
%%
%% Appendix E.28: the host keeps at most the innermost 64 frames of a
%% stack, which the runtime sets at its start (ern_rt:run_main/3), so a
%% frame beneath them is not seen.
-spec running(binary()) -> [pid()].
running(Hash) ->
    Functions = #{{Unit, Function, Arity} => true
                  || {_, Unit, {function, Function, Arity, _}} <- lookup({hash, Hash})},
    [Pid || map_size(Functions) > 0, Pid <- ern_rt:processes(), runs(Pid, Functions)].

%% Whether Pid's stack holds a frame of one of Functions; a process that
%% has ended holds none.
runs(Pid, Functions) ->
    case erlang:process_info(Pid, current_stacktrace) of
        {current_stacktrace, Frames} ->
            lists:any(fun({ErlangModule, Function, Arity, _}) ->
                              is_map_key({ErlangModule, Function, frame_arity(Arity)}, Functions)
                      end, Frames);
        undefined ->
            false
    end.

%% A frame's arity, or the arguments the host gives in its place.
frame_arity(Arity) when is_integer(Arity) -> Arity;
frame_arity(Arguments) when is_list(Arguments) -> length(Arguments).

%% Appendix E.28: Code.hashes, the definitions the compiled module at the
%% path records (§11.1), each its qualified name as text and its hash, the
%% digest in lowercase hexadecimal, in the order of their forms, which is
%% the order the module declares them; a foreign declaration has no hash
%% and no definition (Appendix H). A path that names no file answers
%% `NotFound`, and a file that is no `.erc` of this `ern`, whose interface
%% or forms are of another format or none, `Invalid`; a file the host
%% cannot read answers the host's reason (Appendix E.1).
-spec hashes({'Path', binary()}) -> {'Right', [{binary(), binary()}]} | {'Left', term()}.
hashes({'Path', Path}) ->
    case file:read_file(Path) of
        {ok, Bytes} ->
            case {ern_interface:read(Bytes), ern_canonical:read(Bytes)} of
                {{ok, _}, {ok, #recorded{definitions = Definitions}}} ->
                    {'Right', [{unicode:characters_to_binary(ern_namespace:text(QualifiedName)),
                                binary:encode_hex(DefinitionHash, lowercase)}
                               || #definition{qualified_name = QualifiedName,
                                              hash = DefinitionHash} <- Definitions]};
                _ ->
                    {'Left', 'Invalid'}
            end;
        {error, Error} ->
            {'Left', read_error(Error)}
    end.

%% Appendix E.28, E.1: a path that names no file, one whose directory does
%% not exist or is a file among them, is `NotFound`; any other reason the
%% host gives is its Io.Error.
-spec read_error(atom()) -> term().
read_error(enotdir) -> 'NotFound';
read_error(eisdir) -> 'Invalid';
read_error(Error) -> ern_io:host_error(Error, fun file:format_error/1).

%% Report §8.5, §11.2: the keys a unit's top-level bindings keep their
%% values under, as its '$code'/0 lists them; none for a module that is no
%% unit.
-spec binding_keys(module()) -> [term()].
binding_keys(Unit) ->
    case erlang:function_exported(Unit, '$code', 0) of
        true -> [Key || {_, {binding, _, Key}} <- Unit:'$code'()];
        false -> []
    end.

%%
%% The host's limits, report §11.2
%%

%% Report §11.2: the lines a load gives of the host's limits, one for each
%% limit the host's use has reached four fifths of, said once in the
%% runtime's life. The host gives its counts of module names, export
%% entries and lambdas only in its system information, a text of its whole
%% state that costs more than a small unit's compile (counts/0), so the
%% runtime does not read it at each load: it keeps a sum of each, from the
%% host's own read at the first load, adding what each unit it loads adds
%% (summed/1), and reads the atoms, which the host counts cheaply, at each
%% load. Where a sum, or the atoms, reach four fifths of a limit, it reads
%% the host's counts, says the line of each the host's own count has
%% brought there, so that no line is said on a sum, and takes the host's
%% counts as its sums from then on; a count said is compared no more. A
%% sum leaves out what the runtime did not load, a host module loaded on
%% its own among it, so a line can come a little late, never early.
-spec nearing() -> [binary()].
nearing() ->
    ensure(),
    confirmed(estimated(), fun counts/0).

%% The same, the host's counts being Counts.
-spec nearing([count()]) -> [binary()].
nearing(Counts) ->
    ensure(),
    confirmed(Counts, fun() -> Counts end).

%% The lines of the counts the host's own, read by Read, has brought to
%% four fifths, where Estimated brings one there not said before.
confirmed(Estimated, Read) ->
    Said = [HostTable || {HostTable, _, _} <- Estimated, ets:member(?TABLE, {said, HostTable})],
    case nearing(Estimated, Said) of
        [] ->
            [];
        _ ->
            Counts = Read(),
            rebased(Counts),
            Near = nearing(Counts, Said),
            true = ets:insert(?TABLE, [{{said, HostTable}} || HostTable <- Near]),
            [line(HostTable, Entries, Limit) || {HostTable, Entries, Limit} <- Counts,
                                                 lists:member(HostTable, Near)]
    end.

%% The limits of Counts the host's use has reached four fifths of, but
%% those Said already.
-spec nearing([count()], [host_table()]) -> [host_table()].
nearing(Counts, Said) ->
    [HostTable || {HostTable, Entries, Limit} <- Counts, 5 * Entries >= 4 * Limit,
                  not lists:member(HostTable, Said)].

%% The sums of the host's counts the runtime keeps, none before the first
%% load, and the host's count of its atoms.
estimated() ->
    [Sum || HostTable <- [module_names, exports, lambdas], Sum <- ets:lookup(?SUMS, HostTable)]
        ++ [{atoms, erlang:system_info(atom_count), erlang:system_info(atom_limit)}].

%% Report §11.2: what a unit adds to the host's counts, at most, added to
%% their sums: a module name; an export entry for each function its export
%% table names and each its import table names, which the host makes where
%% none is yet; and a function entry for each lambda its table of lambdas
%% names, each table's count the first word of its chunk. The sums are the
%% host's own counts at the first load, which counts that unit.
summed(Beam) ->
    case ets:member(?SUMS, module_names) of
        false ->
            rebased(counts());
        true ->
            {ok, {_, Chunks}} = beam_lib:chunks(Beam, ["ExpT", "ImpT", "FunT"],
                                                [allow_missing_chunks]),
            [Exports, Imports, Lambdas] = [case Chunk of
                                               <<Count:32, _/binary>> -> Count;
                                               missing_chunk -> 0
                                           end || {_, Chunk} <- Chunks],
            _ = [ets:update_counter(?SUMS, HostTable, {2, Added})
                 || {HostTable, Added} <- [{module_names, 1}, {exports, Exports + Imports},
                                           {lambdas, Lambdas}]],
            ok
    end.

%% The host's counts taken as the sums.
rebased(Counts) ->
    true = ets:insert(?SUMS, [Count || {HostTable, _, _} = Count <- Counts, HostTable =/= atoms]),
    ok.

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

%% The holder waits for nothing: the tables are its owner's, and live as
%% long as it does, which is the host's life; the sums' first, so that the
%% code table's being there says both are.
hold(Caller) ->
    try
        ?SUMS = ets:new(?SUMS, [named_table, public, set, {write_concurrency, true}]),
        ets:new(?TABLE, [named_table, public, bag, {read_concurrency, true}])
    of
        ?TABLE ->
            Caller ! {erlang:self(), made},
            receive after infinity -> ok end
    catch
        error:badarg -> ok
    end.
