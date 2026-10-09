%% The primitives of Path (report Appendix E.14, E.0 rule 1): what only the
%% host knows of its path syntax, the separator and whether a path starts
%% at a root, by `filename`, and a path's parts between its separators or
%% its dots, read by code points as the runtime reads a path. The rest of
%% Path is Ernest over them and String.
-module(ern_path).

-export([separator/0, parts/2, is_absolute/1]).

%% The separator `filename:join/2` writes, `/`, or `\` on Windows.
-spec separator() -> binary().
separator() ->
    case os:type() of
        {win32, _} -> <<"\\">>;
        _ -> <<"/">>
    end.

%% Appendix E.14: the text's parts between each occurrence of the mark,
%% empty ones kept, by `binary:split/3`. It reads bytes, and UTF-8 never
%% holds one code point's bytes inside another's, so each match begins and
%% ends where code points do, and each part is UTF-8: a separator or a dot
%% is one though a combining mark follows it, as the runtime reads a path.
%% Its option is an atom, which Ernest makes only through `Foreign.atom` at
%% each call.
-spec parts(binary(), binary()) -> [binary()].
parts(Text, Mark) -> binary:split(Text, Mark, [global]).

%% A Path is Path(String), {'Path', Text} (report §8.4); filename:pathtype/1
%% answers absolute for a path that starts at a root.
-spec is_absolute({'Path', binary()}) -> boolean().
is_absolute({'Path', Path}) -> filename:pathtype(Path) =:= absolute.
