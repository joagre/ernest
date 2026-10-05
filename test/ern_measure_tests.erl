%% `make bench`'s measuring machine, ern_measure (plan MVP 2.99d item 1):
%% every exported function of the standard library and the libraries is
%% measured, by arguments drawn from its type or by a scenario, or listed
%% with the reason it cannot be, and every call the machine makes runs.
%% Written with the machine; it times nothing, so what the machine reports
%% is not checked here, only that it can report on every function.
-module(ern_measure_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.0 rule 1: each function is measured against the line,
%% or named with why it is not
every_function_measured_test_() ->
    {timeout, 120, fun every_function_measured/0}.

every_function_measured() ->
    Rows = ern_measure:measured([10], once),
    ?assertEqual(length(ern_measure:entries()), length(Rows)),
    ?assertEqual([], [{iolist_to_binary(Display), Outcome}
                      || #{display := Display, outcome := Outcome} <- Rows,
                         not accounted(Outcome)]).

%% A function the machine timed, in a scenario or with another's, or one
%% that is no function or that no measurement can reach.
accounted({timed, _}) -> true;
accounted({system, _, _}) -> true;
accounted({within, _}) -> true;
accounted({not_measured, Reason}) ->
    lists:member(Reason, [<<"a top-level binding, no function">>, <<"reads standard input">>,
                          <<"reads a terminal">>, <<"ends the program, or faults the caller">>]);
accounted(_) -> false.
