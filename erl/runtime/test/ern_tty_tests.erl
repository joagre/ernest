%% Report Appendix E.16: the keys of Appendix E.16, decoded from what a terminal
%% sends. The reading itself needs a terminal; the decoding does not.
-module(ern_tty_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.16: a character, the arrows, Enter, and Escape
decode_test() ->
    ?assertEqual({[{'Key', $a}, {'Key', $b}], []}, ern_tty:decode("ab")),
    ?assertEqual({['Enter', 'Enter'], []}, ern_tty:decode("\n\r")),
    ?assertEqual({['ArrowUp', 'ArrowDown', 'ArrowRight', 'ArrowLeft'], []},
                 ern_tty:decode("\e[A\e[B\e[C\e[D")),
    ?assertEqual({[{'Key', $x}, 'ArrowUp'], []}, ern_tty:decode("x\e[A")),
    ?assertEqual({['Escape', {'Key', $z}], []}, ern_tty:decode("\ez")),
    ?assertEqual({[{'Key', 16#E9}], []}, ern_tty:decode([16#E9])).

%% report Appendix E.16: an escape that may still grow into an arrow waits for the
%% rest, and the caller passes what is left back in
partial_sequence_test() ->
    ?assertEqual({[], "\e"}, ern_tty:decode("\e")),
    ?assertEqual({[], "\e["}, ern_tty:decode("\e[")),
    {[], Rest} = ern_tty:decode("\e["),
    ?assertEqual({['ArrowUp'], []}, ern_tty:decode(Rest ++ "A")),
    %% report Appendix E.16: a sequence Appendix E.16 does not name is the Escape key and the
    %% characters after it, which is how Meta and the page keys arrive
    ?assertEqual({['Escape', {'Key', $[}, {'Key', $5}, {'Key', $~}], []},
                 ern_tty:decode("\e[5~")).

%% report §8.2: Escape is delivered once no escape sequence can still
%% follow it, so what waits is flushed when the pause passes
flush_test() ->
    ?assertEqual(['Escape'], ern_tty:flush("\e")),
    ?assertEqual(['Escape', {'Key', $[}], ern_tty:flush("\e[")),
    ?assertEqual([], ern_tty:flush("")),
    %% a sequence that did arrive whole is decoded, not flushed
    ?assertEqual({['ArrowUp'], []}, ern_tty:decode("\e[A")).

%% report §8.2, Appendix E.16: the terminal's process delivers each key as an
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
           end, <<"main">>, #{stdout => fun(_) -> ok end, keys => fun silent/0}),
    ?assertEqual('ArrowUp', wait(k1)),
    ?assertEqual('Escape', wait(k2)).

%% report §8.2: a process holds one subscription, and a second replaces
%% the first, its wrap from then on. A regression test: each call added the
%% address again, and every key arrived once for each.
second_subscription_test() ->
    Me = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:sys(terminal),
               subscribe(Tty),
               Wrapped = ern_rt:via(fun(E) -> {again, E} end, ern_rt:self()),
               ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Reply, Wrapped} end, 5000),
               %% a key delivered twice would come before the second key
               Tty ! {chars, "a"},
               First = receive M1 -> M1 end,
               Tty ! {chars, "b"},
               Second = receive M2 -> M2 end,
               Me ! {got, [First, Second]}
           end, <<"main">>, #{stdout => fun(_) -> ok end, keys => fun silent/0}),
    ?assertEqual([{again, {'Key', $a}}, {again, {'Key', $b}}], wait(got)).

%% report §8.2, §8.6: a subscription ends when its process dies, so the
%% keys stop being a source that can deliver, and a program left waiting
%% on nothing is found deadlocked. A regression test: a dead subscriber
%% stayed in the list, and the program waited for ever.
dead_subscriber_test_() ->
    {timeout, 10, fun() ->
        Never = fun() -> receive after infinity -> eof end end,
        ?assertEqual({fault, <<"deadlock">>},
                     ern_rt:run_main(
                       fun() ->
                           Tty = ern_rt:sys(terminal),
                           Child = ern_rt:spawn('Local', fun() -> subscribe(Tty) end, <<"c">>),
                           ern_rt:monitor(Child, fun(D) -> {down, D} end),
                           receive {down, _} -> ok end,
                           receive never -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end, keys => Never}))
    end}.

wait(Tag) ->
    receive {Tag, V} -> V after 2000 -> timeout end.

%% Report §8.2: `Subscribe` carries a reply, answered once the terminal is
%% in the mode the keys need.
%% report §8.2: the keys are UTF-8 whatever the host's locale, a
%% character cut across two reads is one key, and keys that are not UTF-8
%% end the program with its entry process's fault
utf8_keys_test() ->
    Me = self(),
    Tab = ets:new(chunks, [public]),
    ets:insert(Tab, {queue, [<<195>>, <<169>>]}),
    Cut = fun() ->
                  case ets:lookup(Tab, queue) of
                      [{_, [C | Rest]}] -> ets:insert(Tab, {queue, Rest}), C;
                      _ -> silent()
                  end
          end,
    ok = ern_rt:run_main(fun() ->
                                 subscribe(ern_rt:sys(terminal)),
                                 receive K -> Me ! {key, K} end
                         end, <<"main">>, #{stdout => fun(_) -> ok end, keys => Cut}),
    ?assertEqual({'Key', 16#e9}, wait(key)),
    ?assertEqual({fault, <<"the standard input is not UTF-8">>},
                 ern_rt:run_main(fun() ->
                                         subscribe(ern_rt:sys(terminal)),
                                         receive never -> ok end
                                 end, <<"main">>,
                                 #{stdout => fun(_) -> ok end, keys => fun() -> <<"a", 255>> end})).

%% A terminal at which nothing is typed, so that a test's keys are the ones
%% it sends the terminal's process itself.
silent() ->
    receive after infinity -> eof end.

subscribe(Tty) ->
    Me = ern_rt:self(),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Reply, Me} end, 5000).

%% report §8.2, Appendix E.16: a paste is one event and not the keys of its
%% characters, its line endings are line feeds whichever the terminal
%% sends, and what has arrived of a paste waits for the end the terminal
%% puts after it, however small the pieces the reader hands over
paste_test() ->
    ?assertEqual({[{'Pasted', <<"ab">>}], []}, ern_tty:decode("\e[200~ab\e[201~")),
    ?assertEqual({[{'Pasted', <<"a\nb">>}], []}, ern_tty:decode("\e[200~a\rb\e[201~")),
    ?assertEqual({[{'Pasted', <<"a\nb">>}], []}, ern_tty:decode("\e[200~a\r\nb\e[201~")),
    %% what follows a paste is read as keys again
    ?assertEqual({[{'Pasted', <<"x">>}, 'Enter'], []}, ern_tty:decode("\e[200~x\e[201~\r")),
    %% the reader reads a character at a time, so each piece waits
    Pending = lists:foldl(fun(C, Buffer) ->
                              {[], Left} = ern_tty:decode(Buffer ++ [C]),
                              Left
                          end, [], "\e[200~hi"),
    ?assertEqual("\e[200~hi", Pending),
    ?assertEqual({[{'Pasted', <<"hi">>}], []}, ern_tty:decode(Pending ++ "\e[201~")).
