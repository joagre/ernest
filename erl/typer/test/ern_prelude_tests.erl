%% The tables of ern_prelude are report section 9 and Appendix E as data.
%% A list that lives in the code and in a document has a test keeping them
%% equal (CLAUDE.md); these read the report and are that test.
-module(ern_prelude_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

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
    Tables = lists:usort([{qname(Q), normalize(T)} || {Q, T, _} <- ern_prelude:values()]
                         ++ Compiled),
    same(Report, Tables).

%% report Appendix E.0 rule 9: no exported function of the standard library
%% takes a `Bool` that chooses a behaviour; `Bool`'s own module takes the
%% value it operates on. A regression test: the library complied when the
%% rule was written
no_bool_choice_test() ->
    Choosing = [Q || #iface{namespace = Ns, values = Vs} <- ern_prelude:stdlib_ifaces(),
                     Ns =/= ['Bool'],
                     {Q, #scheme{type = {tfn, Ps, _, _}}} <- maps:to_list(Vs),
                     lists:member({tcon, ['Bool'], []}, Ps)],
    ?assertEqual([], Choosing).

%% report §9, Appendix E.0 rule 6: every prelude name is documented, a type
%% and a value beside its entry, and an operation marked `module` by its
%% type's module, whose documentation chunk has the entry
prelude_documented_test() ->
    [?assert(is_binary(D) andalso byte_size(D) > 0) || {_, _, D} <- ern_prelude:builtin_types()],
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    Undocumented = [N || #type_decl{doc = undefined, name = N} <- Decls],
    ?assertEqual([], Undocumented),
    Own = [Q || {Q, _, D} <- ern_prelude:values(), is_binary(D)],
    ?assert(length(Own) >= 18),
    ModuleOnly = [Q || {Q, _, module} <- ern_prelude:values()],
    Missing = [Q || [Ns, Name] = Q <- ModuleOnly, not in_module_docs(Ns, Name)],
    ?assertEqual([], Missing),
    %% one entry of the page for every type and every value documented here
    {docs_v1, _, ernest, _, _, _, Entries} = ern_prelude:docs(),
    ?assertEqual(length(ern_prelude:builtin_types()) + length(Decls) + length(Own),
                 length(Entries)).

in_module_docs(Ns, Name) ->
    Mod = list_to_atom("ern@" ++ string:lowercase(atom_to_list(Ns))),
    case code:which(Mod) of
        File when is_list(File) ->
            {ok, {_, [{"Docs", Chunk}]}} = beam_lib:chunks(File, ["Docs"]),
            {docs_v1, _, _, _, _, _, Entries} = binary_to_term(Chunk),
            lists:any(fun({{_, N, _}, _, _, _, _}) -> N =:= Name end, Entries);
        _ ->
            false
    end.

%% report Appendix E.0 rule 1, E.3, E.4, E.5, E.14, E.20: the primitives a
%% module's section names are the module's `foreign fn`s. An exported one
%% is named as itself; a private one by the exported declaration that alone
%% calls it, `slice` for String's `part`, or else by its own name.
primitives_test() ->
    [begin
         {ok, Source} = file:read_file(stdlib_file(Ns)),
         {ok, Decls} = ern_parser:parse_string(Source),
         ?assertEqual({Ns, lists:sort(Named)}, {Ns, lists:sort(foreign_names(Decls))})
     end || {Ns, Body} <- namespaces(section("## Appendix E.", "## Appendix F")),
            Named <- [primitives(Body)], Named =/= []].

%% The names in backticks of a section's sentence "The primitives are ...".
primitives(Body) ->
    Text = lists:append(Body),
    case string:find(Text, "The primitives are") of
        nomatch -> [];
        Found ->
            [Sentence | _] = string:split(Found, "(E.0 rule 1)"),
            {match, Names} = re:run(Sentence, "`(\\w+)`", [global, {capture, [1], list}]),
            [list_to_atom(N) || [N] <- Names]
    end.

stdlib_file([Ns]) ->
    filename:join("../../../stdlib", string:lowercase(atom_to_list(Ns)) ++ ".ern").

%% Each foreign fn under the name the report gives it.
foreign_names(Decls) ->
    Callers = fun(Name) ->
                      [D || D <- Decls, not is_record(D, foreign_fn_decl),
                            lists:member(Name, ern_ast:free_names(body(D), params(D)))]
              end,
    [case {Export, Callers(Name)} of
         {true, _} -> Name;
         {false, [#fn_decl{export = true, name = Caller}]} -> Caller;
         {false, [#let_decl{export = true, name = Caller}]} -> Caller;
         {false, _} -> Name
     end || #foreign_fn_decl{name = Name, export = Export} <- Decls].

%% The names a function's parameters bind, which are not calls.
params(#fn_decl{params = Ps}) ->
    [N || #param{pattern = P} <- Ps, {N, _} <- ern_ast:pattern_bindings(P)];
params(_) -> [].

body(#fn_decl{body = B}) -> B;
body(#let_decl{body = B}) -> B;
body(_) -> [].

%% report §9.3: the declared types
declared_types_test() ->
    Report = declarations(code_lines(section("### 9.3", "### 9.4"))),
    Tables = declarations(string:split(ern_prelude:declared_types(), "\n", all)),
    same(Report, Tables).

%% report Appendix E: the types the standard library declares, by
%% namespace, read from the modules' compiled interfaces, whose parameters
%% are variables: both sides are compared with the parameters renamed in
%% order
stdlib_types_test() ->
    Sections = namespaces(section("## Appendix E.", "## Appendix F")),
    Report = lists:sort(lists:append(
                          [[{Ns, D} || D <- declarations(code_lines(Body))]
                           || {Ns, Body} <- Sections])),
    Compiled = [{Ns, rename(compiled_decl(Ns, TI))}
                || I <- ern_prelude:stdlib_ifaces(), Ns <- [element(2, I)],
                   TI <- maps:values(element(3, I))],
    same(lists:sort([{Ns, rename(D)} || {Ns, D} <- Report]), lists:sort(Compiled)).

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
compiled_decl(_Ns, TI) when element(7, TI) ->
    %% report §3.8: a foreign type has no constructors, and its parameters
    %% are names rather than variables
    Q = element(2, TI),
    Params = element(3, TI),
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", [atom_to_list(P) || P <- Params]) ++ ")"
           end,
    normalize(lists:flatten(["foreign type ", atom_to_list(lists:last(Q)), Head]));
compiled_decl(Ns, TI) ->
    Q = element(2, TI),
    Params = element(3, TI),
    Names = maps:from_list(lists:zip([Id || {tvar, Id} <- Params],
                                     [[C] || C <- lists:seq($a, $a + length(Params) - 1)])),
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", [maps:get(Id, Names) || {tvar, Id} <- Params]) ++ ")"
           end,
    Cons = [con_text(C, Ns, Names) || C <- element(4, TI)],
    normalize(lists:flatten(["type ", atom_to_list(lists:last(Q)), Head, " = ",
                             lists:join(" | ", Cons)])).

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
    same(lists:sort(Base ++ Named),
         lists:sort([{N, A} || {N, A, _} <- ern_prelude:builtin_types()])).

%% The report's list and the code's equal, in order; where they are not, the
%% failure shows first what each has that the other lacks.
same(Report, Code) ->
    ?assertEqual({[], []}, {Report -- Code, Code -- Report}),
    ?assertEqual(Report, Code).

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
