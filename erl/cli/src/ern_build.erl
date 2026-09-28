%% The build of report §11.1, which `ern build` runs and every other job
%% reaches for a module's source, its interface, or a file written whole:
%% finding the modules under a source root and giving each its namespace
%% by the path shape, ordering them by their dependencies, compiling each
%% to its `.erc` when it has changed, and removing what an earlier build
%% wrote that no source now makes. Apart from ern_cli, whose other jobs do
%% not shape a `.erc`, so that the compiler's hash (compiler_modules/0)
%% leaves them out and a change to them recompiles nothing.
-module(ern_build).

-export([compile/3, report_errors/4, shown/1, sources/1, bytes_text/1, module_of/2, shape/1,
         segment/1, namespace/1, module_path/1, compile_order/2, compile_order/3,
         source_root/3, out_dir/2, is_stdlib_root/1, dep_iface/4, load_path/1,
         compiler_modules/0, compile_source/3, absolute/1, relative/2, qname/1,
         write_whole/2, write_whole/3, fail/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_build.hrl").

-spec compile([term()], file:filename(), io:device()) -> 0 | 1.
compile(Opts, Path, Err) ->
    Emit = case lists:member(emit_erl, Opts) of
               true -> erl;
               false -> erc
           end,
    filelib:is_file(Path) orelse fail("no such file or directory " ++ Path),
    DirMode = filelib:is_dir(Path),
    Root = source_root(Opts, Path, case DirMode of true -> Path; false -> "." end),
    OutDir = out_dir(Opts, Root),
    Files = case DirMode of
                true -> sources(Path);
                false -> [Path]
            end,
    Modules = [module_of(absolute(F), Root) || F <- Files],
    Dirs = [OutDir | load_path(Opts)],
    try
        Order = compile_order(Modules, Root, load_path(Opts)),
        Std = stdlib_hash(Root),
        lists:foldl(fun(M, Ifaces) -> build(M, Ifaces, Root, Dirs, Emit, Std) end, #{}, Order),
        case DirMode andalso Emit =:= erc of
            true -> sweep(absolute(Path), Root, OutDir);
            false -> ok
        end,
        0
    catch
        throw:{errors, File, Errors} -> report_errors(Opts, File, Errors, Err)
    end.

%% Report §11.5: each error as ern_diag renders it, the first line alone
%% under --short-errors; status 1. The file is named from the working
%% directory when it lies under it.
-spec report_errors([term()], file:filename(), [ern_diag:diag()], io:device()) -> 1.
report_errors(Opts, File, Errors, Err) ->
    Short = lists:member(short_errors, Opts),
    Source = case file:read_file(File) of
                 {ok, Bin} -> Bin;
                 _ -> <<>>
             end,
    Shown = shown(File),
    lists:foreach(fun(D) ->
                      Text = case Short of
                                 true -> ern_diag:short(Shown, D);
                                 false -> ern_diag:format(Shown, Source, D)
                             end,
                      io:format(Err, "~ts~n", [Text])
                  end, Errors),
    1.

%% A file named from the working directory where it lies under it.
-spec shown(file:filename()) -> file:filename().
shown(File) ->
    {ok, Cwd} = file:get_cwd(),
    case relative(File, Cwd) of
        outside -> absolute(File);
        Rel -> Rel
    end.

%% Report §11.1: every `.ern` under a directory, passing over each file and
%% directory whose name begins with a dot, which is no module, and each
%% symbolic link to a directory. The host gives a name that is not UTF-8 as
%% its bytes, and one of a `.ern` or of a directory that holds one is an
%% error.
-spec sources(file:filename()) -> [file:filename()].
sources(Dir) ->
    {ok, Names} = file:list_dir_all(Dir),
    lists:append([source(Dir, Name) || Name <- lists:sort(Names), not dot_name(Name)]).

source(Dir, Name) when is_binary(Name) ->
    Path = filename:join(Dir, Name),
    Module = filename:extension(Name) =:= <<".ern">>
        orelse (filelib:is_dir(Path) andalso not is_link(Path) andalso sources(Path) =/= []),
    Module andalso fail("a name that is not UTF-8: "
                        ++ filename:join(unicode:characters_to_list(Dir), bytes_text(Name))),
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

%% A name the host could not decode, each byte past ASCII as `\xHH`.
-spec bytes_text(binary()) -> string().
bytes_text(Name) ->
    lists:append([case B < 16#80 of
                      true -> [B];
                      false -> lists:flatten(io_lib:format("\\x~2.16.0B", [B]))
                  end || <<B>> <= Name]).

is_link(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = symlink}} -> true;
        _ -> false
    end.

%% A source file as a module: its namespace from its path under the root,
%% with the path shape rule of §11.1.
-spec module_of(file:filename(), file:filename()) -> #mod{}.
module_of(File, Root) ->
    Rel = relative(File, Root),
    Rel =/= outside orelse fail(File ++ " is not under the source root " ++ Root),
    %% report §4.2: a file of the standard library's own source root is
    %% compiled with that root only
    case is_stdlib_root(Root) orelse relative(File, stdlib_root()) =:= outside of
        true -> ok;
        false -> fail(Rel ++ " is in the standard library's source root; omit --source-root")
    end,
    filename:extension(Rel) =:= ".ern" orelse fail(Rel ++ " does not end in .ern"),
    Components = filename:split(filename:rootname(Rel)),
    lists:foreach(fun shape/1, Components),
    Ns = namespace(Components),
    %% report §4.2: a module namespace is never a namespace of the prelude
    %% or the standard library, except in the standard library's own source
    %% root; the message names which of the two takes it, the prelude where
    %% both do
    case Ns of
        [Single] ->
            not is_stdlib_root(Root) andalso
                case {lists:member(Single, prelude_only_namespaces()),
                      lists:member(Single, stdlib_namespaces())} of
                    {true, _} ->
                        fail(Rel ++ " takes the prelude namespace " ++ atom_to_list(Single));
                    {false, true} ->
                        fail(Rel ++ " takes the standard library namespace "
                             ++ atom_to_list(Single));
                    {false, false} ->
                        ok
                end;
        _ -> ok
    end,
    #mod{ns = Ns, file = File, rel = Rel}.

%% Report §11.1: each component is one word, a lowercase letter, then
%% lowercase letters and digits.
-spec shape(string()) -> ok.
shape(Component) ->
    case word(Component) of
        true -> ok;
        false ->
            case re:run(Component, "[A-Z]") of
                {match, _} -> fail("path component `" ++ Component ++ "` must be lowercase");
                nomatch -> fail("path component `" ++ Component ++ "` must be one word: a"
                                " lowercase letter, then lowercase letters and digits;"
                                " a multi-word module is a directory")
            end
    end.

word(Component) ->
    re:run(Component, "^[a-z][a-z0-9]*$") =/= nomatch.

%% Report §11.1, §4.2: the namespace segment a path component names, where
%% it is one word; the shell's `:load` completion asks here, so that the
%% rule has one owner.
-spec segment(string()) -> {ok, string()} | error.
segment(Component) ->
    case word(Component) of
        true -> {ok, string:titlecase(Component)};
        false -> error
    end.

%% Report §4.2: the canonical typename form of each path segment.
-spec namespace([string()]) -> [atom()].
namespace(Components) ->
    [list_to_atom(string:titlecase(C)) || C <- Components].

%% The inverse: a namespace as a relative path without extension.
-spec module_path([atom()]) -> string().
module_path(Ns) ->
    filename:join([string:lowercase(string:slice(atom_to_list(S), 0, 1))
                   ++ string:slice(atom_to_list(S), 1) || S <- Ns]).

%% Parse every module, find its dependencies, and order them; a cycle is
%% an error naming the modules in it (§11.1).
-spec compile_order([#mod{}], file:filename()) -> [#mod{}].
compile_order(Modules, Root) ->
    compile_order(Modules, Root, []).

-spec compile_order([#mod{}], file:filename(), [file:filename()]) -> [#mod{}].
compile_order(Modules, Root, LoadPath) ->
    Parsed = [parse_module(M, Root, LoadPath) || M <- Modules],
    %% the graph is tables of this process's, deleted whether or not the
    %% order is found
    G = digraph:new(),
    Order = try
                lists:foreach(fun(#mod{ns = Ns}) -> digraph:add_vertex(G, Ns) end, Parsed),
                lists:foreach(fun(#mod{ns = Ns, deps = Deps}) ->
                                  lists:foreach(fun(D) ->
                                                    digraph:add_vertex(G, D),
                                                    digraph:add_edge(G, D, Ns)
                                                end, Deps)
                              end, Parsed),
                topsort(G)
            after
                digraph:delete(G)
            end,
    ByNs = maps:from_list([{Ns, M} || #mod{ns = Ns} = M <- Parsed]),
    [maps:get(Ns, ByNs) || Ns <- Order, is_map_key(Ns, ByNs)].

topsort(G) ->
    case digraph_utils:topsort(G) of
        false ->
            [Cycle | _] = digraph_utils:cyclic_strong_components(G),
            fail("module cycle: " ++ lists:join(", ", [qname(N) || N <- lists:sort(Cycle)]));
        Sorted ->
            Sorted
    end.

parse_module(#mod{file = File} = M, Root, LoadPath) ->
    {ok, Bin} = file:read_file(File),
    case ern_parser:parse_string(Bin) of
        {ok, Decls} ->
            namespace_clash(M#mod{decls = Decls}, Root),
            %% a module naming itself qualified (report §4.2) depends on nothing by it
            M#mod{decls = Decls, deps = deps(Decls, Root, LoadPath) -- [M#mod.ns]};
        {error, E} -> throw({errors, File, [E]})
    end.

%% Report §4.2: a module namespace may not coincide with a type namespace
%% of its parent module. Checked from both files, so either finds it.
namespace_clash(#mod{ns = Ns, rel = Rel, decls = Decls}, Root) ->
    case Ns of
        [_, _ | _] ->
            Parent = lists:droplast(Ns),
            ParentRel = module_path(Parent) ++ ".ern",
            lists:member(lists:last(Ns), source_types(filename:join(Root, ParentRel)))
                andalso clash(Rel, lists:last(Ns), ParentRel, Ns);
        _ ->
            ok
    end,
    lists:foreach(fun(T) ->
                      ChildRel = module_path(Ns ++ [T]) ++ ".ern",
                      filelib:is_regular(filename:join(Root, ChildRel))
                          andalso clash(ChildRel, T, Rel, Ns ++ [T])
                  end, local_types(Decls)).

-spec clash(string(), atom(), string(), [atom()]) -> no_return().
clash(ChildRel, T, ParentRel, Q) ->
    fail(ChildRel ++ " and type " ++ atom_to_list(T) ++ " in " ++ ParentRel
         ++ " share the namespace " ++ qname(Q) ++ " (report §4.2)").

%% The types a parsed source declares; none when it is absent or does not parse.
source_types(File) ->
    case file:read_file(File) of
        {ok, Bin} ->
            case ern_parser:parse_string(Bin) of
                {ok, Decls} -> local_types(Decls);
                {error, _} -> []
            end;
        {error, _} ->
            []
    end.

local_types(Decls) ->
    [N || #type_decl{name = N} <- Decls]
        ++ [N || #abstract_decl{type = #type_decl{name = N}} <- Decls]
        ++ [N || #foreign_type_decl{name = N} <- Decls].

%% The modules a source refers to: every qualified name whose first
%% segment is neither a type of this module nor a prelude namespace, and
%% whose longest prefix names an existing .ern under the root.
deps(Decls, Root, LoadPath) ->
    %% in the standard library's root its own namespaces are dependencies
    Skip = case is_stdlib_root(Root) of
               true -> local_types(Decls);
               false -> local_types(Decls) ++ prelude_namespaces()
           end,
    Paths = lists:usort([P || P <- paths(Decls), P =/= [], not lists:member(hd(P), Skip)]),
    lists:usort(lists:filtermap(fun(P) -> module_prefix(P, Root, LoadPath) end, Paths)).

paths(#e_var{path = P}) -> [P];
paths(#e_con{path = P, args = A}) -> [P | paths(A)];
paths(#p_con{path = P, args = A}) -> [P | paths(A)];
paths(#t_con{path = P, args = A}) -> [P | paths(A)];
paths(T) when is_tuple(T) -> lists:append([paths(X) || X <- tuple_to_list(T)]);
paths(L) when is_list(L) -> lists:append([paths(X) || X <- L]);
paths(_) -> [].

%% Report §11.1: a prefix of a qualified name is a module when the source
%% root holds its source or a --load-path root its compiled module.
module_prefix([], _Root, _LoadPath) ->
    false;
module_prefix(Path, Root, LoadPath) ->
    Rel = module_path(Path),
    case filelib:is_regular(filename:join(Root, Rel ++ ".ern"))
        orelse lists:any(fun(D) -> filelib:is_regular(filename:join(D, Rel ++ ".erc")) end,
                         LoadPath) of
        true -> {true, Path};
        false -> module_prefix(lists:droplast(Path), Root, LoadPath)
    end.

%% Report §11.1: the source root is --source-root; without it, the standard
%% library's root for a path under it, else Default.
-spec source_root([term()], file:filename(), file:filename()) -> file:filename().
source_root(Opts, Path, Default) ->
    case proplists:get_value(source_root, Opts) of
        undefined ->
            case relative(Path, stdlib_root()) of
                outside -> absolute(Default);
                _ -> stdlib_root()
            end;
        Root -> absolute(Root)
    end.

%% Report §11.1: the build directory is --build-root; without it, the source
%% root, and `build/stdlib` for the standard library's own root, where the
%% Makefile builds it.
-spec out_dir([term()], file:filename()) -> file:filename().
out_dir(Opts, Root) ->
    case proplists:get_value(build_root, Opts) of
        undefined ->
            case is_stdlib_root(Root) of
                true -> absolute(filename:join([filename:dirname(stdlib_root()), "build",
                                                "stdlib"]));
                false -> Root
            end;
        Dir -> absolute(Dir)
    end.

-spec is_stdlib_root(file:filename()) -> boolean().
is_stdlib_root(Root) ->
    absolute(Root) =:= stdlib_root().

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

%% The prelude's own: its types, the first segment of its qualified values,
%% and `Prelude`, the name of the prelude itself.
prelude_only_namespaces() ->
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    lists:usort(['Prelude']
                ++ [N || {N, _, _} <- ern_prelude:builtin_types()]
                ++ [N || #type_decl{name = N} <- Decls]
                ++ [hd(Q) || {Q, _, _} <- ern_prelude:values(), length(Q) > 1]).

%% The standard library's modules at the top of the hierarchy.
stdlib_namespaces() ->
    lists:usort([hd(I#iface.namespace) || I <- ern_prelude:stdlib_ifaces()]).

%% Type-check and compile one module against its dependencies'
%% interfaces, unless its .erc is current (§11.1). Returns the interfaces
%% with this module's added.
build(#mod{ns = Ns, file = File, rel = Rel, decls = Decls, deps = Deps}, Ifaces, Root,
      [OutDir | _] = Dirs, Emit, Std) ->
    DepIfaces = [dep_iface(D, Ifaces, Dirs, Root) || D <- Deps],
    DepHashes = lists:sort([{D, ern_iface:hash(I)} || {D, I} <- DepIfaces]),
    {ok, Source} = file:read_file(File),
    SourceHash = crypto:hash(sha256, Source),
    SourcePath = path_from(OutDir, File),
    Out = filename:join(OutDir, filename:rootname(Rel)),
    Erc = Out ++ ".erc",
    case Emit =:= erc andalso current(Erc, SourceHash, SourcePath, DepHashes, Std) of
        {true, Iface} ->
            Ifaces#{Ns => Iface};
        false ->
            case ern_typecheck:check(Ns, Decls, [I || {_, I} <- DepIfaces]) of
                {ok, Typed, Iface, Env} ->
                    ok = filelib:ensure_dir(Erc),
                    case Emit of
                        erl ->
                            Src = ["%% Generated by ern build from ", Rel, "\n",
                                   ern_emitter:erl_source(Ns, Typed, Env)],
                            ok = write_whole(Out ++ ".erl", unicode:characters_to_binary(Src));
                        erc ->
                            Build = #{source_hash => SourceHash, source_path => SourcePath,
                                      deps => DepHashes, compiler => compiler_build(),
                                      stdlib => Std,
                                      source => list_to_binary(filename:basename(Rel))},
                            {ok, _, Beam} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
                            ok = write_whole(Erc, Beam)
                    end,
                    Ifaces#{Ns => Iface};
                {error, Errors} ->
                    throw({errors, File, Errors})
            end
    end.

%% Report §11.1: one hash over every installed standard library interface,
%% so that any change to one recompiles the modules built against it; an
%% operator can reach a standard library module no path names, so the whole
%% set is hashed. The standard library's own modules depend on each other
%% as ordinary modules do, and record none.
stdlib_hash(Root) ->
    case is_stdlib_root(Root) of
        true -> none;
        false ->
            Hashes = lists:sort([{I#iface.namespace, ern_iface:hash(I)}
                                 || I <- ern_prelude:stdlib_ifaces()]),
            crypto:hash(sha256, term_to_binary(Hashes))
    end.

%% Report §11.1: a module outside the source root is found by its namespace
%% under the build directory, then under each --load-path root in order. A
%% stale .erc is no module.
-spec dep_iface([atom()], #{[atom()] => #iface{}}, [file:filename(), ...], file:filename()) ->
          {[atom()], #iface{}}.
dep_iface(D, Ifaces, [OutDir | _] = Dirs, Root) ->
    case Ifaces of
        #{D := I} -> {D, I};
        _ ->
            Found = [{Dir, E} || Dir <- Dirs,
                                 E <- [filename:join(Dir, module_path(D) ++ ".erc")],
                                 filelib:is_regular(E)],
            {Dir, Erc} = case Found of
                             [First | _] -> First;
                             [] -> {OutDir, filename:join(OutDir, module_path(D) ++ ".erc")}
                         end,
            case read_erc(Erc) of
                {ok, #{iface := I} = Chunk} ->
                    case gone(Chunk, Dir, Root) of
                        false -> {D, I};
                        Source -> fail("no module " ++ qname(D) ++ ": " ++ shown(Erc)
                                       ++ " was compiled from " ++ shown(Source)
                                       ++ ", which no longer exists")
                    end;
                {error, Why} -> fail("compile " ++ qname(D) ++ " first: " ++ Erc ++ ": " ++ Why)
            end
    end.

%% Report §11.1: a .erc under the root Dir is stale when the source it
%% records, from Dir, lies under the source root and no longer exists; the
%% source is returned, and false for a .erc that is not.
gone(#{source_path := Recorded}, Dir, Root) ->
    Source = absolute(filename:join(Dir, unicode:characters_to_list(Recorded))),
    case relative(Source, Root) =/= outside andalso not filelib:is_regular(Source) of
        true -> Source;
        false -> false
    end;
gone(_, _, _) ->
    false.

-spec load_path([term()]) -> [file:filename()].
load_path(Opts) ->
    [absolute(D) || {load_path, D} <- Opts].

%% Report §11.1: current when the source and its path from the build root,
%% every dependency's interface, the standard library's interfaces, and the
%% build of the compiler are those the .erc was built from.
current(Erc, SourceHash, SourcePath, DepHashes, Std) ->
    Version = compiler_build(),
    case read_erc(Erc) of
        {ok, #{iface := Iface, source_hash := SourceHash, source_path := SourcePath,
               deps := Deps, compiler := Version, stdlib := Std}} ->
            case lists:sort(Deps) =:= DepHashes of
                true -> {true, Iface};
                false -> false
            end;
        _ -> false
    end.

%% Report §11.1: the modules whose code shapes a .erc: those that compile,
%% and every module of the toolchain they call, which a test holds them to.
-spec compiler_modules() -> [module()].
compiler_modules() ->
    [ern_ast, ern_bitspec, ern_descriptor, ern_diag, ern_docs, ern_emitter, ern_exhaust,
     ern_iface, ern_lexer, ern_parser, ern_prelude, ern_reply, ern_scope, ern_typecheck,
     ern_types, ern_build].

%% Report §11.1: the build of ern, its version and a hash of the modules
%% that compile, so that a compiler changed under one version is another.
compiler_build() ->
    Hash = erlang:md5(term_to_binary([M:module_info(md5) || M <- compiler_modules()])),
    <<(list_to_binary(?VERSION))/binary, $+, (binary:encode_hex(Hash, lowercase))/binary>>.

read_erc(Erc) ->
    case file:read_file(Erc) of
        {ok, Bin} -> ern_iface:read(Bin);
        {error, Reason} -> {error, file:format_error(Reason)}
    end.

%% Report §11.1: remove every stale .erc under the mirror of the compiled
%% subtree, and each directory of the subtree the removals leave empty.
sweep(Dir, Root, OutDir) ->
    Sub = absolute(filename:join(OutDir, relative(Dir, Root))),
    lists:foreach(fun(Erc) ->
                      ok = file:delete(Erc),
                      remove_emptied(filename:dirname(Erc), Sub, OutDir)
                  end, [Erc || Erc <- outputs(Sub), stale(Erc, OutDir, Root)]).

%% A .erc that does not read as this compiler's records nothing, and is kept.
stale(Erc, OutDir, Root) ->
    case read_erc(Erc) of
        {ok, Chunk} -> gone(Chunk, OutDir, Root) =/= false;
        {error, _} -> false
    end.

%% Report §11.1: every .erc under a directory, passing over each name that
%% begins with a dot, as sources/1 does, and each symbolic link.
outputs(Dir) ->
    case file:list_dir(Dir) of
        {ok, Names} ->
            lists:append([case file:read_link_info(Path) of
                              {ok, #file_info{type = directory}} -> outputs(Path);
                              {ok, #file_info{type = regular}} ->
                                  [Path || filename:extension(Name) =:= ".erc"];
                              _ -> []
                          end || Name <- lists:sort(Names), hd(Name) =/= $.,
                                 Path <- [filename:join(Dir, Name)]]);
        {error, _} -> []
    end.

%% A directory the sweep emptied, and each above it that it empties in turn,
%% up to the top of the swept subtree and never the build root; del_dir
%% removes a directory only when it is empty.
remove_emptied(Dir, Sub, OutDir) ->
    case Dir =/= OutDir andalso relative(Dir, Sub) =/= outside andalso file:del_dir(Dir) of
        ok -> remove_emptied(filename:dirname(Dir), Sub, OutDir);
        _ -> ok
    end.


%% Report §11.2: a module compiled from its source for the shell, as
%% `ern build` would compile it but in memory, since `:load` and `:reload`
%% write nothing. `Root` is the source root and `Dirs` the load path, the
%% roots a dependency outside the source root is found under by its
%% namespace, in order (§11.1). A refusal is a sentence, and diagnostics
%% come with the file they are in.
-spec compile_source(file:filename(), file:filename(), [file:filename(), ...]) ->
          {ok, [atom()], binary(), binary()} | {refused, string()}
          | {error, file:filename(), [ern_diag:diag()]}.
compile_source(File, Root, Dirs) ->
    try
        [#mod{ns = Ns, rel = Rel, decls = Decls, deps = Deps}] =
            compile_order([module_of(absolute(File), Root)], Root, Dirs),
        DepIfaces = [dep_iface(D, #{}, Dirs, Root) || D <- Deps],
        DepHashes = lists:sort([{D, ern_iface:hash(I)} || {D, I} <- DepIfaces]),
        {ok, Source} = file:read_file(File),
        Hash = crypto:hash(sha256, Source),
        case ern_typecheck:check(Ns, Decls, [I || {_, I} <- DepIfaces]) of
            {ok, Typed, Iface, Env} ->
                %% the dependencies are recorded as `ern build` records them, so
                %% the shell loads them before the module (report §11.2)
                Build = #{source_hash => Hash, deps => DepHashes,
                          source => list_to_binary(filename:basename(Rel))},
                {ok, _, Beam} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
                {ok, Ns, Beam, Hash};
            {error, Errors} ->
                {error, File, Errors}
        end
    catch
        throw:{cli_error, Message} -> {refused, Message};
        %% a source that does not lex or parse is refused as one that does
        %% not check is, its diagnostics given back and not raised
        throw:{errors, Failed, Unread} -> {error, Failed, Unread}
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
normalize(["." | R], Acc) -> normalize(R, Acc);
normalize([".." | R], [_ | Acc]) -> normalize(R, Acc);
normalize([Seg | R], Acc) -> normalize(R, [Seg | Acc]).

%% Path relative to Root, or outside.
-spec relative(file:filename(), file:filename()) -> file:filename() | outside.
relative(Path, Root) ->
    P = filename:split(absolute(Path)),
    R = filename:split(absolute(Root)),
    case lists:prefix(R, P) of
        true ->
            case lists:nthtail(length(R), P) of
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

unshared([S | Base], [S | Path]) -> unshared(Base, Path);
unshared(Base, Path) -> filename:join([".." || _ <- Base] ++ Path).

-spec qname([atom()]) -> string().
qname(Ns) ->
    lists:flatten(lists:join(".", [atom_to_list(S) || S <- Ns])).

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
    Target = followed(File, 0),
    %% report §11: a file its owner may not write is refused, not replaced
    case file:read_file_info(Target) of
        {ok, #file_info{access = Access}} when Access =:= read; Access =:= none ->
            fail(File ++ ": " ++ file:format_error(eacces));
        _ ->
            ok
    end,
    %% a name of this writer's own, so that two jobs writing one file at
    %% once each write theirs whole and the last rename wins (report §11)
    Own = os:getpid() ++ "." ++ integer_to_list(erlang:unique_integer([positive])),
    New = filename:join(filename:dirname(Target),
                        "." ++ filename:basename(Target) ++ "." ++ Own ++ ".new"),
    Kept = case {Mode, file:read_file_info(Target)} of
               {undefined, {ok, #file_info{mode = M}}} -> M band 8#7777;
               {undefined, _} -> undefined;
               {M, _} -> M
           end,
    Steps = [fun() -> file:write_file(New, <<>>) end]
        ++ [fun() -> file:change_mode(New, Kept) end || Kept =/= undefined]
        ++ [fun() -> file:write_file(New, Data) end, fun() -> file:rename(New, Target) end],
    case lists:foldl(fun(Step, ok) -> Step(); (_, Failed) -> Failed end, ok, Steps) of
        ok ->
            ok;
        {error, Reason} ->
            _ = file:delete(New),
            fail(File ++ ": " ++ file:format_error(Reason))
    end.

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
fail(Msg) ->
    throw({cli_error, lists:flatten(Msg)}).

