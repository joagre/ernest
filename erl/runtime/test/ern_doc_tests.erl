%% The documentation rules of report §2.2 and Appendix E.0 shape rule 6, checked
%% over every standard library module written in Ernest, every library
%% under src/libs/, which keeps the standard library's discipline (plan, MVP
%% 2.7), and the fictive module that docs/module_doc_template.md shows. The
%% examples are run by `ern test` alone (report §11.2): the library's by
%% `make test-library`, and the template's and the prelude's page's here,
%% which no build of the library holds.
-module(ern_doc_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").

-define(ROOT, "../../..").

%% The modules checked: the template, every file under src/stdlib/, and every
%% library's top module under src/libs/.
modules() ->
    [{['Template'], filename:join(?ROOT, "test/fixtures/programs/template.ern")}
     | [{ern_namespace:namespace([filename:basename(File, ".ern")]), File}
        || File <- filelib:wildcard(filename:join(?ROOT, "src/stdlib/*.ern"))
               ++ filelib:wildcard(filename:join(?ROOT, "src/libs/*/*.ern")),
           %% an editor's lock file beside a source, `.#name.ern`, is no module
           not lists:prefix(".#", filename:basename(File))]].

%% Appendix E.0 shape rule 6: the standard library is checked, not only the template
stdlib_present_test() ->
    ?assert(length(modules()) >= 2).

%% report §9, Appendix E.0 shape rule 6: the prelude's page is documented as a
%% module's is, so it holds examples, and every function it documents is
%% called by one of them
prelude_called_test() ->
    Fences = iolist_to_binary([Block || Doc <- prelude_docs(), Block <- fences(Doc)]),
    ?assertNotEqual(<<>>, Fences),
    Functions = [ern_namespace:text(QualifiedName)
                 || {QualifiedName, Text, ValueDoc} <- ern_prelude:values(), is_binary(ValueDoc),
                    hd(QualifiedName) =/= 'Sys',
                    lists:prefix("(", Text)],
    Uncalled = [Function || Function <- Functions,
                            binary:match(Fences, list_to_binary([Function, "("])) =:= nomatch],
    ?assertEqual([], Uncalled).

prelude_docs() ->
    {docs_v1, _, _, _, #{<<"en">> := ModuleDoc}, _, Entries} = ern_prelude:docs(),
    [ModuleDoc | [Doc || {_, _, _, #{<<"en">> := Doc}, _} <- Entries]].

%% report §11.2, Appendix E.0 shape rule 6: the template's examples run under
%% `ern test`, the one checker of the examples, the private declaration's
%% inside the module, and each passes. A regression test, written after the
%% code: this module ran every example itself until `ern test` was their
%% one checker; it does not cover an example that fails, which the CLI's
%% tests of `ern test` do
template_examples_test_() ->
    {timeout, 60, fun template_examples/0}.

template_examples() ->
    Dir = tmp(),
    Programs = filename:join(?ROOT, "test/fixtures/programs"),
    Template = filename:join(Programs, "template.ern"),
    ?assertEqual(0, ern_cli:ern(["build", "--source-root", Programs, "--build-root", Dir,
                                 Template])),
    {ok, Source} = file:read_file(Template),
    {ok, Declarations} = ern_parser:parse_string(Source),
    passed(filename:join(Dir, "template.erc"),
           [Block || Doc <- docs(Declarations), Block <- fences(Doc)]).

%% report §11.2, §9, §11.4, Appendix E.0 shape rule 6: the prelude's page's
%% examples, which no module's `.erc` holds, run under `ern test` as the
%% examples of a module's own doc block, each a program of its own, and
%% each passes. A regression test, written after the code, as the
%% template's; a case is named by its number on the page and not by the
%% declaration it documents, and the blocks are read from the prelude's
%% documentation, not from the page `ern doc` writes of it
prelude_examples_test_() ->
    {timeout, 60, fun prelude_examples/0}.

prelude_examples() ->
    Dir = tmp(),
    Blocks = [Block || Doc <- prelude_docs(), Block <- fences(Doc)],
    Fenced = [["///\n/// ```ernest\n",
               [["///", [[" ", Line] || Line =/= <<>>], "\n"]
                || Line <- binary:split(Block, <<"\n">>, [global])],
               "/// ```\n"]
              || Block <- Blocks],
    Page = filename:join([Dir, "src", "prelude_page.ern"]),
    ok = filelib:ensure_dir(Page),
    ok = file:write_file(Page, ["/// The prelude's page's examples, in its order.\n", Fenced,
                                "\nlet page = Unit\n"]),
    ?assertEqual(0, ern_cli:ern(["build", "--build-root", Dir ++ "/build", Dir ++ "/src"])),
    passed(Dir ++ "/build/prelude_page.erc", Blocks).

%% A directory of the test's own, under the run's, which `make` removes
%% when the run ends (erl/app.mk).
tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_doc_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% Report §11.2, §11.8: `ern test` of the compiled module passes, a case for
%% each of the examples, Blocks, as the lines it writes say, which EUnit's
%% group leader holds.
passed(Erc, Blocks) ->
    ?assertNotEqual([], Blocks),
    ?assertEqual(0, ern_cli:ern(["test", Erc])),
    group_leader() ! {get_output, self()},
    Output = receive {output, Captured} -> iolist_to_binary(Captured) end,
    ?assertEqual(length(Blocks), length(binary:matches(Output, <<": passed\n">>))).

%% Appendix E, Appendix G, report §11.5, §3.9: every listed function's type
%% is the type its module's interface prints, its inferred restrictions
%% marked and the module's own types written without its namespace, so that
%% the report states each function's whole contract. A test of the full
%% review's K20 (2026-10-04), whose first run found every difference to be a
%% mark or a namespace, no signature drifted
listings_are_the_interfaces_test() ->
    Printed = maps:from_list(
                [{ern_namespace:text(QualifiedName),
                  ern_types:format_scheme(Scheme, ern_types:new())}
                 || #interface{values = Values} <- ern_prelude:stdlib_interfaces() ++ libraries([]),
                    {QualifiedName, Scheme} <- maps:to_list(Values)]),
    {ok, Report} = file:read_file(filename:join(?ROOT, "report/library.md")),
    Listed = listed(binary:split(Report, <<"\n">>, [global]), outside, []),
    ?assert(length(Listed) > 300),
    Differing = [{Name, Written, Expected}
                 || {Name, Written} <- Listed,
                    Expected <- [own_plain(Name, maps:get(Name, Printed, missing))],
                    Written =/= Expected],
    ?assertEqual([], Differing).

%% The `Name.function : type` lines of the plain fenced blocks, each with its
%% type as written, a comment after `//` left out.
listed([<<"```", Language/binary>> | Lines], outside, Acc) ->
    listed(Lines, {inside, Language =:= <<>>}, Acc);
listed([<<"```", _/binary>> | Lines], {inside, _}, Acc) ->
    listed(Lines, outside, Acc);
listed([Line | Lines], {inside, true} = State, Acc) ->
    case re:run(Line, "^([A-Z]\\w*(?:\\.\\w+)*\\.(?:\\w+|[-+*/%<>]+)) : (.*?)(?: //.*)?$",
                [{capture, all_but_first, list}, unicode]) of
        {match, [Name, Type]} -> listed(Lines, State, [{Name, Type} | Acc]);
        nomatch -> listed(Lines, State, Acc)
    end;
listed([_ | Lines], State, Acc) ->
    listed(Lines, State, Acc);
listed([], _, Acc) ->
    lists:reverse(Acc).

%% A printed type as its module's section writes it, its own types plain.
own_plain(_, missing) ->
    missing;
own_plain(Name, Type) ->
    [Module | _] = string:split(Name, "."),
    re:replace(Type, "\\b" ++ Module ++ "\\.(?=[A-Z])", "", [global, {return, list}, unicode]).

%% Report §11.1, Appendix G: a library's module is checked with the other
%% libraries' interfaces, as a program has them on its load path; libs/markdown
%% uses libs/ansi.
libraries(Namespace) ->
    [Interface || File <- filelib:wildcard(filename:join(?ROOT, "build/libs/*/*.erc")),
                  {ok, Bytes} <- [file:read_file(File)],
                  {ok, #{interface := Interface}} <- [ern_interface:read(Bytes)],
                  Interface#interface.namespace =/= Namespace].

%% Appendix E.0 shape rule 6, docs/release_review.md step 5: the module's
%% doc block ends with `since v`, and a declaration may state its own. A
%% module, and an exported declaration, says the release that first
%% shipped it, the first tag that holds it, a declaration without a line of
%% its own saying its module's; one no tag holds says a release after the
%% last tag, its next patch, minor or major. A tag holds a declaration of
%% that kind and name. A regression test: OrderedSet and OrderedMap, new
%% after 0.2.0, said 0.2.0, and `Os.user` inherited 0.1.0, which the test
%% before it, that no line is newer than VERSION, let through
doc_since_test_() ->
    [{atom_to_list(hd(Namespace)), fun() -> since(File) end} || {Namespace, File} <- modules()].

since(File) ->
    Tags = tags(),
    ?assertNotEqual([], Tags),
    "../../../" ++ Relative = File,
    Shipped = [{Version, shipped(Tag, Relative)} || {Version, Tag} <- Tags],
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    ModuleDocs = [Text || #module_doc{text = Text} <- Declarations],
    ?assertMatch([_], ModuleDocs),
    ModuleSince = since_of(hd(ModuleDocs)),
    ?assertNotEqual(none, ModuleSince),
    First = [Version || {Version, Keys} <- Shipped, Keys =/= none],
    ?assertEqual([], [{module, ModuleSince} || not is_release(ModuleSince, First, Tags)]),
    Wrong = [{Key, Since} || Declaration <- Declarations,
                             exported_declaration(Declaration) =:= true,
                             Key <- [declaration_key(Declaration)],
                             Since <- [own_since(Declaration, ModuleSince)],
                             not is_release(Since, [Version || {Version, Keys} <- Shipped,
                                                               Keys =/= none,
                                                               lists:member(Key, Keys)],
                                            Tags)],
    ?assertEqual([], Wrong).

%% docs/release_review.md, step 5, report §8.7, Appendix H: a patch release
%% adds nothing and stands on its minor's floor: where VERSION names a
%% release no tag holds yet, a patch of the last tag's minor, the library's
%% listings, the form's version and the protocol's version are the last
%% tag's. Before a release VERSION names the last tag's, and nothing is
%% compared. A tag's are read from its source's lines, since the code of
%% today need not read it, and today's the same way. Written after the code
%% (findings H5, H10); it compares the listings' lines and not what they
%% mean, and a patch that moves a listing's comment alone fails it
patch_floor_test() ->
    {ok, VersionText} = file:read_file(filename:join(?ROOT, "VERSION")),
    [Major, Minor, Patch] = version(VersionText),
    {[LastMajor, LastMinor, LastPatch], Tag} = lists:last(tags()),
    case {Major, Minor} =:= {LastMajor, LastMinor} andalso Patch > LastPatch of
        true ->
            Tagged = fun(Path) -> list_to_binary(os:cmd("git -C " ++ ?ROOT ++ " show " ++ Tag
                                                        ++ ":" ++ Path ++ " 2>/dev/null")) end,
            Today = fun(Path) ->
                        case file:read_file(filename:join(?ROOT, Path)) of
                            {ok, Text} -> Text;
                            {error, enoent} -> <<>>
                        end
                    end,
            ?assertEqual(patch_kept(Tagged), patch_kept(Today));
        false ->
            ok
    end.

%% What a patch keeps of a release, as Read reads each file: the listings'
%% lines, and the lines that define the form's version and the protocol's.
patch_kept(Read) ->
    Lines = fun(Path) -> binary:split(Read(Path), <<"\n">>, [global]) end,
    Defined = fun(Path, Prefix) ->
                  [Line || Line <- Lines(Path), binary:longest_common_prefix([Line, Prefix])
                                                    =:= byte_size(Prefix)]
              end,
    {listed(Lines("report/library.md"), outside, []),
     Defined("erl/checker/src/ern_canonical.erl", <<"-define(FORM_VERSION,">>),
     Defined("erl/cli/src/ern_carrier.erl", <<"-define(PROTOCOL,">>)}.

%% The repository's release tags, `v0.2.0`, oldest first, each with its
%% version.
tags() ->
    Output = os:cmd("git -C " ++ ?ROOT ++ " tag --list 'v*'"),
    lists:sort([{version(Version), Tag}
                || Tag <- string:lexemes(Output, "\n"), "v" ++ Version <- [Tag]]).

%% The exported declarations of the module at the tag, each its kind and
%% its name as the source writes them, or none where the tag has no such
%% file, at its path today or where the releases before the move held it.
%% A tag's source is read by its lines, since the parser of today need not
%% read it.
shipped(Tag, Relative) ->
    Show = fun(Path) -> os:cmd("git -C " ++ ?ROOT ++ " show " ++ Tag ++ ":" ++ Path
                               ++ " 2>/dev/null")
           end,
    case lists:dropwhile(fun(Text) -> Text =:= "" end,
                         [Show(Relative), Show(released(Relative))]) of
        [] -> none;
        [Text | _] ->
            Pattern = "^export\\s+(?:foreign\\s+|abstract\\s+)?(fn|let|type)\\s+([^\\s(:=]+)",
            Options = [global, multiline, unicode, {capture, all_but_first, list}],
            case re:run(unicode:characters_to_binary(Text), Pattern, Options) of
                {match, Keys} -> [{Kind, Name} || [Kind, Name] <- Keys];
                nomatch -> []
            end
    end.

%% Where the releases held a module that has moved since: the template
%% was examples/template.ern until it went among the programs kept for the
%% tests, and the standard library and the libraries stood at the top,
%% stdlib/ and libs/, until they went under src/ after 0.3.1.
released("test/fixtures/programs/template.ern") -> "examples/template.ern";
released("src/" ++ Relative) -> Relative;
released(Relative) -> Relative.

declaration_key(#fn_declaration{} = Declaration) -> {"fn", hd(declaration_names(Declaration))};
declaration_key(#foreign_fn_declaration{} = Declaration) ->
    {"fn", hd(declaration_names(Declaration))};
declaration_key(#let_declaration{} = Declaration) -> {"let", hd(declaration_names(Declaration))};
declaration_key(Declaration) -> {"type", hd(declaration_names(Declaration))}.

%% A declaration's own `since`, or its module's where it states none.
own_since(Declaration, ModuleSince) ->
    case doc_of(Declaration) of
        Doc when is_binary(Doc) ->
            case since_of(Doc) of
                none -> ModuleSince;
                Since -> Since
            end;
        _ -> ModuleSince
    end.

%% Whether a `since` names the release that first shipped what it is on,
%% the first of the versions that hold it, or, where none does, a release
%% after the last tag.
is_release(Since, [First | _], _Tags) ->
    version(Since) =:= First;
is_release(Since, [], Tags) ->
    {[Major, Minor, Patch], _} = lists:last(Tags),
    lists:member(version(Since), [[Major, Minor, Patch + 1], [Major, Minor + 1, 0],
                                  [Major + 1, 0, 0]]).

since_of(Doc) ->
    case re:run(Doc, "(?m)^since ([0-9][0-9.]*)\\s*$", [{capture, all_but_first, binary}]) of
        {match, [Since]} -> Since;
        nomatch -> none
    end.

version(Text) ->
    Trimmed = string:trim(unicode:characters_to_list(Text)),
    [list_to_integer(Part) || Part <- string:split(Trimmed, ".", all)].

%% Appendix E.0 shape rule 6: every exported declaration has a doc block
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

%% Appendix E.0 shape rule 6: a module's page holds examples, and every
%% exported function is called by one, the module's or its own; an operator
%% member, used infix, is not a call and is not looked for
doc_coverage_test_() ->
    [{atom_to_list(hd(Namespace)), fun() ->
                                       coverage(Namespace, File)
                                   end} || {Namespace, File} <- modules()].

coverage(Namespace, File) ->
    {ok, Source} = file:read_file(File),
    {ok, Declarations} = ern_parser:parse_string(Source),
    Examples = iolist_to_binary([Block || Doc <- docs(Declarations), Block <- fences(Doc)]),
    ?assertNotEqual(<<>>, Examples),
    Prefix = ern_namespace:text(Namespace),
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

%% Appendix E.0 shape rule 6: every backticked name under `See also` is a
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
        ++ [ern_namespace:text(QualifiedName) || {QualifiedName, _, _} <- ern_prelude:values()]
        ++ [ern_namespace:text(QualifiedName) || Interface <- ern_prelude:stdlib_interfaces(),
                                        QualifiedName <- maps:keys(Interface#interface.values)]
        ++ [ern_namespace:text(QualifiedName) || Interface <- ern_prelude:stdlib_interfaces(),
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

%% A node's doc block: undefined for a declaration without one, which
%% documented/1 looks for, and none for a node that carries no doc.
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
docs(Node) when is_tuple(Node) ->
    Own = case doc_of(Node) of
              Doc when is_binary(Doc) -> [Doc];
              _ -> []
          end,
    Own ++ docs(tuple_to_list(Node));
docs(Nodes) when is_list(Nodes) ->
    lists:append([docs(Child) || Child <- Nodes]);
docs(_) ->
    [].

fences(Doc) ->
    case re:run(Doc, "```ernest\\n(.*?)\\n```",
                [global, dotall, {capture, all_but_first, binary}]) of
        {match, Matches} -> [Block || [Block] <- Matches];
        nomatch -> []
    end.

%% plan MVP 2.5: every value a compiled standard library interface
%% declares is exported by its module with the arity of its type and its
%% requirement (report §4.9), as the function of the number the interface
%% gives it (report §11.1)
stdlib_targets_test() ->
    Missing = [{QualifiedName, Arity}
               || #interface{namespace = Namespace, values = Values,
                             positions = Positions} <- ern_prelude:stdlib_interfaces(),
                  {QualifiedName, Scheme} <- maps:to_list(Values),
                  Arity <- [arity(Scheme)],
                  ErlangModule <- [ern_namespace:erlang_module(Namespace)],
                  ern_code:ensure_loaded(ErlangModule) =/= {module, ErlangModule}
                      orelse not is_map_key(QualifiedName, Positions)
                      orelse not erlang:function_exported(
                                   ErlangModule,
                                   ern_emitter:function_name(maps:get(QualifiedName, Positions)),
                                   Arity)],
    ?assertEqual([], Missing),
    ?assertNotEqual([], ern_prelude:stdlib_interfaces()).

%% Report §4.9: a function's arity, and a parameter for each member its
%% requirement names.
arity(#scheme{type = {tfn, Params, _, _}, requirement = Requirement}) ->
    length(Params) + length(Requirement);
arity(_) -> 0.
