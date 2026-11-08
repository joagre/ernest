%% A value as Ernest writes its literal, report §2.5 and Appendix E.9: a
%% float's shortest digits laid out, and a string and a character with the
%% escapes they need. The runtime's printer of values (ern_show),
%% `Float.toString` and the parser's helps, which write a pattern back,
%% each write a literal so, and the rule is written once, here.
-module(ern_literal).

-export([float_text/1, string_text/1, char_text/1, escape/2]).

%% Report Appendix E.9: the shortest digits that read back as the same
%% value, which float_to_list/2's `short` gives, written plain from 0.0001
%% to below 1.0e16 and as one digit, the point, the rest and the exponent
%% beyond, the exponent's sign only when negative. The same layout in
%% Ernest over the host's shortest form measured 0.93 times this one, both
%% near eight times the host's alone
%% (the log's *The Principles Review of 2026-10-09, the Judgments*).
-spec float_text(float()) -> string().
float_text(Float) when Float < 0 -> [$- | float_text(-Float)];
float_text(Float) when Float == 0 -> "0.0";
float_text(Float) ->
    {Digits, Point} = digits(float_to_list(Float, [short])),
    case Float >= 1.0e-4 andalso Float < 1.0e16 of
        true -> plain(Digits, Point);
        false -> scientific(Digits, Point)
    end.

%% The significant digits of short's text, and where the point stands among
%% them: the value is 0.Digits times ten to Point.
digits(Short) ->
    {Mantissa, Exponent} = case string:split(Short, "e") of
                               [Before, After] -> {Before, list_to_integer(After)};
                               [Before] -> {Before, 0}
                           end,
    [Whole, Fraction] = string:split(Mantissa, "."),
    All = Whole ++ Fraction,
    Leading = length(lists:takewhile(fun(Char) -> Char =:= $0 end, All)),
    Digits = lists:reverse(lists:dropwhile(fun(Char) -> Char =:= $0 end,
                                           lists:reverse(lists:nthtail(Leading, All)))),
    {Digits, length(Whole) - Leading + Exponent}.

plain(Digits, Point) when Point =< 0 ->
    "0." ++ lists:duplicate(-Point, $0) ++ Digits;
plain(Digits, Point) when Point >= length(Digits) ->
    Digits ++ lists:duplicate(Point - length(Digits), $0) ++ ".0";
plain(Digits, Point) ->
    {Whole, Fraction} = lists:split(Point, Digits),
    Whole ++ "." ++ Fraction.

scientific([First | Rest], Point) ->
    [First, $. | case Rest of [] -> "0"; _ -> Rest end] ++ "e" ++ integer_to_list(Point - 1).

-spec string_text(unicode:unicode_binary()) -> unicode:chardata().
string_text(Text) -> [$", [escape(Char, $") || Char <- unicode:characters_to_list(Text)], $"].

-spec char_text(char()) -> unicode:chardata().
char_text(Char) -> [$', escape(Char, $'), $'].

%% Report §2.5: the escapes a literal needs, the quote being the literal's
%% own, or `none` outside a literal.
-spec escape(char(), char() | none) -> unicode:chardata().
escape(Quote, Quote) -> [$\\, Quote];
escape($\\, _) -> "\\\\";
escape($\n, _) -> "\\n";
escape($\t, _) -> "\\t";
escape($\r, _) -> "\\r";
escape(Char, _) when Char < 16#20; Char >= 16#7F, Char =< 16#9F ->
    ["\\u{", integer_to_list(Char, 16), "}"];
escape(Char, _) -> [Char].
