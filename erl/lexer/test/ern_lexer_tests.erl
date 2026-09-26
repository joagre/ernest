-module(ern_lexer_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("utils/include/ern_diag.hrl").

%% Token list without positions and without the trailing eof.
toks(Text) ->
    {ok, Tokens} = ern_lexer:tokenize(Text),
    [strip(T) || T <- Tokens, element(1, T) =/= eof].

strip({Cat, _Pos, Value}) -> {Cat, Value};
strip({Sym, _Pos}) -> Sym.

err(Text) ->
    {error, #diag{span = {L, C, _}, message = Msg}} = ern_lexer:tokenize(Text),
    {L, C, Msg}.

%% report §2.4
reserved_words_test() ->
    ?assertEqual([type, abstract, with, foreign, match, 'when', 'receive', 'after', as,
                  'if', then, 'else', fn, 'let', export],
                 toks("type abstract with foreign match when receive after as "
                      "if then else fn let export")).

%% report §2.4, §2.5
literals_true_false_test() ->
    ?assertEqual([{bool, true}, {bool, false}], toks("true false")).

%% report §2.3
identifiers_test() ->
    ?assertEqual([{ident, x}, {ident, foo_bar1}, {ident, '_x'}, '_', {ident, tryIt}],
                 toks("x foo_bar1 _x _ tryIt")).

%% report §2.3
typenames_test() ->
    ?assertEqual([{typename, 'Int'}, {typename, 'Http_server'}, {typename, 'T1'}],
                 toks("Int Http_server T1")).

%% report §2.3: a name is at most 255 characters long, and a longer one is
%% refused where it begins. A regression test: the lexer raised system_limit
%% from list_to_atom before
name_length_test() ->
    Long = lists:duplicate(255, $a),
    ?assertEqual([{ident, list_to_atom(Long)}], toks(Long)),
    ?assertEqual({1, 3, "a name is at most 255 characters long"}, err("x " ++ Long ++ "a")),
    ?assertEqual({1, 1, "a name is at most 255 characters long"},
                 err(lists:duplicate(256, $A))).

%% report §2.3
qualified_name_test() ->
    ?assertEqual([{typename, 'Net'}, '.', {typename, 'Http'}, '.', {ident, parse}],
                 toks("Net.Http.parse")),
    ?assertEqual([{typename, 'Int'}, '.', '+'], toks("Int.+")).

%% report §2.5
integers_test() ->
    ?assertEqual([{int, 0}, {int, 42}, {int, 123456789012345678901234567890}],
                 toks("0 42 123456789012345678901234567890")).

%% report §4.8: `!` is a symbol of its own, and `!=` stays one token
not_symbol_test() ->
    ?assertEqual(['!', {ident, ok}], toks("!ok")),
    ?assertEqual([{ident, a}, '!=', {ident, b}], toks("a != b")),
    ?assertEqual(['!', '(', {ident, a}, ')'], toks("!(a)")).

%% report §2.5: hexadecimal, octal, and binary integers, the prefix lowercase
based_integers_test() ->
    ?assertEqual([{int, 16#10FFFF}, {int, 255}, {int, 8#644}, {int, 10}, {int, 0}],
                 toks("0x10FFFF 0xfF 0o644 0b1010 0x0")),
    ?assertEqual({1, 5, "2 is not a binary digit"}, err("0b102")),
    ?assertEqual({1, 1, "0x needs a hexadecimal digit"}, err("0x")),
    ?assertEqual({1, 1, "a base prefix is lowercase: 0x"}, err("0XFF")).

%% report §2.5: nothing word-like directly after a number
number_then_word_test() ->
    ?assertEqual({1, 3, "p cannot follow a number directly"}, err("12px")),
    ?assertEqual({1, 4, "x cannot follow a number directly"}, err("1.5x")).

%% report §2.5: an `_` between two digits groups them; anywhere else in a
%% number it is an error
digit_separators_test() ->
    ?assertEqual([{int, 1000000}, {int, 16#FFFFFFFF}, {int, 2#10101010}, {int, 8#7_55},
                  {float, 3.141592}, {float, 1.0e10}],
                 toks("1_000_000 0xFFFF_FFFF 0b1010_1010 0o7_55 3.141_592 1.0e1_0")),
    ?assertEqual({1, 2, "_ must stand between two digits"}, err("1_")),
    ?assertEqual({1, 2, "_ must stand between two digits"}, err("1__0")),
    ?assertEqual({1, 3, "_ must stand between two digits"}, err("0x_FF")),
    ?assertEqual({1, 4, "_ must stand between two digits"}, err("1.5_")),
    ?assertEqual([{int, 1000}, '..', {int, 2000}], toks("1_000..2_000")).

%% report §2.5
floats_test() ->
    ?assertEqual([{float, 1.0}, {float, 3.25}, {float, 1.0e-9}, {float, 2.5e3},
                  {float, 1.0e9}],
                 toks("1.0 3.25 1.0e-9 2.5E+3 1.0e9")).

%% report §2.5: a float literal beyond the largest finite Float is an error
%% at the literal, not a crash; one below the smallest is 0.0. A regression
%% test, written after the fix; it covers the lexer alone, not how ernc or
%% the shell shows the diagnostic.
float_literal_out_of_range_test() ->
    ?assertEqual({1, 5, "the float literal is beyond the largest finite Float"},
                 err("x = 1.0e400")),
    ?assertEqual({1, 1, "the float literal is beyond the largest finite Float"},
                 err("1.7976931348623159e308")),
    ?assertEqual([{float, 1.7976931348623157e308}], toks("1.7976931348623157e308")),
    ?assertEqual([{float, 0.0}], toks("1.0e-400")).

%% report §2.5, §2.6
int_then_dots_test() ->
    ?assertEqual([{int, 1}, '..', {int, 2}], toks("1..2")),
    ?assertEqual([{int, 1}, '.', {ident, x}], toks("1.x")).

%% report §2.5
negative_is_prefix_operator_test() ->
    ?assertEqual(['-', {int, 1}], toks("-1")).

%% report §2.5
chars_test() ->
    ?assertEqual([{char, $a}, {char, $\n}, {char, $'}, {char, $\\}, {char, 16#1F600},
                  {char, $"}],
                 toks("'a' '\\n' '\\'' '\\\\' '\\u{1F600}' '\"'")).

%% report §2.5
strings_test() ->
    ?assertEqual([{string, <<"hello, world">>}], toks("\"hello, world\"")),
    ?assertEqual([{string, <<"a\nb\r\tc\"'\\">>}], toks("\"a\\nb\\r\\tc\\\"'\\\\\"")),
    ?assertEqual([{string, <<"é"/utf8>>}], toks("\"\\u{e9}\"")),
    ?assertEqual([{string, <<"ö"/utf8>>}], toks(<<"\"ö\""/utf8>>)),
    ?assertEqual([{string, <<>>}], toks("\"\"")).

%% report §2.6
symbols_max_munch_test() ->
    ?assertEqual(['#(', '<<', '>>', '<-', '->', '==', '!=', '<=', '>=', '&&', '||',
                  '|>', '<>', '::', '..'],
                 toks("#( << >> <- -> == != <= >= && || |> <> :: ..")),
    ?assertEqual(['(', ')', '{', '}', '[', ']', ',', ';', ':', '=', '|', '.',
                  '+', '-', '*', '/', '%', '<', '>'],
                 toks("( ) { } [ ] , ; : = | . + - * / % < >")),
    ?assertEqual([{ident, x}, '<-', {ident, y}], toks("x<-y")),
    ?assertEqual([{ident, x}, '<', '-', {ident, y}], toks("x< -y")),
    ?assertEqual([{ident, a}, '||', {ident, b}], toks("a||b")),
    ?assertEqual([{ident, a}, '|', {ident, b}], toks("a|b")).

%% report §2.2
line_comment_test() ->
    ?assertEqual([{ident, a}, {ident, b}], toks("a // comment\nb")),
    ?assertEqual([{ident, a}], toks("a // comment at eof")).

%% report §2.2
four_slashes_is_a_doc_line_test() ->
    %% the report says /// starts a doc line; a fourth slash is text
    ?assertEqual([{doc, <<"/ ruler">>}, {ident, a}], toks("//// ruler\na")).

%% report §2.2
block_comment_test() ->
    ?assertEqual([{ident, a}, {ident, b}], toks("a /* x */ b")),
    ?assertEqual([{ident, a}, {ident, b}], toks("a /* x /* nested */ still */ b")),
    ?assertEqual([{ident, a}, {ident, b}], toks("a /* multi\nline\n*/ b")),
    ?assertEqual({1, 3, "unterminated block comment"}, err("a /* x /* y */")).

%% report §2.2
doc_block_test() ->
    ?assertEqual([{doc, <<"one\ntwo">>}, {ident, a}], toks("/// one\n/// two\na")),
    ?assertEqual([{doc, <<"one">>}, {doc, <<"two">>}, {ident, a}],
                 toks("/// one\n\n/// two\na")),
    ?assertEqual([{doc, <<"x">>}, {ident, a}], toks("  /// x\r\n  a")),
    ?assertEqual([{doc, <<"no space">>}], toks("///no space")),
    ?assertEqual([{doc, <<"">>}], toks("///")).

%% report §11.1 (line and column in errors)
positions_test() ->
    {ok, Tokens} = ern_lexer:tokenize("fn main() =\n    x"),
    ?assertEqual([{fn, {1, 1, {1, 3}, {1, 1}}}, {ident, {1, 4, {1, 8}, {1, 3}}, main},
                  {'(', {1, 8, {1, 9}, {1, 8}}}, {')', {1, 9, {1, 10}, {1, 9}}},
                  {'=', {1, 11, {1, 12}, {1, 10}}}, {ident, {2, 5, {2, 6}, {1, 12}}, x},
                  {eof, {2, 6, {2, 6}, {2, 6}}}],
                 Tokens).

%% report §11.1
position_after_multiline_things_test() ->
    {ok, [_, {ident, {3, 4, _, _}, b} | _]} = ern_lexer:tokenize("a /* x\ny\n*/ b"),
    {ok, [{string, {1, 1, _, _}, _}, {ident, {1, 11, _, _}, b} | _]} =
        ern_lexer:tokenize("\"a\\u{e9}\" b"),
    {ok, [{doc, {1, 1, _, _}, _}, {ident, {3, 1, _, _}, a} | _]} =
        ern_lexer:tokenize("/// x\n/// y\na"),
    {ok, [{char, {1, 1, _, _}, _}, {ident, {1, 6, _, _}, b} | _]} = ern_lexer:tokenize("'\\n' b").

%% report §2.1
bom_is_stripped_test() ->
    ?assertEqual([{ident, a}], toks([16#FEFF | "a"])).

%% report §2.5
errors_test() ->
    ?assertEqual({1, 1, "unterminated string literal"}, err("\"abc")),
    ?assertEqual({1, 5, "newline in string literal; use \\n"}, err("\"abc\ndef\"")),
    ?assertEqual({1, 2, "unknown escape \\q"}, err("\"\\q\"")),
    ?assertEqual({1, 2, "\\u{D800} is not a Unicode scalar value"}, err("\"\\u{D800}\"")),
    ?assertEqual({1, 2, "\\u{110000} is not a Unicode scalar value"}, err("\"\\u{110000}\"")),
    ?assertEqual({1, 2, "\\u{ needs one to six hex digits followed by }"},
                 err("\"\\u{1234567}\"")),
    ?assertEqual({1, 2, "\\u{ needs one to six hex digits"}, err("\"\\u{}\"")),
    ?assertEqual({1, 1, "empty char literal"}, err("''")),
    ?assertEqual({1, 1, "unterminated char literal"}, err("'ab'")),
    ?assertEqual({1, 1, "unterminated char literal"}, err("'a")),
    ?assertEqual({2, 3, "illegal character '@'"}, err("a\n  @")),
    ?assertEqual({1, 1, "illegal character 'é'"}, err(<<"é"/utf8>>)).

%% report §11.5: a token's pos is its line, column, end, and the end of the
%% token before it
token_spans_test() ->
    {ok, Tokens} = ern_lexer:tokenize("ab  +\n\"cd\" 12"),
    ?assertEqual([{ident, {1, 1, {1, 3}, {1, 1}}, ab},
                  {'+', {1, 5, {1, 6}, {1, 3}}},
                  {string, {2, 1, {2, 5}, {1, 6}}, <<"cd">>},
                  {int, {2, 6, {2, 8}, {2, 5}}, 12},
                  {eof, {2, 8, {2, 8}, {2, 8}}}], Tokens).

%% report Appendix B, guide §1
hello_program_test() ->
    Src = "export fn main() -> Unit with Never = Io.println(\"hello, world\")",
    ?assertEqual([export, fn, {ident, main}, '(', ')', '->', {typename, 'Unit'}, with,
                  {typename, 'Never'}, '=', {typename, 'Io'}, '.', {ident, println}, '(',
                  {string, <<"hello, world">>}, ')'],
                 toks(Src)).

%% report §6.3
receive_clause_test() ->
    Src = "receive {\n    Inc(k) -> counter(n + k)\n  | after 0 -> world\n}",
    ?assertEqual(['receive', '{', {typename, 'Inc'}, '(', {ident, k}, ')', '->',
                  {ident, counter}, '(', {ident, n}, '+', {ident, k}, ')', '|', 'after',
                  {int, 0}, '->', {ident, world}, '}'],
                 toks(Src)).

%% report §2.5: a raw string is a String taken as written, no escapes, and may
%% span lines, a CR before a line break dropped
raw_string_test() ->
    ?assertEqual([{string, <<"\\d+\\.\\d+">>}], toks("`\\d+\\.\\d+`")),
    ?assertEqual([{string, <<>>}], toks("``")),
    ?assertEqual([{string, <<"say \"hi\"">>}], toks("`say \"hi\"`")),
    ?assertEqual([{string, <<"a\nb">>}], toks("`a\nb`")),
    ?assertEqual([{string, <<"a\nb">>}], toks("`a\r\nb`")),
    {ok, [_, {ident, {2, 4, _, _}, _} | _]} = ern_lexer:tokenize("`a\nb` x"),
    ?assertEqual({1, 1, "unterminated raw string"}, err("`abc")).
