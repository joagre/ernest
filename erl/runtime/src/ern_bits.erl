%% Report §5.11, §7.4: the checks of bitstring construction that the
%% runtime's bit syntax does not make. Erlang truncates an integer to its
%% segment, rounds a float to infinity, and takes a prefix of a binary;
%% Ernest faults, the cause saying what did not fit where the check knows
%% it, the value and the segment's width, and `segment overflow` alone
%% where the host's bit syntax refused the segment (overflow/0). A
%% construction whose bit count a dynamic size leaves open is checked for
%% byte alignment afterwards.
-module(ern_bits).

-export([int/3, float/2, bytes/2, aligned/1, overflow/0]).

-spec int(integer(), integer(), signed | unsigned) -> integer().
int(Value, Bits, unsigned) when is_integer(Value), Value >= 0, Value bsr Bits =:= 0 -> Value;
int(Value, Bits, signed)
  when is_integer(Value), Value >= -(1 bsl (Bits - 1)), Value < 1 bsl (Bits - 1) ->
    Value;
int(Value, Bits, unsigned) -> overflow("~B does not fit ~B bits", [Value, Bits]);
int(Value, Bits, signed) -> overflow("~B does not fit ~B signed bits", [Value, Bits]).

-spec float(float(), integer()) -> float().
float(Value, 64) when is_float(Value) -> Value;
float(Value, 32)
  when is_float(Value), Value >= -3.4028234663852886e38, Value =< 3.4028234663852886e38 ->
    Value;
float(Value, 16) when is_float(Value), Value >= -65504.0, Value =< 65504.0 -> Value;
float(Value, Bits) -> overflow("~ts does not fit a ~B-bit float", [ern_float:text(Value), Bits]).

%% A bytes segment of a given width, a whole number of octets, holds a value
%% of exactly that size (report §5.11).
-spec bytes(binary(), integer()) -> binary().
bytes(Value, Bits) when is_binary(Value), bit_size(Value) =:= Bits -> Value;
bytes(Value, Bits) ->
    overflow("a ~B-byte value does not fit ~B bytes", [byte_size(Value), Bits div 8]).

-spec aligned(bitstring()) -> binary().
aligned(Bitstring) when is_binary(Bitstring) -> Bitstring;
aligned(_) -> ern_rt:fault(<<"bitstring not byte-aligned">>).

-spec overflow() -> no_return().
overflow() -> ern_rt:fault(<<"segment overflow">>).

overflow(Format, Arguments) ->
    ern_rt:fault(unicode:characters_to_binary(["segment overflow: ",
                                               io_lib:format(Format, Arguments)])).
