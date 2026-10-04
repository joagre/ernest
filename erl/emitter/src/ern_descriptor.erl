%% Report §8.4, Appendix E.1: the descriptor of a type, the runtime's
%% reading of it: what the foreign boundary checks a value against, what a
%% proxy exposes an address with, and what `Io.show`, `Io.debug` and the
%% shell print a value by, one printer (§11.2). A recursive type refers
%% back to its mu.
-module(ern_descriptor).

-export([describe/3, describe/4]).

-include_lib("typer/include/ern_types.hrl").

%% The type's names, the module it is seen from, and the type variables
%% whose descriptors a requirement passes in, each a hole.
-record(scope, {env, namespace = [], holes = []}).

%% The descriptor of Type, whose names Env knows, seen from the module
%% Namespace: from any other, an abstract type's representation is not
%% the program's to print (report §4.4).
-spec describe(term(), ern_typecheck:env(), [atom()]) -> term().
describe(Type, Env, Namespace) ->
    describe(Type, Env, Namespace, []).

%% The descriptor of Type with `{hole, Id}` for each variable of Holes,
%% whose descriptor the program passes in under a requirement that names
%% `show` (report §4.9, Appendix E.1). A descriptor passed in is closed, a
%% mu of its own binding each ref inside it, so it stands in a hole whatever
%% the mus around it.
-spec describe(term(), ern_typecheck:env(), [atom()], [integer()]) -> term().
describe(Type, Env, Namespace, Holes) ->
    Scope = #scope{env = Env, namespace = Namespace, holes = Holes},
    Substituted = ern_types:substitute(Type, ern_typecheck:type_state(Env)),
    {Descriptor, _} = descriptor(Substituted, #{}, Scope),
    Descriptor.

%% Seen maps each user type enclosing the one being described to the id
%% its mu binds, so a recursive type refers back instead of unfolding; a
%% sibling is described in full, since a ref reaches only an enclosing mu.
descriptor({tvar, Id}, Seen, #scope{holes = Holes}) ->
    case lists:member(Id, Holes) of
        true -> {{hole, Id}, Seen};
        false -> {any, Seen}
    end;
descriptor(pure, Seen, _) -> {any, Seen};
descriptor({ttuple, Elements}, Seen, Scope) ->
    {Descriptors, Seen1} = descriptors(Elements, Seen, Scope),
    {{tuple, Descriptors}, Seen1};
descriptor({tfn, Params, _, Result}, Seen, Scope) ->
    %% report §7.4: a function value from foreign code has its result
    %% checked at each call, against the result's descriptor; report §8.4:
    %% one that crosses into foreign code has each argument checked, against
    %% its parameter's
    {ResultDescriptor, Seen1} = descriptor(Result, Seen, Scope),
    {ParamDescriptors, Seen2} = descriptors(Params, Seen1, Scope),
    {{'fun', length(Params), ResultDescriptor,
      text_binary("foreign return does not match ", Result, Scope), ParamDescriptors,
      [text_binary("foreign argument does not match ", Param, Scope) || Param <- Params]},
     Seen2};
descriptor({tcon, ['Int'], []}, Seen, _) -> {int, Seen};
descriptor({tcon, ['Float'], []}, Seen, _) -> {float, Seen};
descriptor({tcon, ['Bool'], []}, Seen, _) -> {bool, Seen};
descriptor({tcon, ['Char'], []}, Seen, _) -> {char, Seen};
descriptor({tcon, ['String'], []}, Seen, _) -> {string, Seen};
descriptor({tcon, ['Bytes'], []}, Seen, _) -> {bytes, Seen};
descriptor({tcon, ['Address'], [MessageType]}, Seen, Scope) ->
    %% the address's messages, for the proxy that exposes it (report §8.4)
    {MessageDescriptor, Seen1} = descriptor(MessageType, Seen, Scope),
    {{address, MessageDescriptor, text_binary("message does not match ", MessageType, Scope)},
     Seen1};
descriptor({tcon, ['Reply'], [AnswerType]}, Seen, Scope) ->
    %% the answer's, which a reply that crosses into foreign code is
    %% checked against (report §8.4)
    {AnswerDescriptor, Seen1} = descriptor(AnswerType, Seen, Scope),
    {{reply, AnswerDescriptor, text_binary("reply does not match ", AnswerType, Scope)}, Seen1};
descriptor({tcon, ['Process'], []}, Seen, _) -> {process, Seen};
descriptor({tcon, ['Never'], []}, Seen, _) -> {never, Seen};
descriptor({tcon, ['List'], [ElementType]}, Seen, Scope) ->
    {ElementDescriptor, Seen1} = descriptor(ElementType, Seen, Scope),
    {{list, ElementDescriptor}, Seen1};
descriptor({tcon, ['Map'], [KeyType, ValueType]}, Seen, Scope) ->
    {[KeyDescriptor, ValueDescriptor], Seen1} = descriptors([KeyType, ValueType], Seen, Scope),
    {{map, KeyDescriptor, ValueDescriptor}, Seen1};
descriptor({tcon, ['Set'], [ElementType]}, Seen, Scope) ->
    {ElementDescriptor, Seen1} = descriptor(ElementType, Seen, Scope),
    {{set, ElementDescriptor}, Seen1};
descriptor({tcon, QualifiedName, Args} = Type, Seen, #scope{env = Env} = Scope) ->
    case Seen of
        #{Type := Id} ->
            {{ref, Id}, Seen};
        _ ->
            case ern_typecheck:lookup_type(QualifiedName, Env) of
                #type_info{foreign = true} ->
                    %% report §8.4, Appendix E.1: unchecked, as a type
                    %% variable is, and shown as `<foreign>`
                    {foreign, Seen};
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
                        true -> {{abstract, Descriptor}, Seen};
                        false -> {Descriptor, Seen}
                    end
            end
    end.

%% Each constructor's descriptor at the type's arguments, a named one's
%% keeping its field names, in declared order (report §3.5), for printing.
constructor_descriptors(Constructors, Args, Seen, Scope) ->
    {Descriptors, _} =
        lists:mapfoldl(fun(#constructor_info{name = Tag, fields = Fields} = Constructor, Acc) ->
                           FieldTypes = field_types(Constructor, Args, Scope),
                           {FieldDescriptors, Acc1} = descriptors(FieldTypes, Acc, Scope),
                           {constructor_descriptor(Tag, Fields, FieldDescriptors), Acc1}
                       end, Seen, Constructors),
    Descriptors.

constructor_descriptor(Tag, {named, Names}, FieldDescriptors) -> {Tag, FieldDescriptors, Names};
constructor_descriptor(Tag, _, FieldDescriptors) -> {Tag, FieldDescriptors}.

refers({ref, Id}, Id) -> true;
refers(Part, Id) when is_tuple(Part) ->
    lists:any(fun(Inner) -> refers(Inner, Id) end, tuple_to_list(Part));
refers(Parts, Id) when is_list(Parts) -> lists:any(fun(Inner) -> refers(Inner, Id) end, Parts);
refers(_, _) -> false.

descriptors(Types, Seen, Scope) ->
    lists:mapfoldl(fun(Type, Acc) -> descriptor(Type, Acc, Scope) end, Seen, Types).

%% A constructor's field types at the type's arguments: its scheme is
%% quantified over the type's parameters, which its result type lists in
%% order as distinct variables once instantiated.
field_types(#constructor_info{scheme = Scheme}, Args, #scope{env = Env}) ->
    {ConstructorType, _} = ern_types:instantiate(Scheme, ern_typecheck:type_state(Env)),
    {FieldTypes, {tcon, _, Params}} = case ConstructorType of
                                          {tfn, ParamTypes, _, Result} -> {ParamTypes, Result};
                                          Result -> {[], Result}
                                      end,
    Substitution = maps:from_list(lists:zip([Id || {tvar, Id} <- Params], Args)),
    [substitute(FieldType, Substitution) || FieldType <- FieldTypes].

substitute({tvar, Id} = Type, Substitution) -> maps:get(Id, Substitution, Type);
substitute({tcon, QualifiedName, Args}, Substitution) ->
    {tcon, QualifiedName, [substitute(Arg, Substitution) || Arg <- Args]};
substitute({ttuple, Elements}, Substitution) ->
    {ttuple, [substitute(Element, Substitution) || Element <- Elements]};
substitute({tfn, Params, Effect, Result}, Substitution) ->
    {tfn, [substitute(Param, Substitution) || Param <- Params], substitute(Effect, Substitution),
     substitute(Result, Substitution)};
substitute(pure, _) -> pure.

text_binary(Prefix, Type, #scope{env = Env}) ->
    unicode:characters_to_binary(Prefix ++ ern_types:format(Type, ern_typecheck:type_state(Env))).
