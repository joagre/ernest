%% The primitives behind Http's heads (report Appendix G.11). The host's
%% `erlang:decode_packet/3` reads a head a line at a time, `http_bin` for
%% the first line and `httph_bin` for each header, but answers the headers
%% and the methods it knows by atoms of its own, and a request's target
%% parsed into terms no Ernest type describes; so a line is read here, and
%% written as an `Http.Line`. Of the first line the host contributes the
%% line's end within the limit, the method as a token and the version's
%% numbers; the library's Ernest reads the line's words, the target and the
%% status's three digits, closing what the host reads otherwise (E.0 rule
%% 1), and the rest: the limits and a header's value.
%%
%% The host's table reads U+007F as a token's character, which no token of
%% RFC 9110, section 5.6.2 holds, so a method or a header's name holding it
%% is answered here as a line the host cannot read. The check is here and
%% not in the Ernest, where it cost a browser's head 2 microseconds in 9
%% against 0.2 here (the log's *`Http`'s First Line Stays the Host's*).
-module(ern_http).

-export([read_first/2, read_field/2]).

-type line() :: 'More' | 'TooLong'
              | {'RequestLine', non_neg_integer(), non_neg_integer(), binary()}
              | {'StatusLine', non_neg_integer(), non_neg_integer(), integer(), binary()}
              | {'Field', binary(), binary(), binary()}
              | {'HeadEnd', binary()}
              | {'Unreadable', binary(), binary()}.

%% Appendix G.11: the host's reading of the head's first line, a request
%% line or a status line, within the host's `packet_size`, 0 being none.
-spec read_first(binary(), non_neg_integer()) -> line().
read_first(Bytes, Size) ->
    line(Bytes, erlang:decode_packet(http_bin, Bytes, [{packet_size, Size}])).

%% Appendix G.11: the host's reading of a header line, as the first line's.
-spec read_field(binary(), non_neg_integer()) -> line().
read_field(Bytes, Size) ->
    line(Bytes, erlang:decode_packet(httph_bin, Bytes, [{packet_size, Size}])).

%% Each packet the host's page names, with the bytes after its line. The
%% host refuses a line past its size as `invalid`, and answers a line it
%% cannot read as `http_error`, with the line. A request line's version and
%% a status line's version and status are the host's; a request's method
%% and target, and a response's phrase, are left out, since the Ernest
%% reads them from the line as written. A header's name is the unmodified
%% field, as written, which the host reads as a token, and its value is the
%% host's, its white space after it kept. A method the host knows is an
%% atom of its own, and one it does not the bytes as written.
line(_, {more, _}) -> 'More';
line(_, {error, invalid}) -> 'TooLong';
line(Bytes, {ok, {http_request, Method, _, {Major, Minor}}, Rest}) ->
    case is_binary(Method) andalso holds_delete(Method) of
        true -> unreadable(Bytes, Rest);
        false -> {'RequestLine', Major, Minor, Rest}
    end;
line(_, {ok, {http_response, {Major, Minor}, Status, _}, Rest}) ->
    {'StatusLine', Major, Minor, Status, Rest};
line(Bytes, {ok, {http_header, _, _, Name, Value}, Rest}) ->
    case holds_delete(Name) of
        true -> unreadable(Bytes, Rest);
        false -> {'Field', Name, Value, Rest}
    end;
line(_, {ok, http_eoh, Rest}) -> {'HeadEnd', Rest};
line(_, {ok, {http_error, Line}, Rest}) -> {'Unreadable', Line, Rest}.

%% The line the bytes begin with, which `Rest` follows, as one the host
%% cannot read.
unreadable(Bytes, Rest) ->
    {'Unreadable', binary:part(Bytes, 0, byte_size(Bytes) - byte_size(Rest)), Rest}.

%% Whether a word holds U+007F.
holds_delete(<<127, _/binary>>) -> true;
holds_delete(<<_, Rest/binary>>) -> holds_delete(Rest);
holds_delete(<<>>) -> false.
