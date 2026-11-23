%% The calls of the toolchain's own Erlang, its shims and the Erlang the
%% compiler writes for the standard library, the shell and the libraries,
%% the code Dialyzer reads (the Makefile), held by the host's xref: each
%% names a function that this code or the host's own applications define,
%% and each call between two of the toolchain's applications goes down
%% their order. A call by a name the code computes, a foreign function's by
%% its declaration among them, is no call xref reads, and a test's module is
%% not read.
-module(ern_xref_tests).

-include_lib("eunit/include/eunit.hrl").

-export([order/0]).

%% docs/development.md "Building": `make xref`. A regression test, written
%% where it found nothing; it reads the units the repository's `make units`
%% linked under build/units, since xref reads a module only from a file
%% whose name ends in .beam.
undefined_calls_test() ->
    Units = filelib:wildcard(filename:join(ern_tree:build("units"), "*.beam")),
    ?assertNotEqual([], Units),
    {ok, Xref} = xref:start([{xref_mode, functions}]),
    try
        ok = xref:set_default(Xref, [{warnings, false}, {verbose, false}]),
        ok = xref:set_library_path(Xref, [Directory || Directory <- code:get_path(),
                                                       lists:prefix(code:lib_dir(), Directory)]),
        [{ok, _} = xref:add_module(Xref, Beam) || Beam <- ern_tree:own_code() ++ Units],
        ?assertEqual({ok, []}, xref:analyze(Xref, undefined_function_calls))
    after
        xref:stop(Xref)
    end.

%% The toolchain's applications, each a directory of ern_tree:code_path/0,
%% from the lowest to the highest. A module calls a module of its own
%% application or of one below it, and never one above it or beside it, so
%% that no application needs one that needs it. docs/architecture.md's *The
%% pipeline* states the order, which ern_docs_tests holds to this one.
-spec order() -> [atom()].
order() ->
    [shared, lexer, parser, formatter, checker, emitter, runtime, builder, nodes, shell, cli].

%% docs/architecture.md "The pipeline": the applications call one another
%% in one order. A call against it is named by its two applications and
%% the modules that make it.
application_order_test() ->
    Applications = [{list_to_atom(filename:basename(filename:dirname(Directory))), Directory}
                    || Directory <- ern_tree:code_path()],
    {ok, Xref} = xref:start([{xref_mode, modules}]),
    try
        ok = xref:set_default(Xref, [{warnings, false}, {verbose, false}]),
        [{ok, Name} = xref:add_application(Xref, filename:dirname(Directory), [{name, Name}])
         || {Name, Directory} <- Applications],
        {ok, Edges} = xref:q(Xref, "AE"),
        Against = [{Caller, Callee} || {Caller, Callee} <- Edges, Caller =/= Callee,
                                       rank(Callee) >= rank(Caller)],
        ?assertEqual([], [called(Xref, Caller, Callee)
                          || {Caller, Callee} <- lists:sort(Against)]),
        ?assertEqual(lists:sort(order()), lists:sort([Name || {Name, _} <- Applications]))
    after
        xref:stop(Xref)
    end.

%% An application's place in the order, the lowest's 0.
rank(Application) ->
    length(lists:takewhile(fun(Name) -> Name =/= Application end, order())).

%% The line that names a call against the order, `nodes -> cli:` and the
%% calls of Caller's modules to Callee's, by module.
called(Xref, Caller, Callee) ->
    Query = lists:flatten(io_lib:format("ME | ~p : App || ~p : App", [Caller, Callee])),
    {ok, Calls} = xref:q(Xref, Query),
    Pairs = [io_lib:format("~p -> ~p", [From, To]) || {From, To} <- lists:sort(Calls)],
    lists:flatten(io_lib:format("~p -> ~p: ~ts", [Caller, Callee, lists:join(", ", Pairs)])).
