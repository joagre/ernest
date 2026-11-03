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

%% A byte that may stand in a number, which a number outside a string is a
%% run of.
-define(IS_NUMBER_BYTE(Byte), ((Byte >= $0 andalso Byte =< $9) orelse Byte =:= $. orelse
                               Byte =:= $e orelse Byte =:= $E orelse Byte =:= $+ orelse
                               Byte =:= $-)).

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
%% follows, which the host answers otherwise (lone_surrogate/2). A literal
%% or an escape the text breaks off is answered by the byte that breaks it,
%% which the host answers otherwise too (broken/2).
-spec parse(binary()) -> {'Right', value()} | {'Left', error()}.
parse(Text) ->
    try json:decode(Text, ok, decoders()) of
        {Term, ok, Rest} ->
            case after_white_space(Rest) of
                <<>> ->
                    {'Right', value(Term)};
                <<Byte, _/binary>> = After ->
                    {'Left', {'UnexpectedByte', Byte, at(Text, byte_size(Text) - byte_size(After))}}
            end
    catch
        throw:{too_long, Digits} ->
            {'Left', {'UnexpectedSequence', Digits, at(Text, number_offset(Text, Digits))}};
        error:unexpected_end ->
            {'Left', lone_surrogate(Text, broken(Text, 'UnexpectedEnd'))};
        error:{invalid_byte, Byte}:Trace ->
            Offset = position(Trace),
            Found = {'UnexpectedByte', Byte, at(Text, Offset)},
            {'Left', lone_surrogate(Text, broken_literal(Text, Found, Offset), Offset)};
        error:{unexpected_sequence, Bytes}:Trace ->
            Offset = position(Trace),
            Found = {'UnexpectedSequence', Bytes, at(Text, Offset)},
            {'Left', broken_escape(Text, Found, Offset, Bytes)}
    end.

%% The text after its JSON white space.
after_white_space(<<Byte, Rest/binary>>)
  when Byte =:= $\s; Byte =:= $\t; Byte =:= $\n; Byte =:= $\r ->
    after_white_space(Rest);
after_white_space(Rest) ->
    Rest.

%% The line and the column the byte at Offset begins, counted as a
%% diagnostic's are (§11.5): from 1, a line ending at a line feed and a
%% column a code point.
at(Text, Offset) ->
    Lines = binary:split(binary:part(Text, 0, Offset), <<"\n">>, [global]),
    {'Position', length(Lines), 1 + length(unicode:characters_to_list(lists:last(Lines)))}.

%% The offset of the integer Digits writes: the first number outside a
%% string that begins with the digits and goes on with no digit, point or
%% exponent, since an earlier integer of the digits would have been thrown
%% on first, and a real that holds them is no integer. A number is compared
%% only where it begins, and passed whole where it is not the one, so the
%% text is read once.
number_offset(Text, Digits) ->
    number_offset(Text, Text, Digits).

