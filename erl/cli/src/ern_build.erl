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

-export([compile/3, report_errors/4, shown/1, sources/1, bytes_text/1, module_of/2, shape/2,
         segment/1, namespace/1, module_path/1, compile_order/2, compile_order/3, source_root/3,
         build_root/2, is_stdlib_root/1, stdlib_hash/1, dependency_interfaces/5,
         dependency_interface/4, load_path/1, compiler_modules/0, sweep_pages/5,
         compile_source/4, absolute/1, relative/2, write_whole/2,
         write_whole/3, write_output/2, read/1, make_dirs/1, fail/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_build.hrl").

-spec compile([term()], file:filename(), io:device()) -> 0 | 1.
compile(Options, Path, ErrorDevice) ->
    Emit = case lists:member(emit_erl, Options) of
               true -> erl;
               false -> erc
           end,
    filelib:is_file(Path) orelse fail("no such file or directory " ++ Path),
    DirMode = filelib:is_dir(Path),
    SourceRoot = source_root(Options, Path, case DirMode of true -> Path; false -> "." end),
    BuildRoot = build_root(Options, SourceRoot),
    Files = case DirMode of
                true -> sources(Path);
                false -> [Path]
            end,
    Modules = [module_of(absolute(Source), SourceRoot) || Source <- Files],
    SearchPath = [BuildRoot | load_path(Options)],
    SetAside = set_aside_installed_stdlib(SourceRoot, BuildRoot),
    try
        %% report §11.1: a module outside the source root is found under
        %% build-root, then under each --load-path root
        {Parsed, Unparsed} = parse_all(Modules, SourceRoot, SearchPath),
        StdlibHash = stdlib_hash(SourceRoot),
        BuildModule = fun(Module, Interfaces) ->
                          build(Module, Interfaces, SourceRoot, SearchPath, Emit, StdlibHash)
                      end,
        Failed = built(order(Parsed), Unparsed, BuildModule),
        case [{File, Diagnostics} || {_, File, Diagnostics} <- Failed, File =/= none] of
            [] ->
                DirMode andalso Emit =:= erc andalso sweep(absolute(Path), SourceRoot, BuildRoot),
                0;
            Reported ->
                [report_errors(Options, File, Diagnostics, ErrorDevice)
                 || {File, Diagnostics} <- Reported],
                1
        end
    catch
        throw:{errors, File, Diagnostics} -> report_errors(Options, File, Diagnostics, ErrorDevice)
    after
        code:add_pathsa(SetAside)
    end.

%% Report §11.5: every module built, in order, but one that uses a module
%% that failed, whose errors would follow from that one's. The modules that
%% failed, each with its file and its errors, or with none where a module
%% it uses failed; Unparsed begins them.
built(Order, Unparsed, BuildModule) ->
    {_, Failed} = lists:foldl(fun(Module, Acc) -> build_step(Module, Acc, BuildModule) end,
                              {#{}, Unparsed}, Order),
    Failed.

build_step(#build_module{namespace = Namespace, dependencies = Dependencies} = Module,
           {Interfaces, Failed}, BuildModule) ->
    case [Dependency || Dependency <- Dependencies, lists:keymember(Dependency, 1, Failed)] of
        [] ->
            try BuildModule(Module, Interfaces) of
                Interfaces1 -> {Interfaces1, Failed}
            catch
                throw:{errors, File, Diagnostics} ->
                    {Interfaces, Failed ++ [{Namespace, File, Diagnostics}]}
            end;
        _ ->
            {Interfaces, Failed ++ [{Namespace, none, []}]}
    end.

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
    Names = case file:list_dir_all(Dir) of
                {ok, Found} -> Found;
                {error, Error} -> refused(Dir, Error)
            end,
    lists:append([source(Dir, Name) || Name <- lists:sort(Names), not dot_name(Name)]).

source(Dir, Name) when is_binary(Name) ->
    Path = filename:join(Dir, Name),
    IsModule = filename:extension(Name) =:= <<".ern">>
        orelse (filelib:is_dir(Path) andalso not is_link(Path) andalso sources(Path) =/= []),
    IsModule andalso fail("a name that is not UTF-8: " ++ bytes_text(Path)),
    [];
source(Dir, Name) ->
    Path = filename:join(Dir, Name),
    case {filelib:is_dir(Path), is_link(Path)} of
        {true, false} -> sources(Path);
        {true, true} -> [];
        {false, _} -> [Path || filename:extension(Name) =:= ".ern"]
    end.

dot_name(<<$., _/binary>>) -> true;
dot_name([$. | _]) -> true;
dot_name(_) -> false.

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
%% with the path shape rule of §11.1.
-spec module_of(file:filename(), file:filename()) -> #build_module{}.
module_of(File, SourceRoot) ->
    Relative = relative(File, SourceRoot),
    Relative =/= outside orelse fail(File ++ " is not under the source root " ++ SourceRoot
                                     ++ "; --source-root names another"),
    %% report §4.2: a file of the standard library's own source root is
    %% compiled with that root only
    case is_stdlib_root(SourceRoot) orelse relative(File, stdlib_root()) =:= outside of
        true -> ok;
        false -> fail(Relative ++ " is in the standard library's source root; omit --source-root")
    end,
    filename:extension(Relative) =:= ".ern" orelse fail(Relative ++ " does not end in .ern"),
    Components = filename:split(filename:rootname(Relative)),
    lists:foreach(fun(Component) -> shape(Relative, Component) end, Components),
    Namespace = namespace(Components),
    %% report §4.2: a module namespace is never a namespace of the prelude
    %% or the standard library, except in the standard library's own source
    %% root; the message names which of the two takes it, the prelude where
    %% both do
    case Namespace of
        [Single] ->
            not is_stdlib_root(SourceRoot) andalso
                case {lists:member(Single, prelude_only_namespaces()),
                      lists:member(Single, stdlib_namespaces())} of
                    {true, _} ->
                        fail(Relative ++ " takes the prelude namespace " ++ atom_to_list(Single));
                    {false, true} ->
                        fail(Relative ++ " takes the standard library namespace "
                             ++ atom_to_list(Single));
                    {false, false} ->
                        ok
                end;
        _ -> ok
    end,
    #build_module{namespace = Namespace, file = File, relative = Relative}.

%% Report §11.1: each component of a file's path is words joined by single
%% `_`, a word a lowercase letter, then lowercase letters and digits
%% (ern_namespace). The refusal names the file.
-spec shape(file:filename(), string()) -> ok.
shape(File, Component) ->
    case ern_namespace:is_component(Component) of
        true -> ok;
        false ->
            Named = File ++ ": path component `" ++ Component ++ "`",
            case lists:any(fun(Char) -> Char >= $A andalso Char =< $Z end, Component) of
                true -> fail(Named ++ " must be lowercase");
                false -> fail(Named ++ " must be words joined by `_`, each a lowercase letter,"
                              " then lowercase letters and digits; a module of several words"
                              " is `ordered_set.ern` or a directory")
            end
    end.

%% Report §11.1, §4.2: the namespace segment a path component names, where
%% it is one; the shell's `:load` completion asks here.
-spec segment(string()) -> {ok, string()} | error.
segment(Component) ->
    ern_namespace:segment(Component).

%% Report §4.2: the namespace the components of a path name.
-spec namespace([string()]) -> [atom()].
namespace(Components) ->
    ern_namespace:namespace(Components).

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
compile_order(Modules, SourceRoot, SearchPath) ->
    order([parse_module(Module, SourceRoot, SearchPath) || Module <- Modules]).

%% Every module parsed, and each that does not parse with its errors, as a
%% build reports them (report §11.5).
parse_all(Modules, SourceRoot, SearchPath) ->
    lists:foldl(fun(Module, {Parsed, Failed}) ->
                    try parse_module(Module, SourceRoot, SearchPath) of
                        ParsedModule -> {Parsed ++ [ParsedModule], Failed}
                    catch
                        throw:{errors, File, Diagnostics} ->
                            {Parsed, Failed ++ [{Module#build_module.namespace, File, Diagnostics}]}
                    end
                end, {[], []}, Modules).

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

parse_module(#build_module{file = File} = Module, SourceRoot, SearchPath) ->
    case ern_parser:parse_string(read(File)) of
        {ok, Declarations} ->
            namespace_clash(Module#build_module{declarations = Declarations}, SourceRoot),
            %% a module naming itself qualified (report §4.2) depends on nothing by it
            Dependencies = dependencies(Declarations, SourceRoot, SearchPath)
                -- [Module#build_module.namespace],
            Module#build_module{declarations = Declarations, dependencies = Dependencies};
        {error, Diagnostic} -> throw({errors, File, [Diagnostic]})
    end.

%% Report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module. Checked from both files, so either finds it.
namespace_clash(#build_module{namespace = Namespace, relative = Relative,
                              declarations = Declarations}, SourceRoot) ->
    case Namespace of
        [_, _ | _] ->
            Parent = lists:droplast(Namespace),
            ParentRelative = module_path(Parent) ++ ".ern",
            lists:member(lists:last(Namespace),
                         source_types(filename:join(SourceRoot, ParentRelative)))
                andalso clash(Relative, lists:last(Namespace), ParentRelative, Namespace);
        _ ->
            ok
    end,
    lists:foreach(fun(Type) ->
                      ChildRelative = module_path(Namespace ++ [Type]) ++ ".ern",
                      filelib:is_regular(filename:join(SourceRoot, ChildRelative))
                          andalso clash(ChildRelative, Type, Relative, Namespace ++ [Type])
                  end, local_types(Declarations)).

-spec clash(string(), atom(), string(), [atom()]) -> no_return().
clash(ChildRelative, Type, ParentRelative, Namespace) ->
    fail(ChildRelative ++ " and type " ++ atom_to_list(Type) ++ " in " ++ ParentRelative
         ++ " share the namespace " ++ ern_namespace:text(Namespace) ++ " (report §4.2)").

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
%% prelude namespace, and whose longest prefix names an existing .ern under
%% the root. Report §4.2: `T.name` is the module's own member where its type
%% `T` declares one of that name, and the namespace T's `name` otherwise.
dependencies(Declarations, SourceRoot, SearchPath) ->
    %% in the standard library's root its own namespaces are dependencies
    Skip = case is_stdlib_root(SourceRoot) of
               true -> [];
               false -> prelude_namespaces()
           end,
    Members = local_members(Declarations),
    Paths = lists:usort([Path || {Path, Name} <- references(Declarations), Path =/= [],
                                 not lists:member(hd(Path), Skip),
                                 not lists:member({Path, Name}, Members)]),
    lists:usort(lists:filtermap(fun(Path) -> module_prefix(Path, SourceRoot, SearchPath) end,
                                Paths)).

%% Each qualified reference of a source, its path and its last name; only a
%% value's lowercase name or operator can be a type's member.
references(#e_var{path = Path, name = Name}) -> [{Path, Name}];
references(#e_constructor{path = Path, name = Name, base = Base, args = Args}) ->
    [{Path, Name} | references(Base) ++ references(Args)];
references(#p_constructor{path = Path, name = Name, args = Args}) ->
    [{Path, Name} | references(Args)];
references(#t_named{path = Path, name = Name, args = Args}) -> [{Path, Name} | references(Args)];
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
%% SearchPath, its compiled module.
module_prefix([], _SourceRoot, _SearchPath) ->
    false;
module_prefix(Path, SourceRoot, SearchPath) ->
    Relative = module_path(Path),
    HoldsCompiled = fun(Dir) -> filelib:is_regular(filename:join(Dir, Relative ++ ".erc")) end,
    case filelib:is_regular(filename:join(SourceRoot, Relative ++ ".ern"))
        orelse lists:any(HoldsCompiled, SearchPath) of
        true -> {true, Path};
        false -> module_prefix(lists:droplast(Path), SourceRoot, SearchPath)
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
                true -> absolute(filename:join([filename:dirname(stdlib_root()), "build",
                                                "stdlib"]));
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

%% Report §4.2: the standard library's source root, `stdlib/` beside the
%% toolchain's `erl/`, found from where this module was loaded.
stdlib_root() ->
    Here = absolute(code:which(?MODULE)),
    Repo = filename:dirname(filename:dirname(filename:dirname(filename:dirname(Here)))),
    absolute(filename:join(Repo, "stdlib")).

%% Report §4.2: the namespaces a module may not take, the prelude's and the
%% standard library's.
prelude_namespaces() ->
    lists:usort(prelude_only_namespaces() ++ stdlib_namespaces()).

%% The prelude's own: `Prelude`, the name of the prelude itself, and each
%% of its types that has members; a prelude type without members takes no
%% namespace (report §4.2).
prelude_only_namespaces() ->
    lists:usort(['Prelude' | ern_prelude:member_types()]).

%% The standard library's modules at the top of the hierarchy.
stdlib_namespaces() ->
    lists:usort([hd(Interface#interface.namespace)
                 || Interface <- ern_prelude:stdlib_interfaces()]).

%% Type-check and compile one module against its dependencies'
%% interfaces, unless its .erc is current (§11.1). Returns the interfaces
%% with this module's added.
build(#build_module{namespace = Namespace, file = File, relative = Relative,
                    declarations = Declarations, dependencies = Dependencies},
      Interfaces, SourceRoot, [BuildRoot | _] = SearchPath, Emit, StdlibHash) ->
    DependencyInterfaces = dependency_interfaces(Namespace, Dependencies, Interfaces, SearchPath,
                                                 SourceRoot),
    DependencyHashes = lists:sort([{Dependency, ern_interface:hash(DependencyInterface)}
                                   || {Dependency, DependencyInterface} <- DependencyInterfaces]),
    SourceHash = crypto:hash(sha256, read(File)),
    SourcePath = path_from(BuildRoot, File),
    OutputBase = filename:join(BuildRoot, filename:rootname(Relative)),
    Erc = OutputBase ++ ".erc",
    case Emit =:= erc andalso current(Erc, SourceHash, SourcePath, DependencyHashes, StdlibHash) of
        {true, Interface} ->
            Interfaces#{Namespace => Interface};
        false ->
            Given = [DependencyInterface || {_, DependencyInterface} <- DependencyInterfaces],
            case ern_typecheck:check(Namespace, Declarations, Given) of
                {ok, Typed, Interface, Env} ->
                    ok = make_dirs(Erc),
                    case Emit of
                        erl ->
                            Build = #{standard => is_stdlib_root(SourceRoot)},
                            Source = ern_emitter:erl_source(Namespace, Typed, Env, Build),
                            ErlangSource = ["%% Generated by ern build from ", Relative, "\n",
                                            Source],
                            ok = write_output(OutputBase ++ ".erl",
                                              unicode:characters_to_binary(ErlangSource));
                        erc ->
                            held_by_another(Erc, Namespace),
                            Build = #{source_hash => SourceHash, source_path => SourcePath,
                                      deps => DependencyHashes, compiler => compiler_build(),
                                      stdlib => StdlibHash, standard => is_stdlib_root(SourceRoot),
                                      source => list_to_binary(filename:basename(Relative))},
                            {ok, _, Beam} =
                                ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
                            ok = write_output(Erc, Beam)
                    end,
                    Interfaces#{Namespace => Interface};
                {error, Diagnostics} ->
                    throw({errors, File, Diagnostics})
            end
    end.

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
%% set is hashed. The standard library's own modules depend on each other
%% as ordinary modules do, and record none.
-spec stdlib_hash(file:filename()) -> binary() | none.
stdlib_hash(SourceRoot) ->
    case is_stdlib_root(SourceRoot) of
        true -> none;
        false ->
            Hashes = lists:sort([{Interface#interface.namespace, ern_interface:hash(Interface)}
                                 || Interface <- ern_prelude:stdlib_interfaces()]),
            crypto:hash(sha256, term_to_binary(Hashes))
    end.

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
dependency_interfaces(Namespace, Dependencies, Interfaces, SearchPath, SourceRoot) ->
    Skip = case is_stdlib_root(SourceRoot) of
               true -> [Namespace];
               false -> [Namespace | [[Name] || Name <- stdlib_namespaces()]]
           end,
    reached([dependency_interface(Dependency, Interfaces, SearchPath, SourceRoot)
             || Dependency <- lists:usort(Dependencies)], Skip, Interfaces, SearchPath,
            SourceRoot).

reached(Found, Skip, Interfaces, SearchPath, SourceRoot) ->
    Have = [Dependency || {Dependency, _} <- Found],
    Named = lists:usort([Namespace || {_, Interface} <- Found, Namespace <- type_modules(Interface),
                                      not lists:member(Namespace, Skip),
                                      not lists:member(Namespace, Have)]),
    case Named of
        [] -> Found;
        _ ->
            reached(Found
                    ++ [dependency_interface(Namespace, Interfaces, SearchPath, SourceRoot)
                        || Namespace <- Named],
                    Skip, Interfaces, SearchPath, SourceRoot)
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
%% stale .erc is no module.
-spec dependency_interface([atom()], #{[atom()] => #interface{}}, [file:filename(), ...],
                           file:filename()) ->
          {[atom()], #interface{}}.
dependency_interface(Dependency, Interfaces, [BuildRoot | _] = SearchPath, SourceRoot) ->
    case Interfaces of
        #{Dependency := Interface} -> {Dependency, Interface};
        _ ->
            Relative = module_path(Dependency) ++ ".erc",
            Found = [{Dir, Candidate} || Dir <- SearchPath,
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
                {error, Error} ->
                    fail("compile " ++ ern_namespace:text(Dependency) ++ " first: " ++ Erc ++ ": "
                         ++ Error)
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

%% Report §11.1: current when the source and its path from the build root,
%% every dependency's interface, the standard library's interfaces, and the
%% build of the compiler are those the .erc was built from.
current(Erc, SourceHash, SourcePath, DependencyHashes, StdlibHash) ->
    CompilerBuild = compiler_build(),
    case read_erc(Erc) of
        {ok, #{interface := Interface, source_hash := SourceHash, source_path := SourcePath,
               deps := RecordedHashes, compiler := CompilerBuild, stdlib := StdlibHash}} ->
            case lists:sort(RecordedHashes) =:= DependencyHashes of
                true -> {true, Interface};
                false -> false
            end;
        _ -> false
    end.

%% Report §11.1: the modules whose code shapes a .erc: those that compile,
%% and every module of the toolchain they call, which a test holds them to.
-spec compiler_modules() -> [module()].
compiler_modules() ->
    [ern_ast, ern_bitspec, ern_descriptor, ern_diagnostic, ern_docs, ern_emitter, ern_exhaust,
     ern_interface, ern_lexer, ern_namespace, ern_parser, ern_prelude, ern_reply, ern_scope,
     ern_typecheck, ern_types, ern_build].

%% Report §11.1: the build of ern, its version and a hash of the modules
%% that compile, so that a compiler changed under one version is another.
compiler_build() ->
    Hash = erlang:md5(term_to_binary([ErlangModule:module_info(md5)
                                      || ErlangModule <- compiler_modules()])),
    <<(list_to_binary(?VERSION))/binary, $+, (binary:encode_hex(Hash, lowercase))/binary>>.

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
                  end, [Erc || Erc <- outputs(Mirror, ".erc"), stale(Erc, BuildRoot, SourceRoot)]).

%% A .erc that does not read as this compiler's records nothing, and is kept.
stale(Erc, BuildRoot, SourceRoot) ->
    case read_erc(Erc) of
        {ok, Chunk} -> gone(Chunk, BuildRoot, SourceRoot) =/= false;
        {error, _} -> false
    end.

%% Report §11.1: every file of an extension under a directory, passing over
%% each name that begins with a dot, as sources/1 does, and each symbolic
%% link.
outputs(Dir, Extension) ->
    case file:list_dir(Dir) of
        {ok, Names} ->
            lists:append([case file:read_link_info(Path) of
                              {ok, #file_info{type = directory}} -> outputs(Path, Extension);
                              {ok, #file_info{type = regular}} ->
                                  [Path || filename:extension(Name) =:= Extension];
                              _ -> []
                          end || Name <- lists:sort(Names), hd(Name) =/= $.,
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
            Place = case Kind of
                        markdown -> Path ++ ".md";
                        man -> filename:join(filename:dirname(Path), "Ernest." ++ Title ++ ".3ern")
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
%% write nothing. SourceRoot is the source root and SearchPath the load
%% path, the roots a dependency outside the source root is found under by
%% its namespace, in order (§11.1). A dependency the session has loaded is
%% compiled against as Interfaces holds it, since it has no `.erc` or one
%% older than it. A refusal is a sentence, and diagnostics come with the
%% file they are in.
-spec compile_source(file:filename(), file:filename(), [file:filename(), ...],
                     #{[atom()] => #interface{}}) ->
          {ok, [atom()], binary(), binary()} | {refused, string()}
          | {error, file:filename(), [ern_diagnostic:diagnostic()]}.
compile_source(File, SourceRoot, SearchPath, Interfaces) ->
    try
        [#build_module{namespace = Namespace, relative = Relative, declarations = Declarations,
                       dependencies = Dependencies}] =
            compile_order([module_of(absolute(File), SourceRoot)], SourceRoot, SearchPath),
        DependencyInterfaces = dependency_interfaces(Namespace, Dependencies, Interfaces,
                                                     SearchPath, SourceRoot),
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
                          source => list_to_binary(filename:basename(Relative))},
                {ok, _, Beam} = ern_emitter:compile(Namespace, Typed, Interface, Env, Build),
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
    write_whole(File, Data, undefined).

-spec write_whole(file:filename(), iodata(), non_neg_integer() | undefined) -> ok.
write_whole(File, Data, Mode) ->
    write_at(File, followed(File, 0), Data, Mode).

%% Report §11: what a build or `ern doc` writes, whole, as write_whole/2
%% writes it, but in its place: a link there is replaced, not followed, so
%% that a link planted in a build tree names nothing the build writes.
-spec write_output(file:filename(), iodata()) -> ok.
write_output(File, Data) ->
    write_at(File, File, Data, undefined).

%% File's data written at Place, the file itself or where its links lead.
write_at(File, Place, Data, Mode) ->
    %% report §11: a file its owner may not write is refused, not replaced
    case file:read_link_info(Place) of
        {ok, #file_info{access = Access}} when Access =:= read; Access =:= none ->
            fail(File ++ ": " ++ file:format_error(eacces));
        _ ->
            ok
    end,
    %% a name of this writer's own, so that two jobs writing one file at
    %% once each write theirs whole and the last rename wins (report §11)
    Own = os:getpid() ++ "." ++ integer_to_list(erlang:unique_integer([positive])),
    New = filename:join(filename:dirname(Place),
                        "." ++ filename:basename(Place) ++ "." ++ Own ++ ".new"),
    Kept = case {Mode, file:read_link_info(Place)} of
               {undefined, {ok, #file_info{type = regular, mode = Existing}}} ->
                   Existing band 8#7777;
               {undefined, _} -> undefined;
               {Given, _} -> Given
           end,
    Steps = [fun() -> file:write_file(New, <<>>) end]
        ++ [fun() -> file:change_mode(New, Kept) end || Kept =/= undefined]
        ++ [fun() -> file:write_file(New, Data) end, fun() -> file:rename(New, Place) end],
    case lists:foldl(fun(Step, ok) -> Step(); (_, Failed) -> Failed end, ok, Steps) of
        ok ->
            ok;
        {error, Error} ->
            _ = file:delete(New),
            fail(File ++ ": " ++ file:format_error(Error))
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

-spec refused(file:filename_all(), term()) -> no_return().
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

