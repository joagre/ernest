%% Lexer for Ernest, report section 2. Input is Unicode text; output is a
%% flat token list ending in {eof, Pos}. Every token carries a pos(): the
%% line and column of its first character, both 1-based, columns in code
%% points, then where it ends and where the token before it ended.
%%
%% Tokens: {int | float | char | string | bool | ident | typename | doc,
%% Pos, Value} and {Symbol, Pos} for reserved words, operators, and
%% delimiters. A doc token holds a `///` block joined with "\n"; its last
%% line is Line plus the number of "\n" in the text.
-module(ern_lexer).

-export([tokenize/1]).

-include_lib("utils/include/ern_diag.hrl").

-export_type([pos/0, token/0]).

-type pos() :: ern_diag:pos().
%% line, column, the end (exclusive) as line and column, and the end of the
%% previous token, from which the parser sets a node's end (report §11.5)
-type token() ::
    {int, pos(), integer()}
  | {float, pos(), float()}
  | {char, pos(), char()}
  | {string, pos(), unicode:unicode_binary()}
  | {bool, pos(), boolean()}
  | {ident, pos(), atom()}
  | {typename, pos(), atom()}
  | {doc, pos(), unicode:unicode_binary()}
  | {atom(), pos()}.

-define(RESERVED, [type, abstract, with, foreign, match, 'when', 'receive', 'after', 'or',
                   as, 'if', then, 'else', fn, 'let', export]).

%% Longest first, so max-munch is clause order.
-define(SYMBOLS, ["#(", "<<", ">>", "<-", "->", "==", "!=", "<=", ">=", "&&",
                  "||", "|>", "<>", "::", "..",
                  "(", ")", "{", "}", "[", "]", ",", ";", ":", "=", "|", ".",
                  "+", "-", "*", "/", "%", "<", ">", "!"]).

