%% Report §8.2, §9.3: the process behind Sys.keys. It answers Subscribe by
%% remembering the address, and sends every key pressed to each subscriber
%% as a Key of §9.3. The terminal is put in raw mode with echo off when the
%% first subscriber arrives, since keys and lines are the same terminal and
%% a program does one or the other. Decoding is decode/1, a function over
%% the bytes read, which is what the tests exercise; the reading itself is
%% the terminal's and cannot be tested without one.
-module(ern_keys).

-export([loop/0, decode/1]).

-spec loop() -> no_return().
loop() ->
    loop([], undefined).

loop(Subscribers, Reader) ->
    receive
        {'Subscribe', Address} ->
            loop([Address | Subscribers], start_reader(Reader));
        {keys, Keys} ->
            lists:foreach(fun(Key) ->
                              lists:foreach(fun(To) -> ern_rt:send(To, Key) end, Subscribers)
                          end, Keys),
            loop(Subscribers, Reader)
    end.

%% The reader runs once a program has asked for keys, and not before: a
%% program that reads lines never leaves the terminal's line mode.
start_reader(undefined) ->
    Keys = self(),
    case ern_rt:own_terminal(keys) of
        ok ->
            raw_mode(),
            erlang:spawn(fun() -> read_loop(Keys, []) end);
        taken ->
            %% the program is already ending with the fault (report §8.2)
            undefined
    end;
start_reader(Reader) ->
    Reader.

raw_mode() ->
    catch shell:start_interactive({noshell, raw}),
    ok.

read_loop(Keys, Rest) ->
    case io:get_chars(standard_io, "", 1) of
        eof ->
            ok;
        {error, _} ->
            ok;
        Data ->
            {Decoded, Left} = decode(Rest ++ unicode:characters_to_list(Data)),
            case Decoded of
                [] -> ok;
                _ -> Keys ! {keys, Decoded}
            end,
            read_loop(Keys, Left)
    end.

%% Report §9.3: Key = Char(Char) | ArrowUp | ArrowDown | ArrowLeft
%% | ArrowRight | Enter | Escape. An escape sequence that is not an arrow
%% is the Escape key and the characters after it.
-spec decode([char()]) -> {[term()], [char()]}.
decode(Chars) ->
    decode(Chars, []).

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
decode([$\n | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([$\r | Rest], Acc) -> decode(Rest, ['Enter' | Acc]);
decode([C | Rest], Acc) -> decode(Rest, [{'Char', C} | Acc]).
