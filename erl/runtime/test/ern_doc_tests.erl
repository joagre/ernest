%% The documentation rules of report §2.2 and Appendix E.0 rule 6, checked
%% over every standard library module written in Ernest, every library
%% under libs/, which keeps the standard library's discipline (plan, MVP
%% 2.7), and the fictive module that docs/module_doc_template.md shows.
-module(ern_doc_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

-define(ROOT, "../../..").

%% The modules checked: the template, every file under stdlib/, and every
%% library's top module under libs/.
modules() ->
    [{['Template'], filename:join(?ROOT, "examples/template.ern")}
     | [{[list_to_atom(string:titlecase(filename:basename(File, ".ern")))], File}
        || File <- filelib:wildcard(filename:join(?ROOT, "stdlib/*.ern"))
               ++ filelib:wildcard(filename:join(?ROOT, "libs/*/*.ern"))]].

%% Appendix E.0 rule 6: the standard library is checked, not only the template
stdlib_present_test() ->
    ?assert(length(modules()) >= 2).

%% report §2.2, Appendix E.0 rule 6: every fenced Ernest block in a module's
%% doc blocks type-checks against the module as the body of a lambda, and
%% one that ends in `// => v` is run and its Io.show rendering compared
%% with v, so an example cannot rot
doc_examples_test_() ->
    [{atom_to_list(hd(Namespace)), fun() ->
                                       examples(Namespace, File)
                                   end} || {Namespace, File} <- modules()].

examples(Namespace, File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    check_examples(Namespace, Source, docs(Declarations, outside, [])).

%% report §9, Appendix E.0 rule 6: the prelude's page is documented as a
%% module's is, so its examples type-check and those with `// => v` run,
%% and every function it documents is called by one of them
prelude_examples_test_() ->
    {timeout, 60,
     fun() -> check_examples(['Docprelude'], <<>>, [{Doc, outside} || Doc <- prelude_docs()]) end}.

prelude_called_test() ->
    Fences = iolist_to_binary([Block || Doc <- prelude_docs(), Block <- fences(Doc)]),
    Functions = [lists:join(".", [atom_to_list(Part) || Part <- QualifiedName])
                 || {QualifiedName, Text, ValueDoc} <- ern_prelude:values(), is_binary(ValueDoc),
                    hd(QualifiedName) =/= 'Sys',
                    lists:prefix("(", Text)],
    Uncalled = [Function || Function <- Functions,
                            binary:match(Fences, list_to_binary([Function, "("])) =:= nomatch],
    ?assertEqual([], Uncalled).

prelude_docs() ->
    {docs_v1, _, _, _, #{<<"en">> := ModuleDoc}, _, Entries} = ern_prelude:docs(),
    [ModuleDoc | [Doc || {_, _, _, #{<<"en">> := Doc}, _} <- Entries]].

%% Appendix E.0 rule 6: each example type-checks where a programmer writes
%% it, in a module of its own that uses the documented one, so that a name
%% the module keeps private, or writes unqualified, is refused; the example
%% of a declaration the module keeps private speaks to the module's own
%% reader, and is checked inside it. A regression test: every example was
%% checked inside the module, where `Terminal.size`'s `Size` passed
%% (findings.md's E15)
check_examples(Namespace, Source, Docs) ->
    Blocks = [{split_result(Block), Where} || {Doc, Where} <- Docs, Block <- fences(Doc)],
    ?assert(Blocks =/= []),
    Numbered = lists:zip(lists:seq(1, length(Blocks)), [Block || {Block, _} <- Blocks]),
    Libraries = libraries(Namespace),
    {ok, _, Own, _} = checked(Namespace, Source, Libraries),
    lists:foreach(fun({{Number, {Body, _}}, Where}) ->
                      Example = <<"fn docExample", (integer_to_binary(Number))/binary,
                                  "() = fn() = {\n", Body/binary, "\n}\n">>,
                      Checked = case Where of
                                    outside ->
                                        {ok, Declarations} = ern_parser:parse_string(Example),
                                        ern_typecheck:check(['Docexample'], Declarations,
                                                            [Own | Libraries]);
                                    inside ->
                                        checked(Namespace, <<Source/binary, "\n", Example/binary>>,
                                                Libraries)
                                end,
                      ?assertMatch({{ok, _, _, _}, _}, {Checked, {Namespace, Number, Body}})
                  end, lists:zip(Numbered, [Where || {_, Where} <- Blocks])),
    WithResult = [{Number, Body, Value} || {Number, {Body, Value}} <- Numbered, Value =/= none],
    Fns = [<<"export fn docExample", (integer_to_binary(Number))/binary, "() = {\n", Body/binary,
             "\n}\n">> || {Number, Body, _} <- WithResult],
    Qualified = lists:join(".", [atom_to_list(Part) || Part <- Namespace]),
    Mains = [iolist_to_binary(["export fn docMain", integer_to_list(Number),
                               "() : Unit with Never =\n    Io.println(Io.show(", Qualified,
                               ".docExample", integer_to_list(Number), "()))\n"])
             || {Number, _, _} <- WithResult],
    Text = iolist_to_binary([Source, "\n", Fns, Mains]),
    {ok, Typed, Interface, Env} = checked(Namespace, Text, Libraries),
    {ok, ErlangModule, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env),
    Original = code:which(ErlangModule),
    {module, ErlangModule} = code:load_binary(ErlangModule, "doc examples", Beam),
    try
        %% Appendix E.0 rule 6: each example runs on its own, and the value
        %% it ends with is the last line it prints; what it prints itself,
        %% as an example of `foreach` does, comes before and is not compared
        lists:foreach(fun({Number, _, Value}) ->
                          run_example(ErlangModule, Number, Value)
                      end, WithResult)
    after
        restore(ErlangModule, Original)
    end.

run_example(ErlangModule, Number, Expected) ->
    %% Appendix E.0 rule 6: an example may touch the file system, so each
    %% runs in a directory of its own, removed afterwards
    {ok, Cwd} = file:get_cwd(),
    Dir = filename:join(["/tmp", "ern_doc_" ++ os:getpid() ++ "_"
                               ++ integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_path(Dir),
    ok = file:set_cwd(Dir),
    try
        run_example(ErlangModule, Number, Expected, Cwd)
    after
        file:set_cwd(Cwd),
        file:del_dir_r(Dir)
    end.

run_example(ErlangModule, Number, Expected, _Cwd) ->
    Main = list_to_atom("docMain" ++ integer_to_list(Number)),
    Self = self(),
    _ = collect([]),
    Init = fun() -> case erlang:function_exported(ErlangModule, '$init', 0) of
                        true -> ErlangModule:'$init'();
                        false -> ok
                    end
           end,
    %% the value goes to stdout, what the example prints itself may go to
    %% either sink, and the two are separate processes, so only stdout's
    %% last line is the value
    Result = ern_rt:run_main(fun() -> ErlangModule:Main() end, atom_to_binary(Main),
                             #{init => Init, stdout => fun(Bytes) -> Self ! {out, Bytes} end,
                               stderr => fun(Bytes) -> Self ! {err, Bytes} end}),
    ?assertEqual(ok, Result),
    Lines = binary:split(collect([]), <<"\n">>, [global, trim]),
    _ = collect(err, []),
    ?assertEqual(iolist_to_binary(Expected), lists:last(Lines)).

collect(Tag, Acc) ->
    receive {Tag, Bytes} -> collect(Tag, [Bytes | Acc])
    after 0 -> lists:reverse(Acc)
    end.

%% A standard library module's own beam comes back after its examples ran.
restore(ErlangModule, Original) when is_list(Original) ->
    code:purge(ErlangModule),
    {module, ErlangModule} = code:load_abs(filename:rootname(Original)),
    code:purge(ErlangModule);
restore(ErlangModule, _) ->
    code:purge(ErlangModule),
    code:delete(ErlangModule),
    code:purge(ErlangModule).

collect(Acc) ->
    receive
        {out, Bytes} -> collect([Bytes | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

%% Report §11.1, Appendix G: a library's module is checked with the other
%% libraries' interfaces, as a program has them on its load path; libs/markdown
%% uses libs/ansi.
libraries(Namespace) ->
    [Interface || File <- filelib:wildcard(filename:join(?ROOT, "build/libs/*/*.erc")),
                  {ok, Bytes} <- [file:read_file(File)],
                  {ok, #{interface := Interface}} <- [ern_interface:read(Bytes)],
                  Interface#interface.namespace =/= Namespace].

checked(Namespace, Text, Libraries) ->
    case ern_parser:parse_string(Text) of
        {ok, Declarations} -> ern_typecheck:check(Namespace, Declarations, Libraries);
        {error, Diagnostic} -> {error, [Diagnostic]}
    end.

%% An example's body and the value its last line `// => v` promises, or none.
split_result(Block) ->
    Lines = binary:split(Block, <<"\n">>, [global]),
    case lists:last(Lines) of
        <<"// => ", Value/binary>> ->
            {iolist_to_binary(lists:join(<<"\n">>, lists:droplast(Lines))), Value};
        _ -> {Block, none}
    end.

%% Appendix E.0 rule 6: the module's doc block ends with `since v`; a
%% declaration may state its own; every one is no newer than VERSION
doc_since_test_() ->
    [{atom_to_list(hd(Namespace)), fun() -> since(File) end} || {Namespace, File} <- modules()].

since(File) ->
    {ok, VersionText} = file:read_file(filename:join(?ROOT, "VERSION")),
    Current = version(VersionText),
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    ModuleDocs = [Text || #module_doc{text = Text} <- Declarations],
    ?assertMatch([_], ModuleDocs),
    ?assertNotEqual(none, since_of(hd(ModuleDocs))),
    Stated = [Since || Doc <- docs(Declarations), Since <- [since_of(Doc)], Since =/= none],
    ?assertEqual([], [Since || Since <- Stated, version(Since) > Current]).

since_of(Doc) ->
    case re:run(Doc, "(?m)^since ([0-9][0-9.]*)\\s*$", [{capture, all_but_first, binary}]) of
        {match, [Since]} -> Since;
        nomatch -> none
    end.

version(Text) ->
    Trimmed = string:trim(unicode:characters_to_list(Text)),
    [list_to_integer(Part) || Part <- string:split(Trimmed, ".", all)].

%% Appendix E.0 rule 6: every exported declaration has a doc block
doc_exported_documented_test_() ->
    [{atom_to_list(hd(Namespace)), fun() ->
                                       documented(File)
                                   end} || {Namespace, File} <- modules()].

documented(File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    ?assertEqual([], [declaration_names(Declaration) || Declaration <- Declarations,
                                                        exported_declaration(Declaration) =:= true,
                                                        doc_of(Declaration) =:= undefined]).

%% Appendix E.0 rule 6: every exported function is called by an example on
%% the page, the module's or its own; an operator member, used infix, is
%% not a call and is not looked for
doc_coverage_test_() ->
    [{atom_to_list(hd(Namespace)), fun() ->
                                       coverage(Namespace, File)
                                   end} || {Namespace, File} <- modules()].

coverage(Namespace, File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    Examples = iolist_to_binary([Block || Doc <- docs(Declarations), Block <- fences(Doc)]),
    Prefix = lists:join(".", [atom_to_list(Part) || Part <- Namespace]),
    Fns = [local_name(MemberOf, Name)
           || #fn_declaration{export = true, member_of = MemberOf, name = Name} <- Declarations,
              is_alpha(Name)]
        ++ [local_name(MemberOf, Name)
            || #foreign_fn_declaration{export = true, member_of = MemberOf,
                                       name = Name} <- Declarations,
               is_alpha(Name)],
    %% a module exports something: `Test`, Appendix E.24, declares types alone
    Types = [Name || #type_declaration{export = true, name = Name} <- Declarations],
    ?assertNotEqual([], Fns ++ Types),
    Uncalled = [Function || Function <- Fns,
                            binary:match(Examples, iolist_to_binary([Prefix, ".", Function, "("]))
                                =:= nomatch],
    ?assertEqual([], Uncalled).

is_alpha(Name) ->
    [First | _] = atom_to_list(Name),
    First >= $a andalso First =< $z.

%% Appendix E.0 rule 6: every backticked name under `See also` is a
%% declaration of the module, a prelude or standard library namespace or
%% value, or a prelude type
doc_see_also_test_() ->
    [{atom_to_list(hd(Namespace)), fun() -> see_also(File) end} || {Namespace, File} <- modules()].

see_also(File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    Known = lists:append([declaration_names(Declaration) || Declaration <- Declarations])
        ++ [atom_to_list(hd(QualifiedName)) || {QualifiedName, _, _} <- ern_prelude:values(),
                                               length(QualifiedName) > 1]
        ++ [atom_to_list(hd(Interface#interface.namespace))
            || Interface <- ern_prelude:stdlib_interfaces()]
        ++ [atom_to_list(Name) || {Name, _, _} <- ern_prelude:builtin_types()]
        ++ [qualified(QualifiedName) || {QualifiedName, _, _} <- ern_prelude:values()]
        ++ [qualified(QualifiedName) || Interface <- ern_prelude:stdlib_interfaces(),
                                        QualifiedName <- maps:keys(Interface#interface.values)]
        ++ [qualified(QualifiedName) || Interface <- ern_prelude:stdlib_interfaces(),
                                        QualifiedName <- maps:keys(Interface#interface.types)],
    Named = [Name || Doc <- docs(Declarations),
                     {match, Sections}
                         <- [re:run(Doc, "#+ See also\\n\\n(.*?)(?=\\n#|$)",
                                    [global, dotall, {capture, all_but_first, list}])],
                     [Section] <- Sections,
                     {match, Matches} <- [re:run(Section, "`([^`]+)`",
                                                 [global, {capture, all_but_first, list}])],
                     [Name] <- Matches],
    ?assertEqual([], [Name || Name <- Named, not lists:member(Name, Known)]).

qualified(QualifiedName) ->
    lists:flatten(lists:join(".", [atom_to_list(Part) || Part <- QualifiedName])).

declaration_names(#type_declaration{name = Name}) -> [atom_to_list(Name)];
declaration_names(#abstract_declaration{declaration = #type_declaration{name = Name}}) ->
    [atom_to_list(Name)];
declaration_names(#fn_declaration{member_of = MemberOf, name = Name}) ->
    [local_name(MemberOf, Name)];
declaration_names(#let_declaration{name = Name}) -> [atom_to_list(Name)];
declaration_names(#foreign_fn_declaration{member_of = MemberOf, name = Name}) ->
    [local_name(MemberOf, Name)];
declaration_names(#foreign_type_declaration{name = Name}) -> [atom_to_list(Name)];
declaration_names(_) -> [].

local_name(undefined, Name) -> atom_to_list(Name);
local_name(MemberOf, Name) -> atom_to_list(MemberOf) ++ "." ++ atom_to_list(Name).

%% Whether a top-level declaration is exported; none for anything else.
exported_declaration(#type_declaration{export = Export}) -> Export;
exported_declaration(#abstract_declaration{export = Export}) -> Export;
exported_declaration(#fn_declaration{export = Export}) -> Export;
exported_declaration(#let_declaration{export = Export}) -> Export;
exported_declaration(#foreign_type_declaration{export = Export}) -> Export;
exported_declaration(#foreign_fn_declaration{export = Export}) -> Export;
exported_declaration(_) -> none.

%% A node's doc block, or none where it carries no doc.
doc_of(#module_doc{text = Doc}) -> Doc;
doc_of(#type_declaration{doc = Doc}) -> Doc;
doc_of(#abstract_declaration{doc = Doc}) -> Doc;
doc_of(#fn_declaration{doc = Doc}) -> Doc;
doc_of(#let_declaration{doc = Doc}) -> Doc;
doc_of(#foreign_type_declaration{doc = Doc}) -> Doc;
doc_of(#foreign_fn_declaration{doc = Doc}) -> Doc;
doc_of(#constructor{doc = Doc}) -> Doc;
doc_of(#field{doc = Doc}) -> Doc;
doc_of(_) -> none.

%% Every doc text in an AST.
docs(Node) ->
    [Doc || {Doc, _} <- docs(Node, outside, [])].

%% Every doc text in an AST, with where its examples are checked: outside
%% the module, or inside it within a declaration the module keeps private.
docs(Node, Where, Acc) when is_tuple(Node) ->
    Where1 = case exported_declaration(Node) of
                 false -> inside;
                 _ -> Where
             end,
    Acc1 = case doc_of(Node) of
               Doc when is_binary(Doc) -> [{Doc, Where1} | Acc];
               _ -> Acc
           end,
    lists:foldl(fun(Child, Found) -> docs(Child, Where1, Found) end, Acc1, tuple_to_list(Node));
docs(Nodes, Where, Acc) when is_list(Nodes) ->
    lists:foldl(fun(Child, Found) -> docs(Child, Where, Found) end, Acc, Nodes);
docs(_, _Where, Acc) -> Acc.

fences(Doc) ->
    case re:run(Doc, "```ernest\\n(.*?)\\n```",
                [global, dotall, {capture, all_but_first, binary}]) of
        {match, Matches} -> [Block || [Block] <- Matches];
        nomatch -> []
    end.

%% plan MVP 2.5: every value a compiled standard library interface
%% declares is exported by its module with the arity of its type
stdlib_targets_test() ->
    Missing = [{QualifiedName, Arity}
               || #interface{namespace = Namespace,
                             values = Values} <- ern_prelude:stdlib_interfaces(),
                  {QualifiedName, Scheme} <- maps:to_list(Values),
                  Arity <- [arity(Scheme)],
                  ErlangModule <- [module_atom(Namespace)],
                  code:ensure_loaded(ErlangModule) =/= {module, ErlangModule}
                      orelse not erlang:function_exported(ErlangModule,
                                                          lists:last(QualifiedName),
                                                          Arity)],
    ?assertEqual([], Missing),
    ?assertNotEqual([], ern_prelude:stdlib_interfaces()).

module_atom(Namespace) ->
    list_to_atom("ern@"
                 ++ string:lowercase(lists:join("@", [atom_to_list(Part) || Part <- Namespace]))).

arity(#scheme{type = {tfn, Params, _, _}}) -> length(Params);
arity(_) -> 0.
