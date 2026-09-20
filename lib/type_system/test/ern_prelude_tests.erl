%% The tables of ern_prelude are report section 9 and Appendix E as data.
%% A list that lives in the code and in a document has a test keeping them
%% equal (CLAUDE.md); these read the report and are that test.
-module(ern_prelude_tests).

-include_lib("eunit/include/eunit.hrl").

-define(REPORT, "../../../ernest_report.md").

%% report §9.4 to §9.7, Appendix E: every signature the report prints is a
%% value of the tables with the same type text, and nothing else is
values_test() ->
    Lines = code_lines(section("## 9. Prelude", "## 10. ")) ++
        code_lines(section("## Appendix E.", "## Appendix F")),
    Report = lists:sort(lists:append([signature(L) || L <- Lines])),
    %% a module written in Ernest gives its signatures by its interface; the
    %% restrictions the compiler infers and prints, `a=` and `a!`, are never
    %% written (report §3.9), so they are left out of the comparison
    St = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    Compiled = [{qname(Q), normalize(unmarked(ern_types:format_scheme(S, St)))}
                || I <- ern_prelude:stdlib_ifaces(), {Q, S} <- maps:to_list(element(4, I))],
    %% a §9.6 operation is in the table, which types it before any module is
    %% installed, and in its module's interface: it counts once when the two
    %% agree, twice and so unequal to the report when they do not
    Tables = lists:usort([{qname(Q), normalize(T)} || {Q, T} <- ern_prelude:values()]
                         ++ Compiled),
    ?assertEqual(Report, Tables).

%% report §9.3: the declared types
declared_types_test() ->
    Report = declarations(code_lines(section("### 9.3", "### 9.4"))),
    Tables = declarations(string:split(ern_prelude:declared_types(), "\n", all)),
    ?assertEqual(Report, Tables).

%% report Appendix E: the types the standard library declares, by namespace
stdlib_types_test() ->
    Sections = namespaces(section("## Appendix E.", "## Appendix F")),
    Report = lists:sort(lists:append(
                          [[{Ns, D} || D <- declarations(code_lines(Body))]
                           || {Ns, Body} <- Sections])),
    Tables = lists:sort(lists:append(
                          [[{Ns, D} || D <- declarations(string:split(Src, "\n", all))]
                           || {Ns, Src} <- ern_prelude:stdlib_types()])),
    %% a module written in Ernest gives its types by its interface, whose
    %% parameters are variables: both sides are compared with the
    %% parameters renamed in order
    Compiled = [{Ns, rename(compiled_decl(Ns, TI))}
                || I <- ern_prelude:stdlib_ifaces(), Ns <- [element(2, I)],
                   TI <- maps:values(element(3, I))],
    ?assertEqual(lists:sort([{Ns, rename(D)} || {Ns, D} <- Report]),
                 lists:sort([{Ns, rename(D)} || {Ns, D} <- Tables] ++ Compiled)).

%% A printed type without the marks of the inferred restrictions.
unmarked(Text) ->
    re:replace(Text, "\\b([a-z][a-z0-9]*)[=!]+", "\\1", [global, {return, list}]).

%% `type T(p, q) = ...` with its parameters renamed a, b, ... in order.
rename(Decl) ->
    case re:run(Decl, "^(?:foreign )?type \\w+\\(([^)]*)\\)", [{capture, all_but_first, list}]) of
        {match, [Ps]} ->
            Params = [string:trim(P) || P <- string:split(Ps, ",", all)],
            Fresh = [[C] || C <- lists:seq($a, $a + length(Params) - 1)],
            lists:foldl(fun({P, F}, D) ->
                            re:replace(D, "\\b" ++ P ++ "\\b", F,
                                       [global, {return, list}])
                        end, Decl, lists:zip(Params, Fresh));
        nomatch ->
            Decl
    end.

%% A compiled type's declaration, as the appendix writes it.
compiled_decl(Ns, TI) ->
    Q = element(2, TI),
    Params = element(3, TI),
    Names = maps:from_list(lists:zip([Id || {tvar, Id} <- Params],
                                     [[C] || C <- lists:seq($a, $a + length(Params) - 1)])),
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", [maps:get(Id, Names) || {tvar, Id} <- Params]) ++ ")"
           end,
    case element(7, TI) of
        true ->
            %% report §3.8: a foreign type has no constructors to print
            normalize(lists:flatten(["foreign type ", atom_to_list(lists:last(Q)), Head]));
        false ->
            Cons = [con_text(C, Ns, Names) || C <- element(4, TI)],
            normalize(lists:flatten(["type ", atom_to_list(lists:last(Q)), Head, " = ",
                                     lists:join(" | ", Cons)]))
    end.

con_text(CI, Ns, Names) ->
    Name = atom_to_list(element(2, CI)),
    Fields = case element(7, CI) of
                 {scheme, _, {tfn, FieldTs, _, _}, _} -> FieldTs;
                 _ -> []
             end,
    case {element(5, CI), Fields} of
        {none, _} -> Name;
        {positional, [T]} -> Name ++ "(" ++ type_text(T, Ns, Names) ++ ")";
        {{named, Fs}, FTs} ->
            Name ++ "(" ++ lists:join(", ", [atom_to_list(F) ++ " : " ++ type_text(T, Ns, Names)
                                             || {F, T} <- lists:zip(Fs, FTs)]) ++ ")"
    end.

