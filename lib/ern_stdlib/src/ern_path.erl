%% The shims behind Path (report Appendix E.14, rule 1): a path is in the
%% runtime's syntax, so `filename` decides what a segment, a parent, and a
%% root are. Each takes and gives the path's text; path.ern wraps it.
-module(ern_path).

-export([join/2, split/1, dirname/1, basename/1, extension/1, rootname/1, is_absolute/1]).

-spec join(binary(), binary()) -> binary().
join(A, B) -> text(filename:join(A, B)).

-spec split(binary()) -> [binary()].
split(P) -> [text(S) || S <- filename:split(P)].

-spec dirname(binary()) -> binary().
dirname(P) -> text(filename:dirname(P)).

-spec basename(binary()) -> binary().
basename(P) -> text(filename:basename(P)).

%% with its leading dot, or empty
-spec extension(binary()) -> binary().
extension(P) -> text(filename:extension(P)).

-spec rootname(binary()) -> binary().
rootname(P) -> text(filename:rootname(P)).

-spec is_absolute(binary()) -> boolean().
is_absolute(P) -> filename:pathtype(P) =:= absolute.

text(S) -> unicode:characters_to_binary(S).
