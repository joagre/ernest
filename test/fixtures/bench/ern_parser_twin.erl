%% The lexer, the parser and the evaluator of
%% test/fixtures/bench/parser.ern as Erlang writes it, for `make bench`
%% (test/ern_program_costs.erl): the same language, the same recursive
%% descent and the same evaluation, over tagged tuples, an answer that may
%% fail `{ok, Value}` or `{error, Error}`. A character's class is tested in
%% the lexer's guards, a letter as ASCII's, since a guard calls no function
%% of the module's; the input is ASCII.
-module(ern_parser_twin).

-export([run/1]).

%% The lines read in order: the sum of the integers they came to, and the
%% count of the lines that were wrong.
-spec run([binary()]) -> {integer(), integer()}.
run(Lines) ->
    {_, Sum, Errors} = lists:foldl(fun evaluate_line/2, {#{}, 0, 0}, Lines),
    {Sum, Errors}.

evaluate_line(Text, {Env, Sum, Errors} = Acc) ->
    case tokenize(Text) of
        {error, _} ->
            {Env, Sum, Errors + 1};
        {ok, []} ->
            Acc;
        {ok, Tokens} ->
            case parse(Tokens) of
                {error, _} ->
                    {Env, Sum, Errors + 1};
                {ok, Expression} ->
                    case {Expression, eval(Env, Expression)} of
                        {_, {error, _}} -> {Env, Sum, Errors + 1};
                        {{'let', Name, _}, {ok, Value}} ->
                            {maps:put(Name, Value, Env), Sum + value_of(Value), Errors};
                        {_, {ok, Value}} -> {Env, Sum + value_of(Value), Errors}
                    end
            end
    end.

value_of({integer, Number}) -> Number;
value_of({closure, _, _, _}) -> 0.

%%
%% The lexer
%%

-define(IS_DIGIT(Char), (Char >= $0 andalso Char =< $9)).
-define(IS_ALPHA(Char), ((Char >= $a andalso Char =< $z) orelse (Char >= $A andalso Char =< $Z))).

tokenize(Text) ->
    lex(unicode:characters_to_list(Text), 0, []).

lex([], _, Acc) ->
    {ok, lists:reverse(Acc)};
lex([$\s | Rest], Index, Acc) ->
    lex(Rest, Index + 1, Acc);
lex([$( | Rest], Index, Acc) ->
    lex(Rest, Index + 1, [open_paren | Acc]);
lex([$) | Rest], Index, Acc) ->
    lex(Rest, Index + 1, [close_paren | Acc]);
lex([$= | Rest], Index, Acc) ->
    lex(Rest, Index + 1, [equals | Acc]);
lex([$-, $> | Rest], Index, Acc) ->
    lex(Rest, Index + 2, [arrow | Acc]);
lex([Char | _] = Chars, Index, Acc) when ?IS_DIGIT(Char) ->
    {Digits, Rest} = lists:splitwith(fun(Digit) -> ?IS_DIGIT(Digit) end, Chars),
    lex(Rest, Index + length(Digits), [{number, list_to_integer(Digits)} | Acc]);
lex([Char | _] = Chars, Index, Acc) when ?IS_ALPHA(Char) ->
    {Word, Rest} = lists:splitwith(fun(Letter) -> ?IS_ALPHA(Letter) end, Chars),
    Token = case unicode:characters_to_binary(Word) of
                <<"let">> -> let_keyword;
                <<"fun">> -> fun_keyword;
                Other -> {name, Other}
            end,
    lex(Rest, Index + length(Word), [Token | Acc]);
lex([Char | Rest], Index, Acc) when Char =:= $+; Char =:= $-; Char =:= $*; Char =:= $/ ->
    lex(Rest, Index + 1, [{operator, Char} | Acc]);
lex([Char | _], Index, _) ->
    {error, {bad_char, Char, Index}}.

%%
%% The parser
%%

parse(Tokens) ->
    Parsed = case Tokens of
                 [let_keyword, {name, Name}, equals | More] ->
                     case parse_expression(More) of
                         {ok, {Value, Remaining}} -> {ok, {{'let', Name, Value}, Remaining}};
                         {error, _} = Failed -> Failed
                     end;
                 _ ->
                     parse_expression(Tokens)
             end,
    case Parsed of
        {ok, {Expression, []}} -> {ok, Expression};
        {ok, {_, [Token | _]}} -> {error, {unexpected, Token}};
        {error, _} = Error -> Error
    end.

parse_expression([fun_keyword, {name, Parameter}, arrow | Rest]) ->
    case parse_expression(Rest) of
        {ok, {Body, Remaining}} -> {ok, {{function, Parameter, Body}, Remaining}};
        {error, _} = Error -> Error
    end;
parse_expression(Tokens) ->
    parse_sum(Tokens).

parse_sum(Tokens) ->
    case parse_product(Tokens) of
        {ok, {Left, Rest}} -> sum_rest(Left, Rest);
        {error, _} = Error -> Error
    end.

sum_rest(Left, [{operator, Operator} | Rest]) when Operator =:= $+; Operator =:= $- ->
    case parse_product(Rest) of
        {ok, {Right, Remaining}} -> sum_rest({binary, Operator, Left, Right}, Remaining);
        {error, _} = Error -> Error
    end;
sum_rest(Left, Tokens) ->
    {ok, {Left, Tokens}}.

parse_product(Tokens) ->
    case parse_application(Tokens) of
        {ok, {Left, Rest}} -> product_rest(Left, Rest);
        {error, _} = Error -> Error
    end.

product_rest(Left, [{operator, Operator} | Rest]) when Operator =:= $*; Operator =:= $/ ->
    case parse_application(Rest) of
        {ok, {Right, Remaining}} -> product_rest({binary, Operator, Left, Right}, Remaining);
        {error, _} = Error -> Error
    end;
product_rest(Left, Tokens) ->
    {ok, {Left, Tokens}}.

parse_application(Tokens) ->
    case parse_atom(Tokens) of
        {ok, {Callee, Rest}} -> application_rest(Callee, Rest);
        {error, _} = Error -> Error
    end.

application_rest(Callee, Tokens) ->
    case parse_atom(Tokens) of
        {error, _} -> {ok, {Callee, Tokens}};
        {ok, {Argument, Rest}} -> application_rest({apply, Callee, Argument}, Rest)
    end.

parse_atom([{number, Value} | Rest]) ->
    {ok, {{literal, Value}, Rest}};
parse_atom([{name, Name} | Rest]) ->
    {ok, {{variable, Name}, Rest}};
parse_atom([open_paren | Rest]) ->
    case parse_expression(Rest) of
        {ok, {Inner, [close_paren | Beyond]}} -> {ok, {Inner, Beyond}};
        {ok, {_, [Token | _]}} -> {error, {unexpected, Token}};
        {ok, {_, []}} -> {error, end_of_input};
        {error, _} = Error -> Error
    end;
parse_atom([Token | _]) ->
    {error, {unexpected, Token}};
parse_atom([]) ->
    {error, end_of_input}.

%%
%% The evaluator
%%

eval(_, {literal, Value}) ->
    {ok, {integer, Value}};
eval(Env, {variable, Name}) ->
    case maps:find(Name, Env) of
        {ok, Value} -> {ok, Value};
        error -> {error, {unbound, Name}}
    end;
eval(Env, {function, Parameter, Body}) ->
    {ok, {closure, Parameter, Body, Env}};
eval(Env, {'let', _, Value}) ->
    eval(Env, Value);
eval(Env, {binary, Operator, Left, Right}) ->
    case eval(Env, Left) of
        {ok, LeftValue} ->
            case eval(Env, Right) of
                {ok, RightValue} -> arithmetic(Operator, LeftValue, RightValue);
                {error, _} = Error -> Error
            end;
        {error, _} = Error ->
            Error
    end;
eval(Env, {apply, Callee, Argument}) ->
    case eval(Env, Callee) of
        {ok, Closure} ->
            case eval(Env, Argument) of
                {ok, Value} ->
                    case Closure of
                        {closure, Parameter, Body, Captured} ->
                            eval(maps:put(Parameter, Value, Captured), Body);
                        {integer, _} ->
                            {error, not_a_function}
                    end;
                {error, _} = Error ->
                    Error
            end;
        {error, _} = Error ->
            Error
    end.

arithmetic(Operator, {integer, First}, {integer, Second}) ->
    case Operator of
        $+ -> {ok, {integer, First + Second}};
        $- -> {ok, {integer, First - Second}};
        $* -> {ok, {integer, First * Second}};
        _ when Second =:= 0 -> {error, division_by_zero};
        _ -> {ok, {integer, First div Second}}
    end;
arithmetic(_, _, _) ->
    {error, not_a_number}.
