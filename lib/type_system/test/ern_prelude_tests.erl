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
    %% a module written in Ernest gives its signatures by its interface
    St = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    Compiled = [{qname(Q), normalize(ern_types:format_scheme(S, St))}
                || I <- ern_prelude:stdlib_ifaces(), {Q, S} <- maps:to_list(element(4, I))],
    Tables = lists:sort([{qname(Q), normalize(T)} || {Q, T} <- ern_prelude:values()] ++ Compiled),
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
    ?assertEqual(Report, Tables).

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
