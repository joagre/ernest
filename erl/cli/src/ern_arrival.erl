%% Report §8.7, The exchange, §11.1, §11.2: the unit the definitions of one
%% exchange make on the node they arrive at, made by the build's back end
%% from the same forms as a build's (ern_emitter:unit/1), compiled by the
%% host and loaded whole before any of it runs. A node has no checker's
%% environment of the sender's, so what the forms reference outside the
%% unit is linked through the code table (ern_code): a definition of
%% another unit by its hash, to a unit that exports its function (§11.1),
%% a type to the forms the unit that holds it keeps; a binding by its
%% identity, to
%% a unit that holds it with its value, through its getter; and what the
%% standard library and the prelude declare by its name, as the build
%% links it, from the prelude's environment, which holds the library's
%% interfaces (ern_compile:named/2). A foreign declaration of the reach is
%% a function of the unit's own, which calls the host's function the
%% sender's declaration names through §8.4's check at its declared type,
%% as the declaring module does; a foreign function spawned or computed by
%% its name crosses so too, with no definition.
%%
%% The unit is named from the node's pool (name/1), `ern$1`, `ern$2` and
%% on, the first the host holds no unit of from the exchange's count, which
%% grows with the units the node holds, for its life (§11.2), an arrival
%% that fails taking no name; and it names each definition by the name
%% its code frame gave it, as text, which makes no atom here, so that a
%% fault's trace and a spawn site its body writes show the sender's names
%% and lines, `Counter.worker:23`, and a check's cause prints a type as
%% the definition's module writes it, by the module's namespace and
%% shadows the frame gave (§11.5). A type keeps the qualified name its form
%% holds. The unit exports every function it holds (§11.1), since a later
%% exchange's definitions call into it by hash. A binding that crossed as
%% a member of its group is no function of the unit: its value is the
%% node's, read where the node holds it, and the group's other members
%% name it by its identity in place of its position. What the unit records
%% of its definitions is kept in the code table beside its code, so that
%% the node ships them onward as its own (§11.2).
-module(ern_arrival).

-export([received/4, name/1]).

-include_lib("typer/include/ern_canonical.hrl").
-include_lib("emitter/include/ern_unit.hrl").

