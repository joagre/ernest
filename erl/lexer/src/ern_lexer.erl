%% Lexer for Ernest, report section 2. Input is Unicode text; output is a
%% flat token list ending in {eof, Position}. Every token carries a
%% position(): the line and column of its first character, both 1-based,
%% columns in code points, then where it ends and where the token before it
%% ended.
%%
%% Tokens: {int | float | char | string | bool | ident | typename | doc,
%% Position, Value} and {Symbol, Position} for reserved words, operators,
%% and delimiters. A doc token holds a `///` block joined with "\n"; its
%% last line is Line plus the number of "\n" in the text. With `comments`,
%% an ordinary comment is a token {comment, Position, Text} too
%% (tokenize/2).
-module(ern_lexer).

-export([tokenize/1, tokenize/2]).

-include_lib("utils/include/ern_diagnostic.hrl").

-export_type([position/0, token/0]).

-type position() :: ern_diagnostic:position().
%% line, column, the end (exclusive) as line and column, and the end of the
%% previous token, from which the parser sets a node's end (report §11.5)
-type token() ::
    {int, position(), integer()}
  | {float, position(), float()}
  | {char, position(), char()}
  | {string, position(), unicode:unicode_binary()}
  | {bool, position(), boolean()}
  | {ident, position(), atom()}
  | {typename, position(), atom()}
  | {doc, position(), unicode:unicode_binary()}
  | {comment, position(), unicode:unicode_binary()}
  | {atom(), position()}.

-define(RESERVED, [type, abstract, with, foreign, derives, match, 'when', 'receive', 'after',
                   'or', as, 'if', then, 'else', fn, 'let', needs, export]).

%% Longest first, so max-munch is clause order.
-define(SYMBOLS, ["#(", "<<", ">>", "<-", "->", "==", "!=", "<=", ">=", "&&",
                  "||", "|>", "<>", "::", "..",
                  "(", ")", "{", "}", "[", "]", ",", ";", ":", "=", "|", ".",
                  "+", "-", "*", "/", "%", "<", ">", "!"]).

-spec tokenize(unicode:chardata()) -> {ok, [token()]} | {error, ern_diagnostic:diagnostic()}.
tokenize(Source) ->
    tokenize(Source, []).

%% With `comments`, every ordinary comment is a token too, `{comment,
%% Position, Text}` with the text as written, for the formatter (report
%% §11.6); it moves no other token's previous end, so the parser's spans
%% are the same. With `no_new_names`, a name the host has not met is the
%% stand-in `'$unmet'`: the host keeps a name it has met for ever, so text
%% that is read and not run, a line being typed, is read so (report §11.2).
-spec tokenize(unicode:chardata(), [comments | no_new_names]) ->
          {ok, [token()]} | {error, ern_diagnostic:diagnostic()}.
tokenize(Source, Options) ->
    case unicode:characters_to_list(Source) of
        Chars when is_list(Chars) ->
            Text = without_bom(Chars),
            try refuse_controls(Text, 1, 1), lex(Text, 1, 1, {1, 1}, [], Options) of
                Tokens -> {ok, Tokens}
            catch
                throw:{lex_error, Diagnostic} -> {error, Diagnostic}
            end;
        {_, Decoded, _} ->
            {Line, Column} = place(without_bom(Decoded), 1, 1),
            {error, diagnostic(Line, Column, "input is not valid UTF-8", false)}
    end.

%% Report §2.1: where the byte after the characters stands, the first that
%% begins no UTF-8 character.
place([], Line, Column) -> {Line, Column};
place([$\n | Rest], Line, _) -> place(Rest, Line + 1, 1);
place([_ | Rest], Line, Column) -> place(Rest, Line, Column + 1).

