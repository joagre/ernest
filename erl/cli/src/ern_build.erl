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

-export([compile/4, compile_in_memory/5, held_another/3, verbose/2, modules_of/3,
         compiled_in_order/3,
         report_errors/4, shown/1, sources/1, compiled_under/1, bytes_text/1, module_of/2,
         module_of/3, shape/2, compile_order/2, compile_order/3, module_cycle/1,
         compiled_dependencies/1, source_root/3, build_root/2, is_stdlib_root/1, stdlib_hash/0,
         dependency_interfaces/5, load_path/1, is_compiled_against/4, compiler_modules/0,
         compiler_build/0, sweep_pages/5, compile_source/5, compile_source/6, absolute/1,
         relative/2, write_whole/2, write_output/2, write_output/3, read/1, make_dirs/1,
         refused/2, fail/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("checker/include/ern_canonical.hrl").
-include_lib("shared/include/ern_diagnostic.hrl").
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

%% Report §11.4: the same, writing nothing and removing nothing, for `ern
%% doc` to read its pages from: every module is compiled but those Given
%% holds, each the compiled module `ern doc` read from its .erc, which is
%% not compiled again, and the compiled modules, Given's among them, are
%% answered with the status.
-spec compile_in_memory(string(), [term()], file:filename(), io:device(),
                        #{[atom()] => binary()}) -> {0 | 1, #{[atom()] => binary()}}.
compile_in_memory(Job, Options, Path, ErrorDevice, Given) ->
    compile(Job, Options, Path, ErrorDevice, {memory, Given}).

compile(Job, Options, Path, ErrorDevice, Emit) ->
    filelib:is_file(Path) orelse fail(Path ++ ": no such file"),
    IsDirectory = filelib:is_dir(Path),
    %% report §11.1: --verbose says each decision as it is made
    Say = verbose(Options, ErrorDevice),
    SourceRoot = source_root(Options, Path, case IsDirectory of true -> Path; false -> "." end),
    Say(["source root ", shown(SourceRoot)]),
    BuildRoot = build_root(Options, SourceRoot),
    Say(["build root ", shown(BuildRoot)]),
    Files = case IsDirectory of
                true -> sources(Path);
                false -> [Path]
            end,
    Mode = case IsDirectory of
               true -> tree;
               false -> file
           end,
    %% report §11.1: a path that is no module's fails that file alone, and
    %% the rest are built; so does a module whose .erc holds another's
    {Found, Misnamed} = modules_of(Files, SourceRoot, Mode),
    IsRootGiven = proplists:is_defined(source_root, Options),
    {Modules, Held} = case Emit of
                          erc -> unheld(Found, BuildRoot, IsRootGiven);
                          _ -> {Found, []}
                      end,
    %% report §11.1: the roots a dependency is found under, the build root
    %% and then each root of the load path
    DependencyRoots = [BuildRoot | load_path(Options)],
    SetAside = set_aside_installed_stdlib(SourceRoot),
    try
        %% report §11.1: a module outside the source root is found under
        %% build-root, then under each --load-path root
        {Parsed, Unparsed1} = parse_all(Modules, SourceRoot, DependencyRoots),
        Unparsed = Misnamed ++ Held ++ Unparsed1,
        %% report §11.1: the library's own modules depend on each other as
        %% ordinary modules do, and record no hash of it
        StdlibHash = case is_stdlib_root(SourceRoot) of
                         true -> none;
                         false -> stdlib_hash()
                     end,
        %% report §11.1, §4.1: a cycle through the load path's modules is
        %% refused as one among the sources is
        BuildNamespaces = [Namespace || #build_module{namespace = Namespace} <- Modules],
        Outside = fun(Namespace) ->
                      case lists:member(Namespace, BuildNamespaces) of
                          true -> [];
                          false -> recorded_uses(Namespace, DependencyRoots, SourceRoot, Say)
                      end
                  end,
        {Failed, Compiled} = built(order(Parsed, Outside), Unparsed,
                                   {SourceRoot, DependencyRoots, Emit, StdlibHash}, Say),
        case [{Failure, Diagnostics} || {_, Failure, Diagnostics} <- Failed] of
            [] ->
                IsDirectory andalso Emit =:= erc
                    andalso sweep(absolute(Path), SourceRoot, BuildRoot, Say),
                {0, Compiled};
            Reported ->
                [report_failure(Job, Options, Failure,
                                nearer_roots(Failure, Diagnostics, SourceRoot, IsRootGiven),
                                ErrorDevice)
                 || {Failure, Diagnostics} <- Reported],
                {1, Compiled}
        end
    after
        put_back(SetAside)
    end.

%% Report §11.1: a .erc that holds another namespace than the build names
%% is not written over, as a build of a file under another source root
%% would write it: the file is another module's, and its module fails, by
%% its namespace, so that a module that uses it is not compiled either.
%% Where the build was given no source root, the refusal names the option
%% that names one; where it was, the file is to be removed. The modules
%% the build compiles, and those it refuses so.
unheld(Modules, BuildRoot, IsRootGiven) ->
    lists:foldr(fun(#build_module{namespace = Namespace, relative = Relative} = Module,
                    {Kept, Held}) ->
                        Erc = filename:join(BuildRoot, filename:rootname(Relative)) ++ ".erc",
                        case read_erc(Erc) of
                            {ok, #{interface := #interface{namespace = Other}}}
                              when Other =/= Namespace ->
                                Refusal = held_by_another(Erc, Other, Namespace, IsRootGiven),
                                {Kept, [{Namespace, {refused, Refusal}, []} | Held]};
                            _ ->
                                {[Module | Kept], Held}
                        end
                end, {[], []}, Modules).

held_by_another(Erc, Other, Namespace, false) ->
    lists:flatten([shown(Erc), " holds ", ern_namespace:text(Other), ", not ",
                   ern_namespace:text(Namespace), "; name ", ern_namespace:text(Namespace),
                   "'s source root with --source-root"]);
held_by_another(Erc, Other, Namespace, true) ->
    lists:flatten([shown(Erc), " holds ", ern_namespace:text(Other), ", not ",
                   ern_namespace:text(Namespace), ", and a build writes over no other module's"
                   " file; remove it to build ", ern_namespace:text(Namespace), " there"]).

%% Report §11.1, §11.2: a file found by a module's namespace that holds
%% another module, Held, the refusal a build's and a run's reading of it
%% give: it is no module of that name, and the module is built where it
%% goes once the file is gone.
-spec held_another(file:filename(), [atom()], [atom()]) -> string().
held_another(File, Held, Namespace) ->
    lists:flatten([shown(File), " holds ", ern_namespace:text(Held), ", not ",
                   ern_namespace:text(Namespace), "; remove it, and build ",
                   ern_namespace:text(Namespace), " from its source root"]).

%% Report §11.1, §11.5: a module's errors, each unknown qualified name
%% given the help, where the build was given no source root and the error
%% has none, of a source root nearer the module's file under which the
%% name's module is a source, `this module is Src.Main; --source-root src
%% makes it Main`; a failure that is no file's as it is.
nearer_roots(File, Diagnostics, SourceRoot, false) when is_list(File) ->
    [nearer_root(Diagnostic, File, SourceRoot) || Diagnostic <- Diagnostics];
nearer_roots(_Failure, Diagnostics, _SourceRoot, _IsRootGiven) ->
    Diagnostics.

nearer_root(#diagnostic{unknown_namespace = [_ | _] = Namespace, help = undefined} = Diagnostic,
            File, SourceRoot) ->
    case relative(File, SourceRoot) of
        outside ->
            Diagnostic;
        Relative ->
            Components = filename:split(filename:rootname(Relative)),
            Directories = lists:droplast(Components),
            Roots = [lists:sublist(Directories, Depth)
                     || Depth <- lists:seq(1, length(Directories))],
            case [Root || Root <- Roots,
                          names_a_source(Namespace, filename:join([SourceRoot | Root]))] of
                [] ->
                    Diagnostic;
                [Root | _] ->
                    Module = ern_namespace:namespace(Components),
                    Nearer = ern_namespace:namespace(lists:nthtail(length(Root), Components)),
                    Help = ["this module is ", ern_namespace:text(Module), "; --source-root ",
                            shown(filename:join([SourceRoot | Root])), " makes it ",
                            ern_namespace:text(Nearer)],
                    Diagnostic#diagnostic{help = lists:flatten(Help)}
            end
    end;
nearer_root(Diagnostic, _File, _SourceRoot) ->
    Diagnostic.

%% Whether a prefix of Namespace is a module whose source lies under Root.
names_a_source([], _Root) ->
    false;
names_a_source(Namespace, Root) ->
    filelib:is_regular(filename:join(Root, ern_namespace:module_path(Namespace) ++ ".ern"))
        orelse names_a_source(lists:droplast(Namespace), Root).

%% Report §11.1, §11.2: what --verbose writes with, a line on the job's
%% ErrorDevice for each decision as the job makes it, where Options hold
%% the flag, and nothing where they do not.
-spec verbose([term()], io:device()) -> fun((iodata()) -> ok).
verbose(Options, ErrorDevice) ->
    case lists:member(verbose, Options) of
        true -> fun(Line) -> io:format(ErrorDevice, "~ts~n", [Line]) end;
        false -> fun(_) -> ok end
    end.

%% The modules the files are, and a failure for each file whose path is
%% none's, keyed by the file, since it has no namespace.
-spec modules_of([file:filename()], file:filename(), tree | file) ->
          {[#build_module{}], [{{file, file:filename()}, {refused, string()}, []}]}.
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
%% BuildRoot for any other: the modules that failed, as built/4 answers
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
    SetAside = set_aside_installed_stdlib(SourceRoot),
    try
        %% a build in memory writes nothing, and so says nothing
        built(Order, [], {SourceRoot, [BuildRoot], {memory, #{}}, StdlibHash}, fun(_) -> ok end)
    after
        put_back(SetAside)
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
%% modules compiled in memory, by namespace. Say says each module written
%% (report §11.1, --verbose).
built(Order, Unparsed, {SourceRoot, DependencyRoots, Emit, StdlibHash}, Say) ->
    Namespaces = [Namespace || #build_module{namespace = Namespace} <- Order],
    %% report §11.1: what every module of the build is compiled against
    %% beside its dependencies, the standard library and the build of
    %% `ern`, as its .erc records them, found once for the build
    Against = #{stdlib => StdlibHash, compiler => compiler_build()},
    BuildModule = fun(Module, Interfaces) ->
                      build(Module, Interfaces, SourceRoot, DependencyRoots, Emit, Against,
                            Namespaces, Say)
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

%% A module's failure as built/4 answers it: its errors; and, report
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
    %% or the standard library, nor under one, except in the standard
    %% library's own source root; the message names which of the two takes
    %% it, the prelude where both do
    [First | Under] = Namespace,
    Taken = case Under of
                [] -> " takes the ";
                _ -> " stands under the "
            end,
    not is_stdlib_root(SourceRoot) andalso
        case {lists:member(First, prelude_namespaces()),
              lists:member(First, stdlib_namespaces())} of
            {true, _} ->
                fail(Shown ++ Taken ++ "prelude namespace " ++ atom_to_list(First));
            {false, true} ->
                fail(Shown ++ Taken ++ "standard library namespace " ++ atom_to_list(First));
            {false, false} ->
                ok
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

%% Parse every module, find its dependencies, and order them; a cycle among
%% them is an error naming the modules in it (§11.1). What a module of the
%% load path records that it uses is not read here: the shell, which
%% orders what a load compiles so, refuses a cycle through the load path as
%% it places the modules (ern_shell), and `ern doc` of one file makes a
%% page and no build.
-spec compile_order([#build_module{}], file:filename()) -> [#build_module{}].
compile_order(Modules, SourceRoot) ->
    compile_order(Modules, SourceRoot, []).

-spec compile_order([#build_module{}], file:filename(), [file:filename()]) -> [#build_module{}].
compile_order(Modules, SourceRoot, DependencyRoots) ->
    order([parse_module(Module, SourceRoot, DependencyRoots) || Module <- Modules]).

%% Every module parsed, and each that does not parse with its errors, as a
%% build reports them (report §11.5). Every source is parsed before any
%% module is checked against its parent, so that the check reads the
%% members a module of the build exports from its parse, and parses a
%% parent's source no more for each of its children (report §4.2).
parse_all(Modules, SourceRoot, DependencyRoots) ->
    Sources = [{Module, source_parsed(Module)} || Module <- Modules],
    Declared = maps:from_list([{File, Declarations}
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

%% The parsed modules in an order where each follows those it uses, and
%% otherwise keeps its place among them, the order of their paths; a cycle
%% is an error naming the modules in it (§11.1).
order(Parsed) ->
    order(Parsed, fun(_) -> [] end).

%% The same, the graph holding beside the parsed modules every module they
%% use outside them, directly or through another, with the modules Outside
%% answers that it uses, so that a cycle through those is found too.
order(Parsed, Outside) ->
    %% the graph is tables of this process's, deleted whether or not the
    %% order is found
    Graph = digraph:new(),
    Order = try
                lists:foreach(fun(#build_module{namespace = Namespace}) ->
                                  digraph:add_vertex(Graph, Namespace)
                              end, Parsed),
                lists:foreach(fun(#build_module{namespace = Namespace,
                                                dependencies = Dependencies}) ->
                                  uses(Graph, Namespace, Dependencies)
                              end, Parsed),
                Seen = maps:from_keys([Namespace || #build_module{namespace = Namespace} <- Parsed],
                                      true),
                outside_uses(Graph, [Dependency
                                     || #build_module{dependencies = Dependencies} <- Parsed,
                                        Dependency <- Dependencies], Outside, Seen),
                acyclic(Graph),
                ordered(Graph, [Namespace || #build_module{namespace = Namespace} <- Parsed])
            after
                digraph:delete(Graph)
            end,
    ByNamespace = maps:from_list([{Namespace, Module}
                                  || #build_module{namespace = Namespace} = Module <- Parsed]),
    [maps:get(Namespace, ByNamespace) || Namespace <- Order, is_map_key(Namespace, ByNamespace)].

%% The edges from each module Namespace uses to it.
uses(Graph, Namespace, Dependencies) ->
    lists:foreach(fun(Dependency) ->
                      digraph:add_vertex(Graph, Dependency),
                      digraph:add_edge(Graph, Dependency, Namespace)
                  end, Dependencies).

%% Each module outside the parsed ones with what it uses, as Outside
%% answers it, and each of those in turn, once; Seen holds the parsed
%% modules and those done.
outside_uses(_Graph, [], _Outside, _Seen) ->
    ok;
outside_uses(Graph, [Namespace | Rest], Outside, Seen) when is_map_key(Namespace, Seen) ->
    outside_uses(Graph, Rest, Outside, Seen);
outside_uses(Graph, [Namespace | Rest], Outside, Seen) ->
    Dependencies = Outside(Namespace),
    uses(Graph, Namespace, Dependencies),
    outside_uses(Graph, Dependencies ++ Rest, Outside, Seen#{Namespace => true}).

%% Report §11.1, §4.1: a cycle among the graph's modules refused, naming
%% the modules in it.
acyclic(Graph) ->
    case digraph_utils:is_acyclic(Graph) of
        false ->
            [Cycle | _] = digraph_utils:cyclic_strong_components(Graph),
            fail(module_cycle(Cycle));
        true ->
            ok
    end.

%% Each module of the acyclic Graph after the modules it uses, taken in
%% the order of Namespaces, and those a module uses in the order of their
%% namespaces, so that the order is the build's alone: the host's tables
%% behind the graph give their vertices in an order that follows its atom
%% table, which every job before the build has added to.
ordered(Graph, Namespaces) ->
    {Order, _} = lists:foldl(fun(Namespace, Acc) -> visited(Graph, Namespace, Acc) end,
                             {[], #{}}, Namespaces),
    lists:reverse(Order).

visited(_Graph, Namespace, {_, Seen} = Acc) when is_map_key(Namespace, Seen) ->
    Acc;
visited(Graph, Namespace, {Order, Seen}) ->
    {Order1, Seen1} = lists:foldl(fun(Used, Acc) -> visited(Graph, Used, Acc) end,
                                  {Order, Seen#{Namespace => true}},
                                  lists:sort(digraph:in_neighbours(Graph, Namespace))),
    {[Namespace | Order1], Seen1}.

%% Report §11.1: a cycle among modules as the build, the runner and the
%% shell report it, its modules in order.
-spec module_cycle([[atom()]]) -> string().
module_cycle(Cycle) ->
    Names = [ern_namespace:text(Namespace) || Namespace <- lists:sort(Cycle)],
    lists:flatten(["module cycle: ", lists:join(", ", Names)]).

%% One module parsed alone, the values it exports checked against the
%% members of its parent's type of its name (member_clash/2), its parent
%% read as it stands.
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

%% A module with its declarations and its dependencies, its exported
%% functions checked against the members of its parent's type of its name,
%% the parent's declarations read from Declared, which holds the build's
%% parsed modules by file, where the build parses it.
parsed_module(#build_module{file = File} = Module, Source, SourceRoot,
              {DependencyRoots, Declared}) ->
    case Source of
        {ok, Declarations} ->
            TypeMembers = fun(Parent, Type) ->
                              type_members(Parent, Type, SourceRoot, DependencyRoots, Declared)
                          end,
            member_clash(Module#build_module{declarations = Declarations}, TypeMembers),
            %% a module naming itself qualified (report §4.2) depends on nothing by it
            Dependencies = dependencies(Declarations, SourceRoot, DependencyRoots, TypeMembers)
                -- [Module#build_module.namespace],
            Module#build_module{declarations = Declarations, dependencies = Dependencies};
        {error, Diagnostic} -> throw({errors, File, [Diagnostic]});
        {cli_error, _} = Refused -> throw(Refused)
    end.

%% Report §4.2, §11.5: the module of a type's name shares the type's
%% namespace, and a value it exports under the name of a member of the
%% type, which its parent exports, a function or a top-level `let`, is an
%% error at the value's declaration, since `M.T.f` would name both.
member_clash(#build_module{namespace = [_, _ | _] = Namespace, file = File,
                           declarations = Declarations}, TypeMembers) ->
    Parent = lists:droplast(Namespace),
    Type = lists:last(Namespace),
    ParentMembers = TypeMembers(Parent, Type),
    case [{Span, Name} || {Span, Name} <- exported_values(Declarations),
                          lists:member(Name, ParentMembers)] of
        [] ->
            ok;
        [{Span, Name} | _] ->
            %% report §11.5: the module that declares the type, by its
            %% name, which a source or a .erc may hold
            Message = ern_namespace:text(Namespace ++ [Name]) ++ " is a member of the type "
                ++ atom_to_list(Type) ++ " in the module " ++ ern_namespace:text(Parent),
            throw({errors, File, [#diagnostic{span = ern_diagnostic:span(Span),
                                              message = Message}]})
    end;
member_clash(_, _) ->
    ok.

%% A module's exported values, a `fn`, a `foreign fn` and a top-level
%% `let`, that are no type's member, each with its declaration's span, in
%% the order the module declares them.
exported_values(Declarations) ->
    lists:append([exported_value(Declaration) || Declaration <- Declarations]).

exported_value(#fn_declaration{span = Span, export = true, member_of = undefined, name = Name}) ->
    [{Span, Name}];
exported_value(#foreign_fn_declaration{span = Span, export = true, member_of = undefined,
                                       name = Name}) ->
    [{Span, Name}];
exported_value(#let_declaration{span = Span, export = true, name = Name}) ->
    [{Span, Name}];
exported_value(_) ->
    [].

%% Report §4.2, §11.2: the names of the members the module Parent exports of
%% its exported type Type, as its interface holds them under Parent.Type:
%% from the build's parse where Parent is a module of the build, from its
%% source under the source root where it is there, and else from its
%% compiled form under DependencyRoots, found as a dependency is; none
%% where no root holds the module.
type_members(Parent, Type, SourceRoot, DependencyRoots, Declared) ->
    File = absolute(filename:join(SourceRoot, ern_namespace:module_path(Parent) ++ ".ern")),
    case Declared of
        #{File := Declarations} -> exported_members(Declarations, Type);
        _ ->
            case source_declarations(File) of
                {ok, Declarations} -> exported_members(Declarations, Type);
                none -> interface_members(Parent, Type, DependencyRoots, SourceRoot)
            end
    end.

%% The declarations a source holds; none when it is absent or does not parse.
source_declarations(File) ->
    case file:read_file(File) of
        {ok, Bytes} ->
            case ern_parser:parse_string(Bytes) of
                {ok, Declarations} -> {ok, Declarations};
                {error, _} -> none
            end;
        {error, _} ->
            none
    end.

%% Report §3.5, §4.2: the members of the exported type Type a module's
%% declarations export: each declared `export`, and a derived `compare`.
exported_members(Declarations, Type) ->
    case [Derives || Declaration <- Declarations,
                     {true, Name, Derives} <- [exported_type(Declaration)], Name =:= Type] of
        [] ->
            [];
        [Derives | _] ->
            [compare || Derives =/= undefined]
                ++ [Name || #fn_declaration{export = true, member_of = MemberOf, name = Name}
                                <- Declarations, MemberOf =:= Type]
                ++ [Name || #foreign_fn_declaration{export = true, member_of = MemberOf,
                                                    name = Name} <- Declarations,
                            MemberOf =:= Type]
    end.

%% A type declaration's export, its name and its `derives`.
exported_type(#type_declaration{export = Export, name = Name, derives = Derives}) ->
    {Export, Name, Derives};
exported_type(#abstract_declaration{export = Export,
                                    declaration = #type_declaration{name = Name,
                                                                    derives = Derives}}) ->
    {Export, Name, Derives};
exported_type(#foreign_type_declaration{export = Export, name = Name}) ->
    {Export, Name, undefined};
exported_type(_) ->
    {false, none, undefined}.

%% The same, from the interface of the module's compiled form; none where
%% no root holds it, it does not read, or it is stale. Where SourceRoot is
%% none, as for a doc example, the compiled form is taken as it stands, as
%% a run takes it (report §11.2).
interface_members(Parent, Type, DependencyRoots, SourceRoot) ->
    case compiled_found(Parent, DependencyRoots) of
        {Dir, Erc} ->
            case read_erc(Erc) of
                {ok, #{interface := #interface{types = Types, values = Values}} = Chunk} ->
                    TypeName = Parent ++ [Type],
                    Fresh = SourceRoot =:= none orelse gone(Chunk, Dir, SourceRoot) =:= false,
                    [lists:last(QualifiedName) || Fresh, is_map_key(TypeName, Types),
                                                  QualifiedName <- maps:keys(Values),
                                                  lists:droplast(QualifiedName) =:= TypeName];
                {error, _} ->
                    []
            end;
        none ->
            []
    end.

%% The modules a source refers to: every qualified name that is not a
%% member of one of this module's types and whose first segment is not a
%% namespace of the prelude or the standard library, and whose longest
%% prefix names a module: a source under the source root, or a compiled
%% module under the build root or a --load-path root, DependencyRoots.
%% Report §4.2: `T.name` is the module's own member where its type `T`
%% declares one of that name, and the namespace T's `name` otherwise; and
%% `M.T.name`, where the module M.T exists, is the module M's where
%% TypeMembers says its exported type T has a member of that name, and
%% M.T's otherwise.
dependencies(Declarations, SourceRoot, DependencyRoots, TypeMembers) ->
    %% in the standard library's root its own namespaces are dependencies
    Skip = case is_stdlib_root(SourceRoot) of
               true -> [];
               false -> taken_namespaces()
           end,
    IsModule = fun(Relative) ->
                   filelib:is_regular(filename:join(SourceRoot, Relative ++ ".ern"))
                       orelse is_compiled(Relative, DependencyRoots)
               end,
    named_modules(Declarations, Skip, IsModule, TypeMembers).

%% Report §11.2: the function that answers the modules a doc example's
%% declarations name, as dependencies/4 finds a module's where there is no
%% source: a module is its compiled form under a root of LoadPath, and a
%% type's members are read from its interface; the prelude's and the
%% standard library's namespaces aside, which every check is given, and
%% which are read once for every example it answers (ern_examples).
-spec compiled_dependencies([file:filename()]) -> fun(([tuple()]) -> [[atom()]]).
compiled_dependencies(LoadPath) ->
    Skip = taken_namespaces(),
    IsModule = fun(Relative) -> is_compiled(Relative, LoadPath) end,
    TypeMembers = fun(Parent, Type) -> interface_members(Parent, Type, LoadPath, none) end,
    fun(Declarations) -> named_modules(Declarations, Skip, IsModule, TypeMembers) end.

%% The modules Declarations name, the namespaces Skip aside, each the
%% longest prefix of a qualified name whose path IsModule answers is a
%% module's, or the module M of `M.T.name` where TypeMembers says so.
named_modules(Declarations, Skip, IsModule, TypeMembers) ->
    OwnMembers = local_members(Declarations),
    References = lists:usort([{Path, Name} || {Path, Name} <- references(Declarations),
                                              Path =/= [], not lists:member(hd(Path), Skip),
                                              not lists:member({Path, Name}, OwnMembers)]),
    Found = maps:from_list([{Path, Module}
                            || Path <- lists:usort([Path || {Path, _} <- References]),
                               {true, Module} <- [module_prefix(Path, IsModule)]]),
    Shared = maps:from_list([{Path, TypeMembers(lists:droplast(Path), lists:last(Path))}
                             || Path := Module <- Found, Module =:= Path, length(Path) >= 2]),
    lists:usort([case lists:member(Name, maps:get(Path, Shared, [])) of
                     true -> lists:droplast(Path);
                     false -> Module
                 end || {Path, Name} <- References, #{Path := Module} <- [Found]]).

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

%% Report §11.1: the longest prefix of a qualified name that is a module,
%% as IsModule answers for the prefix's path, `a/b/c` for A.B.C.
module_prefix([], _IsModule) ->
    false;
module_prefix(Path, IsModule) ->
    case IsModule(ern_namespace:module_path(Path)) of
        true -> {true, Path};
        false -> module_prefix(lists:droplast(Path), IsModule)
    end.

%% Whether a root of Roots holds the compiled module at the path Relative.
is_compiled(Relative, Roots) ->
    lists:any(fun(Dir) -> filelib:is_regular(filename:join(Dir, Relative ++ ".erc")) end, Roots).

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
                true -> ern_tree:build("stdlib");
                false -> SourceRoot
            end;
        Given -> absolute(Given)
    end.

%% Report §11.1: the standard library's own root takes its namespaces from
%% this build's .erc files, so its installed copy, which the checker reads
%% as the library and which a build of ern in another chunk format may have
%% written, is set aside while the library builds, and put back when the
%% build ends (put_back/1); the directory set aside, or kept where another
%% root builds.
set_aside_installed_stdlib(SourceRoot) ->
    case is_stdlib_root(SourceRoot) of
        true -> {set_aside, ern_prelude:set_stdlib_directory(none)};
        false -> kept
    end.

put_back({set_aside, Directory}) -> ern_prelude:set_stdlib_directory(Directory);
put_back(kept) -> kept.

-spec is_stdlib_root(file:filename()) -> boolean().
is_stdlib_root(SourceRoot) ->
    absolute(SourceRoot) =:= stdlib_root().

%% Report §4.2: the standard library's source root, `src/stdlib/` in the
%% toolchain's tree.
stdlib_root() ->
    filename:join([ern_tree:tree(), "src", "stdlib"]).

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
%% module's dependencies, built/4's, and Say says the file written.
%% report §11.4: a module `ern doc` read from its .erc is not compiled
%% again, and its interface is the one its .erc holds
build(#build_module{namespace = Namespace}, Interfaces, _SourceRoot, _DependencyRoots,
      {memory, Given}, _Against, _Namespaces, _Say) when is_map_key(Namespace, Given) ->
    Beam = maps:get(Namespace, Given),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    {Interfaces#{Namespace => Interface}, {Namespace, [], fun(_) -> Beam end}};
build(#build_module{namespace = Namespace, file = File, relative = Relative,
                    declarations = Declarations, dependencies = Dependencies} = Module,
      Interfaces, SourceRoot, [BuildRoot | _] = DependencyRoots, Emit, Against, Namespaces, Say) ->
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
                                   Fresh = [maps:get(Used, Checked) || Used <- Referenced],
                                   Env1 = ern_typecheck:with_interfaces(Fresh, Env),
                                   emitted(Emit, Module, {Typed, Interface, Env1}, Build,
                                           OutputBase, Say)
                               end,
                    Written = ern_interface:written(ern_compile:interface(Namespace, Interface,
                                                                          Canonical, Env, Build)),
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
%% too, which its check gave them (build/8). Report §11.1: Say says each
%% file written, with the module and its source.
emitted(erl, #build_module{namespace = Namespace, file = File} = Module,
        {Typed, _Interface, Env}, Build, OutputBase, Say) ->
    Erl = OutputBase ++ ".erl",
    ok = make_dirs(Erl),
    Source = ern_compile:erl_source(Namespace, Typed, Env, maps:with([standard, canonical], Build)),
    ok = write_output(Erl, unicode:characters_to_binary(["%% Generated by ern build from ",
                                                         shown(File), "\n", Source])),
    Say(compiled_line(Module, Erl)),
    none;
emitted(erc, #build_module{namespace = Namespace} = Module, {Typed, Interface, Env}, Build,
        OutputBase, Say) ->
    Erc = OutputBase ++ ".erc",
    ok = make_dirs(Erc),
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    ok = write_output(Erc, Beam),
    Say(compiled_line(Module, Erc)),
    none;
emitted({memory, _}, #build_module{namespace = Namespace, file = File},
        {Typed, Interface, Env}, Build, _OutputBase, Say) ->
    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
    %% report §11.4: `ern doc` says a module it compiled to read its page
    Say(["compiled ", ern_namespace:text(Namespace), " from ", shown(File)]),
    Beam.

%% Report §11.1: --verbose's line of a module compiled, `compiled Net.Http
%% from src/net/http.ern to build/net/http.erc`.
compiled_line(#build_module{namespace = Namespace, file = File}, Written) ->
    ["compiled ", ern_namespace:text(Namespace), " from ", shown(File), " to ", shown(Written)].

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
            {Dir, Erc} = case compiled_found(Dependency, DependencyRoots) of
                             none ->
                                 Relative = ern_namespace:module_path(Dependency) ++ ".erc",
                                 {BuildRoot, filename:join(BuildRoot, Relative)};
                             Found ->
                                 Found
                         end,
            case read_erc(Erc) of
                %% report §11.1: a .erc of another module is none of this
                %% one's, stale or not
                {ok, #{interface := #interface{namespace = Held}}} when Held =/= Dependency ->
                    fail(held_another(Erc, Held, Dependency));
                {ok, #{interface := Interface} = Chunk} ->
                    case gone(Chunk, Dir, SourceRoot) of
                        false -> {Dependency, Interface};
                        Source ->
                            fail("no module " ++ ern_namespace:text(Dependency) ++ ": "
                                 ++ shown(Erc) ++ " was compiled from " ++ shown(Source)
                                 ++ ", which no longer exists")
                    end;
                %% report §11.5: the path from the working directory, and
                %% the module that needs the one not compiled; report §4.1:
                %% or the cycle compiling it first would meet
                {error, Error} ->
                    case source_cycle(User, Dependency, SourceRoot, DependencyRoots) of
                        none ->
                            fail("compile " ++ ern_namespace:text(Dependency) ++ " first, which "
                                 ++ ern_namespace:text(User) ++ " uses: " ++ shown(Erc) ++ ": "
                                 ++ Error);
                        Cycle ->
                            fail(module_cycle(Cycle))
                    end
            end
    end.

%% Report §11.1, §4.1: a module not compiled that User uses, Dependency,
%% whose source under the source root uses User again, itself or through
%% the sources between, is a cycle, which a build of one file reports as a
%% build of the directory does, and not as a module to compile first: the
%% modules of the cycle, or none. A source that cannot be read or parsed
%% uses nothing here; its build says why.
source_cycle(User, Dependency, SourceRoot, DependencyRoots) ->
    case cycle_through([Dependency], User, [], SourceRoot, DependencyRoots) of
        {cycle, Cycle} -> Cycle;
        {seen, _} -> none
    end.

cycle_through([Namespace | _] = Path, User, Seen, SourceRoot, DependencyRoots) ->
    Uses = source_uses(Namespace, SourceRoot, DependencyRoots),
    case lists:member(User, Uses) of
        true ->
            {cycle, [User | Path]};
        false ->
            lists:foldl(fun(Used, {seen, SeenAcc}) ->
                                case lists:member(Used, SeenAcc) orelse lists:member(Used, Path) of
                                    true -> {seen, SeenAcc};
                                    false -> cycle_through([Used | Path], User, [Used | SeenAcc],
                                                           SourceRoot, DependencyRoots)
                                end;
                           (_, Cycle) ->
                                Cycle
                        end, {seen, Seen}, Uses)
    end.

%% The modules the source of Namespace under the source root uses, none
%% where it has none there or it does not parse.
source_uses(Namespace, SourceRoot, DependencyRoots) ->
    File = filename:join(SourceRoot, ern_namespace:module_path(Namespace) ++ ".ern"),
    case filelib:is_regular(File) of
        false ->
            [];
        true ->
            try parse_module(module_of(absolute(File), SourceRoot), SourceRoot, DependencyRoots) of
                #build_module{dependencies = Dependencies} -> Dependencies
            catch
                throw:_ -> []
            end
    end.

%% Report §11.1: the first root of DependencyRoots that holds a module's
%% compiled form, with the form's path under it, or none.
compiled_found(Namespace, DependencyRoots) ->
    Relative = ern_namespace:module_path(Namespace) ++ ".erc",
    case [{Dir, Candidate} || Dir <- DependencyRoots, Candidate <- [filename:join(Dir, Relative)],
                              filelib:is_regular(Candidate)] of
        [First | _] -> First;
        [] -> none
    end.

%% Report §11.1, §4.1: the modules a module outside the build uses, as its
%% compiled form records them, the form found as dependency_interface/5
%% finds it; none for a module whose form no root holds, does not read or
%% is stale, which is no module, and which the build refuses where a
%% module of its own uses it. A build's order reads each such module here,
%% first and once, so Say says it here (report §11.1, --verbose).
recorded_uses(Namespace, DependencyRoots, SourceRoot, Say) ->
    case compiled_found(Namespace, DependencyRoots) of
        {Dir, Erc} ->
            case read_erc(Erc) of
                {ok, #{deps := DependencyHashes} = Chunk} ->
                    case gone(Chunk, Dir, SourceRoot) of
                        false ->
                            Say(["read ", ern_namespace:text(Namespace), " from ", shown(Erc)]),
                            [Dependency || {Dependency, _} <- DependencyHashes];
                        _ ->
                            []
                    end;
                _ ->
                    []
            end;
        none ->
            []
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

%% Report §11.1, §11.2: the load path past the roots a job puts first: the
%% directories the options add, in the order the options are given, a
%% `--load-path`'s and the `ebin` of each application under a
%% `--libs-dir`, and after them the build of each library of the
%% toolchain's own (Appendix G), so that a program names none of them.
-spec load_path([term()]) -> [file:filename()].
load_path(Options) ->
    lists:append([added(Option) || Option <- Options]) ++ ern_tree:libraries().

added({load_path, Dir}) -> [absolute(Dir)];
added({libs_dir, Dir}) -> application_ebins(Dir);
added(_) -> [].

%% Report §11.2: each directory under Dir that holds `ebin` is an
%% application's, its `ebin` taken in the order of the directories' names;
%% two of one application's name are refused, where the host would take
%% the highest version (code_server's choose/3) and say nothing.
application_ebins(Dir) ->
    Names = case file:list_dir_all(Dir) of
                {ok, Found} -> lists:sort(Found);
                {error, Error} -> refused(Dir, Error)
            end,
    Applications = [Name || Name <- Names, filelib:is_dir(filename:join([Dir, Name, "ebin"]))],
    %% report §11: a name the host could not decode is refused, as a
    %% module's is (files_under/2)
    case [Name || Name <- Applications, is_binary(Name)] of
        [] -> ok;
        [Undecoded | _] ->
            fail("a name that is not UTF-8: " ++ bytes_text(filename:join(Dir, Undecoded)))
    end,
    one_of_each_name(Dir, Applications),
    [absolute(filename:join([Dir, Application, "ebin"])) || Application <- Applications].

%% Report §11.2: two directories of one application's name are refused,
%% naming every directory of that name, in the order of their names.
one_of_each_name(Dir, Applications) ->
    Add = fun(Application, Acc) ->
                  maps:update_with(application_name(Application),
                                   fun(Directories) -> [Application | Directories] end,
                                   [Application], Acc)
          end,
    ByName = lists:foldl(Add, #{}, Applications),
    case lists:sort([{Name, lists:sort(Directories)}
                     || Name := Directories <- ByName, length(Directories) > 1]) of
        [] ->
            ok;
        [{Name, Directories} | _] ->
            fail([Dir, " holds more than one directory of the application ", Name, ", ",
                  lists:join(", ", lists:droplast(Directories)), " and ", lists:last(Directories),
                  ", which --libs-dir names"])
    end.

%% Report §11.2: an application's name, from its directory's, `name` or
%% `name-version`, the version digits separated by dots: its name up to its
%% last `-` where a version so written follows it, and its whole name
%% otherwise.
application_name(Directory) ->
    case string:split(Directory, "-", trailing) of
        [Name, Version] when Name =/= [] ->
            case lists:all(fun is_number_text/1, string:split(Version, ".", all)) of
                true -> Name;
                false -> Directory
            end;
        _ ->
            Directory
    end.

is_number_text(Text) ->
    Text =/= [] andalso lists:all(fun(Char) -> Char >= $0 andalso Char =< $9 end, Text).

%% Report §11.1: whether a .erc is current, and its interface where it is:
%% current when the source and its path from the build root, and the build
%% of the compiler, which Against holds with the standard library's hash,
%% are those the .erc was built from, and it was compiled against the
%% dependencies' interfaces and the standard library as they are.
current(Erc, SourceHash, SourcePath, DependencyHashes,
        #{stdlib := StdlibHash, compiler := CompilerBuild}, DependencyInterfaces) ->
    case read_erc(Erc) of
        {ok, #{interface := Interface, source_hash := SourceHash, source_path := SourcePath,
               compiler := CompilerBuild} = Chunk} ->
            case is_compiled_against(Chunk, DependencyHashes, DependencyInterfaces,
                                     StdlibHash) of
                true -> {true, Interface};
                false -> false
            end;
        _ -> false
    end.

%% Report §11.1, §11.2: whether a compiled module, as its interface chunk
%% records it, was compiled against these interfaces of the modules it
%% uses, whose hashes DependencyHashes holds in order, and against this
%% standard library. Beside the hashes of the interfaces, the hash of each
%% other module's definition its forms reference is compared with the hash
%% that module's interface now holds, so that a change confined to a
%% dependency's bodies counts for a dependent whose forms name what
%% changed, and for no other.
-spec is_compiled_against(ern_interface:chunk(), [{[atom()], binary()}], [#interface{}],
                          binary() | none) -> boolean().
is_compiled_against(#{deps := RecordedHashes, references := References, stdlib := StdlibHash},
                    DependencyHashes, DependencyInterfaces, StdlibHash) ->
    Identities = lists:foldl(fun(#interface{identities = Held}, Acc) -> maps:merge(Acc, Held) end,
                             #{}, DependencyInterfaces),
    lists:sort(RecordedHashes) =:= DependencyHashes
        andalso lists:all(fun({QualifiedName, Hash}) ->
                              maps:get(QualifiedName, Identities, undefined) =:= Hash
                          end, References);
is_compiled_against(_, _, _, _) ->
    false.

%% Report §11.1: the modules whose code shapes a .erc: those that compile,
%% and every module of the toolchain they call, which a test holds them to.
-spec compiler_modules() -> [module()].
compiler_modules() ->
    [ern_ast, ern_bitspec, ern_bound, ern_canonical, ern_chunk, ern_compile, ern_descriptor,
     ern_diagnostic, ern_docs, ern_emitter, ern_exhaust, ern_format, ern_interface, ern_lexer,
     ern_namespace, ern_parser, ern_prelude, ern_pretty, ern_scope, ern_tree, ern_typecheck,
     ern_types, ern_build].

%% Report §11.1, §11.2: the build of ern, its version and a hash of the
%% modules that compile, so that a compiler changed under one version is
%% another; a .erc records the one that wrote it, which the build and the
%% shell's `:load` compare.
-spec compiler_build() -> binary().
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
%% subtree, each said by Say (--verbose), and each directory of the
%% subtree the removals leave empty.
sweep(Dir, SourceRoot, BuildRoot, Say) ->
    Mirror = absolute(filename:join(BuildRoot, relative(Dir, SourceRoot))),
    lists:foreach(fun(Erc) ->
                      ok = delete(Erc),
                      Say(["removed ", shown(Erc)]),
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

%% Report §11.4: remove every document and every manual page `ern doc`
%% wrote under the mirror of the documented subtree whose module is not
%% among Kept, whichever kind the run writes, each said by Say (--verbose),
%% and each directory the removals leave empty. A page names its module in
%% its title and stands at the module's place; a file that does not is no
%% page of `ern doc`'s, and is kept.
-spec sweep_pages(file:filename(), file:filename(), file:filename(), [[atom()]],
                  fun((iodata()) -> ok)) -> ok.
sweep_pages(Dir, SourceRoot, BuildRoot, Kept, Say) ->
    Mirror = absolute(filename:join(BuildRoot, relative(Dir, SourceRoot))),
    Names = [[atom_to_list(Segment) || Segment <- Namespace] || Namespace <- Kept],
    lists:foreach(fun(Page) ->
                      ok = delete(Page),
                      Say(["removed ", shown(Page)]),
                      remove_emptied(filename:dirname(Page), Mirror, BuildRoot)
                  end, [Page || {Kind, Extension} <- [{markdown, ".md"}, {man, ".3ern"}],
                                Page <- outputs(Mirror, Extension),
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
        %% report §11: the file is written whole by a rename in its
        %% directory, so a directory that takes no file is the refusal's
        {error, Error} ->
            fail(shown(filename:dirname(Place)) ++ ": " ++ file:format_error(Error) ++ ", and "
                 ++ filename:basename(File) ++ " is written whole by a rename there")
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

