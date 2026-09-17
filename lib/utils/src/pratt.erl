-module(pratt).

%% https://en.wikipedia.org/wiki/Pratt_parser
%% https://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing
%% http://effbot.org/zone/simple-top-down-parsing.htm
%% https://crockford.com/javascript/tdop/tdop.html

%%% External exports
-export([new/1, delete/1]).
-export([get_token/2, get_token/1]).
-export([is_token/2]).
-export([next_token/2, next_token/1]).
-export([add_semantic_token/6]).
-export([add_literal_semantic_token/3]).
-export([add_symbol_semantic_token/3]).
-export([add_prefix_semantic_token/5]).
-export([add_infix_semantic_token/5]).
-export([add_nud/3, add_led/3]).
-export([parse/1, expression/1, expression/2]).
-export([strerror/1, strerror_token/1, strerror_one_of/1]).

%%% External type exports

%%% Internal exports

%%% Include files
-include_lib("utils/include/pratt.hrl").

%%% Constants

%%% Records

%%% Types

%%%
%%% Exported: new
%%%

new(Lexer) ->
    PS = ets:new(parser, []),
    true = ets:insert(PS, {lexer, Lexer}),
    SemanticCode = ets:new(semantic_code, [{keypos, #token.name}]),
    true = ets:insert(PS, {semantic_code, SemanticCode}),
    add_symbol_semantic_token(PS, end_token, 0),
    PS.

%%%
%%% Exported: delete
%%%

delete(PS) ->
    [{_, SemanticCode}] = ets:lookup(PS, semantic_code),
    ets:delete(SemanticCode),
    ets:delete(PS).

%%%
%%% Exported: get_token
%%%

get_token(PS, Names) when is_list(Names) ->
    Token = get_token(PS),
    is_token(Token, Names),
    Token;
get_token(PS, Name) ->
    case get_token(PS) of
        #token{name = Name} = Token ->
            Token;
        Token ->
            throw({?MODULE, {syntax_error, {expected, Name, Token}}})
    end.

get_token(PS) ->
    [{_, Token}] = ets:lookup(PS, token),
    Token.

%%%
%%% Exported: is_token
%%%

is_token(Token, Names) ->
    is_token(Token, Names, Names).

is_token(Token, Names, []) ->
    throw({?MODULE, {syntax_error, {expected_one_of, Names, Token}}});
is_token(#token{name = Name}, _Names, [Name|_]) ->
    true;
is_token(Token, Names, [_|Rest]) ->
    is_token(Token, Names, Rest).

%%%
%%% Exported: next_token
%%%

next_token(PS, Name) ->
    case get_token(PS) of
        #token{name = Name} ->
            next_token(PS);
        Token ->
            throw({?MODULE, {syntax_error, {expected, Name, Token}}})
    end.

remaining_tokens(PS) ->
    [{_, Lexer}] = ets:lookup(PS, lexer),
    Lexer(length).

next_token(PS) ->
    [{_, Lexer}] = ets:lookup(PS, lexer),
    [{_, SemanticCode}] = ets:lookup(PS, semantic_code),
    case Lexer(get) of
        no_more_tokens ->
            [Token] = ets:lookup(SemanticCode, end_token),
            ets:insert(PS, {token, Token});
        {Name, Line, Value, NewLexer} ->
            true = ets:insert(PS, {lexer, NewLexer}),
            case ets:lookup(SemanticCode, Name) of
                [Token] ->
                    ets:insert(PS,
                               {token, Token#token{line = Line,
                                                   value = Value}});
                [] ->
                    throw({?MODULE,
                           {internal_error, {unknown_token, Name, Line}}})
            end
    end.

%%%
%%% Exported: add_semantic_token
%%%

add_semantic_token(PS, Name, Lbp, Nud, Led, Op) ->
    [{_, SemanticCode}] = ets:lookup(PS, semantic_code),
    NewSemanticToken =
        case ets:lookup(SemanticCode, Name) of
            [] ->
                #token{name = Name,
                       lbp = default_lbp(Lbp),
                       nud = default_nud(Name, Nud),
                       led = default_led(Name, Led),
                       op = Op};
            [#token{lbp = OldLbp,
                    nud = OldNud,
                    led = OldLed,
                    op = OldOp} = SemanticToken] ->
                SemanticToken#token{lbp = update(Lbp, OldLbp),
                                    nud = update(Nud, OldNud),
                                    led = update(Led, OldLed),
                                    op = update(Op, OldOp)}
        end,
    ets:insert(SemanticCode, NewSemanticToken).

default_lbp(undefined) ->
    0;
default_lbp(Lbp) ->
    Lbp.

