%% Report §8.2, §9.3: the process behind Sys.keys. It answers Subscribe by
%% remembering the address, and sends every key pressed to each subscriber
%% as a Key of §9.3. The terminal is put in raw mode with echo off when the
%% first subscriber arrives, since keys and lines are the same terminal and
%% a program does one or the other, and restore/0 puts it back when the
%% program ends (§8.6).
%%
%% The mode is set with stty on a port that inherits the terminal, and not
%% with shell:start_interactive({noshell, raw}), which arrived after the
%% release this was written against. On OTP 29 that mode works, and it sets
%% -opost as well, so a line feed would no longer return the carriage; it
%% leaves isig on, which the shell needs off (§11.2). The decisions log of
%% 2026-09-20 has the measurements and what would make it worth taking.
%%
%% Decoding is decode/1 over the bytes read, and flush/1 for what is left
%% when nothing follows; both are functions and are what the unit tests
%% exercise. The reading itself is driven through a pseudo-terminal by
%% test/ern_terminal_tests.erl, since 2026-09-20.
-module(ern_keys).

-export([loop/0, decode/1, flush/1, restore/0]).

%% Report §8.2: Escape is delivered once no escape sequence can still
%% follow it. A terminal sends a sequence in one burst, so a pause this
%% long after an escape means the key itself.
-define(ESCAPE_PAUSE, 50).

-spec loop() -> no_return().
loop() ->
    loop([], undefined, []).

loop(Subscribers, Reader, Pending) ->
    Pause = case Pending of [] -> infinity; _ -> ?ESCAPE_PAUSE end,
    receive
        {'Subscribe', Address} ->
            case held_by_another(Address) of
                true ->
                    %% report §11.2: the terminal is the shell's
                    exit(ern_rt:process_of(Address),
                         {ern, fault, <<"the shell holds the terminal; run the program with ern "
                                        "to give it the keyboard">>}),
                    loop(Subscribers, Reader, Pending);
                false ->
                    loop([Address | Subscribers], start_reader(Reader), Pending)
            end;
        {chars, Chars} ->
            {Decoded, Left} = decode(Pending ++ Chars),
            deliver(Decoded, Subscribers),
            loop(Subscribers, Reader, Left)
    after Pause ->
        deliver(flush(Pending), Subscribers),
        loop(Subscribers, Reader, [])
    end.

deliver(Keys, Subscribers) ->
    lists:foreach(fun(Key) ->
                      lists:foreach(fun(To) -> ern_rt:send(To, Key) end, Subscribers)
                  end, Keys).

%% The reader runs once a program has asked for keys, and not before: a
%% program that reads lines never leaves the terminal's line mode.
start_reader(undefined) ->
    Keys = self(),
    case ern_rt:own_terminal(keys) of
        ok ->
            stty(["-icanon", "-echo", "min", "1", "time", "0" | interrupt_mode()]),
            %% report §8.6: a subscription is a source that can still deliver
            ern_rt:source_begin(),
            erlang:spawn(fun() -> read_loop(Keys) end);
        taken ->
            %% the program is already ending with the fault (report §8.2)
            undefined
    end;
start_reader(Reader) ->
    Reader.

%% Report §8.2: each key as it is pressed and no echo, which is the input
%% half only. Full raw mode would also stop the terminal turning a line feed
%% into a carriage return and a line feed, and a program that draws would
%% climb the screen a column at a time.
%% Report §11.2: the shell reads the terminal's interrupt as a key, so its
%% signal is turned off for the shell and for nobody else.
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

%% Report §9.3: Key = Char(Char) | ArrowUp | ArrowDown | ArrowLeft
%% | ArrowRight | Enter | Escape | Interrupt. An escape sequence that is not an arrow
%% is the Escape key and the characters after it.
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
