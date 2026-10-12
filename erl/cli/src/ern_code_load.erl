%% Appendix E.28, report §11.2: Code.load, a compiled module and the modules
%% it uses loaded by a program after its node started, as `ern run` loads a
%% program's (ern_cli:program/2) and the shell's `:load` a compiled module
%% (ern_shell), with their refusals, and its top-level bindings evaluated in
%% the calling process.
%%
%% The module at the path names its root, the directory its namespace
%% descends from (§11.2), and each module it uses is found by its namespace
%% under that root and then on the run's load path (ern_cli:load_path/0),
%% each verified against its hashes (ern_canonical:is_verified/1) and
%% checked against the interfaces it was compiled against and the standard
%% library the node holds. Each becomes a unit of the node's (§11.2): the
%% node's own where the node holds that very code under its Erlang name and
%% each module it uses is its own too; else a unit of its Erlang name,
%% loaded from its file, where the host holds no code of the name and each
%% module it uses is under its own Erlang name; and else a unit made from
%% its forms by the back end (ern_compile:from_compiled/5), of its Erlang
%% name where the host holds none and of a name of its own otherwise,
%% `ern@counter$2`, linked to the units of the modules it uses, as the
%% shell's load makes one beside another of its name. The units are loaded
%% by the host's atomic load, one batch, and enter the code table, so that
%% a spawn finds their definitions and an exchange ships them (§8.7); a
%% unit, once loaded, is held for the node's life (§11.2).
%%
%% The bindings of the units without values, the units the node held and
%% had not evaluated among them, are evaluated in the calling process in
%% §8.5's order, each in a body of mailbox type `Never` (§4.6), the caller
%% the head of a spawn chain of its own meanwhile (ern_rt:rooting/0). One
%% that faults ends the evaluation: every process the evaluation started is
%% killed (ern_rt:kill_started/1), the units the load brought are deleted
%% and purged and the values its evaluation stored go (ern_code:withdrawn/2),
%% as a refused load of the shell's is undone, and the load answers the
%% fault as §8.5 reports it.
-module(ern_code_load).

-export([load/1]).

-include_lib("typer/include/ern_types.hrl").
-include_lib("typer/include/ern_canonical.hrl").

%% A module of the load as its compiled form gives it: its namespace, the
%% file it was read from, its bytes, its interface chunk (ern_interface)
%% and what it records of its definitions.
-record(found, {namespace, file, beam, chunk, recorded}).

%% A module of the load placed: the unit it is on the node, and how the
%% unit comes: held, the node's own; file, its compiled form loaded as it
%% is; forms, made from its forms by the back end.
-record(placed, {found, unit, made}).

%% Appendix E.28: `Right(Unit)`, or `Left` with the load's Io.Error.
-spec load({'Path', binary()}) -> {'Right', 'Unit'} | {'Left', term()}.
load({'Path', Path}) ->
    try
        Found = reach(Path),
        Placed = placed(Found),
        loaded(Placed),
        evaluated(Placed)
    catch
        throw:{refused, Error} -> {'Left', Error}
    end.

-spec refuse(term()) -> no_return().
refuse(Error) ->
    throw({refused, Error}).