number_offset(Text, <<$", Rest/binary>>, Digits) ->
    number_offset(Text, after_string(Rest), Digits);
number_offset(Text, <<Byte, _/binary>> = Here, Digits) when ?IS_NUMBER_BYTE(Byte) ->
    case is_written(Here, Digits) of
        true -> byte_size(Text) - byte_size(Here);
        false -> number_offset(Text, after_number(Here), Digits)
    end;
number_offset(Text, <<_, Rest/binary>>, Digits) ->
    number_offset(Text, Rest, Digits).

%% Whether the number the bytes begin with is the integer Digits writes.
is_written(Here, Digits) ->
    Size = byte_size(Digits),
    case Here of
        <<Digits:Size/binary, Byte, _/binary>> ->
            not (Byte >= $0 andalso Byte =< $9) andalso Byte =/= $. andalso Byte =/= $e
                andalso Byte =/= $E;
        <<Digits:Size/binary>> ->
            true;
        _ ->
            false
    end.

after_number(<<Byte, Rest/binary>>) when ?IS_NUMBER_BYTE(Byte) ->
    after_number(Rest);
after_number(Rest) ->
    Rest.

%% The text after a string, from the byte after its opening quote: a
%% backslash escapes the byte after it, a quote among them.
after_string(<<$\\, _, Rest/binary>>) -> after_string(Rest);
after_string(<<$", Rest/binary>>) -> Rest;
after_string(<<_, Rest/binary>>) -> after_string(Rest);
after_string(_) -> <<>>.

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

%% The first lone high surrogate's escape inside a string, and the offset
%% of the byte after it, or none.
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

%% Appendix G.6: a literal, `true`, `false` or `null`, that the text breaks
%% off before its end is the first byte that differs from it, and an escape
%% `\u` broken off before its four hexadecimal digits end is the escape as
%% the text writes it up to the byte that breaks it.
%%
%% The host answers a literal by the count of bytes after its first, the
%% text's end where no more follow than the rest of the literal's and the
%% byte after its first where more do; and an escape by the count after its
%% `u`, the text's end where fewer than four follow and the six bytes from
%% its backslash, past the string's end among them, where more do.
%%
%% So where the host answers so, the text is read for the first literal or
%% escape a byte breaks (first_broken/2), and the host's answer stands
%% where there is none, or where it is not the one the host stopped at: the
%% byte the host names is not the one after the literal's first, or the
%% escape is not among the sequence the host names.
broken(Text, Found) ->
    case first_broken(Text, Text) of
        {_, _, Error} -> Error;
        none -> Found
    end.

broken_literal(Text, Found, Offset) ->
    case first_broken(Text, Text) of
        {literal, Start, Error} when Start + 1 =:= Offset -> Error;
        _ -> Found
    end.

broken_escape(Text, Found, Offset, Sequence) ->
    case first_broken(Text, Text) of
        {escape, Start, Error} when Start >= Offset, Start < Offset + byte_size(Sequence) -> Error;
        _ -> Found
    end.

%% The first literal outside a string that a byte of the text differs from,
%% or the first escape `\u` inside one that a byte breaks before its four
%% hexadecimal digits: which, the offset it begins at, and the error it is,
%% or none. Outside a string a `t`, an `f` or an `n` begins a literal and
%% nothing else, and a literal or an escape the text ends inside is broken
%% by no byte.
first_broken(Text, <<$", Rest/binary>>) ->
    broken_in_string(Text, Rest);
first_broken(Text, <<Byte, _/binary>> = Here) when Byte =:= $t; Byte =:= $f; Byte =:= $n ->
    Literal = literal(Byte),
    case common(Here, Literal) of
        whole ->
            first_broken(Text, binary:part(Here, byte_size(Literal),
                                           byte_size(Here) - byte_size(Literal)));
        ended ->
            none;
        {differs, Index} ->
            Start = byte_size(Text) - byte_size(Here),
            {literal, Start, {'UnexpectedByte', binary:at(Here, Index), at(Text, Start + Index)}}
    end;
first_broken(Text, <<_, Rest/binary>>) ->
    first_broken(Text, Rest);
first_broken(_, <<>>) ->
    none.

broken_in_string(Text, <<$", Rest/binary>>) ->
    first_broken(Text, Rest);
broken_in_string(Text, <<"\\u", Rest/binary>> = Here) ->
    case hex_digits(Rest, 0) of
        4 ->
            broken_in_string(Text, binary:part(Rest, 4, byte_size(Rest) - 4));
        Count when Count =:= byte_size(Rest) ->
            none;
        Count ->
            Start = byte_size(Text) - byte_size(Here),
            Escape = binary:part(Here, 0, 2 + Count),
            {escape, Start, {'UnexpectedSequence', Escape, at(Text, Start)}}
    end;
broken_in_string(Text, <<$\\, _, Rest/binary>>) ->
    broken_in_string(Text, Rest);
broken_in_string(Text, <<_, Rest/binary>>) ->
    broken_in_string(Text, Rest);
broken_in_string(_, _) ->
    none.

%% How the bytes begin against the literal: with it whole, ended inside
%% it, or with a byte that differs from it, at its index.
common(Here, Literal) ->
    Common = binary:longest_common_prefix([Here, Literal]),
    if
        Common =:= byte_size(Literal) -> whole;
        Common =:= byte_size(Here) -> ended;
        true -> {differs, Common}
    end.

%% How many of an escape's four digits the bytes begin with.
hex_digits(<<Byte, Rest/binary>>, Count)
  when Count < 4, (Byte >= $0 andalso Byte =< $9 orelse Byte >= $a andalso Byte =< $f
                   orelse Byte >= $A andalso Byte =< $F) ->
    hex_digits(Rest, Count + 1);
hex_digits(_, Count) ->
    Count.

literal($t) -> <<"true">>;
literal($f) -> <<"false">>;
literal($n) -> <<"null">>.

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
