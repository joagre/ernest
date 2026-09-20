%% The shim behind Int.toFloat (report Appendix E.8): the one conversion
%% whose fault Erlang does not raise in the report's words (§7.4).
-module(ern_int).

-export([to_float/1]).

-spec to_float(integer()) -> float().
to_float(N) ->
    try float(N)
    catch error:badarg -> ern_rt:fault(<<"Int out of Float range">>)
    end.
