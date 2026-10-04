%% The repository's own files as the document and style suites read them:
%% the files a list of patterns matches, an editor's left out, and a file's
%% bytes, each by its path from the repository's root.
-module(ern_repository).

-export([files/1, read/1]).

-define(ROOT, "..").

%% The files the wildcards match, from the repository's root, but an
%% editor's lock file, `.#main.ern`, a link to nothing while the file is
%% open, and its auto-save file, `#main.ern#`: neither is ours, and a name
%% that begins with a dot is no module (report §11.1's path shape).
-spec files([string()]) -> [file:filename()].
files(Patterns) ->
    [File || Pattern <- Patterns, File <- filelib:wildcard(Pattern, ?ROOT),
             not lists:member(hd(filename:basename(File)), ".#")].

%% The bytes of the file at Relative, a path from the repository's root.
-spec read(file:filename()) -> binary().
read(Relative) ->
    {ok, Bytes} = file:read_file(filename:join(?ROOT, Relative)),
    Bytes.
