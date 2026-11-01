%% The primitive behind Http's heads (report Appendix G.11), from the Erlang
%% side: where it closes the difference with the host's
%% `erlang:decode_packet/3`, and how the limits meet the host's
%% `packet_size`. Regression tests, written with the code; libs/http's own
%% cases run the same heads through the module's foreign functions.
-module(ern_http_tests).

-include_lib("eunit/include/eunit.hrl").

-define(LIMITS, {'Limits', 8192, 65536}).

%% report Appendix G.11: a request's method, target and header names as
%% the client wrote them, where the host answers atoms for those it knows,
%% the target parsed and a name it does not know recapitalized
as_written_test() ->
    ?assertEqual({'Right', {'Parsed', {'Request', <<"GET">>, <<"http://example.com/x?y">>,
                                       {'Version', 1, 1},
                                       [{'Header', <<"host">>, <<"example.com">>},
                                        {'Header', <<"Sec-WebSocket-Key">>, <<"k">>}]},
                            <<"body">>}},
                 request(<<"GET http://example.com/x?y HTTP/1.1\r\nhost: example.com\r\n"
                           "Sec-WebSocket-Key: k\r\n\r\nbody">>)),
    ?assertEqual([<<"get">>, <<"PATCH">>, <<"OPTIONS">>, <<"CONNECT">>],
                 [method(Line) || Line <- [<<"get / HTTP/1.1">>, <<"PATCH / HTTP/1.1">>,
                                           <<"OPTIONS * HTTP/1.1">>,
                                           <<"CONNECT example.com:443 HTTP/1.1">>]]),
    ?assertEqual([<<"*">>, <<"example.com:443">>, <<"/a%20b">>],
                 [target(Line) || Line <- [<<"OPTIONS * HTTP/1.1">>,
                                           <<"CONNECT example.com:443 HTTP/1.1">>,
                                           <<"GET /a%20b HTTP/1.1">>]]).

%% report Appendix G.11: a request line of no version, which the host reads
%% as HTTP/0.9's, `GET  HTTP/1.1` with the target `HTTP/1.1` among them, and
%% one of more than three words, whose rest the host drops
three_words_test() ->
    ?assertEqual({ok, {http_request, 'GET', <<"HTTP/1.1">>, {0, 9}}, <<>>},
                 erlang:decode_packet(http_bin, <<"GET  HTTP/1.1\r\n">>, [])),
    ?assertEqual([], [Line || Line <- [<<"GET  HTTP/1.1">>, <<"GET /">>, <<"GET / HTTP/1.1 x">>,
                                       <<"GET /a\rb HTTP/1.1">>],
                              request(<<Line/binary, "\r\n\r\n">>) =/= {'Left', 'Malformed'}]),
    ?assertEqual([{'Version', 0, 9}, {'Version', 2, 0}, {'Version', 1, 1}, {'Version', 1, 1}],
                 [version(Line) || Line <- [<<"GET / HTTP/0.9">>, <<"GET / HTTP/2.0">>,
                                            <<"GET  /x\tHTTP/1.1 ">>,
                                            <<"GET / HTTP/1.1\r">>]]).