%% Appendix E.28: the reason this node gives for a load it could not make,
%% as `Other(text)`.
-spec cannot(#found{}, iodata()) -> no_return().
cannot(#found{namespace = Namespace}, Reason) ->
    refuse({'Other', unicode:characters_to_binary(["this node could not load ",
                                                   ern_namespace:text(Namespace), ": ",
                                                   Reason])}).

%%
%% The reach, report §11.2
%%

%% The module at Path and every module it uses, directly or through
%% another, each once, those it uses before it.
reach(Path) ->
    File = ern_build:absolute(unicode:characters_to_list(Path)),
    #found{namespace = Namespace} = Module = found(File, any),
    Root = root(File, Namespace),
    LoadPath = lists:uniq([Root | ern_cli:load_path()]),
    {Order, _} = with_dependencies(Module, LoadPath, {[], #{Namespace => Module}}),
    Reach = lists:reverse(Order),
    lists:foreach(fun(Found) -> same_interfaces(Found, Reach) end, Reach),
    Reach.

%% Report §11.2: the directory a module's namespace descends from, the
%% file at the path its namespace names under it, each directory between
%% them of §11.1's path shape; a file elsewhere is no `.erc` of its module.
root(File, Namespace) ->
    Root = lists:foldl(fun(_, Dir) -> filename:dirname(Dir) end, File, Namespace),
    Relative = ern_build:module_path(Namespace) ++ ".erc",
    ern_build:relative(File, Root) =:= Relative
        andalso lists:all(fun ern_namespace:is_component/1,
                          filename:split(filename:rootname(Relative)))
        orelse refuse('Invalid'),
    Root.

%% Module's dependencies, each found on the load path and its own
%% dependencies before it, in Order, the last first; Seen by namespace.
with_dependencies(#found{chunk = #{deps := Dependencies}} = Module, LoadPath, {Order, Seen}) ->
    {Order1, Seen1} =
        lists:foldl(fun({Dependency, _}, {AccOrder, AccSeen}) when is_map_key(Dependency,
                                                                              AccSeen) ->
                            {AccOrder, AccSeen};
                       ({Dependency, _}, {AccOrder, AccSeen}) ->
                            Found = found(compiled_file(Dependency, LoadPath), Dependency),
                            with_dependencies(Found, LoadPath,
                                              {AccOrder, AccSeen#{Dependency => Found}})
                    end, {Order, Seen}, Dependencies),
    {[Module | Order1], Seen1}.

%% Report §11.2: a module's compiled form found by its namespace on the
%% load path, the first root that holds it; one the load path lacks is
%% `NotFound`.
compiled_file(Namespace, LoadPath) ->
    Relative = ern_build:module_path(Namespace) ++ ".erc",
    case [Found || Dir <- LoadPath, Found <- [filename:join(Dir, Relative)],
                   filelib:is_regular(Found)] of
        [Found | _] -> Found;
        [] -> refuse('NotFound')
    end.

%% Appendix E.28: a compiled form read, of the namespace Expected or of
%% any: a file of this `ern`, whose interface and forms it can read, which
%% holds that namespace, each of its definitions its hash, and compiled
%% against the standard library the node holds; else `Invalid`. A path
%% that names no file is `NotFound`, and a file the host cannot read its
%% reason (Appendix E.1).
found(File, Expected) ->
    Beam = case file:read_file(File) of
               {ok, Bytes} -> Bytes;
               {error, Error} when Error =:= enoent; Error =:= enotdir -> refuse('NotFound');
               {error, eisdir} -> refuse('Invalid');
               {error, Error} -> refuse(ern_io:host_error(Error, fun file:format_error/1))
           end,
    case {ern_interface:read(Beam), ern_canonical:read(Beam)} of
        {{ok, #{interface := #interface{namespace = Namespace}} = Chunk},
         {ok, #recorded{definitions = Definitions} = Recorded}}
          when Expected =:= any; Expected =:= Namespace ->
            ern_canonical:is_verified(Definitions)
                andalso lists:member(maps:get(stdlib, Chunk, none),
                                     [none, ern_build:stdlib_hash()])
                orelse refuse('Invalid'),
            #found{namespace = Namespace, file = File, beam = Beam, chunk = Chunk,
                   recorded = Recorded};
        _ ->
            refuse('Invalid')
    end.

%% Report §11.2: a module compiled against another interface of a module
%% it uses than the one the load found is `Invalid`, as `ern run` refuses
%% one before anything runs.
same_interfaces(#found{chunk = #{deps := Dependencies}}, Reach) ->
    lists:foreach(fun({Dependency, Hash}) ->
                          [#found{chunk = #{interface := Interface}}] =
                              [Found || #found{namespace = Namespace} = Found <- Reach,
                                        Namespace =:= Dependency],
                          ern_interface:hash(Interface) =:= Hash orelse refuse('Invalid')
                  end, Dependencies).

%%
%% The units, report §11.2
%%

%% Each module of the reach placed as a unit of the node's, in the reach's
%% order, a module's dependencies placed before it.
placed(Reach) ->
    {Placed, _} = lists:mapfoldl(fun place/2, #{}, Reach),
    Placed.

%% Units: the unit of each namespace placed so far. A unit made from these
%% very forms by an earlier load, linked to the same units, is taken as
%% the node holds it, under the module's Erlang name or one of its own, so
%% that loading a module again makes no unit (§11.2).
place(#found{namespace = Namespace, beam = Beam, recorded = Recorded,
             chunk = #{deps := Dependencies}} = Found, Units) ->
    Plain = ern_namespace:erlang_module(Namespace),
    DependencyUnits = [maps:get(Dependency, Units) || {Dependency, _} <- Dependencies],
    Linked = DependencyUnits =:= [ern_namespace:erlang_module(Dependency)
                                  || {Dependency, _} <- Dependencies],
    Made = fun(Unit) ->
                   ern_code:forms(Unit) =:= {ok, Recorded}
                       andalso dependencies(Unit) =:= DependencyUnits
           end,
    Placed = case {Linked andalso ern_code:is_held(Plain, Beam), ern_code:is_free(Plain)} of
                 {true, _} ->
                     #placed{found = Found, unit = Plain, made = held};
                 {false, true} when Linked ->
                     #placed{found = Found, unit = Plain, made = file};
                 {false, true} ->
                     #placed{found = Found, unit = Plain, made = forms};
                 {false, false} ->
                     case erlang:module_loaded(Plain) andalso Made(Plain) of
                         true ->
                             #placed{found = Found, unit = Plain, made = held};
                         false ->
                             case ern_code:unit_beside(Namespace, Made) of
                                 {held, Unit} -> #placed{found = Found, unit = Unit, made = held};
                                 {free, Unit} -> #placed{found = Found, unit = Unit, made = forms};
                                 {error, Text} -> cannot(Found, Text)
                             end
                     end
             end,
    {Placed, Units#{Namespace => Placed#placed.unit}}.

%% Report §8.5: the units a unit's code depends on, which its '$deps'/0
%% lists, none where it lists none.
dependencies(Unit) ->
    case erlang:function_exported(Unit, '$deps', 0) of
        true -> Unit:'$deps'();
        false -> []
    end.

%% The units the node did not hold, made, loaded whole by the host's
%% atomic load, without `-on_load`, and in the code table with what they
%% record; and the node says where its loads near a limit of the host's
%% (§11.2). A load the host refuses, a count of its own it would pass
%% among the reasons, loads none of them.
loaded(Placed) ->
    Made = [made(Unit, Placed) || #placed{made = How} = Unit <- Placed, How =/= held],
    case Made of
        [] ->
            ok;
        _ ->
            case code:atomic_load([{Unit, Name, Beam} || {Unit, Name, Beam, _} <- Made]) of
                ok ->
                    lists:foreach(fun({Unit, _, _, file}) -> ern_code:loaded(Unit);
                                     ({Unit, _, _, Recorded}) -> ern_code:loaded(Unit, Recorded)
                                  end, Made),
                    ern_cli:say_limits();
                {error, [{Unit, What} | _]} ->
                    #placed{found = Found} = lists:keyfind(Unit, #placed.unit, Placed),
                    cannot(Found, ["the host did not load it, ", io_lib:format("~p", [What])])
            end
    end.

%% A unit to load: its name, the file name the host gives it, its code, and
%% file where the code table reads its forms from that file, or what it
%% records, kept beside its code. A unit made from its forms is linked
%% through the interfaces of the modules of the load and the standard
%% library's, each module's code calling the unit it was placed as.
made(#placed{found = #found{file = File, beam = Beam}, unit = Unit, made = file}, _) ->
    {Unit, File, Beam, file};
made(#placed{found = #found{beam = Beam} = Found, unit = Unit, made = forms}, Placed) ->
    Interfaces = [Interface || #placed{found = #found{chunk = #{interface := Interface}}}
                                   <- Placed]
        ++ ern_prelude:stdlib_interfaces(),
    Units = #{Namespace => Placed1
              || #placed{found = #found{namespace = Namespace}, unit = Placed1} <- Placed,
                 Placed1 =/= ern_namespace:erlang_module(Namespace)},
    Made = try ern_compile:from_compiled(Beam, Unit, Interfaces, ern_typecheck:prelude_env(),
                                         Units) of
               {ok, Compiled} -> Compiled
           catch
               error:Reason -> cannot(Found, ["its back end could not compile it, ",
                                              io_lib:format("~P", [Reason, 6])])
           end,
    {ok, Recorded} = ern_canonical:read(Made),
    {Unit, atom_to_list(Unit), Made, Recorded}.

%%
%% The bindings, report §8.5
%%

%% Report §8.5, Appendix E.28: the bindings of each unit of the load whose
%% bindings have no value, those of the units it uses first, evaluated in
%% the calling process, under a spawn chain of its own; `Right(Unit)`, or
%% the fault of one, the load undone (withdrawn/3).
evaluated(Placed) ->
    Units = [Unit || #placed{unit = Unit} <- Placed],
    Evaluated = [Unit || Unit <- ern_rt:ordered(Units), erlang:function_exported(Unit, '$init', 0),
                         not ern_rt:is_initialized(Unit)],
    {Mark, Root} = ern_rt:rooting(),
    Site = ern_rt:site(),
    Outcome = try lists:foreach(fun(Unit) -> Unit:'$init'() end, Evaluated) of
                  ok -> ok
              catch
                  Class:Error:Stack ->
                      %% report §8.5: the binding that faulted, by its site
                      {fault, ern_rt:site(), element(3, ern_rt:fault_exit_reason(Class, Error,
                                                                               Stack))}
              end,
    _ = ern_rt:initializing(Site),
    case Outcome of
        ok ->
            lists:foreach(fun ern_rt:initialized/1, Evaluated),
            ern_rt:rooted(Mark, Root),
            {'Right', 'Unit'};
        {fault, BindingSite, Cause} ->
            withdrawn(Placed, Evaluated, Mark),
            ern_rt:rooted(Mark, Root),
            refuse({'Other', <<BindingSite/binary, " faulted: ", Cause/binary>>})
    end.

%% Report §11.2, Appendix E.28: a load whose binding faulted undone: every
%% process its evaluation started killed, the units it brought deleted and
%% purged, and the values of the units it evaluated gone, a unit the node
%% held and had not evaluated keeping its code; the keys read while the
%% code is current.
withdrawn(Placed, Evaluated, Mark) ->
    Keys = lists:append([ern_code:binding_keys(Unit) || Unit <- Evaluated]),
    _ = ern_rt:kill_started([Mark]),
    ern_code:withdrawn([Unit || #placed{unit = Unit, made = How} <- Placed, How =/= held], Keys).
