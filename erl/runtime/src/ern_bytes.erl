%% The shim behind Bytes.<> (report §9.6, Appendix E.20): the host joins
%% two binaries by its bit syntax, and has no function that does.
-module(ern_bytes).

-export([append/2]).

-spec append(binary(), binary()) -> binary().
append(Left, Right) -> <<Left/binary, Right/binary>>.
