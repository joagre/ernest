%% The primitives of Path (report Appendix E.14, E.0 rule 1): what only the
%% host knows of its path syntax, the separator and whether a path starts
%% at a root, by `filename`. The rest of Path is Ernest over String.
-module(ern_path).

-export([separator/0, is_absolute/1]).

%% The separator `filename:join/2` writes, `/`, or `\` on Windows.
-spec separator() -> binary().
separator() ->
    case os:type() of
        {win32, _} -> <<"\\">>;
        _ -> <<"/">>
    end.

%% A Path is Path(String), {'Path', Text} (report §8.4); filename:pathtype/1
%% answers absolute for a path that starts at a root.
-spec is_absolute({'Path', binary()}) -> boolean().
is_absolute({'Path', P}) -> filename:pathtype(P) =:= absolute.
