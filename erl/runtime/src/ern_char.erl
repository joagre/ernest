%% The shims behind Char (report Appendix E.6): the Unicode properties, the
%% case mappings, and the conversions between a Char and its code point,
%% which are one Erlang integer. The properties are read from the host's
%% own tables, unicode_util's, which its string module is built on, so that
%% Char and String follow one version of Unicode; the host's documentation
%% hides that module, which the log's *Char Reads the Host's Tables*
%% weighs.
-module(ern_char).

-export([is_digit/1, is_alpha/1, is_space/1, is_upper/1, is_lower/1, to_upper/1, to_lower/1,
         to_string/1, to_int/1, from_int/1]).

-spec is_digit(char()) -> boolean().
is_digit(Char) when Char < 16#80 -> Char >= $0 andalso Char =< $9;
is_digit(Char) -> unicode_util:category(Char) =:= {number, decimal}.

-spec is_alpha(char()) -> boolean().
is_alpha(Char) when Char < 16#80 ->
    (Char >= $a andalso Char =< $z) orelse (Char >= $A andalso Char =< $Z);
is_alpha(Char) -> element(1, unicode_util:category(Char)) =:= letter.

%% White_Space: the ASCII controls 9 to 13 and space, U+0085, and the
%% separators of category Z
-spec is_space(char()) -> boolean().
is_space(Char) -> unicode_util:is_whitespace(Char).

-spec is_upper(char()) -> boolean().
is_upper(Char) when Char < 16#80 -> Char >= $A andalso Char =< $Z;
is_upper(Char) -> unicode_util:category(Char) =:= {letter, uppercase}.

-spec is_lower(char()) -> boolean().
is_lower(Char) when Char < 16#80 -> Char >= $a andalso Char =< $z;
is_lower(Char) -> unicode_util:category(Char) =:= {letter, lowercase}.

-spec to_upper(char()) -> char().
to_upper(Char) -> single(string:uppercase([Char]), Char).

-spec to_lower(char()) -> char().
to_lower(Char) -> single(string:lowercase([Char]), Char).

-spec to_string(char()) -> binary().
to_string(Char) -> unicode:characters_to_binary([Char]).

-spec to_int(char()) -> integer().
to_int(Char) -> Char.

%% Char.fromInt has checked the range
-spec from_int(char()) -> char().
from_int(Code) -> Code.

single([Changed], _) -> Changed;
single(_, Char) -> Char.
