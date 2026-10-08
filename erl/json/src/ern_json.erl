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
-spec parse(binary()) -> {'Right', value()} | {'Left', error()}.
parse(Text) ->
    try json:decode(Text, ok, decoders()) of
        {Term, ok, <<>>} -> {'Right', value(Term)};
        {_, ok, <<Byte, _/binary>>} -> {'Left', {'UnexpectedByte', Byte}}
    catch
        error:unexpected_end -> {'Left', 'UnexpectedEnd'};
        error:{invalid_byte, Byte} -> {'Left', {'UnexpectedByte', Byte}};
        error:{unexpected_sequence, Bytes} -> {'Left', {'UnexpectedSequence', Bytes}}
    end.

decoders() ->
    #{array_push => fun(Element, Acc) -> [value(Element) | Acc] end,
      array_finish => fun(Acc, OldAcc) -> {{'Array', lists:reverse(Acc)}, OldAcc} end,
      object_push => fun(Name, Member, Acc) -> [{Name, value(Member)} | Acc] end,
      object_finish => fun(Acc, OldAcc) -> {{'Object', maps:from_list(Acc)}, OldAcc} end,
      integer => fun(Digits) -> {'Integer', binary_to_integer(Digits)} end,
      float => fun(Digits) -> {'Real', binary_to_float(Digits)} end,
      null => 'Null'}.

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
