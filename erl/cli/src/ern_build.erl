%% The build of report §11.1, which `ern build` runs and every other job
%% reaches for a module's source, its interface, or a file written whole:
%% finding the modules under a source root and giving each its namespace
%% by the path shape, ordering them by their dependencies, compiling each
%% to its `.erc` when it has changed, and removing what an earlier build,
%% or `ern doc`, wrote that no source now makes. It shapes a `.erc`, so it
%% is in the compiler's hash (compiler_modules/0); ern_cli and the other
%% jobs' modules shape none and are not, so a change to them recompiles
%% nothing.
-module(ern_build).

-export([compile/4, compile_in_memory/4, compiled_in_order/3, report_errors/4, shown/1,
         sources/1, compiled_under/1, bytes_text/1, module_of/2, module_of/3, shape/2, segment/1,
         module_path/1, compile_order/2, compile_order/3, source_root/3, build_root/2,
         is_stdlib_root/1, stdlib_hash/0,
         dependency_interfaces/5, load_path/1, compiler_modules/0,
         sweep_pages/5, compile_source/5, compile_source/6, absolute/1, relative/2, write_whole/2,
         write_output/2, write_output/3, read/1, make_dirs/1, refused/2, fail/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("checker/include/ern_canonical.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_build.hrl").

%% Report §11.1: the modules a path names compiled, each failure reported
%% as the job named Job reports it; 0 where every module compiled, else 1.
-spec compile(string(), [term()], file:filename(), io:device()) -> 0 | 1.
compile(Job, Options, Path, ErrorDevice) ->
    Emit = case lists:member(emit_erl, Options) of
               true -> erl;
               false -> erc
           end,
    {Status, _} = compile(Job, Options, Path, ErrorDevice, Emit),
    Status.

%% Report §11.4: the same, writing nothing and removing nothing: every
%% module is compiled, and the compiled modules are answered with the
%% status, for `ern doc` to read its pages from.
-spec compile_in_memory(string(), [term()], file:filename(), io:device()) ->
          {0 | 1, #{[atom()] => binary()}}.
compile_in_memory(Job, Options, Path, ErrorDevice) ->
    compile(Job, Options, Path, ErrorDevice, memory).

compile(Job, Options, Path, ErrorDevice, Emit) ->
    filelib:is_file(Path) orelse fail(Path ++ ": no such file or directory"),
    IsDirectory = filelib:is_dir(Path),
    SourceRoot = source_root(Options, Path, case IsDirectory of true -> Path; false -> "." end),
    BuildRoot = build_root(Options, SourceRoot),
    Files = case IsDirectory of
                true -> sources(Path);
                false -> [Path]
            end,
    Mode = case IsDirectory of
               true -> tree;
               false -> file
           end,
    %% report §11.1: a path that is no module's fails that file alone, and
    %% the rest are built
    {Modules, Misnamed} = modules_of(Files, SourceRoot, Mode),
    %% report §11.1: the roots a dependency is found under, the build root
    %% and then each root of the load path
    DependencyRoots = [BuildRoot | load_path(Options)],
    SetAside = set_aside_installed_stdlib(SourceRoot, BuildRoot),
    try
        %% report §11.1: a module outside the source root is found under
        %% build-root, then under each --load-path root
        {Parsed, Unparsed1} = parse_all(Modules, SourceRoot, DependencyRoots),
        Unparsed = Misnamed ++ Unparsed1,
        %% report §11.1: the library's own modules depend on each other as
        %% ordinary modules do, and record no hash of it
        StdlibHash = case is_stdlib_root(SourceRoot) of
                         true -> none;
                         false -> stdlib_hash()
                     end,
        {Failed, Compiled} = built(order(Parsed), Unparsed, {SourceRoot, DependencyRoots, Emit,
                                                             StdlibHash}),
        case [{Failure, Diagnostics} || {_, Failure, Diagnostics} <- Failed] of
            [] ->
                IsDirectory andalso Emit =:= erc
                    andalso sweep(absolute(Path), SourceRoot, BuildRoot),
                {0, Compiled};
            Reported ->
                [report_failure(Job, Options, Failure, Diagnostics, ErrorDevice)
                 || {Failure, Diagnostics} <- Reported],
                {1, Compiled}
        end
    after
        code:add_pathsa(SetAside)
    end.

%% The modules the files are, and a failure for each file whose path is
%% none's, keyed by the file, since it has no namespace.
modules_of(Files, SourceRoot, Mode) ->
    lists:foldr(fun(Source, {Modules, Misnamed}) ->
                    try module_of(absolute(Source), SourceRoot, Mode) of
                        Module -> {[Module | Modules], Misnamed}
                    catch
                        throw:{cli_error, Refusal} ->
                            {Modules, [{{file, Source}, {refused, Refusal}, []} | Misnamed]}
                    end
                end, {[], []}, Files).

%% Report §11.1, §11.5: a module's failure, its errors or the refusal of
%% something it needs, as a refusal of the job is said.
report_failure(Job, _Options, {refused, Refusal}, [], ErrorDevice) ->
    io:format(ErrorDevice, "~s: ~ts~n", [Job, Refusal]);
%% report §11.1: a module left uncompiled is named, with the module it uses
%% that failed
report_failure(Job, _Options, {skipped, Namespace, Dependency}, [], ErrorDevice) ->
    io:format(ErrorDevice, "~s: ~ts is not compiled, since it uses ~ts, which failed~n",
              [Job, ern_namespace:text(Namespace), ern_namespace:text(Dependency)]);
report_failure(_Job, Options, File, Diagnostics, ErrorDevice) ->
    report_errors(Options, File, Diagnostics, ErrorDevice).

%% Report §11.1: the parsed modules Order compiled in memory in that order,
%% each after the modules it depends on, against the `.erc`s under
%% BuildRoot for any other: the modules that failed, as built/3 answers
%% them, and the compiled modules by namespace. A module's code is the
%% same whatever order its build checks the modules in, which a test of the
%% standard library's own build holds.
-spec compiled_in_order([#build_module{}], file:filename(), file:filename()) ->
          {[term()], #{[atom()] => binary()}}.
compiled_in_order(Order, SourceRoot, BuildRoot) ->
    StdlibHash = case is_stdlib_root(SourceRoot) of
                     true -> none;
                     false -> stdlib_hash()
                 end,
    SetAside = set_aside_installed_stdlib(SourceRoot, absolute(BuildRoot)),
    try
        built(Order, [], {SourceRoot, [BuildRoot], memory, StdlibHash})
    after
        code:add_pathsa(SetAside)
    end.

%% Report §11.1, §11.5: every module built, in order, but one that uses a
%% module that failed, whose errors would follow from that one's. A module
%% is checked in order, and emitted once every module of the build its
%% forms reference is checked, by the positions their interfaces give: a
%% module of the standard library's own build that names another by a
%% prelude name or an operator alone, `<>` on lists naming `List.<>`, does
%% not depend on it (§11.1), and its code calls it all the same. The
%% modules that failed, each with its file and its errors, with
%% `{refused, Refusal}` where something it needs was refused, or with
%% `{skipped, Namespace, Dependency}` where a module it uses failed, or a
%% module its forms reference; Unparsed begins them. Beside them, the
%% modules compiled in memory, by namespace.
built(Order, Unparsed, {SourceRoot, DependencyRoots, Emit, StdlibHash}) ->
    Namespaces = [Namespace || #build_module{namespace = Namespace} <- Order],
    %% report §11.1: what every module of the build is compiled against
    %% beside its dependencies, the standard library and the build of
    %% `ern`, as its .erc records them, found once for the build
    Against = #{stdlib => StdlibHash, compiler => compiler_build()},
    BuildModule = fun(Module, Interfaces) ->
                      build(Module, Interfaces, SourceRoot, DependencyRoots, Emit, Against,
                            Namespaces)
                  end,
    {_, Failed, Compiled, Waiting} =
        lists:foldl(fun(Module, Acc) -> build_step(Module, Acc, BuildModule) end,
                    {#{}, Unparsed, #{}, []}, Order),
    Skipped = [{Namespace, {skipped, Namespace, Waited}, []}
               || {Namespace, Waits, _} <- Waiting,
                  Waited <- [hd([Wait || Wait <- Waits, lists:keymember(Wait, 1, Failed)]
                                ++ Waits)]],
    {Failed ++ Skipped, Compiled}.

build_step(#build_module{namespace = Namespace, dependencies = Dependencies} = Module,
           {Interfaces, Failed, Compiled, Waiting}, BuildModule) ->
    case [Dependency || Dependency <- Dependencies, lists:keymember(Dependency, 1, Failed)] of
        [] ->
            try BuildModule(Module, Interfaces) of
                {Interfaces1, none} ->
                    emitted_ready({Interfaces1, Failed, Compiled, Waiting});
                {Interfaces1, Emitting} ->
                    emitted_ready({Interfaces1, Failed, Compiled, Waiting ++ [Emitting]})
            catch
                throw:{errors, _, _} = Thrown ->
                    {Interfaces, Failed ++ [failure(Namespace, Thrown)], Compiled, Waiting};
                throw:{cli_error, _} = Thrown ->
                    {Interfaces, Failed ++ [failure(Namespace, Thrown)], Compiled, Waiting}
            end;
        [Dependency | _] ->
            {Interfaces, Failed ++ [{Namespace, {skipped, Namespace, Dependency}, []}], Compiled,
             Waiting}
    end.

%% Each module checked that waits to be emitted, emitted where every module
%% of the build its forms reference is checked, with their interfaces.
emitted_ready({Interfaces, Failed, Compiled, Waiting}) ->
    {Ready, Waits} = lists:partition(fun({_, Referenced, _}) ->
                                         lists:all(fun(Wait) -> is_map_key(Wait, Interfaces) end,
                                                   Referenced)
                                     end, Waiting),
    lists:foldl(fun({Namespace, _, Emitting}, {InterfacesAcc, FailedAcc, CompiledAcc, WaitsAcc}) ->
                    try Emitting(InterfacesAcc) of
                        none -> {InterfacesAcc, FailedAcc, CompiledAcc, WaitsAcc};
                        Beam -> {InterfacesAcc, FailedAcc, CompiledAcc#{Namespace => Beam},
                                 WaitsAcc}
                    catch
                        throw:{cli_error, _} = Thrown ->
                            {InterfacesAcc, FailedAcc ++ [failure(Namespace, Thrown)],
                             CompiledAcc, WaitsAcc}
                    end
                end, {Interfaces, Failed, Compiled, Waits}, Ready).

%% A module's failure as built/3 answers it: its errors; and, report
%% §11.1, a dependency that is stale or not built, or a compiled file that
%% holds another module, which fails this module alone.
failure(Namespace, {errors, File, Diagnostics}) ->
    {Namespace, File, Diagnostics};
failure(Namespace, {cli_error, Refusal}) ->
    {Namespace, {refused, Refusal}, []}.

%% Report §11.5: each error as ern_diagnostic renders it, the first line alone
%% under --short-errors; status 1. The file is named from the working
%% directory when it lies under it.
-spec report_errors([term()], file:filename(), [ern_diagnostic:diagnostic()], io:device()) -> 1.
report_errors(Options, File, Diagnostics, ErrorDevice) ->
    Short = lists:member(short_errors, Options),
    Source = case file:read_file(File) of
                 {ok, Bytes} -> Bytes;
                 _ -> <<>>
             end,
    Shown = shown(File),
    lists:foreach(fun(Diagnostic) ->
                      Text = case Short of
                                 true -> ern_diagnostic:short(Shown, Diagnostic);
                                 false -> ern_diagnostic:format(Shown, Source, Diagnostic)
                             end,
                      io:format(ErrorDevice, "~ts~n", [Text])
                  end, Diagnostics),
    1.

%% A file named from the working directory where it lies under it.
-spec shown(file:filename()) -> file:filename().
shown(File) ->
    {ok, Cwd} = file:get_cwd(),
    case relative(File, Cwd) of
        outside -> absolute(File);
        Relative -> Relative
    end.

%% Report §11.1: every `.ern` under a directory, passing over each file and
%% directory whose name begins with a dot, which is no module, and each
%% symbolic link to a directory. The host gives a name that is not UTF-8 as
%% its bytes, and one of a `.ern` or of a directory that holds one is an
%% error.
-spec sources(file:filename()) -> [file:filename()].
sources(Dir) ->
    files_under(Dir, ".ern").

%% Report §11.2: every `.erc` under a directory, found as its sources are,
%% in the order of their paths, which `ern test` runs them in.
-spec compiled_under(file:filename()) -> [file:filename()].
compiled_under(Dir) ->
    lists:sort(files_under(Dir, ".erc")).

files_under(Dir, Extension) ->
    Names = case file:list_dir_all(Dir) of
                {ok, Found} -> Found;
                {error, Error} -> refused(Dir, Error)
            end,
    lists:append([file_under(Dir, Name, Extension) || Name <- lists:sort(Names),
                                                      not is_dot_name(Name)]).

file_under(Dir, Name, Extension) when is_binary(Name) ->
    Path = filename:join(Dir, Name),
    IsModule = filename:extension(Name) =:= list_to_binary(Extension)
        orelse (filelib:is_dir(Path) andalso not is_link(Path)
                andalso files_under(Path, Extension) =/= []),
    IsModule andalso fail("a name that is not UTF-8: " ++ bytes_text(Path)),
    [];
file_under(Dir, Name, Extension) ->
    Path = filename:join(Dir, Name),
    case {filelib:is_dir(Path), is_link(Path)} of
        {true, false} -> files_under(Path, Extension);
        {true, true} -> [];
        {false, _} -> [Path || filename:extension(Name) =:= Extension]
    end.

is_dot_name(<<$., _/binary>>) -> true;
is_dot_name([$. | _]) -> true;
is_dot_name(_) -> false.

%% A name the host could not decode, each byte past ASCII as `\xHH`, and
%% one it could as it is. A directory's name may be either, so a name is
%% any path the host gives.
-spec bytes_text(file:filename_all()) -> string().
bytes_text(Name) when is_list(Name) ->
    Name;
bytes_text(Name) ->
    lists:append([case Byte < 16#80 of
                      true -> [Byte];
                      false -> lists:flatten(io_lib:format("\\x~2.16.0B", [Byte]))
                  end || <<Byte>> <= Name]).

is_link(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = symlink}} -> true;
        _ -> false
    end.

%% A source file as a module: its namespace from its path under the root,
%% with the path shape rule of §11.1, a file of a tree.
-spec module_of(file:filename(), file:filename()) -> #build_module{}.
module_of(File, SourceRoot) ->
    module_of(File, SourceRoot, tree).

%% The same, of a tree's file or of a file built alone, whose source root
%% only it takes, so that a directory breaking the path shape is refused
%% with the root that leaves it out (report §11.1).
-spec module_of(file:filename(), file:filename(), file | tree) -> #build_module{}.
module_of(File, SourceRoot, Mode) ->
    %% report §11.5: a refusal names the file from the working directory
    Shown = shown(File),
    Relative = relative(File, SourceRoot),
    Relative =/= outside orelse fail(Shown ++ " is not under the source root " ++ SourceRoot
                                     ++ "; --source-root names another"),
    %% report §4.2: a file of the standard library's own source root is
    %% compiled with that root only
    case is_stdlib_root(SourceRoot) orelse relative(File, stdlib_root()) =:= outside of
        true -> ok;
        false -> fail(Shown ++ " is in the standard library's source root; omit --source-root")
    end,
    filename:extension(Relative) =:= ".ern" orelse fail(Shown ++ " does not end in .ern"),
    Components = filename:split(filename:rootname(Relative)),
    shaped(Shown, Components, SourceRoot, Mode),
    Namespace = ern_namespace:namespace(Components),
    %% report §11.1: the host holds the module's Erlang name
    ErlangModule = ern_namespace:erlang_module_text(Namespace),
    length(ErlangModule) =< ern_namespace:host_name_limit()
        orelse fail(Shown ++ ": " ++ ern_namespace:host_name_text(
                                            "the module's Erlang name, `ern@` and its path,",
                                            ErlangModule)),
    %% report §4.2: a module namespace is never a namespace of the prelude
    %% or the standard library, except in the standard library's own source
    %% root; the message names which of the two takes it, the prelude where
    %% both do
    case Namespace of
        [Single] ->
            not is_stdlib_root(SourceRoot) andalso
                case {lists:member(Single, prelude_namespaces()),
                      lists:member(Single, stdlib_namespaces())} of
                    {true, _} ->
                        fail(Shown ++ " takes the prelude namespace " ++ atom_to_list(Single));
                    {false, true} ->
                        fail(Shown ++ " takes the standard library namespace "
                             ++ atom_to_list(Single));
                    {false, false} ->
                        ok
                end;
        _ -> ok
    end,
    #build_module{namespace = Namespace, file = File, relative = Relative}.

%% Report §11.1: every component of the path keeps the shape. A file built
%% alone has its own name checked first, and then the deepest directory
%% that breaks the shape is refused with the source root that leaves it
%% out of the namespace.
shaped(Shown, Components, _, tree) ->
    lists:foreach(fun(Component) -> shape(Shown, Component) end, Components);
shaped(Shown, Components, SourceRoot, file) ->
    {Directories, [Name]} = lists:split(length(Components) - 1, Components),
    shape(Shown, Name),
    Broken = [Index || {Index, Directory} <- lists:enumerate(Directories),
                       not ern_namespace:is_component(Directory)],
    case lists:reverse(Broken) of
        [] ->
            ok;
        [Deepest | _] ->
            Root = shown(filename:join([SourceRoot | lists:sublist(Directories, Deepest)])),
            shape(Shown, lists:nth(Deepest, Directories),
                  "; --source-root " ++ Root ++ " leaves it out of the namespace")
    end.

%% Report §11.1: each component of a file's path is words joined by single
%% `_`, a word a lowercase letter, then lowercase letters and digits
%% (ern_namespace). The refusal names the file.
-spec shape(file:filename(), string()) -> ok.
shape(File, Component) ->
    shape(File, Component, "").

shape(File, Component, Advice) ->
    case ern_namespace:is_component(Component) of
        true -> ok;
        false ->
            Named = File ++ ": path component `" ++ Component ++ "`",
            case lists:any(fun(Char) -> Char >= $A andalso Char =< $Z end, Component) of
                true -> fail(Named ++ " must be lowercase" ++ Advice);
                false -> fail(Named ++ " must be words joined by `_`, each a lowercase letter,"
                              " then lowercase letters and digits; a module of several words"
                              " is `ordered_set.ern`" ++ Advice)
            end
    end.

%% Report §11.1, §4.2: the namespace segment a path component names, where
%% it is one; the shell's `:load` completion asks here.
-spec segment(string()) -> {ok, string()} | error.
segment(Component) ->
    ern_namespace:segment(Component).

%% Report §11.2: the inverse, a namespace as a relative path without
%% extension.
-spec module_path([atom()]) -> string().
module_path(Namespace) ->
    ern_namespace:module_path(Namespace).

%% Parse every module, find its dependencies, and order them; a cycle is
%% an error naming the modules in it (§11.1).
-spec compile_order([#build_module{}], file:filename()) -> [#build_module{}].
compile_order(Modules, SourceRoot) ->
    compile_order(Modules, SourceRoot, []).

-spec compile_order([#build_module{}], file:filename(), [file:filename()]) -> [#build_module{}].
compile_order(Modules, SourceRoot, DependencyRoots) ->
    order([parse_module(Module, SourceRoot, DependencyRoots) || Module <- Modules]).

%% Every module parsed, and each that does not parse with its errors, as a
%% build reports them (report §11.5). Every source is parsed before any
%% namespace is checked, so that the check reads the types a module of the
%% build declares from its parse, and parses a parent's source no more for
%% each of its children (report §4.2).
parse_all(Modules, SourceRoot, DependencyRoots) ->
    Sources = [{Module, source_parsed(Module)} || Module <- Modules],
    Declared = maps:from_list([{File, local_types(Declarations)}
                               || {#build_module{file = File}, {ok, Declarations}} <- Sources]),
    lists:foldl(fun({Module, Source}, {Parsed, Failed}) ->
                    Namespace = Module#build_module.namespace,
                    try parsed_module(Module, Source, SourceRoot, {DependencyRoots, Declared}) of
                        ParsedModule -> {Parsed ++ [ParsedModule], Failed}
                    catch
                        throw:{errors, File, Diagnostics} ->
                            {Parsed, Failed ++ [{Namespace, File, Diagnostics}]};
                        %% report §11.1: a namespace that clashes fails this
                        %% module alone
                        throw:{cli_error, Refusal} ->
                            {Parsed, Failed ++ [{Namespace, {refused, Refusal}, []}]}
                    end
                end, {[], []}, Sources).

%% The parsed modules in an order where each follows those it uses; a
%% cycle is an error naming the modules in it (§11.1).
order(Parsed) ->
    %% the graph is tables of this process's, deleted whether or not the
    %% order is found
    Graph = digraph:new(),
    Order = try
                lists:foreach(fun(#build_module{namespace = Namespace}) ->
                                  digraph:add_vertex(Graph, Namespace)
                              end, Parsed),
                lists:foreach(fun(#build_module{namespace = Namespace,
                                                dependencies = Dependencies}) ->
                                  lists:foreach(fun(Dependency) ->
                                                    digraph:add_vertex(Graph, Dependency),
                                                    digraph:add_edge(Graph, Dependency, Namespace)
                                                end, Dependencies)
                              end, Parsed),
                topsort(Graph)
            after
                digraph:delete(Graph)
            end,
    ByNamespace = maps:from_list([{Namespace, Module}
                                  || #build_module{namespace = Namespace} = Module <- Parsed]),
    [maps:get(Namespace, ByNamespace) || Namespace <- Order, is_map_key(Namespace, ByNamespace)].

topsort(Graph) ->
    case digraph_utils:topsort(Graph) of
        false ->
            [Cycle | _] = digraph_utils:cyclic_strong_components(Graph),
            fail("module cycle: "
                 ++ lists:join(", ",
                               [ern_namespace:text(Namespace) || Namespace <- lists:sort(Cycle)]));
        Sorted ->
            Sorted
    end.

%% One module parsed alone, its namespace checked against its parent's
%% source as it stands.
parse_module(Module, SourceRoot, DependencyRoots) ->
    parsed_module(Module, source_parsed(Module), SourceRoot, {DependencyRoots, #{}}).

%% A module's source parsed, as ern_parser answers, or the refusal of a
%% source that cannot be read, which fails the module as parsed_module/4
%% throws it.
source_parsed(#build_module{file = File}) ->
    try ern_parser:parse_string(read(File))
    catch
        throw:{cli_error, _} = Refused -> Refused
    end.

%% A module with its declarations and its dependencies, its namespace
%% checked against its parent's types and its own children, of which
%% Declared holds those the build has parsed, by file.
parsed_module(#build_module{file = File} = Module, Source, SourceRoot,
              {DependencyRoots, Declared}) ->
    case Source of
        {ok, Declarations} ->
            namespace_clash(Module#build_module{declarations = Declarations}, SourceRoot,
                            Declared),
            %% a module naming itself qualified (report §4.2) depends on nothing by it
            Dependencies = dependencies(Declarations, SourceRoot, DependencyRoots)
                -- [Module#build_module.namespace],
            Module#build_module{declarations = Declarations, dependencies = Dependencies};
        {error, Diagnostic} -> throw({errors, File, [Diagnostic]});
        {cli_error, _} = Refused -> throw(Refused)
    end.

%% Report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module. Checked from both files, so either finds it.
namespace_clash(#build_module{namespace = Namespace, relative = Relative,
                              declarations = Declarations}, SourceRoot, Declared) ->
    case Namespace of
        [_, _ | _] ->
            Parent = lists:droplast(Namespace),
            ParentRelative = module_path(Parent) ++ ".ern",
            ParentFile = absolute(filename:join(SourceRoot, ParentRelative)),
            lists:member(lists:last(Namespace), declared_types(ParentFile, Declared))
                andalso clash(SourceRoot, Relative, lists:last(Namespace), ParentRelative,
                              Namespace);
        _ ->
            ok
    end,
    lists:foreach(fun(Type) ->
                      ChildRelative = module_path(Namespace ++ [Type]) ++ ".ern",
                      filelib:is_regular(filename:join(SourceRoot, ChildRelative))
                          andalso clash(SourceRoot, ChildRelative, Type, Relative,
                                        Namespace ++ [Type])
                  end, local_types(Declarations)).

%% Report §11.5: the two files named from the working directory.
-spec clash(file:filename(), string(), atom(), string(), [atom()]) -> no_return().
clash(SourceRoot, ChildRelative, Type, ParentRelative, Namespace) ->
    fail(shown(filename:join(SourceRoot, ChildRelative)) ++ " and type " ++ atom_to_list(Type)
         ++ " in " ++ shown(filename:join(SourceRoot, ParentRelative))
         ++ " share the namespace " ++ ern_namespace:text(Namespace) ++ " (§4.2)").

%% The types a source declares: as the build parsed it, where it is a
%% module of the build, else parsed here.
declared_types(File, Declared) ->
    case Declared of
        #{File := Types} -> Types;
        _ -> source_types(File)
    end.

%% The types a parsed source declares; none when it is absent or does not parse.
source_types(File) ->
    case file:read_file(File) of
        {ok, Bytes} ->
            case ern_parser:parse_string(Bytes) of
                {ok, Declarations} -> local_types(Declarations);
                {error, _} -> []
            end;
        {error, _} ->
            []
    end.

local_types(Declarations) ->
    [Name || #type_declaration{name = Name} <- Declarations]
        ++ [Name
            || #abstract_declaration{declaration = #type_declaration{name = Name}} <- Declarations]
        ++ [Name || #foreign_type_declaration{name = Name} <- Declarations].

%% The modules a source refers to: every qualified name that is not a
%% member of one of this module's types and whose first segment is not a
%% namespace of the prelude or the standard library, and whose longest
%% prefix names an existing .ern under the root. Report §4.2: `T.name` is
%% the module's own member where its type `T` declares one of that name,
%% and the namespace T's `name` otherwise.
dependencies(Declarations, SourceRoot, DependencyRoots) ->
    %% in the standard library's root its own namespaces are dependencies
    Skip = case is_stdlib_root(SourceRoot) of
               true -> [];
               false -> taken_namespaces()
           end,
    Members = local_members(Declarations),
    Paths = lists:usort([Path || {Path, Name} <- references(Declarations), Path =/= [],
                                 not lists:member(hd(Path), Skip),
                                 not lists:member({Path, Name}, Members)]),
    lists:usort(lists:filtermap(fun(Path) -> module_prefix(Path, SourceRoot, DependencyRoots) end,
                                Paths)).

%% Each qualified reference of a source, its namespace and its last name; only a
%% value's lowercase name or operator can be a type's member.
references(#e_var{namespace = Namespace, name = Name}) -> [{Namespace, Name}];
references(#e_constructor{namespace = Namespace, name = Name, base = Base, args = Args}) ->
    [{Namespace, Name} | references(Base) ++ references(Args)];
references(#p_constructor{namespace = Namespace, name = Name, args = Args}) ->
    [{Namespace, Name} | references(Args)];
references(#t_named{namespace = Namespace, name = Name, args = Args}) ->
    [{Namespace, Name} | references(Args)];
references(Node) when is_tuple(Node) ->
    lists:append([references(Child) || Child <- tuple_to_list(Node)]);
references(Nodes) when is_list(Nodes) -> lists:append([references(Child) || Child <- Nodes]);
references(_) -> [].

%% The members this module's types declare, `T.name` as {[T], name}.
local_members(Declarations) ->
    [{[MemberOf], Name} || #fn_declaration{member_of = MemberOf, name = Name} <- Declarations,
                           MemberOf =/= undefined]
        ++ [{[MemberOf], Name}
            || #foreign_fn_declaration{member_of = MemberOf, name = Name} <- Declarations,
               MemberOf =/= undefined].

%% Report §11.1: a prefix of a qualified name is a module when the source
%% root holds its source, or the build root or a --load-path root,
%% DependencyRoots, its compiled module.
module_prefix([], _SourceRoot, _DependencyRoots) ->
    false;
module_prefix(Path, SourceRoot, DependencyRoots) ->
    Relative = module_path(Path),
    HoldsCompiled = fun(Dir) -> filelib:is_regular(filename:join(Dir, Relative ++ ".erc")) end,
    case filelib:is_regular(filename:join(SourceRoot, Relative ++ ".ern"))
        orelse lists:any(HoldsCompiled, DependencyRoots) of
        true -> {true, Path};
        false -> module_prefix(lists:droplast(Path), SourceRoot, DependencyRoots)
    end.

%% Report §11.1: the source root is --source-root; without it, the standard
%% library's root for a path under it, else Default.
-spec source_root([term()], file:filename(), file:filename()) -> file:filename().
source_root(Options, Path, Default) ->
    case proplists:get_value(source_root, Options) of
        undefined ->
            case relative(Path, stdlib_root()) of
                outside -> absolute(Default);
                _ -> stdlib_root()
            end;
        Given -> absolute(Given)
    end.

%% Report §11.1: the build directory is --build-root; without it, the source
%% root, and `build/stdlib` for the standard library's own root, where the
%% Makefile builds it.
-spec build_root([term()], file:filename()) -> file:filename().
build_root(Options, SourceRoot) ->
    case proplists:get_value(build_root, Options) of
        undefined ->
            case is_stdlib_root(SourceRoot) of
                true -> absolute(filename:join([tree(), "build", "stdlib"]));
                false -> SourceRoot
            end;
        Given -> absolute(Given)
    end.

%% Report §11.1: the standard library's own root takes its namespaces from
%% this build's .erc files, so its installed copy, which the checker reads
%% as the library and which a build of ern in another chunk format may have
%% written, is off the code path while the library builds; the directories
%% set aside, which return to the path when the build ends.
set_aside_installed_stdlib(SourceRoot, BuildRoot) ->
    case is_stdlib_root(SourceRoot) of
        true ->
            SetAside = [Dir || Dir <- code:get_path(), absolute(Dir) =:= BuildRoot],
            lists:foreach(fun code:del_path/1, SetAside),
            SetAside;
        false ->
            []
    end.

-spec is_stdlib_root(file:filename()) -> boolean().
is_stdlib_root(SourceRoot) ->
    absolute(SourceRoot) =:= stdlib_root().

%% Report §4.2: the standard library's source root, `src/stdlib/` in the
%% toolchain's tree.
stdlib_root() ->
    absolute(filename:join([tree(), "src", "stdlib"])).

%% The toolchain's tree, the checkout or an installation's lib/ernest, found
%% from where this module was loaded, its erl/cli/ebin.
tree() ->
    Here = absolute(code:which(?MODULE)),
    filename:dirname(filename:dirname(filename:dirname(filename:dirname(Here)))).

%% Report §4.2: the namespaces a module may not take, the prelude's and the
%% standard library's.
taken_namespaces() ->
    lists:usort(prelude_namespaces() ++ stdlib_namespaces()).

%% The prelude's own: `Prelude`, the name of the prelude itself, and each
%% of its types that has members; a prelude type without members takes no
%% namespace (report §4.2).
prelude_namespaces() ->
    lists:usort(['Prelude' | ern_prelude:member_types()]).

%% The standard library's modules at the top of the hierarchy.
stdlib_namespaces() ->
    lists:usort([hd(Interface#interface.namespace)
                 || Interface <- ern_prelude:stdlib_interfaces()]).

%% Type-check one module against its dependencies' interfaces, unless its
%% .erc is current (§11.1). Returns the interfaces with this module's added,
%% as its compiled form will hold it, its definitions' hashes and its
%% functions' positions among it; and none, or the module to emit, its
%% namespace, the modules of the build, of Namespaces, its forms reference,
%% and the emit, given the interfaces once those are checked, which answers
%% the compiled module where it is kept in memory and none where it is
%% written. Against is what the build is compiled against beside the
%% module's dependencies, built/3's.
build(#build_module{namespace = Namespace, file = File, relative = Relative,
                    declarations = Declarations, dependencies = Dependencies},
      Interfaces, SourceRoot, [BuildRoot | _] = DependencyRoots, Emit, Against, Namespaces) ->
    DependencyInterfaces = dependency_interfaces(Namespace, Dependencies, Interfaces,
                                                 DependencyRoots, SourceRoot),
    DependencyHashes = lists:sort([{Dependency, ern_interface:hash(DependencyInterface)}
                                   || {Dependency, DependencyInterface} <- DependencyInterfaces]),
    SourceHash = crypto:hash(sha256, read(File)),
    SourcePath = path_from(BuildRoot, File),
    OutputBase = filename:join(BuildRoot, filename:rootname(Relative)),
    Erc = OutputBase ++ ".erc",
    Given = [DependencyInterface || {_, DependencyInterface} <- DependencyInterfaces],
    case Emit =:= erc andalso current(Erc, SourceHash, SourcePath, DependencyHashes, Against,
                                      Given) of
        {true, Interface} ->
            {Interfaces#{Namespace => Interface}, none};
        false ->
            case ern_typecheck:check(Namespace, Declarations, Given) of
                {ok, Typed, Interface, Env} ->
                    Standard = is_stdlib_root(SourceRoot),
                    Canonical = ern_canonical:module(Namespace, Typed, Env, Standard),
                    Build = Against#{source_hash => SourceHash, source_path => SourcePath,
                                     deps => DependencyHashes, standard => Standard,
                                     source => list_to_binary(filename:basename(Relative)),
                                     canonical => Canonical},
                    Referenced = referenced(Canonical, Namespace, Namespaces),
                    Emitting = fun(Checked) ->
                                   Fresh = [maps:get(Module, Checked) || Module <- Referenced],
                                   Env1 = ern_typecheck:with_interfaces(Fresh, Env),
                                   emitted(Emit, Namespace, {Typed, Interface, Env1}, Build,
                                           OutputBase, Relative)
                               end,
                    Written = ern_interface:written(ern_canonical:interface(Interface, Canonical)),
                    {Interfaces#{Namespace => Written}, {Namespace, Referenced, Emitting}};
                {error, Diagnostics} ->
                    throw({errors, File, Diagnostics})
            end
    end.

%% Report §11.1: the modules of the build, of Namespaces, that a module's
%% forms name by name, a prelude name or an operator's resolution among
%% them, each the longest namespace of the build a name begins with; a
%% module named by hash is one it depends on, and is checked before it.
referenced(#{definitions := Definitions, foreign_schemes := ForeignSchemes}, Namespace,
           Namespaces) ->
    Forms = [Form || #definition{form = Form} <- Definitions] ++ maps:values(ForeignSchemes),
    lists:usort([Module || {named, QualifiedName} <- ern_compile:references(Forms),
                           Module <- longest_module(QualifiedName, Namespaces),
                           Module =/= Namespace]).

longest_module(QualifiedName, Namespaces) ->
    case [Prefix || Length <- lists:seq(length(QualifiedName) - 1, 1, -1),
                    Prefix <- [lists:sublist(QualifiedName, Length)],
                    lists:member(Prefix, Namespaces)] of
        [Module | _] -> [Module];
        [] -> []
    end.

%% A checked module written as Erlang source, written as a .erc, or kept in
%% memory for `ern doc`, which writes no .erc (report §11.4): the compiled
%% module where it is kept, none where it is written. Erlang source holds
%% no interface, but a service's and a spawn's hashes as the compiled
%% module does (§8.7), so its dependents are compiled against its hashes
%% too, which its check gave them (build/7).
emitted(erl, Namespace, {Typed, _Interface, Env}, Build, OutputBase, Relative) ->
    Erl = OutputBase ++ ".erl",
    ok = make_dirs(Erl),
    Source = ern_compile:erl_source(Namespace, Typed, Env, maps:with([standard, canonical], Build)),
    ok = write_output(Erl, unicode:characters_to_binary(["%% Generated by ern build from ",
                                                         Relative, "\n", Source])),
    none;
emitted(erc, Namespace, {Typed, Interface, Env}, Build, OutputBase, _) ->
    Erc = OutputBase ++ ".erc",
    ok = make_dirs(Erc),
    held_by_another(Erc, Namespace),
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    ok = write_output(Erc, Beam),
    none;
emitted(memory, Namespace, {Typed, Interface, Env}, Build, _, _) ->
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    Beam.

%% Report §11.1: a .erc that holds another namespace is not written over, as
%% a single-file build from another source root would: the file is another
%% module's. A regression: the build replaced it, and a run of a module
%% using it failed in the host's loader.
held_by_another(Erc, Namespace) ->
    case read_erc(Erc) of
        {ok, #{interface := #interface{namespace = Held}}} when Held =/= Namespace ->
            fail(shown(Erc) ++ " holds " ++ ern_namespace:text(Held)
                 ++ ", and this build names the module "
                 ++ ern_namespace:text(Namespace) ++ "; name its source root with --source-root");
        _ ->
            ok
    end.

%% Report §11.1: one hash over every installed standard library interface,
%% so that any change to one recompiles the modules built against it; an
%% operator can reach a standard library module no path names, so the whole
%% set is hashed. It is the installed library's, whatever the working
%% directory: a run and the shell check a module against it.
-spec stdlib_hash() -> binary().
stdlib_hash() ->
    Hashes = lists:sort([{Interface#interface.namespace, ern_interface:hash(Interface)}
                         || Interface <- ern_prelude:stdlib_interfaces()]),
    crypto:hash(sha256, term_to_binary(Hashes)).

%% Report §11.1: the interfaces a module is checked against, which its
%% `.erc` records: those of the modules its source names, Dependencies, and of
%% each module that declares a type an interface among them names, closed
%% over. A module of the standard library is left out, every interface of
%% the library being given to every checker already (ern_typecheck), except
%% in the library's own source root, where they are ordinary modules. The
%% closure is taken here, once the dependencies are compiled, and not when
%% the source is parsed: an interface exists only once its module is
%% built, and the order of a build needs nothing more, since a type reaches
%% an interface only through a module whose declaration reached that
%% module's checker, which this rule had already put among its dependencies.
-spec dependency_interfaces([atom()], [[atom()]], #{[atom()] => #interface{}},
                            [file:filename(), ...],
                            file:filename()) -> [{[atom()], #interface{}}].
dependency_interfaces(Namespace, Dependencies, Interfaces, DependencyRoots, SourceRoot) ->
    Skip = case is_stdlib_root(SourceRoot) of
               true -> [Namespace];
               false -> [Namespace | [[Name] || Name <- stdlib_namespaces()]]
           end,
    reached(Namespace,
            [dependency_interface(Namespace, Dependency, Interfaces, DependencyRoots, SourceRoot)
             || Dependency <- lists:usort(Dependencies)], Skip, Interfaces, DependencyRoots,
            SourceRoot).

reached(User, Found, Skip, Interfaces, DependencyRoots, SourceRoot) ->
    Have = [Dependency || {Dependency, _} <- Found],
    Named = lists:usort([Namespace || {_, Interface} <- Found, Namespace <- type_modules(Interface),
                                      not lists:member(Namespace, Skip),
                                      not lists:member(Namespace, Have)]),
    case Named of
        [] -> Found;
        _ ->
            reached(User,
                    Found
                    ++ [dependency_interface(User, Namespace, Interfaces, DependencyRoots,
                                             SourceRoot)
                        || Namespace <- Named],
                    Skip, Interfaces, DependencyRoots, SourceRoot)
    end.

%% The modules whose types an interface names, in its values' schemes and
%% its types' constructors: a type's qualified name less its last segment.
%% A type of one segment is the prelude's or a built-in, and no module's.
type_modules(#interface{} = Interface) ->
    lists:usort([lists:droplast(QualifiedName) || QualifiedName <- type_names(Interface, []),
                                                  length(QualifiedName) >= 2]).

type_names({tcon, QualifiedName, Args}, Acc) when is_list(QualifiedName) ->
    type_names(Args, [QualifiedName | Acc]);
type_names(Term, Acc) when is_tuple(Term) ->
    type_names(tuple_to_list(Term), Acc);
type_names(Term, Acc) when is_map(Term) ->
    type_names(maps:to_list(Term), Acc);
type_names([Head | Tail], Acc) ->
    type_names(Tail, type_names(Head, Acc));
type_names(_, Acc) ->
    Acc.

%% Report §11.1: a module outside the source root is found by its namespace
%% under the build directory, then under each --load-path root in order. A
%% stale .erc is no module. User is the module that uses it, which a
%% refusal names.
-spec dependency_interface([atom()], [atom()], #{[atom()] => #interface{}},
                           [file:filename(), ...], file:filename()) ->
          {[atom()], #interface{}}.
dependency_interface(User, Dependency, Interfaces, [BuildRoot | _] = DependencyRoots,
                     SourceRoot) ->
    case Interfaces of
        #{Dependency := Interface} -> {Dependency, Interface};
        _ ->
            Relative = module_path(Dependency) ++ ".erc",
            Found = [{Dir, Candidate} || Dir <- DependencyRoots,
                                         Candidate <- [filename:join(Dir, Relative)],
                                         filelib:is_regular(Candidate)],
            {Dir, Erc} = case Found of
                             [First | _] -> First;
                             [] -> {BuildRoot, filename:join(BuildRoot, Relative)}
                         end,
            case read_erc(Erc) of
                {ok, #{interface := Interface} = Chunk} ->
                    case gone(Chunk, Dir, SourceRoot) of
                        false -> {Dependency, Interface};
                        Source ->
                            fail("no module " ++ ern_namespace:text(Dependency) ++ ": "
                                 ++ shown(Erc) ++ " was compiled from " ++ shown(Source)
                                 ++ ", which no longer exists")
                    end;
                %% report §11.5: the path from the working directory, and
                %% the module that needs the one not compiled
                {error, Error} ->
                    fail("compile " ++ ern_namespace:text(Dependency) ++ " first, which "
                         ++ ern_namespace:text(User) ++ " uses: " ++ shown(Erc) ++ ": " ++ Error)
            end
    end.

%% Report §11.1: a .erc under the root Dir is stale when the source it
%% records, from Dir, lies under the source root and no longer exists; the
%% source is returned, and false for a .erc that is not.
gone(#{source_path := Recorded}, Dir, SourceRoot) ->
    Source = absolute(filename:join(Dir, unicode:characters_to_list(Recorded))),
    case relative(Source, SourceRoot) =/= outside andalso not filelib:is_regular(Source) of
        true -> Source;
        false -> false
    end;
gone(_, _, _) ->
    false.

-spec load_path([term()]) -> [file:filename()].
load_path(Options) ->
    [absolute(Dir) || {load_path, Dir} <- Options].

%% Report §11.1: whether a .erc is current, and its interface where it is:
%% current when the source and its path from the build root, every
%% dependency's interface, the standard library's interfaces, and the
%% build of the compiler, which Against holds, are those the .erc was built
%% from. Beside the hashes of the interfaces it was compiled against, the
%% hash of each other module's definition its forms reference is compared
%% with the hash that module's interface now holds, so that a change
%% confined to a dependency's bodies recompiles a dependent whose forms name
%% what changed.
current(Erc, SourceHash, SourcePath, DependencyHashes,
        #{stdlib := StdlibHash, compiler := CompilerBuild}, DependencyInterfaces) ->
    case read_erc(Erc) of
        {ok, #{interface := Interface, source_hash := SourceHash, source_path := SourcePath,
               deps := RecordedHashes, references := References, compiler := CompilerBuild,
               stdlib := StdlibHash}} ->
            Identities = lists:foldl(fun(#interface{identities = Held}, Acc) ->
                                         maps:merge(Acc, Held)
                                     end, #{}, DependencyInterfaces),
            Unchanged = [Hash || {QualifiedName, Hash} <- References,
                                 maps:get(QualifiedName, Identities, undefined) =:= Hash],
            case lists:sort(RecordedHashes) =:= DependencyHashes
                andalso length(Unchanged) =:= length(References) of
                true -> {true, Interface};
                false -> false
            end;
        _ -> false
    end.

%% Report §11.1: the modules whose code shapes a .erc: those that compile,
%% and every module of the toolchain they call, which a test holds them to.
-spec compiler_modules() -> [module()].
compiler_modules() ->
    [ern_ast, ern_bitspec, ern_bound, ern_canonical, ern_chunk, ern_compile, ern_descriptor,
     ern_diagnostic, ern_docs, ern_emitter, ern_exhaust, ern_format, ern_interface, ern_lexer,
     ern_namespace, ern_parser, ern_prelude, ern_pretty, ern_reply, ern_scope, ern_typecheck,
     ern_types, ern_build].

%% Report §11.1: the build of ern, its version and a hash of the modules
%% that compile, so that a compiler changed under one version is another.
compiler_build() ->
    Hash = erlang:md5(term_to_binary([code_md5(ErlangModule)
                                      || ErlangModule <- compiler_modules()])),
    <<(list_to_binary(?VERSION))/binary, $+, (binary:encode_hex(Hash, lowercase))/binary>>.

%% A module's code as the host digests it: as loaded, which is the code
%% that compiles, where the host has loaded the module; else as its file
%% holds it, which is what the host will load, so that a build that finds
%% every module current loads none of the compiler's code it does not run.
%% A file replaced between the digest and the load leaves the older code's
%% digest recorded, and the next build compiles the module again.
code_md5(ErlangModule) ->
    case erlang:module_loaded(ErlangModule) of
        true ->
            ErlangModule:module_info(md5);
        false ->
            {ok, {ErlangModule, Md5}} = beam_lib:md5(code:which(ErlangModule)),
            Md5
    end.

read_erc(Erc) ->
    case file:read_file(Erc) of
        {ok, Bytes} -> ern_interface:read(Bytes);
        {error, Error} -> {error, file:format_error(Error)}
    end.

%% Report §11.1: remove every stale .erc under the mirror of the compiled
%% subtree, and each directory of the subtree the removals leave empty.
sweep(Dir, SourceRoot, BuildRoot) ->
    Mirror = absolute(filename:join(BuildRoot, relative(Dir, SourceRoot))),
    lists:foreach(fun(Erc) ->
                      ok = delete(Erc),
                      remove_emptied(filename:dirname(Erc), Mirror, BuildRoot)
                  end, [Erc || Erc <- outputs(Mirror, ".erc"),
                               is_stale(Erc, BuildRoot, SourceRoot)]).

%% A .erc that does not read as this compiler's records nothing, and is kept.
is_stale(Erc, BuildRoot, SourceRoot) ->
    case read_erc(Erc) of
        {ok, Chunk} -> gone(Chunk, BuildRoot, SourceRoot) =/= false;
        {error, _} -> false
    end.

%% Report §11.1: every file of an extension under a directory, passing over
%% each name that begins with a dot, as sources/1 does, and each symbolic
%% link.
outputs(Dir, Extension) ->
    %% a name the host gives as its bytes is not UTF-8, and so no module's
    %% output, which is passed over as files_under/2 passes over a source
    case file:list_dir_all(Dir) of
        {ok, Names} ->
            lists:append([case file:read_link_info(Path) of
                              {ok, #file_info{type = directory}} -> outputs(Path, Extension);
                              {ok, #file_info{type = regular}} ->
                                  [Path || filename:extension(Name) =:= Extension];
                              _ -> []
                          end || Name <- lists:sort(Names), is_list(Name), hd(Name) =/= $.,
                                 Path <- [filename:join(Dir, Name)]]);
        {error, _} -> []
    end.

%% Report §11.4: remove every page `ern doc` wrote under the mirror of the
%% documented subtree whose module is not among Kept, and each directory
%% the removals leave empty. A page names its module in its title and
%% stands at the module's place; a file that does not is no page of `ern
%% doc`'s, and is kept.
-spec sweep_pages(markdown | man, file:filename(), file:filename(), file:filename(),
                  [[atom()]]) -> ok.
sweep_pages(Kind, Dir, SourceRoot, BuildRoot, Kept) ->
    Mirror = absolute(filename:join(BuildRoot, relative(Dir, SourceRoot))),
    Extension = case Kind of
                    markdown -> ".md";
                    man -> ".3ern"
                end,
    Names = [[atom_to_list(Segment) || Segment <- Namespace] || Namespace <- Kept],
    lists:foreach(fun(Page) ->
                      ok = delete(Page),
                      remove_emptied(filename:dirname(Page), Mirror, BuildRoot)
                  end, [Page || Page <- outputs(Mirror, Extension),
                                {ok, Segments} <- [page_of(Kind, Page, BuildRoot)],
                                not lists:member(Segments, Names)]).

%% The segments of the module a page documents, by its title, where the
%% page stands at that module's place. A title is no module's name until
%% the place agrees, so it is read as text.
page_of(Kind, Page, BuildRoot) ->
    Title = case {Kind, binary:split(read(Page), <<"\n">>, [global])} of
                {markdown, [<<"# Ernest module ", NamespaceText/binary>> | _]} ->
                    title(NamespaceText);
                {man, [_, <<".TH \"Ernest.", Rest/binary>> | _]} ->
                    [NamespaceText | _] = binary:split(Rest, <<"\"">>),
                    title(NamespaceText);
                _ -> none
            end,
    case Title of
        none -> none;
        _ ->
            Segments = string:split(Title, ".", all),
            Path = ern_namespace:path(Segments),
            %% a top-level module's page stands in the root itself, with no
            %% `./` before it, which the page's own path has none of
            Place = case {Kind, filename:dirname(Path)} of
                        {markdown, _} -> Path ++ ".md";
                        {man, "."} -> "Ernest." ++ Title ++ ".3ern";
                        {man, Directory} -> filename:join(Directory, "Ernest." ++ Title ++ ".3ern")
                    end,
            case relative(Page, BuildRoot) =:= Place of
                true -> {ok, Segments};
                false -> none
            end
    end.

title(Text) ->
    case unicode:characters_to_list(Text) of
        Title when is_list(Title) -> Title;
        _ -> none
    end.

%% A directory the sweep emptied, and each above it that it empties in turn,
%% up to the top of the swept subtree and never the build root; del_dir
%% removes a directory only when it is empty.
remove_emptied(Dir, Mirror, BuildRoot) ->
    case Dir =/= BuildRoot andalso relative(Dir, Mirror) =/= outside andalso file:del_dir(Dir) of
        ok -> remove_emptied(filename:dirname(Dir), Mirror, BuildRoot);
        _ -> ok
    end.

%% Report §11.2: a module compiled from its source for the shell, as
%% `ern build` would compile it but in memory, since `:load` and `:reload`
%% write nothing. SourceRoot is the source root and LoadPath the load
%% path, the roots a dependency outside the source root is found under by
%% its namespace, in order (§11.1). A dependency the session has loaded is
%% compiled against as Interfaces holds it, since it has no `.erc` or one
%% older than it. Units names the unit of each namespace whose unit is
%% not its module's Erlang name, the module's own among them, where a
%% reload brought a version as a unit of its own (§11.2). A refusal is a
%% sentence, and diagnostics come with the file they are in.
-spec compile_source(file:filename(), file:filename(), [file:filename(), ...],
                     #{[atom()] => #interface{}}, #{[atom()] => atom()}) ->
          {ok, [atom()], binary(), binary()} | {refused, string()}
          | {error, file:filename(), [ern_diagnostic:diagnostic()]}.
compile_source(File, SourceRoot, LoadPath, Interfaces, Units) ->
    compile_source(File, SourceRoot, LoadPath, Interfaces, Units, own).

%% The same, the module's spawn sites naming its declarations under
%% SiteNamespace, a reload's version's, `Counter$2` (§11.2), or under the
%% module's own namespace where it is `own`.
-spec compile_source(file:filename(), file:filename(), [file:filename(), ...],
                     #{[atom()] => #interface{}}, #{[atom()] => atom()}, own | [atom()]) ->
          {ok, [atom()], binary(), binary()} | {refused, string()}
          | {error, file:filename(), [ern_diagnostic:diagnostic()]}.
compile_source(File, SourceRoot, LoadPath, Interfaces, Units, SiteNamespace) ->
    try
        [#build_module{namespace = Namespace, relative = Relative, declarations = Declarations,
                       dependencies = Dependencies}] =
            compile_order([module_of(absolute(File), SourceRoot)], SourceRoot, LoadPath),
        DependencyInterfaces = dependency_interfaces(Namespace, Dependencies, Interfaces,
                                                     LoadPath, SourceRoot),
        DependencyHashes =
            lists:sort([{Dependency, ern_interface:hash(DependencyInterface)}
                        || {Dependency, DependencyInterface} <- DependencyInterfaces]),
        Hash = crypto:hash(sha256, read(File)),
        Given = [DependencyInterface || {_, DependencyInterface} <- DependencyInterfaces],
        case ern_typecheck:check(Namespace, Declarations, Given) of
            {ok, Typed, Interface, Env} ->
                %% the dependencies are recorded as `ern build` records them, so
                %% the shell loads them before the module (report §11.2)
                Build = #{source_hash => Hash, deps => DependencyHashes,
                          source => list_to_binary(filename:basename(Relative)), units => Units},
                Sites = case SiteNamespace of
                            own -> #{};
                            _ -> #{site_namespace => SiteNamespace}
                        end,
                {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env,
                                                   maps:merge(Build, Sites)),
                {ok, Namespace, Beam, Hash};
            {error, Diagnostics} ->
                {error, File, Diagnostics}
        end
    catch
        throw:{cli_error, Message} -> {refused, Message};
        %% a source that does not lex or parse is refused as one that does
        %% not check is, its diagnostics given back and not raised
        throw:{errors, FailedFile, ParseDiagnostics} -> {error, FailedFile, ParseDiagnostics}
    end.

%%
%% Options and paths
%%

%% Absolute and normalized: no `.` or `..` segments, so that a default root
%% of `.` is a prefix of the files under it.
-spec absolute(file:filename()) -> file:filename().
absolute(Path) ->
    filename:join(normalize(filename:split(filename:absname(Path)), [])).

normalize([], Acc) -> lists:reverse(Acc);
normalize(["." | Rest], Acc) -> normalize(Rest, Acc);
normalize([".." | Rest], [_ | Acc]) -> normalize(Rest, Acc);
normalize([Segment | Rest], Acc) -> normalize(Rest, [Segment | Acc]).

%% Path relative to Base, or outside.
-spec relative(file:filename(), file:filename()) -> file:filename() | outside.
relative(Path, Base) ->
    PathParts = filename:split(absolute(Path)),
    RootParts = filename:split(absolute(Base)),
    case lists:prefix(RootParts, PathParts) of
        true ->
            case lists:nthtail(length(RootParts), PathParts) of
                [] -> ".";
                Rest -> filename:join(Rest)
            end;
        false -> outside
    end.

%% The path from the directory Base to Path, a `..` for each segment of Base
%% the two do not share, as the ErnI chunk records it.
path_from(Base, Path) ->
    unicode:characters_to_binary(unshared(filename:split(absolute(Base)),
                                          filename:split(absolute(Path)))).

unshared([Segment | Base], [Segment | Path]) -> unshared(Base, Path);
unshared(Base, Path) -> filename:join([".." || _ <- Base] ++ Path).

%% Report §11: a file a job writes is written whole or not at all. It is
%% written beside its place, under a name that begins with a dot, which no
%% job reads as a module (§11.1), with the mode the file has or Mode, and
%% then renamed into its place, which the host does at once. A link is
%% followed, so that it stays a link to the file written.
-spec write_whole(file:filename(), iodata()) -> ok.
write_whole(File, Data) ->
    write_at(File, followed(File, 0), Data, undefined).

%% Report §11: what a build or `ern doc` writes, whole, as write_whole/2
%% writes it, but in its place: a link there is replaced, not followed, so
%% that a link planted in a build tree names nothing the build writes.
-spec write_output(file:filename(), iodata()) -> ok.
write_output(File, Data) ->
    write_output(File, Data, undefined).

-spec write_output(file:filename(), iodata(), non_neg_integer() | undefined) -> ok.
write_output(File, Data, Mode) ->
    write_at(File, File, Data, Mode).

%% File's data written at Place, the file itself or where its links lead.
write_at(File, Place, Data, Mode) ->
    Info = file:read_link_info(Place),
    %% report §11: a file its owner may not write is refused, not replaced
    case Info of
        {ok, #file_info{access = Access}} when Access =:= read; Access =:= none ->
            fail(shown(File) ++ ": " ++ file:format_error(eacces));
        _ ->
            ok
    end,
    Kept = case {Mode, Info} of
               {undefined, {ok, #file_info{type = regular, mode = Existing}}} ->
                   Existing band 8#7777;
               {undefined, _} -> undefined;
               {Given, _} -> Given
           end,
    {New, Device} = made_beside(File, Place, 0),
    %% the mode before the data, so that what is private is never readable
    Steps = [fun() -> file:change_mode(New, Kept) end || Kept =/= undefined]
        ++ [fun() -> file:write(Device, Data) end, fun() -> file:close(Device) end,
            fun() -> file:rename(New, Place) end],
    case lists:foldl(fun(Step, ok) -> Step(); (_, Failed) -> Failed end, ok, Steps) of
        ok ->
            ok;
        {error, Error} ->
            _ = file:close(Device),
            _ = file:delete(New),
            fail(shown(File) ++ ": " ++ file:format_error(Error))
    end.

%% A file of this writer's own beside Place, open, under a name of its own,
%% so that two jobs writing one file at once each write theirs whole and
%% the last rename wins (report §11). It is made here or not at all: the
%% host refuses a name that is there, a link among them, so that a name
%% another planted is passed over for the next and is never written
%% through.
made_beside(File, Place, Tries) ->
    Own = os:getpid() ++ "." ++ integer_to_list(erlang:unique_integer([positive])),
    New = filename:join(filename:dirname(Place),
                        "." ++ filename:basename(Place) ++ "." ++ Own ++ ".new"),
    case file:open(New, [write, exclusive, raw]) of
        {ok, Device} -> {New, Device};
        {error, eexist} when Tries < 16 -> made_beside(File, Place, Tries + 1);
        {error, Error} -> fail(shown(File) ++ ": " ++ file:format_error(Error))
    end.

%% Report §11.8: a file a job cannot read, a directory it cannot make, and
%% a file it cannot remove are refused with the host's reason, status 1.
%% A file already gone is removed.
-spec read(file:filename_all()) -> binary().
read(File) ->
    case file:read_file(File) of
        {ok, Bytes} -> Bytes;
        {error, Error} -> refused(File, Error)
    end.

%% Makes the directories a file is written under.
-spec make_dirs(file:filename()) -> ok.
make_dirs(File) ->
    case filelib:ensure_dir(File) of
        ok -> ok;
        {error, Error} -> refused(filename:dirname(File), Error)
    end.

delete(File) ->
    case file:delete(File) of
        ok -> ok;
        {error, enoent} -> ok;
        {error, Error} -> refused(File, Error)
    end.

%% Report §11.5: a file named from the working directory, and a name the
%% host gives as bytes as its bytes.
-spec refused(file:filename_all(), term()) -> no_return().
refused(File, Error) when is_list(File) ->
    fail(shown(File) ++ ": " ++ file:format_error(Error));
refused(File, Error) ->
    fail(bytes_text(File) ++ ": " ++ file:format_error(Error)).

%% The file a path names, its links followed, as the host follows them, up
%% to a depth past which the host would refuse the path.
followed(Path, 40) ->
    Path;
followed(Path, Depth) ->
    case file:read_link_all(Path) of
        {ok, Link} -> followed(filename:absname(Link, filename:dirname(Path)), Depth + 1);
        {error, _} -> Path
    end.

-spec fail(iodata()) -> no_return().
fail(Message) ->
    throw({cli_error, lists:flatten(Message)}).