%% Report §8.7: the definitions Arrived, each of one code frame, verified,
%% dependencies first, and the foreign declarations of the reach, each
%% {Name, HostModule, HostFunction, Scheme, Printing} as the peer gave
%% them, whose modules and functions the node has (ern_peer:reach_lacked/2),
%% made the
%% unit Unit, compiled, loaded and in the code table; or the reason this
%% node could not, in a line, which the spawns that wait are answered with
%% as `Other(text)`. Env is the prelude's environment.
-spec received(atom(), [#definition{}], [{[binary()], binary(), binary(), term(), term()}],
               ern_typecheck:env()) -> ok | {error, binary()}.
received(Unit, Arrived, Foreigns, Env) ->
    try
        case made(Unit, Arrived, Foreigns, Env) of
            {ok, Made, Recorded} -> compiled(Made, Recorded);
            {error, _} = Error -> Error
        end
    catch
        error:{emitter_defect, _, Message} ->
            reason(["its back end could not compile what arrived: ", Message]);
        Class:Reason ->
            reason(["it failed on what arrived, ",
                    io_lib:format("~p:~P", [Class, Reason, 6])])
    end.

%% Report §8.7, §11.2: the first name of the pool, from Next, the host
%% holds no unit of, and the count the next arrival takes from once this
%% one is loaded. A unit is held for the node's life, so the count only
%% grows; a name the host holds a unit of is passed over, since an
%% exchange started again in one host counts from one, as each run of the
%% tests starts one.
-spec name(pos_integer()) -> {atom(), pos_integer()}.
name(Next) ->
    Unit = list_to_atom("ern$" ++ integer_to_list(Next)),
    case erlang:module_loaded(Unit) of
        false -> {Unit, Next + 1};
        true -> name(Next + 1)
    end.

reason(Text) ->
    {error, ern_show:controls(unicode:characters_to_binary(
                                ["this node could not take the code it received: " | Text]),
                              line)}.

%% The unit compiled by the host, loaded by the host's atomic load, one
%% batch, off the code path and without `-on_load`, and in the code table
%% with what it records; and the node says where its loads near a limit of
%% the host's (§11.2).
compiled(#unit{name = Unit} = Made, Recorded) ->
    {Forms, _} = ern_emitter:unit(Made),
    case ern_compile:compiled(Forms, []) of
        {ok, Unit, Beam} ->
            case code:atomic_load([{Unit, atom_to_list(Unit), Beam}]) of
                ok ->
                    ok = ern_code:loaded(Unit, Recorded),
                    ern_cli:say_limits();
                {error, [{_, What} | _]} ->
                    reason(["the host did not load it, ", atom_to_list(What)])
            end;
        {error, [{_, [{_, Compiler, Description} | _]} | _]} ->
            reason(["the host's compiler refused it, ", Compiler:format_error(Description)]);
        {error, _} ->
            reason(["the host's compiler refused it"])
    end.

%%
%% The unit, report §8.7 and §11.1
%%

made(Unit, Arrived, Foreigns, Env) ->
    {Bindings, Definitions} = lists:partition(fun(#definition{kind = Kind}) ->
                                                  Kind =:= binding
                                              end, Arrived),
    case binding_references(Bindings) of
        {error, _} = Error ->
            Error;
        {ok, ByPosition} ->
            Compiled = [compiled_definition(Definition, ByPosition) || Definition <- Definitions],
            ForeignFunctions = [foreign_function(Foreign) || Foreign <- Foreigns],
            case linked(Compiled, ForeignFunctions, Env) of
                {ok, Link, Others} ->
                    {ok, #unit{namespace = [], name = Unit, definitions = Compiled,
                               foreign_functions = ForeignFunctions,
                               exported = [QualifiedName || #definition{kind = function,
                                                                        qualified_name =
                                                                            QualifiedName}
                                                                <- Compiled],
                               reaches = ern_canonical:unit_reaches(Compiled, Others),
                               link = Link, code = true, form_namespace = [],
                               site_namespace = []},
                     #recorded{definitions = Arrived,
                               foreign = [{QualifiedName, Scheme, HostModule, HostFunction,
                                           Printing}
                                          || #foreign_function{qualified_name = QualifiedName,
                                                               scheme = Scheme,
                                                               host_module = HostModule,
                                                               host_function = HostFunction,
                                                               printing = Printing}
                                                 <- ForeignFunctions]}};
                {error, _} = Error ->
                    Error
            end
    end.

%% Report Appendix H, §8.7: each binding that crossed as a member of its
%% group, by its group and its position, as the reference that names it by
%% its identity, its qualified name with its hash, which the node holds
%% with its value, so its atoms are here.
binding_references(Bindings) ->
    try
        {ok, maps:from_list([{{GroupHash, Position},
                              {binding, [binary_to_existing_atom(Segment) || Segment <- Name],
                               Hash}}
                             || #definition{qualified_name = Name, hash = Hash,
                                            group = {GroupHash, Position}} <- Bindings])}
    catch
        error:badarg -> reason(["it names a binding this node does not hold"])
    end.

%% A definition as the back end compiles it: a function by the name its
%% frame gave it, a type by its form's qualified name, and the members of
%% its group that are bindings named by their identities.
compiled_definition(#definition{kind = Kind, form = Form, sourced = Sourced,
                                group = Group} = Definition, ByPosition) ->
    QualifiedName = case Kind of
                        type -> element(2, Form);
                        function -> Definition#definition.qualified_name
                    end,
    Definition#definition{qualified_name = QualifiedName,
                          form = in_group(Form, Group, ByPosition),
                          sourced = in_group(Sourced, Group, ByPosition)}.

