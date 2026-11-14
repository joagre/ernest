%% A JSON file of the toolchain's own, a node's `ernest.conf` (report
%% §12.5, Appendix C) and a package's `package.conf` (§11.9), read the one
%% way: the text as one JSON value, each object in it `{object, Pairs}`, its
%% fields in the file's order and twice where the file gives one twice, and
%% an object's fields held to the names it knows. A fault is said in the
%% same words in either file; the reader of the file says it, after the
%% file's name, `ernest.conf: is not JSON`.
-module(ern_conf).

-export([decoded/1, pairs/3, fields/3, quoted/1]).

-type value() :: {object, [{binary(), value()}]} | [value()] | binary() | number() | boolean()
               | null.
-export_type([value/0]).

%% The text as one JSON value, or the one fault that keeps it from being
%% read: no JSON, more than one value, or a whole number longer than the
%% host holds, which its decoder would raise for.
-spec decoded(binary()) -> {ok, value()} | {fault, string()}.
decoded(Text) ->
    Decoders = #{object_start => fun(_) -> [] end,
                 object_push => fun(Name, Item, Acc) -> [{Name, Item} | Acc] end,
                 object_finish => fun(Acc, Outer) -> {{object, lists:reverse(Acc)}, Outer} end,
                 integer => fun integer/1},
    try json:decode(Text, ok, Decoders) of
        {Decoded, ok, Rest} ->
            case string:trim(Rest) of
                <<>> -> {ok, Decoded};
                _ -> {fault, "holds more than one JSON value"}
            end
    catch
        throw:too_large -> {fault, "holds a number too large for the host to read"};
        error:_ -> {fault, "is not JSON"}
    end.

integer(Numeral) ->
    try binary_to_integer(Numeral)
    catch
        error:system_limit -> throw(too_large)
    end.

%% An object's fields in the order the object gives them, What naming it in
%% a fault, `the file` or `a peer`: `{field, Name, Value}` for the first
%% field of each name among Known, and the fault of each field whose name is
%% not among Known and of each given again, so that a reader that judges
%% the values says every fault in the order of where each stands.
%% `not_object` where Item is no object.
-spec pairs(string(), value(), [binary()]) ->
          [{field, binary(), value()} | {fault, string()}] | not_object.
pairs(What, {object, Pairs}, Known) ->
    {Said, _} = lists:mapfoldl(fun({Name, Item}, Given) -> pair(What, Name, Item, Known, Given) end,
                               [], Pairs),
    Said;
pairs(_What, _Item, _Known) ->
    not_object.

pair(What, Name, Item, Known, Given) ->
    case {lists:member(Name, Known), lists:member(Name, Given)} of
        {false, _} -> {{fault, What ++ " has the unknown field " ++ text(Name)}, Given};
        {true, true} -> {{fault, What ++ " gives " ++ text(Name) ++ " twice"}, Given};
        {true, false} -> {{field, Name, Item}, [Name | Given]}
    end.

%% The same as a map of the fields, a field given twice keeping its first
%% value, with the faults in the order the object gives them.
-spec fields(string(), value(), [binary()]) -> {#{binary() => value()}, [string()]} | not_object.
fields(What, Item, Known) ->
    case pairs(What, Item, Known) of
        not_object -> not_object;
        Said -> {maps:from_list([{Name, Value} || {field, Name, Value} <- Said]),
                 [Fault || {fault, Fault} <- Said]}
    end.

%% A string the file gives, quoted as JSON writes it, each character one,
%% in a fault that names a value not of its form: `"0.11"`.
-spec quoted(binary()) -> string().
quoted(Text) ->
    unicode:characters_to_list(iolist_to_binary(json:encode(Text))).

text(Name) ->
    unicode:characters_to_list(Name).
