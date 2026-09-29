%% The primitives of String (report Appendix E.5, E.0 rule 1): Erlang's
%% Unicode operations, each returning what the declared type says; the rest
%% of String is Ernest over them, so every search matches whole graphemes.
%% A String is a UTF-8 binary (report §8.4), so toUtf8 is the value itself
%% and comparison is Erlang's on binaries, which is by code point.
-module(ern_string).

-export([graphemes/1, index_of/2, last_index_of/2, slice/3, trim_start/1, trim_end/1, to_lower/1,
         to_upper/1, to_int_base/2, to_float/1, to_list/1, from_list/1, from_utf8/1, to_utf8/1]).

%% Appendix E.5: the graphemes in order, as `string:to_graphemes/1` splits
%% them, extended grapheme clusters by the host's Unicode data, the same
%% `string:length/1` counts; each is a code point or a list of them.
-spec graphemes(binary()) -> [binary()].
graphemes(S) -> [unicode:characters_to_binary([G]) || G <- string:to_graphemes(S)].

%% Appendix E.5: where the part begins as whole graphemes, beginning and
%% ending where the string's own graphemes do, counted in graphemes as
%% `slice` takes them, so that the answer indexes the same string `slice`
%% does. `string:find/2` matches code points, and a match that began inside
%% a grapheme, a line feed of a carriage return's, split it. The host's
%% byte search finds each candidate, and the graphemes are walked only as
%% far as it, so that a search costs what it reads.
-spec index_of(binary(), binary()) -> 'None' | {'Some', integer()}.
index_of(_, <<>>) ->
    {'Some', 0};
index_of(S, Part) ->
    case next_match(S, Part, 0, 0) of
        {I, _} -> {'Some', I};
        none -> 'None'
    end.

%% Appendix E.5: the last occurrence, and the string's size for an empty
%% part; each match is found from the grapheme after the one before.
-spec last_index_of(binary(), binary()) -> 'None' | {'Some', integer()}.
last_index_of(S, <<>>) ->
    {'Some', string:length(S)};
last_index_of(S, Part) ->
    last_match(S, Part, 0, 0, 'None').

last_match(S, Part, B, I, Last) ->
    case next_match(S, Part, B, I) of
        {At, C} ->
            {B1, I1} = step(S, C, At),
            last_match(S, Part, B1, I1, {'Some', At});
        none ->
            Last
    end.

%% The first match at or after the boundary B, which I graphemes precede:
%% the graphemes before it and its byte offset, or none.
next_match(S, Part, B, I) ->
    case binary:match(S, Part, [{scope, {B, byte_size(S) - B}}]) of
        nomatch ->
            none;
        {C, N} ->
            case walk(S, B, I, C) of
                {C, At} ->
                    case walk(S, C, At, C + N) of
                        {End, _} when End =:= C + N -> {At, C};
                        _ -> next_after(S, Part, C, At)
                    end;
                {B1, I1} ->
                    %% the candidate began inside a grapheme, which ends at B1
                    next_match(S, Part, B1, I1)
            end
    end.

next_after(S, Part, C, At) ->
    case step(S, C, At) of
        {C, _} -> none;
        {B1, I1} -> next_match(S, Part, B1, I1)
    end.

%% From the boundary B, which I graphemes precede, to the first boundary at
%% or past the offset: that boundary and the graphemes before it.
walk(_, B, I, Offset) when B >= Offset ->
    {B, I};
walk(S, B, I, Offset) ->
    case step(S, B, I) of
        {B, I} -> {B, I};
        {B1, I1} -> walk(S, B1, I1, Offset)
    end.

%% Past the grapheme at the boundary B; at the end, B itself.
step(S, B, I) ->
    case string:next_grapheme(binary:part(S, B, byte_size(S) - B)) of
        [G | _] -> {B + byte_size(unicode:characters_to_binary([G])), I + 1};
        [] -> {B, I}
    end.

-spec slice(binary(), integer(), integer()) -> binary().
slice(S, From, Count) -> unicode:characters_to_binary(string:slice(S, From, Count)).

%% Appendix E.5: without the leading graphemes whose first code point is
%% White_Space, as Char.isSpace says. string:next_grapheme/1 answers the
%% first grapheme cluster, a code point or a list of them, and the rest.
-spec trim_start(binary()) -> binary().
trim_start(S) ->
    case string:next_grapheme(S) of
        [G | Rest] ->
            case ern_char:is_space(first(G)) of
                true -> trim_start(Rest);
                false -> S
            end;
        [] ->
            <<>>
    end.

%% Appendix E.5: without the trailing graphemes whose first code point is
%% White_Space.
-spec trim_end(binary()) -> binary().
trim_end(S) ->
    Kept = lists:dropwhile(fun(G) -> ern_char:is_space(first(G)) end,
                           lists:reverse(string:to_graphemes(S))),
    unicode:characters_to_binary(lists:reverse(Kept)).

first([C | _]) -> C;
first(C) -> C.

-spec to_lower(binary()) -> binary().
to_lower(S) -> unicode:characters_to_binary(string:lowercase(S)).

-spec to_upper(binary()) -> binary().
to_upper(S) -> unicode:characters_to_binary(string:uppercase(S)).

%% report Appendix E.5: in that base, its digits and letters in either case
-spec to_int_base(binary(), integer()) -> {'Some', integer()} | 'None'.
to_int_base(S, Base) ->
    try {'Some', binary_to_integer(S, Base)}
    catch error:badarg -> 'None'
    end.

%% report §2.5: the float literal form, with an optional leading minus;
%% §3.1: "-0.0" reads as 0.0
-spec to_float(binary()) -> {'Some', float()} | 'None'.
to_float(S) ->
    case re:run(S, "^-?[0-9]+\\.[0-9]+([eE][+-]?[0-9]+)?$") of
        nomatch -> 'None';
        _ ->
            try {'Some', binary_to_float(S) + 0.0}
            catch error:badarg -> 'None'
            end
    end.

-spec to_list(binary()) -> [char()].
to_list(S) -> unicode:characters_to_list(S).

-spec from_list([char()]) -> binary().
from_list(Cs) -> unicode:characters_to_binary(Cs).

-spec from_utf8(binary()) -> {'Some', binary()} | 'None'.
from_utf8(B) ->
    case unicode:characters_to_binary(B, utf8, utf8) of
        S when is_binary(S) -> {'Some', S};
        _ -> 'None'
    end.

-spec to_utf8(binary()) -> binary().
to_utf8(S) -> S.
