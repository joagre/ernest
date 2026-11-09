%% Program 4's host side: a process that sends Message to To after Ms
%% milliseconds, and its pid.
-module(later).
-export([send/3]).

send(To, Message, Ms) ->
    erlang:spawn(fun() ->
                     receive after Ms -> ok end,
                     To ! Message
                 end).