type_text({tvar, Id}, _, Names) -> maps:get(Id, Names);
type_text({tcon, Q, Args}, Ns, Names) ->
    N = case lists:droplast(Q) of
            Ns -> atom_to_list(lists:last(Q));
            _ -> qname(Q)
        end,
    case Args of
        [] -> N;
        _ -> N ++ "(" ++ lists:join(", ", [type_text(A, Ns, Names) || A <- Args]) ++ ")"
    end;
type_text({ttuple, Es}, Ns, Names) ->
    "#(" ++ lists:join(", ", [type_text(E, Ns, Names) || E <- Es]) ++ ")".

%% report §3.1, §9.1, §9.2: the built-in types and their arities
builtin_types_test() ->
    Base = [{list_to_atom(N), 0}
            || L <- section("### 3.1", "**Integer arithmetic"),
               [N] <- [captures(L, "^\\| `([A-Z]\\w*)`")]],
    Named = [{list_to_atom(N), arity(Ps)}
             || L <- code_lines(section("### 9.1", "### 9.3")),
                [N, Ps] <- [captures(L, "^([A-Z]\\w*)(\\([^)]*\\)|) ")]],
    ?assertEqual(lists:sort(Base ++ Named), lists:sort(ern_prelude:builtin_types())).

%%
%% Reading the report
%%

%% The lines from the first line starting with From up to the next line
%% starting with To.
section(From, To) ->
    {ok, Bin} = file:read_file(?REPORT),
    Lines = string:split(unicode:characters_to_list(Bin), "\n", all),
    Rest = lists:dropwhile(fun(L) -> not lists:prefix(From, L) end, Lines),
    lists:takewhile(fun(L) -> not lists:prefix(To, L) end, tl(Rest)).

%% The lines inside ``` fences.
code_lines(Lines) -> code_lines(Lines, false).

code_lines([], _) -> [];
code_lines(["```" ++ _ | Ls], In) -> code_lines(Ls, not In);
code_lines([L | Ls], true) -> [L | code_lines(Ls, true)];
code_lines([_ | Ls], false) -> code_lines(Ls, false).

%% Appendix E's sections, each with its namespace from the heading.
namespaces([]) -> [];
namespaces([H | Ls]) ->
    case captures(H, "^### Appendix E\\.\\d+\\. `\\w+\\.ern` \\(namespace `(\\w+)`\\)") of
        [Ns] ->
            {Body, Rest} = lists:splitwith(fun(L) -> not lists:prefix("### ", L) end, Ls),
            [{[list_to_atom(Ns)], Body} | namespaces(Rest)];
        _ -> namespaces(Ls)
    end.

%% A signature line, `Name, Name : Type // comment`, as {name, type} pairs;
%% any other line as [].
signature([C | _] = Line) when C =/= $\s, C =/= $= , C =/= $| ->
    case re:split(Line, "\\s+:\\s+", [unicode, {return, list}, {parts, 2}]) of
        [Names, TypeAndComment] ->
            Name = "[A-Za-z][\\w.]*(\\.[-+*/%<>]+)?",
            case re:run(Names, "^" ++ Name ++ "(,\\s*" ++ Name ++ ")*$", [unicode]) of
                {match, _} ->
                    Type = normalize(hd(string:split(TypeAndComment, "//"))),
                    [{string:trim(N), Type} || N <- string:split(Names, ",", all)];
                nomatch -> []
            end;
        _ -> []
    end;
signature(_) -> [].

%% Type declarations in the lines, comments stripped, one string each: a
%% declaration starts at a `type` line and continues over indented lines.
declarations(Lines) ->
    Stripped = [string:trim(hd(string:split(L, "//")), trailing) || L <- Lines],
    lists:sort([normalize(D) || D <- group(Stripped)]).

group([]) -> [];
group([L | Ls]) ->
    case is_declaration(L) of
        true ->
            {Cont, Rest} = lists:splitwith(fun continuation/1, Ls),
            [lists:flatten(lists:join(" ", [L | Cont])) | group(Rest)];
        false -> group(Ls)
    end.

is_declaration("type " ++ _) -> true;
is_declaration("foreign type " ++ _) -> true;
is_declaration(_) -> false.

continuation(" " ++ _) -> true;
continuation(_) -> false.

captures(Line, Re) ->
    case re:run(Line, Re, [unicode, {capture, all_but_first, list}]) of
        {match, Cs} -> Cs;
        nomatch -> nomatch
    end.

arity("") -> 0;
arity(Params) -> length(string:split(Params, ",", all)).

qname(Q) -> lists:flatten(lists:join(".", [atom_to_list(A) || A <- Q])).

normalize(S) -> re:replace(string:trim(S), "\\s+", " ", [global, unicode, {return, list}]).
