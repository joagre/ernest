%% Report Appendix A generated against (plan, MVP 2.99c item 1): programs
%% derived at random from the grammar as the report states it, read through
%% ern_grammar, so that the parser is held to the grammar rather than to the
%% programs someone thought to write. Three oracles:
%%
%% - every program derived parses, and the programs together reach every
%%   alternative of every rule, every optional part taken and left, and every
%%   repetition run no times, once and more: a thousand derived at random,
%%   and then one for each choice they left untaken, steered to take it;
%% - every program laid out by the formatter parses to the same tree, and is
%%   laid out again to the same text (report §11.6);
%% - each program with one token deleted, doubled, swapped with the next, or
%%   replaced or preceded by another of the grammar's is a near miss, and a
%%   recognizer built from the same grammar, Earley's, says whether it is a
%%   sentence of it: the parser refuses it with a diagnostic where it is not,
%%   and parses it where it is.
%%
%% The seed is drawn afresh each run and named in a failure, and ERN_SEED
%% runs one again. A program's size grows with its number, so the first
%% that fails is a small one.
-module(ern_grammar_programs_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("utils/include/ern_diagnostic.hrl").

-define(PROGRAMS, 1000).

%% The grammar as the generator reads it: each rule's expression by name,
%% the fewest tokens each nonterminal derives, and §2.4's reserved words.
-record(grammar, {rules, shortest, reserved}).

%% A program being derived: its tokens so far, last first, how many, how
%% many it may have before every choice takes its shortest branch, the
%% choices the programs have made so far, and the choice it is steered to
%% take, with how many rules each nonterminal is from that choice's rule.
-record(derivation, {tokens = [], size = 0, budget, coverage, target, distances}).

%% The recognizer's grammar: the productions, each a nonterminal and the
%% symbols it derives, those of each nonterminal by number, and the
%% nonterminals that derive no token.
-record(recognizer, {productions, by_name, nullable}).

%%
%% The tests
%%

%% report Appendix A: every program the grammar derives parses, and the
%% programs reach every alternative of every rule
derived_programs_parse_test_() ->
    {timeout, 300, fun() ->
                       {Seed, Grammar} = start(),
                       {Programs, Coverage} = programs(Grammar),
                       Failures = [failure(Seed, Number, Text, Outcome)
                                   || {Number, Tokens} <- Programs,
                                      Text <- [text(Tokens)],
                                      Outcome <- [parsed(Text)],
                                      element(1, Outcome) =/= ok],
                       ?assertEqual([], first(Failures)),
                       ?assertEqual([], choices(Grammar) -- maps:keys(Coverage))
                   end}.

%% report §11.6: a program laid out parses to the same tree, and is laid
%% out again to the same text
layout_keeps_the_tree_test_() ->
    {timeout, 300, fun() ->
                       {Seed, Grammar} = start(),
                       {Programs, _} = programs(Grammar),
                       Failures = [failure(Seed, Number, Text, Outcome)
                                   || {Number, Tokens} <- Programs,
                                      Text <- [text(Tokens)],
                                      Outcome <- [laid_out(Text)],
                                      Outcome =/= ok],
                       ?assertEqual([], first(Failures))
                   end}.

%% report Appendix A, §11.5: a near miss that is no sentence of the grammar
%% is refused with a diagnostic, and one that is parses
near_misses_test_() ->
    {timeout, 300, fun() ->
                       {Seed, Grammar} = start(),
                       Recognizer = recognizer(ern_grammar:rules()),
                       Vocabulary = vocabulary(ern_grammar:rules()),
                       {Programs, _} = programs(Grammar),
                       Failures = [failure(Seed, Number, text(Near), Outcome)
                                   || {Number, Tokens} <- Programs,
                                      Near <- [near_miss(Tokens, Vocabulary, Grammar)],
                                      Outcome <- [decided(Near, Recognizer)],
                                      Outcome =/= ok],
                       ?assertEqual([], first(Failures))
                   end}.

%% The recognizer itself: every program the grammar derives is a sentence
%% of it, so that its verdict on a near miss can be trusted
recognizer_accepts_derived_programs_test_() ->
    {timeout, 300, fun() ->
                       {Seed, Grammar} = start(),
                       Recognizer = recognizer(ern_grammar:rules()),
                       {Programs, _} = programs(Grammar),
                       Refused = [failure(Seed, Number, text(Tokens), refused)
                                  || {Number, Tokens} <- Programs,
                                     not recognized(Tokens, Recognizer)],
                       ?assertEqual([], first(Refused))
                   end}.

%% The seed, ERN_SEED's or a fresh one, set for this process, and the
%% grammar read.
start() ->
    Seed = case os:getenv("ERN_SEED") of
               false -> erlang:phash2({erlang:monotonic_time(), self()});
               Given -> list_to_integer(Given)
           end,
    rand:seed(exsss, Seed),
    Rules = ern_grammar:rules(),
    {Seed, #grammar{rules = maps:from_list(Rules), shortest = shortest(Rules),
                    reserved = ern_grammar:reserved()}}.

