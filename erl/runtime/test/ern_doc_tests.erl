%% The documentation rules of report §2.2 and Appendix E.0 rule 6, checked
%% over every standard library module written in Ernest, every library
%% under libs/, which keeps the standard library's discipline (plan, MVP
%% 2.7), and the fictive module that docs/module_doc_template.md shows.
-module(ern_doc_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").

-define(ROOT, "../../..").

%% The modules checked: the template, every file under stdlib/, and every
%% library's top module under libs/.
modules() ->
    [{['Template'], filename:join(?ROOT, "examples/template.ern")}
     | [{[list_to_atom(string:titlecase(filename:basename(F, ".ern")))], F}
        || F <- filelib:wildcard(filename:join(?ROOT, "stdlib/*.ern"))
               ++ filelib:wildcard(filename:join(?ROOT, "libs/*/*.ern"))]].

%% Appendix E.0 rule 6: the standard library is checked, not only the template
stdlib_present_test() ->
    ?assert(length(modules()) >= 2).

%% report §2.2, Appendix E.0 rule 6: every fenced Ernest block in a module's
%% doc blocks type-checks against the module as the body of a lambda, and
%% one that ends in `// => v` is run and its Io.debug rendering compared
%% with v, so an example cannot rot
doc_examples_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> examples(Ns, File) end} || {Ns, File} <- modules()].

examples(Ns, File) ->
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    check_examples(Ns, Src, docs(Decls, [])).

%% report §9, Appendix E.0 rule 6: the prelude's page is documented as a
%% module's is, so its examples type-check and those with `// => v` run,
%% and every function it documents is called by one of them
prelude_examples_test_() ->
    {timeout, 60, fun() -> check_examples(['Docprelude'], <<>>, prelude_docs()) end}.

prelude_called_test() ->
    Fences = iolist_to_binary([B || Doc <- prelude_docs(), B <- fences(Doc)]),
    Functions = [lists:join(".", [atom_to_list(A) || A <- Q])
                 || {Q, T, D} <- ern_prelude:values(), is_binary(D), hd(Q) =/= 'Sys',
                    lists:prefix("(", T)],
    Uncalled = [F || F <- Functions, binary:match(Fences, list_to_binary([F, "("])) =:= nomatch],
    ?assertEqual([], Uncalled).

prelude_docs() ->
    {docs_v1, _, _, _, #{<<"en">> := Mod}, _, Entries} = ern_prelude:docs(),
    [Mod | [D || {_, _, _, #{<<"en">> := D}, _} <- Entries]].

check_examples(Ns, Src, Docs) ->
    Blocks = [split_result(B) || Doc <- Docs, B <- fences(Doc)],
    ?assert(Blocks =/= []),
    Numbered = lists:zip(lists:seq(1, length(Blocks)), Blocks),
    lists:foreach(fun({N, {Body, _}}) ->
                      Text = <<Src/binary, "\nfn docExample", (integer_to_binary(N))/binary,
                               "() = fn() = {\n", Body/binary, "\n}\n">>,
                      ?assertMatch({ok, _, _, _}, ern_typecheck:check_string(Ns, Text))
                  end, Numbered),
    WithResult = [{N, Body, V} || {N, {Body, V}} <- Numbered, V =/= none],
    Fns = [<<"export fn docExample", (integer_to_binary(N))/binary, "() = {\n", Body/binary,
             "\n}\n">> || {N, Body, _} <- WithResult],
    Q = lists:join(".", [atom_to_list(A) || A <- Ns]),
    Mains = [iolist_to_binary(["export fn docMain", integer_to_list(N),
                               "() -> Unit with Never = {\n    let _ = Io.debug(", Q,
                               ".docExample", integer_to_list(N), "());\n    Unit\n}\n"])
             || {N, _, _} <- WithResult],
    Text = iolist_to_binary([Src, "\n", Fns, Mains]),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Text),
    {ok, Mod, Bin} = ern_emitter:compile(Ns, Typed, Iface, Env),
    Original = code:which(Mod),
    {module, Mod} = code:load_binary(Mod, "doc examples", Bin),
    try
        %% Appendix E.0 rule 6: each example runs on its own, and the value
        %% it ends with is the last line it prints; what it prints itself,
        %% as an example of `foreach` does, comes before and is not compared
        lists:foreach(fun({N, _, V}) -> run_example(Mod, N, V) end, WithResult)
    after
        restore(Mod, Original)
    end.

run_example(Mod, N, Expected) ->
    %% Appendix E.0 rule 6: an example may touch the file system, so each
    %% runs in a directory of its own, removed afterwards
    {ok, Cwd} = file:get_cwd(),
    Dir = filename:join(["/tmp", "ern_doc_" ++ integer_to_list(erlang:unique_integer([positive]))]),
    ok = filelib:ensure_path(Dir),
    ok = file:set_cwd(Dir),
    try
        run_example(Mod, N, Expected, Cwd)
    after
        file:set_cwd(Cwd),
        file:del_dir_r(Dir)
    end.

run_example(Mod, N, Expected, _Cwd) ->
    Main = list_to_atom("docMain" ++ integer_to_list(N)),
    Me = self(),
    _ = collect([]),
    Init = fun() -> case erlang:function_exported(Mod, '$init', 0) of
                        true -> Mod:'$init'();
                        false -> ok
                    end
           end,
    %% the value goes to stdout, what the example prints itself may go to
    %% either sink, and the two are separate processes, so only stdout's
    %% last line is the value
    Result = ern_rt:run_main(fun() -> Mod:Main() end, atom_to_binary(Main),
                             #{init => Init, stdout => fun(B) -> Me ! {out, B} end,
                               stderr => fun(B) -> Me ! {err, B} end}),
    ?assertEqual(ok, Result),
    Lines = binary:split(collect([]), <<"\n">>, [global, trim]),
    _ = collect(err, []),
    ?assertEqual(iolist_to_binary(Expected), lists:last(Lines)).

collect(Tag, Acc) ->
    receive {Tag, Bin} -> collect(Tag, [Bin | Acc])
    after 0 -> lists:reverse(Acc)
    end.

%% A standard library module's own beam comes back after its examples ran.
restore(Mod, Original) when is_list(Original) ->
    code:purge(Mod),
    {module, Mod} = code:load_abs(filename:rootname(Original)),
    code:purge(Mod);
restore(Mod, _) ->
    code:purge(Mod),
    code:delete(Mod),
    code:purge(Mod).

collect(Acc) ->
    receive
        {out, B} -> collect([B | Acc])
    after 0 ->
        iolist_to_binary(lists:reverse(Acc))
    end.

%% An example's body and the value its last line `// => v` promises, or none.
split_result(Block) ->
    Lines = binary:split(Block, <<"\n">>, [global]),
    case lists:last(Lines) of
        <<"// => ", V/binary>> ->
            {iolist_to_binary(lists:join(<<"\n">>, lists:droplast(Lines))), V};
        _ -> {Block, none}
    end.

%% Appendix E.0 rule 6: the module's doc block ends with `since v`; a
%% declaration may state its own; every one is no newer than VERSION
doc_since_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> since(File) end} || {Ns, File} <- modules()].

