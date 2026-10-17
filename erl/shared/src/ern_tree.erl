%% Report §11.1, §11.2: the toolchain's tree, the checkout or an
%% installation's lib/ernest, and the builds of its own under it, the
%% standard library's in `build/stdlib`, the shell's in `build/shell` and
%% the libraries' in `build/libs`, which the toolchain finds relative to
%% its own modules (docs/design/install.md).
-module(ern_tree).

-export([tree/0, build/1]).

%% The tree, found from where this module was loaded, its erl/shared/ebin.
-spec tree() -> file:filename().
tree() ->
    Segments = normalized(filename:split(filename:absname(code:which(?MODULE))), []),
    {Tree, ["erl", "shared", "ebin", _]} = lists:split(length(Segments) - 4, Segments),
    filename:join(Tree).

%% A build of the toolchain's own, by its path under the tree's `build`:
%% `stdlib`, `shell`, `libs/markdown`.
-spec build(file:filename()) -> file:filename().
build(Path) ->
    filename:join([tree(), "build", Path]).

%% A path's segments with `.` and `..` resolved, since the code path a
%% test gives the host is relative.
normalized([], Acc) -> lists:reverse(Acc);
normalized(["." | Rest], Acc) -> normalized(Rest, Acc);
normalized([".." | Rest], [_ | Acc]) -> normalized(Rest, Acc);
normalized([Segment | Rest], Acc) -> normalized(Rest, [Segment | Acc]).
