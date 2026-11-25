%% The shim behind Bytes.fromHex (report Appendix E.20, E.0 rule 1), whose
%% host function raises where E.20 answers `None`, on a text Ernest cannot
%% find invalid short of doing that function's work.
-module(ern_bytes).

-export([from_hex/1]).

%% Appendix E.20: the octets that two hexadecimal digits of either case
%% write each. `binary:decode_hex/1` raises on an odd count of them or on
%% another character.
-spec from_hex(binary()) -> {'Some', binary()} | 'None'.
from_hex(Text) ->
    try {'Some', binary:decode_hex(Text)}
    catch error:badarg -> 'None'
    end.
