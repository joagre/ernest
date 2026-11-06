%% The primitive behind Base64.decode (report Appendix G.8). The host's
%% `base64:decode/1` raises on a text it cannot read, which Ernest cannot
%% catch, and reads texts that `Base64.encode` does not write: it skips
%% white space, and it drops the bits of the last character before a `=`
%% that the bytes do not use. So the host's function is called here, its
%% raise answered as `None`, and the texts it reads beyond `encode`'s
%% refused.
-module(ern_base64).

-export([decode/1]).

%% Appendix G.8: the bytes Text writes, where `encode` writes Text, or
%% None. The host refuses a character outside the alphabet but white
%% space, a count of the others that is no multiple of four, and a `=`
%% anywhere but as the last one or two of them, each by a raise whose
%% reason its page does not name, so that every raise is None.
-spec decode(binary()) -> {'Some', binary()} | 'None'.
decode(Text) when byte_size(Text) rem 4 =:= 0 ->
    try base64:decode(Text) of
        Bytes -> written(Text, Bytes)
    catch
        error:_ -> 'None'
    end;
decode(_) ->
    'None'.

%% A text of n characters, a multiple of four, none of them white space,
%% writes 3n/4 bytes less one for each `=` it ends with. A text of n
%% characters among which the host skipped white space holds four of it
%% at least, since the host reads the rest four by four, and so writes
%% three bytes fewer at least, which no two `=` make up: the count of the
%% bytes tells whether the host skipped any, without a second reading of
%% the text.
written(Text, Bytes) ->
    case byte_size(Bytes) =:= byte_size(Text) div 4 * 3 - padding(Text)
         andalso is_canonical(Text) of
        true -> {'Some', Bytes};
        false -> 'None'
    end.

%% The count of the `=` the text ends with, which the host has read as
%% one or two at most.
padding(Text) ->
    case Text of
        <<_:(byte_size(Text) - 2)/binary, "==">> -> 2;
        <<_:(byte_size(Text) - 1)/binary, "=">> -> 1;
        _ -> 0
    end.

%% Whether the bits of the last character before a `=` that the bytes do
%% not use are zero, as `encode` writes them, RFC 4648's canonical
%% encoding (§3.5): four of them before two `=`, two before one.
is_canonical(Text) ->
    case Text of
        <<_:(byte_size(Text) - 3)/binary, Char, "==">> -> value(Char) rem 16 =:= 0;
        <<_:(byte_size(Text) - 2)/binary, Char, "=">> -> value(Char) rem 4 =:= 0;
        _ -> true
    end.

%% A character's value, its place in the standard alphabet (RFC 4648 §4),
%% which the host has read the character as.
value(Char) ->
    {Value, 1} =
        binary:match(<<"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/">>,
                     <<Char>>),
    Value.
