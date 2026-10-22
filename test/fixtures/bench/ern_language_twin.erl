%% The language against the host, construct by construct, for `make bench`
%% (test/ern_language_costs.erl): each loop of
%% test/fixtures/bench/language.ern as Erlang writes it, the plain Erlang
%% a programmer writes for the same construct, over the same operands,
%% which the bench gives both.
-module(ern_language_twin).

-export([loop_alone/3, matched/3, guarded/3, updated/2, float_added/4, float_multiplied/4,
         dotted/2, int_added/4, pair_compared/4, required/4, appended/4, sliced/3, parted/3,
         map_read/3, map_written/3, list_mapped/3, messaged/2, shown/3, applied/3, successor/0,
         made/3]).

-record('Account', {id, name, balance, open}).
-record(vector, {x, y, z}).

-spec loop_alone(non_neg_integer(), integer(), integer()) -> integer().
loop_alone(0, _, Acc) -> Acc;
loop_alone(Count, Operand, _) -> loop_alone(Count - 1, Operand, Operand).

%% A case on tagged tuples.
-spec matched(non_neg_integer(), tuple() | atom(), integer()) -> integer().
matched(0, _, Acc) -> Acc;
matched(Count, Shape, _) -> matched(Count - 1, Shape, area(Shape)).

area(Shape) ->
    case Shape of
        {'Square', Side} -> Side * Side;
        {'Rectangle', Width, Height} -> Width * Height;
        'Dot' -> 0
    end.

%% A case whose tests call functions, which no guard can.
-spec guarded(non_neg_integer(), char(), integer()) -> integer().
guarded(0, _, Acc) -> Acc;
guarded(Count, Char, _) -> guarded(Count - 1, Char, classified(Char)).

classified($\s) ->
    0;
classified(Char) ->
    case is_digit(Char) of
        true ->
            1;
        false ->
            case is_letter(Char) of
                true -> 2;
                false -> 3
            end
    end.

is_digit(Char) -> Char >= $0 andalso Char =< $9.

is_letter(Char) -> Char >= $a andalso Char =< $z.

%% A record update.
-spec updated(non_neg_integer(), #'Account'{}) -> #'Account'{}.
updated(0, Account) -> Account;
updated(Count, Account) -> updated(Count - 1, Account#'Account'{balance = Count}).

%% The bare operators on floats, and on integers.
-spec float_added(non_neg_integer(), float(), float(), float()) -> float().
float_added(0, _, _, Acc) -> Acc;
float_added(Count, Left, Right, _) -> float_added(Count - 1, Left, Right, Left + Right).

-spec float_multiplied(non_neg_integer(), float(), float(), float()) -> float().
float_multiplied(0, _, _, Acc) -> Acc;
float_multiplied(Count, Left, Right, _) ->
    float_multiplied(Count - 1, Left, Right, Left * Right).

%% A float expression of five operations over records of floats.
-spec dotted(non_neg_integer(), float()) -> float().
dotted(0, Acc) -> Acc;
dotted(Count, Acc) ->
    Weights = #vector{x = 0.5, y = 0.25, z = 0.25},
    dotted(Count - 1, dot(#vector{x = Acc, y = Acc, z = Acc}, Weights)).

dot(Left, Right) ->
    Left#vector.x * Right#vector.x + Left#vector.y * Right#vector.y
        + Left#vector.z * Right#vector.z.

-spec int_added(non_neg_integer(), integer(), integer(), integer()) -> integer().
int_added(0, _, _, Acc) -> Acc;
int_added(Count, Left, Right, _) -> int_added(Count - 1, Left, Right, Left + Right).

%% A comparison of two records written by hand, field by field.
-spec pair_compared(non_neg_integer(), tuple(), tuple(), atom()) -> atom().
pair_compared(0, _, _, Acc) -> Acc;
pair_compared(Count, Left, Right, _) ->
    pair_compared(Count - 1, Left, Right, compare_pairs(Left, Right)).

compare_pairs({'Pair', LeftFirst, LeftSecond}, {'Pair', RightFirst, RightSecond}) ->
    if
        LeftFirst < RightFirst -> 'Less';
        LeftFirst > RightFirst -> 'Greater';
        LeftSecond < RightSecond -> 'Less';
        LeftSecond > RightSecond -> 'Greater';
        true -> 'Equal'
    end.

%% A comparison function called directly.
-spec required(non_neg_integer(), integer(), integer(), integer()) -> integer().
required(0, _, _, Acc) -> Acc;
required(Count, Left, Right, _) -> required(Count - 1, Left, Right, larger(Left, Right)).

larger(Left, Right) ->
    case compare(Left, Right) of
        'Less' -> Right;
        _ -> Left
    end.

compare(Left, Right) when Left < Right -> 'Less';
compare(Left, Right) when Left > Right -> 'Greater';
compare(_, _) -> 'Equal'.

%% A binary concatenation, the host's slice of graphemes, and its slice of
%% bytes.
-spec appended(non_neg_integer(), binary(), binary(), binary()) -> binary().
appended(0, _, _, Acc) -> Acc;
appended(Count, Left, Right, _) -> appended(Count - 1, Left, Right, <<Left/binary, Right/binary>>).

-spec sliced(non_neg_integer(), binary(), binary()) -> binary().
sliced(0, _, Acc) -> Acc;
sliced(Count, Text, _) -> sliced(Count - 1, Text, string:slice(Text, 2, 5)).

-spec parted(non_neg_integer(), binary(), binary()) -> binary().
parted(0, _, Acc) -> Acc;
parted(Count, Text, _) -> parted(Count - 1, Text, binary:part(Text, 2, 5)).

%% A read of a map with a default, and a write.
-spec map_read(non_neg_integer(), map(), integer()) -> integer().
map_read(0, _, Acc) -> Acc;
map_read(Count, Map, _) -> map_read(Count - 1, Map, maps:get(Count rem 8, Map, 0)).

-spec map_written(non_neg_integer(), map(), map()) -> map().
map_written(0, _, Acc) -> Acc;
map_written(Count, Map, _) -> map_written(Count - 1, Map, maps:put(Count rem 8, Count, Map)).

-spec list_mapped(non_neg_integer(), [integer()], [integer()]) -> [integer()].
list_mapped(0, _, Acc) -> Acc;
list_mapped(Count, List, _) ->
    list_mapped(Count - 1, List, lists:map(fun(Element) -> Element + Count end, List)).

%% A bare send to the process itself and a receive by the pattern.
-spec messaged(non_neg_integer(), integer()) -> integer().
messaged(0, Acc) -> Acc;
messaged(Count, _) ->
    self() ! {'Ping', Count},
    Value = receive
                {'Ping', Received} -> Received
            end,
    messaged(Count - 1, Value).

%% A term written as text, as the host prints it.
-spec shown(non_neg_integer(), tuple(), binary()) -> binary().
shown(0, _, Acc) -> Acc;
shown(Count, Point, _) -> shown(Count - 1, Point, iolist_to_binary(io_lib:format("~p", [Point]))).

%% A fun called, and a fun made.
-spec applied(non_neg_integer(), fun((integer()) -> integer()), integer()) -> integer().
applied(0, _, Acc) -> Acc;
applied(Count, F, _) -> applied(Count - 1, F, F(Count)).

-spec successor() -> fun((integer()) -> integer()).
successor() ->
    fun(N) -> N + 1 end.

-spec made(non_neg_integer(), integer(), fun((integer()) -> integer())) ->
          fun((integer()) -> integer()).
made(0, _, Acc) -> Acc;
made(Count, Addend, _) -> made(Count - 1, Addend, fun(K) -> K + Addend + Count end).
