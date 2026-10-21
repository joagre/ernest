%% Report §11.2, Appendix E.0 shape rule 6: the doc examples of a compiled
%% module as the cases `ern test` runs after its tests, each compiled in a
%% module of its own that uses the documented one, a private declaration's
%% inside the documented one, and each run as a program of its own in a
%% directory of its own.
-module(ern_examples).

-export([cases/2, in_directory/2, unload/1]).

-export_type([example/0]).

-include_lib("shared/include/ern_diagnostic.hrl").
-include_lib("checker/include/ern_types.hrl").

%% Report §11.2: the module an example is compiled in: its namespace, the
%% text before the example's, the interfaces it is checked against, the
%% build it is compiled with, whether its unit is the namespace's own or
%% one of a fresh name (example_module/6), and the units the example's
%% program initializes beside its own, as the run loaded them, the top
%% first (§8.5).
-record(example_module, {namespace, before = <<>>, interfaces, build, unit = own, uses}).

%% Report §11.2: an example's case, and the units its program initializes.
-type example() :: {{'Case', binary(), fun(() -> term())}, [module()]}.

%% The doc examples of the module Namespace, which the run has loaded with
%% the modules it uses, Loaded, its own first: each a case as a test is,
%% `{'Case', Name, Run}`, its run answering `'Passed'` or `{'Failed', Text}`,
%% with the units its program initializes (report §8.5), the top first: its
%% own and those it uses, the documented module's among them or, inside it,
%% the example's unit in its place, so that each is initialized once; none
%% for an example that does not run. Beside them the units their compiling
%% loaded, which unload/1 takes out once they have run. Report §11.2: an
%% example is named by the declaration it documents and its number among
%% that declaration's, `List.take example 2`, the module's own as `List
%% example 1`; the fenced `ernest` blocks of a type's constructors and
%% fields are the type's, after its own. The source a private declaration's
%% example is compiled inside is read once, where the module has one.
-spec cases([atom()], [module()]) -> {[example()], [module()]}.
cases(Namespace, [ErlangModule | _] = Loaded) ->
    Erc = code:which(ErlangModule),
    {ok, Beam} = file:read_file(Erc),
    Interfaces = [Interface || Unit <- lists:reverse(Loaded),
                               {ok, Compiled} <- [file:read_file(code:which(Unit))],
                               {ok, #{interface := Interface}} <- [ern_interface:read(Compiled)]],
    Examples = [{iolist_to_binary([Owner, " example ", integer_to_list(Number)]), Where, Block}
                || {Owner, Docs} <- documented(Namespace, Beam),
                   {Number, {Where, Block}} <- lists:enumerate([{Where, Block}
                                                                || {Where, Doc} <- Docs,
                                                                   Block <- fences(Doc)])],
    Module = case lists:keymember(inside, 2, Examples) of
                 true -> module_source(Namespace, Erc, Beam);
                 false -> none
             end,
    Compiled = [example(Name, Block, example_module(Where, Index, Namespace, Interfaces, Module,
                                                    Loaded))
                || {Index, {Name, Where, Block}} <- lists:enumerate(Examples)],
    {[Example || {Example, _} <- Compiled], [Unit || {_, Unit} <- Compiled, Unit =/= none]}.

%% Report §11.2: an example run by Run, its program, in an empty directory
%% of its own, made for it under the host's directory for temporary files,
%% `TMPDIR` or `/tmp`, and removed after it, whether it passed, failed or
%% faulted. The host's working directory is the node's and not a
%% process's, so it is the example's directory while its program runs,
%% where the program's start initializes the modules it uses and
%% `Os.workingDirectory` names it (Appendix E.23), and the run's again
%% after it. Where the run's directory cannot be read, or the example's
%% cannot be made, the case fails with the host's reason, and its program
%% initializes nothing; a directory the example left that cannot be removed
%% is said on standard error, as the runner says what stops a case.
-spec in_directory(example(), fun((example()) -> Outcome)) -> Outcome.
in_directory({{'Case', Name, _}, _} = Example, Run) ->
    %% an empty `TMPDIR` is none, as mktemp(1) takes it
    Base = case os:getenv("TMPDIR", "") of
               "" -> "/tmp";
               Given -> Given
           end,
    case file:get_cwd() of
        {ok, Working} ->
            case made_directory(Base) of
                {ok, Dir} ->
                    ok = file:set_cwd(Dir),
                    try
                        Run(Example)
                    after
                        ok = file:set_cwd(Working),
                        remove(Name, Dir)
                    end;
                {error, Error} ->
                    Run({failed(Name, ["its directory cannot be made under ", Base, ": ",
                                       file:format_error(Error)]), []})
            end;
        {error, Error} ->
            Run({failed(Name, ["the working directory cannot be read: ",
                               file:format_error(Error)]), []})
    end.

failed(Name, Text) ->
    Failed = {'Failed', unicode:characters_to_binary(Text)},
    {'Case', Name, fun() -> Failed end}.

%% A directory of a name no other holds, made empty under Base.
made_directory(Base) ->
    Dir = filename:join(Base, "ern_example_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    case file:make_dir(Dir) of
        ok -> {ok, Dir};
        {error, eexist} -> made_directory(Base);
        {error, _} = Error -> Error
    end.

remove(Name, Dir) ->
    case file:del_dir_r(Dir) of
        ok ->
            ok;
        {error, Error} ->
            ern_rt:send(ern_rt:system_process(stderr),
                        unicode:characters_to_binary(
                          ["ern test: the directory of ", ern_show:controls(Name, line), ", ",
                           Dir, ", cannot be removed: ", file:format_error(Error), "\n"]))
    end.

%% The units the examples' compiling loaded, the values their bindings
%% stored gone (report §8.5), deleted, out of the code table, and purged, as
%% the shell takes out a module of its own (ern_shell).
-spec unload([module()]) -> ok.
unload(Units) ->
    lists:foreach(fun(Unit) ->
                      lists:foreach(fun persistent_term:erase/1, ern_code:binding_keys(Unit)),
                      code:delete(Unit),
                      ern_code:unloaded(Unit),
                      code:purge(Unit)
                  end, Units).

%% Each declaration the module's documentation holds, as the program names
%% it, with its doc blocks, the module's own first, in the order the module
%% writes them (report §11.1, §11.4), each with where its examples are
%% compiled: outside the module, or inside it for what the module keeps
%% private, a declaration or an abstract type's constructors (report
%% §11.2, §4.4).
documented(Namespace, Beam) ->
    Module = ern_namespace:text(Namespace),
    case ern_docs:read(Beam) of
        {ok, {docs_v1, _, _, _, ModuleDoc, _, Entries}} ->
            [{Module, [{outside, Doc} || Doc <- texts([ModuleDoc])]}
             | [{[Module, ".", atom_to_binary(Name)],
                 [{where(Meta), Text} || Text <- texts([Doc])] ++ item_docs(Meta)}
                || {{_Kind, Name, _Arity}, _, _, Doc, Meta} <- Entries]];
        {error, _} ->
            []
    end.

where(#{private := true}) -> inside;
where(_) -> outside.

%% Report §11.2: the source of the module, Namespace, that its `.erc`, Erc,
%% was compiled from, as Beam records it, and whether it is the standard
%% library's own; or why no source holds the module as it was compiled:
%% gone, or changed since, which the `.erc`'s hash of it tells.
module_source(Namespace, Erc, Beam) ->
    {ok, #{source_path := SourcePath, source_hash := Hash}} = ern_interface:read(Beam),
    %% the build root lies as many directories up as the namespace is deep
    BuildRoot = lists:foldl(fun(_, Dir) -> filename:dirname(Dir) end, Erc, Namespace),
    File = filename:join(BuildRoot, unicode:characters_to_list(SourcePath)),
    Compiled = [ern_build:shown(Erc), " was compiled from ", ern_build:shown(File)],
    case file:read_file(File) of
        {ok, Source} ->
            case crypto:hash(sha256, Source) of
                Hash ->
                    SourceRoot = lists:foldl(fun(_, Dir) -> filename:dirname(Dir) end, File,
                                             Namespace),
                    {source, Source, ern_build:is_stdlib_root(SourceRoot)};
                _ ->
                    {error, [Compiled, ", which has changed since"]}
            end;
        {error, _} ->
            {error, [Compiled, ", which no longer exists"]}
    end.

%% Report §11.2: the module an example is compiled in. An exported
%% declaration's, and the module's own, is a module of its own,
%% `$Example3`, which uses the documented one, and whose program
%% initializes every module the run loaded; a private declaration's is the
%% module, its source with the example after it, under its namespace and
%% in a unit of its own, `ern@main$2`, so that the module's unit, which the
%% tests ran, is as it was, and whose program initializes that unit in the
%% module's place, so that the module's bindings are evaluated once in it
%% (§8.5). Or why the example has no module to be compiled in, its source
%% not as it was compiled.
example_module(outside, Index, _Namespace, Interfaces, _Module, Loaded) ->
    #example_module{namespace = [list_to_atom("$Example" ++ integer_to_list(Index))],
                    interfaces = Interfaces, build = #{source_hash => <<>>, deps => []},
                    uses = Loaded};
example_module(inside, _Index, Namespace, Interfaces, {source, Source, Standard},
               [_Documented | Used]) ->
    Others = [Interface || #interface{namespace = Other} = Interface <- Interfaces,
                           Other =/= Namespace],
    #example_module{namespace = Namespace, before = <<Source/binary, "\n">>, interfaces = Others,
                    build = #{source_hash => <<>>, deps => [], standard => Standard},
                    unit = fresh, uses = Used};
example_module(inside, _Index, _Namespace, _Interfaces, {error, _} = Error, _Loaded) ->
    Error.

texts(Docs) ->
    [Text || #{<<"en">> := Text} <- Docs].

%% A type's constructors' and their fields' doc blocks, in declared order,
%% each with where its examples are compiled: inside the module where the
%% type is private or the constructor is, as an abstract type's is.
item_docs(#{items := Items} = Meta) ->
    lists:append([[{Where, Doc} || is_binary(Doc)]
                  ++ [{Where, FieldDoc} || #{doc := FieldDoc} <- Fields, is_binary(FieldDoc)]
                  || #{doc := Doc, fields := Fields} = Item <- Items,
                     Where <- [item_where(Meta, Item)]]);
item_docs(_) ->
    [].

item_where(Meta, Item) ->
    case {where(Meta), where(Item)} of
        {outside, outside} -> outside;
        _ -> inside
    end.

%% Report §2.2: a doc block's fenced `ernest` blocks.
fences(Doc) ->
    case re:run(Doc, "```ernest\\n(.*?)\\n```", [global, dotall, {capture, all_but_first, binary}])
    of
        {match, Matches} -> [Block || [Block] <- Matches];
        nomatch -> []
    end.

%% One example, its case and the units its program initializes, and the
%% unit its compiling loaded, or none, compiled in its module. Report
%% §11.2, Appendix E.0 shape rule 6: an example that does not compile fails
%% with the diagnostic's message, the first of its errors; one that ends in
%% `// => v` runs, and fails where `Io.show` of its value is not `v`; one
%% without the line passes where it compiles. An example's function is
%% checked as a lambda's body where it runs nothing, so that it may
%% receive, and one that runs has the mailbox type Never, as an entry
%% point's left open has (report §8.1).
example(Name, _Block, {error, Text}) ->
    {{failed(Name, Text), []}, none};
example(Name, Block, #example_module{namespace = Namespace, before = Before,
                                     interfaces = Interfaces, build = Build, unit = Unit,
                                     uses = Uses}) ->
    {Body, Value} = split_result(Block),
    {Declared, Expression} = declared(Body),
    Text = case Value of
               none -> [Before, Declared, "fn docExample() = fn() = {\n", Expression, "\n}\n"];
               _ -> [Before, Declared, "fn docExample() = {\n", Expression, "\n}\n\n"
                     "export fn docShown() : String receiving Never = Io.show(docExample())\n"]
           end,
    case {checked(Namespace, iolist_to_binary(Text), Interfaces), Value} of
        {{error, [#diagnostic{message = Message} | _]}, _} ->
            {{failed(Name, Message), []}, none};
        {{ok, _, _, _}, none} ->
            {{{'Case', Name, fun() -> 'Passed' end}, []}, none};
        {{ok, Typed, Interface, Env}, Expected} ->
            case unit_built(Namespace, Unit, Build) of
                {ok, Built} ->
                    {Case, Loaded} = loaded(Name, Namespace, Typed, Interface, Env, Built,
                                            Expected),
                    {{Case, [Loaded | Uses]}, Loaded};
                {error, Refusal} ->
                    {{failed(Name, Refusal), []}, none}
            end
    end.

%% The build an example is compiled with: inside its module, the module's
%% unit named as a version is, the first name with `$` and a number the
%% host holds no code of (ern_code:fresh_unit/1), or the refusal of a name
%% past the host's limit.
unit_built(_Namespace, own, Build) ->
    {ok, Build};
unit_built(Namespace, fresh, Build) ->
    case ern_code:fresh_unit(Namespace) of
        {ok, Unit} -> {ok, Build#{units => #{Namespace => Unit}}};
        {error, _} = Error -> Error
    end.

%% The example compiled and loaded, and its case, which runs it.
loaded(Name, Namespace, Typed, Interface, Env, Build, Expected) ->
    {ok, Unit, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    {module, Unit} = code:load_binary(Unit, "doc example", Beam),
    {ok, Recorded} = ern_canonical:read(Beam),
    ok = ern_code:loaded(Unit, Beam, Recorded),
    %% report §11.1: the unit names its functions by their position
    {Shown, 0} = ern_code:function(Unit, Namespace ++ [docShown]),
    {{'Case', Name, fun() -> compared(Unit, Shown, Expected) end}, Unit}.

%% The example's value as `Io.show` writes it, against the one its last
%% line promises; its program's start has initialized its unit (report
%% §8.5).
compared(Unit, Shown, Expected) ->
    case Unit:Shown() of
        Expected -> 'Passed';
        Got -> {'Failed', <<"expected ", Expected/binary, ", got ", Got/binary>>}
    end.

checked(Namespace, Text, Interfaces) ->
    case ern_parser:parse_string(Text) of
        {ok, Declarations} -> ern_typecheck:check(Namespace, Declarations, Interfaces);
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

%% Appendix E.0 shape rule 6: an example is an expression, which
%% declarations may stand before, as in a module: the paragraphs before its
%% last blank line, where they parse as a module's declarations, and the
%% expression after them; else no declaration and the whole example.
declared(Body) ->
    case string:split(Body, <<"\n\n">>, trailing) of
        [Declared, Expression] ->
            case ern_parser:parse_string(Declared) of
                {ok, [_ | _]} -> {<<Declared/binary, "\n">>, Expression};
                _ -> {<<>>, Body}
            end;
        _ ->
            {<<>>, Body}
    end.
