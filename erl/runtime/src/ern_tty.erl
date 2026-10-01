%% Report §8.2, Appendix E.16: the process behind Terminal's reference. It
%% answers Subscribe with Left(NotATerminal) where standard input is not a
%% terminal, claiming nothing, and otherwise by remembering the address;
%% it sends every key pressed to each subscriber as a Terminal.Event,
%% through a courier of the subscriber's own that applies its wrap, answers
%% Measure with the terminal's size, and sends Resized when that size changes.
%% The terminal is put in the mode the keys need when the first subscriber
%% arrives, since keys and lines are the same terminal and a program does
%% one or the other, and restore/0 puts it back when the program ends
%% (§8.6).
%%
%% The mode is stty's raw mode on a port that inherits the terminal, with
%% opost put back, without which a line feed would no longer return the
%% carriage. Raw mode turns the interrupt's signal off, so that the
%% interrupt arrives as a key, Interrupt, to every subscriber.
%%
%% A resize arrives as SIGWINCH, which OTP's signal server hands to
%% ern_tty_signal, installed with the first subscription; the size is
%% then asked for once.
%%
%% Decoding is decode/1 over the bytes read, and flush/1 for what is left
%% when nothing follows; both are functions and are what the unit tests
%% exercise. The reading itself is driven through a pseudo-terminal by
%% test/ern_terminal_tests.erl, since 2026-09-20; loop/2 takes the input
%% as ern_rt's stdin does, the host's standard input but in a test, and
%% whether keys can come, which a test's keys say they can.
-module(ern_tty).

-export([loop/2, restore/0, is_terminal/1, more/2, decode/1, flush/1]).

%% What waits for more to arrive: the characters of an escape that may
%% still grow into a sequence, or a paste under way, its text so far
%% reversed and a tail that may still grow into its end.
-type pending() :: [char()] | {paste, [char()], [char()]}.

%% Report §8.2: how long a paste may take to arrive whole.
-define(PASTE_PAUSE, 200).

%% Report §8.2: Escape is delivered once no escape sequence can still
%% follow it. A terminal sends a sequence in one burst, so a pause this
%% long after an escape means the key itself.
-define(ESCAPE_PAUSE, 50).

%% Report §8.2: bracketed paste. The terminal is asked for it while a
%% program is subscribed, and wraps pasted text in these.
-define(PASTE_ON, "\e[?2004h").
-define(PASTE_OFF, "\e[?2004l").
-define(PASTE_BEGIN, "\e[200~").
-define(PASTE_END, "\e[201~").

%% Open is the input, which ern_rt:read_input/1 reads; Keys says whether
%% keys can come, standard input being a terminal.
-spec loop(fun(() -> port() | pid()), boolean()) -> no_return().
loop(Open, true) ->
    loop([], {unstarted, Open}, [], none);
loop(_, false) ->
    refusing().

%% Report §8.2: where standard input is not a terminal, a subscription is
%% refused and claims nothing, and the size is asked of standard output.
refusing() ->
    receive
        {'Subscribe', Reply, Address} ->
            case held_by_another(Address) of
                true -> exit(ern_rt:process_of(Address), {ern, fault, ern_rt:shell_holds()});
                false -> ern_rt:answer(Reply, {'Left', 'NotATerminal'})
            end;
        {'Measure', Reply} ->
            ern_rt:answer(Reply, measured(size_now()));
        {new_run, Pid, Ref} ->
            %% report §6.9: where nothing is subscribed, a restart ends nothing
            Pid ! {Ref, fresh}
    end,
    refusing().

