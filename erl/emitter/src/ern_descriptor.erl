%% Report §8.4, Appendix E.1: the descriptor of a type, the runtime's
%% reading of it: what the foreign boundary checks a value against, what a
%% proxy exposes an address with, and what `Io.show`, `Io.debug` and the
%% shell print a value by, one printer (§11.2). A recursive type refers
%% back to its mu.
-module(ern_descriptor).

-export([describe/3, describe/4, cause/3]).

-export_type([descriptor/0]).

-include_lib("typer/include/ern_types.hrl").

%% A type as this module describes it, which `Io.show`, `Io.debug` and the
%% shell print a value by (ern_show) and the emitter builds the runtime's
%% form of for the boundary (ern_boundary): a function's is tagged
%% `function` here, and the built one `'fun'`, since the two carry other
%% parts. mu binds Id for each `{ref, Id}` inside it, which is how a
%% recursive type is described once; a hole stands for a descriptor a
%% requirement passes in; an abstract type seen from outside its module is
%% wrapped, and a named constructor carries its fields' names, both for
%% printing.
-type descriptor() :: any | int | float | bool | char | string | bytes | process | never
                    | foreign
                    | {hole, integer()} | {ref, pos_integer()}
                    | {tuple, [descriptor()]} | {list, descriptor()} | {set, descriptor()}
                    | {map, descriptor(), descriptor()}
                    | {address, descriptor(), binary()} | {reply, descriptor(), binary()}
                    | {function, non_neg_integer(), descriptor(), binary(), [descriptor()],
                       [binary()]}
                    | {con, [{atom(), [descriptor()]} | {atom(), [descriptor()], [atom()]}]}
                    | {mu, pos_integer(), descriptor()} | {abstract, descriptor()}.

%% The type's names, the module it is seen from, and the type variables
%% whose descriptors a requirement passes in, each a hole.
-record(scope, {env, namespace = [], holes = []}).

%% The descriptor of Type, whose names Env knows, seen from the module
%% Namespace: from any other, an abstract type's representation is not
%% the program's to print (report §4.4).
-spec describe(ern_types:type(), ern_typecheck:env(), [atom()]) -> descriptor().
describe(Type, Env, Namespace) ->
    describe(Type, Env, Namespace, []).