%% What a failure names: the seed that makes it again, the program's
%% number, its text, and what went wrong.
failure(Seed, Number, Text, Outcome) ->
    #{seed => Seed, program => Number, text => Text, outcome => Outcome}.

%% The first failure, the smallest, and how many there were.
first([]) -> [];
first([First | _] = Failures) -> [First#{failures => length(Failures)}].

%%
%% The oracles
%%

%% The program parsed, or the diagnostic or the crash that stopped it.
parsed(Text) ->
    try ern_parser:parse_string(Text)
    catch Class:Reason:Trace -> {crashed, Class, Reason, lists:sublist(Trace, 3)}
    end.

%% ok when the text laid out parses to the tree the text does, and lays
%% out to itself; otherwise what differed.
laid_out(Text) ->
    try
        {ok, Tree} = ern_parser:parse_string(Text),
        case ern_format:format(Text) of
            {ok, Laid} ->
                case ern_parser:parse_string(Laid) of
                    {ok, LaidTree} ->
                        case {unspanned(LaidTree) =:= unspanned(Tree), ern_format:format(Laid)} of
                            {true, {ok, Laid}} -> ok;
                            {true, Again} -> {laid_out_again, Laid, Again};
                            {false, _} -> {another_tree, Laid}
                        end;
                    Refused -> {laid_out_refused, Laid, Refused}
                end;
            Refused -> {refused, Refused}
        end
    catch Class:Reason:Trace -> {crashed, Class, Reason, lists:sublist(Trace, 3)}
    end.

%% ok when the parser decides a near miss as the grammar does: it parses a
%% sentence, and refuses anything else with a diagnostic whose span lies
%% in the text.
decided(Tokens, Recognizer) ->
    Text = text(Tokens),
    Sentence = recognized(Tokens, Recognizer),
    case {Sentence, parsed(Text)} of
        {true, {ok, _}} -> ok;
        {false, {error, #diagnostic{span = {Line, _, _}}}} ->
            case Line >= 1 andalso Line =< lines(Text) of
                true -> ok;
                false -> {span_outside, Line}
            end;
        {true, Outcome} -> {sentence_refused, Outcome};
        {false, {ok, _}} -> no_sentence_parsed;
        {false, Outcome} -> {no_diagnostic, Outcome}
    end.

lines(Text) ->
    length(binary:matches(Text, <<"\n">>)) + 1.

%% A tree with every span taken out, so that two trees differ only where
%% their nodes do.
unspanned({Line, Column, {EndLine, EndColumn}})
  when is_integer(Line), is_integer(Column), is_integer(EndLine), is_integer(EndColumn) ->
    span;
unspanned(Tuple) when is_tuple(Tuple) ->
    list_to_tuple([unspanned(Element) || Element <- tuple_to_list(Tuple)]);
unspanned(List) when is_list(List) ->
    [unspanned(Element) || Element <- List];
unspanned(Other) ->
    Other.

%%
%% The generator
%%

%% The programs, each its number and its tokens, and the choices they made.
programs(Grammar) ->
    {Programs, Coverage} =
        lists:mapfoldl(fun(Number, Coverage) ->
                           Budget = 2 + Number * 100 div ?PROGRAMS,
                           Derivation = derive({nonterminal, 'Program'}, root, Grammar,
                                               #derivation{budget = Budget,
                                                           coverage = Coverage}),
                           {{Number, lists:reverse(Derivation#derivation.tokens)},
                            Derivation#derivation.coverage}
                       end, #{}, lists:seq(1, ?PROGRAMS)),
    steered(choices(Grammar), ?PROGRAMS + 1, Grammar, Coverage, lists:reverse(Programs)).

%% A program for each choice no program has taken yet, steered to take it,
%% every other choice its shortest.
steered([], _, _, Coverage, Acc) ->
    {lists:reverse(Acc), Coverage};
steered([Choice | Rest], Number, Grammar, Coverage, Acc) ->
    case is_map_key(Choice, Coverage) of
        true ->
            steered(Rest, Number, Grammar, Coverage, Acc);
        false ->
            Derivation = derive({nonterminal, 'Program'}, root, Grammar,
                                #derivation{budget = 0, coverage = Coverage, target = Choice,
                                            distances = distances(Choice, Grammar)}),
            steered(Rest, Number + 1, Grammar, Derivation#derivation.coverage,
                    [{Number, lists:reverse(Derivation#derivation.tokens)} | Acc])
    end.

%% An expression derived at the choice point Point, a rule's name and the
%% path to the expression in its tree.
derive({terminal, Terminal}, _, Grammar, Derivation) ->
    emit(token(Terminal, Grammar), Derivation);
derive({nonterminal, Name}, _, Grammar, Derivation) ->
    derive(maps:get(Name, Grammar#grammar.rules), {Name, []}, Grammar, Derivation);
derive({sequence, Items}, Point, Grammar, Derivation) ->
    Steered = nearest(Items, Point, Derivation),
    lists:foldl(fun({Index, Item}, Acc) when Index =:= Steered ->
                        derive(Item, inner(Point, Index), Grammar, Acc);
                   ({Index, Item}, #derivation{target = Target} = Acc) ->
                        Derived = derive(Item, inner(Point, Index), Grammar,
                                         Acc#derivation{target = undefined}),
                        Derived#derivation{target = Target}
                end, Derivation, lists:enumerate(Items));
derive({alternatives, Branches}, Point, Grammar, Derivation) ->
    Options = [{Index, length_of(Branch, Grammar), Branch}
               || {Index, Branch} <- lists:enumerate(Branches)],
    Index = chosen(Point, Options, Derivation),
    derive(lists:nth(Index, Branches), inner(Point, Index), Grammar,
           covered(Point, Index, Derivation));
derive({optional, Expression}, Point, Grammar, Derivation) ->
    Options = [{0, 0, none}, {1, length_of(Expression, Grammar), Expression}],
    case chosen(Point, Options, Derivation) of
        0 -> covered(Point, 0, Derivation);
        1 -> derive(Expression, inner(Point, 1), Grammar, covered(Point, 1, Derivation))
    end;
derive({repetition, Expression}, Point, Grammar, Derivation) ->
    Length = length_of(Expression, Grammar),
    Times = case chosen(Point, [{0, 0, none}, {1, Length, Expression}, {2, 2 * Length, Expression}],
                        Derivation) of
                2 -> 1 + rand:uniform(2);
                Chosen -> Chosen
            end,
    lists:foldl(fun(_, Acc) -> derive(Expression, inner(Point, 1), Grammar, Acc) end,
                covered(Point, min(Times, 2), Derivation), lists:seq(1, Times)).

%% The root of a rule's tree is named for the rule when the rule is
%% entered, so a nonterminal's own point is never asked for.
inner({Rule, Path}, Index) -> {Rule, [Index | Path]}.

emit(Token, #derivation{tokens = Tokens, size = Size} = Derivation) ->
    Derivation#derivation{tokens = [Token | Tokens], size = Size + 1}.

%% The option taken at Point, and the derivation's target given up once
%% it is taken.
covered(Point, Option, #derivation{coverage = Coverage, target = Target} = Derivation) ->
    Reached = case Target of
                  {Point, Option} -> undefined;
                  _ -> Target
              end,
    Derivation#derivation{coverage = Coverage#{{Point, Option} => true}, target = Reached}.

%% An option among Options, each with the fewest tokens it derives and
%% what it derives: one that steers a derivation with a target nearer it;
%% past the budget one of the shortest, so that the program ends;
%% otherwise, as often as not, one no program has taken yet, and else any.
chosen(Point, Options,
       #derivation{size = Size, budget = Budget, coverage = Coverage} = Derivation) ->
    case steering(Point, Options, Derivation) of
        none when Size >= Budget ->
            Fewest = lists:min([Length || {_, Length, _} <- Options]),
            pick([Option || {Option, Length, _} <- Options, Length =:= Fewest]);
        none ->
            Untaken = [Option || {Option, _, _} <- Options,
                                 not is_map_key({Point, Option}, Coverage)],
            case Untaken =/= [] andalso rand:uniform(2) =:= 1 of
                true -> pick(Untaken);
                false -> pick([Option || {Option, _, _} <- Options])
            end;
        Steered ->
            Steered
    end.

%% The option that brings a derivation nearer its target: the target's own
%% at its point, and elsewhere the one whose expression reaches the
%% target's point through the fewest rules; none without a target, or
%% where no option reaches it.
steering(_, _, #derivation{target = undefined}) ->
    none;
steering(Point, _, #derivation{target = {Point, Option}}) ->
    Option;
steering(Point, Options, #derivation{target = Target, distances = Distances}) ->
    Reaching = [{Distance, Option}
                || {Option, _, Expression} <- Options, Expression =/= none,
                   Distance <- [distance(Expression, inner(Point, Option), Target, Distances)],
                   Distance =/= infinity],
    case Reaching of
        [] -> none;
        _ -> element(2, lists:min(Reaching))
    end.

%% The item of a sequence that a derivation with a target is steered in,
%% the first of those nearest the target, so that no other item reaches
%% it again through a rule that leads back; none without a target.
nearest(_, _, #derivation{target = undefined}) ->
    none;
nearest(Items, Point, #derivation{target = Target, distances = Distances}) ->
    Reaching = [{Distance, Index} || {Index, Item} <- lists:enumerate(Items),
                                     Distance <- [distance(Item, inner(Point, Index), Target,
                                                           Distances)],
                                     Distance =/= infinity],
    case Reaching of
        [] -> none;
        _ -> element(2, lists:min(Reaching))
    end.

%% How many rules an expression at Point is from the target's point: none
%% where the point lies within it, and else one more than its nearest
%% nonterminal is.
distance(Expression, {Rule, Path}, {{TargetRule, TargetPath}, _}, Distances) ->
    case Rule =:= TargetRule andalso lists:suffix(Path, TargetPath) of
        true -> 0;
        false -> lists:min([infinity | [further(maps:get(Name, Distances))
                                        || Name <- ern_grammar:nonterminals(Expression)]])
    end.

%% How many rules each nonterminal is from the target's rule, to their
%% fixed point; `infinity` where none leads there.
distances({{TargetRule, _}, _}, Grammar) ->
    Rules = maps:to_list(Grammar#grammar.rules),
    Distance = fun(Name, Expression, Distances) when Name =/= TargetRule ->
                       lists:min([infinity | [further(maps:get(Inner, Distances))
                                              || Inner <- ern_grammar:nonterminals(Expression)]]);
                  (_, _, _) ->
                       0
               end,
    Step = fun(Distances) ->
                   maps:from_list([{Name, Distance(Name, Expression, Distances)}
                                   || {Name, Expression} <- Rules])
           end,
    ern_grammar:fix(Step, maps:from_list([{Name, infinity} || {Name, _} <- Rules])).

further(infinity) -> infinity;
further(Distance) -> Distance + 1.

pick(Options) ->
    lists:nth(rand:uniform(length(Options)), Options).

%% Every choice point of the grammar with each of its options: a branch of
%% a choice, an optional part taken and left, a repetition run no times,
%% once and more.
choices(Grammar) ->
    Rules = maps:to_list(Grammar#grammar.rules),
    lists:append([choices(Expression, {Name, []}) || {Name, Expression} <- Rules]).

choices({sequence, Items}, Point) ->
    lists:append([choices(Item, inner(Point, Index)) || {Index, Item} <- lists:enumerate(Items)]);
choices({alternatives, Branches}, Point) ->
    [{Point, Index} || Index <- lists:seq(1, length(Branches))]
        ++ lists:append([choices(Branch, inner(Point, Index))
                         || {Index, Branch} <- lists:enumerate(Branches)]);
choices({optional, Expression}, Point) ->
    [{Point, 0}, {Point, 1} | choices(Expression, inner(Point, 1))];
choices({repetition, Expression}, Point) ->
    [{Point, 0}, {Point, 1}, {Point, 2} | choices(Expression, inner(Point, 1))];
choices(_, _) ->
    [].

%% The fewest tokens each nonterminal derives, to their fixed point.
shortest(Rules) ->
    Infinite = maps:from_list([{Name, infinity} || {Name, _} <- Rules]),
    Step = fun(Shortest) ->
                   maps:from_list([{Name, length_of(Expression, #grammar{shortest = Shortest})}
                                   || {Name, Expression} <- Rules])
           end,
    ern_grammar:fix(Step, Infinite).

%% The fewest tokens an expression derives; an atom is larger than any
%% number, so `infinity` stands for none yet.
length_of({terminal, _}, _) -> 1;
length_of({nonterminal, Name}, Grammar) -> maps:get(Name, Grammar#grammar.shortest);
length_of({sequence, Items}, Grammar) -> sum([length_of(Item, Grammar) || Item <- Items]);
length_of({alternatives, Branches}, Grammar) ->
    lists:min([length_of(Branch, Grammar) || Branch <- Branches]);
length_of({optional, _}, _) -> 0;
length_of({repetition, _}, _) -> 0.

sum(Lengths) ->
    case lists:member(infinity, Lengths) of
        true -> infinity;
        false -> lists:sum(Lengths)
    end.

%%
%% Tokens and text
%%

%% A token for a terminal of the grammar: its class and its text. A
%% quoted terminal is a reserved word or a delimiter, or a word §2.4 does
%% not reserve, which the lexer reads as an identifier; a category is one
%% of a few spellings of it, among them identifiers that are words of the
%% grammar elsewhere.
token(Text, Grammar) when is_list(Text) ->
    case is_word(Text) andalso not lists:member(Text, Grammar#grammar.reserved) of
        true -> {ident, Text};
        false -> {word, Text}
    end;
token(Category, _) ->
    {Category, pick(spellings(Category))}.

is_word([First | _] = Text) ->
    is_lower(First) andalso lists:all(fun(Char) -> is_lower(Char) orelse is_digit(Char) end, Text).

is_lower(Char) -> Char >= $a andalso Char =< $z.

is_digit(Char) -> Char >= $0 andalso Char =< $9.

spellings(ident) ->
    ["x", "y", "go", "acc2", "_x", "a_b", "size", "compare", "negate", "show", "int", "big",
     "utf8", "signed"];
spellings(typename) ->
    ["T", "Foo", "Int", "B2", "Ab_c"];
spellings(int) ->
    ["0", "7", "42", "1_000", "0x1F", "0o17", "0b1010"];
spellings(float) ->
    ["1.5", "0.0", "2.5e3", "1e10", "3.141_592", "1.0E-9"];
spellings(char) ->
    ["'a'", "'\\n'", "'\\''", "'\\u{1F600}'", "'\x{e9}'", "'\"'"];
spellings(string) ->
    ["\"\"", "\"hi\"", "\"a\\tb\"", "\"\\u{41}\"", "`raw\\d`", "\"\x{e9}\"", "\"'\""].

%% The tokens as source text, whitespace between each two: mostly a
%% space, sometimes a line break, a blank line or a tab.
text(Tokens) ->
    Texts = [Text || {_, Text} <- Tokens],
    unicode:characters_to_binary(lists:join(" ", [[gap(), Text] || Text <- Texts])).

gap() ->
    case rand:uniform(100) of
        Roll when Roll =< 85 -> "";
        Roll when Roll =< 93 -> "\n";
        Roll when Roll =< 96 -> "\n\n";
        Roll when Roll =< 98 -> "\t";
        _ -> "\r\n"
    end.

%%
%% Near misses
%%

%% Every terminal of the grammar, once.
vocabulary(Rules) ->
    lists:usort(lists:append([terminals(Expression) || {_, Expression} <- Rules])).

terminals({terminal, Terminal}) -> [Terminal];
terminals({nonterminal, _}) -> [];
terminals({optional, Expression}) -> terminals(Expression);
terminals({repetition, Expression}) -> terminals(Expression);
terminals({_, Items}) -> lists:append([terminals(Item) || Item <- Items]).

%% The tokens with one changed: deleted, doubled, swapped with the next,
%% replaced, or preceded by another of the grammar's.
near_miss([], Vocabulary, Grammar) ->
    [token(pick(Vocabulary), Grammar)];
near_miss(Tokens, Vocabulary, Grammar) ->
    Index = rand:uniform(length(Tokens)),
    {Before, [Token | After]} = lists:split(Index - 1, Tokens),
    case rand:uniform(5) of
        1 -> Before ++ After;
        2 -> Before ++ [Token, Token | After];
        3 when After =/= [] -> Before ++ [hd(After), Token | tl(After)];
        4 -> Before ++ [token(pick(Vocabulary), Grammar) | After];
        _ -> Before ++ [token(pick(Vocabulary), Grammar), Token | After]
    end.

%%
%% The recognizer
%%

%% Appendix A's rules as productions: each rule's alternatives, and a
%% nonterminal of its own for each group, optional part and repetition
%% within a rule, `{Rule, Number}`.
recognizer(Rules) ->
    {Productions, _} =
        lists:foldl(fun({Name, Expression}, {Acc, Next}) ->
                        {Alternatives, Acc1, Next1} = alternatives(Expression, Acc, Next),
                        {[{Name, Symbols} || Symbols <- Alternatives] ++ Acc1, Next1}
                    end, {[], 1}, Rules),
    Numbered = lists:enumerate(Productions),
    ByName = lists:foldl(fun({Index, {Name, _}}, Acc) ->
                             maps:update_with(Name, fun(Indexes) -> [Index | Indexes] end,
                                              [Index], Acc)
                         end, #{}, Numbered),
    #recognizer{productions = list_to_tuple([{Name, list_to_tuple(Symbols)}
                                             || {Name, Symbols} <- Productions]),
                by_name = ByName,
                nullable = nullable(Productions)}.

%% An expression's alternatives, each a list of symbols, with the
%% productions its inner groups need.
alternatives({alternatives, Branches}, Acc, Next) ->
    lists:foldr(fun(Branch, {Alternatives, BranchAcc, BranchNext}) ->
                    {Symbols, BranchAcc1, BranchNext1} = symbols(Branch, BranchAcc, BranchNext),
                    {[Symbols | Alternatives], BranchAcc1, BranchNext1}
                end, {[], Acc, Next}, Branches);
alternatives(Expression, Acc, Next) ->
    {Symbols, Acc1, Next1} = symbols(Expression, Acc, Next),
    {[Symbols], Acc1, Next1}.

symbols({sequence, Items}, Acc, Next) ->
    lists:foldl(fun(Item, {Symbols, ItemAcc, ItemNext}) ->
                    {Symbol, ItemAcc1, ItemNext1} = symbol(Item, ItemAcc, ItemNext),
                    {Symbols ++ [Symbol], ItemAcc1, ItemNext1}
                end, {[], Acc, Next}, Items);
symbols(Expression, Acc, Next) ->
    {Symbol, Acc1, Next1} = symbol(Expression, Acc, Next),
    {[Symbol], Acc1, Next1}.

symbol({terminal, _} = Terminal, Acc, Next) ->
    {Terminal, Acc, Next};
symbol({nonterminal, _} = Nonterminal, Acc, Next) ->
    {Nonterminal, Acc, Next};
symbol({optional, Expression}, Acc, Next) ->
    Name = {inner, Next},
    {Alternatives, Acc1, Next1} = alternatives(Expression, Acc, Next + 1),
    Productions = [{Name, []} | [{Name, Symbols} || Symbols <- Alternatives]],
    {{nonterminal, Name}, Productions ++ Acc1, Next1};
symbol({repetition, Expression}, Acc, Next) ->
    Name = {inner, Next},
    {Alternatives, Acc1, Next1} = alternatives(Expression, Acc, Next + 1),
    Productions = [{Name, []} | [{Name, Symbols ++ [{nonterminal, Name}]}
                                 || Symbols <- Alternatives]],
    {{nonterminal, Name}, Productions ++ Acc1, Next1};
symbol(Group, Acc, Next) ->
    Name = {inner, Next},
    {Alternatives, Acc1, Next1} = alternatives(Group, Acc, Next + 1),
    {{nonterminal, Name}, [{Name, Symbols} || Symbols <- Alternatives] ++ Acc1, Next1}.

%% The nonterminals that derive no token, to their fixed point.
nullable(Productions) ->
    Step = fun(Nullable) ->
                   Empty = fun({nonterminal, Inner}) -> is_map_key(Inner, Nullable);
                              ({terminal, _}) -> false
                           end,
                   maps:from_list([{Name, true} || {Name, Symbols} <- Productions,
                                                   lists:all(Empty, Symbols)])
           end,
    ern_grammar:fix(Step, #{}).

%% Whether the tokens are a sentence of the grammar: Earley's recognizer,
%% an item a production, how much of it is read, and where it began; a
%% nonterminal that derives nothing is stepped over where it is predicted
%% (Aycock and Horspool), so that no completion is lost.
recognized(Tokens, Recognizer) ->
    Input = list_to_tuple(Tokens),
    Initial = [{Index, 0, 0} || Index <- maps:get('Program', Recognizer#recognizer.by_name)],
    recognized(0, Initial, Input, Recognizer, #{}).

recognized(Position, Items, Input, Recognizer, Waitings) ->
    {Seen, Waiting, Scanned} = closure(Items, Position, Input, Recognizer, Waitings, #{}, #{}, []),
    case Position =:= tuple_size(Input) of
        true ->
            lists:any(fun({Index, Dot, 0}) ->
                              {Name, Symbols} = element(Index, Recognizer#recognizer.productions),
                              Name =:= 'Program' andalso Dot =:= tuple_size(Symbols);
                         (_) -> false
                      end, maps:keys(Seen));
        false when Scanned =:= [] ->
            false;
        false ->
            recognized(Position + 1, Scanned, Input, Recognizer, Waitings#{Position => Waiting})
    end.

%% The items at Position, those that wait there for each nonterminal, and
%% those a token moves to the next position.
closure([], _, _, _, _, Seen, Waiting, Scanned) ->
    {Seen, Waiting, Scanned};
closure([Item | Agenda], Position, Input, Recognizer, Waitings, Seen, Waiting, Scanned) ->
    case is_map_key(Item, Seen) of
        true ->
            closure(Agenda, Position, Input, Recognizer, Waitings, Seen, Waiting, Scanned);
        false ->
            {Index, Dot, Origin} = Item,
            {Name, Symbols} = element(Index, Recognizer#recognizer.productions),
            Seen1 = Seen#{Item => true},
            case Dot =:= tuple_size(Symbols) of
                true ->
                    Waiters = case Origin =:= Position of
                                  true -> maps:get(Name, Waiting, []);
                                  false -> maps:get(Name, maps:get(Origin, Waitings), [])
                              end,
                    closure([advanced(Waiter) || Waiter <- Waiters] ++ Agenda, Position, Input,
                            Recognizer, Waitings, Seen1, Waiting, Scanned);
                false ->
                    case element(Dot + 1, Symbols) of
                        {nonterminal, Inner} ->
                            Predicted = [{Production, 0, Position}
                                         || Production <- maps:get(Inner,
                                                                   Recognizer#recognizer.by_name)],
                            Stepped = case is_map_key(Inner, Recognizer#recognizer.nullable) of
                                          true -> [advanced(Item)];
                                          false -> []
                                      end,
                            Waiting1 = maps:update_with(Inner, fun(Items) -> [Item | Items] end,
                                                        [Item], Waiting),
                            closure(Predicted ++ Stepped ++ Agenda, Position, Input, Recognizer,
                                    Waitings, Seen1, Waiting1, Scanned);
                        {terminal, Terminal} ->
                            Scanned1 = case scans(Terminal, Position, Input) of
                                           true -> [advanced(Item) | Scanned];
                                           false -> Scanned
                                       end,
                            closure(Agenda, Position, Input, Recognizer, Waitings, Seen1, Waiting,
                                    Scanned1)
                    end
            end
    end.

advanced({Index, Dot, Origin}) -> {Index, Dot + 1, Origin}.

%% Whether the token after Position is the terminal.
scans(Terminal, Position, Input) ->
    Position < tuple_size(Input) andalso matches(Terminal, element(Position + 1, Input)).

%% Whether a token is the terminal: a category by its class, and a quoted
%% terminal by its text, a reserved word or delimiter or an identifier.
matches(Text, {Class, Text}) when is_list(Text) -> Class =:= word orelse Class =:= ident;
matches(Category, {Category, _}) -> true;
matches(_, _) -> false.
