%% The primitives behind Http's heads (report Appendix G.11), from the
%% Erlang side: each line of a head as the host's `erlang:decode_packet/3`
%% reads it, and the readings the library's Ernest reads again, where the
%% host reads a line past the form RFC 9112 writes. Regression tests,
%% written with the code; libs/http's own cases read the same heads
%% through the module's Ernest.
-module(ern_http_tests).

-include_lib("eunit/include/eunit.hrl").

%% report Appendix G.11: a first line, a request line or a status line,
%% with its version, a status line's status and the bytes after it, the
%% method, the target and the phrase left out
first_line_test() ->
    ?assertEqual({'RequestLine', 1, 1, <<"Host: a\r\n">>},
                 ern_http:read_first(<<"GET http://example.com/x?y HTTP/1.1\r\nHost: a\r\n">>, 0)),
    ?assertEqual({'StatusLine', 1, 0, 404, <<>>},
                 ern_http:read_first(<<"HTTP/1.0 404 Not Found\r\n">>, 0)),
    ?assertEqual({'Unreadable', <<"\r\n">>, <<"GET">>}, ern_http:read_first(<<"\r\nGET">>, 0)),
    ?assertEqual({'Unreadable', <<"X: a\r\n">>, <<"\r\n">>},
                 ern_http:read_first(<<"X: a\r\n\r\n">>, 0)),
    ?assertEqual('More', ern_http:read_first(<<"GET / HTTP/1.1\r">>, 0)).

%% report Appendix G.11: a header line by its name as written, where the
%% host recapitalizes a name, its value with the white space after it,
%% which the host keeps, and the empty line, the head's end. A header line
%% is answered once the byte after it shows that no continuation follows
field_line_test() ->
    ?assertEqual({'Field', <<"sec-websocket-key">>, <<"k \t">>, <<"\r\n">>},
                 ern_http:read_field(<<"sec-websocket-key: \t k \t\r\n\r\n">>, 0)),
    ?assertEqual({'Field', <<"host">>, <<"a">>, <<"X">>}, ern_http:read_field(<<"host: a\nX">>, 0)),
    ?assertEqual({'HeadEnd', <<"body">>}, ern_http:read_field(<<"\r\nbody">>, 0)),
    ?assertEqual('More', ern_http:read_field(<<"X: a\r\n">>, 0)),
    ?assertEqual([{'Unreadable', <<Line/binary, "\r\n">>, <<"\r\n">>}
                  || Line <- [<<"X">>, <<"X y: z">>, <<"Host : x">>, <<" Host: x">>,
                              <<"X(y): z">>, <<"X", 255, ": a">>]],
                 [ern_http:read_field(<<Line/binary, "\r\n\r\n">>, 0)
                  || Line <- [<<"X">>, <<"X y: z">>, <<"Host : x">>, <<" Host: x">>,
                              <<"X(y): z">>, <<"X", 255, ": a">>]]).

%% report Appendix G.11: the host's packet_size counts a line's ending, and
%% a line past it is refused before its line feed comes
size_test() ->
    Line = <<"GET /abcdefgh HTTP/1.1\r\n">>,
    ?assertEqual(24, byte_size(Line)),
    ?assertMatch({'RequestLine', 1, 1, <<>>}, ern_http:read_first(Line, 24)),
    ?assertEqual('TooLong', ern_http:read_first(Line, 23)),
    ?assertEqual('TooLong', ern_http:read_first(<<"GET /abcdefghijklmnop">>, 21)),
    ?assertEqual('More', ern_http:read_first(<<"GET /abcdefghijklmnop">>, 22)),
    ?assertEqual('TooLong', ern_http:read_field(<<"X: abcdefghijklm">>, 16)),
    ?assertEqual('More', ern_http:read_field(<<"X: abcdefghijkl">>, 16)).

%% report Appendix G.11: what the Ernest reads again of a request line. The
%% host reads a line of no version as HTTP/0.9's, `GET  HTTP/1.1` with the
%% target `HTTP/1.1` among them, and a bare carriage return in a target;
%% it drops the words after the third, and reads a version past its form
request_line_read_again_test() ->
    ?assertEqual({ok, {http_request, 'GET', <<"HTTP/1.1">>, {0, 9}}, <<>>},
                 erlang:decode_packet(http_bin, <<"GET  HTTP/1.1\r\n">>, [])),
    ?assertMatch({ok, {http_request, 'GET', {abs_path, <<"/a\rb">>}, {0, 9}}, _},
                 erlang:decode_packet(http_bin, <<"GET /a\rb\r\n">>, [])),
    ?assertEqual([{'RequestLine', 1, 1, <<>>}, {'RequestLine', 1, 1, <<>>}],
                 [ern_http:read_first(Line, 0)
                  || Line <- [<<"GET / HTTP/1.1 x\r\n">>, <<"GET / HTTP/1.1x\r\n">>]]).

%% report Appendix G.11: what the Ernest reads again of a status line: the
%% host reads a status of any count of digits, dropping a leading zero
status_line_read_again_test() ->
    ?assertEqual([{'StatusLine', 1, 1, 200, <<>>}, {'StatusLine', 1, 1, 20, <<>>}],
                 [ern_http:read_first(Line, 0)
                  || Line <- [<<"HTTP/1.1 0200 OK\r\n">>, <<"HTTP/1.1 20 OK\r\n">>]]).

%% report Appendix G.11: what the Ernest reads again of a header: the host
%% reads a header with no name, and answers a folded value with its line
%% break and a value with a NUL or bytes that are not UTF-8 as written
values_read_again_test() ->
    ?assertEqual({'Field', <<>>, <<"a">>, <<"\r\n">>}, ern_http:read_field(<<": a\r\n\r\n">>, 0)),
    ?assertEqual([{'Field', <<"X">>, Value, <<"\r\n">>}
                  || Value <- [<<"a\r\n b">>, <<"a\rb">>, <<"a", 0, "b">>, <<"a", 255>>]],
                 [ern_http:read_field(<<"X: ", Value/binary, "\r\n\r\n">>, 0)
                  || Value <- [<<"a\r\n b">>, <<"a\rb">>, <<"a", 0, "b">>, <<"a", 255>>]]).