in_group(Term, none, _) ->
    Term;
in_group({in_group, Position} = Reference, {GroupHash, _}, ByPosition)
  when is_integer(Position) ->
    maps:get({GroupHash, Position}, ByPosition, Reference);
in_group(Term, Group, ByPosition) when is_tuple(Term) ->
    list_to_tuple(in_group(tuple_to_list(Term), Group, ByPosition));
in_group([Head | Tail], Group, ByPosition) ->
    [in_group(Head, Group, ByPosition) | in_group(Tail, Group, ByPosition)];
in_group(Term, _, _) ->
    Term.

%% Report §8.7, §8.4: a foreign declaration of the reach as a function of
%% the unit's, by its qualified name as the forms that call it write it,
%% where its atoms are here, and else as text, its scheme the declared
%% type the check holds the host's return to, printed in its cause as its
%% module writes it. Its module and function are the node's, whose atoms
%% the reach's check made sure of, so the frame makes none.
foreign_function({Name, HostModule, HostFunction, Scheme, Printing}) ->
    QualifiedName = try [binary_to_existing_atom(Segment) || Segment <- Name]
                    catch error:badarg -> Name
                    end,
    #foreign_function{qualified_name = QualifiedName, scheme = Scheme,
                      host_module = binary_to_existing_atom(HostModule),
                      host_function = binary_to_existing_atom(HostFunction), export = true,
                      printing = Printing}.

%%
%% The link, report §8.7 and §11.1
%%

