%% Appendix E.14, namespace Path, as an Erlang module for MVP 1. A Path is
%% {'Path', String} under the ABI (report §8.4, §9.3), in the runtime's
%% syntax, and the functions are filename's: join is filename:join, so an
%% absolute second stands alone; split keeps the root as the first segment;
%% parent is dirname, None where dirname answers "." or the path itself.
-module('ernest@path').

-export([join/2, split/1, parent/1, name/1, extension/1, withExtension/2, isAbsolute/1,
         toString/1]).

join({'Path', A}, {'Path', B}) -> {'Path', bin(filename:join(A, B))}.
split({'Path', P}) -> [bin(S) || S <- filename:split(P)].
parent({'Path', P}) ->
    case bin(filename:dirname(P)) of
        <<".">> -> 'None';
        P -> 'None';
        D -> {'Some', {'Path', D}}
    end.
name({'Path', P}) -> bin(filename:basename(P)).
extension({'Path', P}) ->
    case bin(filename:extension(P)) of
        <<>> -> 'None';
        <<$., Ext/binary>> -> {'Some', Ext}
    end.
withExtension({'Path', P}, <<>>) -> {'Path', bin(filename:rootname(P))};
withExtension({'Path', P}, Ext) -> {'Path', <<(bin(filename:rootname(P)))/binary, $., Ext/binary>>}.
isAbsolute({'Path', P}) -> filename:pathtype(P) =:= absolute.
toString({'Path', P}) -> P.

bin(S) -> unicode:characters_to_binary(S).
