%% The shim behind Map.get (report Appendix E.3, E.0 rule 1): the value at
%% a key, as an Optional. The host's `maps:find/2` answers `{ok, Value}` or
%% `error`, no value of Ernest's; the rest of Map's primitives are the
%% `maps` module's own functions.
-module(ern_map).

-export([get/2]).

-spec get(map(), term()) -> {'Some', term()} | 'None'.
get(Map, Key) ->
    case Map of
        #{Key := Value} -> {'Some', Value};
        _ -> 'None'
    end.
