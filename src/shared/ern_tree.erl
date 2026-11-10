%% Report §11.1, §11.2: the toolchain's tree, the checkout or an
%% installation's lib/ernest, and the builds of its own under it, the
%% standard library's in `build/stdlib`, the shell's in `build/shell` and
%% the libraries' in `build/libs`, which the toolchain finds relative to
%% its own modules, and its own Erlang under the same `build`
%% (docs/design/install.md).
-module(ern_tree).

-export([tree/0, build/1, libraries/0, code_path/0, own_code/0, run_code/0]).

%% The tree, found from where this module was loaded, its build/shared/ebin.
-spec tree() -> file:filename().
tree() ->
    Segments = normalized(filename:split(filename:absname(code:which(?MODULE))), []),
    {Tree, ["build", "shared", "ebin", _]} = lists:split(length(Segments) - 4, Segments),
    filename:join(Tree).

%% A build of the toolchain's own, by its path under the tree's `build`:
%% `stdlib`, `shell`, `libs/markdown`.
-spec build(file:filename()) -> file:filename().
build(Path) ->
    filename:join([tree(), "build", Path]).

%% Report §11.1, §11.2, Appendix G: the builds of the toolchain's own
%% libraries, each directory `build/libs/<name>` under the tree, in the
%% order of their names, as the tree holds them when asked; none where it
%% holds none, as before `make` builds them.
-spec libraries() -> [file:filename()].
libraries() ->
    Libraries = build("libs"),
    case file:list_dir(Libraries) of
        {ok, Names} -> [Library || Name <- lists:sort(Names),
                                   Library <- [filename:join(Libraries, Name)],
                                   filelib:is_dir(Library)];
        {error, _} -> []
    end.

%% The directories of the toolchain's own Erlang that bin/ern puts on the
%% host's code path, which hold no test's module.
-spec code_path() -> [file:filename()].
code_path() ->
    filelib:wildcard(build("toolchain/*/ebin"))
        ++ [build(Root ++ "/ebin") || Root <- ["shared", "nodes", "runtime", "shell"]].

%% Report §11.2: the toolchain's own Erlang, the .beam files of its code path
%% and each library's shim beside its .erc. The rest of `build` is no code of
%% its own: a site's source, the units' links and a test's modules.
-spec own_code() -> [file:filename()].
own_code() ->
    [Beam || Directory <- code_path() ++ libraries(),
             Beam <- filelib:wildcard(filename:join(Directory, "*.beam"))].

%% Report §12: the toolchain's own Erlang of a run's side, which a run loads
%% at its start (ern_code:load_runtime/0): the .beam files of the
%% runtime's, the nodes' and the shared directories and each library's
%% shim. The runner's is loaded as its job starts, and the compiler's and
%% the shell's at their first call.
-spec run_code() -> [file:filename()].
run_code() ->
    [Beam || Directory <- [build(Root ++ "/ebin") || Root <- ["runtime", "nodes", "shared"]]
                              ++ libraries(),
             Beam <- filelib:wildcard(filename:join(Directory, "*.beam"))].

%% A path's segments with `.` and `..` resolved, since the code path a
%% test gives the host is relative.
normalized([], Acc) -> lists:reverse(Acc);
normalized(["." | Rest], Acc) -> normalized(Rest, Acc);
normalized([".." | Rest], [_ | Acc]) -> normalized(Rest, Acc);
normalized([Segment | Rest], Acc) -> normalized(Rest, [Segment | Acc]).
