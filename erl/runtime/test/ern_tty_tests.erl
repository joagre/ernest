%% Report §9.3: the keys of Appendix E.16, decoded from what a terminal
%% sends. The reading itself needs a terminal; the decoding does not.
-module(ern_tty_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §9.3: a character, the arrows, Enter, and Escape
decode_test() ->
    ?assertEqual({[{'Char', $a}, {'Char', $b}], []}, ern_tty:decode("ab")),
    ?assertEqual({['Enter', 'Enter'], []}, ern_tty:decode("\n\r")),
    ?assertEqual({['ArrowUp', 'ArrowDown', 'ArrowRight', 'ArrowLeft'], []},
                 ern_tty:decode("\e[A\e[B\e[C\e[D")),
    ?assertEqual({[{'Char', $x}, 'ArrowUp'], []}, ern_tty:decode("x\e[A")),
    ?assertEqual({['Escape', {'Char', $z}], []}, ern_tty:decode("\ez")),
    ?assertEqual({[{'Char', 16#E9}], []}, ern_tty:decode([16#E9])).

%% report §9.3: an escape that may still grow into an arrow waits for the
%% rest, and the caller passes what is left back in
partial_sequence_test() ->
    ?assertEqual({[], "\e"}, ern_tty:decode("\e")),
    ?assertEqual({[], "\e["}, ern_tty:decode("\e[")),
    {[], Rest} = ern_tty:decode("\e["),
    ?assertEqual({['ArrowUp'], []}, ern_tty:decode(Rest ++ "A")),
    %% report §9.3: a sequence §9.3 does not name is the Escape key and the
    %% characters after it, which is how Meta and the page keys arrive
    ?assertEqual({['Escape', {'Char', $[}, {'Char', $5}, {'Char', $~}], []},
                 ern_tty:decode("\e[5~")).

%% report §8.2: Escape is delivered once no escape sequence can still
%% follow it, so what waits is flushed when the pause passes
flush_test() ->
    ?assertEqual(['Escape'], ern_tty:flush("\e")),
    ?assertEqual(['Escape', {'Char', $[}], ern_tty:flush("\e[")),
    ?assertEqual([], ern_tty:flush("")),
    %% a sequence that did arrive whole is decoded, not flushed
    ?assertEqual({['ArrowUp'], []}, ern_tty:decode("\e[A")).

%% report §8.2, §9.3: the terminal's process delivers each key as an
%% `Event`, a lone Escape after the pause
%% and an arrow at once; ern_rt:send needs a run, so this one has one
escape_pause_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:sys(terminal),
               %% report §8.2: the subscription is answered once the mode is set
               subscribe(Tty),
               %% as the reader sends them: the arrow whole, the escape alone
               Tty ! {chars, "\e[A"},
               receive K1 -> Me ! {k1, K1} end,
               Tty ! {chars, "\e"},
               receive K2 -> Me ! {k2, K2} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual('ArrowUp', wait(k1)),
    ?assertEqual('Escape', wait(k2)).

wait(Tag) ->
    receive {Tag, V} -> V after 2000 -> timeout end.

%% Report §8.2: `Subscribe` carries a reply, answered once the terminal is
%% in the mode the keys need.
subscribe(Tty) ->
    Me = ern_rt:self(),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Reply, Me} end, 5000).
