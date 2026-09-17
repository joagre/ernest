%% Appendix E.2, namespace List, as an Erlang module for MVP 1. Indices are
%% zero-based. No Erlang exception escapes: the partial operations return
%% Optional.
-module('ernest@list').

-export([size/1, isEmpty/1, head/1, last/1, at/2, reverse/1, take/2, drop/2, dropLast/1,
         contains/2, find/2, any/2, all/2, map/2, filter/2, filterMap/2, foldLeft/3,
         foreach/2, span/2, sort/2, remove/2]).

size(Xs) -> length(Xs).
isEmpty(Xs) -> Xs =:= [].
head([X | _]) -> {'Some', X};
head([]) -> 'None'.
last([]) -> 'None';
last(Xs) -> {'Some', lists:last(Xs)}.
at(Xs, N) when N >= 0, N < length(Xs) -> {'Some', lists:nth(N + 1, Xs)};
at(_, _) -> 'None'.
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
sort(Xs, Compare) -> lists:sort(fun(A, B) -> Compare(A, B) =/= 'Greater' end, Xs).
remove(Xs, X) -> lists:delete(X, Xs).
