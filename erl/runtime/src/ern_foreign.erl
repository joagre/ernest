%% The shims behind Foreign (report Appendix E.12, rule 1): what a value of
%% the runtime is can only be asked of the runtime. `term/1` stands behind
%% the declaration and is the identity: a use of `Foreign.term` is compiled
%% to the crossing itself, by the type it is used at (report §8.4,
%% ern_emitter), and nothing of the value's type is known here.
-module(ern_foreign).

-export([term/1, to_int/1, to_float/1, to_string/1, to_bytes/1, to_bool/1, to_list/1]).

-spec term(term()) -> term().
term(Value) -> Value.

-spec to_int(term()) -> {'Some', integer()} | 'None'.
to_int(Value) when is_integer(Value) -> {'Some', Value};
to_int(_) -> 'None'.

%% report §3.1: the language has no negative zero
-spec to_float(term()) -> {'Some', float()} | 'None'.
to_float(Value) when is_float(Value) -> {'Some', Value + 0.0};
to_float(_) -> 'None'.

-spec to_string(term()) -> {'Some', binary()} | 'None'.
to_string(Value) when is_binary(Value) ->
    case unicode:characters_to_binary(Value, utf8, utf8) of
        Value -> {'Some', Value};
        _ -> 'None'
    end;
to_string(_) -> 'None'.

%% report Appendix E.12: any binary, a bitstring of whole bytes; one of
%% another length is no Bytes
-spec to_bytes(term()) -> {'Some', binary()} | 'None'.
to_bytes(Value) when is_binary(Value) -> {'Some', Value};
to_bytes(_) -> 'None'.

-spec to_bool(term()) -> {'Some', boolean()} | 'None'.
to_bool(Value) when is_boolean(Value) -> {'Some', Value};
to_bool(_) -> 'None'.

%% report §8.4, Appendix E.12: a List is a proper list, so an improper one
%% is none; the guard's length fails on one
-spec to_list(term()) -> {'Some', [term()]} | 'None'.
to_list(Value) when is_list(Value), length(Value) >= 0 -> {'Some', Value};
to_list(_) -> 'None'.
