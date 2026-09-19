%% The shim behind Float.toString (report Appendix E.9): Erlang prints the
%% shortest form only when asked.
-module(ern_float).

-export([to_string/1]).

-spec to_string(float()) -> binary().
to_string(F) -> float_to_binary(F, [short]).
