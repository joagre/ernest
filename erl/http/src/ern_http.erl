%% The shims behind Http's heads (report Appendix G.11). The host's
%% `erlang:decode_packet/3` reads a head a line at a time, `http_bin` for
%% the first line and `httph_bin` for each header, but answers the headers
%% and the methods it knows by atoms of its own, and a request's target
%% parsed into terms no Ernest type describes; so the lines are read here,
%% and written as `Http.Request`'s and `Http.Response`'s.
-module(ern_http).

-export([parse_request/2, parse_response/2]).

-type version() :: {'Version', non_neg_integer(), non_neg_integer()}.
-type header() :: {'Header', binary(), binary()}.
-type request() :: {'Request', binary(), binary(), version(), [header()]}.
-type response() :: {'Response', version(), integer(), [header()]}.
-type limits() :: {'Limits', integer(), integer()}.
-type error() :: 'Malformed' | 'LineTooLong' | 'HeadersTooLarge'.
-type parsed(Head) :: 'Incomplete' | {'Parsed', Head, binary()}.

%% The bytes between a request line's words, and its line feed.
-define(IS_SPACE(Byte), (Byte =:= $\s orelse Byte =:= $\t orelse Byte =:= $\r orelse Byte =:= $\n)).

%% Appendix G.11: the request the bytes begin with, and the bytes after its
%% head, or `Incomplete`, or why the head is refused.
-spec parse_request(binary(), limits()) -> {'Right', parsed(request())} | {'Left', error()}.
parse_request(Bytes, Limits) ->
    parse(request, Bytes, Limits).

%% Appendix G.11: the response the bytes begin with, as a request's.
-spec parse_response(binary(), limits()) -> {'Right', parsed(response())} | {'Left', error()}.
parse_response(Bytes, Limits) ->
    parse(response, Bytes, Limits).

%% The host's `packet_size` is the most bytes of a line, its line ending
%% among them, and refuses a line that has passed it before its line feed
%% comes, so that a line is never read past the limit. Its 0 is no limit,
%% so a limit below 1, which no line of a byte or more is within, is
%% answered here.
parse(_, <<>>, _) ->
    {'Right', 'Incomplete'};
parse(_, _, {'Limits', Line, _}) when Line < 1 ->
    {'Left', 'LineTooLong'};
parse(Kind, Bytes, {'Limits', Line, Headers}) ->
    case erlang:decode_packet(http_bin, Bytes, [{packet_size, packet_size(Line, Bytes)}]) of
        {more, _} ->
            {'Right', 'Incomplete'};
        {error, invalid} ->
            {'Left', 'LineTooLong'};
        {ok, First, Rest} ->
            case first(Kind, First, binary:part(Bytes, 0, byte_size(Bytes) - byte_size(Rest))) of
                {ok, Head} -> headers(Rest, Line, Headers, 0, Head, []);
                malformed -> {'Left', 'Malformed'}
            end
    end.

%% A limit the bytes are shorter than no line in them can pass, and is
%% given to the host as none, since the host takes no limit past 2^32 - 1.
packet_size(Line, Bytes) when Line > byte_size(Bytes) -> 0;
packet_size(Line, _) -> Line.

%% Appendix G.11: the head's first line as its constructor's first fields,
%% to which the headers are added. A response's phrase is dropped: the
%% status's is `reason`'s.
%%
%% The host reads a request line without a version as HTTP/0.9's,
%% `GET  HTTP/1.1` among them, whose target it takes for `HTTP/1.1`, and
%% answers the target parsed. So the line is read again here as its three
%% words, the method, the target and the version, and the target is the
%% second as the client wrote it: this is where Ernest closes the
%% difference with the host's reading.
first(request, {http_request, _, _, {Major, Minor}}, Line) ->
    case words(Line, []) of
        [Method, Target, _] ->
            case is_target(Target) of
                true -> {ok, {'Request', Method, Target, {'Version', Major, Minor}}};
                false -> malformed
            end;
        _ ->
            malformed
    end;
