%% Report §8.2, §9.3: the process behind Sys.terminal. It answers
%% Subscribe by remembering the address, sends every key pressed to each
%% subscriber as an Event of §9.3, answers Size with the terminal's size,
%% and sends Resized when that size changes. The terminal is put in the
%% mode the keys need when the first subscriber arrives, since keys and
%% lines are the same terminal and a program does one or the other, and
%% restore/0 puts it back when the program ends (§8.6).
%%
%% The mode is the host's raw mode, shell:start_interactive({noshell,
%% raw}), with two flags put back by stty on a port that inherits the
%% terminal: opost, without which a line feed would no longer return the
%% carriage, and, for the shell alone, -isig, so that the interrupt is a
%% key (§11.2). Raw mode is also what makes the size askable, io:rows and
%% io:columns answering only while the host's terminal is in charge.
%%
%% A resize is noticed by asking, five times a second while anything is
%% subscribed: SIGWINCH is delivered through OTP's signal server, which is
%% reached by writing a gen_event handler, and this repository has no OTP
%% behaviours (docs/style.md).
%%
%% Decoding is decode/1 over the bytes read, and flush/1 for what is left
%% when nothing follows; both are functions and are what the unit tests
%% exercise. The reading itself is driven through a pseudo-terminal by
%% test/ern_terminal_tests.erl, since 2026-09-20; loop/1 takes the reading
%% as a function, read_char/0 but in a test, as the runtime's stdin does.
-module(ern_tty).

-export([loop/1, read_char/0, decode/1, flush/1, restore/0]).

%% Report §8.2: how often the terminal is asked for its size while a
%% program is subscribed, which is how a resize is noticed.
-define(RESIZE_PAUSE, 200).

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

%% Read answers the next characters, eof, or {error, Reason}.
-spec loop(fun(() -> eof | {error, term()} | unicode:chardata())) -> no_return().
loop(Read) ->
    loop([], {unstarted, Read}, [], none).

%% The next character the host's terminal gives.
-spec read_char() -> eof | {error, term()} | unicode:chardata().
read_char() ->
    io:get_chars(standard_io, "", 1).

loop(Subscribers, Reader, Pending, Size) ->
    Pause = pause(Subscribers, Pending),
    receive
        %% report §3.5: the fields are in canonical order, `reply` before `to`
        {'Subscribe', Reply, Address} ->
            case held_by_another(Address) of
                true ->
                    %% report §11.2: the terminal is the shell's
                    exit(ern_rt:process_of(Address), {ern, fault, ern_rt:shell_holds()}),
                    loop(Subscribers, Reader, Pending, Size);
                false ->
                    Reader1 = start_reader(Reader),
                    %% report §8.2: the mode is set before the caller goes
                    %% on, so that nothing it types then is echoed
                    ern_rt:answer(Reply, 'Unit'),
                    loop([Address | Subscribers], Reader1, Pending, size_now())
            end;
        {'Measure', Reply} ->
            ern_rt:answer(Reply, optional(size_now())),
            loop(Subscribers, Reader, Pending, Size);
        {chars, Chars} ->
            {Decoded, Left} = decode(Pending ++ Chars),
            deliver(Decoded, Subscribers),
            loop(Subscribers, Reader, Left, Size);
        closed ->
            %% report §8.6: at the end of input no key can come, so the
            %% subscription is no longer a source that can deliver
            ern_rt:source_end(),
            loop(Subscribers, closed, Pending, Size)
    after Pause ->
        %% report §8.2: a paste may take longer to arrive than an escape
        %% sequence, and what has come of it is not keys
        Left = case pasting(Pending) of
                   true -> Pending;
                   false -> deliver(flush(Pending), Subscribers), []
               end,
        %% report §8.2: a size that has changed is news to every subscriber
        case size_now() of
            Size -> loop(Subscribers, Reader, Left, Size);
            Now ->
                deliver([{'Resized', Now} || Now =/= none], Subscribers),
                loop(Subscribers, Reader, Left, Now)
        end
    end.

pasting(?PASTE_BEGIN ++ _) -> true;
pasting(_) -> false.

%% An escape alone may still grow into an arrow, and `\e[2` into the start
%% of a paste; `flush/1` is what ends the waiting when nothing follows.
growing(Chars) ->
    lists:prefix(Chars, "\e[") orelse lists:prefix(Chars, ?PASTE_BEGIN).

%% An escape waits only as long as a sequence may still follow it; a
%% subscriber's terminal is asked for its size between times.
pause([], []) -> infinity;
pause(_, []) -> ?RESIZE_PAUSE;
pause(_, Pending) ->
    case pasting(Pending) of
        true -> ?RESIZE_PAUSE;
        false -> ?ESCAPE_PAUSE
    end.

deliver(Events, Subscribers) ->
    lists:foreach(fun(Event) ->
                      lists:foreach(fun(To) -> ern_rt:send(To, Event) end, Subscribers)
                  end, Events).

%% Report §9.3: Size(rows, columns), which the host answers only while its
%% terminal is in charge, so before the first subscription there is none.
size_now() ->
    case {io:rows(), io:columns()} of
        {{ok, Rows}, {ok, Columns}} -> {'Size', Columns, Rows};
        _ -> none
    end.

optional(none) -> 'None';
optional(Size) -> {'Some', Size}.

