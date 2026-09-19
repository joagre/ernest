%% Appendix E.12, namespace Foreign, as an Erlang module for MVP 1: a
%% Foreign value is any Erlang term (report §3.8); each conversion answers
%% Some when the term has the Ernest representation of the target type
%% (report §8.4) and None otherwise.
-module('ernest@foreign').

-export([toInt/1, toFloat/1, toString/1, toBool/1, toList/1]).

toInt(X) when is_integer(X) -> {'Some', X};
toInt(_) -> 'None'.
toFloat(X) when is_float(X) -> {'Some', X + 0.0}; % report §3.1: no negative zero
toFloat(_) -> 'None'.
toString(X) when is_binary(X) ->
    case unicode:characters_to_binary(X, utf8, utf8) of
        X -> {'Some', X};
        _ -> 'None'
    end;
toString(_) -> 'None'.
toBool(X) when is_boolean(X) -> {'Some', X};
toBool(_) -> 'None'.
toList(X) when is_list(X) -> {'Some', X};
toList(_) -> 'None'.