without_bom([16#FEFF | Rest]) -> Rest;
without_bom(Chars) -> Chars.

%% Report §2.1: a control character but tab, line feed and carriage return
%% is an error wherever it stands, a comment and a doc block among them,
%% so that no source carries one to a terminal.
refuse_controls([], _, _) ->
    ok;
refuse_controls([$\n | Rest], Line, _) ->
    refuse_controls(Rest, Line + 1, 1);
refuse_controls([Char | _], Line, Column) when Char < 16#20, Char =/= $\t, Char =/= $\r;
                                               Char >= 16#7F, Char =< 16#9F ->
    error_at(Line, Column, io_lib:format("control character U+~4.16.0B; a string or a character"
                                         " literal writes it `\\u{~.16B}`", [Char, Char]));
refuse_controls([_ | Rest], Line, Column) ->
    refuse_controls(Rest, Line, Column + 1).

%%
%% Main loop. Acc is reversed; PreviousEnd is the end of the last token
%% emitted.
%%

lex([], Line, Column, PreviousEnd, Acc, _KeepComments) ->
    lists:reverse([{eof, {Line, Column, {Line, Column}, PreviousEnd}} | Acc]);
lex([$\n | Rest], Line, _Column, PreviousEnd, Acc, Options) ->
    lex(Rest, Line + 1, 1, PreviousEnd, Acc, Options);
lex([Char | Rest], Line, Column, PreviousEnd, Acc, Options)
  when Char =:= $\s; Char =:= $\t; Char =:= $\r ->
    lex(Rest, Line, Column + 1, PreviousEnd, Acc, Options);
%% report §2.2: `///` begins a doc comment and `////` an ordinary one
lex("////" ++ Rest, Line, Column, PreviousEnd, Acc, Options) ->
    lex_line_comment("////", Rest, Line, Column, PreviousEnd, Acc, Options);
lex("///" ++ Rest, Line, Column, PreviousEnd, Acc, Options) ->
    is_after_token(Acc, Line) andalso
        error_at(Line, Column, "a doc comment `///` stands on a line of its own; a note after"
                               " code is written `//`"),
    {Text, Rest1, EndLine} = doc_block(Rest, Line, []),
    lex(Rest1, EndLine, 1, {EndLine, 1},
        [{doc, {Line, Column, {EndLine, 1}, PreviousEnd}, Text} | Acc], Options);
lex("//" ++ Rest, Line, Column, PreviousEnd, Acc, Options) ->
    lex_line_comment("//", Rest, Line, Column, PreviousEnd, Acc, Options);
lex("/*" ++ Rest, Line, Column, PreviousEnd, Acc, Options) ->
    {Text, Rest1, EndLine, EndColumn} =
        block_comment(Rest, 1, Line, Column + 2, Line, Column, "*/"),
    Position = {Line, Column, {EndLine, EndColumn}, PreviousEnd},
    lex(Rest1, EndLine, EndColumn, PreviousEnd,
        with_comment(lists:member(comments, Options), Text, Position, Acc), Options);
lex([Char | _] = Input, Line, Column, PreviousEnd, Acc, Options)
  when Char >= $0, Char =< $9 ->
    {Kind, Value, Rest, EndColumn} = number(Input, Line, Column),
    refuse_word_after_number(Rest, Line, EndColumn),
    lex(Rest, Line, EndColumn, {Line, EndColumn},
        [{Kind, {Line, Column, {Line, EndColumn}, PreviousEnd}, Value} | Acc], Options);
lex([$" | Rest], Line, Column, PreviousEnd, Acc, Options) ->
    {Chars, Rest1, EndLine, EndColumn} = string_body(Rest, Line, Column + 1, Line, Column, []),
    lex(Rest1, EndLine, EndColumn, {EndLine, EndColumn},
        [{string, {Line, Column, {EndLine, EndColumn}, PreviousEnd},
          unicode:characters_to_binary(Chars)} | Acc], Options);
lex([$` | Rest], Line, Column, PreviousEnd, Acc, Options) ->
    %% report §2.5: a raw string, no escapes, may span lines
    {Chars, Rest1, EndLine, EndColumn} = raw_body(Rest, Line, Column + 1, Line, Column, []),
    lex(Rest1, EndLine, EndColumn, {EndLine, EndColumn},
        [{string, {Line, Column, {EndLine, EndColumn}, PreviousEnd},
          unicode:characters_to_binary(Chars)} | Acc], Options);
lex([$' | Rest], Line, Column, PreviousEnd, Acc, Options) ->
    {Char, Rest1, EndColumn} = char_body(Rest, Line, Column),
    lex(Rest1, Line, EndColumn, {Line, EndColumn},
        [{char, {Line, Column, {Line, EndColumn}, PreviousEnd}, Char} | Acc], Options);
lex([Char | _] = Input, Line, Column, PreviousEnd, Acc, Options)
  when Char >= $a, Char =< $z; Char =:= $_ ->
    {Name, Rest} = word(Input, Line, Column),
    EndColumn = Column + length(Name),
    lex(Rest, Line, EndColumn, {Line, EndColumn},
        [word_token(Name, {Line, Column, {Line, EndColumn}, PreviousEnd}, Options) | Acc],
        Options);
lex([Char | _] = Input, Line, Column, PreviousEnd, Acc, Options)
  when Char >= $A, Char =< $Z ->
    {Name, Rest} = word(Input, Line, Column),
    EndColumn = Column + length(Name),
    lex(Rest, Line, EndColumn, {Line, EndColumn},
        [{typename, {Line, Column, {Line, EndColumn}, PreviousEnd}, name(Name, Options)} | Acc],
        Options);
lex(Input, Line, Column, PreviousEnd, Acc, Options) ->
    case symbol(Input, ?SYMBOLS) of
        {Symbol, Rest, Length} ->
            EndColumn = Column + Length,
            lex(Rest, Line, EndColumn, {Line, EndColumn},
                [{Symbol, {Line, Column, {Line, EndColumn}, PreviousEnd}} | Acc], Options);
        none ->
            error_at(Line, Column, io_lib:format("illegal character '~ts'", [[hd(Input)]]))
    end.

%%
%% Comments
%%

%% A `//` or `////` comment runs to the end of its line.
lex_line_comment(Opener, Input, Line, Column, PreviousEnd, Acc, Options) ->
    {Body, Rest} = line(Input),
    Text = Opener ++ Body,
    EndColumn = Column + length(Text),
    lex(Rest, Line, EndColumn, PreviousEnd,
        with_comment(lists:member(comments, Options), Text,
                     {Line, Column, {Line, EndColumn}, PreviousEnd}, Acc),
        Options).

%% Report §2.2: whether a token stands before this point on the line.
is_after_token([{Kind, _, _} | Before], Line) when Kind =:= comment; Kind =:= doc ->
    is_after_token(Before, Line);
is_after_token([Token | _], Line) ->
    {_, _, {EndLine, _}, _} = element(2, Token),
    EndLine =:= Line;
is_after_token([], _Line) ->
    false.

with_comment(true, Text, Position, Acc) ->
    [{comment, Position, unicode:characters_to_binary(Text)} | Acc];
with_comment(false, _Text, _Position, Acc) ->
    Acc.

%% Consecutive /// lines join with "\n". One space after /// is dropped.
%% Returns the rest starting at the line after the block.
doc_block(Input, Line, DocLines) ->
    Content = case Input of [$\s | Rest] -> Rest; _ -> Input end,
    {DocLine, Rest1} = line(Content),
    DocLines1 = [DocLine | DocLines],
    case next_doc_line(Rest1) of
        {yes, Rest2} -> doc_block(Rest2, Line + 1, DocLines1);
        no -> {unicode:characters_to_binary(lists:join($\n, lists:reverse(DocLines1))),
               after_newline(Rest1), Line + 1}
    end.

line(Input) -> line(Input, []).

line([$\n | _] = Rest, Acc) -> {without_return(lists:reverse(Acc)), Rest};
line([], Acc) -> {without_return(lists:reverse(Acc)), []};
line([Char | Rest], Acc) -> line(Rest, [Char | Acc]).

without_return(Line) ->
    case lists:reverse(Line) of
        [$\r | Rest] -> lists:reverse(Rest);
        _ -> Line
    end.

after_newline([$\n | Rest]) -> Rest;
after_newline(Rest) -> Rest.

%% Is the next line (after optional blanks) another /// line?
next_doc_line([$\n | Rest]) -> next_doc_line_start(Rest);
next_doc_line(_) -> no.

next_doc_line_start([Char | Rest]) when Char =:= $\s; Char =:= $\t; Char =:= $\r ->
    next_doc_line_start(Rest);
next_doc_line_start("////" ++ _) -> no;
next_doc_line_start("///" ++ Rest) -> {yes, Rest};
next_doc_line_start(_) -> no.

%% A block comment's text, from its `/*` to its `*/`, gathered reversed in
%% Seen as it is read, and what follows it.
block_comment([], _Depth, _Line, _Column, StartLine, StartColumn, _Seen) ->
    unfinished_at(StartLine, StartColumn, "unterminated block comment");
block_comment("*/" ++ Rest, 1, Line, Column, _StartLine, _StartColumn, Seen) ->
    {lists:reverse("/*" ++ Seen), Rest, Line, Column + 2};
block_comment("*/" ++ Rest, Depth, Line, Column, StartLine, StartColumn, Seen) ->
    block_comment(Rest, Depth - 1, Line, Column + 2, StartLine, StartColumn, "/*" ++ Seen);
block_comment("/*" ++ Rest, Depth, Line, Column, StartLine, StartColumn, Seen) ->
    block_comment(Rest, Depth + 1, Line, Column + 2, StartLine, StartColumn, "*/" ++ Seen);
block_comment([$\n | Rest], Depth, Line, _Column, StartLine, StartColumn, Seen) ->
    block_comment(Rest, Depth, Line + 1, 1, StartLine, StartColumn, [$\n | Seen]);
block_comment([Char | Rest], Depth, Line, Column, StartLine, StartColumn, Seen) ->
    block_comment(Rest, Depth, Line, Column + 1, StartLine, StartColumn, [Char | Seen]).

%%
%% Numbers, report §2.5: int = decimal | "0x" hexdigit {["_"] hexdigit} |
%% "0o" ... | "0b" ...; float = decimal ("." decimal [exponent] | exponent); decimal =
%% digit {["_"] digit}. Returns the kind, the value, the rest, and the
%% column after the text, underscores counted.
%%

number([$0, Prefix | Rest], Line, Column) when Prefix =:= $x; Prefix =:= $o; Prefix =:= $b ->
    {Base, Name} = case Prefix of
                       $x -> {16, "hexadecimal"};
                       $o -> {8, "octal"};
                       $b -> {2, "binary"}
                   end,
    {Digits, Consumed, Rest1} = digits(Rest, fun(Char) -> digit_value(Char) < Base end),
    case {Digits, Rest} of
        {[], [$_ | _]} -> error_at(Line, Column + 2, "_ must stand between two digits");
        {[], _} -> error_at(Line, Column, [$0, Prefix] ++ " needs a " ++ Name ++ " digit");
        _ -> ok
    end,
    EndColumn = Column + 2 + Consumed,
    case Rest1 of
        [Char | _] when Char =/= $_ ->
            case is_word_char(Char) of
                true -> error_at(Line, EndColumn, [Char] ++ " is not a " ++ Name ++ " digit");
                false -> ok
            end;
        _ ->
            ok
    end,
    {int, list_to_integer(Digits, Base), Rest1, EndColumn};
number([$0, Prefix | _], Line, Column) when Prefix =:= $X; Prefix =:= $O; Prefix =:= $B ->
    error_at(Line, Column, "a base prefix is lowercase: 0" ++ [Prefix + 32]);
number(Input, Line, Column) ->
    {Whole, WholeWidth, AfterWhole} = digits(Input, fun is_digit/1),
    case AfterWhole of
        [$., Digit | _] when Digit >= $0, Digit =< $9 ->
            {Fraction, FractionWidth, AfterFraction} = digits(tl(AfterWhole), fun is_digit/1),
            {Exponent, ExponentWidth, AfterExponent} = exponent(AfterFraction),
            Text = Whole ++ "." ++ Fraction ++ Exponent,
            {float, float_value(Text, Line, Column), AfterExponent,
             Column + WholeWidth + 1 + FractionWidth + ExponentWidth};
        _ ->
            case exponent(AfterWhole) of
                {"", 0, _} ->
                    {int, list_to_integer(Whole), AfterWhole, Column + WholeWidth};
                %% report §2.5: an exponent alone makes a float, `1e10`;
                %% the host reads a float only with its point
                {Exponent, ExponentWidth, AfterExponent} ->
                    {float, float_value(Whole ++ ".0" ++ Exponent, Line, Column), AfterExponent,
                     Column + WholeWidth + ExponentWidth}
            end
    end.

%% Report §2.5: nothing word-like directly after a number.
refuse_word_after_number([$_ | _], Line, Column) ->
    error_at(Line, Column, "_ must stand between two digits");
refuse_word_after_number([Next | _], Line, Column) ->
    case is_word_char(Next) of
        true -> error_at(Line, Column, [Next] ++ " cannot follow a number directly");
        false -> ok
    end;
refuse_word_after_number([], _, _) ->
    ok.

%% A float literal's value, rounded to the nearest Float. One that rounds
%% beyond the largest finite Float is an error at the literal (report §2.5);
%% one that rounds below the smallest is 0.0.
float_value(Text, Line, Column) ->
    try
        list_to_float(Text)
    catch
        error:badarg ->
            error_at(Line, Column, "the float literal is beyond the largest finite Float")
    end.

%% The digits IsDigit accepts, a single `_` allowed between two of them:
%% the digits without it, the characters consumed, and the rest. An `_`
%% that does not stand between two digits is left in the rest.
digits(Input, IsDigit) ->
    digits(Input, IsDigit, [], 0).

digits([$_, Digit | Rest], IsDigit, Acc, Consumed) when Acc =/= [] ->
    case IsDigit(Digit) of
        true -> digits(Rest, IsDigit, [Digit | Acc], Consumed + 2);
        false -> {lists:reverse(Acc), Consumed, [$_, Digit | Rest]}
    end;
digits([Digit | Rest] = Input, IsDigit, Acc, Consumed) ->
    case IsDigit(Digit) of
        true -> digits(Rest, IsDigit, [Digit | Acc], Consumed + 1);
        false -> {lists:reverse(Acc), Consumed, Input}
    end;
digits([], _, Acc, Consumed) ->
    {lists:reverse(Acc), Consumed, []}.

is_digit(Char) -> digit_value(Char) < 10.

is_hex(Char) -> digit_value(Char) < 16.

digit_value(Char) when Char >= $0, Char =< $9 -> Char - $0;
digit_value(Char) when Char >= $a, Char =< $f -> Char - $a + 10;
digit_value(Char) when Char >= $A, Char =< $F -> Char - $A + 10;
digit_value(_) -> 99.

exponent([Marker, Sign, Digit | Rest]) when (Marker =:= $e orelse Marker =:= $E),
                                            (Sign =:= $+ orelse Sign =:= $-),
                                            Digit >= $0, Digit =< $9 ->
    {Digits, Consumed, Rest1} = digits([Digit | Rest], fun is_digit/1),
    {[Marker, Sign | Digits], Consumed + 2, Rest1};
exponent([Marker, Digit | Rest]) when (Marker =:= $e orelse Marker =:= $E),
                                      Digit >= $0, Digit =< $9 ->
    {Digits, Consumed, Rest1} = digits([Digit | Rest], fun is_digit/1),
    {[Marker | Digits], Consumed + 1, Rest1};
exponent(Rest) ->
    {"", 0, Rest}.

%%
%% Strings and chars. Content excludes the quote, backslash, LF, and CR.
%%

string_body([], _Line, _Column, StartLine, StartColumn, _Acc) ->
    error_at(StartLine, StartColumn, "unterminated string literal");
string_body([$" | Rest], Line, Column, _StartLine, _StartColumn, Acc) ->
    {lists:reverse(Acc), Rest, Line, Column + 1};
string_body([Char | _], Line, Column, _StartLine, _StartColumn, _Acc)
  when Char =:= $\n; Char =:= $\r ->
    error_at(Line, Column, "newline in string literal; use \\n");
string_body([$\\ | Rest], Line, Column, StartLine, StartColumn, Acc) ->
    {Char, Rest1, Length} = escape(Rest, Line, Column),
    string_body(Rest1, Line, Column + 1 + Length, StartLine, StartColumn, [Char | Acc]);
string_body([Char | Rest], Line, Column, StartLine, StartColumn, Acc) ->
    string_body(Rest, Line, Column + 1, StartLine, StartColumn, [Char | Acc]).

%% Report §2.5: everything up to the next backtick, a line break being a
%% line feed and a carriage return before it dropped.
raw_body([], _Line, _Column, StartLine, StartColumn, _Acc) ->
    unfinished_at(StartLine, StartColumn, "unterminated raw string");
raw_body([$` | Rest], Line, Column, _StartLine, _StartColumn, Acc) ->
    {lists:reverse(Acc), Rest, Line, Column + 1};
raw_body([$\r, $\n | Rest], Line, _Column, StartLine, StartColumn, Acc) ->
    raw_body(Rest, Line + 1, 1, StartLine, StartColumn, [$\n | Acc]);
raw_body([$\n | Rest], Line, _Column, StartLine, StartColumn, Acc) ->
    raw_body(Rest, Line + 1, 1, StartLine, StartColumn, [$\n | Acc]);
raw_body([Char | Rest], Line, Column, StartLine, StartColumn, Acc) ->
    raw_body(Rest, Line, Column + 1, StartLine, StartColumn, [Char | Acc]).

char_body([$\\ | Rest], Line, Column) ->
    {Char, Rest1, Length} = escape(Rest, Line, Column + 1),
    closed_char(Char, Rest1, Line, Column, Column + 2 + Length);
char_body([$' | _], Line, Column) ->
    error_at(Line, Column, "empty char literal");
char_body([Char | _], Line, Column) when Char =:= $\n; Char =:= $\r ->
    error_at(Line, Column, "newline in char literal; use '\\n'");
char_body([Char | Rest], Line, Column) ->
    closed_char(Char, Rest, Line, Column, Column + 2);
char_body([], Line, Column) ->
    error_at(Line, Column, "unterminated char literal").

closed_char(Char, [$' | Rest], _Line, _StartColumn, QuoteColumn) ->
    {Char, Rest, QuoteColumn + 1};
closed_char(_Char, Rest, Line, StartColumn, _QuoteColumn) ->
    case is_closed_on_line(Rest) of
        true -> error_at(Line, StartColumn, "a char literal holds one code point; a string is"
                                            " written between double quotes");
        false -> error_at(Line, StartColumn, "unterminated char literal")
    end.

%% Whether a quote closes a char literal later on its line, past more than
%% one code point.
is_closed_on_line([$' | _]) -> true;
is_closed_on_line([$\\, Char | Rest]) when Char =/= $\n, Char =/= $\r -> is_closed_on_line(Rest);
is_closed_on_line([Char | _]) when Char =:= $\n; Char =:= $\r -> false;
is_closed_on_line([_ | Rest]) -> is_closed_on_line(Rest);
is_closed_on_line([]) -> false.

%% After the backslash: the code point, the rest, and the characters the
%% escape took after the backslash.
escape([$' | Rest], _Line, _Column) -> {$', Rest, 1};
escape([$" | Rest], _Line, _Column) -> {$", Rest, 1};
escape([$\\ | Rest], _Line, _Column) -> {$\\, Rest, 1};
escape([$n | Rest], _Line, _Column) -> {$\n, Rest, 1};
escape([$r | Rest], _Line, _Column) -> {$\r, Rest, 1};
escape([$t | Rest], _Line, _Column) -> {$\t, Rest, 1};
escape([$u, ${ | Rest], Line, Column) ->
    {Hex, Rest1} = lists:splitwith(fun is_hex/1, Rest),
    case {Hex, Rest1} of
        {[], _} -> error_at(Line, Column, "\\u{ needs one to six hex digits");
        {_, [$} | Rest2]} when length(Hex) =< 6 ->
            CodePoint = list_to_integer(Hex, 16),
            case CodePoint =< 16#10FFFF
                andalso not (CodePoint >= 16#D800 andalso CodePoint =< 16#DFFF) of
                true -> {CodePoint, Rest2, 3 + length(Hex)};
                false ->
                    error_at(Line, Column, "\\u{" ++ Hex ++ "} is not a Unicode scalar value")
            end;
        _ -> error_at(Line, Column, "\\u{ needs one to six hex digits followed by }")
    end;
escape([Char | _], Line, Column) when Char =:= $\n; Char =:= $\r ->
    error_at(Line, Column, "a line break cannot follow `\\`; use \\n");
escape([Char | _], Line, Column) ->
    error_at(Line, Column, io_lib:format("unknown escape \\~ts", [[Char]]));
escape([], Line, Column) ->
    error_at(Line, Column, "unterminated escape").

%%
%% Words: identifiers, type names, reserved words, bool literals, wildcard.
%%

%% Report §2.3: a word is at most 255 characters long.
word(Input, Line, Column) ->
    {Name, Rest} = lists:splitwith(fun is_word_char/1, Input),
    case length(Name) =< 255 of
        true -> {Name, Rest};
        false -> error_at(Line, Column, "a name is at most 255 characters long")
    end.

is_word_char(Char) -> (Char >= $a andalso Char =< $z) orelse (Char >= $A andalso Char =< $Z)
                      orelse (Char >= $0 andalso Char =< $9) orelse Char =:= $_.

word_token("_", Position, _) -> {'_', Position};
word_token("true", Position, _) -> {bool, Position, true};
word_token("false", Position, _) -> {bool, Position, false};
word_token(Name, Position, Options) ->
    Atom = name(Name, Options),
    case lists:member(Atom, ?RESERVED) of
        true -> {Atom, Position};
        false -> {ident, Position, Atom}
    end.

%% A name as the atom a token carries; under `no_new_names`, one the host
%% has not met is the stand-in, and no atom is made.
name(Name, Options) ->
    case lists:member(no_new_names, Options) of
        true -> try list_to_existing_atom(Name) catch error:badarg -> '$unmet' end;
        false -> list_to_atom(Name)
    end.

%%
%% Symbols
%%

symbol(_Input, []) ->
    none;
symbol(Input, [Symbol | Symbols]) ->
    case lists:prefix(Symbol, Input) of
        true -> {list_to_atom(Symbol), lists:nthtail(length(Symbol), Input), length(Symbol)};
        false -> symbol(Input, Symbols)
    end.

%%
%% Errors
%%

error_at(Line, Column, Message) ->
    throw({lex_error, diagnostic(Line, Column, lists:flatten(Message), false)}).

%% Report §11.2, §2.5: a raw string and a block comment may span lines, so
%% more input can finish one, and the diagnostic says so; a string or a
%% char literal may not, and an unfinished one is an error whatever follows.
unfinished_at(Line, Column, Message) ->
    throw({lex_error, diagnostic(Line, Column, Message, true)}).

%% A diagnostic at the character at Line and Column.
diagnostic(Line, Column, Message, Incomplete) ->
    #diagnostic{span = {Line, Column, {Line, Column + 1}}, message = Message,
                incomplete = Incomplete}.
