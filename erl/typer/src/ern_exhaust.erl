%% Match exhaustiveness, report §5.9: the unguarded clauses of every
%% `match` must cover the scrutinee's type, and no clause of a `match` or
%% a `receive` may be redundant. Maranget's usefulness algorithm; a
%% witness for the missing case goes into the message. `receive` is exempt
%% from coverage (report §6.3), not from redundancy.
-module(ern_exhaust).

-export([check/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

%% Simplified patterns: wild | {con, key(), [pattern()]}
%%   key(): {con, QualifiedName} | {tuple, Size} | nil | cons | {bool, Bool}
%%        | {lit, Value}
%% QualifiedName is the constructor's, as the checker keeps it, so a
%% constructor is read back by it with no name to resolve (report §4.2).

-spec check(tuple(), ern_typecheck:env()) -> ok.
check(Node, Env) ->
    walk(fun(#e_match{span = Span, scrutinee = Scrutinee, clauses = Clauses}) ->
                 redundant(Clauses, Env),
                 exhaustive(Span, Scrutinee, Clauses, Env);
            (#e_receive{clauses = Clauses}) ->
                 redundant(Clauses, Env);
            (_) -> ok
         end, Node).

%% Report §5.9: the unguarded clauses of a `match` cover its scrutinee's
%% type; where they do not, the message names a value none of them matches.
exhaustive(Span, Scrutinee, Clauses, Env) ->
    Rows = lists:append([alternative_rows(Pattern, Env)
                         || #clause{pattern = Pattern, guard = undefined} <- Clauses]),
    case useful(Rows, [wild], Env) of
        no -> ok;
        {yes, [Witness]} ->
            Type = ern_typecheck:resolve_type(ern_typecheck:node_type(Scrutinee), Env),
            Shown = ern_types:format(Type, ern_typecheck:type_state(Env)),
            throw({type_error, Span, lists:flatten(["match on ", Shown,
                                                    " is not exhaustive; missing ",
                                                    show(Witness, Env)])})
    end.

%% Report §5.9: a clause, or an alternative of one, that can match no value
%% the clauses before it leave is an error. The label names the earliest
%% clause with which the cover is complete.
redundant(Clauses, Env) ->
    lists:foldl(fun(Clause, Earlier) -> rows_through(Clause, Earlier, Env) end, [], Clauses),
    ok.

%% The rows the clauses before this one cover, and this one's own, each
%% beside its pattern, once each of its alternatives is judged. A guarded
%% clause adds none, since its guard may fail; the alternatives before one
%% in its own clause cover what they match.
rows_through(#clause{pattern = Pattern, guard = Guard}, Earlier, Env) ->
    Alternatives = alternatives(Pattern),
    IsAlternative = length(Alternatives) > 1,
    Own = lists:foldl(fun(Alternative, Before) ->
                          judge(Alternative, IsAlternative, Before, Env),
                          Before ++ [{[simplify(Alternative, Env)], Alternative}]
                      end, Earlier, Alternatives),
    case Guard of
        undefined -> Own;
        _ -> Earlier
    end.

alternatives(#p_or{alternatives = Alternatives}) -> Alternatives;
alternatives(Pattern) -> [Pattern].

judge(Alternative, IsAlternative, Before, Env) ->
    Candidate = [relax(simplify(Alternative, Env))],
    case useful([Row || {Row, _} <- Before], Candidate, Env) of
        {yes, _} -> ok;
        no ->
            What = case IsAlternative of
                       true -> "alternative";
                       false -> "clause"
                   end,
            [{Last, Covering} | _] = cover(Before, Candidate, [], Env),
            Label = case useful([Last], Candidate, Env) of
                        no -> "this pattern matches every value it would";
                        {yes, _} -> "with those before it, this one matches every value it would"
                    end,
            throw({type_error,
                   #diagnostic{span = ern_diagnostic:span(ern_ast:span(Alternative)),
                               message = "this " ++ What ++ " can never match",
                               labels = [{ern_diagnostic:span(ern_ast:span(Covering)), Label}],
                               help = "remove it, or move it above the patterns that cover it"}})
    end.

%% The shortest run of rows from the first that leaves Candidate useless:
%% the rows from the last of them on.
cover([Row | Rest], Candidate, Taken, Env) ->
    Taken1 = Taken ++ [Row],
    case useful([TakenRow || {TakenRow, _} <- Taken1], Candidate, Env) of
        no -> [Row | Rest];
        {yes, _} -> cover(Rest, Candidate, Taken1, Env)
    end.

%% A bitstring pattern counts as matching nothing among the rows that
%% cover, and as matching anything in the pattern judged, so that no
%% bitstring clause is called redundant for what its size may decide
%% (report §5.9, §5.11).
relax({con, bits, []}) -> wild;
relax({con, Key, SubPatterns}) -> {con, Key, [relax(SubPattern) || SubPattern <- SubPatterns]};
relax(wild) -> wild.

walk(Visit, Node) ->
    ern_ast:walk(fun(Child, ok) -> Visit(Child), ok end, Node, ok).

%%
%% Simplification
%%

%% Report §5.9: a clause with alternatives covers what each alternative covers.
alternative_rows(Pattern, Env) ->
    [[simplify(Alternative, Env)] || Alternative <- alternatives(Pattern)].

simplify(#p_wildcard{}, _) -> wild;
simplify(#p_var{}, _) -> wild;
simplify(#p_as{pattern = Pattern}, Env) -> simplify(Pattern, Env);
simplify(#p_literal{kind = bool, value = Value}, _) -> {con, {bool, Value}, []};
simplify(#p_literal{value = Value}, _) -> {con, {lit, Value}, []};
simplify(#p_tuple{elements = Elements}, Env) ->
    {con, {tuple, length(Elements)}, [simplify(Element, Env) || Element <- Elements]};
simplify(#p_list{elements = []}, _) -> {con, nil, []};
simplify(#p_list{elements = [Element | Elements]} = Pattern, Env) ->
    {con, cons, [simplify(Element, Env), simplify(Pattern#p_list{elements = Elements}, Env)]};
simplify(#p_cons{head = Head, tail = Tail}, Env) ->
    {con, cons, [simplify(Head, Env), simplify(Tail, Env)]};
simplify(#p_constructor{span = Span, path = Path, name = Name, args = Args}, Env) ->
    #constructor_info{qualified_name = QualifiedName, fields = Fields} =
        ern_typecheck:lookup_constructor(Span, Path, Name, Env),
    SubPatterns = case {Fields, Args} of
                      {none, _} -> [];
                      {positional, none} -> [wild];
                      {positional, {positional, Pattern}} -> [simplify(Pattern, Env)];
                      {{named, Names}, none} -> [wild || _ <- Names];
                      {{named, Names}, {named, FieldPatterns}} ->
                          [field_pattern(FieldName, FieldPatterns, Env) || FieldName <- Names]
                  end,
    {con, {con, QualifiedName}, SubPatterns};
simplify(#p_bitstring{}, _) -> {con, bits, []}.

%% Report §5.10: a field a pattern omits matches any value.
field_pattern(FieldName, FieldPatterns, Env) ->
    case [Pattern || #field_pattern{name = Name, pattern = Pattern} <- FieldPatterns,
                     Name =:= FieldName] of
        [Pattern] -> simplify(Pattern, Env);
        [] -> wild
    end.

%%
%% Usefulness with a witness. useful(Rows, Vector) is no when every value
%% matching Vector is matched by some row, else {yes, Witness}.
%%

useful([], Vector, _Env) ->
    {yes, [wild || _ <- Vector]};
useful(_Rows, [], _Env) ->
    no;
useful(Rows, [{con, Key, SubPatterns} | Vector], Env) ->
    Arity = length(SubPatterns),
    case useful(specialize(Rows, Key, Arity), SubPatterns ++ Vector, Env) of
        no -> no;
        {yes, Witnesses} ->
            {SubWitnesses, RestWitnesses} = lists:split(Arity, Witnesses),
            {yes, [{con, Key, SubWitnesses} | RestWitnesses]}
    end;
useful(Rows, [wild | Vector], Env) ->
    Keys = lists:usort([Key || [{con, Key, _} | _] <- Rows]),
    case complete(Keys, Env) of
        {true, AllKeys} ->
            try_keys(AllKeys, Rows, Vector, Env);
        {false, Missing} ->
            Default = [Rest || [wild | Rest] <- Rows],
            case useful(Default, Vector, Env) of
                no -> no;
                {yes, Witnesses} ->
                    Witness = case Missing of
                                  any -> wild;
                                  Key -> {con, Key, [wild || _ <- lists:seq(1, arity(Key, Env))]}
                              end,
                    {yes, [Witness | Witnesses]}
            end
    end.

try_keys([], _Rows, _Vector, _Env) ->
    no;
try_keys([Key | Keys], Rows, Vector, Env) ->
    Arity = arity(Key, Env),
    case useful(specialize(Rows, Key, Arity), [wild || _ <- lists:seq(1, Arity)] ++ Vector, Env) of
        no -> try_keys(Keys, Rows, Vector, Env);
        {yes, Witnesses} ->
            {SubWitnesses, RestWitnesses} = lists:split(Arity, Witnesses),
            {yes, [{con, Key, SubWitnesses} | RestWitnesses]}
    end.

specialize(Rows, Key, Arity) ->
    lists:append([case Row of
                      [{con, Key, SubPatterns} | Rest] -> [SubPatterns ++ Rest];
                      [wild | Rest] -> [[wild || _ <- lists:seq(1, Arity)] ++ Rest];
                      _ -> []
                  end || Row <- Rows]).

%% Is the set of keys a complete signature? Returns {true, AllKeys} or
%% {false, MissingKey | any}.
complete([], _Env) ->
    {false, any};
complete([{lit, _} | _], _Env) ->
    {false, any};
complete([bits | _], _Env) ->
    %% report §5.11, §6.3: a bitstring pattern can fail to match
    {false, any};
complete([{bool, _} | _] = Keys, _Env) ->
    All = [{bool, true}, {bool, false}],
    missing(All, Keys);
complete([{tuple, _} = Key | _], _Env) ->
    {true, [Key]};
complete([Key | _] = Keys, _Env) when Key =:= nil; Key =:= cons ->
    missing([nil, cons], Keys);
complete([{con, QualifiedName} | _] = Keys, Env) ->
    #constructor_info{type_qualified_name = TypeQualifiedName} =
        ern_typecheck:constructor_info(QualifiedName, Env),
    #type_info{constructors = Constructors} = ern_typecheck:lookup_type(TypeQualifiedName, Env),
    missing([{con, ConstructorQualifiedName}
             || #constructor_info{qualified_name = ConstructorQualifiedName} <- Constructors],
            Keys).

missing(All, Keys) ->
    case All -- Keys of
        [] -> {true, All};
        [First | _] -> {false, First}
    end.

arity({con, QualifiedName}, Env) ->
    (ern_typecheck:constructor_info(QualifiedName, Env))#constructor_info.tag_arity;
arity({tuple, Size}, _) -> Size;
arity(cons, _) -> 2;
arity(_, _) -> 0.

%%
%% Witness printing
%%

show(wild, _) -> "_";
show({con, {bool, Bool}, []}, _) -> atom_to_list(Bool);
show({con, {lit, Value}, []}, _) -> lists:flatten(io_lib:format("~p", [Value]));
show({con, bits, []}, _) -> "<<...>>";
show({con, {tuple, _}, SubPatterns}, Env) ->
    ["#(", join([show(SubPattern, Env) || SubPattern <- SubPatterns]), ")"];
show({con, nil, []}, _) -> "[]";
show({con, cons, [Head, Tail]}, Env) -> [show_atom(Head, Env), " :: ", show(Tail, Env)];
show({con, {con, QualifiedName}, SubPatterns}, Env) ->
    #constructor_info{name = Name, fields = Fields} =
        ern_typecheck:constructor_info(QualifiedName, Env),
    case {Fields, SubPatterns} of
        {none, []} -> atom_to_list(Name);
        {positional, [SubPattern]} -> [atom_to_list(Name), "(", show(SubPattern, Env), ")"];
        {{named, Names}, _} ->
            Shown = [[atom_to_list(FieldName), " = ", show(SubPattern, Env)]
                     || {FieldName, SubPattern} <- lists:zip(Names, SubPatterns),
                        SubPattern =/= wild],
            case Shown of
                [] -> atom_to_list(Name);
                _ -> [atom_to_list(Name), "(", join(Shown), ")"]
            end
    end.

show_atom({con, cons, _} = Pattern, Env) -> ["(", show(Pattern, Env), ")"];
show_atom(Pattern, Env) -> show(Pattern, Env).

join(Parts) -> lists:join(", ", Parts).
