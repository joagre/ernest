%% The shims behind Json (report Appendix G.6). The host's `json` reads a
%% text into terms no Ernest type describes, and raises on a text it cannot
%% read, which Ernest cannot catch; so the host's functions are called here,
%% and their terms written as `Json.Value`'s.
-module(ern_json).

-export([parse/1, format/1]).

-type value() :: 'Null' | {'Boolean', boolean()} | {'Integer', integer()} | {'Real', float()}
               | {'Text', binary()} | {'Array', [value()]} | {'Object', #{binary() => value()}}.
-type position() :: {'Position', pos_integer(), pos_integer()}.
-type error() :: 'UnexpectedEnd' | {'UnexpectedByte', byte(), position()}
               | {'UnexpectedSequence', binary(), position()}.

%% Appendix G.6: the value the text writes, or the host's error and where.
%% `json:decode/3` raises the three errors its page lists, and calls the
%% decoders given to build each value, in the order of the text: a number,
%% null and an array or an object as it ends, and an element or a member's
%% value as it is pushed, which is where a string and a boolean, which have
%% no decoder, are seen. It answers the text left after the value, white
%% space among it, whose first other byte is an unexpected one.
%%
%% The host's raise carries the byte's or the sequence's offset in the
%% text as its error's position (position/1), from which the line and the
%% column are counted (at/2). A number the host cannot hold is the
%% decoder's own throw, with no offset, so the text is read for the number
%% (number_offset/2).
%%
%% An object keeps a name's last member, as `Map.fromList` keeps a later
%% pair (Appendix E.3): the members, pushed in front, are put back in the
%% text's order, and `maps:from_list/1` keeps a key's last. An integer
%% longer than the host holds, on which `binary_to_integer/1` raises
%% `system_limit`, is an unexpected sequence, as a real larger than a
%% `Float` is; and so is a high surrogate's escape that no low one's
%% follows, which the host answers otherwise (lone_surrogate/2).
-spec parse(binary()) -> {'Right', value()} | {'Left', error()}.
parse(Text) ->
    try json:decode(Text, ok, decoders()) of
        {Term, ok, Rest} ->
            case white_space(Rest) of
                <<>> ->
                    {'Right', value(Term)};
                <<Byte, _/binary>> = After ->
                    {'Left', {'UnexpectedByte', Byte, at(Text, byte_size(Text) - byte_size(After))}}
            end
    catch
        throw:{too_long, Digits} ->
            {'Left', {'UnexpectedSequence', Digits, at(Text, number_offset(Text, Digits))}};
        error:unexpected_end ->
            {'Left', lone_surrogate(Text, 'UnexpectedEnd')};
        error:{invalid_byte, Byte}:Trace ->
            Offset = position(Trace),
            {'Left', lone_surrogate(Text, {'UnexpectedByte', Byte, at(Text, Offset)}, Offset)};
        error:{unexpected_sequence, Bytes}:Trace ->
            {'Left', {'UnexpectedSequence', Bytes, at(Text, position(Trace))}}
    end.

%% The text after its JSON white space.
white_space(<<Byte, Rest/binary>>) when Byte =:= $\s; Byte =:= $\t; Byte =:= $\n; Byte =:= $\r ->
    white_space(Rest);
white_space(Rest) ->
    Rest.

%% The line and the column the byte at Offset begins, counted as a
%% diagnostic's are (§11.5): from 1, a line ending at a line feed and a
%% column a code point.
at(Text, Offset) ->
    Lines = binary:split(binary:part(Text, 0, Offset), <<"\n">>, [global]),
    {'Position', length(Lines), 1 + length(unicode:characters_to_list(lists:last(Lines)))}.

%% The offset of the number Digits writes: its first occurrence outside a
%% string, since an earlier number holding the digits would be as long and
%% would have been thrown on first.
number_offset(Text, Digits) ->
    number_offset(Text, Digits, byte_size(Digits), 0, false).

number_offset(<<$\\, _, Rest/binary>>, Digits, Size, Offset, true) ->
    number_offset(Rest, Digits, Size, Offset + 2, true);
number_offset(<<$", Rest/binary>>, Digits, Size, Offset, InString) ->
    number_offset(Rest, Digits, Size, Offset + 1, not InString);
number_offset(<<_, Rest/binary>> = Text, Digits, Size, Offset, false) ->
    case Text of
        <<Digits:Size/binary, _/binary>> -> Offset;
        _ -> number_offset(Rest, Digits, Size, Offset + 1, false)
    end;
number_offset(<<_, Rest/binary>>, Digits, Size, Offset, true) ->
    number_offset(Rest, Digits, Size, Offset + 1, true).

decoders() ->
    #{array_push => fun(Element, Acc) -> [value(Element) | Acc] end,
      array_finish => fun(Acc, OldAcc) -> {{'Array', lists:reverse(Acc)}, OldAcc} end,
      object_push => fun(Name, Member, Acc) -> [{Name, value(Member)} | Acc] end,
      object_finish => fun(Acc, OldAcc) ->
                           {{'Object', maps:from_list(lists:reverse(Acc))}, OldAcc}
                       end,
      integer => fun integer/1,
      float => fun(Digits) -> {'Real', binary_to_float(Digits)} end,
      null => 'Null'}.

integer(Digits) ->
    try {'Integer', binary_to_integer(Digits)}
    catch error:system_limit -> throw({too_long, Digits})
    end.

%% The offset of the byte or the sequence the host's decoder could not
%% read, which its raise carries as the error's position.
position([{_, _, _, Info} | _]) ->
    maps:get(position, maps:get(cause, proplists:get_value(error_info, Info))).

%% Appendix G.6: an escape of a high surrogate that no low one's follows
%% writes no character, UnexpectedSequence of its six bytes, as the host
%% answers a lone low surrogate. The host instead answers it as the text's
%% end where fewer than an escape's bytes follow it, and as the byte after
%% it where more do; so where the host answers either, the text is read for
%% such an escape, string by string and an escape by its bytes, and the
%% host's answer stands where there is none, or where the byte the host
%% names is not the one after it.
lone_surrogate(Text, Found) ->
    case lone_escape(Text, 0) of
        {Escape, After} -> {'UnexpectedSequence', Escape, at(Text, After - byte_size(Escape))};
        none -> Found
    end.

lone_surrogate(Text, Found, Offset) ->
    case lone_escape(Text, 0) of
        {Escape, Offset} -> {'UnexpectedSequence', Escape, at(Text, Offset - byte_size(Escape))};
        _ -> Found
    end.

%% The first lone high surrogate's escape outside, and the offset of the
%% byte after it, or none.
lone_escape(<<$", Rest/binary>>, Offset) -> in_string(Rest, Offset + 1);
lone_escape(<<_, Rest/binary>>, Offset) -> lone_escape(Rest, Offset + 1);
lone_escape(<<>>, _) -> none.

in_string(<<$", Rest/binary>>, Offset) ->
    lone_escape(Rest, Offset + 1);
in_string(<<"\\u", Hex:4/binary, Rest/binary>>, Offset) ->
    case {surrogate(Hex), Rest} of
        {high, <<"\\u", Low:4/binary, After/binary>>} ->
            case surrogate(Low) of
                low -> in_string(After, Offset + 12);
                _ -> in_string(Rest, Offset + 6)
            end;
        {high, _} ->
            case is_escape_begun(Rest) of
                true -> none;
                false -> {<<"\\u", Hex/binary>>, Offset + 6}
            end;
        _ ->
            in_string(Rest, Offset + 6)
    end;
in_string(<<$\\, _, Rest/binary>>, Offset) ->
    in_string(Rest, Offset + 2);
in_string(<<_, Rest/binary>>, Offset) ->
    in_string(Rest, Offset + 1);
in_string(<<>>, _) ->
    none.

%% Whether the text ends inside an escape a low surrogate's could be.
is_escape_begun(<<>>) -> true;
is_escape_begun(<<"\\">>) -> true;
is_escape_begun(<<"\\u", Part/binary>>) -> byte_size(Part) < 4;
is_escape_begun(_) -> false.

%% Four hexadecimal digits as a high or a low surrogate, or neither.
surrogate(Hex) ->
    try binary_to_integer(Hex, 16) of
        Unit when Unit >= 16#D800, Unit =< 16#DBFF -> high;
        Unit when Unit >= 16#DC00, Unit =< 16#DFFF -> low;
        _ -> neither
    catch
        error:badarg -> neither
    end.

%% A string and a boolean as `Json.Value`'s; every other value a decoder
%% built already is one.
value(Text) when is_binary(Text) -> {'Text', Text};
value(Bool) when is_boolean(Bool) -> {'Boolean', Bool};
value(Value) -> Value.

%% Appendix G.6: the value laid out by `json:format/3`, which calls the
%% encoder given on every value it holds and on every member's name, and
%% lays out an array by the host's terms it holds, so it is given those; an
%% object's members in the order of their names, which its page leaves to
%% the program.
-spec format(value()) -> binary().
format(Value) ->
    iolist_to_binary(json:format(term(Value), fun formatted/3, #{})).

term('Null') -> null;
term({'Array', Values}) -> [term(Value) || Value <- Values];
term({'Object', Map}) -> maps:map(fun(_, Member) -> term(Member) end, Map);
term({_, Value}) -> Value.

formatted(Map, Encode, State) when is_map(Map) ->
    json:format_key_value_list(lists:keysort(1, maps:to_list(Map)), Encode, State);
formatted(Term, Encode, State) -> json:format_value(Term, Encode, State).