%% Report §8.7, §11.1: where each reference the unit's forms make outside
%% it is, as the code table and the prelude's environment know it; and the
%% reach of each definition of another unit its forms reference by hash,
%% which its own reaches take in. A reference that links to nothing is the
%% reason the reach cannot be taken.
linked(Compiled, ForeignFunctions, Env) ->
    Hashes = maps:from_keys([Hash || #definition{hash = Hash} <- Compiled], true),
    Foreign = [QualifiedName || #foreign_function{qualified_name = QualifiedName}
                                    <- ForeignFunctions],
    Forms = [Form || #definition{form = Form} <- Compiled]
        ++ [Scheme || #foreign_function{scheme = Scheme} <- ForeignFunctions],
    External = [Reference || Reference <- ern_compile:references(Forms),
                             not own(Reference, Hashes, Foreign)],
    try
        {Functions, Others, TypeReferences} =
            lists:foldl(fun(Reference, Acc) -> external(Reference, Acc, Env) end,
                        {#{}, #{}, []}, External),
        Types = types(TypeReferences, #{}, {Hashes, #{}}, Env),
        {ok, #link{functions = Functions, types = Types,
                   printing = ern_types:printing(ern_typecheck:type_state(Env))},
         Others}
    catch
        throw:{unlinked, Text} -> reason(Text)
    end.

own({hash, Hash}, Hashes, _) -> is_map_key(Hash, Hashes);
own({foreign, QualifiedName, _}, _, Foreign) -> lists:member(QualifiedName, Foreign);
own(_, _, _) -> false.

%% One reference outside the unit linked: a function or a binding into
%% Functions, a type among the type references, and a function's reach
%% among Others.
external({hash, Hash} = Reference, {Functions, Others, Types}, _Env) ->
    case ern_code:linkable(Hash) of
        {type, _} ->
            {Functions, Others#{Hash => {[], []}}, [Reference | Types]};
        {function, Unit, Function, Arity, Reach} ->
            {Functions#{Reference => #linked{unit = Unit, function = Function, arity = Arity,
                                             identity = Hash}},
             Others#{Hash => Reach}, Types};
        none ->
            throw({unlinked, ["it references a definition this node does not hold, ",
                              binary:encode_hex(Hash, lowercase)]})
    end;
external({binding, QualifiedName, Hash} = Reference, {Functions, Others, Types}, _Env) ->
    case ern_code:valued(Reference) of
        {Unit, Getter} ->
            {Functions#{Reference => #linked{unit = Unit, function = Getter, arity = 0,
                                             kind = value, identity = Hash}},
             Others, Types};
        none ->
            throw({unlinked, ["the binding ", ern_namespace:text(QualifiedName),
                              " has no value here"]})
    end;
external({named, QualifiedName} = Reference, {Functions, Others, Types}, Env) ->
    case ern_typecheck:described_type(QualifiedName, Env) of
        undefined ->
            Linked = maps:from_list([{Reference, Named}
                                     || Named <- ern_compile:named(Reference, Env)]),
            {maps:merge(Functions, Linked), Others, Types};
        _ ->
            {Functions, Others, [Reference | Types]}
    end;
external({foreign, QualifiedName, _}, _, _) ->
    throw({unlinked, ["it calls a foreign function its reach did not declare, ",
                      ern_namespace:text(QualifiedName)]}).

%% Report §8.4, §11.5: each type of References with its name and its
%% constructors as its form writes them, a program's from the forms the
%% unit that holds it keeps, the library's and the prelude's from the
%% prelude's environment, and those its constructors name, each once,
%% which the descriptors read; a type of the unit's own the back end reads
%% from its form. Own holds the unit's hashes and the forms of each unit
%% read.
types([], Types, _Own, _Env) ->
    Types;
types([Reference | References], Types, Own, Env) when is_map_key(Reference, Types) ->
    types(References, Types, Own, Env);
types([{named, QualifiedName} = Reference | References], Types, Own, Env) ->
    case ern_canonical:declared_type(QualifiedName, Env, [], []) of
        foreign ->
            types(References, Types#{Reference => {QualifiedName, foreign}}, Own, Env);
        {Arity, Constructors, _} ->
            types(inner(Constructors, Env) ++ References,
                  Types#{Reference => {QualifiedName, {Arity, Constructors}}}, Own, Env)
    end;
types([{hash, Hash} | References], Types, {Hashes, _} = Own, Env) when is_map_key(Hash, Hashes) ->
    types(References, Types, Own, Env);
types([{hash, Hash} = Reference | References], Types, {Hashes, Read}, Env) ->
    {{type, QualifiedName, Arity, _, _, Constructors}, Read1} = type_form(Hash, Read),
    types(inner(Constructors, Env) ++ References,
          Types#{Reference => {QualifiedName, {Arity, Constructors}}}, {Hashes, Read1}, Env).

%% The types a type's constructors name, by hash or by name: a
%% constructor's field holds types alone, so a reference by hash is to a
%% type.
inner(Constructors, Env) ->
    [Reference || Reference <- ern_compile:references(Constructors),
                  case Reference of
                      {hash, _} -> true;
                      {named, QualifiedName} ->
                          ern_typecheck:described_type(QualifiedName, Env) =/= undefined;
                      _ -> false
                  end].

%% The form of the type Hash names, from the forms the unit that holds it
%% keeps.
type_form(Hash, Read) ->
    Unit = case ern_code:linkable(Hash) of
               {type, Holder} -> Holder;
               _ -> throw({unlinked, ["it names a type this node does not hold, ",
                                      binary:encode_hex(Hash, lowercase)]})
           end,
    {Definitions, Read1} = case Read of
                               #{Unit := Kept} ->
                                   {Kept, Read};
                               _ ->
                                   Held = case ern_code:forms(Unit) of
                                              {ok, #recorded{definitions = Recorded}} -> Recorded;
                                              none -> []
                                          end,
                                   {Held, Read#{Unit => Held}}
                           end,
    case [Form || #definition{hash = Defined, form = Form} <- Definitions, Defined =:= Hash] of
        [Form | _] -> {Form, Read1};
        [] -> throw({unlinked, ["it names a type whose form this node does not keep, ",
                                binary:encode_hex(Hash, lowercase)]})
    end.
