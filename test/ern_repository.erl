%% The repository's own files as the document and style suites read them:
%% the files a list of patterns matches, an editor's left out, and a file's
%% bytes, each by its path from the repository's root.
-module(ern_repository).

-export([files/1, is_editors/1, modules/0, read/1]).

-define(ROOT, "..").

%% The files the wildcards match, from the repository's root, but an
%% editor's (is_editors/1).
-spec files([string()]) -> [file:filename()].
files(Patterns) ->
    [File || Pattern <- Patterns, File <- filelib:wildcard(Pattern, ?ROOT), not is_editors(File)].

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