%% The descriptor of Type with `{hole, Id}` for each variable of Holes,
%% whose descriptor the program passes in under a requirement that names
%% `show` (report §4.9, Appendix E.1). A descriptor passed in is closed, a
%% mu of its own binding each ref inside it, so it stands in a hole whatever
%% the mus around it.
-spec describe(ern_types:type(), ern_typecheck:env(), [atom()], [integer()]) -> descriptor().
describe(Type, Env, Namespace, Holes) ->
    Scope = #scope{env = Env, namespace = Namespace, holes = Holes},
    Substituted = ern_types:substitute(Type, ern_typecheck:type_state(Env)),
    descriptor(Substituted, #{}, Scope).

%% Seen maps each user type enclosing the one being described to the id
%% its mu binds, so a recursive type refers back instead of unfolding; it
%% is passed down alone, and a sibling is described in full, since a ref
%% reaches only an enclosing mu.
descriptor({tvar, Id}, _Seen, #scope{holes = Holes}) ->
    case lists:member(Id, Holes) of
        true -> {hole, Id};
        false -> any
    end;
descriptor(pure, _, _) -> any;
descriptor({ttuple, Elements}, Seen, Scope) ->
    {tuple, descriptors(Elements, Seen, Scope)};
descriptor({tfn, Params, _, Result}, Seen, Scope) ->
    %% report §7.4: a function value from foreign code has its result
    %% checked at each call, against the result's descriptor; report §8.4:
    %% one that crosses into foreign code has each argument checked, against
    %% its parameter's
    {function, length(Params), descriptor(Result, Seen, Scope),
     text_binary("foreign return does not match ", Result, Scope), descriptors(Params, Seen, Scope),
     [text_binary("foreign argument does not match ", Param, Scope) || Param <- Params]};
descriptor({tcon, ['Int'], []}, _, _) -> int;
descriptor({tcon, ['Float'], []}, _, _) -> float;
descriptor({tcon, ['Bool'], []}, _, _) -> bool;
descriptor({tcon, ['Char'], []}, _, _) -> char;
descriptor({tcon, ['String'], []}, _, _) -> string;
descriptor({tcon, ['Bytes'], []}, _, _) -> bytes;
descriptor({tcon, ['Address'], [MessageType]}, Seen, Scope) ->
    %% the address's messages, for the proxy that exposes it (report §8.4)
    {address, descriptor(MessageType, Seen, Scope),
     text_binary("message does not match ", MessageType, Scope)};
descriptor({tcon, ['Reply'], [AnswerType]}, Seen, Scope) ->
    %% the answer's, which a reply that crosses into foreign code is
    %% checked against (report §8.4)
    {reply, descriptor(AnswerType, Seen, Scope),
     text_binary("reply does not match ", AnswerType, Scope)};
descriptor({tcon, ['Process'], []}, _, _) -> process;
descriptor({tcon, ['Never'], []}, _, _) -> never;
descriptor({tcon, ['List'], [ElementType]}, Seen, Scope) ->
    {list, descriptor(ElementType, Seen, Scope)};
descriptor({tcon, ['Map'], [KeyType, ValueType]}, Seen, Scope) ->
    {map, descriptor(KeyType, Seen, Scope), descriptor(ValueType, Seen, Scope)};
descriptor({tcon, ['Set'], [ElementType]}, Seen, Scope) ->
    {set, descriptor(ElementType, Seen, Scope)};
descriptor({tcon, QualifiedName, Args} = Type, Seen, #scope{env = Env} = Scope) ->
    case Seen of
        #{Type := Id} ->
            {ref, Id};
        _ ->
            case ern_typecheck:described_type(QualifiedName, Env) of
                #type_info{foreign = true} ->
                    %% report §8.4, Appendix E.1: unchecked, as a type
                    %% variable is, and shown as `<foreign>`
                    foreign;
                #type_info{constructors = Constructors, abstract = Abstract} ->
                    Id = map_size(Seen) + 1,
                    Sum = {con, constructor_descriptors(Constructors, Args, Seen#{Type => Id},
                                                        Scope)},
                    Descriptor = case refers(Sum, Id) of
                                     true -> {mu, Id, Sum};
                                     false -> Sum
                                 end,
                    %% report §4.4: seen from outside its module, an abstract
                    %% type's representation is not the program's to print
                    case Abstract andalso lists:droplast(QualifiedName) =/= Scope#scope.namespace of
                        true -> {abstract, Descriptor};
                        false -> Descriptor
                    end
            end
    end.

%% Each constructor's descriptor at the type's arguments, a named one's
%% keeping its field names, in declared order (report §3.5), for printing.
constructor_descriptors(Constructors, Args, Seen, Scope) ->
    [constructor_descriptor(Tag, Fields,
                            descriptors(field_types(Constructor, Args, Scope), Seen, Scope))
     || #constructor_info{name = Tag, fields = Fields} = Constructor <- Constructors].

constructor_descriptor(Tag, {named, Names}, FieldDescriptors) -> {Tag, FieldDescriptors, Names};
constructor_descriptor(Tag, _, FieldDescriptors) -> {Tag, FieldDescriptors}.

refers({ref, Id}, Id) -> true;
refers(Part, Id) when is_tuple(Part) ->
    lists:any(fun(Inner) -> refers(Inner, Id) end, tuple_to_list(Part));
refers(Parts, Id) when is_list(Parts) -> lists:any(fun(Inner) -> refers(Inner, Id) end, Parts);
refers(_, _) -> false.

descriptors(Types, Seen, Scope) ->
    [descriptor(Type, Seen, Scope) || Type <- Types].

%% A constructor's field types at the type's arguments: its scheme is
%% quantified over the type's parameters, which its result type lists in
%% order as distinct variables once instantiated.
field_types(#constructor_info{scheme = Scheme}, Args, #scope{env = Env}) ->
    {ConstructorType, _} = ern_types:instantiate(Scheme, ern_typecheck:type_state(Env)),
    {FieldTypes, {tcon, _, Params}} = case ConstructorType of
                                          {tfn, ParamTypes, _, Result} -> {ParamTypes, Result};
                                          Result -> {[], Result}
                                      end,
    Replacements = maps:from_list(lists:zip([Id || {tvar, Id} <- Params], Args)),
    [ern_types:replace_variables(FieldType, Replacements) || FieldType <- FieldTypes].

%% Report §7.4, §8.4: a check's cause, its Prefix and the type as §11.5
%% prints it, which the boundary faults with.
-spec cause(string(), ern_types:type(), ern_typecheck:env()) -> binary().
cause(Prefix, Type, Env) ->
    unicode:characters_to_binary(Prefix ++ ern_types:format(Type, ern_typecheck:type_state(Env))).

text_binary(Prefix, Type, #scope{env = Env}) -> cause(Prefix, Type, Env).
