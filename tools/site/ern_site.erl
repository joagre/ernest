%% The site generator's helper, tools/site/code_block.ern's one foreign function: Ernest
%% code read by the toolchain's own lexer (report §2), so that the site
%% colors code as `ern` reads it. The lexer's tokens are host terms no Ernest
%% type describes, a tuple of two or of three by the token, so the helper
%% gives each as an Ernest value (report §12.2): `Some` of the lexemes, or
%% `None` where the lexer refuses the code, a fragment. A name is read with
%% `no_new_names`, since the site reads where a token stands and never its
%% name, and comments come as tokens.
-module(ern_site).

-export([lexed/1]).

%% A lexeme as the Ernest side declares it: Lexeme(kind, at, end), at and
%% end each Position(line, column), the end the column after the token's
%% last character, both counted as report §11.5 counts them.
-type position() :: {'Position', pos_integer(), pos_integer()}.
-type lexeme() :: {'Lexeme', atom(), position(), position()}.

-spec lexed(unicode:unicode_binary()) -> {'Some', [lexeme()]} | 'None'.
lexed(Code) ->
    case ern_lexer:tokenize(Code, [comments, no_new_names]) of
        {ok, Tokens} -> {'Some', [lexeme(Token) || Token <- Tokens, element(1, Token) =/= eof]};
        {error, _} -> 'None'
    end.

lexeme(Token) ->
    {Line, Column, {EndLine, EndColumn}, _} = element(2, Token),
    {'Lexeme', kind(Token), {'Position', Line, Column}, {'Position', EndLine, EndColumn}}.

%% The lexer's category, a constructor of the Ernest side's Kind; a symbol
%% spelled with letters is a reserved word (report §2.4), any other an
%% operator or a delimiter (report §2.6).
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
