%% The formatter, report §11.6: a module in its one layout, where only
%% line breaks and the spaces between tokens change. Every token is
%% written as it was written, cut from the source by its span, so a
%% literal's spelling, a parenthesis and the form a `|>` took stay as they
%% are; every comment stays beside the token it was beside.
%%
%% Two passes. The first walks the parse tree and builds a template of
%% the layout, one function per production of Appendix A, naming each
%% token in the order the source has it. The second walks the template in
%% that order with a cursor over the tokens, which fills in each token's
%% text and the comments before and after it, and yields the layout
%% ern_pretty prints. Parentheses make no node in the tree, so the second
%% pass finds a node's own by the brackets' pairs.
-module(ern_format).

-export([format/1, markdown/1]).

-include_lib("parser/include/ern_ast.hrl").

%% What the template reads: the code tokens and their text as written,
%% where each begins and ends, and each opening bracket's closing one.
-record(ctx, {toks, texts, starts, ends, pairs}).

%% The cursor of the second pass: the next code token, the comments not
%% yet written, the last line written from the source, the code token
%% before, and whether a blank line must come before what comes next.
-record(cur, {i = 1, trivia = [], last = 0, prev = none, force = false}).

%% A module in the layout, or the diagnostic that stopped it.
-spec format(unicode:chardata()) ->
          {ok, unicode:unicode_binary()} | {error, ern_diagnostic:diagnostic()}.
