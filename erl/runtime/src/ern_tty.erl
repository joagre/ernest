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
%% test/ern_terminal_tests.erl, since 2026-09-20.
-module(ern_tty).

-export([loop/0, decode/1, flush/1, restore/0]).

%% Report §8.2: how often the terminal is asked for its size while a
%% program is subscribed, which is how a resize is noticed.
-define(RESIZE_PAUSE, 200).

%% Report §8.2: Escape is delivered once no escape sequence can still
%% follow it. A terminal sends a sequence in one burst, so a pause this
%% long after an escape means the key itself.
-define(ESCAPE_PAUSE, 50).

-spec loop() -> no_return().
loop() ->
    loop([], undefined, [], none).

loop(Subscribers, Reader, Pending, Size) ->
    Pause = pause(Subscribers, Pending),
    receive
        %% report §3.5: the fields are in canonical order, `reply` before `to`
        {'Subscribe', Reply, Address} ->
            case held_by_another(Address) of
                true ->
                    %% report §11.2: the terminal is the shell's
                    exit(ern_rt:process_of(Address),
                         {ern, fault, <<"the shell holds the terminal; run the program with ern "
                                        "to give it the keyboard">>}),
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
            loop(Subscribers, Reader, Left, Size)
    after Pause ->
        deliver(flush(Pending), Subscribers),
        %% report §8.2: a size that has changed is news to every subscriber
        case size_now() of
            Size -> loop(Subscribers, Reader, [], Size);
            Now ->
                deliver([{'Resized', Now} || Now =/= none], Subscribers),
                loop(Subscribers, Reader, [], Now)
        end
    end.

%% An escape waits only as long as a sequence may still follow it; a
%% subscriber's terminal is asked for its size between times.
pause([], []) -> infinity;
pause(_, []) -> ?RESIZE_PAUSE;
pause(_, _) -> ?ESCAPE_PAUSE.

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
start_reader(undefined) ->
    Tty = self(),
    case ern_rt:own_terminal(keys) of
        ok ->
            raw_mode(),
            %% report §8.6: a subscription is a source that can still deliver
            ern_rt:source_begin(),
            erlang:spawn(fun() -> read_loop(Tty) end);
        taken ->
            %% the program is already ending with the fault (report §8.2)
            undefined
    end;
start_reader(Reader) ->
    Reader.

%% Report §8.2: each key as it is pressed and no echo, and the host's
%% terminal in charge, which is what makes the size askable. The host's raw
%% mode also stops the terminal turning a line feed into a carriage return
%% and a line feed, and a program that draws would climb the screen a
%% column at a time, so `opost` goes back.
%% Report §11.2: the shell reads the terminal's interrupt as a key, so its
%% signal is turned off for the shell and for nobody else.
raw_mode() ->
    shell:start_interactive({noshell, raw}),
    stty(["opost" | interrupt_mode()]).

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
    stty(["sane"]).

%% stty acts on its own standard input, and a port opened with nouse_stdio
%% inherits the runtime's, which is the terminal. Nothing is done when the
%% input is not one: keys read from a pipe need no mode, and a mode set
%% there would be set on whatever terminal the runtime was started from.
stty(Args) ->
    case terminal() andalso os:find_executable("stty") of
        false ->
            ok;
        Stty ->
            Port = open_port({spawn_executable, Stty},
                             [{args, Args}, nouse_stdio, exit_status]),
            receive {Port, {exit_status, _}} -> ok after 2000 -> ok end
    end.

terminal() ->
    try prim_tty:isatty(stdin) =:= true
    catch _:_ -> false
    end.

read_loop(Keys) ->
    case io:get_chars(standard_io, "", 1) of
        eof -> ok;
        {error, _} -> ok;
        Data ->
            Keys ! {chars, unicode:characters_to_list(Data)},
            read_loop(Keys)
    end.

%% Report §9.3: Event = Char(Char) | ArrowUp | ArrowDown | ArrowLeft
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
decode([$\e], Acc) ->
    %% an escape alone may still grow into an arrow, so it waits
    {lists:reverse(Acc), [$\e]};
decode([$\e, $[], Acc) ->
    {lists:reverse(Acc), [$\e, $[]};
decode([$\e, $[, $A | Rest], Acc) -> decode(Rest, ['ArrowUp' | Acc]);
decode([$\e, $[, $B | Rest], Acc) -> decode(Rest, ['ArrowDown' | Acc]);
decode([$\e, $[, $C | Rest], Acc) -> decode(Rest, ['ArrowRight' | Acc]);
decode([$\e, $[, $D | Rest], Acc) -> decode(Rest, ['ArrowLeft' | Acc]);
decode([$\e | Rest], Acc) -> decode(Rest, ['Escape' | Acc]);
decode([3 | Rest], Acc) -> decode(Rest, ['Interrupt' | Acc]);
decode([$\n | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([$\r | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([C | Rest], Acc) -> decode(Rest, [{'Char', C} | Acc]).
