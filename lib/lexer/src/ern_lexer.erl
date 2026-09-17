%% Lexer for Ernest, report section 2. Input is Unicode text; output is a
%% flat token list ending in {eof, Pos}. Every token carries the {Line,
%% Column} of its first character, both 1-based, columns in code points.
%%
%% Tokens: {int | float | char | string | bool | ident | typename | doc,
%% Pos, Value} and {Symbol, Pos} for reserved words, operators, and
%% delimiters. A doc token holds a `///` block joined with "\n"; its last
%% line is Line plus the number of "\n" in the text.
-module(ern_lexer).

-export([tokenize/1, format_error/1]).

-export_type([pos/0, token/0, error/0]).

-type pos() :: {pos_integer(), pos_integer()}.
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
-type error() :: {pos_integer(), pos_integer(), string()}.

-define(RESERVED, [type, abstract, with, foreign, match, 'when', 'receive', 'after',
                   as, 'if', then, 'else', fn, 'let', export]).

%% Longest first, so max-munch is clause order.
-define(SYMBOLS, ["#(", "<<", ">>", "<-", "->", "==", "!=", "<=", ">=", "&&",
                  "||", "|>", "<>", "::", "..",
                  "(", ")", "{", "}", "[", "]", ",", ";", ":", "=", "|", ".",
                  "+", "-", "*", "/", "%", "<", ">"]).

-spec tokenize(unicode:chardata()) -> {ok, [token()]} | {error, error()}.
tokenize(Data) ->
    case unicode:characters_to_list(Data) of
        Chars when is_list(Chars) ->
            try lex(strip_bom(Chars), 1, 1, []) of
                Tokens -> {ok, Tokens}
            catch
                throw:{lex_error, Line, Col, Message} -> {error, {Line, Col, Message}}
            end;
        _ ->
            {error, {1, 1, "input is not valid UTF-8"}}
    end.

-spec format_error(error()) -> string().
format_error({Line, Col, Message}) ->
    lists:flatten(io_lib:format("~B:~B: ~s", [Line, Col, Message])).

strip_bom([16#FEFF | Rest]) -> Rest;
strip_bom(Chars) -> Chars.

%%
%% Main loop. Acc is reversed.
%%

lex([], L, C, Acc) ->
    lists:reverse([{eof, {L, C}} | Acc]);
lex([$\n | R], L, _C, Acc) ->
    lex(R, L + 1, 1, Acc);
lex([Ch | R], L, C, Acc) when Ch =:= $\s; Ch =:= $\t; Ch =:= $\r ->
    lex(R, L, C + 1, Acc);
lex("////" ++ R, L, C, Acc) ->
    lex(skip_line(R), L, C, Acc);
lex("///" ++ R, L, C, Acc) ->
    {Text, Rest, L1} = doc_block(R, L, []),
    lex(Rest, L1, 1, [{doc, {L, C}, Text} | Acc]);
lex("//" ++ R, L, C, Acc) ->
    lex(skip_line(R), L, C, Acc);
lex("/*" ++ R, L, C, Acc) ->
    {Rest, L1, C1} = block_comment(R, 1, L, C + 2, L, C),
    lex(Rest, L1, C1, Acc);
lex([Ch | _] = S, L, C, Acc) when Ch >= $0, Ch =< $9 ->
    {Token, Rest, C1} = number(S, L, C),
    lex(Rest, L, C1, [Token | Acc]);
lex([$" | R], L, C, Acc) ->
    {Chars, Rest, L1, C1} = string_body(R, L, C + 1, L, C, []),
    lex(Rest, L1, C1, [{string, {L, C}, unicode:characters_to_binary(Chars)} | Acc]);
lex([$' | R], L, C, Acc) ->
    {Ch, Rest, C1} = char_body(R, L, C),
    lex(Rest, L, C1, [{char, {L, C}, Ch} | Acc]);
lex([Ch | _] = S, L, C, Acc) when Ch >= $a, Ch =< $z; Ch =:= $_ ->
    {Name, Rest} = take_word(S),
    lex(Rest, L, C + length(Name), [word_token(Name, {L, C}) | Acc]);
lex([Ch | _] = S, L, C, Acc) when Ch >= $A, Ch =< $Z ->
    {Name, Rest} = take_word(S),
    lex(Rest, L, C + length(Name), [{typename, {L, C}, list_to_atom(Name)} | Acc]);
lex(S, L, C, Acc) ->
    case symbol(S, ?SYMBOLS) of
        {Sym, Rest, Len} ->
            lex(Rest, L, C + Len, [{Sym, {L, C}} | Acc]);
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
next_doc_line_start("////" ++ _) -> no;
next_doc_line_start("///" ++ R) -> {yes, R};
next_doc_line_start(_) -> no.

block_comment([], _Depth, _L, _C, L0, C0) ->
    error_at(L0, C0, "unterminated block comment");
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
%% Numbers: int = digit {digit}; float = int "." digit {digit} [exponent].
%%

number(S, L, C) ->
    {Int, R1} = take_digits(S),
    case R1 of
        [$., D | _] when D >= $0, D =< $9 ->
            {Frac, R2} = take_digits(tl(R1)),
            {Exp, R3} = exponent(R2),
            Text = Int ++ "." ++ Frac ++ Exp,
            {{float, {L, C}, list_to_float(Text)}, R3, C + length(Text)};
        _ ->
            {{int, {L, C}, list_to_integer(Int)}, R1, C + length(Int)}
    end.

take_digits(S) -> lists:splitwith(fun(Ch) -> Ch >= $0 andalso Ch =< $9 end, S).

exponent([E, Sign, D | R]) when (E =:= $e orelse E =:= $E),
                                (Sign =:= $+ orelse Sign =:= $-),
                                D >= $0, D =< $9 ->
    {Digits, R1} = take_digits([D | R]),
    {[E, Sign | Digits], R1};
exponent([E, D | R]) when (E =:= $e orelse E =:= $E), D >= $0, D =< $9 ->
    {Digits, R1} = take_digits([D | R]),
    {[E | Digits], R1};
exponent(R) ->
    {"", R}.

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

is_hex(Ch) -> (Ch >= $0 andalso Ch =< $9) orelse (Ch >= $a andalso Ch =< $f)
              orelse (Ch >= $A andalso Ch =< $F).

%%
%% Words: identifiers, type names, reserved words, bool literals, wildcard.
%%

take_word(S) ->
    lists:splitwith(fun is_word_char/1, S).

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

error_at(L, C, Message) ->
    throw({lex_error, L, C, lists:flatten(Message)}).
