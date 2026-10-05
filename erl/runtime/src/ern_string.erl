%% The primitives of String (report Appendix E.5, E.0 rule 1): Erlang's
%% Unicode operations, each returning what the declared type says; the rest
%% of String is Ernest over them, so every search matches whole graphemes.
%% One stands on a host function whose answer no Ernest value is,
%% `binary_to_integer/2`'s raise.
%% A String is a UTF-8 binary (report §8.4), so toUtf8 is the value itself
%% and comparison is Erlang's on binaries, which is by code point.
-module(ern_string).

-export([graphemes/1, index_of/2, last_index_of/2, around/2, slice/3, drop/2, last_grapheme/1,
         to_lower/1, to_upper/1, to_integer/2, to_float/1, to_list/1, from_list/1, from_utf8/1,
         to_utf8/1]).

%% Appendix E.5: the graphemes in order, as `string:to_graphemes/1` splits
%% them, extended grapheme clusters by the host's Unicode data, the same
%% `string:length/1` counts; each is a code point or a list of them.
-spec graphemes(binary()) -> [binary()].
graphemes(Text) ->
    [unicode:characters_to_binary([Grapheme]) || Grapheme <- string:to_graphemes(Text)].

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
index_of(Text, Part) ->
    case next_match(Text, Part, 0, 0) of
        {Index, _} -> {'Some', Index};
        none -> 'None'
    end.

%% Appendix E.5: the last occurrence, and the string's size for an empty
%% part; each match is found from the grapheme after the one before.
-spec last_index_of(binary(), binary()) -> 'None' | {'Some', integer()}.
last_index_of(Text, <<>>) ->
    {'Some', string:length(Text)};
last_index_of(Text, Part) ->
    last_match(Text, Part, 0, 0, 'None').

last_match(Text, Part, Boundary, Index, Last) ->
    case next_match(Text, Part, Boundary, Index) of
        {MatchIndex, MatchOffset} ->
            {Boundary1, Index1} = step(Text, MatchOffset, MatchIndex),
            last_match(Text, Part, Boundary1, Index1, {'Some', MatchIndex});
        none ->
            Last
    end.

%% Appendix E.5: the string before the first match of the part and the
%% string after it, found as index_of finds it, so that `split` reads the
%% string once. The part is not empty.
-spec around(binary(), binary()) -> 'None' | {'Some', {binary(), binary()}}.
around(Text, Part) ->
    case next_match(Text, Part, 0, 0) of
        {_, Offset} ->
            End = Offset + byte_size(Part),
            {'Some', {binary:part(Text, 0, Offset), binary:part(Text, End, byte_size(Text) - End)}};
        none ->
            'None'
    end.

%% The first match at or after the grapheme boundary Boundary, which Index
%% graphemes precede: the graphemes before it and its byte offset, or none.
next_match(Text, Part, Boundary, Index) ->
    case binary:match(Text, Part, [{scope, {Boundary, byte_size(Text) - Boundary}}]) of
        nomatch ->
            none;
        {Offset, Length} ->
            case walk(Text, Boundary, Index, Offset) of
                {Offset, MatchIndex} ->
                    case walk(Text, Offset, MatchIndex, Offset + Length) of
                        {End, _} when End =:= Offset + Length -> {MatchIndex, Offset};
                        _ -> next_after(Text, Part, Offset, MatchIndex)
                    end;
                {Boundary1, Index1} ->
                    %% the candidate began inside a grapheme, which ends at
                    %% Boundary1
                    next_match(Text, Part, Boundary1, Index1)
            end
    end.

next_after(Text, Part, Offset, MatchIndex) ->
    case step(Text, Offset, MatchIndex) of
        {Offset, _} -> none;
        {Boundary1, Index1} -> next_match(Text, Part, Boundary1, Index1)
    end.

%% From the grapheme boundary Boundary, which Index graphemes precede, to
%% the first boundary at or past Offset: that boundary and the graphemes
%% before it.
walk(_, Boundary, Index, Offset) when Boundary >= Offset ->
    {Boundary, Index};
walk(Text, Boundary, Index, Offset) ->
    case step(Text, Boundary, Index) of
        {Boundary, Index} -> {Boundary, Index};
        {Boundary1, Index1} -> walk(Text, Boundary1, Index1, Offset)
    end.

%% Past the grapheme at the boundary; at the end, the boundary itself.
%% `string:next_grapheme/1` answers the rest, of a form its page leaves
%% open: where it is a binary the grapheme ends where the rest begins, and
%% otherwise the grapheme is measured.
step(Text, Boundary, Index) ->
    case string:next_grapheme(binary:part(Text, Boundary, byte_size(Text) - Boundary)) of
        [_ | Rest] when is_binary(Rest) ->
            {byte_size(Text) - byte_size(Rest), Index + 1};
        [Grapheme | _] ->
            {Boundary + byte_size(unicode:characters_to_binary([Grapheme])), Index + 1};
        [] ->
            {Boundary, Index}
    end.

-spec slice(binary(), integer(), integer()) -> binary().
slice(Text, Index, Count) -> unicode:characters_to_binary(string:slice(Text, Index, Count)).

%% Appendix E.5: the string after its first Count graphemes, found by
%% walking only those, so that `split` costs what it reads; what is after
%% begins at a grapheme of valid UTF-8, and is the string's own bytes.
-spec drop(binary(), integer()) -> binary().
drop(Text, Count) ->
    Boundary = past(Text, 0, Count),
    binary:part(Text, Boundary, byte_size(Text) - Boundary).

%% The boundary Count graphemes past Boundary, or the string's end.
past(_, Boundary, Count) when Count =< 0 ->
    Boundary;
past(Text, Boundary, Count) ->
    case step(Text, Boundary, 0) of
        {Boundary, _} -> Boundary;
        {Next, _} -> past(Text, Next, Count - 1)
    end.

