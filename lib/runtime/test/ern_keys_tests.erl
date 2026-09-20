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
