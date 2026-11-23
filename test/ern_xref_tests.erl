%% The calls of the toolchain's own Erlang, its shims and the Erlang the
%% compiler writes for the standard library, the shell and the libraries,
%% the code Dialyzer reads (the Makefile), held by the host's xref: each
%% names a function that this code or the host's own applications define,
%% each call between two of the toolchain's applications goes down their
%% order, and each export of the toolchain's own is called. A call by a
%% name the code computes is no call xref reads, and a test's module is read
%% only as a caller of the exports.
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

%% docs/code_style.md "Erlang": every export of the toolchain's own Erlang
%% is called, by its own code, by the code the compiler writes for the
%% standard library, the shell and the libraries, or by a test, which
%% stands in a module of its own and calls what it tests by its export. A
%% call by a name xref cannot read is told apart: a callback of a behavior
%% the module declares, a call the emitter writes (written_calls/0), the
%% launcher's start (launched/0) and the exports the short list names
%% (called_by_name/0), each of which the test holds to be exported. A
%% module whose name does not begin `ern` is vendored, and keeps its
%% upstream's exports. A regression test, written once the tree was cleaned
%% of every export it found.
unused_exports_test() ->
    Units = filelib:wildcard(filename:join(ern_tree:build("units"), "*.beam")),
    {ok, Xref} = xref:start([{xref_mode, functions}]),
    try
        ok = xref:set_default(Xref, [{warnings, false}, {verbose, false}]),
        ok = xref:set_library_path(Xref, [Directory || Directory <- code:get_path(),
                                                       lists:prefix(code:lib_dir(), Directory)]),
        Own = [Module || Beam <- ern_tree:own_code(),
                         {ok, Module} <- [xref:add_module(Xref, Beam)]],
        [{ok, _} = xref:add_module(Xref, Beam) || Beam <- Units ++ test_beams()],
        {ok, Exported} = xref:q(Xref, "X"),
        ?assertEqual([], called_by_name() -- Exported),
        {ok, Unused} = xref:analyze(Xref, exports_not_used),
        Called = callbacks() ++ written_calls() ++ launched() ++ called_by_name(),
        ?assertEqual([], [Export || {Module, Function, _} = Export <- lists:sort(Unused),
                                    lists:member(Module, Own),
                                    lists:prefix("ern", atom_to_list(Module)),
                                    not lists:member(Export, Called),
                                    not lists:member({Module, Function, any}, Called)])
    after
        xref:stop(Xref)
    end.

%% The tests' compiled modules: each root's, beside its ebin, each
%% library's shim's, and those under test/, beside this one.
test_beams() ->
    Directories = [filename:join(filename:dirname(Directory), "test")
                   || Directory <- ern_tree:code_path()]
        ++ [filename:join(Library, "test") || Library <- ern_tree:libraries()]
        ++ [filename:dirname(code:which(?MODULE))],
    lists:append([filelib:wildcard(filename:join(Directory, "*.beam"))
                  || Directory <- Directories]).

%% The callbacks of each behavior a module of its own declares in its
%% source, `-behaviour(Name).`, which the host's server calls by the
%% module's name.
callbacks() ->
    [{list_to_atom(filename:basename(File, ".erl")), Function, Arity}
     || File <- ern_repository:files(["src/**/*.erl"]),
        {match, Declared} <- [re:run(ern_repository:read(File), "^-behaviour\\(([a-z_]+)\\)\\.",
                                     [global, multiline, {capture, all_but_first, binary}])],
        [Name] <- Declared,
        Behavior <- [binary_to_atom(Name)],
        {module, _} <- [code:ensure_loaded(Behavior)],
        {Function, Arity} <- Behavior:behaviour_info(callbacks)].

%% Report §11.1: the host's functions the emitter writes a call of into the
%% code it emits, each by its module and its function as call_remote/3 is
%% given them, or the runtime's as reply_call/4 is given its function, at
%% any arity, since xref reads such a call only where a unit holds its
%% construct, and a program's call of `Address.callForever` passes one
%% argument more than the standard library's.
written_calls() ->
    {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}]}} =
        beam_lib:chunks(code:which(ern_emitter), [abstract_code]),
    lists:usort(remote_calls(Forms)).

remote_calls({call, _, {atom, _, call_remote}, [{atom, _, Module}, {atom, _, Function} | Rest]}) ->
    [{Module, Function, any} | remote_calls(Rest)];
remote_calls({call, _, {atom, _, reply_call}, [{atom, _, Function} | Rest]}) ->
    [{ern_rt, Function, any} | remote_calls(Rest)];
remote_calls(Term) when is_tuple(Term) ->
    remote_calls(tuple_to_list(Term));
remote_calls(Terms) when is_list(Terms) ->
    lists:flatmap(fun remote_calls/1, Terms);
remote_calls(_) ->
    [].

%% docs/design/install.md: the functions bin/ern runs, each `-run Module
%% Function`, which the host calls with no argument.
launched() ->
    {match, Runs} = re:run(ern_repository:read("bin/ern"), "-run ([a-z_]+) ([a-z_]+)",
                           [global, {capture, all_but_first, binary}]),
    [{binary_to_atom(Module), binary_to_atom(Function), 0} || [Module, Function] <- Runs].

%% The exports called by a name no rule above reads, each group with its
%% reason.
called_by_name() ->
    %% Report §12.5: the carrier's distribution module and its map of
    %% ports, which the host calls by the names the node's flags give them,
    %% -proto_dist ern_tls and -epmd_module ern_epmd (ern_carrier's
    %% boot_flags/1), and the check of a peer's certificate, which the
    %% host's TLS calls by the name the flags' verify_fun gives it
    [{ern_tls_dist, Function, Arity}
     || {Function, Arity} <- [{childspecs, 0}, {select, 1}, {address, 0}, {is_node_name, 1},
                              {listen, 2}, {setup, 5}, {close, 1}, {accept, 1},
                              {accept_connection, 5}]]
        ++ [{ern_epmd, Function, Arity}
            || {Function, Arity} <- [{start_link, 0}, {register_node, 2}, {register_node, 3},
                                     {port_please, 2}, {port_please, 3}, {address_please, 3},
                                     {listen_port_please, 2}, {names, 1}]]
        ++ [{ern_carrier, verify, 3}]
        %% Report §8.6, §11.2: the error handler of each process the
        %% runtime starts, which the host calls by the name the process's
        %% flag gives it, at a call into a module the host has not loaded
        ++ [{ern_rt, undefined_function, 3}, {ern_rt, undefined_lambda, 3}]
        %% Report §8.7: a spawn on a peer and a compute, which the emitter
        %% writes by the function its case picks (ern_emitter's
        %% peer_spawn/6), with the function's identity in place of the
        %% function and the site after the declaration's arguments
        ++ [{ern_peer, spawn, 4}, {ern_peer, spawn_monitored, 5}, {ern_peer, compute, 3},
            {ern_peer, compute_at, 4}]
        %% Report §8.4, §9.4: the functions Io.show's and Io.debug's
        %% declarations name, at the count of their parameters, which the
        %% checker holds a declaration to; the compiler calls show/2 and
        %% debug/2, the descriptor of the value's type after the value, and
        %% no code calls these two
        ++ [{ern_io, show, 1}, {ern_io, debug, 1}].