first(response, {http_response, {Major, Minor}, Status, _}, _) ->
    {ok, {'Response', {'Version', Major, Minor}, Status}};
first(_, _, _) ->
    malformed.

%% The words of a line, at most four: the runs of bytes between spaces, tabs,
%% and carriage returns no line feed follows, at which RFC 9112, section 3 has
%% a recipient part a request line, as the host does. Each byte is tested
%% directly, as a fixed question is (docs/style.md).
words(_, [_, _, _, _] = Words) ->
    lists:reverse(Words);
words(<<Byte, Rest/binary>>, Words) when ?IS_SPACE(Byte) ->
    words(Rest, Words);
words(<<>>, Words) ->
    lists:reverse(Words);
words(Line, Words) ->
    Size = word_size(Line, 0),
    <<Word:Size/binary, Rest/binary>> = Line,
    words(Rest, [Word | Words]).

word_size(<<Byte, Rest/binary>>, Size) when not ?IS_SPACE(Byte) -> word_size(Rest, Size + 1);
word_size(_, Size) -> Size.

%% Appendix G.11: the header lines to the empty one that ends the head,
%% each line within the line's limit and all of them, their line endings
%% counted, within the headers'. A header line is answered by the host once
%% the byte after it shows that the next line is no continuation of it.
headers(Bytes, Line, Limit, Count, Head, Acc) ->
    case erlang:decode_packet(httph_bin, Bytes, [{packet_size, packet_size(Line, Bytes)}]) of
        {more, _} ->
            {'Right', 'Incomplete'};
        {error, invalid} ->
            {'Left', 'HeadersTooLarge'};
        {ok, http_eoh, Rest} ->
            {'Right', {'Parsed', erlang:append_element(Head, lists:reverse(Acc)), Rest}};
        {ok, {http_header, _, _, Name, Value}, Rest} ->
            Total = Count + byte_size(Bytes) - byte_size(Rest),
            case header(Name, Value) of
                _ when Total > Limit ->
                    {'Left', 'HeadersTooLarge'};
                {ok, Header} ->
                    headers(Rest, Line, Limit, Total, Head, [Header | Acc]);
                malformed ->
                    {'Left', 'Malformed'}
            end;
        {ok, {http_error, _}, _} ->
            {'Left', 'Malformed'}
    end.

%% Appendix G.11: a header by its name as written, which the host answers as
%% the unmodified field, and its value without the white space after it, which
%% RFC 9112, section 5.1 leaves out of the value and the host keeps; the host
%% has dropped the white space before it. A header the host reads with no name
%% is refused, as is a value holding a carriage return or a line feed, which a
%% header folded over two lines holds, or a NUL, which RFC 9110, section 5.5
%% has a recipient refuse, or one that is not UTF-8, which no `String` holds.
header(<<>>, _) ->
    malformed;
header(Name, Value) ->
    case is_value(Value) of
        true -> {ok, {'Header', Name, trimmed(Value, byte_size(Value))}};
        false -> malformed
    end.

%% Whether a value is UTF-8 and holds no carriage return, line feed or NUL,
%% each byte tested directly.
is_value(<<Byte, _/binary>>) when Byte =:= $\r; Byte =:= $\n; Byte =:= 0 -> false;
is_value(<<Byte, Rest/binary>>) when Byte < 128 -> is_value(Rest);
is_value(<<_/utf8, Rest/binary>>) -> is_value(Rest);
is_value(<<>>) -> true;
is_value(_) -> false.

trimmed(Value, Size) when Size > 0 ->
    case binary:at(Value, Size - 1) of
        Space when Space =:= $\s; Space =:= $\t -> trimmed(Value, Size - 1);
        _ -> binary:part(Value, 0, Size)
    end;
trimmed(_, 0) ->
    <<>>.

%% Appendix G.11: a target is written in the visible ASCII characters, RFC
%% 3986's, so a byte outside them, a raw UTF-8 one among them, is refused.
is_target(<<Byte, Rest/binary>>) when Byte >= 16#21, Byte =< 16#7E -> is_target(Rest);
is_target(<<>>) -> true;
is_target(_) -> false.