%% The reader runs once a program has asked for keys, and not before: a
%% program that reads lines never leaves the terminal's line mode.
start_reader({unstarted, Read}) ->
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
            %% linked, so that the reader ends with the terminal's process
            %% at the program's end and takes no key meant for what follows
            erlang:spawn_link(fun() -> read_loop(Tty, Read) end);
        taken ->
            %% the program is already ending with the fault (report §8.2)
            {unstarted, Read}
    end;
start_reader(Reader) ->
    %% running, or `closed` at the end of input, which no reader reopens
    Reader.

%% Report §8.2: each key as it is pressed and no echo, and the host's
%% terminal in charge, which is what makes the size askable. The host's raw
%% mode also stops the terminal turning a line feed into a carriage return
%% and a line feed, and a program that draws would climb the screen a
%% column at a time, so `opost` goes back. A paste is asked to be
%% bracketed, so that pasted text is one `Pasted` and not the keys of its
%% characters; a terminal that does not know the request ignores it.
%% Report §11.2: the shell reads the terminal's interrupt as a key, so its
%% signal is turned off for the shell and for nobody else.
raw_mode() ->
    shell:start_interactive({noshell, raw}),
    stty(["opost" | interrupt_mode()]),
    write(?PASTE_ON).

interrupt_mode() ->
    case ern_rt:terminal_holder() of
        undefined -> [];
        _ -> ["-isig"]
    end.

held_by_another(Address) ->
    case ern_rt:terminal_holder() of
        undefined -> false;
        Holder -> ern_rt:process_of(Address) =/= Holder
    end.

%% Report §8.6: the terminal is the one the program found.
-spec restore() -> ok.
restore() ->
    write(?PASTE_OFF),
    stty(["sane"]).

%% Report §8.2: the terminal's own mode, written past the sinks a program's
%% output is bound to, since it is the terminal that is being spoken to.
write(Text) ->
    case terminal() of
        true -> io:put_chars(standard_io, Text);
        false -> ok
    end.

%% stty acts on its own standard input, and a port opened with nouse_stdio
%% inherits the runtime's, which is the terminal. Nothing is done when the
%% input is not one: keys read from a pipe need no mode, and a mode set
%% there would be set on whatever terminal the runtime was started from.
%% An stty that does not finish in time is closed, and what its port sent
%% is not left in the mailbox, where report §8.6 would read it as a message
%% still to be handled.
stty(Args) ->
    case terminal() andalso os:find_executable("stty") of
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

flush_port(Port) ->
    receive
        {Port, _} -> flush_port(Port)
    after 0 ->
        ok
    end.

terminal() ->
    try prim_tty:isatty(stdin) =:= true
    catch _:_ -> false
    end.

read_loop(Keys, Read) ->
    case Read() of
        eof -> Keys ! closed;
        {error, _} -> Keys ! closed;
        Data ->
            Keys ! {chars, unicode:characters_to_list(Data)},
            read_loop(Keys, Read)
    end.

%% Report §9.3: Event = Key(Char) | ArrowUp | ArrowDown | ArrowLeft
%% | ArrowRight | Enter | Escape | Interrupt | Resized(Size), one list of
%% what the terminal sent. An escape sequence that is none of those is the
%% Escape key and the characters after it, which is how Meta and Shift-Tab
%% reach a program (§8.2).
-spec decode([char()]) -> {[term()], [char()]}.
decode(Chars) ->
    decode(Chars, []).

%% Report §8.2: what is left when nothing followed it. An escape alone is
%% the Escape key, and a sequence that never grew into an arrow is the
%% Escape key and the characters after it.
-spec flush([char()]) -> [term()].
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
        more -> {lists:reverse(Acc), ?PASTE_BEGIN ++ Rest}
    end;
decode([$\e, $[, $A | Rest], Acc) -> decode(Rest, ['ArrowUp' | Acc]);
decode([$\e, $[, $B | Rest], Acc) -> decode(Rest, ['ArrowDown' | Acc]);
decode([$\e, $[, $C | Rest], Acc) -> decode(Rest, ['ArrowRight' | Acc]);
decode([$\e, $[, $D | Rest], Acc) -> decode(Rest, ['ArrowLeft' | Acc]);
decode([$\e | Rest] = Chars, Acc) ->
    %% what has arrived may still grow into a sequence the terminal is in
    %% the middle of sending, and the reader reads a character at a time
    case growing(Chars) of
        true -> {lists:reverse(Acc), Chars};
        false -> decode(Rest, ['Escape' | Acc])
    end;
decode([3 | Rest], Acc) -> decode(Rest, ['Interrupt' | Acc]);
decode([$\n | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([$\r | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([C | Rest], Acc) -> decode(Rest, [{'Key', C} | Acc]).

%% The text of a paste, up to the end the terminal puts after it. A
%% terminal sends the line endings of what was pasted, and a program is
%% given the text as Ernest writes it (report §2.5).
pasted(?PASTE_END ++ Rest, Text) ->
    {ok, unicode:characters_to_binary(lists:reverse(Text)), Rest};
pasted([$\r, $\n | Rest], Text) -> pasted(Rest, [$\n | Text]);
pasted([$\r | Rest], Text) -> pasted(Rest, [$\n | Text]);
pasted([C | Rest], Text) -> pasted(Rest, [C | Text]);
pasted([], _Text) -> more.
