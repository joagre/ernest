%% Report Appendix E.16: the keys, decoded from what a terminal sends. The
%% reading itself needs a terminal; the decoding does not.
-module(ern_tty_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix E.16, §8.2: a character, Enter's carriage return or line
%% feed among them, the arrows, and Escape
decode_test() ->
    ?assertEqual({[{'Key', $a}, {'Key', $b}], []}, ern_tty:decode("ab")),
    ?assertEqual({[{'Key', $\n}, {'Key', $\r}, {'Key', 127}, {'Key', $\t}], []},
                 ern_tty:decode("\n\r\x7f\t")),
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
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:system_process(terminal),
               %% report §8.2: the subscription is answered once the mode is set
               subscribe(Tty),
               %% as the reader sends them: the arrow whole, the escape alone
               Tty ! {chars, "\e[A"},
               receive Key1 -> Self ! {k1, Key1} end,
               Tty ! {chars, "\e"},
               receive Key2 -> Self ! {k2, Key2} end
           end, <<"main">>, #{stdout => fun(_) -> ok end, keys => fun silent/0}),
    ?assertEqual('ArrowUp', wait(k1)),
    ?assertEqual('Escape', wait(k2)).

%% report §8.2: a process holds one subscription, and a second replaces
%% the first, its wrap from then on. A regression test: each call added the
%% address again, and every key arrived once for each.
second_subscription_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:system_process(terminal),
               subscribe(Tty),
               Wrapped = ern_rt:via(ern_rt:self(), fun(Event) -> {again, Event} end),
               ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Wrapped, Reply} end, 5000),
               %% a key delivered twice would come before the second key
               Tty ! {chars, "a"},
               First = receive Message1 -> Message1 end,
               Tty ! {chars, "b"},
               Second = receive Message2 -> Message2 end,
               Self ! {got, [First, Second]}
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
                           Tty = ern_rt:system_process(terminal),
                           Child = ern_rt:spawn(fun() -> subscribe(Tty) end, <<"c">>),
                           ern_rt:monitor(Child, fun(Down) -> {down, Down} end),
                           receive {down, _} -> ok end,
                           receive never -> ok end
                       end, <<"main">>, #{stdout => fun(_) -> ok end, keys => Never}))
    end}.

wait(Tag) ->
    receive {Tag, Value} -> Value after 2000 -> timeout end.

