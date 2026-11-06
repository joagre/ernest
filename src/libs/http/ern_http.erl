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

%% The bytes that part a request line's words: a space and a tab.
-define(IS_SPACE(Byte), (Byte =:= $\s orelse Byte =:= $\t)).

%% Appendix G.11: the request the bytes begin with, and the bytes after its
%% head, or `Incomplete`, or why the head is refused.
-spec parse_request(binary(), limits()) -> {'Right', parsed(request())} | {'Left', error()}.
parse_request(Bytes, Limits) ->
    parse(request, Bytes, Limits, 1).

%% Appendix G.11: the response the bytes begin with, as a request's.
-spec parse_response(binary(), limits()) -> {'Right', parsed(response())} | {'Left', error()}.
parse_response(Bytes, Limits) ->
    parse(response, Bytes, Limits, 0).

%% The host's `packet_size` is the most bytes of a line, its line ending
%% among them, and refuses a line that has passed it before its line feed
%% comes, so that a line is never read past the limit. Its 0 is no limit,
%% so a limit below 1, which no line of a byte or more is within, is
%% answered here.
%%
%% RFC 9112, section 2.2 has a server skip at least one empty line before a
%% request line, which the host reads as an error of its own; one is
%% skipped, within the line's limit as any line is, and a second is the
%% host's error, `Malformed`.
parse(_, <<>>, _, _) ->
    {'Right', 'Incomplete'};
parse(_, _, {'Limits', LineLimit, _}, _) when LineLimit < 1 ->
    {'Left', 'LineTooLong'};
parse(Kind, Bytes, {'Limits', LineLimit, _} = Limits, Skips) ->
    case erlang:decode_packet(http_bin, Bytes, [{packet_size, packet_size(LineLimit, Bytes)}]) of
        {more, _} ->
            {'Right', 'Incomplete'};
        {error, invalid} ->
            {'Left', 'LineTooLong'};
        {ok, {http_error, Empty}, Rest} when Skips > 0, Empty =:= <<"\r\n">>;
                                             Skips > 0, Empty =:= <<"\n">> ->
            parse(Kind, Rest, Limits, Skips - 1);
        {ok, First, Rest} ->
            Line = without_ending(binary:part(Bytes, 0, byte_size(Bytes) - byte_size(Rest))),
            case first(Kind, First, Line) of
                {ok, Head} -> headers(Kind, Rest, Limits, 0, Head, []);
                malformed -> {'Left', 'Malformed'}
            end
    end.

%% A limit the bytes are shorter than no line in them can pass, and is
%% given to the host as none, since the host takes no limit past 2^32 - 1.
packet_size(Limit, Bytes) when Limit > byte_size(Bytes) -> 0;
packet_size(Limit, _) -> Limit.

%% A line without its line feed and the carriage return before it.
without_ending(Line) ->
    Size = byte_size(Line) - 2,
    case Line of
        <<Content:Size/binary, "\r\n">> -> Content;
        <<Content:(Size + 1)/binary, "\n">> -> Content
    end.

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
%%
%% The host reads a version past its form too, `HTTP/1.1x` as 1.1 and
%% `HTTP/1.10` as 1.10, so the third word is read again as RFC 9112,
%% section 2.3 writes a version, `HTTP/`, a digit, `.` and a digit. And the
%% host reads a status of any count of digits, `0200` as 200, so the status
%% line's second word is read again too, as the three digits RFC 9112,
%% section 4 writes.
first(request, {http_request, _, _, {Major, Minor}}, Line) ->
    case words(Line, []) of
        [Method, Target, Version] ->
            case is_target(Target) andalso is_version(Version) of
                true -> {ok, {'Request', Method, Target, {'Version', Major, Minor}}};
                false -> malformed
            end;
        _ ->
            malformed
    end;
first(response, {http_response, {Major, Minor}, Status, _}, Line) ->
    case words(Line, []) of
        [_, Word | _] ->
            case is_status(Word) of
                true -> {ok, {'Response', {'Version', Major, Minor}, Status}};
                false -> malformed
            end;
        _ ->
            malformed
    end;
first(_, _, _) ->
    malformed.

%% The words of a line without its ending, at most four: the runs of bytes
%% between spaces and tabs, at which the host parts a request line. RFC
%% 9112, section 3 lets a recipient part one at a bare carriage return, a
%% vertical tab and a form feed too, which the host refuses between words;
%% so a bare carriage return stays in its word, where a target holds none.
%% Each byte is tested directly, as a fixed question is (docs/style.md).
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

%% Whether a word is a version, `HTTP/1.1`.
is_version(<<"HTTP/", Major, ".", Minor>>) ->
    Major >= $0 andalso Major =< $9 andalso Minor >= $0 andalso Minor =< $9;
is_version(_) ->
    false.

%% Whether a word is a status, three digits.
is_status(<<A, B, C>>) when A >= $0, A =< $9, B >= $0, B =< $9, C >= $0, C =< $9 -> true;
is_status(_) -> false.

