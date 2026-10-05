%% The shims behind Int.toFloat and Int.shiftLeft (report Appendix E.8):
%% the two operations whose faults Erlang does not raise in the report's
%% words (§7.4).
-module(ern_int).

-export([to_float/1, shift_left/2]).

-spec to_float(integer()) -> float().
to_float(Integer) ->
    try float(Integer)
    catch error:badarg -> ern_rt:fault(<<"Int out of Float range">>)
    end.

%% Report §7.4: a result beyond the host's integers is a limit of the host
%% met, the same cause `*` gives, and not a foreign function's raise.
-spec shift_left(integer(), non_neg_integer()) -> integer().
shift_left(Integer, Count) ->
    try Integer bsl Count
    catch error:system_limit -> ern_rt:fault(<<"error:system_limit">>)
    end.