%% report Appendix G.11: a header folded over two lines, which the host
%% answers as one value holding the line break, and a value holding a
%% carriage return, a NUL or bytes that are not UTF-8, which the host keeps
values_refused_test() ->
    ?assertMatch({ok, {http_header, _, <<"X">>, <<"X">>, <<"a\r\n b">>}, _},
                 erlang:decode_packet(httph_bin, <<"X: a\r\n b\r\n\r\n">>, [])),
    ?assertEqual([], [Value || Value <- [<<"a\r\n b">>, <<"a\r\n\tb">>, <<"a\rb">>, <<"a", 0, "b">>,
                                         <<"a", 255>>, <<"a", 16#c3>>],
                               request(<<"GET / HTTP/1.1\r\nX: ", Value/binary, "\r\n\r\n">>)
                                   =/= {'Left', 'Malformed'}]).

%% report Appendix G.11: a header line the host cannot read, with no `:`,
%% white space before it or a name that is no token, and one with no name,
%% which the host reads
names_refused_test() ->
    ?assertMatch({ok, {http_header, _, <<>>, <<>>, <<"a">>}, _},
                 erlang:decode_packet(httph_bin, <<": a\r\n\r\n">>, [])),
    ?assertEqual([], [Line || Line <- [<<"X">>, <<"X y: z">>, <<"Host : x">>, <<" Host: x">>,
                                       <<"X(y): z">>, <<": a">>],
                              request(<<"GET / HTTP/1.1\r\n", Line/binary, "\r\n\r\n">>)
                                  =/= {'Left', 'Malformed'}]).

%% report Appendix G.11: a value without the white space after it, which the
%% host keeps, and before it, which the host drops
white_space_test() ->
    ?assertMatch({ok, {http_header, _, _, _, <<"a b \t ">>}, _},
                 erlang:decode_packet(httph_bin, <<"X: \t a b \t \r\n\r\n">>, [])),
    ?assertEqual([{'Header', <<"X">>, <<"a b">>}, {'Header', <<"Y">>, <<>>}],
                 headers(request(<<"GET / HTTP/1.1\r\nX: \t a b \t \r\nY:   \r\n\r\n">>))).

%% report Appendix G.11: lines that end in a line feed alone
line_feeds_test() ->
    ?assertEqual(request(<<"GET / HTTP/1.1\r\nX: a\r\n\r\nrest">>),
                 request(<<"GET / HTTP/1.1\nX: a\n\nrest">>)).

%% report Appendix G.11: a status line's phrase dropped, an empty one among
%% them, and a request line refused as a response's first line, and the
%% other way
responses_test() ->
    ?assertEqual([{'Right', {'Parsed', {'Response', {'Version', 1, 1}, 404, []}, <<>>}},
                  {'Right', {'Parsed', {'Response', {'Version', 1, 0}, 200, []}, <<>>}},
                  {'Left', 'Malformed'}],
                 [ern_http:parse_response(Text, ?LIMITS)
                  || Text <- [<<"HTTP/1.1 404 \r\n\r\n">>, <<"HTTP/1.0 200 Very Fine\r\n\r\n">>,
                              <<"GET / HTTP/1.1\r\n\r\n">>]]),
    ?assertEqual({'Left', 'Malformed'}, request(<<"HTTP/1.1 200 OK\r\n\r\n">>)).

%% report Appendix G.11: a limit of a line counts its line ending, as the
%% host's packet_size does, and a line past it is refused before its line
%% feed comes
line_limit_test() ->
    Line = <<"GET /abcdefgh HTTP/1.1\r\n">>,
    ?assertEqual(24, byte_size(Line)),
    ?assertMatch({'Right', {'Parsed', _, <<>>}},
                 ern_http:parse_request(<<Line/binary, "\r\n">>, {'Limits', 24, 0})),
    ?assertEqual({'Left', 'LineTooLong'}, ern_http:parse_request(Line, {'Limits', 23, 0})),
    ?assertEqual({'Left', 'LineTooLong'},
                 ern_http:parse_request(<<"GET /abcdefghijklmnop">>, {'Limits', 21, 0})),
    ?assertEqual({'Right', 'Incomplete'},
                 ern_http:parse_request(<<"GET /abcdefghijklmnop">>, {'Limits', 22, 0})).

%% report Appendix G.11: a header line past the line's limit, and header
%% lines past the headers', their line endings counted, each found before
%% the head ends
headers_limit_test() ->
    Head = <<"GET / HTTP/1.1\r\nX: a\r\nY: b\r\n\r\n">>,
    ?assertMatch({'Right', {'Parsed', _, <<>>}}, ern_http:parse_request(Head, {'Limits', 16, 12})),
    ?assertEqual({'Left', 'HeadersTooLarge'}, ern_http:parse_request(Head, {'Limits', 16, 11})),
    ?assertEqual({'Left', 'HeadersTooLarge'},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: abcdefghijklmnopq\r\n\r\n">>,
                                        {'Limits', 16, 100})),
    ?assertEqual({'Left', 'HeadersTooLarge'},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: abcdefghijklm">>,
                                        {'Limits', 16, 100})),
    ?assertEqual({'Right', 'Incomplete'},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: abcdefghijkl">>,
                                        {'Limits', 16, 100})),
    ?assertEqual({'Left', 'HeadersTooLarge'},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: a\r\nY">>, {'Limits', 16, 5})).

%% report Appendix G.11, §7.4: a limit below 1, the host's 0 being none, and
%% one past the most the host takes, 2^32 - 1
limits_test() ->
    ?assertEqual({'Left', 'LineTooLong'}, ern_http:parse_request(<<"G">>, {'Limits', 0, 0})),
    ?assertEqual({'Left', 'LineTooLong'}, ern_http:parse_request(<<"G">>, {'Limits', -1, 0})),
    ?assertEqual({'Right', 'Incomplete'}, ern_http:parse_request(<<>>, {'Limits', 0, 0})),
    ?assertEqual({'Left', 'HeadersTooLarge'},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: a\r\n\r\n">>, {'Limits', 100, -1})),
    ?assertMatch({'Right', {'Parsed', _, <<>>}},
                 ern_http:parse_request(<<"GET / HTTP/1.1\r\nX: a\r\n\r\n">>,
                                        {'Limits', 1 bsl 40, 1 bsl 40})).

%% report Appendix G.11: a head short of its empty line is incomplete, a
%% header line among it, which the host answers once the byte after it
%% shows that no continuation follows
incomplete_test() ->
    Head = <<"GET / HTTP/1.1\r\nHost: example.com\r\n\r\n">>,
    ?assertEqual([], [Size || Size <- lists:seq(0, byte_size(Head) - 1),
                              request(binary:part(Head, 0, Size)) =/= {'Right', 'Incomplete'}]).

request(Bytes) ->
    ern_http:parse_request(Bytes, ?LIMITS).

head(Line) ->
    {'Right', {'Parsed', Request, _}} = request(<<Line/binary, "\r\n\r\n">>),
    Request.

method(Line) -> element(2, head(Line)).

target(Line) -> element(3, head(Line)).

version(Line) -> element(4, head(Line)).

headers({'Right', {'Parsed', {'Request', _, _, _, Headers}, _}}) -> Headers.
