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
    Report = lists:sort(lists:append([signature(Line) || Line <- Lines])),
    %% a module written in Ernest gives its signatures by its interface; the
    %% restrictions the compiler infers and prints, `a=` and `a!`, are never
    %% written (report §3.9), so they are left out of the comparison; a
    %% module's section writes its own types unqualified (§4.2)
    TypeState = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    Compiled = [{ern_namespace:text(QualifiedName), printed(QualifiedName, Scheme, TypeState)}
                || #interface{values = Values} <- ern_prelude:stdlib_interfaces(),
                   {QualifiedName, Scheme} <- maps:to_list(Values)],
    %% a §9.6 operation is in the table, which types it before any module is
    %% installed, and in its module's interface: it counts once when the two
    %% agree, twice and so unequal to the report when they do not
    Tables = lists:usort([{ern_namespace:text(QualifiedName), normalize(Text)}
                          || {QualifiedName, Text, _} <- ern_prelude:values()]
                         ++ Compiled),
    same(Report, Tables).

%% report Appendix E.0 rule 9: no exported function of the standard library
%% takes a `Bool` that chooses a behaviour; `Bool`'s own module takes the
%% value it operates on. A regression test: the library complied when the
%% rule was written
no_bool_choice_test() ->
    Choosing = [QualifiedName
                || #interface{namespace = Namespace, values = Values}
                       <- ern_prelude:stdlib_interfaces(),
                   Namespace =/= ['Bool'],
                   {QualifiedName, #scheme{type = {tfn, ParamTypes, _, _}}} <- maps:to_list(Values),
                   lists:member({tcon, ['Bool'], []}, ParamTypes)],
    ?assertEqual([], Choosing).

%% report §9, Appendix E.0 rule 6: every prelude name is documented, a type
%% and a value beside its entry, and an operation marked `module` by its
%% type's module, whose documentation chunk has the entry
prelude_documented_test() ->
    [?assert(is_binary(Doc) andalso byte_size(Doc) > 0)
     || {_, _, Doc} <- ern_prelude:builtin_types()],
    {ok, Declarations} = ern_parser:parse_string(ern_prelude:declared_types()),
    Undocumented = [Name || #type_declaration{doc = undefined, name = Name} <- Declarations],
    ?assertEqual([], Undocumented),
    Own = [QualifiedName || {QualifiedName, _, Doc} <- ern_prelude:values(), is_binary(Doc)],
    ?assert(length(Own) >= 12),
    ModuleOnly = [QualifiedName || {QualifiedName, _, module} <- ern_prelude:values()],
    Missing = [QualifiedName || [Namespace, Name] = QualifiedName <- ModuleOnly,
                                not in_module_docs(Namespace, Name)],
    ?assertEqual([], Missing),
    %% one entry of the page for every type and every value documented here
    {docs_v1, _, ernest, _, _, _, Entries} = ern_prelude:docs(),
    ?assertEqual(length(ern_prelude:builtin_types()) + length(Declarations) + length(Own),
                 length(Entries)).

in_module_docs(Namespace, Name) ->
    ErlangModule = list_to_atom("ern@" ++ string:lowercase(atom_to_list(Namespace))),
    case code:which(ErlangModule) of
        File when is_list(File) ->
            {ok, {_, [{"Docs", Chunk}]}} = beam_lib:chunks(File, ["Docs"]),
            {docs_v1, _, _, _, _, _, Entries} = binary_to_term(Chunk),
            lists:any(fun({{_, EntryName, _}, _, _, _, _}) -> EntryName =:= Name end, Entries);
        _ ->
            false
    end.

%% report Appendix E.0 rule 1, E.1, E.3, E.4, E.5, E.14, E.16, E.20, E.22:
%% the primitives a module's section names are the module's `foreign fn`s.
%% An exported one is named as itself; a private one by the exported
%% declaration that alone calls it, `slice` for String's `part`; one that
%% only system references call, a system module's (§8.2), by the exported
%% functions that reach them, since in a system module a function that
%% reaches its process is a primitive; or else by its own name.
primitives_test() ->
    [begin
         {ok, Source} = file:read_file(stdlib_file(Namespace)),
         {ok, Declarations} = ern_parser:parse_string(Source),
         ?assertEqual({Namespace, lists:sort(Named)},
                      {Namespace, lists:sort(foreign_names(Declarations))})
     end || {Namespace, Body} <- namespaces(section("## Appendix E.", "## Appendix F")),
            Named <- [primitives(Body)], Named =/= []].

%% The names in backticks of a section's sentence "The primitives are ...".
primitives(Body) ->
    Text = lists:append(Body),
    case string:find(Text, "The primitives are") of
        nomatch -> [];
        Found ->
            [Sentence | _] = string:split(Found, "(E.0 rule 1)"),
            {match, Names} = re:run(Sentence, "`(\\w+)`", [global, {capture, [1], list}]),
            [list_to_atom(Name) || [Name] <- Names]
    end.

stdlib_file(Namespace) ->
    filename:join("../../../stdlib", ern_namespace:module_path(Namespace) ++ ".ern").

%% Each foreign fn under the name the report gives it.
foreign_names(Declarations) ->
    Callers = fun(Name) ->
                  [Declaration || Declaration <- Declarations,
                                  not is_record(Declaration, foreign_fn_declaration),
                                  lists:member(Name, free_names(Declaration))]
              end,
    lists:append(
      [case {Export, Callers(Name)} of
           {true, _} -> [Name];
           {false, [#fn_declaration{export = true, name = Caller}]} -> [Caller];
           {false, [#let_declaration{export = true, name = Caller}]} -> [Caller];
           {false, [_ | _] = References} ->
               LetNames = [LetName
                           || #let_declaration{export = false, name = LetName} <- References],
               case length(LetNames) =:= length(References) of
                   true -> reaching(LetNames, Declarations);
                   false -> [Name]
               end;
           {false, _} -> [Name]
       end || #foreign_fn_declaration{name = Name, export = Export} <- Declarations]).

%% The exported declarations that reach one of the names, directly or
%% through private ones.
reaching(Names, Declarations) ->
    Reach = [Declaration || Declaration <- Declarations,
                            not is_record(Declaration, foreign_fn_declaration),
                            lists:any(fun(Name) -> lists:member(Name, free_names(Declaration)) end,
                                      Names)],
    Exported = [Name || Declaration <- Reach, {true, Name} <- [export_name(Declaration)]],
    case [Name || Declaration <- Reach, {false, Name} <- [export_name(Declaration)]] -- Names of
        [] -> lists:usort(Exported);
        Private -> lists:usort(Exported ++ reaching(Names ++ Private, Declarations))
    end.

export_name(#fn_declaration{export = Export, name = Name}) -> {Export, Name};
export_name(#let_declaration{export = Export, name = Name}) -> {Export, Name}.

%% The names a function's parameters bind, which are not calls.
params(#fn_declaration{params = Params}) ->
    [Name || #param{pattern = Pattern} <- Params, {Name, _} <- ern_ast:pattern_bindings(Pattern)];
params(_) -> [].

body(#fn_declaration{body = Body}) -> Body;
body(#let_declaration{body = Body}) -> Body;
body(_) -> [].

%% The names a declaration's body refers to, outside its parameters.
free_names(Declaration) ->
    ern_ast:free_names(body(Declaration), params(Declaration)).

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
                          [[{Namespace, Declaration}
                            || Declaration <- declarations(code_lines(Body))]
                           || {Namespace, Body} <- Sections])),
    Compiled = [{Namespace, rename(compiled_declaration(TypeInfo, stdlib_file(Namespace)))}
                || #interface{namespace = Namespace, types = Types}
                       <- ern_prelude:stdlib_interfaces(),
                   TypeInfo <- maps:values(Types)],
    same(lists:sort([{Namespace, rename(Declaration)} || {Namespace, Declaration} <- Report]),
         lists:sort(Compiled)).

%% report Appendix E.0 rule 2: the words rule 2 gives a set and a map are
%% functions of `Set` and `Map`, which rule 4 admits as the vocabulary. A
%% regression test, written when rule 2 named them (findings.md's R-6)
set_and_map_words_test() ->
    Rules = lists:flatten(lists:join(" ", section("Four *admission rules*", "Nine *shape rules*"))),
    Exported = lists:append([maps:keys(Values)
                             || #interface{values = Values} <- ern_prelude:stdlib_interfaces()]),
    lists:foreach(
      fun({Kind, Module}) ->
          {match, [Sentence]} = re:run(Rules, "A " ++ Kind ++ " adds ([^.]*)\\.",
                                       [{capture, all_but_first, list}]),
          {match, Words} = re:run(Sentence, "`([a-zA-Z]+)`",
                                  [global, {capture, all_but_first, list}]),
          ?assertNotEqual([], Words),
          [?assert(lists:member([Module, list_to_atom(Word)], Exported)) || [Word] <- Words]
      end, [{"set", 'Set'}, {"map", 'Map'}]).

%% report Appendix G: every library under libs/ has a section, and each
%% section's signatures and types are the library's compiled interface,
%% as Appendix E's are the standard library's
libraries_test() ->
    %% Appendix G is the report's last, so its section runs to the report's
    %% end, a heading of Appendix H never being met
    Sections = libraries(section("## Appendix G.", "## Appendix H")),
    Dirs = [filename:basename(Dir) || Dir <- filelib:wildcard("../../../libs/*"),
                                      filelib:is_dir(Dir)],
    ?assertEqual(lists:sort(Dirs), lists:sort([Library || {Library, _, _} <- Sections])),
    TypeState = ern_typecheck:type_state(ern_typecheck:prelude_env()),
    lists:foreach(
      fun({Library, Namespace, Body}) ->
          SourceFile = filename:join(["../../../libs", Library, Library ++ ".ern"]),
          {ok, Erc} = file:read_file(filename:join(["../../../build/libs", Library,
                                                    Library ++ ".erc"])),
          {ok, #{interface := #interface{namespace = Namespace, types = Types,
                                         values = Values}}} = ern_interface:read(Erc),
          same(lists:sort(lists:append([signature(Line) || Line <- code_lines(Body)])),
               lists:sort([{ern_namespace:text(QualifiedName),
                            printed(QualifiedName, Scheme, TypeState)}
                           || {QualifiedName, Scheme} <- maps:to_list(Values)])),
          same(lists:sort([rename(unmarked(Declaration))
                           || Declaration <- declarations(code_lines(Body))]),
               lists:sort([rename(compiled_declaration(TypeInfo, SourceFile))
                           || TypeInfo <- maps:values(Types)]))
      end, Sections).

%% A value's type as the report writes it: without the marks of the
%% inferred restrictions, and its own module's types unqualified.
printed(QualifiedName, Scheme, TypeState) ->
    normalize(own(QualifiedName, unmarked(ern_types:format_scheme(Scheme, TypeState)))).

%% A printed type without the marks of the inferred restrictions.
unmarked(Text) ->
    re:replace(Text, "\\b([a-z][a-z0-9]*)[=!+]+", "\\1", [global, {return, list}]).

%% A type text with the names of the value's own module unqualified.
own(QualifiedName, Text) ->
    Prefix = ern_namespace:text(lists:droplast(QualifiedName)),
    re:replace(Text, "\\b" ++ Prefix ++ "\\.(?=[A-Z])", "", [global, {return, list}]).

%% `type T(p, q) = ...` with its parameters renamed a, b, ... in order.
rename(Declaration) ->
    case re:run(Declaration, "^(?:foreign |abstract )?type \\w+\\(([^)]*)\\)",
                [{capture, all_but_first, list}]) of
        {match, [ParamsText]} ->
            Params = [string:trim(Param) || Param <- string:split(ParamsText, ",", all)],
            Fresh = [[Char] || Char <- lists:seq($a, $a + length(Params) - 1)],
            lists:foldl(fun({Param, FreshName}, Acc) ->
                            re:replace(Acc, "\\b" ++ Param ++ "\\b", FreshName,
                                       [global, {return, list}])
                        end, Declaration, lists:zip(Params, Fresh));
        nomatch ->
            Declaration
    end.

%% A compiled type's declaration, as the appendix writes it, the field
%% order read from the module's source.
compiled_declaration(#type_info{foreign = true, qualified_name = QualifiedName,
                                params = Params},
                     _SourceFile) ->
    %% report §3.8: a foreign type has no constructors, and its parameters
    %% are names rather than variables
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", [atom_to_list(Param) || Param <- Params]) ++ ")"
           end,
    normalize(lists:flatten(["foreign type ", atom_to_list(lists:last(QualifiedName)), Head]));
compiled_declaration(#type_info{abstract = true, qualified_name = QualifiedName, params = Params},
                     _SourceFile) ->
    %% report §4.4: an abstract type is listed without its constructors, its
    %% parameters named in order
    Letters = [[Char] || Char <- lists:seq($a, $a + length(Params) - 1)],
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", Letters) ++ ")"
           end,
    lists:flatten(["abstract type ", atom_to_list(lists:last(QualifiedName)), Head]);
compiled_declaration(#type_info{qualified_name = QualifiedName, params = Params,
                                constructors = Constructors},
                     SourceFile) ->
    Namespace = lists:droplast(QualifiedName),
    Names = maps:from_list(lists:zip([Id || {tvar, Id} <- Params],
                                     [[Char] || Char <- lists:seq($a, $a + length(Params) - 1)])),
    Head = case Params of
               [] -> "";
               _ -> "(" ++ lists:join(", ", [maps:get(Id, Names) || {tvar, Id} <- Params]) ++ ")"
           end,
    Order = declared_fields(SourceFile),
    ConstructorTexts = [constructor_text(ConstructorInfo, Namespace, Names, Order)
                        || ConstructorInfo <- Constructors],
    normalize(lists:flatten(["type ", atom_to_list(lists:last(QualifiedName)), Head, " = ",
                             lists:join(" | ", ConstructorTexts)])).

%% The field names of each constructor of a module's source, in the order
%% declared, which the interface does not keep (its fields are canonical).
declared_fields(File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    Types = [TypeDeclaration || #type_declaration{} = TypeDeclaration <- Declarations]
        ++ [TypeDeclaration
            || #abstract_declaration{declaration = TypeDeclaration} <- Declarations],
    maps:from_list([{Constructor, [Field || #field{name = Field} <- Fields]}
                    || #type_declaration{constructors = Constructors} <- Types,
                       #constructor{name = Constructor, fields = {named, Fields}} <- Constructors]).

constructor_text(#constructor_info{name = Constructor, fields = Fields, scheme = Scheme},
                 Namespace, Names, Order) ->
    Name = atom_to_list(Constructor),
    FieldTypes = case Scheme of
                     #scheme{type = {tfn, ParamTypes, _, _}} -> ParamTypes;
                     _ -> []
                 end,
    case {Fields, FieldTypes} of
        {none, _} -> Name;
        {positional, [Type]} -> Name ++ "(" ++ type_text(Type, Namespace, Names) ++ ")";
        {{named, FieldNames}, Types} ->
            Typed = lists:zip(FieldNames, Types),
            Declared = maps:get(Constructor, Order),
            FieldText = fun(Field) ->
                            atom_to_list(Field) ++ " : "
                                ++ type_text(proplists:get_value(Field, Typed), Namespace, Names)
                        end,
            Name ++ "(" ++ lists:join(", ", [FieldText(Field) || Field <- Declared]) ++ ")"
    end.

type_text({tvar, Id}, _, Names) -> maps:get(Id, Names);
type_text({tcon, QualifiedName, Args}, Namespace, Names) ->
    Text = case lists:droplast(QualifiedName) of
               Namespace -> atom_to_list(lists:last(QualifiedName));
               _ -> ern_namespace:text(QualifiedName)
           end,
    case Args of
        [] -> Text;
        _ ->
            Text ++ "(" ++ lists:join(", ", [type_text(Arg, Namespace, Names) || Arg <- Args])
                ++ ")"
    end;
type_text({ttuple, Elements}, Namespace, Names) ->
    "#(" ++ lists:join(", ", [type_text(Element, Namespace, Names) || Element <- Elements]) ++ ")";
type_text({tfn, Params, Effect, Result}, Namespace, Names) ->
    ParamsText = [type_text(Param, Namespace, Names) || Param <- Params],
    Arrow = "(" ++ lists:join(", ", ParamsText) ++ ") -> " ++ type_text(Result, Namespace, Names),
    case Effect of
        pure -> Arrow;
        _ -> Arrow ++ " with " ++ type_text(Effect, Namespace, Names)
    end.

%% report §3.1, §9.1, §9.2: the built-in types and their arities
builtin_types_test() ->
    Base = [{list_to_atom(Name), 0}
            || Line <- section("### 3.1", "**Integer arithmetic"),
               [Name] <- [captures(Line, "^\\| `([A-Z]\\w*)`")]],
    Named = [{list_to_atom(Name), arity(ParamsText)}
             || Line <- code_lines(section("### 9.1", "### 9.3")),
                [Name, ParamsText] <- [captures(Line, "^([A-Z]\\w*)(\\([^)]*\\)|) ")]],
    same(lists:sort(Base ++ Named),
         lists:sort([{Name, Arity} || {Name, Arity, _} <- ern_prelude:builtin_types()])).

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
    {ok, Contents} = file:read_file(?REPORT),
    Lines = string:split(unicode:characters_to_list(Contents), "\n", all),
    Rest = lists:dropwhile(fun(Line) -> not lists:prefix(From, Line) end, Lines),
    lists:takewhile(fun(Line) -> not lists:prefix(To, Line) end, tl(Rest)).

%% The lines inside ``` fences.
code_lines(Lines) -> code_lines(Lines, false).

code_lines([], _) -> [];
code_lines(["```" ++ _ | Lines], InFence) -> code_lines(Lines, not InFence);
code_lines([Line | Lines], true) -> [Line | code_lines(Lines, true)];
code_lines([_ | Lines], false) -> code_lines(Lines, false).

%% Appendix E's sections, each with its namespace from the heading.
namespaces([]) -> [];
namespaces([Heading | Lines]) ->
    case captures(Heading, "^### Appendix E\\.\\d+\\. `\\w+\\.ern` \\(namespace `(\\w+)`\\)") of
        [Namespace] ->
            {Body, Rest} = lists:splitwith(fun(Line) -> not lists:prefix("### ", Line) end, Lines),
            [{[list_to_atom(Namespace)], Body} | namespaces(Rest)];
        _ -> namespaces(Lines)
    end.

%% Appendix G's sections, each with its library's directory and namespace
%% from the heading.
libraries([]) -> [];
libraries([Heading | Lines]) ->
    case captures(Heading, "^### Appendix G\\.\\d+\\. `libs/(\\w+)` \\(namespace `(\\w+)`\\)") of
        [Library, Namespace] ->
            {Body, Rest} = lists:splitwith(fun(Line) -> not lists:prefix("### ", Line) end, Lines),
            [{Library, [list_to_atom(Namespace)], Body} | libraries(Rest)];
        _ -> libraries(Lines)
    end.

%% A signature line, `Name, Name : Type // comment`, as {name, type} pairs;
%% any other line as [].
signature([First | _] = Line) when First =/= $\s, First =/= $= , First =/= $| ->
    case re:split(Line, "\\s+:\\s+", [unicode, {return, list}, {parts, 2}]) of
        [Names, TypeAndComment] ->
            NamePattern = "[A-Za-z][\\w.]*(\\.[-+*/%<>]+)?",
            case re:run(Names, "^" ++ NamePattern ++ "(,\\s*" ++ NamePattern ++ ")*$", [unicode]) of
                {match, _} ->
                    Type = normalize(hd(string:split(TypeAndComment, "//"))),
                    [{string:trim(Name), Type} || Name <- string:split(Names, ",", all)];
                nomatch -> []
            end;
        _ -> []
    end;
signature(_) -> [].

%% Type declarations in the lines, comments stripped, one string each: a
%% declaration starts at a `type` line and continues over indented lines.
declarations(Lines) ->
    Stripped = [string:trim(hd(string:split(Line, "//")), trailing) || Line <- Lines],
    lists:sort([normalize(Declaration) || Declaration <- group(Stripped)]).

group([]) -> [];
group([Line | Lines]) ->
    case is_declaration(Line) of
        true ->
            {Continued, Rest} = lists:splitwith(fun continuation/1, Lines),
            [lists:flatten(lists:join(" ", [Line | Continued])) | group(Rest)];
        false -> group(Lines)
    end.

is_declaration("type " ++ _) -> true;
is_declaration("foreign type " ++ _) -> true;
is_declaration("abstract type " ++ _) -> true;
is_declaration(_) -> false.

continuation(" " ++ _) -> true;
continuation(_) -> false.

captures(Line, Pattern) ->
    case re:run(Line, Pattern, [unicode, {capture, all_but_first, list}]) of
        {match, Captured} -> Captured;
        nomatch -> nomatch
    end.

arity("") -> 0;
arity(Params) -> length(string:split(Params, ",", all)).

normalize(Text) -> re:replace(string:trim(Text), "\\s+", " ", [global, unicode, {return, list}]).
