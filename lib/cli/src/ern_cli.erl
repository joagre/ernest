%% The two programs of report §11: ernc (§11.1, §11.4) and ern (§11.2,
%% §11.3). The escripts under bin/ are thin; everything is here so that the
%% tests can call it. Each entry point returns the exit status.
-module(ern_cli).

-export([main/2, ernc/1, ernc/2, ern/1, ern/2, namespace/1, module_path/1]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").

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
            io:format(Err, "~s: ~s~n", [Tool, Msg]),
            usage(Spec, Tool, Positional, Err),
            1;
        throw:{cli_error, Msg} ->
            io:format(Err, "~s: ~s~n", [Tool, Msg]),
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
        throw:{errors, File, Errors} -> report_errors(Opts, File, Errors, Err)
    end.

%% Report §11.5: each error as ern_diag renders it, the first line alone
%% under --errors short; status 1.
report_errors(Opts, File, Errors, Err) ->
    Short = proplists:get_value(errors, Opts) =:= "short",
    Source = case file:read_file(File) of
                 {ok, Bin} -> Bin;
                 _ -> <<>>
             end,
    lists:foreach(fun(D) ->
                      Text = case Short of
                                 true -> ern_diag:short(File, D);
                                 false -> ern_diag:format(File, Source, D)
                             end,
                      io:format(Err, "~s~n", [Text])
                  end, Errors),
    1.

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
    %% report §4.2: a module namespace is never a prelude namespace, except
    %% in the standard library's own source root
    case Ns of
        [Single] ->
            not is_stdlib_root(Root) andalso lists:member(Single, prelude_namespaces()) andalso
                fail(Rel ++ " takes the prelude namespace " ++ atom_to_list(Single));
        _ -> ok
    end,
    #mod{ns = Ns, file = File, rel = Rel}.

%% Report §11.1: each component is one word, a lowercase letter, then
%% lowercase letters and digits.
shape(Component) ->
    case re:run(Component, "^[a-z][a-z0-9]*$") of
        {match, _} -> ok;
        nomatch ->
            case re:run(Component, "[A-Z]") of
                {match, _} -> fail("path component `" ++ Component ++ "` must be lowercase");
                nomatch -> fail("path component `" ++ Component ++ "` must be one word: a"
                                " lowercase letter, then lowercase letters and digits;"
                                " a multi-word module is a directory")
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
        {ok, Decls} ->
            namespace_clash(M#mod{decls = Decls}, Root),
            %% a module naming itself qualified (report §4.2) depends on nothing by it
            M#mod{decls = Decls, deps = deps(Decls, Root) -- [M#mod.ns]};
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
deps(Decls, Root) ->
    %% in the standard library's root its own namespaces are dependencies
    Skip = case is_stdlib_root(Root) of
               true -> local_types(Decls);
               false -> local_types(Decls) ++ prelude_namespaces()
           end,
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

%% Report §4.2: the standard library's source root, `stdlib/` beside the
%% toolchain's `lib/`, found from where this module was loaded.
is_stdlib_root(Root) ->
    Here = absolute(code:which(?MODULE)),
    Repo = filename:dirname(filename:dirname(filename:dirname(filename:dirname(Here)))),
    absolute(Root) =:= absolute(filename:join(Repo, "stdlib")).

prelude_namespaces() ->
    {ok, Decls} = ern_parser:parse_string(ern_prelude:declared_types()),
    lists:usort([N || {N, _} <- ern_prelude:builtin_types()]
                ++ [N || #type_decl{name = N} <- Decls]
                ++ [hd(Ns) || {Ns, _} <- ern_prelude:stdlib_types()]
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
                            Build = #{source_hash => SourceHash, deps => DepHashes,
                                      compiler => list_to_binary(?VERSION)},
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
                {error, Why} -> fail("compile " ++ qname(D) ++ " first: " ++ Erc ++ ": " ++ Why)
            end
    end.

%% Report §11.1: current when the source, every dependency's interface, and
%% the compiler's version are those the .erc was built from.
current(Erc, SourceHash, DepHashes) ->
    Version = list_to_binary(?VERSION),
    case read_erc(Erc) of
        {ok, #{iface := Iface, source_hash := SourceHash, deps := Deps, compiler := Version}} ->
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
            Root = absolute(proplists:get_value(source_root, Opts, ".")),
            OutDir = absolute(proplists:get_value(out_dir, Opts, Root)),
            try
                Mod = module_of(absolute(Path), Root),
                [Parsed] = compile_order([Mod], Root),
                io:put_chars(doc_text(Parsed, OutDir)),
                0
            catch
                throw:{errors, F, Errors} -> report_errors(Opts, F, Errors, Err)
            end
    end.

doc_dir(Opts, Path) ->
    Root = absolute(proplists:get_value(source_root, Opts, Path)),
    OutDir = absolute(proplists:get_value(out_dir, Opts, Root)),
    Files = [filename:join(Path, F) || F <- filelib:wildcard("**/*.ern", Path)],
    Mods = compile_order([module_of(absolute(F), Root) || F <- Files], Root),
    Entries = [begin
                   Rel = module_path(Ns) ++ ".md",
                   Out = filename:join(OutDir, Rel),
                   ok = filelib:ensure_dir(Out),
                   ok = file:write_file(Out, unicode:characters_to_binary(doc_text(M, OutDir))),
                   ["- [", qname(Ns), "](", Rel, ")\n"]
               end || #mod{ns = Ns} = M <- lists:sort(Mods)],
    ok = file:write_file(filename:join(OutDir, "index.md"),
                         unicode:characters_to_binary(["# Modules\n\n", Entries])),
    0.

%% The document of one parsed module: type-checked as for a compilation.
doc_text(#mod{ns = Ns, file = File, decls = Decls, deps = Deps}, OutDir) ->
    DepIfaces = [I || D <- Deps, {_, I} <- [dep_iface(D, #{}, OutDir)]],
    case ern_typecheck:check(Ns, Decls, DepIfaces) of
        {ok, Typed, _, Env} ->
            ModDoc = case [T || #module_doc{text = T} <- Typed] of
                         [T | _] ->
                             {Text, Since} = split_since(T),
                             [since_line(Since), Text, "\n\n"];
                         [] -> []
                     end,
            %% a member of an abstract type is documented at its signature
            %% entry (Appendix E.0 rule 6)
            Entries = maps:from_list([{{TName, N}, Doc}
                                      || #abstract_decl{type = #type_decl{name = TName},
                                                        signatures = Sigs} <- Typed,
                                         #signature{name = N, doc = Doc} <- Sigs,
                                         Doc =/= undefined]),
            ["# Ernest module ", qname(Ns), "\n\n", ModDoc,
             [doc_decl(D, Entries, Env) || D <- Typed, documented(D)],
             "---\n\nGenerated by ernc ", ?VERSION, " from ", filename:basename(File), ".\n"];
        {error, Errors} ->
            throw({errors, File, Errors})
    end.

documented(#module_doc{}) -> false;
documented(D) -> exported(D) orelse doc_of(D) =/= undefined.

doc_decl(D, Entries, Env) ->
    {Own, Since} = case doc_of(D) of
                       undefined -> {undefined, undefined};
                       OwnDoc -> split_since(OwnDoc)
                   end,
    %% a member whose own block is only its `since` line inherits the entry's text
    Text = case Own of
               T when T =:= undefined; T =:= <<>> -> maps:get(member_key(D), Entries, undefined);
               _ -> Own
           end,
    ["## ", heading(D), "\n\n```ernest\n", signature(D, Env), "\n```\n\n", since_line(Since),
     case Text of
         undefined -> [];
         _ -> [Text, "\n\n"]
     end,
     items(D)].

%% Appendix E.0 rule 6: a doc block's last line `since v` names the version
%% the declaration appeared in; it is rendered after the synopsis.
split_since(Doc) ->
    case re:run(Doc, "^(.*?)\\n?since ([0-9][0-9A-Za-z.+-]*)\\s*$",
                [dotall, {capture, all_but_first, binary}]) of
        {match, [Text, V]} -> {string:trim(Text, trailing), V};
        nomatch -> {Doc, undefined}
    end.

since_line(undefined) -> [];
since_line(V) -> ["*Since ", V, ".*\n\n"].

member_key(#fn_decl{owner = O, name = N}) -> {O, N};
member_key(#let_decl{owner = O, name = N}) -> {O, N};
member_key(#foreign_fn_decl{owner = O, name = N}) -> {O, N};
member_key(_) -> none.

%% The documented constructors, fields, and signature entries as a list.
items(#type_decl{constructors = Cs}) ->
    list([begin
              FieldItems = [["  - `", atom_to_list(F), " : ", syn(T), "`: ", FDoc, "\n"]
                            || #field{doc = FDoc, name = F, type = T} <- named_fields(Fields),
                               FDoc =/= undefined],
              case {Doc, FieldItems} of
                  {undefined, []} -> [];
                  {undefined, _} -> [["- `", atom_to_list(N), "`\n"], FieldItems];
                  _ -> [["- `", atom_to_list(N), "`: ", Doc, "\n"], FieldItems]
              end
          end || #constructor{doc = Doc, name = N, fields = Fields} <- Cs]);
items(#abstract_decl{signatures = Sigs}) ->
    list([["- `", atom_to_list(N), " : ", syn(T), "`: ", Doc, "\n"]
          || #signature{doc = Doc, name = N, type = T} <- Sigs, Doc =/= undefined]);
items(_) ->
    [].

named_fields({named, Fs}) -> Fs;
named_fields(_) -> [].

list(Items) ->
    case lists:flatten(Items) of
        [] -> [];
        _ -> [Items, "\n"]
    end.

heading(#type_decl{name = N}) -> atom_to_list(N);
heading(#abstract_decl{type = #type_decl{name = N}}) -> atom_to_list(N);
heading(#fn_decl{owner = O, name = N}) -> owned(O, N);
heading(#let_decl{owner = O, name = N}) -> owned(O, N);
heading(#foreign_type_decl{name = N}) -> atom_to_list(N);
heading(#foreign_fn_decl{owner = O, name = N}) -> owned(O, N).

exported(#type_decl{export = E}) -> E;
exported(#abstract_decl{export = E}) -> E;
exported(#fn_decl{export = E}) -> E;
exported(#let_decl{export = E}) -> E;
exported(#foreign_type_decl{export = E}) -> E;
exported(#foreign_fn_decl{export = E}) -> E.

doc_of(#type_decl{doc = D}) -> D;
doc_of(#abstract_decl{doc = D}) -> D;
doc_of(#fn_decl{doc = D}) -> D;
doc_of(#let_decl{doc = D}) -> D;
doc_of(#foreign_type_decl{doc = D}) -> D;
doc_of(#foreign_fn_decl{doc = D}) -> D.

owned(undefined, N) -> atom_to_list(N);
owned(O, N) -> atom_to_list(O) ++ "." ++ atom_to_list(N).

%% The declaration's type: inferred schemes for fn and let, the
%% declaration itself for the type forms, an abstract type without its
%% representation.
signature(#fn_decl{owner = O, name = N, type = Scheme}, Env) ->
    code([owned(O, N), " : ", ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#let_decl{owner = O, name = N, type = Scheme}, Env) ->
    code([owned(O, N), " : ", ern_types:format_scheme(Scheme, ern_typecheck:type_state(Env))]);
signature(#foreign_fn_decl{owner = O, name = N, params = Ps, ret = R, effect = E}, _) ->
    code([owned(O, N), " : ", syn(#t_fn{params = [T || #param{type = T} <- Ps], ret = R,
                                        effect = E})]);
signature(#type_decl{} = D, _) ->
    code(type_text(D));
signature(#abstract_decl{type = #type_decl{name = TName, params = Ps}, signatures = Sigs}, _) ->
    code([["abstract type ", atom_to_list(TName), params_text(Ps), " with {\n"],
          lists:join(";\n", [["    ", atom_to_list(N), " : ", syn(T)]
                              || #signature{name = N, type = T} <- Sigs]),
          "\n}"]);
signature(#foreign_type_decl{name = N, params = Ps}, _) ->
    code(["foreign type ", atom_to_list(N), params_text(Ps)]).

type_text(#type_decl{name = N, params = Ps, constructors = Cs}) ->
    ["type ", atom_to_list(N), params_text(Ps), " = ",
     lists:join(" | ", [constructor_text(C) || C <- Cs])].

params_text([]) -> "";
params_text(Ps) -> ["(", lists:join(", ", [atom_to_list(P) || P <- Ps]), ")"].

constructor_text(#constructor{name = N, fields = none}) ->
    atom_to_list(N);
constructor_text(#constructor{name = N, fields = {positional, T}}) ->
    [atom_to_list(N), "(", syn(T), ")"];
constructor_text(#constructor{name = N, fields = {named, Fs}}) ->
    [atom_to_list(N), "(",
     lists:join(", ", [[atom_to_list(F), " : ", syn(T)] || #field{name = F, type = T} <- Fs]),
     ")"].

%% A syntactic type as written.
syn(#t_con{path = P, name = N, args = []}) -> qname(P ++ [N]);
syn(#t_con{path = P, name = N, args = As}) ->
    [qname(P ++ [N]), "(", lists:join(", ", [syn(A) || A <- As]), ")"];
syn(#t_var{name = N}) -> atom_to_list(N);
syn(#t_tuple{elems = Es}) -> ["#(", lists:join(", ", [syn(E) || E <- Es]), ")"];
syn(#t_fn{params = Ps, ret = R, effect = E}) ->
    ["(", lists:join(", ", [syn(P) || P <- Ps]), ") -> ", syn(R),
     case E of undefined -> ""; _ -> [" with ", syn(E)] end].

code(Text) ->
    unicode:characters_to_list(Text).

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
    ern(Args, standard_error).

-spec ern([string()], io:device()) -> 0 | 1.
ern(Args, Err) ->
    tool(ern, ern_options(), "file.erc", Args, fun ern_main/3, Err).

ern_main(Opts, Rest, Err) ->
    case {proplists:get_value(create_config_dir, Opts), lists:member(shell, Opts), Rest} of
        {Dir, _, []} when Dir =/= undefined -> create_config_dir(Dir);
        {undefined, true, _} -> fail("the shell is not in MVP 1");
        {undefined, false, [File]} -> run(Opts, File, Err);
        _ -> usage_fail("one .erc file argument is required")
    end.

run(Opts, File, Err) ->
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
    %% report §8.5: every top-level let, dependencies first, once the
    %% runtime has bound the Sys.* references
    Init = fun() ->
               lists:foreach(fun(Mod) ->
                                 erlang:function_exported(Mod, '$init', 0) andalso Mod:'$init'()
                             end, lists:reverse(Loaded1))
           end,
    Site = unicode:characters_to_binary(qname(entry_ns(EntryMod)) ++ "." ++ atom_to_list(EntryFn)),
    case ern_rt:run_main(fun() -> EntryMod:EntryFn() end, Site, #{init => Init}) of
        ok -> 0;
        {fault, Msg} ->
            io:format(Err, "fault: ~s~n", [Msg]),
            1;
        deadlock ->
            %% report §8.6
            io:format(Err, "error: Deadlock~n", []),
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
