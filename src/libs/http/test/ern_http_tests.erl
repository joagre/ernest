%% The primitives behind Http's heads (report Appendix G.11), from the
%% Erlang side: each line of a head as the host's `erlang:decode_packet/3`
%% reads it, and the readings the library's Ernest reads again, where the
%% host reads a line past the form RFC 9112 writes. Written with the
%% code; libs/http's own cases read the same heads
%% through the module's Ernest.
%%
%% And a request's head and its body read from a loopback socket as they
%% come in pieces, by the library's unit called from Erlang, which
%% libs/http's own cases cannot pace; those cases hold the rules.
-module(ern_http_tests).

-include_lib("eunit/include/eunit.hrl").

%% eunit's time for one test, which no test here outlasts: the
%% milliseconds a socket's step is given where its time is not what the
%% test holds.
-define(MS, 5000).

%% Http.defaultLimits.
-define(LIMITS, {'Limits', 8192, 65536}).

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

%% report Appendix G.11: a regression test, written after the code: a
%% method or a header's name holding U+007F, which the host's table reads as
%% a token's, is answered as a line the host cannot read. It does not cover
%% a known method, which the host answers as an atom of its own
delete_test() ->
    ?assertEqual({'Unreadable', <<"G", 127, "T / HTTP/1.1\r\n">>, <<"\r\n">>},
                 ern_http:read_first(<<"G", 127, "T / HTTP/1.1\r\n\r\n">>, 0)),
    ?assertEqual({'Unreadable', <<"X", 127, "Y: a\r\n">>, <<"\r\n">>},
                 ern_http:read_field(<<"X", 127, "Y: a\r\n\r\n">>, 0)),
    ?assertMatch({'Field', <<"X">>, <<"a", 127>>, _},
                 ern_http:read_field(<<"X: a", 127, "\r\n\r\n">>, 0)).

%% report Appendix G.11: a regression test, written after the code: a
%% request's head that comes in pieces, cut inside the request line, inside
%% a header's name, between a line's carriage return and its line feed and
%% before the empty line, with bytes after the head in the last piece, is
%% read whole, and those bytes are answered after it. Each piece is written
%% once the reader has taken the one before, so no read takes two. It does
%% not cover a response's head through `readResponse`, a piece that a limit
%% passes inside, nor `carried`.
head_in_pieces_test() ->
    Pieces = [<<"GET /pie">>, <<"ces HTTP/1.1\r\nHo">>, <<"st: example.com\r">>,
              <<"\nAccept: */*\r\n">>, <<"\r\nnext">>],
    Writer = spawn(fun() -> written_one_by_one(Pieces) end),
    Request = {'Request', <<"GET">>, <<"/pieces">>, {'Version', 1, 1},
               [{'Header', <<"Host">>, <<"example.com">>}, {'Header', <<"Accept">>, <<"*/*">>}]},
    ?assertEqual({ok, {'Right', {Request, <<"next">>}}}, served(Writer, request_head())).

%% report Appendix G.11: a regression test, written after the code: a
%% request's body that comes in pieces is read whole, and the bytes after
%% it in the last piece are answered after it: one of a `Content-Length`,
%% part of it carried, and a chunked one, cut inside a chunk's size, inside
%% its extension, inside its bytes, between a chunk's carriage return and
%% its line feed, inside the trailers and between the empty line's carriage
%% return and its line feed. It does not cover a response's body, read by
%% the same reader, nor a limit or a close met inside a piece.
body_in_pieces_test() ->
    Sized = [{'Header', <<"Content-Length">>, <<"11">>}],
    SizedWriter = spawn(fun() -> written_one_by_one([<<"lo w">>, <<"orl">>, <<"dGET /">>]) end),
    ?assertEqual({ok, {'Right', {<<"hello world">>, <<"GET /">>}}},
                 served(SizedWriter, request_body(<<"hel">>, Sized))),
    Chunked = [{'Header', <<"Transfer-Encoding">>, <<"chunked">>}],
    Chunks = [<<"A;name=va">>, <<"lue\r\nabcdefghijklm">>, <<"nopqrstuvwxyz\r">>,
              <<"\n4\r\nWiki\r\n0\r\nExpi">>, <<"res: never\r\n\r">>, <<"\nnext">>],
    ChunkedWriter = spawn(fun() -> written_one_by_one(Chunks) end),
    ?assertEqual({ok, {'Right', {<<"abcdefghijklmnopqrstuvwxyzWiki">>, <<"next">>}}},
                 served(ChunkedWriter, request_body(<<"1">>, Chunked))).

