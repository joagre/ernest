#!/usr/bin/env escript
%% -*- erlang -*-
%% make calls (docs/coherence.md C13): Erlang's xref over the toolchain
%% and its tests, and over the Erlang the compiler writes for the standard
%% library, the shell, the libraries and the examples, whose .erc files,
%% compiled into build/calls, are read under their module's names, since
%% xref reads only a .beam. It prints every call to a function that is not
%% defined, every call to one that is deprecated, and every export of the
%% toolchain's own modules that nothing calls, and fails where there is
%% one. A call xref cannot see is counted: the target of every `foreign
%% fn`, read from the Ernest sources by Ernest's parser, since the foreign
%% boundary calls it by its name; every call the emitter writes into a
%% compiled module, read from the emitter's source, since a construct no
%% program of the repository uses is compiled in no module here; the
%% callbacks of a module's behaviours, which OTP calls, and of a module
%% that makes itself a process's error handler, which the host calls; and
%% the entry bin/ern starts the host with. The vendored getopt is read,
%% and its exports are its own.

-include("../erl/parser/include/ern_ast.hrl").

main([]) ->
    code:add_pathsa(filelib:wildcard("erl/*/ebin")),
    Tool = [F || F <- filelib:wildcard("erl/*/ebin/*.beam"), not lists:suffix("_tests.beam", F)],
    Tests = filelib:wildcard("erl/*/ebin/*_tests.beam"),
    Compiled = filelib:wildcard("build/stdlib/ern@*.beam")
        ++ [F || F <- filelib:wildcard("build/shell/ern@*.beam"),
                 filename:basename(F) =/= "ern@markdown.beam"]
        ++ as_beams(filelib:wildcard("build/libs/**/*.erc")
                    ++ filelib:wildcard("build/calls/**/*.erc")),
    {ok, _} = xref:start(s),
    ok = xref:set_default(s, [{warnings, false}, {verbose, false}]),
    ok = xref:set_library_path(s, code:get_path()),
    [{ok, _} = xref:add_module(s, F) || F <- Tool ++ Tests ++ Compiled],
    Own = [M || F <- Tool, M <- [list_to_atom(filename:basename(F, ".beam"))],
                lists:prefix("ern_", atom_to_list(M))],
    Called = foreign_targets() ++ emitted() ++ callbacks(Own) ++ error_handlers(Own)
        ++ entry(),
    {ok, Undefined} = xref:analyze(s, undefined_function_calls),
    {ok, Deprecated} = xref:analyze(s, deprecated_function_calls),
    {ok, Exports} = xref:analyze(s, exports_not_used),
    Unused = [MFA || {M, _, _} = MFA <- Exports, lists:member(M, Own),
                     not lists:member(MFA, Called)],
    report("a call to a function that is not defined", [Call || {_, Call} <- Undefined]),
    report("a call to a deprecated function", [Call || {_, Call} <- Deprecated]),
    report("an export nothing calls", Unused),
    case Undefined ++ Deprecated ++ Unused of
        [] -> ok;
        _ -> halt(1)
    end.

%% Each compiled module under its module's name, in build/calls/beams.
as_beams(Ercs) ->
    Dir = "build/calls/beams",
    ok = filelib:ensure_path(Dir),
    lists:usort([begin
                     {ok, Beam} = file:read_file(Erc),
                     {module, M} = lists:keyfind(module, 1, beam_lib:info(Beam)),
                     Out = filename:join(Dir, atom_to_list(M) ++ ".beam"),
                     ok = file:write_file(Out, Beam),
                     Out
                 end || Erc <- Ercs]).

