%% The shims behind Char (report Appendix E.6): the Unicode properties, the
%% case mappings, and the conversions between a Char and its code point,
%% which are one Erlang integer.
-module(ern_char).

-export([is_digit/1, is_alpha/1, is_space/1, is_upper/1, is_lower/1, to_upper/1, to_lower/1,
         to_string/1, to_int/1, from_int/1]).

-spec is_digit(char()) -> boolean().
is_digit(C) when C < 16#80 -> C >= $0 andalso C =< $9;
is_digit(C) -> category(C, "Nd").

-spec is_alpha(char()) -> boolean().
is_alpha(C) when C < 16#80 -> (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z);
is_alpha(C) -> category(C, "L").

%% White_Space: the ASCII controls 9 to 13 and space, U+0085, and the
%% separators of category Z
-spec is_space(char()) -> boolean().
is_space(C) when C < 16#80 -> (C >= 16#9 andalso C =< 16#D) orelse C =:= $\s;
is_space(C) -> C =:= 16#85 orelse category(C, "Z").

-spec is_upper(char()) -> boolean().
is_upper(C) when C < 16#80 -> C >= $A andalso C =< $Z;
is_upper(C) -> category(C, "Lu").

-spec is_lower(char()) -> boolean().
is_lower(C) when C < 16#80 -> C >= $a andalso C =< $z;
is_lower(C) -> category(C, "Ll").

-spec to_upper(char()) -> char().
to_upper(C) -> single(string:uppercase([C]), C).

-spec to_lower(char()) -> char().
to_lower(C) -> single(string:lowercase([C]), C).

-spec to_string(char()) -> binary().
to_string(C) -> unicode:characters_to_binary([C]).

-spec to_int(char()) -> integer().
to_int(C) -> C.

%% Char.fromInt has checked the range
-spec from_int(char()) -> char().
from_int(N) -> N.

single([U], _) -> U;
single(_, C) -> C.

category(C, Class) ->
    re:run(<<C/utf8>>, "^\\p{" ++ Class ++ "}$", [unicode]) =/= nomatch.