format(Text) ->
    Source = source_lines(Text),
    case ern_lexer:tokenize(Text, [comments]) of
        {error, _} = E -> E;
        {ok, Tokens} ->
            {Code, Trivia} = split(Tokens, Source),
            case ern_parser:parse(Code) of
                {error, _} = E -> E;
                {ok, Decls} ->
                    X = context(Code, Source),
                    Template = module(Decls, X),
                    {Doc, C} = resolve(Template, X, #cur{trivia = Trivia}),
                    {Tail, C1} = lead(C, X),
                    case {tuple_size(X#ctx.toks) =:= C1#cur.i, C1#cur.trivia} of
                        {true, []} -> ok;
                        _ -> error({not_all_written, C1#cur.i, C1#cur.trivia})
                    end,
                    {ok, ern_pretty:render([Doc, Tail])}
            end
    end.

%% A CommonMark text with each Ernest block in the layout: one that
%% parses as a module is laid out as one, one that parses as a function's
%% body, as a doc block's example does, as that body, and any other is
%% left as it is (report §11.6).
-spec markdown(unicode:unicode_binary()) -> unicode:unicode_binary().
markdown(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    iolist_to_binary(lists:join(<<"\n">>, fences(Lines))).

fences([]) ->
    [];
fences([Line | Rest]) ->
    Trimmed = string:trim(Line, leading),
    case string:prefix(Trimmed, <<"```ernest">>) of
        nomatch -> [Line | fences(Rest)];
        _ ->
            Indent = byte_size(Line) - byte_size(Trimmed),
            case lists:splitwith(fun(L) -> string:trim(L) =/= <<"```">> end, Rest) of
                {Body, [Close | After]} ->
                    Dedented = [dedent(L, Indent) || L <- Body],
                    Pad = binary:copy(<<" ">>, Indent),
                    Laid = case fence(Dedented) of
                               Dedented -> Body;
                               New -> [indent(Pad, L) || L <- New]
                           end,
                    [Line] ++ Laid ++ [Close | fences(After)];
                {_, []} -> [Line | Rest]
            end
    end.

fence(Lines) ->
    Text = iolist_to_binary(lists:join(<<"\n">>, Lines)),
    case format(Text) of
        {ok, Out} -> lines(Out);
        {error, _} ->
            Wrapped = <<"fn f() = {\n", Text/binary, "\n}\n">>,
            case format(Wrapped) of
                {ok, Out} ->
                    Inner = lists:droplast(tl(lines(Out))),
                    [dedent(L, 4) || L <- Inner];
                {error, _} -> Lines
            end
    end.

lines(Out) ->
    binary:split(string:trim(Out, trailing, "\n"), <<"\n">>, [global]).

dedent(Line, N) ->
    case Line of
        <<Pad:N/binary, Rest/binary>> ->
            case string:trim(Pad, both, " ") of
                <<>> -> Rest;
                _ -> Line
            end;
        _ -> string:trim(Line, leading, " ")
    end.

indent(_Pad, <<>>) -> <<>>;
indent(Pad, Line) -> <<Pad/binary, Line/binary>>.

%%
%% The source: its lines, its code tokens, its comments
%%

source_lines(Text) ->
    Chars = case unicode:characters_to_list(Text) of
                [16#FEFF | R] -> R;
                R when is_list(R) -> R;
                _ -> []
            end,
    list_to_tuple([strip_cr(L) || L <- string:split(Chars, "\n", all)]).

strip_cr(Line) ->
    case lists:reverse(Line) of
        [$\r | R] -> lists:reverse(R);
        _ -> Line
    end.

%% The code tokens, each told that the code token before it ended where it
%% did, so that the parser's spans end at code; and the comments and doc
%% blocks, as {Kind, Line, Column, EndLine, Text}.
split(Tokens, Source) ->
    {Code, Trivia} = lists:partition(fun(T) -> not trivia(T) end, Tokens),
    {relink(Code, {1, 1}), [trivium(T, Source) || T <- Trivia]}.

trivia({comment, _, _}) -> true;
trivia({doc, _, _}) -> true;
trivia(_) -> false.

relink([T | Ts], Prev) ->
    {L, C, End, _} = element(2, T),
    [setelement(2, T, {L, C, End, Prev}) | relink(Ts, End)];
relink([], _) ->
    [].

trivium({comment, {L, C, {EL, _}, _}, Text}, _Source) ->
    Kind = case Text of <<"/*", _/binary>> -> block; _ -> line end,
    {Kind, L, C, EL, Text};
trivium({doc, {L, C, {L1, _}, _}, _}, Source) ->
    %% a doc block is kept as written, but for where its lines begin
    Lines = [unicode:characters_to_binary(string:trim(element(N, Source), leading))
             || N <- lists:seq(L, L1 - 1)],
    {doc, L, C, L1 - 1, doc_lines(Lines)}.

%% A doc block's lines, each Ernest example in it laid out; a line
%% outside an example, and an example that does not change, as written.
doc_lines([]) ->
    [];
doc_lines([Line | Rest]) ->
    case string:prefix(doc_content(Line), <<"```ernest">>) of
        nomatch -> [Line | doc_lines(Rest)];
        _ ->
            Inside = fun(L) -> string:trim(doc_content(L)) =/= <<"```">> end,
            case lists:splitwith(Inside, Rest) of
                {Body, [Close | After]} ->
                    Content = [doc_content(B) || B <- Body],
                    Laid = case fence(Content) of
                               Content -> Body;
                               New -> [doc_line(N) || N <- New]
                           end,
                    [Line] ++ Laid ++ [Close | doc_lines(After)];
                {_, []} -> [Line | Rest]
            end
    end.

doc_content(<<"/// ", Rest/binary>>) -> Rest;
doc_content(<<"///", Rest/binary>>) -> Rest.

doc_line(<<>>) -> <<"///">>;
doc_line(Line) -> <<"/// ", Line/binary>>.

context(Code, Source) ->
    Toks = list_to_tuple(Code),
    Indexed = lists:zip(lists:seq(1, length(Code)), Code),
    #ctx{toks = Toks,
         texts = list_to_tuple([text(T, Source) || T <- Code]),
         starts = maps:from_list([{{L, C}, I} || {I, T} <- Indexed,
                                                 {L, C, _, _} <- [element(2, T)]]),
         ends = maps:from_list([{End, I} || {I, T} <- Indexed, element(1, T) =/= eof,
                                            {_, _, End, _} <- [element(2, T)]]),
         pairs = pairs(Indexed, [], #{})}.

%% A token's text as written.
text({eof, _}, _Source) ->
    <<>>;
text(T, Source) ->
    {L, C, {EL, EC}, _} = element(2, T),
    Chars = case L =:= EL of
                true -> lists:sublist(element(L, Source), C, EC - C);
                false ->
                    [lists:nthtail(C - 1, element(L, Source)), $\n,
                     [[element(N, Source), $\n] || N <- lists:seq(L + 1, EL - 1)],
                     lists:sublist(element(EL, Source), EC - 1)]
            end,
    unicode:characters_to_binary(Chars).

%% Each opening bracket's index mapped to its closing one's.
pairs([], _Open, Acc) ->
    Acc;
pairs([{I, T} | Rest], Open, Acc) ->
    case element(1, T) of
        S when S =:= '('; S =:= '#('; S =:= '['; S =:= '{'; S =:= '<<' ->
            pairs(Rest, [I | Open], Acc);
        S when S =:= ')'; S =:= ']'; S =:= '}'; S =:= '>>' ->
            [O | Open1] = Open,
            pairs(Rest, Open1, Acc#{O => I});
        _ -> pairs(Rest, Open, Acc)
    end.

%%
%% Nodes and their tokens
%%

sym(T) -> element(1, T).

%% Where a node's first token is: a call, an operator and a selection
%% begin with what they apply to.
first(#e_call{pipe = true, args = [X | _]}) -> first(X);
first(#e_call{callee = F}) -> first(F);
first(#e_binop{left = L}) -> first(L);
first(#e_select{expr = E}) -> first(E);
first(N) -> {L, C, _} = element(2, N), {L, C}.

first_index(N, X) -> maps:get(first(N), X#ctx.starts).

last_index(N, X) ->
    {_, _, End} = element(2, N),
    maps:get(End, X#ctx.ends).

%% Whether parentheses stand around a node: its span ends at the closing
%% one, and the token before its first is the opening one.
paren(N, X) ->
    I = first_index(N, X) - 1,
    I >= 1 andalso sym(element(I, X#ctx.toks)) =:= '('
        andalso maps:get(I, X#ctx.pairs) =:= last_index(N, X).

%% How a node's first line may end: a block's brace; a brace, for what
%% runs over lines inside braces and may stay on the line before them
%% (report §11.6); or neither.
kind(N, X) ->
    case paren(N, X) of
        true -> other;
        false -> kind_(N, X)
    end.

kind_(#e_block{}, _) -> block;
kind_(#e_match{}, _) -> brace;
kind_(#e_receive{}, _) -> brace;
kind_(#e_lambda{body = B}, X) -> braced(B, X);
kind_(#e_call{pipe = false, args = [_ | _] = As}, X) -> braced(lists:last(As), X);
kind_(#e_con{args = {positional, E}}, X) -> braced(E, X);
kind_(#e_con{args = {named, _, [_ | _] = Sets}}, X) ->
    braced((lists:last(Sets))#field_set.expr, X);
kind_(_, _) -> other.

braced(N, X) ->
    case kind(N, X) of
        other -> other;
        _ -> brace
    end.

%%
%% The first pass: a template of the layout, in source order
%%

tok(Sym) -> {tok, Sym}.
tok() -> {tok, any}.
sp() -> <<" ">>.

module(Decls, X) ->
    lists:join([hardline, force_blank], [decl(D, X) || D <- Decls]).

decl(#fn_decl{export = E, owner = O, params = Ps, ret = R, effect = F, body = B}, X) ->
    [export(E), tok(fn), sp(), name(O), params(Ps, X), ret(R, F, X), sp(), tok('='),
     case kind(B, X) of
         block -> [sp(), ex(B, X)];
         _ -> {nest, 4, [hardline, ex(B, X)]}
     end];
decl(#let_decl{export = E, ann = A, body = B}, X) ->
    [export(E), tok('let'), sp(), tok(), ann(A, X), sp(), tok('='), {body, ex(B, X)}];
decl(#type_decl{export = E, params = Ps, constructors = Cs}, X) ->
    [export(E), type_decl(Ps, Cs, X)];
decl(#abstract_decl{export = E, type = #type_decl{params = Ps, constructors = Cs}}, X) ->
    [export(E), tok(abstract), sp(), type_decl(Ps, Cs, X)];
decl(#foreign_type_decl{export = E, params = Ps, eq = Eq}, _X) ->
    Vars = case Ps of
               [] -> [];
               _ -> bracket(tok('('), [[tok() | [tok('=') || lists:member(P, Eq)]] || P <- Ps],
                            ')')
           end,
    [export(E), tok(foreign), sp(), tok(type), sp(), tok(), Vars];
decl(#foreign_fn_decl{export = E, owner = O, params = Ps, ret = R, effect = F}, X) ->
    [export(E), tok(foreign), sp(), tok(fn), sp(), name(O), params(Ps, X), ret(R, F, X), sp(),
     tok('='), {nest, 4, [hardline, tok(string)]}].

export(true) -> [tok(export), sp()];
export(false) -> [].

name(undefined) -> tok();
name(_Owner) -> [tok(), tok('.'), tok()].

params(Ps, X) ->
    bracket(tok('('), [param(P, X) || P <- Ps], ')').

param(#param{pattern = P, type = undefined}, X) -> pat(P, X);
param(#param{pattern = P, type = T}, X) -> [pat(P, X), sp(), tok(':'), sp(), ty(T, X)].

%% A head's result annotation is written `: T`, and a function type's
%% result after `->` (report §3.4, §4.5).
ret(R, F, X) ->
    ret(':', R, F, X).

ret(_, undefined, _, _) -> [];
ret(Sym, R, undefined, X) -> [sp(), tok(Sym), sp(), ty(R, X)];
ret(Sym, R, F, X) -> [sp(), tok(Sym), sp(), ty(R, X), sp(), tok(with), sp(), ty(F, X)].

ann(undefined, _) -> [];
ann(T, X) -> [sp(), tok(':'), sp(), ty(T, X)].

type_decl(Ps, Cs, X) ->
    Vars = case Ps of
               [] -> [];
               _ -> bracket(tok('('), [tok() || _ <- Ps], ')')
           end,
    [tok(type), sp(), tok(), Vars, sp(), tok('='), alternatives(Cs, X)].

%% A type of one alternative keeps it on its line; alternatives that run
%% past the line break after the `=` and stand one a line, each further
%% line led by its bar, as a `match`'s arms do (report §11.6).
alternatives([C], X) ->
    %% a doc block puts the one alternative on a line of its own, a step in;
    %% one that does not fit breaks after the `=`, as several do, rather than
    %% inside the parentheses of the type's parameters or of its fields
    {if_lead, {nest, 4, [sp(), con(C, X)]}, {alternative, con(C, X)}};
alternatives([C | Cs], X) ->
    Bar = {nest, -2, [line, tok('|'), sp()]},
    {group, {nest, 4, [line, con(C, X) | lists:append([[Bar, con(D, X)] || D <- Cs])]}}.

con(#constructor{fields = none}, _) -> tok();
con(#constructor{fields = {positional, T}}, X) -> [tok(), bracket(tok('('), [ty(T, X)], ')')];
con(#constructor{fields = {named, Fs}}, X) ->
    [tok(), bracket(tok('('), [[tok(), sp(), tok(':'), sp(), ty(T, X)] || #field{type = T} <- Fs],
                    ')')].

%% A bracket and its items, which the second pass lays out on one line or
%% one a line, aligned; Hug when its last item may stay on the bracket's
%% line with the brace it opens.
bracket(Open, Items, Close) ->
    {bracket, Open, Items, Close, false}.

bracket(Open, Items, Close, Last, X) ->
    {bracket, Open, Items, Close, Last =/= none andalso kind(Last, X) =/= other}.

last([]) -> none;
last(Xs) -> lists:last(Xs).

%% Types

ty(T, X) -> {node, T, ty_(T, X)}.

ty_(#t_con{path = P, args = []}, _) -> [path(P), tok()];
ty_(#t_con{path = P, args = As}, X) ->
    [path(P), tok(), bracket(tok('('), [ty(A, X) || A <- As], ')')];
ty_(#t_var{}, _) -> tok();
ty_(#t_tuple{elems = Es}, X) -> bracket(tok('#('), [ty(E, X) || E <- Es], ')');
ty_(#t_fn{params = Ps, ret = R, effect = F}, X) ->
    [bracket(tok('('), [ty(P, X) || P <- Ps], ')'), ret('->', R, F, X)].

path(P) -> [[tok(), tok('.')] || _ <- P].

%% Expressions

ex(E, X) -> {node, E, ex_(E, X)}.

ex_(#e_lit{}, _) -> tok();
ex_(#e_var{path = P}, _) -> [path(P), tok()];
ex_(#e_con{path = P, args = none}, _) -> [path(P), tok()];
ex_(#e_con{path = P, args = {positional, E}}, X) ->
    [path(P), tok(), bracket(tok('('), [ex(E, X)], ')', E, X)];
ex_(#e_con{path = P, args = {named, Base, Sets}}, X) ->
    Items = [[tok('..'), ex(Base, X)] || Base =/= undefined]
        ++ [[tok(), sp(), tok('='), sp(), ex(E, X)] || #field_set{expr = E} <- Sets],
    [path(P), tok(), bracket(tok('('), Items, ')', last([E || #field_set{expr = E} <- Sets]), X)];
ex_(#e_tuple{elems = Es}, X) -> bracket(tok('#('), [ex(E, X) || E <- Es], ')', last(Es), X);
ex_(#e_list{elems = Es}, X) -> bracket(tok('['), [ex(E, X) || E <- Es], ']', last(Es), X);
ex_(#e_bits{segments = Ss}, X) -> bracket(tok('<<'), [seg(S, X, fun ex/2) || S <- Ss], '>>');
ex_(#e_block{stmts = Ss}, X) -> braces([stmts(Ss, X), lead_trivia]);
ex_(#e_call{pipe = false, callee = F, args = As}, X) -> [ex(F, X), args(As, X)];
ex_(#e_call{pipe = true} = Call, X) ->
    {Base, Segments} = pipe_chain(Call, X, []),
    {group, [ex(Base, X),
             {nest, 4, [[line, tok('|>'), sp(), ex(F, X), Args] || {F, Args} <- Segments]}]};
ex_(#e_select{expr = E}, X) -> [ex(E, X), tok('.'), tok()];
ex_(#e_neg{expr = E}, X) -> [tok('-'), ex(E, X)];
ex_(#e_not{expr = E}, X) -> [tok('!'), ex(E, X)];
ex_(#e_binop{} = B, X) ->
    [First | Rest] = operands(B, X),
    {group, [ex(First, X), {nest, 4, [[line, tok(Op), sp(), ex(N, X)] || {Op, N} <- Rest]}]};
ex_(#e_lambda{params = Ps, ret = R, effect = F, body = B}, X) ->
    [tok(fn), params(Ps, X), ret(R, F, X), sp(), tok('='), {body, ex(B, X)}];
ex_(#e_if{} = If, X) ->
    {group, ladder(If, X)};
ex_(#e_match{scrutinee = S, clauses = Cs}, X) ->
    [tok(match), sp(), ex(S, X), sp(), braces([arms(Cs, X), lead_trivia])];
ex_(#e_receive{clauses = Cs, 'after' = A}, X) ->
    Arms = case {Cs, A} of
               {[], #after_clause{}} -> after_clause(A, X);
               {_, undefined} -> arms(Cs, X);
               _ -> [arms(Cs, X), bar(after_clause(A, X))]
           end,
    [tok('receive'), sp(), braces([Arms, lead_trivia])].

args(As, X) -> bracket(tok('('), [ex(A, X) || A <- As], ')', last(As), X).

%% A block's, a match's and a receive's brace runs over lines.
braces(Inside) ->
    [tok('{'), {nest, 4, [hardline, Inside]}, hardline, tok('}')].

stmts(Ss, X) ->
    lists:join([tok(';'), hardline], [stmt(S, X) || S <- Ss]).

stmt(#binding{pattern = P, ann = A, expr = E}, X) ->
    [tok('let'), sp(), pat(P, X), ann(A, X), sp(), tok(), {body, ex(E, X)}];
stmt(#fn_decl{} = F, X) -> decl(F, X);
stmt(E, X) -> ex(E, X).

seg(#bit_seg{value = V, specs = []}, X, Value) ->
    Value(V, X);
seg(#bit_seg{value = V, specs = Ss}, X, Value) ->
    [Value(V, X), tok(':'), lists:join(tok('-'), [spec(S, X) || S <- Ss])].

spec({size, E}, X) -> [tok(), tok('('), ex(E, X), tok(')')];
spec(_, _) -> tok().

%% `x |> f(a) |> g`: the first operand, then each callee with the
%% arguments after the first, where the call has its parentheses.
pipe_chain(#e_call{pipe = true, callee = F, args = [Y | Rest]} = Call, X, Acc) ->
    Args = case bracketed(Call, F, X) of
               true -> args(Rest, X);
               false -> []
           end,
    Acc1 = [{F, Args} | Acc],
    case Y of
        #e_call{pipe = true} ->
            case paren(Y, X) of
                false -> pipe_chain(Y, X, Acc1);
                true -> {Y, Acc1}
            end;
        _ -> {Y, Acc1}
    end.

bracketed(Call, F, X) ->
    Next = last_index(F, X) + 1,
    Next =< last_index(Call, X) andalso sym(element(Next, X#ctx.toks)) =:= '('.

%% A chain of one operator, written as one: `a <> b <> c` breaks before
%% every `<>` or none. `::` groups to the right, every other to the left.
operands(#e_binop{op = '::', left = L, right = R}, X) ->
    [L | right_chain(R, X)];
operands(#e_binop{op = Op, left = L, right = R}, X) ->
    left_chain(L, Op, X) ++ [{Op, R}].

left_chain(#e_binop{op = Op, left = L, right = R} = N, Op, X) ->
    case paren(N, X) of
        false -> left_chain(L, Op, X) ++ [{Op, R}];
        true -> [N]
    end;
left_chain(N, _, _) ->
    [N].

right_chain(#e_binop{op = '::', left = L, right = R} = N, X) ->
    case paren(N, X) of
        false -> [{'::', L} | right_chain(R, X)];
        true -> [{'::', N}]
    end;
right_chain(N, _) ->
    [{'::', N}].

%% An `if` on one line, or broken at every `then` and `else`, an `else
%% if` continuing the ladder; a block, or a branch whose first line ends
%% in a brace, stays beside its `then` or `else` (report §11.6).
ladder(#e_if{condition = C, then_branch = T, else_branch = E}, X) ->
    Then = case kind(T, X) of
               block -> [sp(), ex(T, X), sp()];
               brace -> {hug_then, ex(T, X)};
               other -> [{nest, 4, [line, ex(T, X)]}, line]
           end,
    [tok('if'), sp(), ex(C, X), sp(), tok(then), Then, tok('else'), else_branch(E, X)].

else_branch(#e_if{} = E, X) ->
    case paren(E, X) of
        false -> [sp(), ladder(E, X)];
        true -> {nest, 4, [line, ex(E, X)]}
    end;
else_branch(E, X) ->
    case kind(E, X) of
        block -> [sp(), ex(E, X)];
        brace -> {hug_else, ex(E, X)};
        other -> {nest, 4, [line, ex(E, X)]}
    end.

%% Each arm on a line of its own, a further one led by its bar two
%% columns to the left.
arms([C | Cs], X) ->
    [clause(C, X) | [bar(clause(D, X)) || D <- Cs]].

bar(Arm) ->
    {nest, -2, [hardline, tok('|'), sp(), {nest, 2, Arm}]}.

clause(#clause{pattern = P, guard = G, body = B}, X) ->
    Guard = case G of
                undefined -> [];
                _ -> [sp(), tok('when'), sp(), ex(G, X)]
            end,
    [pat(P, X), Guard, sp(), tok('->'), {body, ex(B, X)}].

after_clause(#after_clause{timeout = T, body = B}, X) ->
    [tok('after'), sp(), ex(T, X), sp(), tok('->'), {body, ex(B, X)}].

%% Patterns, which have no parentheses

pat(#p_wild{}, _) -> tok();
pat(#p_var{}, _) -> tok();
pat(#p_lit{} = P, X) ->
    case sym(element(first_index(P, X), X#ctx.toks)) of
        '-' -> [tok('-'), tok()];
        _ -> tok()
    end;
pat(#p_con{path = Pa, args = none}, _) -> [path(Pa), tok()];
pat(#p_con{path = Pa, args = {named, []}}, _) -> [path(Pa), tok(), tok('('), tok(')')];
pat(#p_con{path = Pa, args = {named, Fs}}, X) ->
    [path(Pa), tok(), bracket(tok('('), [[tok(), sp(), tok('='), sp(), pat(P, X)]
                                         || #field_pat{pattern = P} <- Fs], ')')];
pat(#p_con{path = Pa, args = {positional, P}}, X) ->
    [path(Pa), tok(), bracket(tok('('), [pat(P, X)], ')')];
pat(#p_tuple{elems = Es}, X) -> bracket(tok('#('), [pat(E, X) || E <- Es], ')');
pat(#p_list{elems = Es}, X) -> bracket(tok('['), [pat(E, X) || E <- Es], ']');
pat(#p_cons{head = H, tail = T}, X) -> [pat(H, X), sp(), tok('::'), sp(), pat(T, X)];
pat(#p_as{pattern = P}, X) -> [pat(P, X), sp(), tok(as), sp(), tok()];
pat(#p_or{alts = As}, X) -> lists:join([sp(), tok('or'), sp()], [pat(A, X) || A <- As]);
pat(#p_bits{segments = Ss}, X) -> bracket(tok('<<'), [seg(S, X, fun pat/2) || S <- Ss], '>>').

%%
%% The second pass: the template in source order, with the tokens' text
%%

resolve(T, _X, C) when is_binary(T) ->
    {T, C};
resolve(T, X, C) when is_list(T) ->
    lists:mapfoldl(fun(E, Acc) -> resolve(E, X, Acc) end, C, T);
resolve(T, _X, C) when T =:= line; T =:= softline; T =:= hardline; T =:= blank ->
    {T, C};
resolve(force_blank, _X, C) ->
    {[], C#cur{force = true}};
resolve(lead_trivia, X, C) ->
    lead(C, X);
resolve({nest, N, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{nest, N, D}, C1};
resolve({align, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{align, D}, C1};
resolve({group, T}, X, C) ->
    %% the comments on lines before a group's first token stand before the
    %% group, which they would otherwise break
    {Lead, C1} = case leading_break(T) of
                     true -> {[], C};
                     false -> lead(C, X)
                 end,
    {D, C2} = resolve(T, X, C1),
    {[Lead, {group, D}], C2};
resolve({tok, Expect}, X, C) ->
    consume(Expect, X, C);
resolve({if_lead, WithLead, Without}, X, C) ->
    {NL, NC, _, _} = element(2, element(C#cur.i, X#ctx.toks)),
    case C#cur.trivia of
        [{_, L, Col, _, _} | _] when {L, Col} < {NL, NC} -> resolve(WithLead, X, C);
        _ -> resolve(Without, X, C)
    end;
resolve({node, N, T}, X, C) ->
    parens(N, T, X, C);
resolve({bracket, Open, Items, Close, Hug}, X, C) ->
    items(Open, Items, Close, Hug, X, C);
resolve({body, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{choice, body, [sp(), D, mark], {nest, 4, [hardline, D]}}, C1};
resolve({alternative, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{choice, alternative, [sp(), D, mark], {nest, 4, [hardline, D]}}, C1};
resolve({hug_then, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{choice, branch, [sp(), D, sp()], [{nest, 4, [line, D]}, line]}, C1};
resolve({hug_else, T}, X, C) ->
    {D, C1} = resolve(T, X, C),
    {{choice, branch, [sp(), D], {nest, 4, [line, D]}}, C1}.

%% Whether a template begins with a line break.
leading_break(T) when T =:= line; T =:= softline; T =:= hardline -> true;
leading_break([]) -> false;
leading_break([[] | Rest]) -> leading_break(Rest);
leading_break([H | _]) -> leading_break(H);
leading_break({nest, _, T}) -> leading_break(T);
leading_break({align, T}) -> leading_break(T);
leading_break({group, T}) -> leading_break(T);
leading_break(_) -> false.

%% A node's own parentheses, the outermost closing where its span ends.
parens(N, T, X, C) ->
    {Opens, C1} = opens(last_index(N, X), X, C, []),
    {D, C2} = resolve(T, X, C1),
    {Closes, C3} = lists:mapfoldl(fun(_, Acc) -> consume(')', X, Acc) end, C2, Opens),
    case Opens of
        [] -> {D, C2};
        _ -> {[lists:reverse(Opens), {align, D}, Closes], C3}
    end.

opens(Last, X, #cur{i = I} = C, Acc) ->
    case sym(element(I, X#ctx.toks)) =:= '(' andalso maps:get(I, X#ctx.pairs) =:= Last of
        true ->
            {D, C1} = consume('(', X, C),
            opens(Last - 1, X, C1, [D | Acc]);
        false -> {Acc, C}
    end.

%% A bracket on one line when it fits, else its first item on the
%% bracket's line and each further one on a line of its own under it; a
%% last item that opens a brace may keep the items on the bracket's line
%% (report §11.6).
items(Open, [], Close, _Hug, X, C) ->
    {OpenD, C1} = resolve(Open, X, C),
    {Lead, C2} = lead(C1, X),
    {CloseD, C3} = consume(Close, X, C2),
    {[OpenD, Lead, CloseD], C3};
items(Open, [First | Rest], Close, Hug, X, C) ->
    {Before, C0} = lead(C, X),
    {OpenD, C1} = resolve(Open, X, C0),
    {Above, C1a} = lead(C1, X),
    {FirstD0, C2} = resolve(First, X, C1a),
    FirstD = [Above, FirstD0],
    {Pairs, C3} = lists:mapfoldl(fun(Item, Acc) ->
                                     {Comma, Acc1} = consume(',', X, Acc),
                                     {D, Acc2} = resolve(Item, X, Acc1),
                                     {{Comma, D}, Acc2}
                                 end, C2, Rest),
    {Lead, C4} = lead(C3, X),
    {CloseD, C5} = consume(Close, X, C4),
    Items = [FirstD, [[Comma, line, D] || {Comma, D} <- Pairs], Lead],
    Broken = {bracket, [OpenD, {align, Items}, CloseD]},
    Laid = case {Pairs, Hug} of
              %% a comment or a doc block on the first item's lines puts it
              %% on a line of its own, and the items a step in
              _ when Above =/= [] -> {bracket, [OpenD, {nest, 4, Items}, CloseD]};
              {[], true} -> [OpenD, FirstD, Lead, CloseD];
              {[], false} -> [OpenD, {align, [FirstD, Lead]}, CloseD];
              {_, false} -> Broken;
              {_, true} ->
                  {choice, hug, [OpenD, FirstD, [[Comma, sp(), D] || {Comma, D} <- Pairs], Lead,
                                 CloseD], Broken}
          end,
    {[Before, Laid], C5}.

%% The next code token, with the comments on lines of their own before
%% it and those after it on its line. A blank line in the source before a
%% token or a comment is kept, but not after an opening bracket or before
%% a closing one, and one comes before a declaration after the first.
consume(Expect, X, C) ->
    T = element(C#cur.i, X#ctx.toks),
    Expect =:= any orelse sym(T) =:= Expect orelse error({formatter_expected, Expect, T}),
    {Lead, C1} = lead(C, X),
    {L, _, {EL, _}, _} = element(2, T),
    Blank = blank_before(C1, L, sym(T)),
    C2 = C1#cur{i = C1#cur.i + 1, last = EL, prev = sym(T), force = false},
    {Trail, C3} = trailing(C2, X, EL),
    {[Lead, Blank, element(C#cur.i, X#ctx.texts), Trail], C3}.

lead(#cur{trivia = [{Kind, L, Col, EL, Text} | Rest]} = C, X) ->
    {NL, NC, _, _} = element(2, element(C#cur.i, X#ctx.toks)),
    case {L, Col} < {NL, NC} of
        true ->
            %% comments directly under a declaration, with a blank line after
            %% them, are the declaration's, and the blank line between two
            %% declarations comes after them
            Stays = C#cur.force andalso ends_before_gap(C#cur.last, C#cur.trivia, {NL, NC}, true),
            Blank = case Stays of
                        true -> [];
                        false -> blank_before(C, L, none)
                    end,
            C1 = C#cur{trivia = Rest, last = EL, prev = Kind, force = Stays},
            {More, C2} = lead(C1, X),
            {[hardline, Blank, trivium_doc(Kind, Text), hardline, More], C2};
        false -> {[], C}
    end;
lead(C, _X) ->
    {[], C}.

%% Whether the comments before Next begin on the line after Last, each on
%% the line after the one before, and a blank line follows them.
ends_before_gap(Last, [{_, L, Col, EL, _} | Rest], Next, First) when {L, Col} < Next ->
    case L - Last =< 1 of
        true -> ends_before_gap(EL, Rest, Next, false);
        false -> not First
    end;
ends_before_gap(Last, _, {NL, _}, First) ->
    not First andalso NL - Last >= 2.

%% Comments that begin on the line a token ended on, before the next
%% token: a line comment ends the line, a block comment need not, and is
%% kept apart by a space from a token after it on its line but a closing
%% bracket or a separator, and from the token before it but an opening
%% bracket.
trailing(#cur{trivia = [{Kind, L, Col, EL, Text} | Rest]} = C, X, Line)
  when L =:= Line, Kind =/= doc ->
    Next = element(C#cur.i, X#ctx.toks),
    {NL, NC, _, _} = element(2, Next),
    case {L, Col} < {NL, NC} of
        true ->
            Apart = NL =:= EL andalso not lists:member(element(1, Next),
                                                       [')', ']', '}', '>>', ',', ';']),
            Opened = lists:member(C#cur.prev, ['(', '[', '{', '#(', '<<']),
            %% the space after a block comment is one with a space the
            %% layout puts there (ern_pretty)
            Before = case Opened of
                         true -> [];
                         false -> [sp()]
                     end,
            D = case {Kind, Apart} of
                    {line, _} -> {suffix, <<" ", Text/binary>>};
                    {block, true} -> [Before, Text, sp()];
                    {block, false} -> [Before, Text]
                end,
            {More, C1} = trailing(C#cur{trivia = Rest, last = EL, prev = Kind}, X, EL),
            {[D, More], C1};
        false -> {[], C}
    end;
trailing(C, _X, _Line) ->
    {[], C}.

trivium_doc(doc, Lines) -> lists:join(hardline, Lines);
trivium_doc(_, Text) -> Text.

blank_before(#cur{force = true}, _Line, _Sym) ->
    blank;
blank_before(#cur{last = Last, prev = Prev}, Line, Sym) ->
    Opener = lists:member(Prev, ['(', '#(', '[', '{', '<<']),
    Closer = lists:member(Sym, [')', ']', '}', '>>']),
    case Last > 0 andalso Line - Last >= 2 andalso not Opener andalso not Closer of
        true -> blank;
        false -> []
    end.
