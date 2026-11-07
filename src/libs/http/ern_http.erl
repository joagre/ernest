%% The primitives behind Http's heads (report Appendix G.11). The host's
%% `erlang:decode_packet/3` reads a head a line at a time, `http_bin` for
%% the first line and `httph_bin` for each header, but answers the headers
%% and the methods it knows by atoms of its own, and a request's target
%% parsed into terms no Ernest type describes; so a line is read here, and
%% written as an `Http.Line`. The library's Ernest reads the rest: the
%% line's words, the limits, and a header's value.
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
    line(erlang:decode_packet(http_bin, Bytes, [{packet_size, Size}])).

%% Appendix G.11: the host's reading of a header line, as the first line's.
-spec read_field(binary(), non_neg_integer()) -> line().
read_field(Bytes, Size) ->
    line(erlang:decode_packet(httph_bin, Bytes, [{packet_size, Size}])).

%% Each packet the host's page names, with the bytes after its line. The
%% host refuses a line past its size as `invalid`, and answers a line it
%% cannot read as `http_error`, with the line. A request line's version and
%% a status line's version and status are the host's; a request's method
%% and target, and a response's phrase, are left out, since the Ernest
%% reads them from the line as written. A header's name is the unmodified
%% field, as written, which the host reads as a token, and its value is the
%% host's, its white space after it kept.
line({more, _}) -> 'More';
line({error, invalid}) -> 'TooLong';
line({ok, {http_request, _, _, {Major, Minor}}, Rest}) -> {'RequestLine', Major, Minor, Rest};
line({ok, {http_response, {Major, Minor}, Status, _}, Rest}) ->
    {'StatusLine', Major, Minor, Status, Rest};
line({ok, {http_header, _, _, Name, Value}, Rest}) -> {'Field', Name, Value, Rest};
line({ok, http_eoh, Rest}) -> {'HeadEnd', Rest};
line({ok, {http_error, Line}, Rest}) -> {'Unreadable', Line, Rest}.
