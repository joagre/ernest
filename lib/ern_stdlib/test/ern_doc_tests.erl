%% The documentation rules of report §2.2 and Appendix E.0 rule 6, checked
%% over every standard library module written in Ernest and over the
%% fictive module that docs/module_doc_template.md shows.
-module(ern_doc_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parser/include/ern_ast.hrl").
-include_lib("type_system/include/ern_types.hrl").

-define(ROOT, "../../..").

%% The modules checked: the template and every file under stdlib/.
modules() ->
    [{['Template'], filename:join(?ROOT, "examples/template.ern")}
     | [{[list_to_atom(string:titlecase(filename:basename(F, ".ern")))], F}
        || F <- filelib:wildcard(filename:join(?ROOT, "stdlib/*.ern"))]].

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
    Blocks = [split_result(B) || Doc <- docs(Decls, []), B <- fences(Doc)],
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
    Calls = [iolist_to_binary(["    let _ = Io.debug(", Q, ".docExample", integer_to_list(N),
                               "());\n"]) || {N, _, _} <- WithResult],
    Main = iolist_to_binary(["export fn docMain() -> Unit with Never = {\n", Calls,
                             "    Unit\n}\n"]),
    Text = iolist_to_binary([Src, "\n", Fns, Main]),
    {ok, Typed, Iface, Env} = ern_typecheck:check_string(Ns, Text),
    {ok, Mod, Bin} = ern_compiler:compile(Ns, Typed, Iface, Env),
    Original = code:which(Mod),
    {module, Mod} = code:load_binary(Mod, "doc examples", Bin),
    Me = self(),
    _ = collect([]),
    Init = fun() -> case erlang:function_exported(Mod, '$init', 0) of
                        true -> Mod:'$init'();
                        false -> ok
                    end
           end,
    Result = ern_rt:run_main(fun() -> Mod:docMain() end, <<"docMain">>,
                             #{init => Init, stdout => fun(B) -> Me ! {out, B} end}),
    restore(Mod, Original),
    ?assertEqual(ok, Result),
    Expected = iolist_to_binary([[V, "\n"] || {_, _, V} <- WithResult]),
    ?assertEqual(Expected, collect([])).

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

%% Appendix E.0 rule 6: the module's doc block and every exported
%% declaration's end with `since v`, v no newer than VERSION; a member of an
%% abstract type may leave its text to its signature entry, not its `since`
doc_since_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> since(File) end} || {Ns, File} <- modules()].

since(File) ->
    {ok, V} = file:read_file(filename:join(?ROOT, "VERSION")),
    Current = version(V),
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    Blocks = [T || #module_doc{text = T} <- Decls]
        ++ [doc_field(D) || D <- Decls, exported_decl(D)],
    ?assertNotEqual([], [T || #module_doc{text = T} <- Decls]),
    Missing = [B || B <- Blocks, B =:= undefined orelse since_of(B) =:= none],
    ?assertEqual([], Missing),
    ?assertEqual([], [S || B <- Blocks, S <- [since_of(B)], version(S) > Current]).

since_of(Doc) ->
    case re:run(Doc, "(?m)^since ([0-9][0-9.]*)\\s*$", [{capture, all_but_first, binary}]) of
        {match, [S]} -> S;
        nomatch -> none
    end.

version(Text) ->
    Trimmed = string:trim(unicode:characters_to_list(Text)),
    [list_to_integer(P) || P <- string:split(Trimmed, ".", all)].

%% Appendix E.0 rule 6: every backticked name under `See also` is a
%% declaration of the module, a prelude or standard library namespace, or a
%% prelude type
doc_see_also_test_() ->
    [{atom_to_list(hd(Ns)), fun() -> see_also(File) end} || {Ns, File} <- modules()].

see_also(File) ->
    {ok, Src} = file:read_file(File),
    {ok, Decls} = ern_parser:parse_string(Src),
    Known = lists:append([decl_names(D) || D <- Decls])
        ++ [atom_to_list(hd(Ns)) || {Ns, _} <- ern_prelude:stdlib_types()]
        ++ [atom_to_list(hd(Q)) || {Q, _} <- ern_prelude:values(), length(Q) > 1]
        ++ [atom_to_list(hd(I#iface.namespace)) || I <- ern_prelude:stdlib_ifaces()]
        ++ [atom_to_list(N) || {N, _} <- ern_prelude:builtin_types()],
    Named = [N || Doc <- docs(Decls, []),
                  {match, Secs} <- [re:run(Doc, "#+ See also\\n\\n(.*?)(?=\\n#|$)",
                                           [global, dotall, {capture, all_but_first, list}])],
                  [Sec] <- Secs,
                  {match, Ns} <- [re:run(Sec, "`([^`]+)`",
                                         [global, {capture, all_but_first, list}])],
                  [N] <- Ns],
    ?assertEqual([], [N || N <- Named, not lists:member(N, Known)]).

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

%% plan MVP 2.5 step 2: every value a compiled standard library interface
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
    list_to_atom("ernest@" ++ string:lowercase(lists:join("@", [atom_to_list(A) || A <- Ns]))).

arity(Scheme) ->
    case element(3, Scheme) of
        {tfn, Ps, _, _} -> length(Ps);
        _ -> 0
    end.
