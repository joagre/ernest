%% Appendix E.2, namespace List, as an Erlang module for MVP 1. No Erlang
%% exception escapes: the partial operations return Optional.
-module('ernest@list').

-export([size/1, isEmpty/1, get/2, last/1, reverse/1, take/2, drop/2, dropLast/1,
         contains/2, find/2, any/2, all/2, map/2, filter/2, filterMap/2, foldLeft/3,
         foreach/2, span/2, partition/2, unique/1, indexed/1, repeat/2, sort/2, remove/2,
         zip/2, unzip/1, flatMap/2, range/2, tryMap/2, tryFold/3]).

size(Xs) -> length(Xs).
isEmpty(Xs) -> Xs =:= [].
get(Xs, N) when N >= 0, N < length(Xs) -> {'Some', lists:nth(N + 1, Xs)};
get(_, _) -> 'None'.
last([]) -> 'None';
last(Xs) -> {'Some', lists:last(Xs)}.
reverse(Xs) -> lists:reverse(Xs).
take(_, N) when N =< 0 -> [];
take(Xs, N) -> lists:sublist(Xs, N).
drop(Xs, N) when N =< 0 -> Xs;
drop(Xs, N) when N >= length(Xs) -> [];
drop(Xs, N) -> lists:nthtail(N, Xs).
dropLast([]) -> [];
dropLast(Xs) -> lists:droplast(Xs).
contains(Xs, X) -> lists:member(X, Xs).
find([], _) -> 'None';
find([X | Xs], P) ->
    case P(X) of
        true -> {'Some', X};
        false -> find(Xs, P)
    end.
any(Xs, P) -> lists:any(P, Xs).
all(Xs, P) -> lists:all(P, Xs).
map(Xs, F) -> lists:map(F, Xs).
filter(Xs, P) -> lists:filter(P, Xs).
filterMap(Xs, F) ->
    lists:filtermap(fun(X) ->
                        case F(X) of
                            {'Some', Y} -> {true, Y};
                            'None' -> false
                        end
                    end, Xs).
foldLeft(Xs, Acc, F) -> lists:foldl(fun(X, A) -> F(A, X) end, Acc, Xs).
foreach(Xs, F) -> lists:foreach(F, Xs), 'Unit'.
span(Xs, P) ->
    {Prefix, Rest} = lists:splitwith(P, Xs),
    {Prefix, Rest}.
partition(Xs, P) -> lists:partition(P, Xs).
unique(Xs) -> lists:uniq(Xs).
indexed(Xs) -> lists:enumerate(0, Xs).
repeat(_, N) when N =< 0 -> [];
repeat(X, N) -> lists:duplicate(N, X).
sort(Xs, Compare) -> lists:sort(fun(A, B) -> Compare(A, B) =/= 'Greater' end, Xs).
remove(Xs, X) -> lists:delete(X, Xs).
zip([X | Xs], [Y | Ys]) -> [{X, Y} | zip(Xs, Ys)];
zip(_, _) -> [].
unzip(Pairs) -> lists:unzip(Pairs).
flatMap(Xs, F) -> lists:append([F(X) || X <- Xs]).
range(From, To) when From > To -> [];
range(From, To) -> lists:seq(From, To).
tryMap(Xs, F) -> tryMap(Xs, F, []).

tryMap([], _, Acc) -> {'Right', lists:reverse(Acc)};
tryMap([X | Xs], F, Acc) ->
    case F(X) of
        {'Right', Y} -> tryMap(Xs, F, [Y | Acc]);
        {'Left', _} = Left -> Left
    end.

tryFold([], Acc, _) -> {'Right', Acc};
tryFold([X | Xs], Acc, F) ->
    case F(Acc, X) of
        {'Right', Acc1} -> tryFold(Xs, Acc1, F);
        {'Left', _} = Left -> Left
    end.
