%% ern_tree: what the toolchain finds of its own under its tree.
-module(ern_tree_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.2: the toolchain's own Erlang is the code bin/ern puts on the
%% host's path and each library's shim, by which the look, the code digest and
%% the manual pages' times know it; no test's module is among it. A regression
%% test, written after the code: moved beside their libraries the shims would
%% have fallen out of all three
own_code_test() ->
    Own = [filename:basename(Beam, ".beam") || Beam <- ern_tree:own_code()],
    ?assertEqual([], ["ern_cli", "ern_tree", "ern_node", "ern_rt", "ern_shell", "ern_json",
                      "ern_http", "ern_base64"] -- Own),
    ?assertEqual([], [Module || Module <- ["ern_tree_tests", "ern_named", "ern_site"],
                                lists:member(Module, Own)]).

%% docs/design/install.md: the directories of the toolchain's code are the
%% ones that hold it, and no directory of a test's
code_path_test() ->
    Path = ern_tree:code_path(),
    ?assertEqual([], [Directory || Directory <- Path, not filelib:is_dir(Directory)]),
    ?assert(lists:member(filename:dirname(code:which(ern_tree)), Path)),
    ?assertEqual([], [Directory || Directory <- Path, filename:basename(Directory) =/= "ebin"]).
