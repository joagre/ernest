%% Report §9.3: the keys of Appendix E.16, decoded from what a terminal
%% sends. The reading itself needs a terminal; the decoding does not.
-module(ern_keys_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §9.3: a character, the arrows, Enter, and Escape
decode_test() ->
    ?assertEqual({[{'Char', $a}, {'Char', $b}], []}, ern_keys:decode("ab")),
    ?assertEqual({['Enter', 'Enter'], []}, ern_keys:decode("\n\r")),
    ?assertEqual({['ArrowUp', 'ArrowDown', 'ArrowRight', 'ArrowLeft'], []},
                 ern_keys:decode("\e[A\e[B\e[C\e[D")),
    ?assertEqual({[{'Char', $x}, 'ArrowUp'], []}, ern_keys:decode("x\e[A")),
    ?assertEqual({['Escape', {'Char', $z}], []}, ern_keys:decode("\ez")),
    ?assertEqual({[{'Char', 16#E9}], []}, ern_keys:decode([16#E9])).

%% report §9.3: an escape that may still grow into an arrow waits for the
%% rest, and the caller passes what is left back in
partial_sequence_test() ->
    ?assertEqual({[], "\e"}, ern_keys:decode("\e")),
    ?assertEqual({[], "\e["}, ern_keys:decode("\e[")),
    {[], Rest} = ern_keys:decode("\e["),
    ?assertEqual({['ArrowUp'], []}, ern_keys:decode(Rest ++ "A")).

%% report §8.2: Escape is delivered once no escape sequence can still
%% follow it, so what waits is flushed when the pause passes
flush_test() ->
    ?assertEqual(['Escape'], ern_keys:flush("\e")),
    ?assertEqual(['Escape', {'Char', $[}], ern_keys:flush("\e[")),
    ?assertEqual([], ern_keys:flush("")),
    %% a sequence that did arrive whole is decoded, not flushed
    ?assertEqual({['ArrowUp'], []}, ern_keys:decode("\e[A")).

%% report §8.2: the keys process delivers a lone Escape after the pause,
%% and an arrow at once; ern_rt:send needs a run, so this one has one
escape_pause_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Keys = ern_rt:sys(keys),
               ern_rt:send(Keys, {'Subscribe', ern_rt:self()}),
               %% as the reader sends them: the arrow whole, the escape alone
               Keys ! {chars, "\e[A"},
               receive K1 -> Me ! {k1, K1} end,
               Keys ! {chars, "\e"},
               receive K2 -> Me ! {k2, K2} end
           end, <<"main">>, #{stdout => fun(_) -> ok end}),
    ?assertEqual('ArrowUp', wait(k1)),
    ?assertEqual('Escape', wait(k2)).

wait(Tag) ->
    receive {Tag, V} -> V after 2000 -> timeout end.