loop(Subscribers, Reader, Pending, Size) ->
    Pause = pause(Pending),
    receive
        %% report §3.5: the fields are in canonical order, `reply` before `to`
        {'Subscribe', Reply, Address} ->
            case held_by_another(Address) of
                true ->
                    %% report §11.2: the terminal is the shell's
                    exit(ern_rt:process_of(Address), {ern, fault, ern_rt:shell_holds()}),
                    loop(Subscribers, Reader, Pending, Size);
                false ->
                    case start_reader(Reader) of
                        {ok, Reader1} ->
                            %% report §8.2: the mode is set before the caller
                            %% goes on, so that nothing it types then is echoed
                            ern_rt:answer(Reply, {'Right', 'Unit'}),
                            loop(subscribe(Address, Subscribers, Reader, Reader1), Reader1,
                                 Pending, size_now());
                        {taken, Cause} ->
                            %% report §8.2: the terminal is read as lines
                            ern_rt:refuse(Reply, Cause),
                            loop(Subscribers, Reader, Pending, Size)
                    end
            end;
        {'DOWN', _, process, Pid, _} ->
            %% report §8.2: a subscription ends when its process dies
            loop(unsubscribe(Pid, Subscribers, Reader), Reader, Pending, Size);
        {new_run, Pid, Ref} ->
            %% report §6.9: and when it restarts, with the keys on their way
            Left = unsubscribe(Pid, Subscribers, Reader),
            Pid ! {Ref, fresh},
            loop(Left, Reader, Pending, Size);
        {'Measure', Reply} ->
            ern_rt:answer(Reply, measured(size_now())),
            loop(Subscribers, Reader, Pending, Size);
        {chars, Chars} ->
            {Decoded, Left} = more(Pending, Chars),
            deliver(Decoded, Subscribers),
            loop(Subscribers, Reader, Left, Size);
        closed ->
            %% report §8.6: at the end of input no key can come, so the
            %% subscription is no longer a source that can deliver
            Subscribers =/= [] andalso ern_rt:source_end(),
            loop(Subscribers, closed, Pending, Size);
        resized ->
            %% report §8.2: a size that has changed is news to every subscriber
            case size_now() of
                Size -> loop(Subscribers, Reader, Pending, Size);
                Now ->
                    deliver([{'Resized', Now} || Now =/= none], Subscribers),
                    loop(Subscribers, Reader, Pending, Now)
            end
    after Pause ->
        %% report §8.2: a paste may take longer to arrive than an escape
        %% sequence, and one whose end has not come ends when no more of it
        %% arrives, what came of it being the paste
        deliver(flush(Pending), Subscribers),
        loop(Subscribers, Reader, [], Size)
    end.

pasting({paste, _, _}) -> true;
pasting(_) -> false.

%% An escape alone may still grow into an arrow, and `\e[2` into the start
%% of a paste; `flush/1` is what ends the waiting when nothing follows.
growing(Chars) ->
    lists:prefix(Chars, "\e[") orelse lists:prefix(Chars, ?PASTE_BEGIN)
        orelse lists:prefix(Chars, ?PASTE_END).

%% An escape waits only as long as a sequence may still follow it, and a
%% paste as long as the rest of it may take to arrive.
pause([]) -> infinity;
pause(Pending) ->
    case pasting(Pending) of
        true -> ?PASTE_PAUSE;
        false -> ?ESCAPE_PAUSE
    end.

deliver([], _) ->
    ok;
deliver(Events, Subscribers) ->
    lists:foreach(fun({_, Courier, _}) -> Courier ! {events, Events} end, Subscribers).

%% Report §8.2: one subscriber's keys, in order, its wrap applied here, so
%% that a wrap that does not finish delays that subscriber's keys and no
%% other's; a fault in the wrap is the subscriber's (§6.5). Linked to the
%% terminal's process, so that it ends with it.
courier(Address) ->
    receive
        {to, Next} ->
            courier(Next);
        {events, Events} ->
            lists:foreach(fun(Event) -> ern_rt:send(Address, Event) end, Events),
            courier(Address)
    end.

%% Report §8.2: a process holds one subscription, the latest, keyed by the
%% process behind its address and watched so that it ends with it. Report
%% §8.6: the keys are a source while someone would receive them, counted
%% once while any subscription holds: for the first by start_reader/1, and
%% here for a subscription that comes back after all had ended.
subscribe(Address, Subscribers, Before, After) ->
    Pid = ern_rt:process_of(Address),
    case lists:keyfind(Pid, 1, Subscribers) of
        {Pid, Courier, _} ->
            Courier ! {to, Address},
            Subscribers;
        false ->
            Watch = erlang:monitor(process, Pid),
            Subscribers =:= [] andalso running(Before) andalso After =/= closed
                andalso ern_rt:source_begin(),
            [{Pid, erlang:spawn_link(fun() -> courier(Address) end), Watch} | Subscribers]
    end.