%% Appendix E.5: the string without its last grapheme, and that grapheme,
%% found from the string's end. No rule of Unicode's segmentation looks
%% back across an ASCII code point but a line feed's to the carriage return
%% before it, so of the graphemes the host splits from an ASCII byte, every
%% one after the first is the string's own: where they are two or more, the
%% last is the string's last. A tail of one grapheme is split again from
%% the ASCII byte before it, and one from the string's start is the
%% string's own: only the tail is split, and ordinary text ends in a few
%% bytes.
-spec last_grapheme(binary()) -> {'Some', {binary(), binary()}} | 'None'.
last_grapheme(<<>>) ->
    'None';
last_grapheme(Text) ->
    last_grapheme(Text, byte_size(Text) - 1).

last_grapheme(Text, Offset) ->
    From = ascii_byte(Text, Offset),
    <<_:From/binary, Tail/binary>> = Text,
    case lists:reverse(string:to_graphemes(Tail)) of
        [Last, _ | _] -> split_off(Text, Last);
        [Last] when From =:= 0 -> split_off(Text, Last);
        [_] -> last_grapheme(Text, From - 1)
    end.

%% The offset of the last ASCII byte at Offset or before it, or 0. An ASCII
%% byte is a code point of its own in UTF-8, never a part of another.
ascii_byte(_, Offset) when Offset =< 0 ->
    0;
ascii_byte(Text, Offset) ->
    case binary:at(Text, Offset) < 16#80 of
        true -> Offset;
        false -> ascii_byte(Text, Offset - 1)
    end.

%% The string before its last grapheme, and the grapheme, a code point or a
%% list of them as the host splits it.
split_off(Text, Last) ->
    Size = byte_size(Text) - byte_size(unicode:characters_to_binary([Last])),
    {'Some', {binary:part(Text, 0, Size), binary:part(Text, Size, byte_size(Text) - Size)}}.

-spec to_lower(binary()) -> binary().
to_lower(Text) -> unicode:characters_to_binary(string:lowercase(Text)).

-spec to_upper(binary()) -> binary().
to_upper(Text) -> unicode:characters_to_binary(string:uppercase(Text)).

%% Appendix E.5: the integer the text spells in the base, 2 to 36.
%% `binary_to_integer/2` takes the base's digits and letters in either case
%% after an optional `+` or `-`, and raises on anything else; E.5 takes no
%% `+`, and answers `None` where the host raises, which Ernest cannot catch.
-spec to_integer(binary(), 2..36) -> {'Some', integer()} | 'None'.
to_integer(<<"+", _/binary>>, _) ->
    'None';
to_integer(Text, Base) ->
    try {'Some', binary_to_integer(Text, Base)}
    catch error:badarg -> 'None'
    end.

%% report §2.5: the float literal form, with an optional leading minus;
%% §3.1: "-0.0" reads as 0.0
-spec to_float(binary()) -> {'Some', float()} | 'None'.
to_float(Text) ->
    case float_form(Text) of
        true ->
            try {'Some', binary_to_float(with_point(Text)) + 0.0}
            catch error:badarg -> 'None'
            end;
        false ->
            'None'
    end.

%% Digits, then a point, digits and an exponent that may follow, or an
%% exponent alone, `e` or `E`, a sign that may, and digits; a minus may
%% lead.
float_form(<<"-", Rest/binary>>) -> digits(Rest, point);
float_form(Text) -> digits(Text, point).

%% At least one digit, then Next: the point, the exponent, or the end.
digits(<<Digit, Rest/binary>>, Next) when Digit >= $0, Digit =< $9 -> more_digits(Rest, Next);
digits(_, _) -> false.

more_digits(<<Digit, Rest/binary>>, Next) when Digit >= $0, Digit =< $9 -> more_digits(Rest, Next);
more_digits(<<".", Rest/binary>>, point) -> digits(Rest, exponent);
more_digits(<<Mark, Sign, Rest/binary>>, point) when (Mark =:= $e orelse Mark =:= $E),
                                                    (Sign =:= $+ orelse Sign =:= $-) ->
    digits(Rest, done);
more_digits(<<Mark, Rest/binary>>, point) when Mark =:= $e; Mark =:= $E -> digits(Rest, done);
more_digits(<<Mark, Sign, Rest/binary>>, exponent) when (Mark =:= $e orelse Mark =:= $E),
                                                       (Sign =:= $+ orelse Sign =:= $-) ->
    digits(Rest, done);
more_digits(<<Mark, Rest/binary>>, exponent) when Mark =:= $e; Mark =:= $E -> digits(Rest, done);
more_digits(<<>>, Next) -> Next =/= point;
more_digits(_, _) -> false.

%% The host reads a float only with its point: `1e5` is read as `1.0e5`.
with_point(Text) ->
    case {binary:match(Text, <<".">>), binary:match(Text, [<<"e">>, <<"E">>])} of
        {nomatch, {Offset, 1}} ->
            <<Whole:Offset/binary, Exponent/binary>> = Text,
            <<Whole/binary, ".0", Exponent/binary>>;
        _ ->
            Text
    end.

-spec to_list(binary()) -> [char()].
to_list(Text) -> unicode:characters_to_list(Text).

-spec from_list([char()]) -> binary().
from_list(Chars) -> unicode:characters_to_binary(Chars).

-spec from_utf8(binary()) -> {'Some', binary()} | 'None'.
from_utf8(Bytes) ->
    case unicode:characters_to_binary(Bytes, utf8, utf8) of
        Text when is_binary(Text) -> {'Some', Text};
        _ -> 'None'
    end.

-spec to_utf8(binary()) -> binary().
to_utf8(Text) -> Text.
