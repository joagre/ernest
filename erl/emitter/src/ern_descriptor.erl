%% Report Appendix E.1, §11.2: the shell's describer, the descriptor of a
%% type the checker gave an input's value, by which the shell prints it
%% (ern_show). The emitter describes from forms the descriptors of a
%% program's code, which the boundary checks a value against, a checker
%% exposes an address with, and `Io.show` and `Io.debug` print by
%% (ern_emitter, report §8.4); this module owns their type, which one
%% printer reads. A recursive type refers back to its mu.
-module(ern_descriptor).

-export([describe/3]).

-export_type([descriptor/0, named_cause/0]).

-include_lib("checker/include/ern_types.hrl").

%% A type as a descriptor holds it, which `Io.show`, `Io.debug` and the
%% shell print a value by (ern_show) and the emitter builds the runtime's
%% form of for the boundary (ern_boundary): a function's is tagged
%% `function` here, and the built one `'fun'`, since the two carry other
%% parts. mu binds Id for each `{ref, Id}` inside it, which is how a
%% recursive type is described once; a hole stands for a descriptor a
%% requirement passes in; an abstract type seen from outside its module is
%% wrapped, and a named constructor carries its fields' names, both for
%% printing. A check's cause is none in a descriptor the shell prints by,
%% which no check reads.
-type descriptor() :: any | int | float | bool | char | string | bytes | process | never
                    | unit | foreign
                    | {hole, integer()} | {ref, pos_integer()}
                    | {tuple, [descriptor()]} | {list, descriptor()} | {set, descriptor()}
                    | {map, descriptor(), descriptor()}
                    | {address, descriptor(), binary() | none}
                    | {reply, descriptor(), binary() | none}
                    | {function, non_neg_integer(), descriptor(), named_cause() | none,
                       [descriptor()], [named_cause()] | none}
                    | {con, [{atom(), [descriptor()]} | {atom(), [descriptor()], [atom()]}]}
                    | {mu, pos_integer(), descriptor()} | {abstract, descriptor()}.

%% Report §12.3, §8.4: the cause a function value's check faults with, the
%% text before the function's name and the text after it, which the
%% boundary writes the name between.
-type named_cause() :: {binary(), binary()}.

%% The type's names and the module it is seen from.
-record(scope, {env, namespace = []}).

%% The descriptor of Type, whose names Env knows, seen from the module
%% Namespace: from any other, an abstract type's representation is not
%% the program's to print (report §4.4).
-spec describe(ern_types:type(), ern_typecheck:env(), [atom()]) -> descriptor().
describe(Type, Env, Namespace) ->
    Scope = #scope{env = Env, namespace = Namespace},
    Substituted = ern_types:substitute(Type, ern_typecheck:type_state(Env)),
    descriptor(Substituted, #{}, Scope).

%% Seen maps each user type enclosing the one being described to the id
%% its mu binds, so a recursive type refers back instead of unfolding; it
%% is passed down alone, and a sibling is described in full, since a ref
%% reaches only an enclosing mu.
descriptor({tvar, _}, _, _) -> any;
descriptor(none, _, _) -> any;
descriptor({ttuple, Elements}, Seen, Scope) ->
    {tuple, descriptors(Elements, Seen, Scope)};
descriptor({tfn, Params, _, Result}, Seen, Scope) ->
    {function, length(Params), descriptor(Result, Seen, Scope), none,
     descriptors(Params, Seen, Scope), none};
descriptor({tcon, ['Int'], []}, _, _) -> int;
descriptor({tcon, ['Float'], []}, _, _) -> float;
descriptor({tcon, ['Bool'], []}, _, _) -> bool;
descriptor({tcon, ['Char'], []}, _, _) -> char;
descriptor({tcon, ['String'], []}, _, _) -> string;
descriptor({tcon, ['Bytes'], []}, _, _) -> bytes;
%% report §8.4, Appendix E.1: the prelude's Unit, a word of its own,
%% where a program's own type named Unit is its constructors
descriptor({tcon, ['Unit'], []}, _, _) -> unit;
descriptor({tcon, ['Address'], [MessageType]}, Seen, Scope) ->
    {address, descriptor(MessageType, Seen, Scope), none};
descriptor({tcon, ['Reply'], [AnswerType]}, Seen, Scope) ->
    {reply, descriptor(AnswerType, Seen, Scope), none};
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