%% The subscription of Pid, its courier ended and waited for, so that no
%% key it carried arrives after, and its watch of Pid with it.
unsubscribe(Pid, Subscribers, Reader) ->
    case lists:keyfind(Pid, 1, Subscribers) of
        {Pid, Courier, Watch} ->
            erlang:demonitor(Watch, [flush]),
            Ended = erlang:monitor(process, Courier),
            erlang:unlink(Courier),
            exit(Courier, kill),
            receive {'DOWN', Ended, process, Courier, _} -> ok end;
        false ->
            ok
    end,
    Left = lists:keydelete(Pid, 1, Subscribers),
    Left =:= [] andalso Subscribers =/= [] andalso Reader =/= closed
        andalso ern_rt:source_end(),
    Left.

running({unstarted, _}) -> false;
running(closed) -> false;
running(_) -> true.

%% Report Appendix E.16: Size(rows, columns), or None where standard output
%% is not a terminal. It is the host's terminal's, `user`, whatever device
%% the job writes to.
size_now() ->
    case {io:rows(user), io:columns(user)} of
        {{ok, Rows}, {ok, Columns}} -> {'Size', Columns, Rows};
        _ -> none
    end.

%% Report Appendix E.16: the host has no size for a device that is not a
%% terminal, and that is the one cause.
measured(none) -> {'Left', 'NotATerminal'};
measured(Size) -> {'Right', Size}.

%% The reader runs once a program has asked for keys, and not before: a
%% program that reads lines never leaves the terminal's line mode, and a
%% subscription after a line was read is refused with the cause.
start_reader({unstarted, Open}) ->
    Tty = self(),
    case ern_rt:own_terminal(keys) of
        ok ->
            %% report §8.6: a subscription is a source that can still
            %% deliver, and it is counted before the mode is set rather
            %% than after: setting the mode runs `stty`, and while this
            %% process waits for it, it is waiting with an empty mailbox
            %% and would be read as quiet, though the answer to Subscribe
            %% is a computation whose completion delivers a message
            ern_rt:source_begin(),
            raw_mode(),
            %% one handler, this run's, which restore/0 removes
            _ = gen_event:delete_handler(erl_signal_server, ern_tty_signal, stop),
            ok = gen_event:add_handler(erl_signal_server, ern_tty_signal, Tty),
            %% linked, so that the reader ends with the terminal's process
            %% at the program's end and takes no key meant for what follows
            {ok, erlang:spawn_link(fun() -> read_loop(Tty, Open) end)};
        {taken, Cause} ->
            {taken, Cause}
    end;
start_reader(Reader) ->
    %% running, or `closed` at the end of input, which no reader reopens
    {ok, Reader}.

%% Report §8.2: each key as it is pressed and no echo. The mode is set by
%% stty on the terminal itself, since the runtime reads standard input
%% through its own port and the host's io server must not take it back.
%% Raw mode also stops the terminal turning a line feed into a carriage
%% return and a line feed, and a program that draws would climb the screen
%% a column at a time, so `opost` goes back. A paste is asked to be
%% bracketed, so that pasted text is one `Pasted` and not the keys of its
%% characters; a terminal that does not know the request ignores it.
%% Report §8.2: while the terminal is claimed for keys, its interrupt is
%% delivered to every subscriber as `Interrupt`, so raw mode's `-isig`
%% stays. A regression: the signal was turned back on but for the shell.
%% Report §8.6: the terminal's settings are kept first, so that the end
%% gives back the ones the program found; where they cannot be read, the
%% mode is left as it is, since it could not be given back.
raw_mode() ->
    case settings() of
        none ->
            ok;
        Found ->
            persistent_term:put({?MODULE, found}, Found),
            stty(["raw", "-echo", "opost"])
    end,
    write(?PASTE_ON).

held_by_another(Address) ->
    case ern_rt:terminal_holder() of
        undefined -> false;
        Holder -> ern_rt:process_of(Address) =/= Holder
    end.

%% Report §8.6: the terminal is the one the program found.
-spec restore() -> ok.
restore() ->
    _ = gen_event:delete_handler(erl_signal_server, ern_tty_signal, stop),
    write(?PASTE_OFF),
    case persistent_term:get({?MODULE, found}, none) of
        none ->
            ok;
        Found ->
            stty([Found]),
            _ = persistent_term:erase({?MODULE, found}),
            ok
    end.

%% Report §8.2: the terminal's own mode, written past the sinks a program's
%% output is bound to, since it is the terminal that is being spoken to.
write(Text) ->
    case terminal() of
        true -> file:write(standard_io, unicode:characters_to_binary(Text));
        false -> ok
    end.