%% Appendix G.11: the header lines to the empty one that ends the head,
%% each line within the line's limit and all of them, their line endings
%% counted, within the headers'. A header line is answered by the host once
%% the byte after it shows that the next line is no continuation of it.
headers(_, <<>>, _, _, _, _) ->
    {'Right', 'Incomplete'};
headers(Kind, Bytes, Limits, Taken, Head, Acc) ->
    case line_read(Bytes, room(Bytes, Limits, Taken)) of
        {more, _} ->
            {'Right', 'Incomplete'};
        {error, invalid} ->
            {'Left', 'HeadersTooLarge'};
        {ok, http_eoh, Rest} ->
            {'Right', {'Parsed', erlang:append_element(Head, lists:reverse(Acc)), Rest}};
        {ok, {http_header, _, _, Name, Value}, Rest} ->
            case header(Kind, Name, Value) of
                {ok, Header} ->
                    Size = byte_size(Bytes) - byte_size(Rest),
                    headers(Kind, Rest, Limits, Taken + Size, Head, [Header | Acc]);
                malformed ->
                    {'Left', 'Malformed'}
            end;
        {ok, {http_error, _}, _} ->
            {'Left', 'Malformed'}
    end.

%% The most bytes the line the bytes begin with may take: a header line the
%% headers' limit less what the lines before it took, or the line's limit
%% where that is less, so that the host refuses it at the bytes that pass
%% either; and the empty line that ends the head, which is no header line,
%% the line's limit.
room(Bytes, {'Limits', LineLimit, HeadersLimit}, Taken) ->
    case is_head_end(Bytes) of
        true -> LineLimit;
        false -> min(LineLimit, HeadersLimit - Taken)
    end.

%% Whether the bytes begin with the empty line, or with the carriage return
%% it may begin with, its line feed still to come.
is_head_end(<<"\n", _/binary>>) -> true;
is_head_end(<<"\r\n", _/binary>>) -> true;
is_head_end(<<"\r">>) -> true;
is_head_end(_) -> false.

%% The host's reading of the header line the bytes begin with, within the
%% room it may take. The host's 0 is no limit, so a room below 1, which no
%% line is within, is refused here as the host refuses a line past it.
line_read(_, Room) when Room < 1 ->
    {error, invalid};
line_read(Bytes, Room) ->
    erlang:decode_packet(httph_bin, Bytes, [{packet_size, packet_size(Room, Bytes)}]).

%% Appendix G.11: a header by its name as written, which the host answers
%% as the unmodified field, and its value without the white space around
%% it, which RFC 9112, section 5.1 leaves out of the value and the host
%% keeps after it. A header the host reads with no name is refused, as is a
%% value holding a carriage return or a line feed, which a header folded
%% over two lines holds, or a NUL, which RFC 9110, section 5.5 has a
%% recipient refuse, or one that is not UTF-8, which no `String` holds.
%%
%% In a response each fold is first replaced by a space (unfolded/1).
header(_, <<>>, _) ->
    malformed;
header(Kind, Name, Value) ->
    Read = case Kind of
               request -> Value;
               response -> unfolded(Value)
           end,
    case is_value(Read) of
        true -> {ok, {'Header', Name, trimmed(Read)}};
        false -> malformed
    end.

%% RFC 9112, section 5.2: a response's value with each fold, a line break
%% and the white space around it, replaced by one space, as a user agent
%% replaces it; the host answers a folded value with its line breaks.
unfolded(Value) ->
    Lines = binary:split(Value, [<<"\r\n">>, <<"\n">>], [global]),
    iolist_to_binary(lists:join(<<" ">>, [trimmed(Line) || Line <- Lines])).

%% Whether a value is UTF-8 and holds no carriage return, line feed or NUL,
%% each byte tested directly.
is_value(<<Byte, _/binary>>) when Byte =:= $\r; Byte =:= $\n; Byte =:= 0 -> false;
is_value(<<Byte, Rest/binary>>) when Byte < 128 -> is_value(Rest);
is_value(<<_/utf8, Rest/binary>>) -> is_value(Rest);
is_value(<<>>) -> true;
is_value(_) -> false.

%% The bytes without the spaces and tabs before and after them.
trimmed(<<Space, Rest/binary>>) when Space =:= $\s; Space =:= $\t ->
    trimmed(Rest);
trimmed(Bytes) ->
    trimmed_end(Bytes, byte_size(Bytes)).

trimmed_end(Bytes, Size) when Size > 0 ->
    case binary:at(Bytes, Size - 1) of
        Space when Space =:= $\s; Space =:= $\t -> trimmed_end(Bytes, Size - 1);
        _ -> binary:part(Bytes, 0, Size)
    end;
trimmed_end(_, 0) ->
    <<>>.

%% Appendix G.11: a target is written in the visible ASCII characters, RFC
%% 3986's, so a byte outside them, a raw UTF-8 one among them, is refused.
is_target(<<Byte, Rest/binary>>) when Byte >= 16#21, Byte =< 16#7E -> is_target(Rest);
is_target(<<>>) -> true;
is_target(_) -> false.
