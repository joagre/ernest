%% The shim behind List.zip (report Appendix E.2): the host's zip, told to
%% leave the longer list's rest out, which takes an atom that Ernest would
%% make at every call. Made in Ernest, the atom cost 160 to 200 ns a call,
%% twice the host's zip of ten pairs (E.0 rule 1; the log's *List Stands on
%% the Host*).
-module(ern_list).

-export([zip/2]).

-spec zip(list(), list()) -> [{term(), term()}].
zip(List, Other) ->
    lists:zip(List, Other, trim).
