%% The shims behind Bytes (report Appendix E.20, E.0 rule 1) whose host
%% function takes an atom, which Ernest makes only through `Foreign.atom` at
%% each call, or raises where E.20 answers `None`, which Ernest cannot
%% catch.
-module(ern_bytes).

-export([split/2, replace/3, from_hex/1]).

%% Appendix E.20: the parts between each occurrence of the separator, which
%% is not empty, found from the first.
-spec split(binary(), binary()) -> [binary()].
split(Bytes, Separator) -> binary:split(Bytes, Separator, [global]).

%% Appendix E.20: each occurrence of the old part, which is not empty,
%% replaced by the new, found as split finds them.
-spec replace(binary(), binary(), binary()) -> binary().
replace(Bytes, Old, New) -> binary:replace(Bytes, Old, New, [global]).

%% Appendix E.20: the octets that two hexadecimal digits of either case
%% write each. `binary:decode_hex/1` raises on an odd count of them or on
%% another character.
-spec from_hex(binary()) -> {'Some', binary()} | 'None'.
from_hex(Text) ->
    try {'Some', binary:decode_hex(Text)}
    catch error:badarg -> 'None'
    end.
