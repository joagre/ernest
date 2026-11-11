%% The shims behind Char (report Appendix E.6): the Unicode properties, the
%% case mappings, and the conversions between a Char and its code point,
%% which are one Erlang integer. The properties are read from the host's
%% own tables, unicode_util's, which its string module is built on, so that
%% Char and String follow one version of Unicode; the host's documentation
%% hides that module, which the log's *Char Reads the Host's Tables*
%% weighs.
-module(ern_char).

-export([is_digit/1, is_alpha/1, is_space/1, is_upper/1, is_lower/1, is_mark/1, is_number/1,
         is_punctuation/1, is_symbol/1, is_separator/1, is_control/1, to_upper/1, to_lower/1,
         to_string/1, to_code_point/1, from_code_point/1]).

-spec is_digit(char()) -> boolean().
is_digit(Char) when Char < 16#80 -> Char >= $0 andalso Char =< $9;
is_digit(Char) -> unicode_util:category(Char) =:= {number, decimal}.

-spec is_alpha(char()) -> boolean().
is_alpha(Char) when Char < 16#80 ->
    (Char >= $a andalso Char =< $z) orelse (Char >= $A andalso Char =< $Z);
is_alpha(Char) ->
    case unicode_util:category(Char) of
        {letter, _} -> true;
        _ -> false
    end.

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

-spec is_mark(char()) -> boolean().
is_mark(Char) -> major(Char) =:= mark.

-spec is_number(char()) -> boolean().
is_number(Char) -> major(Char) =:= number.

-spec is_punctuation(char()) -> boolean().
is_punctuation(Char) -> major(Char) =:= punctuation.

-spec is_symbol(char()) -> boolean().
is_symbol(Char) -> major(Char) =:= symbol.

-spec is_separator(char()) -> boolean().
is_separator(Char) -> major(Char) =:= separator.

%% Cc alone, not the rest of the host's `other`: a format character, a
%% surrogate, a private-use or an unassigned code point
-spec is_control(char()) -> boolean().
is_control(Char) -> unicode_util:category(Char) =:= {other, control}.

%% The major class of the character's general category, the first letter of
%% Unicode's two: `letter` for L, `mark` for M, `number` for N
major(Char) ->
    {Major, _} = unicode_util:category(Char),
    Major.

-spec to_upper(char()) -> char().
to_upper(Char) -> single(string:uppercase([Char]), Char).

-spec to_lower(char()) -> char().
to_lower(Char) -> single(string:lowercase([Char]), Char).

-spec to_string(char()) -> binary().
to_string(Char) -> unicode:characters_to_binary([Char]).

-spec to_code_point(char()) -> integer().
to_code_point(Char) -> Char.

%% Char.fromCodePoint has checked the range
-spec from_code_point(char()) -> char().
from_code_point(Code) -> Code.

single([Changed], _) -> Changed;
single(_, Char) -> Char.