system_stty() ->
    case [P || P <- ["/bin/stty", "/usr/bin/stty"], filelib:is_regular(P)] of
        [P | _] -> P;
        [] -> false
    end.

%% stty acts on its own standard input, and a port opened with nouse_stdio
%% inherits the runtime's, which is the terminal. Nothing is done when the
%% input is not one: keys read from a pipe need no mode, and a mode set
%% there would be set on whatever terminal the runtime was started from.
%% An stty that does not finish in time is closed, and what its port sent
%% is not left in the mailbox, where report §8.6 would read it as a message
%% still to be handled. It is the system's own stty, not the first that
%% PATH names, which could be any program in any directory the PATH lists.
stty(Args) ->
    case terminal() andalso system_stty() of
        false ->
            ok;
        Stty ->
            Port = open_port({spawn_executable, Stty},
                             [{args, Args}, nouse_stdio, exit_status]),
            receive
                {Port, {exit_status, _}} -> ok
            after 2000 ->
                %% the port may have closed since, which is the same
                try port_close(Port) catch error:badarg -> true end,
                flush_port(Port)
            end
    end.

%% The terminal's settings as `stty -g` writes them, one word that stty
%% takes back, or none. stty reads the terminal on the standard input its
%% shell inherits, and writes to the port's descriptor 4, which a port
%% opened with nouse_stdio reads.
settings() ->
    case terminal() andalso os:find_executable("sh") =/= false
        andalso os:find_executable("stty") =/= false of
        false ->
            none;
        true ->
            Port = open_port({spawn_executable, os:find_executable("sh")},
                             [{args, ["-c", "stty -g >&4"]}, nouse_stdio, exit_status,
                              binary]),
            settings(Port, [])
    end.

settings(Port, Acc) ->
    receive
        {Port, {data, Bytes}} ->
            settings(Port, [Acc, Bytes]);
        {Port, {exit_status, 0}} ->
            case string:trim(binary_to_list(iolist_to_binary(Acc))) of
                "" -> none;
                Found -> Found
            end;
        {Port, {exit_status, _}} ->
            none
    after 2000 ->
        try port_close(Port) catch error:badarg -> true end,
        flush_port(Port),
        none
    end.

flush_port(Port) ->
    receive
        {Port, _} -> flush_port(Port)
    after 0 ->
        ok
    end.

terminal() ->
    is_terminal(stdin).

%% Whether the stream is a terminal, as the host's io server of the
%% standard streams, `user`, reports it (the `stdin` and `stdout` options of
%% io:getopts/1), whatever device the job writes to.
-spec is_terminal(stdin | stdout | stderr) -> boolean().
is_terminal(Stream) ->
    try proplists:get_value(Stream, io:getopts(user), false) =:= true
    catch _:_ -> false
    end.

%% Report §8.2: the keys are UTF-8, whatever the host's locale; a
%% character may arrive in two reads, and bytes that are not UTF-8 end the
%% program. The reader traps exits, so that its input's failure is the end
%% of the keys, and the terminal's process ending is its own end.
read_loop(Keys, Open) ->
    erlang:process_flag(trap_exit, true),
    read_loop(Keys, Open, <<>>).

read_loop(Keys, Open, Partial) ->
    case ern_rt:read_input(Open) of
        {data, Bin} ->
            case unicode:characters_to_list(<<Partial/binary, Bin/binary>>, utf8) of
                Chars when is_list(Chars) ->
                    keys(Keys, Chars),
                    read_loop(Keys, Open, <<>>);
                {incomplete, Chars, Rest} ->
                    keys(Keys, Chars),
                    read_loop(Keys, Open, Rest);
                {error, Chars, _} ->
                    keys(Keys, Chars),
                    ern_rt:input_not_utf8(),
                    Keys ! closed
            end;
        eof -> Keys ! closed;
        {error, _} -> Keys ! closed
    end.

keys(_, []) -> ok;
keys(Keys, Chars) -> Keys ! {chars, Chars}.

%% What has arrived after what was pending. A paste under way is read on
%% from where it stopped, so that each of its characters is read once
%% however many pieces it comes in; anything else is decoded with the
%% escape that was pending before it. A regression: a paste was read again
%% from its start at every piece, a cost that grew as its square.
-spec more(pending(), [char()]) -> {[term()], pending()}.
more({paste, Text, Tail}, Chars) ->
    case pasted(Tail ++ Chars, Text) of
        {ok, Pasted, After} ->
            {Events, Left} = decode(After),
            {[{'Pasted', Pasted} | Events], Left};
        {more, Text1, Tail1} ->
            {[], {paste, Text1, Tail1}}
    end;