default_nud(Name, undefined) ->
    fun(#token{name = end_token}) ->
            throw({?MODULE, {syntax_error, eoe}});
       (#token{line = Line}) ->
            throw({?MODULE, {syntax_error, {{bad_literal, Name}, Line}}})
    end;
default_nud(_Name, Nud) ->
    Nud.

default_led(Name, undefined) ->
    fun(#token{name = end_token}, _Left) ->
            throw({?MODULE, {syntax_error, eoe}});
       (#token{line = Line}, _Left) ->
            throw({?MODULE,
                   {syntax_error, {{unknown_operator, Name}, Line}}})
    end;
default_led(_Name, Led) ->
    Led.

update(undefined, OldValue) ->
    OldValue;
update(NewValue, _OldValue) ->
    NewValue.

%%%
%%% Exported: add_literal_semantic_token
%%%

add_literal_semantic_token(PS, Name, Nud) ->
    add_semantic_token(PS, Name, 0, Nud, undefined, undefined).

%%%
%%% Exported: add_symbol_semantic_token
%%%

add_symbol_semantic_token(PS, Name, Lbp) ->
    add_semantic_token(PS, Name, Lbp, undefined, undefined, undefined).

%%%
%%% Exported: add_prefix_semantic_token
%%%

add_prefix_semantic_token(PS, Name, Lbp, Nud, Op) ->
    add_semantic_token(PS, Name, Lbp, Nud, undefined, Op).

%%%
%%% Exported: add_infix_semantic_token
%%%

add_infix_semantic_token(PS, Name, Lbp, Led, Op) ->
    add_semantic_token(PS, Name, Lbp, undefined, Led, Op).

%%%
%%% Exported: add_nud
%%%

add_nud(PS, Name, Nud) ->
    add_semantic_token(PS, Name, undefined, Nud, undefined, undefined).

%%%
%%% Exported: add_led
%%%

add_led(PS, Name, Led) ->
    add_semantic_token(PS, Name, undefined, undefined, Led, undefined).

%%%
%%% Exported: start
%%%

parse(PS) ->
    true = next_token(PS),
    parse_expressions(PS).

parse_expressions(PS) ->
    case get_token(PS) of
        #token{name = end_token} ->
            [];
        _ ->
            N = remaining_tokens(PS),
            if
                N >= 0 ->
                    [expression(PS, 0)|parse_expressions(PS)];
                true ->
                    []
            end
    end.

%%%
%%% Exported: expression
%%%

expression(PS) ->
    expression(PS, 0).

expression(PS, Rbp) ->
    Token = get_token(PS),
    true = next_token(PS),
    Left = (Token#token.nud)(Token),
    expression(PS, Rbp, Left).

expression(PS, Rbp, Left) ->
    Token = get_token(PS),
    if
        Rbp < Token#token.lbp ->
            true = next_token(PS),
            NextLeft = (Token#token.led)(Token, Left),
            expression(PS, Rbp, NextLeft);
        true ->
            Left
    end.

%%%
%%% Exported: strerror
%%%

strerror({syntax_error, {expected, _Name, #token{name = end_token}}}) ->
    "Premature end of expression";
strerror({syntax_error, {expected, Name, #token{line = Line} = Token}}) ->
    fformat("~w: Expected ~w instead of ~s",
            [Line, Name, strerror_token(Token)]);
strerror({syntax_error,
          {expected_one_of, Names, #token{line = Line} = Token}}) ->
    fformat("~w: Expected ~s instead of ~s",
            [Line, strerror_one_of(Names), strerror_token(Token)]);
strerror({syntax_error, {internal_error, {unknown_token, Name, Line}}}) ->
    fformat("~w: Unknown token ~w", [Line, Name]);
strerror({syntax_error, eoe}) ->
    "Unexpected end of expression";
strerror({syntax_error, {{bad_literal, Name}, Line}}) ->
    fformat("~w: Unknown literal ~w", [Line, Name]);
strerror({syntax_error, {{unknown_operator, Name}, Line}}) ->
    fformat("~w: Unknown operator ~w", [Line, Name]);
strerror(Reason) ->
    fformat("~w: ~p", [?MODULE, Reason]).

fformat(Format, Args) ->
    lists:flatten(io_lib:format(Format, Args)).

strerror_token(#token{value = Value}) when is_binary(Value) ->
    io_lib:format("\"~s\"", [Value]);
strerror_token(#token{name = Name, value = Value}) when is_tuple(Value) ->
    atom_to_list(Name);
strerror_token(#token{value = Value}) when Value /= undefined ->
    io_lib:format("~p", [Value]);
strerror_token(#token{name = Name}) ->
    atom_to_list(Name).

strerror_one_of([Name]) ->
    strerror_name(Name);
strerror_one_of([FirstName, SecondName]) ->
    strerror_name(FirstName) ++ " or " ++ strerror_name(SecondName);
strerror_one_of([FirstName|Rest]) ->
    strerror_name(FirstName) ++
        lists:flatten(
          [", " ++ strerror_name(Name) || Name <- lists:droplast(Rest)]) ++
        " or " ++ strerror_name(lists:last(Rest)).

strerror_name(Name) ->
    "'" ++ atom_to_list(Name) ++ "'".
