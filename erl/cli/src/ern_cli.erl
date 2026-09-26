%% The two programs of report §11: ernc (§11.1, §11.4) and ern (§11.2,
%% §11.3). The escripts under bin/ are thin; everything is here so that the
%% tests can call it. Each entry point returns the exit status.
-module(ern_cli).

-export([main/2, ernc/1, ernc/2, namespace/1, segment/1, module_path/1, ern/1, ern/2,
         compile_source/3]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

%% VERSION is the top-level VERSION file, passed by the Makefile.

%%
%% Entry
%%

-spec main(ernc | ern, [string()]) -> no_return().
main(Tool, Args) ->
    halt(?MODULE:Tool(Args, standard_error)).

%% Run a tool with its options parsed by getopt. --help and --version
%% print and stop with status 0; a usage error prints the message and the
%% usage on Err, the error device, any other error one line, both with
%% status 1. Err is standard_error for the escripts; a test passes its
%% own device and reads what the user would see.
tool(Tool, Spec, Positional, Args, Fun, Err) ->
    try
        {Opts, Rest} = case getopt:parse(Spec, Args) of
                           {ok, Parsed} -> Parsed;
                           {error, {Reason, Data}} ->
                               usage_fail(getopt:format_error(Spec, {Reason, Data}))
                       end,
        case {lists:member(help, Opts), lists:member(version, Opts)} of
            {true, _} -> usage(Spec, Tool, Positional, standard_io), 0;
            {_, true} -> io:format("~s ~s~n", [Tool, ?VERSION]), 0;
            _ -> Fun(Opts, Rest, Err)
        end
    catch
        throw:{cli_usage, Msg} ->
            io:format(Err, "~s: ~ts~n", [Tool, Msg]),
            usage(Spec, Tool, Positional, Err),
            1;
        throw:{cli_error, Msg} ->
            io:format(Err, "~s: ~ts~n", [Tool, Msg]),
            1
    end.

%% getopt's usage text on any device; getopt:usage/4 takes only an atom.
usage(Spec, Tool, Positional, Device) ->
    io:format(Device, "~ts ~ts~n~n~ts~n",
              [getopt:usage_cmd_line(atom_to_list(Tool), Spec), Positional,
               getopt:usage_options(Spec)]).

%%
%% ernc, report §11.1 and §11.4
%%

ernc_options() ->
    [{source_root, undefined, "source-root", string,
      "the directory whose layout yields namespaces"},
     {out_dir, undefined, "out-dir", string,
      "where the compiled tree goes; default: the source root"},
     {load_path, undefined, "load-path", string,
      "a root of compiled modules a module may use; may be repeated"},
     {emit, undefined, "emit", string, "erl: write the module's Erlang source instead of .erc"},
     {no_clean, undefined, "no-clean", undefined,
      "keep stale .erc files under the build directory"},
     {doc, undefined, "doc", undefined,
      "write the documentation of a file to stdout, of a directory into the build directory"},
     {errors, undefined, "errors", string, "short: the first line of each error only"},
     {help, undefined, "help", undefined, "print this text"},
     {version, undefined, "version", undefined, "print the version"}].

-spec ernc([string()]) -> 0 | 1.
ernc(Args) ->
    ernc(Args, standard_error).

-spec ernc([string()], io:device()) -> 0 | 1.
ernc(Args, Err) ->
    tool(ernc, ernc_options(), "file.ern | src-dir", Args, fun ernc_main/3, Err).

ernc_main(Opts, Rest, Err) ->
    case {Rest, lists:member(doc, Opts)} of
        {[Path], true} -> doc(Opts, Path, Err);
        {[Path], false} -> ernc_compile(Opts, Path, Err);
        _ -> usage_fail("one file or directory argument is required")
    end.

ernc_compile(Opts, Path, Err) ->
    Emit = case proplists:get_value(emit, Opts) of
               undefined -> erc;
               "erl" -> erl;
               Other -> usage_fail("unknown --emit kind " ++ Other ++ "; erl is the only kind")
           end,
    case proplists:get_value(errors, Opts) of
        undefined -> ok;
        "short" -> ok;
        Kind -> usage_fail("unknown --errors kind " ++ Kind ++ "; short is the only kind")
    end,
    filelib:is_file(Path) orelse fail("no such file or directory " ++ Path),
    DirMode = filelib:is_dir(Path),
    Root = source_root(Opts, Path, case DirMode of true -> Path; false -> "." end),
    OutDir = out_dir(Opts, Root),
    Files = case DirMode of
                true -> [filename:join(Path, F) || F <- filelib:wildcard("**/*.ern", Path)];
                false -> [Path]
            end,
    Modules = [module_of(absolute(F), Root) || F <- Files],
    Dirs = [OutDir | load_path(Opts)],
    try
        Order = compile_order(Modules, Root, load_path(Opts)),
        Std = stdlib_hash(Root),
        lists:foldl(fun(M, Ifaces) -> build(M, Ifaces, Dirs, Emit, Std) end, #{}, Order),
        case DirMode andalso Emit =:= erc andalso not lists:member(no_clean, Opts) of
            true -> sweep(absolute(Path), Root, OutDir);
            false -> ok
        end,
        0
    catch
        throw:{errors, File, Errors} -> report_errors(Opts, File, Errors, Err)
    end.

%% Report §11.5: each error as ern_diag renders it, the first line alone
%% under --errors short; status 1. The file is named from the working
%% directory when it lies under it.
report_errors(Opts, File, Errors, Err) ->
    Short = proplists:get_value(errors, Opts) =:= "short",
    Source = case file:read_file(File) of
                 {ok, Bin} -> Bin;
                 _ -> <<>>
             end,
    {ok, Cwd} = file:get_cwd(),
    Shown = case relative(File, Cwd) of
                outside -> absolute(File);
                Rel -> Rel
            end,
    lists:foreach(fun(D) ->
                      Text = case Short of
                                 true -> ern_diag:short(Shown, D);
                                 false -> ern_diag:format(Shown, Source, D)
                             end,
                      io:format(Err, "~ts~n", [Text])
                  end, Errors),
    1.

%% A source file as a module: its namespace from its path under the root,
%% with the path shape rule of §11.1.
-record(mod, {ns, file, rel, decls, deps = []}).

module_of(File, Root) ->
    Rel = relative(File, Root),
    Rel =/= outside orelse fail(File ++ " is not under the source root " ++ Root),
    %% report §4.2: a file of the standard library's own source root is
    %% compiled with that root only
    is_stdlib_root(Root) orelse relative(File, stdlib_root()) =:= outside orelse
        fail(Rel ++ " is in the standard library's source root; omit --source-root"),
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
compile_order(Modules, Root) ->
    compile_order(Modules, Root, []).

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
    Clash = fun(ChildRel, T, ParentRel, Q) ->
                fail(ChildRel ++ " and type " ++ atom_to_list(T) ++ " in " ++ ParentRel
                     ++ " share the namespace " ++ qname(Q) ++ " (report §4.2)")
            end,
    case Ns of
        [_, _ | _] ->
            Parent = lists:droplast(Ns),
            ParentRel = module_path(Parent) ++ ".ern",
            lists:member(lists:last(Ns), source_types(filename:join(Root, ParentRel)))
                andalso Clash(Rel, lists:last(Ns), ParentRel, Ns);
        _ ->
            ok
    end,
    lists:foreach(fun(T) ->
                      ChildRel = module_path(Ns ++ [T]) ++ ".ern",
                      filelib:is_regular(filename:join(Root, ChildRel))
                          andalso Clash(ChildRel, T, Rel, Ns ++ [T])
                  end, local_types(Decls)).

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
source_root(Opts, Path, Default) ->
    case proplists:get_value(source_root, Opts) of
        undefined ->
            case relative(Path, stdlib_root()) of
                outside -> absolute(Default);
                _ -> stdlib_root()
            end;
        Root -> absolute(Root)
    end.

%% Report §11.1: the build directory is --out-dir; without it, the source
%% root, and `build/stdlib` for the standard library's own root, where the
%% Makefile builds it.
out_dir(Opts, Root) ->
    case proplists:get_value(out_dir, Opts) of
        undefined ->
            case is_stdlib_root(Root) of
                true -> absolute(filename:join([filename:dirname(stdlib_root()), "build",
                                                "stdlib"]));
                false -> Root
            end;
        Dir -> absolute(Dir)
    end.

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
build(#mod{ns = Ns, file = File, rel = Rel, decls = Decls, deps = Deps}, Ifaces,
      [OutDir | _] = Dirs, Emit, Std) ->
    DepIfaces = [dep_iface(D, Ifaces, Dirs) || D <- Deps],
    DepHashes = lists:sort([{D, ern_emitter:iface_hash(I)} || {D, I} <- DepIfaces]),
    {ok, Source} = file:read_file(File),
    SourceHash = crypto:hash(sha256, Source),
    Out = filename:join(OutDir, filename:rootname(Rel)),
    Erc = Out ++ ".erc",
    case Emit =:= erc andalso current(Erc, SourceHash, DepHashes, Std) of
        {true, Iface} ->
            Ifaces#{Ns => Iface};
        false ->
            case ern_typecheck:check(Ns, Decls, [I || {_, I} <- DepIfaces]) of
                {ok, Typed, Iface, Env} ->
                    ok = filelib:ensure_dir(Erc),
                    case Emit of
                        erl ->
                            Src = ["%% Generated by ernc from ", Rel, "\n",
                                   ern_emitter:erl_source(Ns, Typed, Env)],
                            ok = file:write_file(Out ++ ".erl", Src);
                        erc ->
                            Build = #{source_hash => SourceHash, deps => DepHashes,
                                      compiler => compiler_build(), stdlib => Std,
                                      source => list_to_binary(filename:basename(Rel))},
                            case ern_emitter:compile(Ns, Typed, Iface, Env, Build) of
                                {ok, _, Beam} -> ok = file:write_file(Erc, Beam);
                                {error, Errors} -> throw({errors, File, Errors})
                            end
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
            Hashes = lists:sort([{I#iface.namespace, ern_emitter:iface_hash(I)}
                                 || I <- ern_prelude:stdlib_ifaces()]),
            crypto:hash(sha256, term_to_binary(Hashes))
    end.

%% Report §11.1: a module outside the source root is found by its namespace
%% under the build directory, then under each --load-path root in order.
dep_iface(D, Ifaces, [OutDir | _] = Dirs) ->
    case Ifaces of
        #{D := I} -> {D, I};
        _ ->
            Found = [E || Dir <- Dirs,
                          E <- [filename:join(Dir, module_path(D) ++ ".erc")],
                          filelib:is_regular(E)],
            Erc = case Found of
                      [First | _] -> First;
                      [] -> filename:join(OutDir, module_path(D) ++ ".erc")
                  end,
            case read_erc(Erc) of
                {ok, #{iface := I}} -> {D, I};
                {error, Why} -> fail("compile " ++ qname(D) ++ " first: " ++ Erc ++ ": " ++ Why)
            end
    end.

load_path(Opts) ->
    [absolute(D) || {load_path, D} <- Opts].

%% Report §11.1: current when the source, every dependency's interface, the
%% standard library's interfaces, and the build of the compiler are those the
%% .erc was built from.
current(Erc, SourceHash, DepHashes, Std) ->
    Version = compiler_build(),
    case read_erc(Erc) of
        {ok, #{iface := Iface, source_hash := SourceHash, deps := Deps, compiler := Version,
               stdlib := Std}} ->
            case lists:sort(Deps) =:= DepHashes of
                true -> {true, Iface};
                false -> false
            end;
        _ -> false
    end.

%% Report §11.1: the build of ernc, its version and a hash of the modules
%% that compile, so that a compiler changed under one version is another.
compiler_build() ->
    Mods = [ern_lexer, ern_diag, ern_parser, ern_types, ern_typecheck, ern_reply, ern_exhaust,
            ern_prelude, ern_emitter, ern_cli],
    Hash = erlang:md5(term_to_binary([M:module_info(md5) || M <- Mods])),
    <<(list_to_binary(?VERSION))/binary, $+, (binary:encode_hex(Hash, lowercase))/binary>>.

read_erc(Erc) ->
    case file:read_file(Erc) of
        {ok, Bin} -> ern_emitter:read_interface(Bin);
        {error, Reason} -> {error, file:format_error(Reason)}
    end.

%% Report §11.1: remove .erc files under the mirror of the compiled subtree
%% whose source is gone, and directories left empty.
sweep(Dir, Root, OutDir) ->
    Sub = filename:join(OutDir, relative(Dir, Root)),
    lists:foreach(fun(Rel) ->
                      Source = filename:join(Root, filename:rootname(Rel) ++ ".ern"),
                      case filelib:is_regular(Source) of
                          true -> ok;
                          false -> ok = file:delete(filename:join(OutDir, Rel))
                      end
                  end, [filename:join(relative(Sub, OutDir), F)
                        || F <- filelib:wildcard("**/*.erc", Sub)]),
    remove_empty(Sub, OutDir).

remove_empty(Dir, Top) ->
    case file:list_dir(Dir) of
        {ok, Entries} ->
            lists:foreach(fun(E) ->
                              Path = filename:join(Dir, E),
                              filelib:is_dir(Path) andalso remove_empty(Path, Top)
                          end, Entries),
            case Dir =/= Top andalso file:list_dir(Dir) =:= {ok, []} of
                true -> ok = file:del_dir(Dir);
                false -> ok
            end;
        _ -> ok
    end.

%% Report §11.4: a file's documentation to stdout, a directory's into the
%% build directory, one document per module and an index. The modules are
%% compiled first, so every document is of a module that type-checks and
%% every dependency has an interface.
doc(Opts, Path, Err) ->
    case filelib:is_dir(Path) of
        true ->
            case ernc_compile(Opts -- [doc], Path, Err) of
                0 -> doc_dir(Opts, Path);
                Status -> Status
            end;
        false ->
            filelib:is_regular(Path) orelse fail("no such file " ++ Path),
            try
                io:put_chars(ern_page:page(beam_of(Opts, Path))),
                0
            catch
                throw:{errors, F, Errors} -> report_errors(Opts, F, Errors, Err)
            end
    end.

%% Report §11.4: the documentation comes from the compiled module. A `.erc`
%% is read; a source is compiled first, in memory, so that asking for a page
%% writes nothing.
beam_of(Opts, Path) ->
    case filename:extension(Path) of
        ".erc" ->
            {ok, Bin} = file:read_file(Path),
            Bin;
        _ ->
            Root = source_root(Opts, Path, "."),
            OutDir = out_dir(Opts, Root),
            [#mod{ns = Ns, file = File, rel = Rel, decls = Decls, deps = Deps}] =
                compile_order([module_of(absolute(Path), Root)], Root, load_path(Opts)),
            DepIfaces = [I || D <- Deps,
                              {_, I} <- [dep_iface(D, #{}, [OutDir | load_path(Opts)])]],
            case ern_typecheck:check(Ns, Decls, DepIfaces) of
                {ok, Typed, Iface, Env} ->
                    Build = #{source_hash => <<>>, deps => [],
                              source => list_to_binary(filename:basename(Rel))},
                    case ern_emitter:compile(Ns, Typed, Iface, Env, Build) of
                        {ok, _, Beam} -> Beam;
                        {error, Errors} -> throw({errors, File, Errors})
                    end;
                {error, Errors} ->
                    throw({errors, File, Errors})
            end
    end.

doc_dir(Opts, Path) ->
    Root = source_root(Opts, Path, Path),
    OutDir = out_dir(Opts, Root),
    Files = [filename:join(Path, F) || F <- filelib:wildcard("**/*.ern", Path)],
    Mods = compile_order([module_of(absolute(F), Root) || F <- Files], Root),
    Entries = [begin
                   Rel = module_path(Ns) ++ ".md",
                   Out = filename:join(OutDir, Rel),
                   ok = filelib:ensure_dir(Out),
                   Erc = filename:join(OutDir, module_path(Ns) ++ ".erc"),
                   {ok, Beam} = file:read_file(Erc),
                   ok = file:write_file(Out, unicode:characters_to_binary(ern_page:page(Beam))),
                   ["- [", qname(Ns), "](", Rel, ")\n"]
               end || #mod{ns = Ns} <- lists:sort(Mods)],
    Prelude = prelude_page(is_stdlib_root(Root), OutDir),
    ok = file:write_file(filename:join(OutDir, "index.md"),
                         unicode:characters_to_binary(["# Modules\n\n", Prelude, Entries])),
    0.

%% Report §11.4: the standard library's own source root also gets the
%% prelude's page, first in the index.
prelude_page(false, _OutDir) ->
    [];
prelude_page(true, OutDir) ->
    ok = file:write_file(filename:join(OutDir, "prelude.md"),
                         unicode:characters_to_binary(ern_page:prelude_page())),
    ["- [Prelude](prelude.md)\n"].

%%
%% ern, report §11.2 and §11.3
%%

ern_options() ->
    [{config_dir, undefined, "config-dir", string,
      "the configuration directory; default ./.ernest"},
     {load_path, undefined, "load-path", string, "a root of compiled modules; may be repeated"},
     {main, undefined, "main", string, "the entry point, a qualified exported function"},
     {shell, undefined, "shell", undefined, "add an interactive shell to the running program"},
     {source_root, undefined, "source-root", string,
      "where the shell finds a module's source; default the working directory"},
     {test, undefined, "test", undefined, "run the module's tests instead of its entry point"},
     {create_config_dir, undefined, "create-config-dir", string,
      "create dir/.ernest with a configuration and a private key, and stop"},
     {help, undefined, "help", undefined, "print this text"},
     {version, undefined, "version", undefined, "print the version"}].

-spec ern([string()]) -> 0 | 1.
ern(Args) ->
    ern(Args, standard_error).

-spec ern([string()], io:device()) -> 0 | 1.
ern(Args, Err) ->
    tool(ern, ern_options(), "file.erc", Args, fun ern_main/3, Err).

ern_main(Opts, Rest, Err) ->
    case {proplists:get_value(create_config_dir, Opts), lists:member(shell, Opts), Rest} of
        {Dir, _, []} when Dir =/= undefined -> create_config_dir(Dir);
        {undefined, true, Rest2} -> shell(Opts, Rest2, Err);
        {undefined, false, [File]} -> run(Opts, File, Err);
        _ -> usage_fail("one .erc file argument is required")
    end.

%% Report §11.2: the shell is the entry process, and a file's entry point is
%% spawned beside it, so §8.6 ends the program when the shell ends and not
%% when that entry point returns. The shell spawns it itself, through the
%% front end, so that it can monitor it (§6.9); what the runner does is load
%% the modules, put their interfaces in the session's scope, and run their
%% initializers (§8.5) before the shell starts.
shell(Opts, Rest, Err) ->
    quiet_signals(),
    Mod = ern_emitter:module_atom(['Shell']),
    case code:ensure_loaded(Mod) of
        {module, Mod} -> ok;
        _ -> fail("the shell is not built; run make")
    end,
    Init = case Rest of
               [] ->
                   host_path(load_path(Opts)),
                   ern_shell:loaded(#{roots => load_path(Opts),
                                      source_root => source_root(Opts, ".", "."),
                                      ifaces => [], entry => none,
                                      startups => startups(Opts),
                                      history => history_file()}),
                   fun() -> ok end;
               [File] ->
                   {Ns, Roots, Loaded} = program(File, Opts),
                   {Entry, Loaded1} = shell_entry(Opts, Ns, Roots, Loaded),
                   ern_shell:loaded(#{roots => Roots,
                                      source_root => source_root(Opts, File, "."),
                                      ifaces => ifaces(Loaded1),
                                      entry => Entry,
                                      startups => startups(Opts),
                                      history => history_file()}),
                   init_fun(Loaded1);
               _ ->
                   usage_fail("--shell takes at most one .erc file")
           end,
    %% report §11.2: the sinks are the screen's, which the shell names
    Sink = fun(Bin) -> ern_shell:to_screen(Bin) end,
    case ern_rt:run_main(fun() -> Mod:main() end, <<"Shell.main">>,
                         #{stdout => Sink, stderr => Sink, init => Init}) of
        ok -> 0;
        {fault, Msg} ->
            io:format(Err, "fault: ~ts~n", [Msg]),
            1
    end.

run(Opts, File, Err) ->
    quiet_signals(),
    {Ns, Roots, Loaded} = program(File, Opts),
    case lists:member(test, Opts) of
        true -> run_tests(Ns, Loaded, Err);
        false -> run_entry(Opts, Ns, Roots, Loaded, Err)
    end.

%% The module of a `.erc`, its load path, and every module loaded for it:
%% the file's own dependencies first (report §11.2, §4.2).
program(File, Opts) ->
    filelib:is_regular(File) orelse fail("no such file " ++ File),
    filename:extension(File) =:= ".erc" orelse fail(File ++ " does not end in .erc"),
    Abs = absolute(File),
    {ok, Bin} = file:read_file(Abs),
    Ns = case ern_emitter:read_interface(Bin) of
             {ok, #{iface := #iface{namespace = N}}} -> N;
             {error, Why} -> fail(File ++ ": " ++ Why)
         end,
    %% the root lies as many directories up as the namespace is deep
    Root = lists:foldl(fun(_, D) -> filename:dirname(D) end, Abs, Ns),
    relative(Abs, Root) =:= module_path(Ns) ++ ".erc" orelse
        fail(File ++ " is not at the path of its namespace " ++ qname(Ns)),
    lists:foreach(fun shape/1, filename:split(filename:rootname(module_path(Ns)))),
    Roots = [Root | load_path(Opts)],
    host_path(Roots),
    {Ns, Roots, load(Ns, Roots, [])}.

%% Report §11.2: an Erlang module a `foreign fn` names is the host's own or
%% a `.beam` in a directory of the load path, the host's own found first.
host_path(Roots) ->
    ok = code:add_pathsz(Roots).

%% Report §11.2: the interfaces of the modules loaded, which the shell puts
%% in the session's scope, each with the hash of the source it was compiled
%% from, which `:reload` compares against the source it finds; both are in
%% the `ErnI` chunk of the `.erc` it came from (§11.1).
ifaces(Loaded) ->
    [{I, H} || Mod <- lists:reverse(Loaded),
               {ok, Bin} <- [file:read_file(code:which(Mod))],
               {ok, #{iface := I, source_hash := H}} <- [ern_emitter:read_interface(Bin)]].

%% Report §11.2: where the startup files are, the person's first and then
%% the node's; the shell reads them and finds out whether they are there.
%% The node's is in the configuration directory of §11.3, which
%% `--config-dir` names.
startups(Opts) ->
    Config = proplists:get_value(config_dir, Opts, ".ernest"),
    Home = case os:getenv("HOME") of
               false -> [];
               Dir -> [filename:join([Dir, ".ernest", "startup"])]
           end,
    Home ++ [filename:join(Config, "startup")].

%% Report §11.2: where the person's history is kept. Only where it is is
%% the host's to say; the shell reads and writes it in Ernest.
history_file() ->
    case os:getenv("HOME") of
        false -> none;
        Dir -> filename:join([Dir, ".ernest", "history"])
    end.

%% Report §11.2: a module compiled from its source for the shell, as
%% `ernc` would compile it but in memory, since `:load` and `:reload`
%% write nothing. `Root` is the source root and `Dirs` the load path, the
%% roots a dependency outside the source root is found under by its
%% namespace, in order (§11.1).
-spec compile_source(file:filename(), file:filename(), [file:filename(), ...]) ->
          {ok, [atom()], binary(), binary()} | {error, file:filename(), [term()]}.
compile_source(File, Root, Dirs) ->
    try
        [#mod{ns = Ns, rel = Rel, decls = Decls, deps = Deps}] =
            compile_order([module_of(absolute(File), Root)], Root, Dirs),
        DepIfaces = [dep_iface(D, #{}, Dirs) || D <- Deps],
        DepHashes = lists:sort([{D, ern_emitter:iface_hash(I)} || {D, I} <- DepIfaces]),
        {ok, Source} = file:read_file(File),
        Hash = crypto:hash(sha256, Source),
        case ern_typecheck:check(Ns, Decls, [I || {_, I} <- DepIfaces]) of
            {ok, Typed, Iface, Env} ->
                %% the dependencies are recorded as `ernc` records them, so
                %% the shell loads them before the module (report §11.2)
                Build = #{source_hash => Hash, deps => DepHashes,
                          source => list_to_binary(filename:basename(Rel))},
                case ern_emitter:compile(Ns, Typed, Iface, Env, Build) of
                    {ok, _, Beam} -> {ok, Ns, Beam, Hash};
                    {error, Errors} -> {error, File, Errors}
                end;
            {error, Errors} ->
                {error, File, Errors}
        end
    catch
        throw:{cli_error, Message} -> {error, File, [Message]};
        %% a source that does not lex or parse is refused as one that does
        %% not check is, its diagnostics given back and not raised
        throw:{errors, Failed, Unread} -> {error, Failed, Unread}
    end.

%% Report §8.6: a signal from outside ends the program as returning from
%% main does, and the runtime prints nothing of its own about it. The host
%% ends the node in order, which flushes what has been written; its own
%% notice of the signal is an informational report, and a program's output
%% is not to be mixed with it.
quiet_signals() ->
    ok = os:set_signal(sigterm, handle),
    ok = os:set_signal(sighup, handle),
    %% the host logs its own note about the signal at notice level, and a
    %% program's output is not to be mixed with it; a warning or an error
    %% from the host still comes through.
    _ = logger:set_handler_config(default, level, warning),
    ok.

%% Report §8.5: every top-level let of the loaded modules, dependencies
%% first, once the runtime has bound the Sys.* references.
init_fun(Loaded) ->
    fun() ->
        lists:foreach(fun(Mod) ->
                          erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'()
                      end, lists:reverse(Loaded))
    end.

%% Report §11.2: every test of the module, each in a process of its own;
%% status 1 unless every one passed.
run_tests(Ns, Loaded, Err) ->
    Mod = ern_emitter:module_atom(Ns),
    Me = self(),
    Main = fun() ->
               Tests = case erlang:function_exported(Mod, '$tests', 0) of
                           true -> Mod:'$tests'();
                           false -> []
                       end,
               Me ! {ern_tests, [run_test(T) || T <- Tests]}
           end,
    Site = unicode:characters_to_binary(qname(Ns) ++ ".$tests"),
    case ern_rt:run_main(Main, Site, #{init => init_fun(Loaded)}) of
        ok ->
            Results = receive {ern_tests, R} -> R after 0 -> [] end,
            lists:foreach(fun({Name, Outcome}) ->
                              io:format("~ts: ~ts~n", [Name, Outcome])
                          end, Results),
            case [N || {N, Outcome} <- Results, Outcome =/= <<"passed">>] of
                [] -> 0;
                _ -> 1
            end;
        {fault, Msg} ->
            io:format(Err, "fault: ~ts~n", [Msg]),
            1
    end.

%% One test, Test(name, run) in canonical field order, in a process of its
%% own, monitored so that a fault is reported and not taken for the run's.
run_test({'Test', Name, Run}) ->
    Me = ern_rt:self(),
    Ref = make_ref(),
    Pid = ern_rt:spawn('Local', fun() -> Me ! {Ref, Run()} end, Name),
    ern_rt:monitor(Pid, fun(Down) -> {Ref, down, Down} end),
    Outcome = receive
                  {Ref, 'Passed'} -> returned(Ref, <<"passed">>);
                  {Ref, {'Failed', Text}} -> returned(Ref, <<"failed: ", Text/binary>>);
                  {Ref, down, {'Down', _, Reason}} -> <<"faulted: ", (cause(Reason))/binary>>
              end,
    {Name, Outcome}.

%% A test that returned still sends its Down; it is taken so that it is not
%% left in the runner's mailbox.
returned(Ref, Outcome) ->
    receive {Ref, down, _} -> Outcome end.

cause({'Fault', Msg}) -> Msg;
cause(Reason) -> atom_to_binary(Reason).

run_entry(Opts, Ns, Roots, Loaded, Err) ->
    {EntryMod, EntryFn, Loaded1} = entry_point(Opts, Ns, Roots, Loaded),
    Init = init_fun(Loaded1),
    Site = entry_site(EntryMod, EntryFn),
    case ern_rt:run_main(fun() -> EntryMod:EntryFn() end, Site, #{init => Init}) of
        ok -> 0;
        {fault, Msg} ->
            %% report §8.6: a deadlock is the entry process's fault
            io:format(Err, "fault: ~ts~n", [Msg]),
            1
    end.

%% Report §11.2: the entry point the shell spawns beside it, or none for a
%% file without one, which is loaded to be tried. A `main` that is not an
%% entry point (§8.1) leaves the file without one; a function `--main`
%% names must be one.
shell_entry(Opts, Ns, Roots, Loaded) ->
    Mod = ern_emitter:module_atom(Ns),
    case proplists:get_value(main, Opts) =:= undefined
         andalso entry_shape(Mod, main) =/= entry of
        true ->
            {none, Loaded};
        false ->
            {EntryMod, EntryFn, Loaded1} = entry_point(Opts, Ns, Roots, Loaded),
            {{EntryMod, EntryFn, entry_site(EntryMod, EntryFn)}, Loaded1}
    end.

%% Report §8.1: the entry point, the loaded module's `main` or the function
%% `--main` names, and every module loaded for it. It is an exported `fn`
%% of type `() -> Unit`, with a mailbox type or pure; a top-level `let`,
%% and a function of another shape, is refused.
entry_point(Opts, Ns, Roots, Loaded) ->
    {EntryMod, EntryFn, Loaded1} =
        case proplists:get_value(main, Opts) of
            undefined -> {ern_emitter:module_atom(Ns), main, Loaded};
            Q ->
                Parts = [list_to_atom(P) || P <- string:split(Q, ".", all)],
                length(Parts) >= 2 orelse
                    usage_fail("--main takes a qualified name, Module.function"),
                MainNs = lists:droplast(Parts),
                {ern_emitter:module_atom(MainNs), lists:last(Parts), load(MainNs, Roots, Loaded)}
        end,
    Name = qname(entry_ns(EntryMod) ++ [EntryFn]),
    Shape = "; an entry point is an exported fn of type () -> Unit (report §8.1)",
    case entry_shape(EntryMod, EntryFn) of
        entry -> ok;
        missing -> fail("no exported function " ++ Name ++ Shape);
        {'let', Type} ->
            fail(Name ++ " is not an entry point: it is a let of type " ++ Type ++ Shape);
        {other, Type} ->
            fail(Name ++ " is not an entry point: its type is " ++ Type ++ Shape)
    end,
    {EntryMod, EntryFn, Loaded1}.

%% What the interface of a loaded module says of one of its names: an entry
%% point, a `let`, a function of another shape, or nothing it exports. A
%% result type that is a type variable is instantiated to `Unit`, as a
%% polymorphic mailbox type is to `Never` (report §8.1).
entry_shape(Mod, Fn) ->
    {ok, Bin} = file:read_file(code:which(Mod)),
    {ok, #{iface := #iface{namespace = Ns, values = Values, lets = Lets}}} =
        ern_emitter:read_interface(Bin),
    Q = Ns ++ [Fn],
    case maps:find(Q, Values) of
        error ->
            missing;
        {ok, #scheme{type = T} = Scheme} ->
            Type = ern_types:format_scheme(Scheme, ern_types:new()),
            case {lists:member(Q, Lets), T} of
                {true, _} -> {'let', Type};
                {false, {tfn, [], _, {tcon, ['Unit'], []}}} -> entry;
                {false, {tfn, [], _, {tvar, _}}} -> entry;
                {false, _} -> {other, Type}
            end
    end.

entry_site(Mod, Fn) ->
    unicode:characters_to_binary(qname(entry_ns(Mod)) ++ "." ++ atom_to_list(Fn)).

entry_ns(Mod) ->
    "ern@" ++ Path = atom_to_list(Mod),
    namespace(string:split(Path, "@", all)).

%% Load a module and, first, its dependencies, each once; the result lists
%% modules most recently loaded first, so dependencies come last.
load(Ns, Roots, Loaded) ->
    Mod = ern_emitter:module_atom(Ns),
    case lists:member(Mod, Loaded) of
        true -> Loaded;
        false ->
            Rel = module_path(Ns) ++ ".erc",
            File = case [F || R <- Roots, F <- [filename:join(R, Rel)], filelib:is_regular(F)] of
                       [F | _] -> F;
                       [] -> fail("cannot find module " ++ qname(Ns) ++ " (" ++ Rel
                                  ++ ") on the load path")
                   end,
            {ok, Bin} = file:read_file(File),
            {ok, #{deps := Deps}} = ern_emitter:read_interface(Bin),
            Loaded1 = lists:foldl(fun({D, _}, L) -> load(D, Roots, L) end, Loaded, Deps),
            code:purge(Mod),
            case code:load_binary(Mod, File, Bin) of
                {module, Mod} -> [Mod | Loaded1];
                {error, What} -> fail("cannot load " ++ File ++ ": " ++ atom_to_list(What))
            end
    end.

%% Report §11.3, Appendix C: a configuration with no peers and this node's
%% key pair; the network address is a placeholder to edit.
create_config_dir(Dir) ->
    Conf = filename:join(Dir, ".ernest"),
    not filelib:is_dir(Conf) orelse fail(Conf ++ " exists"),
    Key = public_key:generate_key({namedCurve, ed25519}),
    Private = public_key:pem_encode([public_key:pem_entry_encode('PrivateKeyInfo', Key)]),
    {'ECPrivateKey', _, _, _, PublicPoint, _} = Key,
    Curve = {namedCurve, pubkey_cert_records:namedCurves(ed25519)},
    Public = public_key:pem_encode(
               [public_key:pem_entry_encode('SubjectPublicKeyInfo',
                                            {{'ECPoint', PublicPoint}, Curve})]),
    Json = json:encode(#{<<"network-address">> => <<"127.0.0.1:8654">>,
                         <<"public-key">> => Public,
                         <<"peers">> => []}),
    ok = filelib:ensure_path(Conf),
    ok = file:write_file(filename:join(Conf, "ernest.conf"), [Json, "\n"]),
    KeyFile = filename:join(Conf, "private-key.pem"),
    ok = file:write_file(KeyFile, Private),
    ok = file:change_mode(KeyFile, 8#600),
    0.

%%
%% Options and paths
%%

%% Absolute and normalized: no `.` or `..` segments, so that a default root
%% of `.` is a prefix of the files under it.
absolute(Path) ->
    filename:join(normalize(filename:split(filename:absname(Path)), [])).

normalize([], Acc) -> lists:reverse(Acc);
normalize(["." | R], Acc) -> normalize(R, Acc);
normalize([".." | R], [_ | Acc]) -> normalize(R, Acc);
normalize([Seg | R], Acc) -> normalize(R, [Seg | Acc]).

%% Path relative to Root, or outside.
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

qname(Ns) ->
    lists:flatten(lists:join(".", [atom_to_list(S) || S <- Ns])).

fail(Msg) ->
    throw({cli_error, lists:flatten(Msg)}).

usage_fail(Msg) ->
    throw({cli_usage, lists:flatten(Msg)}).
