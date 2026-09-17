%% The two programs of report §11: ernc (§11.1, §11.4) and ern (§11.2,
%% §11.3). The escripts under bin/ are thin; everything is here so that the
%% tests can call it. Each entry point returns the exit status.
-module(ern_cli).

-export([main/2, ernc/1, ern/1, namespace/1, module_path/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").

-define(VERSION, "0.1.0").

%%
%% Entry
%%

-spec main(ernc | ern, [string()]) -> no_return().
main(Tool, Args) ->
    halt(?MODULE:Tool(Args)).

%% Run a tool with its options parsed by getopt. --help and --version
%% print and stop with status 0; a usage error prints the message and the
%% usage on stderr, any other error one line, both with status 1.
tool(Tool, Spec, Positional, Args, Fun) ->
    try
        {Opts, Rest} = case getopt:parse(Spec, Args) of
                           {ok, Parsed} -> Parsed;
                           {error, {Reason, Data}} ->
                               usage_fail(getopt:format_error(Spec, {Reason, Data}))
                       end,
        case {lists:member(help, Opts), lists:member(version, Opts)} of
            {true, _} -> getopt:usage(Spec, atom_to_list(Tool), Positional, standard_io), 0;
            {_, true} -> io:format("~s ~s~n", [Tool, ?VERSION]), 0;
            _ -> Fun(Opts, Rest)
        end
    catch
        throw:{cli_usage, Msg} ->
            io:format(standard_error, "~s: ~s~n", [Tool, Msg]),
            getopt:usage(Spec, atom_to_list(Tool), Positional, standard_error),
            1;
        throw:{cli_error, Msg} ->
            io:format(standard_error, "~s: ~s~n", [Tool, Msg]),
            1
    end.

%%
%% ernc, report §11.1 and §11.4
%%

ernc_options() ->
    [{source_root, undefined, "source-root", string,
      "the directory whose layout yields namespaces"},
     {out_dir, undefined, "out-dir", string,
      "where the compiled tree goes; default: the source root"},
     {emit, undefined, "emit", string, "erl: write the module's Erlang source instead of .erc"},
     {no_clean, undefined, "no-clean", undefined,
      "keep stale .erc files under the build directory"},
     {doc, undefined, "doc", undefined, "write the doc comments of a file to stdout as Markdown"},
     {help, undefined, "help", undefined, "print this text"},
     {version, undefined, "version", undefined, "print the version"}].

-spec ernc([string()]) -> 0 | 1.
ernc(Args) ->
    tool(ernc, ernc_options(), "file.ern | src-dir", Args, fun ernc_main/2).

ernc_main(Opts, Rest) ->
    case {Rest, lists:member(doc, Opts)} of
        {[File], true} -> doc(File);
        {[Path], false} -> ernc_compile(Opts, Path);
        _ -> usage_fail("one file or directory argument is required")
    end.

ernc_compile(Opts, Path) ->
    Emit = case proplists:get_value(emit, Opts) of
               undefined -> erc;
               "erl" -> erl;
               Other -> usage_fail("unknown --emit kind " ++ Other ++ "; erl is the only kind")
           end,
    filelib:is_file(Path) orelse fail("no such file or directory " ++ Path),
    DirMode = filelib:is_dir(Path),
    Root = absolute(proplists:get_value(source_root, Opts,
                                        case DirMode of true -> Path; false -> "." end)),
    OutDir = absolute(proplists:get_value(out_dir, Opts, Root)),
    Files = case DirMode of
                true -> [filename:join(Path, F) || F <- filelib:wildcard("**/*.ern", Path)];
                false -> [Path]
            end,
    Modules = [module_of(absolute(F), Root) || F <- Files],
    try
        Order = compile_order(Modules, Root),
        lists:foldl(fun(M, Ifaces) -> build(M, Ifaces, OutDir, Emit) end, #{}, Order),
        case DirMode andalso Emit =:= erc andalso not lists:member(no_clean, Opts) of
            true -> sweep(absolute(Path), Root, OutDir);
            false -> ok
        end,
        0
    catch
        throw:{errors, File, Errors} ->
            lists:foreach(fun({L, C, Msg}) -> io:format(standard_error, "~s:~B:~B: ~s~n",
                                                        [File, L, C, Msg]) end, Errors),
            1
    end.

%% A source file as a module: its namespace from its path under the root,
%% with the path shape rule of §11.1.
-record(mod, {ns, file, rel, decls, deps = []}).

module_of(File, Root) ->
    Rel = relative(File, Root),
    Rel =/= outside orelse fail(File ++ " is not under the source root " ++ Root),
    filename:extension(Rel) =:= ".ern" orelse fail(Rel ++ " does not end in .ern"),
    Components = filename:split(filename:rootname(Rel)),
    lists:foreach(fun shape/1, Components),
    Ns = namespace(Components),
    %% report §4.2: a module namespace is never a prelude namespace
    case Ns of
        [Single] ->
            lists:member(Single, prelude_namespaces()) andalso
                fail(Rel ++ " takes the prelude namespace " ++ atom_to_list(Single));
        _ -> ok
    end,
    #mod{ns = Ns, file = File, rel = Rel}.

%% Report §11.1: each component is a lowercase letter, then lowercase
%% letters, digits, and underscores.
shape(Component) ->
    case re:run(Component, "^[a-z][a-z0-9_]*$") of
        {match, _} -> ok;
        nomatch ->
            case re:run(Component, "[A-Z]") of
                {match, _} -> fail("path component `" ++ Component ++ "` must be lowercase");
                nomatch -> fail("path component `" ++ Component
                                ++ "` must start with a lowercase letter")
            end
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
    Parsed = [parse_module(M, Root) || M <- Modules],
    G = digraph:new(),
    lists:foreach(fun(#mod{ns = Ns}) -> digraph:add_vertex(G, Ns) end, Parsed),
    lists:foreach(fun(#mod{ns = Ns, deps = Deps}) ->
                      lists:foreach(fun(D) ->
                                        digraph:add_vertex(G, D),
                                        digraph:add_edge(G, D, Ns)
                                    end, Deps)
                  end, Parsed),
    Order = case digraph_utils:topsort(G) of
                false ->
                    Cycle = hd([C || C <- digraph_utils:cyclic_strong_components(G)]),
                    Names = [qname(N) || N <- lists:sort(Cycle)],
                    fail("module cycle: " ++ lists:join(", ", Names));
                Sorted -> Sorted
            end,
    digraph:delete(G),
    ByNs = maps:from_list([{Ns, M} || #mod{ns = Ns} = M <- Parsed]),
    [maps:get(Ns, ByNs) || Ns <- Order, is_map_key(Ns, ByNs)].

parse_module(#mod{file = File} = M, Root) ->
    {ok, Bin} = file:read_file(File),
    case ern_parser:parse_string(Bin) of
        {ok, Decls} -> M#mod{decls = Decls, deps = deps(Decls, Root)};
        {error, E} -> throw({errors, File, [E]})
    end.

%% The modules a source refers to: every qualified name whose first
%% segment is neither a type of this module nor a prelude namespace, and
%% whose longest prefix names an existing .ern under the root.
deps(Decls, Root) ->
    Local = [N || #type_decl{name = N} <- Decls]
        ++ [N || #abstract_decl{type = #type_decl{name = N}} <- Decls]
        ++ [N || #foreign_type_decl{name = N} <- Decls],
    Skip = Local ++ prelude_namespaces(),
    Paths = lists:usort([P || P <- paths(Decls), P =/= [], not lists:member(hd(P), Skip)]),
    lists:usort(lists:filtermap(fun(P) -> module_prefix(P, Root) end, Paths)).

paths(#e_var{path = P}) -> [P];
paths(#e_con{path = P, args = A}) -> [P | paths(A)];
paths(#p_con{path = P, args = A}) -> [P | paths(A)];
paths(#t_con{path = P, args = A}) -> [P | paths(A)];
paths(T) when is_tuple(T) -> lists:append([paths(X) || X <- tuple_to_list(T)]);
paths(L) when is_list(L) -> lists:append([paths(X) || X <- L]);
paths(_) -> [].

module_prefix([], _Root) ->
    false;
module_prefix(Path, Root) ->
    case filelib:is_regular(filename:join(Root, module_path(Path) ++ ".ern")) of
        true -> {true, Path};
        false -> module_prefix(lists:droplast(Path), Root)
    end.

prelude_namespaces() ->
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    lists:usort([N || {N, _} <- ern_prelude:builtin_types()]
                ++ [N || #type_decl{name = N} <- Decls]
                ++ [hd(Q) || {Q, _} <- ern_prelude:values(), length(Q) > 1]).

%% Type-check and compile one module against its dependencies'
%% interfaces, unless its .erc is current (§11.1). Returns the interfaces
%% with this module's added.
build(#mod{ns = Ns, file = File, rel = Rel, decls = Decls, deps = Deps}, Ifaces, OutDir, Emit) ->
    DepIfaces = [dep_iface(D, Ifaces, OutDir) || D <- Deps],
    DepHashes = lists:sort([{D, ern_compiler:iface_hash(I)} || {D, I} <- DepIfaces]),
    {ok, Source} = file:read_file(File),
    SourceHash = crypto:hash(sha256, Source),
    Out = filename:join(OutDir, filename:rootname(Rel)),
    Erc = Out ++ ".erc",
    case Emit =:= erc andalso current(Erc, SourceHash, DepHashes) of
        {true, Iface} ->
            Ifaces#{Ns => Iface};
        false ->
            case ern_typecheck:check(Ns, Decls, [I || {_, I} <- DepIfaces]) of
                {ok, Typed, Iface, Env} ->
                    ok = filelib:ensure_dir(Erc),
                    case Emit of
                        erl ->
                            Src = ["%% Generated by ernc from ", Rel, "\n",
                                   ern_compiler:erl_source(Ns, Typed, Env)],
                            ok = file:write_file(Out ++ ".erl", Src);
                        erc ->
                            Build = #{source_hash => SourceHash, deps => DepHashes},
                            case ern_compiler:compile(Ns, Typed, Iface, Env, Build) of
                                {ok, _, Beam} -> ok = file:write_file(Erc, Beam);
                                {error, Errors} -> throw({errors, File, Errors})
                            end
                    end,
                    Ifaces#{Ns => Iface};
                {error, Errors} ->
                    throw({errors, File, Errors})
            end
    end.

dep_iface(D, Ifaces, OutDir) ->
    case Ifaces of
        #{D := I} -> {D, I};
        _ ->
            Erc = filename:join(OutDir, module_path(D) ++ ".erc"),
            case read_erc(Erc) of
                {ok, #{iface := I}} -> {D, I};
                {error, _} -> fail("compile " ++ qname(D) ++ " first: no " ++ Erc)
            end
    end.

current(Erc, SourceHash, DepHashes) ->
    case read_erc(Erc) of
        {ok, #{iface := Iface, source_hash := SourceHash, deps := Deps}} ->
            case lists:sort(Deps) =:= DepHashes of
                true -> {true, Iface};
                false -> false
            end;
        _ -> false
    end.

read_erc(Erc) ->
    case file:read_file(Erc) of
        {ok, Bin} -> ern_compiler:read_interface(Bin);
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

%% Report §11.4: doc comments as Markdown, grouped by declaration.
doc(File) ->
    {ok, Bin} = file:read_file(File),
    case ern_parser:parse_string(Bin) of
        {ok, Decls} ->
            lists:foreach(fun(D) ->
                              case doc_of(D) of
                                  undefined -> ok;
                                  Doc -> io:format("### ~s~n~n~s~n~n", [decl_name(D), Doc])
                              end
                          end, Decls),
            0;
        {error, {L, C, Msg}} ->
            io:format(standard_error, "~s:~B:~B: ~s~n", [File, L, C, Msg]),
            1
    end.

doc_of(#type_decl{doc = D}) -> D;
doc_of(#abstract_decl{doc = D}) -> D;
doc_of(#fn_decl{doc = D}) -> D;
doc_of(#let_decl{doc = D}) -> D;
doc_of(#foreign_type_decl{doc = D}) -> D;
doc_of(#foreign_fn_decl{doc = D}) -> D.

decl_name(#type_decl{name = N}) -> "type " ++ atom_to_list(N);
decl_name(#abstract_decl{type = #type_decl{name = N}}) -> "abstract type " ++ atom_to_list(N);
decl_name(#fn_decl{owner = O, name = N}) -> "fn " ++ owned(O, N);
decl_name(#let_decl{owner = O, name = N}) -> "let " ++ owned(O, N);
decl_name(#foreign_type_decl{name = N}) -> "foreign type " ++ atom_to_list(N);
decl_name(#foreign_fn_decl{owner = O, name = N}) -> "foreign fn " ++ owned(O, N).

owned(undefined, N) -> atom_to_list(N);
owned(O, N) -> atom_to_list(O) ++ "." ++ atom_to_list(N).

%%
%% ern, report §11.2 and §11.3
%%

ern_options() ->
    [{config_dir, undefined, "config-dir", string,
      "the configuration directory; default ./.ernest"},
     {load_path, undefined, "load-path", string, "a root of compiled modules; may be repeated"},
     {main, undefined, "main", string, "the entry point, a qualified exported function"},
     {shell, undefined, "shell", undefined, "add an interactive shell to the running program"},
     {create_config_dir, undefined, "create-config-dir", string,
      "create dir/.ernest with a configuration and a private key, and stop"},
     {help, undefined, "help", undefined, "print this text"},
     {version, undefined, "version", undefined, "print the version"}].

-spec ern([string()]) -> 0 | 1.
ern(Args) ->
    tool(ern, ern_options(), "file.erc", Args, fun ern_main/2).

ern_main(Opts, Rest) ->
    case {proplists:get_value(create_config_dir, Opts), lists:member(shell, Opts), Rest} of
        {Dir, _, []} when Dir =/= undefined -> create_config_dir(Dir);
        {undefined, true, _} -> fail("the shell is not in MVP 1");
        {undefined, false, [File]} -> run(Opts, File);
        _ -> usage_fail("one .erc file argument is required")
    end.

run(Opts, File) ->
    filelib:is_regular(File) orelse fail("no such file " ++ File),
    filename:extension(File) =:= ".erc" orelse fail(File ++ " does not end in .erc"),
    Abs = absolute(File),
    {ok, Bin} = file:read_file(Abs),
    Ns = case ern_compiler:read_interface(Bin) of
             {ok, #{iface := #iface{namespace = N}}} -> N;
             {error, Why} -> fail(File ++ ": " ++ Why)
         end,
    %% the root lies as many directories up as the namespace is deep
    Root = lists:foldl(fun(_, D) -> filename:dirname(D) end, Abs, Ns),
    relative(Abs, Root) =:= module_path(Ns) ++ ".erc" orelse
        fail(File ++ " is not at the path of its namespace " ++ qname(Ns)),
    lists:foreach(fun shape/1, filename:split(filename:rootname(module_path(Ns)))),
    Roots = [Root | [absolute(D) || {load_path, D} <- Opts]],
    Loaded = load(Ns, Roots, []),
    {EntryMod, EntryFn, Loaded1} =
        case proplists:get_value(main, Opts) of
            undefined -> {ern_compiler:module_atom(Ns), main, Loaded};
            Q ->
                Parts = [list_to_atom(P) || P <- string:split(Q, ".", all)],
                length(Parts) >= 2 orelse
                    usage_fail("--main takes a qualified name, Module.function"),
                MainNs = lists:droplast(Parts),
                {ern_compiler:module_atom(MainNs), lists:last(Parts), load(MainNs, Roots, Loaded)}
        end,
    erlang:function_exported(EntryMod, EntryFn, 0) orelse
        fail("no exported entry point " ++ atom_to_list(EntryFn) ++ " in "
             ++ qname(entry_ns(EntryMod)) ++ "; an entry point takes no arguments (report §8.1)"),
    %% report §8.5: every top-level let, dependencies first
    lists:foreach(fun(Mod) ->
                      erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'()
                  end, lists:reverse(Loaded1)),
    Site = unicode:characters_to_binary(qname(entry_ns(EntryMod)) ++ "." ++ atom_to_list(EntryFn)),
    case ern_rt:run_main(fun() -> EntryMod:EntryFn() end, Site) of
        ok -> 0;
        {fault, Msg} ->
            io:format(standard_error, "fault: ~s~n", [Msg]),
            1
    end.

entry_ns(Mod) ->
    "ernest@" ++ Path = atom_to_list(Mod),
    namespace(string:split(Path, "@", all)).

%% Load a module and, first, its dependencies, each once; the result lists
%% modules most recently loaded first, so dependencies come last.
load(Ns, Roots, Loaded) ->
    Mod = ern_compiler:module_atom(Ns),
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
            {ok, #{deps := Deps}} = ern_compiler:read_interface(Bin),
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

absolute(Path) ->
    filename:absname(Path).

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
