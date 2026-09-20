%% The shims behind Foreign (report Appendix E.12, rule 1): what a value of
%% the runtime is can only be asked of the runtime. `from` is the identity,
%% since an Ernest value is already a value of the runtime (report §8.4).
-module(ern_foreign).

-export([from/1, to_int/1, to_float/1, to_string/1, to_bool/1, to_list/1]).

-spec from(term()) -> term().
from(X) -> X.

-spec to_int(term()) -> {'Some', integer()} | 'None'.
to_int(X) when is_integer(X) -> {'Some', X};
to_int(_) -> 'None'.

%% report §3.1: the language has no negative zero
-spec to_float(term()) -> {'Some', float()} | 'None'.
to_float(X) when is_float(X) -> {'Some', X + 0.0};
to_float(_) -> 'None'.

-spec to_string(term()) -> {'Some', binary()} | 'None'.
to_string(X) when is_binary(X) ->
    case unicode:characters_to_binary(X, utf8, utf8) of
        X -> {'Some', X};
        _ -> 'None'
    end;
to_string(_) -> 'None'.

-spec to_bool(term()) -> {'Some', boolean()} | 'None'.
to_bool(X) when is_boolean(X) -> {'Some', X};
to_bool(_) -> 'None'.

-spec to_list(term()) -> {'Some', [term()]} | 'None'.
to_list(X) when is_list(X) -> {'Some', X};
to_list(_) -> 'None'.
