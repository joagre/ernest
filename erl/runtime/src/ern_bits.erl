%% Report §5.11, §7.4: the checks of bitstring construction that the
%% runtime's bit syntax does not make. Erlang truncates an integer to its
%% segment, rounds a float to infinity, and takes a prefix of a binary;
%% Ernest faults. A construction whose bit count a dynamic size leaves
%% open is checked for byte alignment afterwards.
-module(ern_bits).

-export([int/3, float/2, bytes/2, bits/2, aligned/1, overflow/0]).

-spec int(integer(), integer(), signed | unsigned) -> integer().
int(V, Bits, unsigned) when is_integer(V), V >= 0, V bsr Bits =:= 0 -> V;
int(V, Bits, signed) when is_integer(V), V >= -(1 bsl (Bits - 1)), V < 1 bsl (Bits - 1) -> V;
int(_, _, _) -> overflow().

-spec float(float(), integer()) -> float().
float(V, 64) when is_float(V) -> V;
float(V, 32) when is_float(V), V >= -3.4028234663852886e38, V =< 3.4028234663852886e38 -> V;
float(V, 16) when is_float(V), V >= -65504.0, V =< 65504.0 -> V;
float(_, _) -> overflow().

%% A bytes segment of a given width holds a value of exactly that size.
-spec bytes(binary(), integer()) -> binary().
bytes(V, Bits) when is_binary(V), bit_size(V) =:= Bits -> V;
bytes(_, _) -> overflow().

%% A bits segment bound to Bytes has a byte-multiple width (report §5.11).
-spec bits(binary(), integer()) -> binary().
bits(_, Bits) when Bits rem 8 =/= 0 -> ern_rt:fault(<<"bitstring not byte-aligned">>);
bits(V, Bits) when is_binary(V), bit_size(V) =:= Bits -> V;
bits(_, _) -> overflow().

-spec aligned(bitstring()) -> binary().
aligned(B) when is_binary(B) -> B;
aligned(_) -> ern_rt:fault(<<"bitstring not byte-aligned">>).

-spec overflow() -> no_return().
overflow() -> ern_rt:fault(<<"segment overflow">>).