more(Pending, Chars) ->
    decode(Pending ++ Chars).

%% Report Appendix E.16: Event = Key(Char) | ArrowUp | ArrowDown | ArrowLeft
%% | ArrowRight | Escape | Interrupt | Resized(Size), one list of what the
%% terminal sent; a key of one character is Key of it, Enter's carriage
%% return among them (report §8.2). An escape sequence that is none of those is the
%% Escape key and the characters after it, which is how Meta and Shift-Tab
%% reach a program (§8.2).
-spec decode([char()]) -> {[term()], pending()}.
decode(Chars) ->
    decode(Chars, []).

%% Report §8.2: what is left when nothing followed it. An escape alone is
%% the Escape key, and a sequence that never grew into an arrow is the
%% Escape key and the characters after it.
-spec flush(pending()) -> [term()].
flush({paste, Text, Tail}) ->
    %% report §8.2: a paste whose end did not come, what it held back as
    %% the start of an end being its text too
    [{'Pasted', unicode:characters_to_binary(lists:reverse(Text, [line_feed(C) || C <- Tail]))}];
flush(?PASTE_BEGIN ++ _ = Chars) ->
    {Events, Left} = decode(Chars),
    Events ++ flush(Left);
flush([$\e | Rest]) ->
    {Keys, _} = decode(Rest),
    ['Escape' | Keys];
flush(Chars) ->
    {Keys, _} = decode(Chars),
    Keys.

decode([], Acc) ->
    {lists:reverse(Acc), []};

%% report §8.2: a paste is one event, and its line endings are line feeds
decode(?PASTE_BEGIN ++ Rest, Acc) ->
    case pasted(Rest, []) of
        {ok, Text, After} -> decode(After, [{'Pasted', Text} | Acc]);
        {more, Text, Tail} -> {lists:reverse(Acc), {paste, Text, Tail}}
    end;
%% report §8.2: the end of a paste that had already ended is nothing
decode(?PASTE_END ++ Rest, Acc) ->
    decode(Rest, Acc);
decode([$\e, $[, $A | Rest], Acc) -> decode(Rest, ['ArrowUp' | Acc]);
decode([$\e, $[, $B | Rest], Acc) -> decode(Rest, ['ArrowDown' | Acc]);
decode([$\e, $[, $C | Rest], Acc) -> decode(Rest, ['ArrowRight' | Acc]);
decode([$\e, $[, $D | Rest], Acc) -> decode(Rest, ['ArrowLeft' | Acc]);
decode([$\e | Rest] = Chars, Acc) ->
    %% what has arrived may still grow into a sequence the terminal is in
    %% the middle of sending, and a read may end anywhere in it
    case growing(Chars) of
        true -> {lists:reverse(Acc), Chars};
        false -> decode(Rest, ['Escape' | Acc])
    end;
decode([3 | Rest], Acc) -> decode(Rest, ['Interrupt' | Acc]);
decode([C | Rest], Acc) -> decode(Rest, [{'Key', C} | Acc]).

%% The text of a paste, up to the end the terminal puts after it, from its
%% text so far, reversed, and what has arrived since. A terminal sends the
%% line endings of what was pasted, and a program is given the text as
%% Ernest writes it (report §2.5). What may still grow into the end, or a
%% carriage return a line feed may follow, is held back as the tail.
pasted(?PASTE_END ++ Rest, Text) ->
    {ok, unicode:characters_to_binary(lists:reverse(Text)), Rest};
pasted([$\r, $\n | Rest], Text) -> pasted(Rest, [$\n | Text]);
pasted([$\r], Text) -> {more, Text, [$\r]};
pasted([$\r | Rest], Text) -> pasted(Rest, [$\n | Text]);
pasted([$\e | Rest] = Chars, Text) ->
    case lists:prefix(Chars, ?PASTE_END) of
        true -> {more, Text, Chars};
        false -> pasted(Rest, [$\e | Text])
    end;
pasted([C | Rest], Text) -> pasted(Rest, [C | Text]);
pasted([], Text) -> {more, Text, []}.

line_feed($\r) -> $\n;
line_feed(C) -> C.
