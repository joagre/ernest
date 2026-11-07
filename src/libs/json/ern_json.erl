%% The shims behind Json (report Appendix G.6). The host's `json` reads a
%% text into terms no Ernest type describes, and raises on a text it cannot
%% read, which Ernest cannot catch; so the host's functions are called here,
%% their terms written as `Json.Value`'s and a raise as what it names and
%% where. The library's Ernest reads the rest of a text and an error's
%% position.
-module(ern_json).

-export([decode/1, format/1, encode/1]).

-type value() :: 'Null' | {'Boolean', boolean()} | {'Integer', integer()} | {'Real', float()}
               | {'Text', binary()} | {'Array', [value()]} | {'Object', #{binary() => value()}}.
-type decoded() :: {'Decoded', value(), binary()} | 'EndMet'
                 | {'InvalidByte', byte(), non_neg_integer()}
                 | {'InvalidSequence', binary(), non_neg_integer()}
                 | {'IntegerTooLong', binary()}.

%% Appendix G.6: the value the text writes and the text after it, or what
%% the host raised and at which byte. `json:decode/3` raises the three
%% errors its page lists, and calls the decoders given to build each
%% value, in the order of the text: a number, null and an array or an
%% object as it ends, and an element or a member's value as it is pushed,
%% which is where a string and a boolean, which have no decoder, are seen.
%% It answers the text left after the value, white space among it.
%%
%% The host's raise carries the byte's or the sequence's offset in the
%% text as its error's position (position/1). A number the host cannot
%% hold is the decoder's own throw, with no offset: an integer longer than
%% the host holds, on which `binary_to_integer/1` raises `system_limit`.
%%
%% An object keeps a name's last member, as `Map.fromList` keeps a later
%% pair (Appendix E.3): the members, pushed in front, are put back in the
%% text's order, and `maps:from_list/1` keeps a key's last.
-spec decode(binary()) -> decoded().
decode(Text) ->
    try json:decode(Text, ok, decoders()) of
        {Term, ok, Rest} -> {'Decoded', value(Term), Rest}
    catch
        throw:{too_long, Digits} -> {'IntegerTooLong', Digits};
        error:unexpected_end -> 'EndMet';
        error:{invalid_byte, Byte}:Trace -> {'InvalidByte', Byte, position(Trace)};
        error:{unexpected_sequence, Bytes}:Trace -> {'InvalidSequence', Bytes, position(Trace)}
    end.

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

%% Appendix G.6: the value on one line by `json:encode/2`, which calls the
%% encoder given on every value it holds; an object's members in the order
%% format/1 writes them.
-spec encode(value()) -> binary().
encode(Value) ->
    iolist_to_binary(json:encode(term(Value), fun encoded/2)).

encoded(Map, Encode) when is_map(Map) ->
    json:encode_key_value_list(lists:keysort(1, maps:to_list(Map)), Encode);
encoded(Term, Encode) -> json:encode_value(Term, Encode).
