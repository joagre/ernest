%% The shims behind String (report Appendix E.5): Erlang's Unicode
%% operations, which rule 1 admits, each returning what the declared type
%% says. A String is a UTF-8 binary (report §8.4), so toUtf8 is the value
%% itself and comparison is Erlang's on binaries, which is by code point.
-module(ern_string).

-export([contains/2, index_of/2, last_index_of/2, starts_with/2, ends_with/2,
         replace/3, slice/3, trim/1, to_lower/1,
         to_upper/1, to_int_base/2, to_float/1, to_list/1, from_list/1, from_utf8/1, to_utf8/1,
         split/2, copy/2]).

-spec contains(binary(), binary()) -> boolean().
contains(S, Sub) -> string:find(S, Sub) =/= nomatch.

%% Appendix E.5: in the characters `string:length/1` counts, as `slice`
%% takes them, so that the answer indexes the same string `slice` does.
-spec index_of(binary(), binary()) -> 'None' | {'Some', integer()}.
index_of(S, Part) ->
    case string:find(S, Part) of
        nomatch -> 'None';
        Suffix -> {'Some', string:length(S) - string:length(Suffix)}
    end.

%% Appendix E.5: the last occurrence, and the string's size for an empty
%% part, which `string:find/3` answers as the first.
-spec last_index_of(binary(), binary()) -> 'None' | {'Some', integer()}.
last_index_of(S, <<>>) ->
    {'Some', string:length(S)};
last_index_of(S, Part) ->
    case string:find(S, Part, trailing) of
        nomatch -> 'None';
        Suffix -> {'Some', string:length(S) - string:length(Suffix)}
    end.

-spec starts_with(binary(), binary()) -> boolean().
starts_with(S, Prefix) -> string:prefix(S, Prefix) =/= nomatch.

-spec ends_with(binary(), binary()) -> boolean().
ends_with(S, Suffix) ->
    Size = byte_size(S),
    SSize = byte_size(Suffix),
    Size >= SSize andalso binary:part(S, Size - SSize, SSize) =:= Suffix.

%% every occurrence; an empty From changes nothing
-spec replace(binary(), binary(), binary()) -> binary().
replace(S, <<>>, _) -> S;
replace(S, From, To) -> unicode:characters_to_binary(string:replace(S, From, To, all)).

-spec slice(binary(), integer(), integer()) -> binary().
slice(S, From, Count) -> unicode:characters_to_binary(string:slice(S, From, Count)).

-spec trim(binary()) -> binary().
trim(S) -> unicode:characters_to_binary(string:trim(S)).

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

-spec split(binary(), binary()) -> [binary()].
split(S, Sep) -> binary:split(S, Sep, [global]).

-spec copy(binary(), integer()) -> binary().
copy(S, N) -> binary:copy(S, N).
