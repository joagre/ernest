%% The shims behind Json (report Appendix G.6). The host's `json` reads a
%% text into terms no Ernest type describes, and raises on a text it cannot
%% read, which Ernest cannot catch; so the host's functions are called here,
%% and their terms written as `Json.Value`'s.
-module(ern_json).

-export([parse/1, format/1]).

-type value() :: 'Null' | {'Boolean', boolean()} | {'Integer', integer()} | {'Real', float()}
               | {'Text', binary()} | {'Array', [value()]} | {'Object', #{binary() => value()}}.
-type error() :: 'UnexpectedEnd' | {'UnexpectedByte', byte()} | {'UnexpectedSequence', binary()}.

%% Appendix G.6: the value the text writes, or the host's error.
%% `json:decode/3` raises the three errors its page lists, and calls the
%% decoders given to build each value, in the order of the text: a number,
%% null and an array or an object as it ends, and an element or a member's
%% value as it is pushed, which is where a string and a boolean, which have
%% no decoder, are seen. It answers the text left after the value, which
%% `json:decode/1` refuses as an invalid byte, its first. An object keeps a
%% name's first member, the last in the list `maps:from_list/1` is given.
%% An integer longer than the host holds, on which `binary_to_integer/1`
%% raises `system_limit`, is an unexpected sequence, as a real larger than
%% a `Float` is; and so is a high surrogate's escape that no low one's
%% follows, which the host answers otherwise (lone_surrogate/2).
-spec parse(binary()) -> {'Right', value()} | {'Left', error()}.
parse(Text) ->
    try json:decode(Text, ok, decoders()) of
        {Term, ok, <<>>} -> {'Right', value(Term)};
        {_, ok, <<Byte, _/binary>>} -> {'Left', {'UnexpectedByte', Byte}}
    catch
        throw:{too_long, Digits} ->
            {'Left', {'UnexpectedSequence', Digits}};
        error:unexpected_end ->
            {'Left', lone_surrogate(Text, 'UnexpectedEnd')};
        error:{invalid_byte, Byte}:Trace ->
            {'Left', lone_surrogate(Text, {'UnexpectedByte', Byte}, position(Trace))};
        error:{unexpected_sequence, Bytes} ->
            {'Left', {'UnexpectedSequence', Bytes}}
    end.

decoders() ->
    #{array_push => fun(Element, Acc) -> [value(Element) | Acc] end,
      array_finish => fun(Acc, OldAcc) -> {{'Array', lists:reverse(Acc)}, OldAcc} end,
      object_push => fun(Name, Member, Acc) -> [{Name, value(Member)} | Acc] end,
      object_finish => fun(Acc, OldAcc) -> {{'Object', maps:from_list(Acc)}, OldAcc} end,
      integer => fun integer/1,
      float => fun(Digits) -> {'Real', binary_to_float(Digits)} end,
      null => 'Null'}.

integer(Digits) ->
    try {'Integer', binary_to_integer(Digits)}
    catch error:system_limit -> throw({too_long, Digits})
    end.

%% The offset of the byte the host's decoder could not read, which its
%% raise carries as the error's position.
position([{_, _, _, Info} | _]) ->
    maps:get(position, maps:get(cause, proplists:get_value(error_info, Info, #{}), #{}), none);
position(_) ->
    none.

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
        {Escape, _After} -> {'UnexpectedSequence', Escape};
        none -> Found
    end.

lone_surrogate(Text, Found, Position) ->
    case lone_escape(Text, 0) of
        {Escape, Position} -> {'UnexpectedSequence', Escape};
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
