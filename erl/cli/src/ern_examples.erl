%% Report §11.2, Appendix E.0 shape rule 6: the doc examples of a compiled
%% module as the cases `ern test` runs after its tests, each compiled in a
%% module of its own that uses the documented one, a private declaration's
%% inside the documented one, and each run as a program of its own in a
%% directory of its own.
-module(ern_examples).

-export([cases/4, in_directory/3, unload/1, module_text/3]).

-export_type([example/0, load/0]).

-include_lib("shared/include/ern_diagnostic.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("parser/include/ern_fence.hrl").
-include("ern_build.hrl").

%% Report §11.2: the module an example is compiled in: its namespace, the
%% text before the example's, the interfaces it is checked against beside
%% those of the modules it names, the build it is compiled with, whether
%% its unit is the namespace's own or one of a fresh name
%% (example_module/6), the units the example's program initializes beside
%% its own and those of the modules it names, as the run loaded them, the
%% top first (§8.5), and the modules the load of a module it names waits
%% on: inside the documented module, that module, so that a module that
%% uses it is a cycle (§4.1); and outside it, the documented module's
%% interface, whose names the example writes as a caller does (qualifying/2),
%% none inside.
-record(example_module, {namespace, before = <<>>, interfaces, build, unit = own, uses,
                         waiting = [], documented = none}).

%% Report §11.2: an example's case, the units its program initializes and
%% what names the frames of its fault's trace.
-type example() :: #example{}.

%% Report §11.2: the run's load of a module an example names, with those
%% it uses, given the modules its load waits on and the units loaded, the
%% top first, which it answers with the units it loaded before them; it
%% throws the run's refusal, `{cli_error, Refusal}`, where the run would
%% refuse the module (ern_cli).
-type load() :: fun(([atom()], [[atom()]], [module()]) -> [module()]).

%% The doc examples of the module Namespace, which the run has loaded with
%% the modules it uses, Loaded, its own first: each a case as a test is,
%% `{'Case', Name, Run}`, its run answering `'Passed'`, `{'Failed', Text}`
%% or `'Compiled'`, with the units its program initializes (report §8.5),
%% the top first: its own, those of the modules it names and those it
%% uses, the documented module's among them or, inside it, the example's
%% unit in its place, so that each is initialized once; none for an
%% example that does not run. Beside them the units their compiling loaded,
%% which unload/1 takes out once they have run. Report §11.2: an example is
%% named by the declaration it documents and its number among that
%% declaration's, `List.take example 2`, the module's own as `List example
%% 1`; the fenced `ernest` blocks of a type's constructors and fields are
%% the type's, after its own. A module an example names is found on
%% LoadPath, the documented module's root first, and loaded by Load, as the
%% run loads a module the documented one uses (report §11.1). The source of
%% the module is read once, where it has examples: a private declaration's
%% example is compiled inside it, and every example's frames name the line
%% of the source that holds it (frames/2).
-spec cases([atom()], [module()], [file:filename()], load()) -> {[example()], [module()]}.
cases(Namespace, [ErlangModule | _] = Loaded, LoadPath, Load) ->
    Erc = code:which(ErlangModule),
    {ok, Beam} = file:read_file(Erc),
    Interfaces = interfaces(Loaded),
    Documented = documented(Namespace, Beam),
    Source = case [Doc || {_, Docs} <- Documented, {_, Doc} <- Docs, fences(Doc) =/= []] of
                 [] -> none;
                 _ -> module_source(Namespace, Erc, Beam)
             end,
    Examples = [{iolist_to_binary([Declaration, " example ", integer_to_list(Number)]), Where,
                 Block, Start}
                || {Declaration, Docs} <- lined(Documented, Source),
                   {Number, {Where, Block, Start}}
                       <- lists:enumerate([{Where, Block, example_line(DocLine, Offset)}
                                           || {Where, Doc, DocLine} <- Docs,
                                              {Offset, Block} <- fences(Doc)])],
    Naming = {ern_build:compiled_dependencies(LoadPath), Load},
    Compiled = [example(Name, Block, Start, example_module(Where, Index, Namespace, Interfaces,
                                                           Source, Loaded),
                        Naming)
                || {Index, {Name, Where, Block, Start}} <- lists:enumerate(Examples)],
    {[Example || {Example, _} <- Compiled], [Unit || {_, Unit} <- Compiled, Unit =/= none]}.

%% The interfaces of loaded units, those they use before them, each read
%% from the `.erc` the unit was loaded from (report §11.1).
interfaces(Units) ->
    [Interface || Unit <- lists:reverse(Units),
                  {ok, Compiled} <- [file:read_file(code:which(Unit))],
                  {ok, #{interface := Interface}} <- [ern_interface:read(Compiled)]].

%% Report §11.2: an example run by Run, its program, in an empty directory
%% of its own, made for it under the host's directory for temporary files,
%% `TMPDIR` or `/tmp`, and removed after it, whether it passed, failed or
%% faulted. The host's working directory is the node's and not a
%% process's, so it is the example's directory while its program runs,
%% where the program's start initializes the modules it uses and
%% `Os.workingDirectory` names it (Appendix E.23), and the run's again
%% after it. Where the run's directory cannot be read, or the example's
%% cannot be made, the case fails with the reason, and its program
%% initializes nothing; a directory the example left that cannot be removed
%% is said on ErrorDevice, the job's standard error, as the job says its
%% own lines, since the example's launch has ended then.
-spec in_directory(example(), fun((example()) -> Outcome), io:device()) -> Outcome.
in_directory(#example{test_case = {'Case', Name, _}} = Example, Run, ErrorDevice) ->
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
                        remove(Name, Dir, ErrorDevice)
                    end;
                {error, Why} ->
                    Run(failed(Name, ["its directory cannot be made under ", Base, ": ", Why]))
            end;
        {error, Error} ->
            Run(failed(Name, ["the working directory cannot be read: ",
                              file:format_error(Error)]))
    end.

%% An example that fails with Text, its program initializing nothing.
failed(Name, Text) ->
    Failed = {'Failed', unicode:characters_to_binary(Text)},
    #example{test_case = {'Case', Name, fun() -> Failed end}, frames = fun(Trace) -> Trace end}.

%% A directory of a name no other holds, made under Base, which others
%% share, its owner's alone before the example writes in it, as the
%% configuration directory is made (ern_build:make_private_dir/1); or why
%% it cannot be made.
made_directory(Base) ->
    Dir = filename:join(Base, "ern_example_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    case ern_build:make_private_dir(Dir) of
        ok -> {ok, Dir};
        exists -> made_directory(Base);
        {error, _} = Error -> Error
    end.

remove(Name, Dir, ErrorDevice) ->
    case file:del_dir_r(Dir) of
        ok ->
            ok;
        {error, Error} ->
            io:put_chars(ErrorDevice,
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

%% The documented declarations with each doc block's first line in the
%% module's source, Source, as the source's doc blocks give it, in the
%% order both write them, or none for each where no source holds the
%% module as it was compiled.
lined(Documented, {source, Source, _}) ->
    {ok, Tokens} = ern_lexer:tokenize(Source, [comments]),
    Lines = [{Line, Text} || {doc, {Line, _, _, _}, Text} <- Tokens],
    {Lined, _} = lists:mapfoldl(fun({Declaration, Docs}, Left) ->
                                     {Own, Rest} = lists:mapfoldl(fun doc_line/2, Left, Docs),
                                     {{Declaration, Own}, Rest}
                                 end, Lines, Documented),
    Lined;
lined(Documented, _NoSource) ->
    [{Declaration, [{Where, Doc, none} || {Where, Doc} <- Docs]}
     || {Declaration, Docs} <- Documented].

%% A doc block with the line it begins on, the first of the source's doc
%% blocks left, Left, that holds its text, and those after that one.
doc_line({Where, Doc}, [{Line, Doc} | Rest]) -> {{Where, Doc, Line}, Rest};
doc_line(Documented, [_ | Rest]) -> doc_line(Documented, Rest);
doc_line({Where, Doc}, []) -> {{Where, Doc, none}, []}.

%% The line of the source an example's first line stands on, Offset lines
%% into a doc block that begins on DocLine, or none.
example_line(none, _Offset) -> none;
example_line(DocLine, Offset) -> DocLine + Offset.

%% Report §11.2: the source of the module, Namespace, that its `.erc`, Erc,
%% was compiled from, as Beam records it, and whether it is the standard
%% library's own; or why no source holds the module as it was compiled:
%% gone, or changed since, which the `.erc`'s hash of it tells.
module_source(Namespace, Erc, Beam) ->
    {ok, #{source_path := SourcePath, source_hash := Hash}} = ern_interface:read(Beam),
    BuildRoot = ern_build:root_of(Erc, Namespace),
    File = filename:join(BuildRoot, unicode:characters_to_list(SourcePath)),
    Compiled = [ern_build:shown(Erc), " was compiled from ", ern_build:shown(File)],
    case file:read_file(File) of
        {ok, Source} ->
            case crypto:hash(sha256, Source) of
                Hash ->
                    {source, Source,
                     ern_build:is_stdlib_root(ern_build:root_of(File, Namespace))};
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
%% (§8.5), and a module it names that uses the module is a cycle (§4.1).
%% Each program initializes the modules its example names too. Or why the
%% example has no module to be compiled in, its source not as it was
%% compiled.
example_module(outside, Index, Namespace, Interfaces, _Source, Loaded) ->
    #example_module{namespace = [list_to_atom("$Example" ++ integer_to_list(Index))],
                    interfaces = Interfaces, build = #{source_hash => <<>>, deps => []},
                    uses = Loaded,
                    documented = lists:keyfind(Namespace, #interface.namespace, Interfaces)};
example_module(inside, _Index, Namespace, Interfaces, {source, Source, Standard},
               [_Documented | Used]) ->
    Others = [Interface || #interface{namespace = Other} = Interface <- Interfaces,
                           Other =/= Namespace],
    #example_module{namespace = Namespace, before = <<Source/binary, "\n">>, interfaces = Others,
                    build = #{source_hash => <<>>, deps => [], standard => Standard},
                    unit = fresh, uses = Used, waiting = [Namespace]};
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

%% Report §2.2, §11.2: a doc block's fenced `ernest` blocks, its examples,
%% as CommonMark finds them (ern_parser:fenced/1), each with the number of
%% the doc block's lines before its content.
fences(Doc) ->
    Parts = ern_parser:fenced(binary:split(Doc, <<"\n">>, [global])),
    {Blocks, _} = lists:mapfoldl(fun(Part, Offset) -> {{Offset, Part}, Offset + taken(Part)} end,
                                 0, Parts),
    [{Offset + 1, iolist_to_binary(lists:join(<<"\n">>, Content))}
     || {Offset, #fence{language = <<"ernest">>, content = Content}} <- Blocks].

%% The lines a part of a doc block takes, a fenced block's or a line's.
taken(#fence{lines = Lines, closing = Closing}) ->
    1 + length(Lines) + length([Closing || Closing =/= none]);
taken(_Line) ->
    1.

%% One example, its case and the units its program initializes, and the
%% unit its compiling loaded, or none, compiled in its module, the modules
%% it names found and loaded by Naming, the finding on the load path and
%% the run's load (named/3); Start is the line of the module's source its
%% first line stands on, or none. Report §11.2, Appendix E.0 shape rule 6:
%% an example that does not compile fails with the diagnostic's message,
%% the first of its errors, and the help that qualifies a name the
%% documented module exports (qualifying/2), or with the refusal of a
%% module it names that the run would refuse; one whose last line is
%% `// => v`, standing alone, runs, and fails where `Io.show` of its value
%% is not `v`; any other is `compiled` where it compiles, and runs nothing
%% (module_text/3).
example(Name, _Block, _Start, {error, Text}, _Naming) ->
    {failed(Name, Text), none};
example(Name, Block, Start, #example_module{namespace = Namespace, before = Before,
                                            build = Build, unit = Unit} = Module, Naming) ->
    {Text, Value} = module_text(Namespace, Before, Block),
    case {checked(iolist_to_binary(Text), Module, Naming), Value} of
        {{error, [#diagnostic{message = Message} = Diagnostic | _]}, _} ->
            {failed(Name, [Message | qualifying(Diagnostic, Module)]), none};
        {{refused, Refusal}, _} ->
            {failed(Name, Refusal), none};
        {{ok, _, _, _, _}, none} ->
            {#example{test_case = {'Case', Name, fun() -> 'Compiled' end},
                      frames = fun(Trace) -> Trace end},
             none};
        {{ok, Typed, Interface, Env, Uses}, Expected} ->
            case unit_built(Namespace, Unit, Build) of
                {ok, Built} ->
                    {Case, Loaded} = loaded(Name, Namespace, Typed, Interface, Env, Built,
                                            Expected),
                    Named = {Name, Namespace, lines(Before), Start},
                    {#example{test_case = Case, initialized = [Loaded | Uses],
                              frames = fun(Trace) -> frames(Trace, Named) end},
                     Loaded};
                {error, Refusal} ->
                    {failed(Name, Refusal), none}
            end
    end.

%% Report §11.2, §11.5: an example of an exported declaration, or of the
%% module, stands outside the documented module and names its declarations
%% as a caller does, qualified, so an unknown name that the module exports
%% is given the help that writes it so after the message, as `Checks.add`;
%% none for any other failure.
qualifying(#diagnostic{unknown_name = Unknown},
           #example_module{documented = #interface{namespace = Namespace, values = Values}})
  when is_atom(Unknown), Unknown =/= undefined ->
    case is_map_key(Namespace ++ [Unknown], Values) of
        true -> ["; write `", ern_namespace:text(Namespace ++ [Unknown]), "`"];
        false -> []
    end;
qualifying(_Diagnostic, _Module) ->
    [].

%% How many lines a text takes before what follows it, which begins on the
%% line after its last line feed.
lines(Text) ->
    length(binary:matches(Text, <<"\n">>)).

%% Report §11.2, Appendix E.21: the trace of an example's fault with its
%% frames named as its case is. A frame of the example's own code, which
%% its module, of the namespace Namespace, holds past the lines Before
%% takes, names the case and the line of the module's source that holds
%% it, `Adds.f example 1:12`, the example's lines standing in its module
%% as they stand in its doc block (module_text/3), or the case alone where
%% Start, the line its first line stands on, is none. Every other frame is
%% as the runtime wrote it, the module's own beside a private
%% declaration's example among them; `docShown` leaves none, since it calls
%% the example last.
frames(Trace, {Name, Namespace, Before, Start}) ->
    Prefix = unicode:characters_to_binary([ern_namespace:text(Namespace), "."]),
    iolist_to_binary([[framed(Line, Prefix, {Name, Before, Start}), "\n"]
                      || Line <- binary:split(Trace, <<"\n">>, [global, trim_all])]).

%% A frame as the runtime wrote it, `Name:Line` or `Name` (§6.9), as an
%% example's trace writes it.
framed(Line, Prefix, Named) ->
    case string:prefix(Line, Prefix) of
        nomatch ->
            Line;
        Rest ->
            case string:split(Rest, ":", trailing) of
                [_, Number] -> framed_at(Line, binary_to_integer(Number), Named);
                [_] -> Line
            end
    end.

%% A frame of the example's module at the line Number: the case's where
%% the line is past Before's, the example's, at the line of the source that
%% holds it.
framed_at(Line, Number, {_Name, Before, _Start}) when Number =< Before ->
    Line;
framed_at(_Line, _Number, {Name, _Before, none}) ->
    Name;
framed_at(_Line, Number, {Name, Before, Start}) ->
    ern_namespace:site_text([Name], Start + Number - Before - 1).

%% Report §11.2, Appendix E.0 shape rule 6: the text of the module, of the
%% namespace Namespace, that an example, Block, is compiled in, after
%% Before, and the value its last line `// => v` promises, or none. The
%% example is the body of `docExample`, its declarations before it, each
%% of its lines on the line after Before's that is its line in the doc
%% block: `docExample`'s head stands on the blank line after the
%% declarations, or before the example's first line where there are none,
%% so that a trace names the example's line (frames/2). One without a
%% value is a lambda's body, since it runs nothing, so that it may receive.
%% One with a value runs, `docExample` giving its value to `Io.show` as the
%% module writes it (shown/1), so that the example's last call leaves its
%% frame, and `docShown`, which calls it, has the mailbox type Never, as
%% an entry point's left open has (report §8.1).
-spec module_text([atom()], binary(), binary()) -> {iodata(), binary() | none}.
module_text(Namespace, Before, Block) ->
    {Body, Value} = split_result(Block),
    {Head, Close} = case Value of
                        none -> {"fn docExample() = fn() = {", "\n}\n"};
                        _ -> {["fn docExample() = ", shown(Namespace), "({"], "\n})\n\n"
                              "export fn docShown() : String receiving Never = docExample()\n"}
                    end,
    Opened = case declared(Body) of
                 {none, Expression} -> [Head, " ", Expression];
                 {Declared, Expression} -> [Declared, "\n", Head, "\n", Expression]
             end,
    {[Before, Opened, Close], Value}.

%% Report §4.2: `Io.show` as the example's module writes it, plain within
%% Io itself, which writes its own declaration qualified only where a
%% binding hides it.
shown(['Io']) -> "show";
shown(_) -> "Io.show".

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

%% The example's module, Text, checked against the module's interfaces and
%% those of the modules it names, with the units its program initializes,
%% the top first (named/3).
checked(Text, #example_module{namespace = Namespace, interfaces = Interfaces} = Module,
        Naming) ->
    case ern_parser:parse_string(Text) of
        {ok, Declarations} ->
            case named(Declarations, Module, Naming) of
                {ok, Uses, Named} ->
                    case ern_typecheck:check(Namespace, Declarations, Interfaces ++ Named) of
                        {ok, Typed, Interface, Env} -> {ok, Typed, Interface, Env, Uses};
                        {error, _} = Error -> Error
                    end;
                {error, Refusal} ->
                    {refused, Refusal}
            end;
        {error, Diagnostic} ->
            {error, [Diagnostic]}
    end.

%% Report §11.2, §11.1: the modules an example's module, Declarations,
%% names that a root of the load path holds, but for the prelude's and the
%% standard library's, which every check is given, and for the example's
%% own module, each loaded by the run's load with those it uses beside the
%% units the example's program initializes, Uses: the units then, the top
%% first, and the interfaces of those the loads added; or the refusal of a
%% module the run would refuse, a cycle through the documented module
%% among them.
named(Declarations, #example_module{namespace = Namespace, uses = Uses, waiting = Waiting},
      {Find, Load}) ->
    Named = Find(Declarations) -- [Namespace],
    try lists:foldl(fun(Module, Acc) -> Load(Module, Waiting, Acc) end, Uses, Named) of
        Loaded -> {ok, Loaded, interfaces(Loaded -- Uses)}
    catch
        throw:{cli_error, Refusal} -> {error, Refusal}
    end.

%% An example's body and the value its last line `// => v` promises, the
%% line standing alone, or none.
split_result(Block) ->
    Lines = binary:split(Block, <<"\n">>, [global]),
    case lists:last(Lines) of
        <<"// => ", Value/binary>> ->
            {iolist_to_binary(lists:join(<<"\n">>, lists:droplast(Lines))), Value};
        _ -> {Block, none}
    end.

%% Report §11.2, Appendix E.0 shape rule 6: an example is an expression,
%% which declarations may stand before, as in a module: the longest run of
%% its first paragraphs, those its blank lines part, that parses as a
%% module's declarations, and the expression in the paragraphs after them;
%% else none and the whole example.
declared(Body) ->
    Paragraphs = binary:split(Body, <<"\n\n">>, [global]),
    declared(Body, Paragraphs, length(Paragraphs) - 1).

declared(Body, _Paragraphs, 0) ->
    {none, Body};
declared(Body, Paragraphs, Count) ->
    {First, Rest} = lists:split(Count, Paragraphs),
    Declared = iolist_to_binary(lists:join(<<"\n\n">>, First)),
    case ern_parser:parse_string(Declared) of
        {ok, [_ | _]} -> {Declared, iolist_to_binary(lists:join(<<"\n\n">>, Rest))};
        _ -> declared(Body, Paragraphs, Count - 1)
    end.