%% report §8.2: the keys are UTF-8 whatever the host's locale, a
%% character cut across two reads is one key, and keys that are not UTF-8
%% end the program with its entry process's fault
utf8_keys_test() ->
    Self = self(),
    Tab = ets:new(chunks, [public]),
    ets:insert(Tab, {queue, [<<195>>, <<169>>]}),
    Cut = fun() ->
              case ets:lookup(Tab, queue) of
                  [{_, [Char | Rest]}] -> ets:insert(Tab, {queue, Rest}), Char;
                  _ -> silent()
              end
          end,
    ok = ern_rt:run_main(fun() ->
                             subscribe(ern_rt:system_process(terminal)),
                             receive Key -> Self ! {key, Key} end
                         end, <<"main">>, #{stdout => fun(_) -> ok end, keys => Cut}),
    ?assertEqual({'Key', 16#e9}, wait(key)),
    ?assertEqual({fault, <<"the standard input is not UTF-8">>},
                 ern_rt:run_main(fun() ->
                                     subscribe(ern_rt:system_process(terminal)),
                                     receive never -> ok end
                                 end, <<"main">>,
                                 #{stdout => fun(_) -> ok end, keys => fun() -> <<"a", 255>> end})).

%% report §8.2, Appendix E.16: where standard input is not a terminal a
%% subscription is refused with Left(NotATerminal) and claims nothing, so
%% a line can still be read, and the size is still asked of the output
not_a_terminal_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               %% the terminal's process as the runtime starts it where no
               %% keys can come
               Tty = erlang:spawn(fun() -> ern_tty:loop(fun silent/0, false) end),
               Subscribe = fun(Reply) -> {'Subscribe', Self, Reply} end,
               Self ! {answer, ern_rt:call_forever(Tty, Subscribe)},
               ReadLine = fun(Reply) -> {'ReadLine', Reply} end,
               Self ! {line, ern_rt:call_forever(ern_rt:system_process(stdin), ReadLine)},
               exit(Tty, kill)
           end, <<"main">>, #{stdout => fun(_) -> ok end, stdin => fun() -> "line\n" end}),
    ?assertEqual({'Left', 'NotATerminal'}, wait(answer)),
    ?assertEqual({'Some', <<"line">>}, wait(line)).

%% report §8.6, §8.2: at the end of input no key can come, so a program
%% that waits only for keys is in a deadlock and faults. A regression test:
%% the subscription went on counting as a source, and the program waited
%% for ever. It ran a program with its standard input closed until such an
%% input came to refuse the subscription; the keys here end instead
keys_at_end_of_input_test() ->
    ?assertEqual({fault, <<"deadlock">>},
                 ern_rt:run_main(fun() ->
                                     subscribe(ern_rt:system_process(terminal)),
                                     receive never -> ok end
                                 end, <<"main">>,
                                 #{stdout => fun(_) -> ok end, keys => fun() -> eof end})).

%% report §8.2: the terminal applies each subscriber's wrap itself, in
%% order, so a wrap that does not finish delays that subscriber's keys and
%% no other's
couriers_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:system_process(terminal),
               Main = self(),
               Endless = fun(Event) -> receive after infinity -> Event end end,
               Stuck = ern_rt:spawn(fun() ->
                                        subscribe(Tty, Endless),
                                        Main ! stuck_subscribed,
                                        receive never -> ok end
                                    end, <<"stuck">>),
               wait_atom(stuck_subscribed),
               subscribe(Tty, fun(Event) -> {key, Event} end),
               Tty ! {chars, "ab"},
               Keys = [receive {key, Key1} -> Key1 end, receive {key, Key2} -> Key2 end],
               Self ! {keys, Keys},
               ern_rt:kill(Stuck)
           end, <<"main">>, #{stdout => fun(_) -> ok end, keys => fun silent/0}),
    ?assertEqual([{'Key', $a}, {'Key', $b}], wait(keys)).

%% A terminal at which nothing is typed, so that a test's keys are the ones
%% it sends the terminal's process itself.
%% report §6.9, §8.2: a restart ends the process's subscription to the
%% terminal, so a key typed in the new run does not reach it. A regression
%% test: the subscription stood, and the key arrived
restart_ends_subscription_test() ->
    Self = self(),
    ok = ern_rt:run_main(
           fun() ->
               Tty = ern_rt:system_process(terminal),
               Main = erlang:self(),
               Restarted = fun() ->
                               case get(ran) of
                                   undefined ->
                                       put(ran, true),
                                       Self ! {subscribed, subscribe(Tty)},
                                       error(crash);
                                   true ->
                                       Tty ! {chars, "a"},
                                       ern_rt:timed(),
                                       Got = receive Key -> Key after 300 -> none end,
                                       ern_rt:untimed(),
                                       Main ! {got, Got}
                               end
                           end,
               _ = ern_rt:spawn(ern_rt:restarting({'RestartLimit', 1, 60000}, Restarted),
                                <<"worker">>),
               receive {got, Got} -> Self ! {got, Got} end
           end, <<"main">>,
           #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end, keys => fun silent/0}),
    %% the subscription was granted, so the key it no longer gets is the
    %% restart's doing; a regression test, the answer was not looked at
    ?assertEqual({'Some', {'Right', 'Unit'}}, wait(subscribed)),
    ?assertEqual(none, wait(got)).

%% A terminal's key reader that never reads a key.
silent() ->
    receive after infinity -> eof end.

%% Report §8.2: `Subscribe` carries a reply, answered once the terminal is
%% in the mode the keys need.
subscribe(Tty) ->
    Self = ern_rt:self(),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Self, Reply} end, 5000).

subscribe(Tty, Wrap) ->
    Address = ern_rt:via(ern_rt:self(), Wrap),
    ern_rt:call(Tty, fun(Reply) -> {'Subscribe', Address, Reply} end, 5000).

wait_atom(Atom) ->
    receive Atom -> Atom after 2000 -> error({no, Atom}) end.

%% report §8.2, Appendix E.16: a paste is one event and not the keys of its
%% characters, its line endings are line feeds whichever the terminal
%% sends, and what has arrived of a paste waits for the end the terminal
%% puts after it, however small the pieces the reader hands over
paste_test() ->
    ?assertEqual({[{'Pasted', <<"ab">>}], []}, ern_tty:decode("\e[200~ab\e[201~")),
    ?assertEqual({[{'Pasted', <<"a\nb">>}], []}, ern_tty:decode("\e[200~a\rb\e[201~")),
    ?assertEqual({[{'Pasted', <<"a\nb">>}], []}, ern_tty:decode("\e[200~a\r\nb\e[201~")),
    %% what follows a paste is read as keys again
    ?assertEqual({[{'Pasted', <<"x">>}, {'Key', $\r}], []}, ern_tty:decode("\e[200~x\e[201~\r")),
    %% a read may end anywhere in a paste, so each piece waits, and the
    %% paste is read on from where it stopped, a line ending and its end
    %% split between pieces among them
    Pending = lists:foldl(fun(Char, Buffer) ->
                              {[], Left} = ern_tty:more(Buffer, [Char]),
                              Left
                          end, [], "\e[200~h\r\ni\e[20"),
    ?assertEqual({[{'Pasted', <<"h\ni">>}, {'Key', $x}], []},
                 ern_tty:more(Pending, "1~x")),
    ?assertEqual([{'Pasted', <<"h\ni\e[20">>}], ern_tty:flush(Pending)).

%% report §8.2: a paste whose end does not come ends when no more of it
%% arrives, what came of it being the paste, and an end that comes after it
%% is nothing, a piece of it waiting as the whole of it would. A regression
%% test: the paste waited for its end for good, and took in every key after
%% it (findings C31)
unended_paste_test() ->
    ?assertEqual([{'Pasted', <<"hi">>}], ern_tty:flush("\e[200~hi")),
    ?assertEqual({[{'Key', $x}], []}, ern_tty:decode("\e[201~x")),
    ?assertEqual({[], "\e[201"}, ern_tty:decode("\e[201")).