%% Every `foreign fn`'s target, "module:function/arity", in the Ernest the
%% repository ships and its examples.
foreign_targets() ->
    Sources = lists:append([filelib:wildcard(P) || P <- ["stdlib/*.ern", "shell/**/*.ern",
                                                          "libs/**/*.ern", "examples/**/*.ern",
                                                          "tools/*.ern"]]),
    lists:append([targets(S) || S <- Sources, not lists:member($#, filename:basename(S))]).

targets(Source) ->
    {ok, Text} = file:read_file(Source),
    {ok, Decls} = ern_parser:parse_string(Text),
    [target(Impl) || #foreign_fn_decl{impl = Impl} <- Decls].

target(Impl) ->
    [M, FA] = string:split(unicode:characters_to_list(Impl), ":"),
    [F, A] = string:split(FA, "/"),
    {list_to_atom(M), list_to_atom(F), list_to_integer(A)}.

%% The calls the emitter writes, `call_remote(M, F, [A, ...])` and
%% `remote_fun(M, F, N)`, where the module is named: with the function
%% named too, that function, and with the function a variable, every
%% export of the module with as many arguments. One whose arguments are
%% not written out is left to the modules compiled here.
emitted() ->
    {ok, Text} = file:read_file("erl/emitter/src/ern_emitter.erl"),
    {ok, Tokens, _} = erl_scan:string(unicode:characters_to_list(Text)),
    emitted(Tokens).

emitted([{atom, _, call_remote}, {'(', _}, {atom, _, M}, {',', _}, Fun, {',', _}, {'[', _}
         | Rest]) ->
    named(M, Fun, elements(Rest)) ++ emitted(Rest);
emitted([{atom, _, remote_fun}, {'(', _}, {atom, _, M}, {',', _}, Fun, {',', _},
         {integer, _, N}, {')', _} | Rest]) ->
    named(M, Fun, N) ++ emitted(Rest);
emitted([_ | Rest]) ->
    emitted(Rest);
emitted([]) ->
    [].

named(M, {atom, _, F}, N) -> [{M, F, N}];
named(M, {var, _, _}, N) -> [{M, F, N} || {F, A} <- M:module_info(exports), A =:= N].

%% The elements of a list up to its closing bracket: none where it closes
%% at once, and otherwise one more than the commas outside any bracket in
%% it.
elements([{']', _} | _]) -> 0;
elements(Tokens) -> commas(Tokens, 0, 0) + 1.

commas([{']', _} | _], 0, N) -> N;
commas([{',', _} | Rest], 0, N) -> commas(Rest, 0, N + 1);
commas([{T, _} | Rest], D, N) when T =:= '('; T =:= '['; T =:= '{'; T =:= '<<' ->
    commas(Rest, D + 1, N);
commas([{T, _} | Rest], D, N) when T =:= ')'; T =:= ']'; T =:= '}'; T =:= '>>' ->
    commas(Rest, D - 1, N);
commas([_ | Rest], D, N) -> commas(Rest, D, N).

%% A module that makes itself a process's error handler, whose two
%% functions the host calls on an undefined function or fun.
error_handlers(Mods) ->
    [{M, F, 3} || M <- Mods, F <- [undefined_function, undefined_lambda],
                  lists:member({F, 3}, M:module_info(exports)),
                  sets_error_handler(M)].

sets_error_handler(M) ->
    {ok, Text} = file:read_file(proplists:get_value(source, M:module_info(compile))),
    binary:match(Text, <<"process_flag(error_handler, ?MODULE)">>) =/= nomatch.

%% The callbacks of each module's behaviours.
callbacks(Mods) ->
    [{M, F, A} || M <- Mods,
                  {behaviour, Bs} <- M:module_info(attributes),
                  B <- Bs,
                  {F, A} <- B:behaviour_info(callbacks)].

%% The entry bin/ern starts the host with, `-run Module Function`.
entry() ->
    {ok, Launcher} = file:read_file("bin/ern"),
    {match, [M, F]} = re:run(Launcher, "-run ([a-z_]+) ([a-z_]+)",
                             [{capture, all_but_first, list}]),
    [{list_to_atom(M), list_to_atom(F), 0}].

report(_, []) ->
    ok;
report(What, MFAs) ->
    [io:format("make calls: ~s: ~s:~s/~B~n", [What, M, F, A]) || {M, F, A} <- lists:sort(MFAs)].