%% A read of a request's head.
request_head() ->
    ReadRequest = (http())(readRequest),
    fun(Socket) -> ReadRequest(Socket, <<>>, ?LIMITS, ?MS) end.

%% A read of the body of a POST request carrying Headers, after the bytes
%% Carried.
request_body(Carried, Headers) ->
    ReadRequestBody = (http())(readRequestBody),
    Request = {'Request', <<"POST">>, <<"/">>, {'Version', 1, 1}, Headers},
    fun(Socket) -> ReadRequestBody(Socket, Carried, Request, 1000, ?MS) end.

%% The outcome of a program that reads from a connection Writer makes, and
%% what Read answered given the program's socket. Writer is told the port
%% and the reader, then that the read begins, and once the program has
%% ended that the reader has answered; the test waits for its end.
served(Writer, Read) ->
    Self = self(),
    Tcp = ern_named:functions('ern@tcp'),
    Result = ern_rt:run_main(
               fun() ->
                   {'Right', Listener} = Tcp(listen)(<<"127.0.0.1">>, 0),
                   {'Right', Port} = Tcp(port)(Listener),
                   Writer ! {port, Port, self()},
                   {'Right', Server} = Tcp(accept)(Listener, ?MS),
                   Writer ! reading,
                   Self ! {read, Read(Server)}
               end, <<"served">>, #{}),
    MonitorRef = erlang:monitor(process, Writer),
    Writer ! answered,
    receive {'DOWN', MonitorRef, process, Writer, _} -> ok end,
    {Result, receive {read, Answer} -> Answer after 0 -> none end}.

%% Http's functions by their Ernest names, its unit loaded once from its
%% .erc under the library's build, as a program's load path gives it: it is
%% no unit of the toolchain's own, which ern_named finds alone
%% (ern_code:own_file/1).
http() ->
    case erlang:module_loaded('ern@http') of
        true ->
            ok;
        false ->
            Erc = filename:join(ern_tree:build("libs/http"), "http.erc"),
            {ok, Bytes} = file:read_file(Erc),
            {module, 'ern@http'} = code:load_binary('ern@http', Erc, Bytes)
    end,
    ern_named:functions('ern@http').

%% A writer's connection to the port it is told, and the reader it is
%% told of, once the read begins.
connected() ->
    {Port, Reader} = receive {port, Told, Process} -> {Told, Process} end,
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port,
                                   [binary, {active, false}, {nodelay, true}]),
    receive reading -> ok end,
    {Socket, Reader}.

%% The pieces written one at a time, each once the reader has taken the one
%% before, which the host shows as the socket's answer to its read put in
%% the reader's mailbox, a call's reply answered `Right`. The reader is sent
%% other messages as it reads, a code server's reply and a timeout among
%% them, which are passed by. A piece the host split in two would let the
%% next reach a read with the second half, which holds less and fails
%% nothing.
written_one_by_one(Pieces) ->
    {Socket, Reader} = connected(),
    MonitorRef = erlang:monitor(process, Reader),
    try erlang:trace(Reader, true, ['receive']) of
        _ -> taken_one_by_one(Socket, Reader, MonitorRef, Pieces)
    catch
        error:badarg -> ended
    end,
    receive answered -> gen_tcp:close(Socket) end.

taken_one_by_one(_, _, _, []) ->
    ok;
taken_one_by_one(Socket, Reader, MonitorRef, [Piece | Pieces]) ->
    _ = gen_tcp:send(Socket, Piece),
    receive
        {trace, Reader, 'receive', {_, answered, {'Right', _}}} ->
            taken_one_by_one(Socket, Reader, MonitorRef, Pieces);
        {'DOWN', MonitorRef, process, Reader, _} -> ended
    end.
