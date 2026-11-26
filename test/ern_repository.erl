%% The repository's own files as the document and style suites read them:
%% the tracked files a list of patterns matches, and a file's bytes, each
%% by its path from the repository's root. An untracked file is the
%% user's, which no suite reads, as no build's product is.
-module(ern_repository).

-export([files/1, is_editors/1, modules/0, read/1]).

-define(ROOT, "..").

%% The tracked files the patterns match, from the repository's root, in
%% the order of the patterns and in each the order git lists them, a file
%% the working tree has lost left out. A pattern is git's `:(glob)`
%% pathspec, which has no braces: `*` matches within a segment and `**/`
%% any run of directories. A pattern that matches no tracked file fails
%% the test, which would otherwise read nothing of it and pass.
-spec files([string()]) -> [file:filename()].
files(Patterns) ->
    lists:append([tracked(Pattern) || Pattern <- Patterns]).

tracked(Pattern) ->
    Listed = string:lexemes(os:cmd("git -C " ++ ?ROOT ++ " ls-files -- ':(glob)"
                                   ++ Pattern ++ "'"), "\n"),
    Listed =/= [] orelse erlang:error({no_tracked_file, Pattern}),
    [File || File <- Listed, filelib:is_regular(filename:join(?ROOT, File))].

%% Whether File is an editor's: a lock file, `.#main.ern`, a link to
%% nothing while the file is open, or an auto-save file, `#main.ern#`.
%% Neither is ours, and a name that begins with a dot is no module (report
%% §11.1's path shape).
-spec is_editors(file:filename()) -> boolean().
is_editors(File) ->
    lists:member(hd(filename:basename(File)), ".#").

%% The toolchain's own Erlang, the modules a release ships, by their paths
%% from the repository's root.
-spec modules() -> [file:filename()].
modules() ->
    [File || File <- files(["src/**/*.erl"]), not lists:member("test", filename:split(File))].

%% The bytes of the file at Relative, a path from the repository's root.
-spec read(file:filename()) -> binary().
read(Relative) ->
    {ok, Bytes} = file:read_file(filename:join(?ROOT, Relative)),
    Bytes.