-spec tokenize(unicode:chardata()) -> {ok, [token()]} | {error, ern_diag:diag()}.
tokenize(Data) ->
    case unicode:characters_to_list(Data) of
        Chars when is_list(Chars) ->
            try lex(strip_bom(Chars), 1, 1, {1, 1}, []) of
                Tokens -> {ok, Tokens}
            catch
                throw:{lex_error, Line, Col, Message, Incomplete} ->
                    {error, #diag{span = {Line, Col, {Line, Col + 1}}, message = Message,
                                  incomplete = Incomplete}}
            end;
        _ ->
            {error, #diag{span = {1, 1, {1, 2}}, message = "input is not valid UTF-8"}}
    end.

strip_bom([16#FEFF | Rest]) -> Rest;
strip_bom(Chars) -> Chars.

%%
%% Main loop. Acc is reversed; Prev is the end of the last token emitted.
%%

lex([], L, C, Prev, Acc) ->
    lists:reverse([{eof, {L, C, {L, C}, Prev}} | Acc]);
lex([$\n | R], L, _C, Prev, Acc) ->
    lex(R, L + 1, 1, Prev, Acc);
lex([Ch | R], L, C, Prev, Acc) when Ch =:= $\s; Ch =:= $\t; Ch =:= $\r ->
    lex(R, L, C + 1, Prev, Acc);
lex("///" ++ R, L, C, Prev, Acc) ->
    {Text, Rest, L1} = doc_block(R, L, []),
    lex(Rest, L1, 1, {L1, 1}, [{doc, {L, C, {L1, 1}, Prev}, Text} | Acc]);
lex("//" ++ R, L, C, Prev, Acc) ->
    lex(skip_line(R), L, C, Prev, Acc);
lex("/*" ++ R, L, C, Prev, Acc) ->
    {Rest, L1, C1} = block_comment(R, 1, L, C + 2, L, C),
    lex(Rest, L1, C1, Prev, Acc);
lex([Ch | _] = S, L, C, Prev, Acc) when Ch >= $0, Ch =< $9 ->
    {Kind, V, Rest, C1} = number(S, L, C),
    %% report §2.5: nothing word-like directly after a number
    case Rest of
        [$_ | _] ->
            error_at(L, C1, "_ must stand between two digits");
        [Next | _] ->
            case is_word_char(Next) of
                true -> error_at(L, C1, [Next] ++ " cannot follow a number directly");
                false -> ok
            end;
        [] ->
            ok
    end,
    lex(Rest, L, C1, {L, C1}, [{Kind, {L, C, {L, C1}, Prev}, V} | Acc]);
lex([$" | R], L, C, Prev, Acc) ->
    {Chars, Rest, L1, C1} = string_body(R, L, C + 1, L, C, []),
    lex(Rest, L1, C1, {L1, C1},
        [{string, {L, C, {L1, C1}, Prev}, unicode:characters_to_binary(Chars)} | Acc]);
lex([$` | R], L, C, Prev, Acc) ->
    %% report §2.5: a raw string, no escapes, may span lines
    {Chars, Rest, L1, C1} = raw_body(R, L, C + 1, L, C, []),
    lex(Rest, L1, C1, {L1, C1},
        [{string, {L, C, {L1, C1}, Prev}, unicode:characters_to_binary(Chars)} | Acc]);
lex([$' | R], L, C, Prev, Acc) ->
    {Ch, Rest, C1} = char_body(R, L, C),
    lex(Rest, L, C1, {L, C1}, [{char, {L, C, {L, C1}, Prev}, Ch} | Acc]);
lex([Ch | _] = S, L, C, Prev, Acc) when Ch >= $a, Ch =< $z; Ch =:= $_ ->
    {Name, Rest} = take_word(S, L, C),
    C1 = C + length(Name),
    lex(Rest, L, C1, {L, C1}, [word_token(Name, {L, C, {L, C1}, Prev}) | Acc]);
lex([Ch | _] = S, L, C, Prev, Acc) when Ch >= $A, Ch =< $Z ->
    {Name, Rest} = take_word(S, L, C),
    C1 = C + length(Name),
    lex(Rest, L, C1, {L, C1}, [{typename, {L, C, {L, C1}, Prev}, list_to_atom(Name)} | Acc]);
lex(S, L, C, Prev, Acc) ->
    case symbol(S, ?SYMBOLS) of
        {Sym, Rest, Len} ->
            lex(Rest, L, C + Len, {L, C + Len}, [{Sym, {L, C, {L, C + Len}, Prev}} | Acc]);
        none ->
            error_at(L, C, io_lib:format("illegal character '~ts'", [[hd(S)]]))
    end.

%%
%% Comments
%%

skip_line([$\n | _] = R) -> R;
skip_line([_ | R]) -> skip_line(R);
skip_line([]) -> [].

%% Consecutive /// lines join with "\n". One space after /// is dropped.
%% Returns the rest starting at the line after the block.
doc_block(S, L, Lines) ->
    S1 = case S of [$\s | R0] -> R0; _ -> S end,
    {Line, Rest} = take_line(S1),
    Lines1 = [Line | Lines],
    case next_doc_line(Rest) of
        {yes, Rest1} -> doc_block(Rest1, L + 1, Lines1);
        no -> {unicode:characters_to_binary(lists:join($\n, lists:reverse(Lines1))),
               after_newline(Rest), L + 1}
    end.

take_line(S) -> take_line(S, []).

take_line([$\n | _] = R, Acc) -> {strip_cr(lists:reverse(Acc)), R};
take_line([], Acc) -> {strip_cr(lists:reverse(Acc)), []};
take_line([Ch | R], Acc) -> take_line(R, [Ch | Acc]).

strip_cr(Line) ->
    case lists:reverse(Line) of
        [$\r | R] -> lists:reverse(R);
        _ -> Line
    end.

after_newline([$\n | R]) -> R;
after_newline(R) -> R.

%% Is the next line (after optional blanks) another /// line?
next_doc_line([$\n | R]) -> next_doc_line_start(R);
next_doc_line(_) -> no.

next_doc_line_start([Ch | R]) when Ch =:= $\s; Ch =:= $\t; Ch =:= $\r ->
    next_doc_line_start(R);
next_doc_line_start("///" ++ R) -> {yes, R};
next_doc_line_start(_) -> no.

block_comment([], _Depth, _L, _C, L0, C0) ->
    unfinished_at(L0, C0, "unterminated block comment");
block_comment("*/" ++ R, 1, L, C, _L0, _C0) ->
    {R, L, C + 2};
block_comment("*/" ++ R, Depth, L, C, L0, C0) ->
    block_comment(R, Depth - 1, L, C + 2, L0, C0);
block_comment("/*" ++ R, Depth, L, C, L0, C0) ->
    block_comment(R, Depth + 1, L, C + 2, L0, C0);
block_comment([$\n | R], Depth, L, _C, L0, C0) ->
    block_comment(R, Depth, L + 1, 1, L0, C0);
block_comment([_ | R], Depth, L, C, L0, C0) ->
    block_comment(R, Depth, L, C + 1, L0, C0).

%%
%% Numbers, report §2.5: int = decimal | "0x" hexdigit {["_"] hexdigit} |
%% "0o" ... | "0b" ...; float = decimal "." decimal [exponent]; decimal =
%% digit {["_"] digit}. Returns the kind, the value, the rest, and the
%% column after the text, underscores counted.
%%

number([$0, P | R], L, C) when P =:= $x; P =:= $o; P =:= $b ->
    {Base, Name} = case P of
                       $x -> {16, "hexadecimal"};
                       $o -> {8, "octal"};
                       $b -> {2, "binary"}
                   end,
    {Digits, N, R1} = digits(R, fun(Ch) -> digit_value(Ch) < Base end),
    case {Digits, R} of
        {[], [$_ | _]} -> error_at(L, C + 2, "_ must stand between two digits");
        {[], _} -> error_at(L, C, [$0, P] ++ " needs a " ++ Name ++ " digit");
        _ -> ok
    end,
    End = C + 2 + N,
    case R1 of
        [Ch | _] when Ch =/= $_ ->
            case is_word_char(Ch) of
                true -> error_at(L, End, [Ch] ++ " is not a " ++ Name ++ " digit");
                false -> ok
            end;
        _ ->
            ok
    end,
    {int, list_to_integer(Digits, Base), R1, End};
number([$0, P | _], L, C) when P =:= $X; P =:= $O; P =:= $B ->
    error_at(L, C, "a base prefix is lowercase: 0" ++ [P + 32]);
number(S, L, C) ->
    {Int, N1, R1} = digits(S, fun is_digit/1),
    case R1 of
        [$., D | _] when D >= $0, D =< $9 ->
            {Frac, N2, R2} = digits(tl(R1), fun is_digit/1),
            {Exp, N3, R3} = exponent(R2),
            Text = Int ++ "." ++ Frac ++ Exp,
            {float, float_value(Text, L, C), R3, C + N1 + 1 + N2 + N3};
        _ ->
            {int, list_to_integer(Int), R1, C + N1}
    end.

%% A float literal's value, rounded to the nearest Float. One that rounds
%% beyond the largest finite Float is an error at the literal (report §2.5);
%% one that rounds below the smallest is 0.0.
float_value(Text, L, C) ->
    try
        list_to_float(Text)
    catch
        error:badarg -> error_at(L, C, "the float literal is beyond the largest finite Float")
    end.

%% The digits Pred accepts, a single `_` allowed between two of them: the
%% digits without it, the characters consumed, and the rest. An `_` that
%% does not stand between two digits is left in the rest.
digits(S, Pred) ->
    digits(S, Pred, [], 0).

digits([$_, D | R], Pred, Acc, N) when Acc =/= [] ->
    case Pred(D) of
        true -> digits(R, Pred, [D | Acc], N + 2);
        false -> {lists:reverse(Acc), N, [$_, D | R]}
    end;
digits([D | R] = S, Pred, Acc, N) ->
    case Pred(D) of
        true -> digits(R, Pred, [D | Acc], N + 1);
        false -> {lists:reverse(Acc), N, S}
    end;
digits([], _, Acc, N) ->
    {lists:reverse(Acc), N, []}.

is_digit(Ch) -> digit_value(Ch) < 10.

is_hex(Ch) -> digit_value(Ch) < 16.

digit_value(Ch) when Ch >= $0, Ch =< $9 -> Ch - $0;
digit_value(Ch) when Ch >= $a, Ch =< $f -> Ch - $a + 10;
digit_value(Ch) when Ch >= $A, Ch =< $F -> Ch - $A + 10;
digit_value(_) -> 99.

exponent([E, Sign, D | R]) when (E =:= $e orelse E =:= $E),
                                (Sign =:= $+ orelse Sign =:= $-),
                                D >= $0, D =< $9 ->
    {Digits, N, R1} = digits([D | R], fun is_digit/1),
    {[E, Sign | Digits], N + 2, R1};
exponent([E, D | R]) when (E =:= $e orelse E =:= $E), D >= $0, D =< $9 ->
    {Digits, N, R1} = digits([D | R], fun is_digit/1),
    {[E | Digits], N + 1, R1};
exponent(R) ->
    {"", 0, R}.

%%
%% Strings and chars. Content excludes the quote, backslash, LF, and CR.
%%

string_body([], _L, _C, L0, C0, _Acc) ->
    error_at(L0, C0, "unterminated string literal");
string_body([$" | R], L, C, _L0, _C0, Acc) ->
    {lists:reverse(Acc), R, L, C + 1};
string_body([Ch | _], L, C, _L0, _C0, _Acc) when Ch =:= $\n; Ch =:= $\r ->
    error_at(L, C, "newline in string literal; use \\n");
string_body([$\\ | R], L, C, L0, C0, Acc) ->
    {Ch, R1, Len} = escape(R, L, C),
    string_body(R1, L, C + 1 + Len, L0, C0, [Ch | Acc]);
string_body([Ch | R], L, C, L0, C0, Acc) ->
    string_body(R, L, C + 1, L0, C0, [Ch | Acc]).

%% Report §2.5: everything up to the next backtick, a line break being a
%% line feed and a carriage return before it dropped.
raw_body([], _L, _C, L0, C0, _Acc) ->
    unfinished_at(L0, C0, "unterminated raw string");
raw_body([$` | R], L, C, _L0, _C0, Acc) ->
    {lists:reverse(Acc), R, L, C + 1};
raw_body([$\r, $\n | R], L, _C, L0, C0, Acc) ->
    raw_body(R, L + 1, 1, L0, C0, [$\n | Acc]);
raw_body([$\n | R], L, _C, L0, C0, Acc) ->
    raw_body(R, L + 1, 1, L0, C0, [$\n | Acc]);
raw_body([Ch | R], L, C, L0, C0, Acc) ->
    raw_body(R, L, C + 1, L0, C0, [Ch | Acc]).

char_body([$\\ | R], L, C) ->
    {Ch, R1, Len} = escape(R, L, C + 1),
    close_char(Ch, R1, L, C, C + 2 + Len);
char_body([$' | _], L, C) ->
    error_at(L, C, "empty char literal");
char_body([Ch | _], L, C) when Ch =:= $\n; Ch =:= $\r ->
    error_at(L, C, "newline in char literal; use '\\n'");
char_body([Ch | R], L, C) ->
    close_char(Ch, R, L, C, C + 2);
char_body([], L, C) ->
    error_at(L, C, "unterminated char literal").

close_char(Ch, [$' | R], _L, _C0, C1) -> {Ch, R, C1 + 1};
close_char(_Ch, _R, L, C0, _C1) -> error_at(L, C0, "unterminated char literal").

%% After the backslash. Returns {CodePoint, Rest, CharsConsumedAfterBackslash}.
escape([$' | R], _L, _C) -> {$', R, 1};
escape([$" | R], _L, _C) -> {$", R, 1};
escape([$\\ | R], _L, _C) -> {$\\, R, 1};
escape([$n | R], _L, _C) -> {$\n, R, 1};
escape([$r | R], _L, _C) -> {$\r, R, 1};
escape([$t | R], _L, _C) -> {$\t, R, 1};
escape([$u, ${ | R], L, C) ->
    {Hex, R1} = lists:splitwith(fun is_hex/1, R),
    case {Hex, R1} of
        {[], _} -> error_at(L, C, "\\u{ needs one to six hex digits");
        {_, [$} | R2]} when length(Hex) =< 6 ->
            Cp = list_to_integer(Hex, 16),
            case Cp =< 16#10FFFF andalso not (Cp >= 16#D800 andalso Cp =< 16#DFFF) of
                true -> {Cp, R2, 3 + length(Hex)};
                false -> error_at(L, C, "\\u{" ++ Hex ++ "} is not a Unicode scalar value")
            end;
        _ -> error_at(L, C, "\\u{ needs one to six hex digits followed by }")
    end;
escape([Ch | _], L, C) ->
    error_at(L, C, io_lib:format("unknown escape \\~ts", [[Ch]]));
escape([], L, C) ->
    error_at(L, C, "unterminated escape").

%%
%% Words: identifiers, type names, reserved words, bool literals, wildcard.
%%

%% Report §2.3: a word is at most 255 characters long.
take_word(S, L, C) ->
    {Name, Rest} = lists:splitwith(fun is_word_char/1, S),
    case length(Name) =< 255 of
        true -> {Name, Rest};
        false -> error_at(L, C, "a name is at most 255 characters long")
    end.

is_word_char(Ch) -> (Ch >= $a andalso Ch =< $z) orelse (Ch >= $A andalso Ch =< $Z)
                    orelse (Ch >= $0 andalso Ch =< $9) orelse Ch =:= $_.

word_token("_", Pos) -> {'_', Pos};
word_token("true", Pos) -> {bool, Pos, true};
word_token("false", Pos) -> {bool, Pos, false};
word_token(Name, Pos) ->
    Atom = list_to_atom(Name),
    case lists:member(Atom, ?RESERVED) of
        true -> {Atom, Pos};
        false -> {ident, Pos, Atom}
    end.

%%
%% Symbols
%%

symbol(_S, []) ->
    none;
symbol(S, [Sym | Syms]) ->
    case lists:prefix(Sym, S) of
        true -> {list_to_atom(Sym), lists:nthtail(length(Sym), S), length(Sym)};
        false -> symbol(S, Syms)
    end.

%%
%% Errors
%%

error_at(L, C, Message) ->
    throw({lex_error, L, C, lists:flatten(Message), false}).

%% Report §11.2, §2.5: a raw string and a block comment may span lines, so
%% more input can finish one, and the diagnostic says so; a string or a
%% char literal may not, and an unfinished one is an error whatever follows.
unfinished_at(L, C, Message) ->
    throw({lex_error, L, C, Message, true}).
