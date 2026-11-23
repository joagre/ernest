%% The tools' one helper, the lexemes of source text as the tools written in
%% Ernest read them: Ernest's by the toolchain's own lexer (report §2), for
%% tools/site/code_block.ern, which colors code as `ern` reads it, and for
%% tools/clones.ern; and Erlang's by the host's erl_scan, for
%% tools/clones.ern. A token is a host term no Ernest type describes, a
%% tuple of two or of three by the token, so each is given as an Ernest
%% value (report §12.2), `Some` of the tokens, or `None` where the lexer
%% refuses the text. A name is read with `no_new_names`, since no tool reads
%% a token's name.
-module(ern_lexemes).

-export([lexed/1, ernest_tokens/1, erlang_tokens/1]).

%% A lexeme as tools/site/code_block.ern declares it: Lexeme(kind, at, end),
%% at and end each Position(line, column), the end the column after the
%% token's last character, both counted as report §11.5 counts them.
-type position() :: {'Position', pos_integer(), pos_integer()}.
-type lexeme() :: {'Lexeme', atom(), position(), position()}.

%% A token as tools/clones.ern declares it: Token(category, line), the
%% category the lexer's own, `ident` or `(`, and the line its first
%% character stands on.
-type token() :: {'Token', binary(), pos_integer()}.

%% Ernest's lexemes with their comments, for the site.
-spec lexed(unicode:unicode_binary()) -> {'Some', [lexeme()]} | 'None'.
lexed(Code) ->
    case ern_lexer:tokenize(Code, [comments, no_new_names]) of
        {ok, Tokens} -> {'Some', [lexeme(Token) || Token <- Tokens, element(1, Token) =/= eof]};
        {error, _} -> 'None'
    end.

lexeme(Token) ->
    {Line, Column, {EndLine, EndColumn}, _} = element(2, Token),
    {'Lexeme', kind(Token), {'Position', Line, Column}, {'Position', EndLine, EndColumn}}.

%% The lexer's category, a constructor of the site's Kind; a symbol spelled
%% with letters is a reserved word (report §2.4), any other an operator or a
%% delimiter (report §2.6).
kind({int, _, _}) -> 'IntLiteral';
kind({float, _, _}) -> 'FloatLiteral';
kind({char, _, _}) -> 'CharLiteral';
kind({string, _, _}) -> 'StringLiteral';
kind({bool, _, _}) -> 'BoolLiteral';
kind({ident, _, _}) -> 'Name';
kind({typename, _, _}) -> 'TypeName';
kind({doc, _, _}) -> 'DocBlock';
kind({comment, _, _}) -> 'Comment';
kind({Symbol, _}) ->
    case atom_to_list(Symbol) of
        [First | _] when First >= $a, First =< $z -> 'Reserved';
        _ -> 'Symbol'
    end.

%% Ernest's tokens, a doc block's among them and no comment's.
-spec ernest_tokens(unicode:unicode_binary()) -> {'Some', [token()]} | 'None'.
ernest_tokens(Code) ->
    case ern_lexer:tokenize(Code, [no_new_names]) of
        {ok, Tokens} -> {'Some', [token(element(1, Token), element(1, element(2, Token)))
                                  || Token <- Tokens, element(1, Token) =/= eof]};
        {error, _} -> 'None'
    end.

%% Erlang's tokens as the host's scanner reads them, with no comment's.
-spec erlang_tokens(unicode:unicode_binary()) -> {'Some', [token()]} | 'None'.
erlang_tokens(Code) ->
    try erl_scan:string(unicode:characters_to_list(Code)) of
        {ok, Tokens, _} -> {'Some', [token(element(1, Token), erl_anno:line(element(2, Token)))
                                     || Token <- Tokens]};
        {error, _, _} -> 'None'
    catch
        error:badarg -> 'None'
    end.

token(Category, Line) ->
    {'Token', atom_to_binary(Category), Line}.
