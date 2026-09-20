%% The shim behind List.sort (report Appendix E.2, rule 1): Erlang's merge
%% sort, which is stable and tuned, given Ernest's comparison as the `=<`
%% the sort wants.
-module(ern_list).

-export([sort/2]).

-spec sort([term()], fun((term(), term()) -> 'Less' | 'Equal' | 'Greater')) -> [term()].
sort(Xs, Compare) -> lists:sort(fun(A, B) -> Compare(A, B) =/= 'Greater' end, Xs).