since(File) ->
    {ok, V} = file:read_file(filename:join(?ROOT, "VERSION")),
    Current = version(V),
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    ModDocs = [T || #module_doc{text = T} <- Decls],
    ?assertMatch([_], ModDocs),
    ?assertNotEqual(none, since_of(hd(ModDocs))),
    Stated = [S || B <- docs(Decls, []), S <- [since_of(B)], S =/= none],
    ?assertEqual([], [S || S <- Stated, version(S) > Current]).

since_of(Doc) ->
    case re:run(Doc, "(?m)^since ([0-9][0-9.]*)\\s*$", [{capture, all_but_first, binary}]) of
        {match, [S]} -> S;
        nomatch -> none
    end.

version(Text) ->
    Trimmed = string:trim(unicode:characters_to_list(Text)),
    [list_to_integer(P) || P <- string:split(Trimmed, ".", all)].

%% Appendix E.0 rule 6: every exported declaration has a doc block, a
%% member of an abstract type at its signature entry if not its own
doc_exported_documented_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> documented(File) end} || {Ns, File} <- modules()].

documented(File) ->
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    Entries = [{T, N} || #abstract_decl{type = #type_decl{name = T}, signatures = Sigs} <- Decls,
                         #signature{name = N, doc = Doc} <- Sigs, Doc =/= undefined],
    ?assertEqual([], [decl_names(D) || D <- Decls, exported_decl(D), doc_field(D) =:= undefined,
                                       not lists:member(member_of(D), Entries)]).

member_of(#fn_decl{owner = O, name = N}) -> {O, N};
member_of(#let_decl{owner = O, name = N}) -> {O, N};
member_of(_) -> none.

%% Appendix E.0 rule 6: every exported function is called by an example on
%% the page, the module's or its own; an operator member, used infix, is
%% not a call and is not looked for
doc_coverage_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> coverage(Ns, File) end} || {Ns, File} <- modules()].

coverage(Ns, File) ->
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    Examples = iolist_to_binary([B || Doc <- docs(Decls, []), B <- fences(Doc)]),
    Prefix = lists:join(".", [atom_to_list(A) || A <- Ns]),
    Fns = [owned_name(O, N) || #fn_decl{export = true, owner = O, name = N} <- Decls,
                               is_alpha(N)]
        ++ [owned_name(O, N) || #foreign_fn_decl{export = true, owner = O, name = N} <- Decls,
                                is_alpha(N)],
    ?assertNotEqual([], Fns),
    Uncalled = [F || F <- Fns,
                     binary:match(Examples, iolist_to_binary([Prefix, ".", F, "("])) =:= nomatch],
    ?assertEqual([], Uncalled).

is_alpha(N) ->
    [C | _] = atom_to_list(N),
    C >= $a andalso C =< $z.

%% Appendix E.0 rule 6: every backticked name under `See also` is a
%% declaration of the module, a prelude or standard library namespace or
%% value, or a prelude type
doc_see_also_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> see_also(File) end} || {Ns, File} <- modules()].

