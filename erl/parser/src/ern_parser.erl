%% Parser for Ernest, report Appendix A. Recursive descent over the token
%% list from ern_lexer, threading {Node, RestTokens}; a precedence-climbing
%% loop for binary operators, a second one for `::` in patterns. First-token
%% dispatch; the three bounded lookaheads named in Appendix A; no
%% backtracking. Errors are thrown and returned as {error, #diag{}}. Every node's
%% pos is its span, set by w/1 from the end of the token before the rest.
-module(ern_parser).

-export([parse/1, parse_string/1, parse_expr/1, parse_stmt/1, parse_type/1]).

-export_type([error/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("lexer/include/ern_diag.hrl").

-type error() :: ern_diag:diag().

-define(DECL_START, [export, type, abstract, fn, 'let', foreign]).
-define(SPECS, [bytes, int, float, utf8, utf16, utf32, big, little, signed, unsigned]).

-spec parse([ern_lexer:token()]) -> {ok, [tuple()]} | {error, error()}.
parse(Tokens) ->
    try
        {ModDoc, Tokens1} = module_doc(Tokens),
        Decls = program(prune_docs(Tokens1), undefined, []),
        {ok, case ModDoc of undefined -> Decls; _ -> [ModDoc | Decls] end}
    catch
        throw:{parse_error, #diag{} = D} -> {error, at_end(Tokens, D)}
    end.

%% Report §11.2: the parser stopped at the end of the input, so more input
%% could finish it and the shell takes another line. The parser is the one
%% that knows; no other reader of a diagnostic looks at the flag.
at_end(Tokens, #diag{span = Span} = D) ->
    case lists:last(Tokens) of
        {eof, Pos} ->
            case ern_diag:span(Pos) of
                Span -> D#diag{incomplete = true};
                _ -> D
            end;
        _ -> D
    end.

-spec parse_string(unicode:chardata()) -> {ok, [tuple()]} | {error, error()}.
parse_string(Text) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} -> parse(Tokens);
        {error, _} = E -> E
    end.

%% One expression, for tests and the shell.
-spec parse_expr(unicode:chardata()) -> {ok, tuple()} | {error, error()}.
parse_expr(Text) ->
    parse_one(Text, fun(Tokens) -> expr(prune_docs(Tokens)) end).

%% One statement of a block, for the shell: report §11.2, a `let` at the
%% prompt is a block `let`.
-spec parse_stmt(unicode:chardata()) -> {ok, tuple()} | {error, error()}.
parse_stmt(Text) ->
    parse_one(Text, fun(Tokens) -> stmt(prune_docs(Tokens)) end).

%% One type, for the prelude tables and tests.
-spec parse_type(unicode:chardata()) -> {ok, tuple()} | {error, error()}.
parse_type(Text) ->
    parse_one(Text, fun type/1).

%% What Parse reads from the whole of Text, which must end there.
parse_one(Text, Parse) ->
    case ern_lexer:tokenize(Text) of
        {ok, Tokens} ->
            try
                case Parse(Tokens) of
                    {Node, [{eof, _}]} -> {ok, Node};
                    {_, [T | _]} ->
                        fail(pos(T), "expected end of input instead of " ++ describe(T))
                end
            catch
                throw:{parse_error, #diag{} = D} -> {error, at_end(Tokens, D)}
            end;
        {error, _} = E ->
            E
    end.

%% Report §2.2: a doc block before the first declaration, with a blank line
%% after it, is the module's documentation.
module_doc([{doc, Pos, Text}, Next | R]) ->
    case line(Next) > doc_end(Pos, Text) + 1 of
        true -> {#module_doc{pos = Pos, text = Text}, [Next | R]};
        false -> {undefined, [{doc, Pos, Text}, Next | R]}
    end;
module_doc(Ts) ->
    {undefined, Ts}.

doc_end(Pos, Text) ->
    element(1, Pos) + length([Ch || <<Ch>> <= Text, Ch =:= $\n]).

%% A doc token survives only where report §2.2 attaches it: on the line
%% before a declaration, or, inside a type declaration, before a
%% constructor, a field, or a signature entry; elsewhere it is an ordinary
%% comment. InType is true inside a type or abstract type declaration,
%% where no expression can occur. Depth counts the open brackets, so that
%% only a declaration keyword outside every bracket ends a type.
prune_docs(Ts) ->
    prune_docs(Ts, false, 0).

prune_docs([{doc, Pos, Text} = D, Next | R], InType, Depth) ->
    Adjacent = line(Next) =:= doc_end(Pos, Text) + 1,
    Keep = Adjacent andalso
           (lists:member(sym(Next), ?DECL_START)
            orelse (InType andalso lists:member(sym(Next), [typename, ident, '|']))),
    Rest = prune_docs([Next | R], InType, Depth),
    case Keep of
        true -> [D | Rest];
        false -> Rest
    end;
prune_docs([T | R], InType, Depth) ->
    {InType1, Depth1} =
        case sym(T) of
            type -> {true, Depth};
            S when S =:= '('; S =:= '#('; S =:= '{' -> {InType, Depth + 1};
            S when S =:= ')'; S =:= '}' -> {InType, Depth - 1};
            S when Depth =:= 0 ->
                {InType andalso not lists:member(S, ?DECL_START), Depth};
            _ -> {InType, Depth}
        end,
    [T | prune_docs(R, InType1, Depth1)];
prune_docs([], _, _) ->
    [].

%%
%% Program and declarations
%%

program([{eof, _}], _Prev, Acc) ->
    lists:reverse(Acc);
program(Ts, Prev, Acc) ->
    {D, Ts1} = declaration(Ts),
    one_clause(D, Prev),
    program(Ts1, D, [D | Acc]).

%% A second consecutive fn with the same name is the Haskell habit.
one_clause(#fn_decl{pos = Pos, owner = O, name = N}, #fn_decl{owner = O, name = N}) ->
    fail(Pos, "a function has one clause", "write one clause whose body is a `match`");
one_clause(_, _) ->
    ok.

declaration(Ts) ->
    {Doc, Ts1} = doc(Ts),
    {Export, Ts2} = case Ts1 of
                        [{export, _} | R] -> {true, R};
                        _ -> {false, Ts1}
                    end,
    case Ts2 of
        [{type, _} | _] -> type_decl(Ts2, Doc, Export);
        [{abstract, _} | _] -> abstract_decl(Ts2, Doc, Export);
        [{fn, _} | _] -> fn_decl(Ts2, Doc, Export);
        [{'let', _} | _] -> let_decl(Ts2, Doc, Export);
        [{foreign, _} | _] -> foreign_decl(Ts2, Doc, Export);
        [T | _] -> wanted(declaration, pos(T),
                          "expected a declaration (type, abstract, fn, let, foreign)"
                                " instead of " ++ describe(T))
    end.

doc([{doc, _, Text} | R]) -> {Text, R};
doc(Ts) -> {undefined, Ts}.

type_decl([{type, Pos} | R], Doc, Export) ->
    {Name, R1} = expect_typename(R),
    {Params, R2} = opt_typevars(R1),
    R3 = expect(R2, '='),
    {Cons, R4} = constructors(R3),
    w({#type_decl{pos = Pos, doc = Doc, export = Export, name = Name, params = Params,
                  constructors = Cons}, R4}).

opt_typevars([{'(', _} | R]) ->
    {Vars, R1} = sep_by(R, ',', fun expect_ident/1),
    {Vars, expect(R1, ')')};
opt_typevars(Ts) ->
    {[], Ts}.

%% Report §2.2: a doc block before a constructor documents it, on the line
%% above the constructor or above the `|` that leads it.
constructors(Ts) ->
    {C, R} = constructor(Ts),
    constructors_rest(R, [C]).

constructors_rest([{doc, _, Text}, {'|', _} | R], Acc) ->
    {C, R1} = constructor(R, Text),
    constructors_rest(R1, [C | Acc]);
constructors_rest([{'|', _} | R], Acc) ->
    {C, R1} = constructor(R),
    constructors_rest(R1, [C | Acc]);
constructors_rest(R, Acc) ->
    {lists:reverse(Acc), R}.

constructor(Ts) ->
    {Doc, Ts1} = doc(Ts),
    constructor(Ts1, Doc).

constructor(Ts, Doc) ->
    {Name, Pos, R} = expect_typename_pos(Ts),
    Named = case R of
                [{'(', _}, {ident, _, _}, {':', _} | _] -> true;
                [{'(', _}, {doc, _, _}, {ident, _, _}, {':', _} | _] -> true;
                _ -> false
            end,
    case R of
        [{'(', _} | R1] when Named ->
            {Fields, R2} = sep_by(R1, ',', fun field/1),
            w({#constructor{pos = Pos, doc = Doc, name = Name, fields = {named, Fields}},
               expect(R2, ')')});
        [{'(', _} | R1] ->
            {T, R2} = type(R1),
            w({#constructor{pos = Pos, doc = Doc, name = Name, fields = {positional, T}},
               expect(R2, ')')});
        _ ->
            w({#constructor{pos = Pos, doc = Doc, name = Name}, R})
    end.

field(Ts) ->
    {Doc, Ts1} = doc(Ts),
    {Name, Pos, R} = expect_ident_pos(Ts1),
    {T, R1} = type(expect(R, ':')),
    w({#field{pos = Pos, doc = Doc, name = Name, type = T}, R1}).

abstract_decl([{abstract, Pos} | R], Doc, Export) ->
    {TD, R1} = case R of
                   [{type, _} | _] -> type_decl(R, undefined, false);
                   [T | _] -> fail(pos(T), "expected `type` after `abstract`")
               end,
    R2 = expect(expect(R1, with), '{'),
    {Sigs, R3} = sep_by(R2, ';', fun signature/1),
    w({#abstract_decl{pos = Pos, doc = Doc, export = Export, type = TD, signatures = Sigs},
       expect(R3, '}')}).

signature(Ts) ->
    {Doc, Ts1} = doc(Ts),
    signature(Ts1, Doc).

signature([{ident, Pos, Name} | R], Doc) ->
    {T, R1} = type(expect(R, ':')),
    w({#signature{pos = Pos, doc = Doc, name = Name, type = T}, R1});
signature([{Op, Pos} | R], Doc) when Op =:= '+'; Op =:= '-'; Op =:= '*'; Op =:= '/';
                                     Op =:= '%'; Op =:= '<>' ->
    {T, R1} = type(expect(R, ':')),
    w({#signature{pos = Pos, doc = Doc, name = Op, type = T}, R1});
signature([T | _], _) ->
    fail(pos(T), "expected a signature name instead of " ++ describe(T)).

fn_decl([{fn, Pos} | R], Doc, Export) ->
    {Owner, Name, R1} = decl_name(R),
    {Params, R2} = params(R1),
    {Ret, Effect, R3} = opt_return(R2),
    {Body, R4} = expr(expect(R3, '=')),
    w({#fn_decl{pos = Pos, doc = Doc, export = Export, owner = Owner, name = Name,
                params = Params, ret = Ret, effect = Effect, body = Body}, R4}).

decl_name([{ident, _, Name} | R]) ->
    {undefined, Name, R};
decl_name([{typename, _, Owner}, {'.', _}, {ident, _, Name} | R]) ->
    {Owner, Name, R};
decl_name([{typename, _, Owner}, {'.', _}, {Op, _} | R]) when Op =:= '+'; Op =:= '-';
                                                             Op =:= '*'; Op =:= '/';
                                                             Op =:= '%'; Op =:= '<>' ->
    {Owner, Op, R};
decl_name([{typename, _, _}, {'.', _}, T | _]) ->
    fail(pos(T), "expected a member name or operator after `.` instead of " ++ describe(T));
decl_name([{typename, Pos, T} | _]) ->
    fail(Pos, "expected a name; a type member is written `" ++ atom_to_list(T) ++ ".name`");
decl_name([T | _]) ->
    fail(pos(T), "expected a name instead of " ++ describe(T)).

params(Ts) ->
    R = expect(Ts, '('),
    case R of
        [{')', _} | R1] -> {[], R1};
        _ ->
            {Ps, R1} = sep_by(R, ',', fun param/1),
            {Ps, expect(R1, ')')}
    end.

param(Ts) ->
    {P, R} = pattern(Ts),
    case R of
        [{':', _} | R1] ->
            {T, R2} = type(R1),
            w({#param{pos = node_pos(P), pattern = P, type = T}, R2});
        _ ->
            w({#param{pos = node_pos(P), pattern = P}, R})
    end.

opt_return([{'->', _} | R]) ->
    {T, R1} = type(R),
    case R1 of
        [{with, _} | R2] ->
            {E, R3} = type(R2),
            {T, E, R3};
        _ ->
            {T, undefined, R1}
    end;
opt_return(Ts) ->
    {undefined, undefined, Ts}.

let_decl([{'let', Pos} | R], Doc, Export) ->
    {Owner, Name, R1} = decl_name(R),
    {Ann, R2} = case R1 of
                    [{':', _} | R1a] -> type(R1a);
                    _ -> {undefined, R1}
                end,
    R3 = case R2 of
             [{'<-', P} | _] -> fail(P, "`<-` is a block form", "a top-level `let` uses `=`");
             _ -> expect(R2, '=')
         end,
    {Body, R4} = expr(R3),
    w({#let_decl{pos = Pos, doc = Doc, export = Export, owner = Owner, name = Name, ann = Ann,
                 body = Body}, R4}).

foreign_decl([{foreign, Pos}, {type, _} | R], Doc, Export) ->
    {Name, R1} = expect_typename(R),
    {Params, R2} = opt_typevars(R1),
    w({#foreign_type_decl{pos = Pos, doc = Doc, export = Export, name = Name, params = Params},
       R2});
foreign_decl([{foreign, Pos}, {fn, _} | R], Doc, Export) ->
    {Owner, Name, R1} = decl_name(R),
    R2 = expect(R1, '('),
    {Params, R3} = case R2 of
                       [{')', _} | _] -> {[], R2};
                       _ -> sep_by(R2, ',', fun foreign_param/1)
                   end,
    R4 = expect(R3, ')'),
    {Ret, Effect, R5} = case opt_return(R4) of
                            {undefined, _, _} ->
                                fail(pos(hd(R4)), "a foreign function declares its return type");
                            Ok -> Ok
                        end,
    R6 = expect(R5, '='),
    case R6 of
        [{string, _, Impl} | R7] ->
            w({#foreign_fn_decl{pos = Pos, doc = Doc, export = Export, owner = Owner,
                                name = Name, params = Params, ret = Ret, effect = Effect,
                                impl = Impl}, R7});
        [T | _] ->
            fail(pos(T), "expected the implementation name as a string instead of "
                         ++ describe(T))
    end;
foreign_decl([{foreign, _}, T | _], _Doc, _Export) ->
    fail(pos(T), "expected `type` or `fn` after `foreign` instead of " ++ describe(T)).

foreign_param(Ts) ->
    {Name, Pos, R} = expect_ident_pos(Ts),
    {PV, _} = w({#p_var{pos = Pos, name = Name}, R}),
    {T, R1} = type(expect(R, ':')),
    w({#param{pos = Pos, pattern = PV, type = T}, R1}).

%%
%% Types
%%

type([{'(', Pos} | R]) ->
    {Elems, R1} = case R of
                      [{')', _} | _] -> {[], R};
                      _ -> sep_by(R, ',', fun type/1)
                  end,
    R2 = expect(R1, ')'),
    case R2 of
        [{'->', _} | R3] ->
            {Ret, R4} = type(R3),
            case R4 of
                [{with, _} | R5] ->
                    {Eff, R6} = type(R5),
                    w({#t_fn{pos = Pos, params = Elems, ret = Ret, effect = Eff}, R6});
                _ ->
                    w({#t_fn{pos = Pos, params = Elems, ret = Ret}, R4})
            end;
        _ ->
            case Elems of
                [T] -> w({T, R2});
                [] -> fail(Pos, "expected a type inside the parentheses, or `->` after them");
                _ -> fail(pos(hd(R2)), "expected `->` after a parameter list instead of "
                                       ++ describe(hd(R2)))
            end
    end;
type([{'#(', Pos} | R]) ->
    {Elems, R1} = sep_by(R, ',', fun type/1),
    w({#t_tuple{pos = Pos, elems = Elems}, expect(R1, ')')});
type([{typename, Pos, _} | _] = Ts) ->
    case qualified(Ts) of
        {{con, Path, Name}, [{'(', _} | R]} ->
            {Args, R1} = sep_by(R, ',', fun type/1),
            w({#t_con{pos = Pos, path = Path, name = Name, args = Args}, expect(R1, ')')});
        {{con, Path, Name}, R} ->
            w({#t_con{pos = Pos, path = Path, name = Name}, R});
        {{value, _, _}, _} ->
            fail(Pos, "expected a type name; a qualified type ends in an uppercase name")
    end;
type([{ident, Pos, Name} | R]) ->
    w({#t_var{pos = Pos, name = Name}, R});
type([T | _]) ->
    wanted(typename, pos(T), "expected a type instead of " ++ describe(T)).

%% {typename "."} followed by a final segment. Returns {con, Path, Name} for
%% an uppercase final, {value, Path, Name} for an ident or userop final.
qualified([{typename, _, T} | R]) ->
    qualified(R, [], T).

qualified([{'.', _}, {typename, _, T2} | R], Path, Cur) ->
    qualified(R, Path ++ [Cur], T2);
qualified([{'.', _}, {ident, _, N} | R], Path, Cur) ->
    {{value, Path ++ [Cur], N}, R};
qualified([{'.', _}, {Op, _} | R], Path, Cur) when Op =:= '+'; Op =:= '-'; Op =:= '*';
                                                  Op =:= '/'; Op =:= '%'; Op =:= '<>' ->
    {{value, Path ++ [Cur], Op}, R};
qualified([{'.', _}, T | _], _Path, _Cur) ->
    fail(pos(T), "expected a name after `.` instead of " ++ describe(T));
qualified(R, Path, Cur) ->
    {{con, Path, Cur}, R}.

%%
%% Expressions
%%

expr(Ts) ->
    {E, R} = case Ts of
                 [{fn, Pos} | R0] -> lambda(R0, Pos);
                 [{'if', Pos} | R0] -> if_expr(R0, Pos);
                 [{match, Pos} | R0] -> match_expr(R0, Pos);
                 [{'receive', Pos} | R0] -> receive_expr(R0, Pos);
                 _ -> binexpr(Ts, 0)
             end,
    juxtaposition(R),
    {E, R}.

%% `f x` where `f(x)` was meant: an operand directly after an expression.
juxtaposition([T | _]) when element(1, T) =:= ident; element(1, T) =:= typename;
                            element(1, T) =:= int; element(1, T) =:= float;
                            element(1, T) =:= char; element(1, T) =:= string;
                            element(1, T) =:= bool ->
    fail(pos(T), "unexpected " ++ describe(T) ++ " after an expression",
         "a call is written f(x), and statements are separated by `;`");
juxtaposition(_) ->
    ok.

lambda(Ts, Pos) ->
    {Params, R1} = params(Ts),
    {Ret, Effect, R2} = opt_return(R1),
    {Body, R3} = expr(expect(R2, '=')),
    w({#e_lambda{pos = Pos, params = Params, ret = Ret, effect = Effect, body = Body}, R3}).

if_expr(Ts, Pos) ->
    {Cond, R1} = expr(Ts),
    {Then, R2} = expr(expect(R1, then)),
    case R2 of
        [{'else', _} | R3] ->
            {Else, R4} = expr(R3),
            w({#e_if{pos = Pos, condition = Cond, then_branch = Then, else_branch = Else}, R4});
        [T | _] ->
            fail(pos(T), "`if` needs an `else`", "every `if` is an expression; give the"
                 " other branch a value")
    end.

match_expr(Ts, Pos) ->
    {Scrutinee, R1} = expr(Ts),
    R2 = expect(R1, '{'),
    {Clauses, R3} = sep_by(R2, '|', fun clause/1),
    w({#e_match{pos = Pos, scrutinee = Scrutinee, clauses = Clauses}, expect(R3, '}')}).

receive_expr(Ts, Pos) ->
    R = expect(Ts, '{'),
    {Clauses, After, R1} = receive_clauses(R, []),
    w({#e_receive{pos = Pos, clauses = Clauses, 'after' = After}, expect(R1, '}')}).

receive_clauses([{'after', Pos} | R], Acc) ->
    {Timeout, R1} = expr(R),
    {Body, R2} = expr(expect(R1, '->')),
    {After, _} = w({#after_clause{pos = Pos, timeout = Timeout, body = Body}, R2}),
    {lists:reverse(Acc), After, R2};
receive_clauses(Ts, Acc) ->
    {C, R} = clause(Ts),
    case R of
        [{'|', _} | R1] -> receive_clauses(R1, [C | Acc]);
        _ -> {lists:reverse([C | Acc]), undefined, R}
    end.

%% Report §5.9: a clause lists one or more patterns separated by `or`.
clause(Ts) ->
    {Alts, R} = sep_by(Ts, 'or', fun pattern/1),
    {P, _} = case Alts of
                 [Single] -> {Single, R};
                 [First | _] -> w({#p_or{pos = node_pos(First), alts = Alts}, R})
             end,
    {Guard, R1} = case R of
                      [{'when', _} | R0] -> expr(R0);
                      _ -> {undefined, R}
                  end,
    {Body, R2} = expr(expect(R1, '->')),
    w({#clause{pos = node_pos(P), pattern = P, guard = Guard, body = Body}, R2}).

%% Precedence climbing. Higher binds tighter; report §2.6 numbers the levels
%% the other way round.
binexpr(Ts, Min) ->
    {Left, R} = unary(Ts),
    binexpr_loop(Left, R, Min).

binexpr_loop(Left, [{Op, Pos} | R] = Ts, Min) ->
    case prec(Op) of
        {P, Assoc} when P >= Min ->
            NextMin = case Assoc of left -> P + 1; right -> P end,
            {Right, R1} = binexpr(R, NextMin),
            Start = start_of(Left, Pos),
            Combined = case Op =:= '|>' andalso parenthesized(R, R1) of
                           %% report §5.7: a parenthesized right-hand side is a
                           %% value, applied to the left
                           true -> #e_call{pos = Start, callee = Right, args = [Left]};
                           false -> combine(Op, Start, Left, Right)
                       end,
            {Node, _} = w({Combined, R1}),
            binexpr_loop(Node, R1, Min);
        _ ->
            {Left, Ts}
    end;
binexpr_loop(Left, Ts, _Min) ->
    {Left, Ts}.

prec('*') -> {7, left};
prec('/') -> {7, left};
prec('%') -> {7, left};
prec('+') -> {6, left};
prec('-') -> {6, left};
prec('<>') -> {6, left};
prec('::') -> {5, right};
prec('==') -> {4, left};
prec('!=') -> {4, left};
prec('<') -> {4, left};
prec('<=') -> {4, left};
prec('>') -> {4, left};
prec('>=') -> {4, left};
prec('&&') -> {3, left};
prec('||') -> {2, left};
prec('|>') -> {1, left};
prec(_) -> none.

%% Whether the tokens from Ts to Rest are one parenthesized expression and
%% nothing more; parentheses produce no node, so only the tokens can say.
parenthesized([{'(', _} | _] = Ts, Rest) ->
    {_, AfterParen} = primary(Ts),
    length(AfterParen) =:= length(Rest);
parenthesized(_, _) ->
    false.

%% `x |> f(a)` is `f(x, a)`; `x |> f` is `f(x)`.
combine('|>', Pos, X, #e_call{callee = C, args = A}) ->
    #e_call{pos = Pos, callee = C, args = [X | A]};
combine('|>', Pos, X, F) ->
    #e_call{pos = Pos, callee = F, args = [X]};
combine(Op, Pos, L, R) ->
    #e_binop{pos = Pos, op = Op, left = L, right = R}.

%% An operator expression spans from its left operand (report §11.5).
start_of(Left, OpPos) ->
    LPos = element(2, Left),
    {element(1, LPos), element(2, LPos), element(3, OpPos), element(4, OpPos)}.

unary([{'-', Pos} | R]) ->
    {E, R1} = postfix(R),
    w({#e_neg{pos = Pos, expr = E}, R1});
unary([{'!', Pos} | R]) ->
    %% report §4.8: prefix negation on Bool
    {E, R1} = postfix(R),
    w({#e_not{pos = Pos, expr = E}, R1});
unary(Ts) ->
    postfix(Ts).

postfix(Ts) ->
    {P, R} = primary(Ts),
    calls(P, R).

calls(Callee, [{'(', _} | R]) ->
    {Args, R1} = case R of
                     [{')', _} | _] -> {[], R};
                     _ -> arguments(Callee, R, 0)
                 end,
    Closed = inside(Callee, max(0, length(Args) - 1), fun() -> expect(R1, ')') end),
    {Call, R2} = w({#e_call{pos = node_pos(Callee), callee = Callee, args = Args}, Closed}),
    calls(Call, R2);
calls(E, Ts) ->
    {E, Ts}.

%% A call's arguments, each parsed as the argument it is, so that an input
%% that stops inside one says which.
arguments(Callee, Ts, N) ->
    {X, R} = inside(Callee, N, fun() -> expr(Ts) end),
    case R of
        [{',', _} | R1] ->
            {Xs, R2} = arguments(Callee, R1, N + 1),
            {[X | Xs], R2};
        _ ->
            {[X], R}
    end.

%% Report §11.2: the call an unfinished input stops inside, its callee and
%% the argument at the cursor, for `Shift-Tab`. The innermost call is the
%% first to catch the error, so it is the one that names itself.
inside(#e_var{path = Path, name = Name}, N, Parse) ->
    try Parse()
    catch throw:{parse_error, #diag{within = undefined} = D} ->
        throw({parse_error, D#diag{within = {Path, Name, N}}})
    end;
inside(_, _, Parse) ->
    Parse().

primary([{Kind, Pos, V} | R]) when Kind =:= int; Kind =:= float; Kind =:= char;
                                   Kind =:= string; Kind =:= bool ->
    w({#e_lit{pos = Pos, kind = Kind, value = V}, R});
primary([{ident, Pos, Name} | R]) ->
    w({#e_var{pos = Pos, name = Name}, R});
primary([{typename, Pos, _} | _] = Ts) ->
    case qualified(Ts) of
        {{value, Path, Name}, R} -> w({#e_var{pos = Pos, path = Path, name = Name}, R});
        {{con, Path, Name}, R} -> constructor_expr(Pos, Path, Name, R)
    end;
primary([{'#(', Pos} | R]) ->
    {Elems, R1} = sep_by(R, ',', fun expr/1),
    w({#e_tuple{pos = Pos, elems = Elems}, expect(R1, ')')});
primary([{'[', Pos} | R]) ->
    {Elems, R1} = case R of
                      [{']', _} | _] -> {[], R};
                      _ -> sep_by(R, ',', fun expr/1)
                  end,
    w({#e_list{pos = Pos, elems = Elems}, expect(R1, ']')});
primary([{'<<', Pos} | R]) ->
    {Segs, R1} = bit_segments(R, fun expr/1),
    w({#e_bits{pos = Pos, segments = Segs}, R1});
primary([{'{', Pos} | R]) ->
    block(R, Pos);
primary([{'(', _} | R]) ->
    {E, R1} = expr(R),
    w({E, expect(R1, ')')});
primary([{'_', Pos} | _]) ->
    fail(Pos, "`_` is a pattern, not an expression");
primary([{Kw, Pos} | _]) when Kw =:= 'if'; Kw =:= match; Kw =:= 'receive'; Kw =:= fn ->
    fail(Pos, "`" ++ atom_to_list(Kw) ++ "` is not an operand", "parenthesize it");
primary([T | _]) ->
    wanted(expression, pos(T), "expected an expression instead of " ++ describe(T)).

constructor_expr(Pos, Path, Name, [{'(', _} | R]) ->
    case R of
        [{'..', _} | R1] ->
            {Base, R2} = expr(R1),
            {Sets, R3} = sep_by(expect(R2, ','), ',', field_of(Path, Name)),
            w({#e_con{pos = Pos, path = Path, name = Name, args = {named, Base, Sets}},
               expect(R3, ')')});
        [{ident, _, _}, {'=', _} | _] ->
            {Sets, R1} = sep_by(R, ',', field_of(Path, Name)),
            w({#e_con{pos = Pos, path = Path, name = Name, args = {named, undefined, Sets}},
               expect(R1, ')')});
        [{')', P} | _] ->
            fail(P, "a constructor's fields are listed inside the parentheses",
                 "a nullary constructor takes none: write it without parentheses");
        [{eof, P} | _] ->
            %% report §11.2: the input ends where the constructor's first
            %% argument would stand, and positional or named is not
            %% decided yet: what may stand here is a value or a field's
            %% name, and only the constructor's type tells which
            inside_con(Path, Name, none, fun() ->
                wanted({field_or_value, Name}, P, "expected an expression instead of end of input")
            end);
        _ ->
            {E, R1} = inside_con(Path, Name, 0, fun() -> expr(R) end),
            w({#e_con{pos = Pos, path = Path, name = Name, args = {positional, E}},
               expect(R1, ')')})
    end;
constructor_expr(Pos, Path, Name, Ts) ->
    w({#e_con{pos = Pos, path = Path, name = Name}, Ts}).

%% Report §11.2: a field of this constructor, which the tag names, so
%% that completion knows which fields may stand at the cursor; and where
%% the input stops, which field's value it stops in, or `none` where a
%% field's name would stand, for `Shift-Tab`.
field_of(Path, Con) ->
    fun(Ts) ->
        {Name, Pos, R} = inside_con(Path, Con, none, fun() ->
                             tagging({field, Con}, fun() -> expect_ident_pos(Ts) end)
                         end),
        {E, R1} = inside_con(Path, Con, {field, Name}, fun() -> expr(expect(R, '=')) end),
        w({#field_set{pos = Pos, name = Name, expr = E}, R1})
    end.

%% Report §11.2: the constructor an unfinished input stops inside, as
%% `inside/3` records a call.
inside_con(Path, Name, At, Parse) ->
    try Parse()
    catch throw:{parse_error, #diag{within = undefined} = D} ->
        throw({parse_error, D#diag{within = {Path, Name, At}}})
    end.

%%
%% Blocks
%%

block([{'}', Pos} | _], _BlockPos) ->
    fail(Pos, "a block needs at least one expression");
block(Ts, Pos) ->
    {Stmts, R} = stmts(Ts, undefined, []),
    w({#e_block{pos = Pos, stmts = Stmts}, R}).

stmts(Ts, Prev, Acc) ->
    {S, R} = stmt(Ts),
    one_clause(S, Prev),
    case R of
        [{';', _}, {'}', P} | _] ->
            fail(P, "a block ends with an expression", "remove the trailing `;`");
        [{';', _} | R1] ->
            stmts(R1, S, [S | Acc]);
        [{'}', P} | R1] ->
            case S of
                #binding{} -> fail(P, "a block ends with an expression, not a `let`",
                                    "add the expression the block is worth after it");
                #fn_decl{} -> fail(P, "a block ends with an expression, not a `fn`",
                                    "add the expression the block is worth after it");
                _ -> {lists:reverse([S | Acc]), R1}
            end;
        [T | _] ->
            fail(pos(T), "expected `;` or `}` instead of " ++ describe(T))
    end.

stmt([{doc, _, Text} | R]) ->
    case stmt(R) of
        {#fn_decl{} = F, R1} -> {F#fn_decl{doc = Text}, R1};
        Other -> Other
    end;
stmt([{'let', Pos} | R]) ->
    {P, R1} = pattern(R),
    {Ann, R2} = case R1 of
                    [{':', _} | R1a] -> type(R1a);
                    _ -> {undefined, R1}
                end,
    {Op, R3} = case R2 of
                   [{'=', _} | R2a] -> {'=', R2a};
                   [{'<-', _} | R2a] -> {'<-', R2a};
                   [T | _] -> fail(pos(T), "expected `=` or `<-` instead of " ++ describe(T))
               end,
    {E, R4} = expr(R3),
    w({#binding{pos = Pos, pattern = P, ann = Ann, op = Op, expr = E}, R4});
stmt([{fn, _}, {'(', _} | _] = Ts) ->
    expr(Ts);
stmt([{fn, _} | _] = Ts) ->
    fn_decl(Ts, undefined, false);
stmt(Ts) ->
    expr(Ts).

%%
%% Patterns
%%

pattern(Ts) ->
    {P, R} = conspat(Ts),
    case R of
        [{as, _}, {ident, _, Name} | R1] ->
            w({#p_as{pos = node_pos(P), pattern = P, name = Name}, R1});
        [{as, _}, T | _] ->
            fail(pos(T), "expected a name after `as` instead of " ++ describe(T));
        _ ->
            {P, R}
    end.

conspat(Ts) ->
    {Head, R} = atompat(Ts),
    case R of
        [{'::', Pos} | R1] ->
            {Tail, R2} = conspat(R1),
            w({#p_cons{pos = Pos, head = Head, tail = Tail}, R2});
        _ ->
            {Head, R}
    end.

atompat([{'_', Pos} | R]) ->
    w({#p_wild{pos = Pos}, R});
atompat([{ident, Pos, Name} | R]) ->
    w({#p_var{pos = Pos, name = Name}, R});
atompat([{Kind, Pos, V} | R]) when Kind =:= int; Kind =:= float; Kind =:= char;
                                   Kind =:= string; Kind =:= bool ->
    w({#p_lit{pos = Pos, kind = Kind, value = V}, R});
atompat([{'-', Pos}, {Kind, _, V} | R]) when Kind =:= int; Kind =:= float ->
    w({#p_lit{pos = Pos, kind = Kind, value = -V}, R});
atompat([{'-', _}, T | _]) ->
    fail(pos(T), "expected a number after `-` in a pattern instead of " ++ describe(T));
atompat([{typename, Pos, _} | _] = Ts) ->
    case qualified(Ts) of
        {{con, Path, Name}, R} -> constructor_pat(Pos, Path, Name, R);
        {{value, _, _}, _} -> fail(Pos, "expected a constructor; a pattern cannot name a"
                                       " function or value")
    end;
atompat([{'#(', Pos} | R]) ->
    {Elems, R1} = sep_by(R, ',', fun pattern/1),
    w({#p_tuple{pos = Pos, elems = Elems}, expect(R1, ')')});
atompat([{'[', Pos} | R]) ->
    {Elems, R1} = case R of
                      [{']', _} | _] -> {[], R};
                      _ -> sep_by(R, ',', fun pattern/1)
                  end,
    w({#p_list{pos = Pos, elems = Elems}, expect(R1, ']')});
atompat([{'<<', Pos} | R]) ->
    {Segs, R1} = bit_segments(R, fun pattern/1),
    w({#p_bits{pos = Pos, segments = Segs}, R1});
atompat([T | _]) ->
    wanted(pattern, pos(T), "expected a pattern instead of " ++ describe(T)).

constructor_pat(Pos, Path, Name, [{'(', _} | R]) ->
    case R of
        [{')', _} | R1] ->
            w({#p_con{pos = Pos, path = Path, name = Name, args = {named, []}}, R1});
        [{ident, _, _}, {'=', _} | _] ->
            {Fields, R1} = sep_by(R, ',', field_pat_of(Name)),
            w({#p_con{pos = Pos, path = Path, name = Name, args = {named, Fields}},
               expect(R1, ')')});
        [{eof, P} | _] ->
            %% report §11.2: as in an expression, a field's name or a
            %% pattern may stand here, and the constructor's type tells
            wanted({field_or_pattern, Name}, P, "expected a pattern instead of end of input");
        _ ->
            {P, R1} = pattern(R),
            w({#p_con{pos = Pos, path = Path, name = Name, args = {positional, P}},
               expect(R1, ')')})
    end;
constructor_pat(Pos, Path, Name, Ts) ->
    w({#p_con{pos = Pos, path = Path, name = Name}, Ts}).

%% Report §11.2: a field of this constructor in a pattern, tagged as in
%% an expression, so that completion knows which fields may stand there.
field_pat_of(Con) ->
    fun(Ts) ->
        {Name, Pos, R} = tagging({field, Con}, fun() -> expect_ident_pos(Ts) end),
        {P, R1} = pattern(expect(R, '=')),
        w({#field_pat{pos = Pos, name = Name, pattern = P}, R1})
    end.

%%
%% Bitstrings. Value is parsed by Parse (an expression or a pattern).
%%

bit_segments([{'>>', _} | R], _Parse) ->
    {[], R};
bit_segments(Ts, Parse) ->
    {Segs, R} = sep_by(Ts, ',', fun(T) -> bit_segment(T, Parse) end),
    {Segs, expect(R, '>>')}.

bit_segment(Ts, Parse) ->
    {V, R} = Parse(Ts),
    case R of
        [{':', _} | R1] ->
            {Specs, R2} = sep_by(R1, '-', fun bit_spec/1),
            w({#bit_seg{pos = node_pos(V), value = V, specs = Specs}, R2});
        _ ->
            w({#bit_seg{pos = node_pos(V), value = V}, R})
    end.

bit_spec([{ident, _, size}, {'(', _} | R]) ->
    {E, R1} = expr(R),
    {{size, E}, expect(R1, ')')};
bit_spec([{ident, _, unit}, {'(', _}, {int, _, N}, {')', _} | R]) ->
    {{unit, N}, R};
bit_spec([{ident, Pos, unit} | _]) ->
    fail(Pos, "`unit` takes an integer in parentheses");
bit_spec([{ident, Pos, Name} | R]) ->
    case lists:member(Name, ?SPECS) of
        true -> {Name, R};
        false -> fail(Pos, "unknown bitstring specifier `" ++ atom_to_list(Name) ++ "`")
    end;
bit_spec([T | _]) ->
    fail(pos(T), "expected a bitstring specifier instead of " ++ describe(T)).

%%
%% Token helpers
%%

sep_by(Ts, Sep, Parse) ->
    {X, R} = Parse(Ts),
    case R of
        [{Sep, _} | R1] ->
            {Xs, R2} = sep_by(R1, Sep, Parse),
            {[X | Xs], R2};
        _ ->
            {[X], R}
    end.

expect([{Sym, _} | R], Sym) ->
    R;
expect([{'<-', _} = T | _], Sym) ->
    %% report §2.6, §11.5: max-munch makes `a<-1` a binding arrow, which a
    %% comparison with a negative number was meant as
    fail(pos(T), "expected `" ++ atom_to_list(Sym) ++ "` instead of " ++ describe(T),
         "`<-` is one token; write `a < -1` to compare with a negative number");
expect([T | _], Sym) ->
    fail(pos(T), "expected `" ++ atom_to_list(Sym) ++ "` instead of " ++ describe(T)).

expect_ident(Ts) ->
    {Name, _, R} = expect_ident_pos(Ts),
    {Name, R}.

expect_ident_pos([{ident, Pos, Name} | R]) -> {Name, Pos, R};
expect_ident_pos([T | _]) -> fail(pos(T), "expected a name instead of " ++ describe(T)).

expect_typename(Ts) ->
    {Name, _, R} = expect_typename_pos(Ts),
    {Name, R}.

expect_typename_pos([{typename, Pos, Name} | R]) -> {Name, Pos, R};
expect_typename_pos([T | _]) ->
    wanted(typename, pos(T), "expected a type name instead of " ++ describe(T)).

sym(T) -> element(1, T).
pos(T) -> element(2, T).
line(T) -> element(1, pos(T)).
node_pos(Node) -> element(2, Node).

%% Report §11.5: a node's pos is its span, from the node's first token to
%% the end of the token before the rest, which every token carries.
w({Node, R}) ->
    Pos = element(2, Node),
    End = case R of
              [Next | _] -> element(4, element(2, Next));
              [] -> element(3, Pos)
          end,
    {setelement(2, Node, {element(1, Pos), element(2, Pos), End}), R}.

describe({ident, _, N}) -> "identifier `" ++ atom_to_list(N) ++ "`";
describe({typename, _, N}) -> "type name `" ++ atom_to_list(N) ++ "`";
describe({int, _, V}) -> "integer " ++ integer_to_list(V);
describe({float, _, V}) -> "float " ++ float_to_list(V, [short]);
describe({char, _, _}) -> "char literal";
describe({string, _, _}) -> "string literal";
describe({bool, _, V}) -> "`" ++ atom_to_list(V) ++ "`";
describe({doc, _, _}) -> "doc comment";
describe({eof, _}) -> "end of input";
describe({Sym, _}) -> "`" ++ atom_to_list(Sym) ++ "`".

fail(Pos, Message) ->
    fail(Pos, Message, undefined).

%% Report §11.2: what the parser wanted here, for the shell's
%% completion, which asks what may stand at the cursor. Only the
%% categories completion acts on are marked; every other failure leaves
%% the field alone.
wanted(What, Pos, Message) ->
    tagging(What, fun() -> fail(Pos, Message) end).

%% What a failure inside this call wanted, where the caller knows it and
%% the failing code does not: a field name belongs to its constructor.
tagging(What, Parse) ->
    try Parse()
    catch throw:{parse_error, #diag{expected = undefined} = D} ->
        throw({parse_error, D#diag{expected = What}})
    end.

%% Report §11.5: the message states the rule, the help line the fix.
fail(Pos, Message, Help) ->
    throw({parse_error, #diag{span = ern_diag:span(Pos), message = lists:flatten(Message),
                              help = Help}}).