see_also(File) ->
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    Known = lists:append([decl_names(D) || D <- Decls])
        ++ [atom_to_list(hd(Q)) || {Q, _, _} <- ern_prelude:values(), length(Q) > 1]
        ++ [atom_to_list(hd(I#iface.namespace)) || I <- ern_prelude:stdlib_ifaces()]
        ++ [atom_to_list(N) || {N, _, _} <- ern_prelude:builtin_types()]
        ++ [qualified(Q) || {Q, _, _} <- ern_prelude:values()]
        ++ [qualified(Q) || I <- ern_prelude:stdlib_ifaces(), Q <- maps:keys(element(4, I))],
    Named = [N || Doc <- docs(Decls, []),
                  {match, Secs} <- [re:run(Doc, "#+ See also\\n\\n(.*?)(?=\\n#|$)",
                                           [global, dotall, {capture, all_but_first, list}])],
                  [Sec] <- Secs,
                  {match, Ns} <- [re:run(Sec, "`([^`]+)`",
                                         [global, {capture, all_but_first, list}])],
                  [N] <- Ns],
    ?assertEqual([], [N || N <- Named, not lists:member(N, Known)]).

qualified(Q) -> lists:flatten(lists:join(".", [atom_to_list(A) || A <- Q])).

decl_names(#type_decl{name = N}) -> [atom_to_list(N)];
decl_names(#abstract_decl{type = #type_decl{name = N}}) -> [atom_to_list(N)];
decl_names(#fn_decl{owner = O, name = N}) -> [owned_name(O, N)];
decl_names(#let_decl{owner = O, name = N}) -> [owned_name(O, N)];
decl_names(#foreign_fn_decl{owner = O, name = N}) -> [owned_name(O, N)];
decl_names(#foreign_type_decl{name = N}) -> [atom_to_list(N)];
decl_names(_) -> [].

owned_name(undefined, N) -> atom_to_list(N);
owned_name(O, N) -> atom_to_list(O) ++ "." ++ atom_to_list(N).

exported_decl(D) when is_tuple(D), tuple_size(D) >= 4, element(1, D) =/= module_doc ->
    element(4, D) =:= true;
exported_decl(_) -> false.

doc_field(D) -> element(3, D).

%% Every doc text in an AST: the third element of the records that carry one.
docs(T, Acc) when is_tuple(T), tuple_size(T) >= 3 ->
    Acc1 = case lists:member(element(1, T), [module_doc, type_decl, abstract_decl, fn_decl,
                                              let_decl, foreign_type_decl, foreign_fn_decl,
                                              constructor, field, signature])
                    andalso is_binary(element(3, T)) of
               true -> [element(3, T) | Acc];
               false -> Acc
           end,
    lists:foldl(fun docs/2, Acc1, tuple_to_list(T));
docs(L, Acc) when is_list(L) -> lists:foldl(fun docs/2, Acc, L);
docs(_, Acc) -> Acc.

fences(Doc) ->
    case re:run(Doc, "```ernest\\n(.*?)\\n```",
                [global, dotall, {capture, all_but_first, binary}]) of
        {match, Ms} -> [B || [B] <- Ms];
        nomatch -> []
    end.

%% plan MVP 2.5: every value a compiled standard library interface
%% declares is exported by its module with the arity of its type
stdlib_targets_test() ->
    Missing = [{Q, Ar} || #iface{namespace = Ns, values = Vs} <- ern_prelude:stdlib_ifaces(),
                          {Q, Scheme} <- maps:to_list(Vs),
                          Ar <- [arity(Scheme)],
                          Mod <- [module_atom(Ns)],
                          code:ensure_loaded(Mod) =/= {module, Mod}
                              orelse not erlang:function_exported(Mod, lists:last(Q), Ar)],
    ?assertEqual([], Missing),
    ?assertNotEqual([], ern_prelude:stdlib_ifaces()).

module_atom(Ns) ->
    list_to_atom("ern@" ++ string:lowercase(lists:join("@", [atom_to_list(A) || A <- Ns]))).

arity(Scheme) ->
    case element(3, Scheme) of
        {tfn, Ps, _, _} -> length(Ps);
        _ -> 0
    end.
