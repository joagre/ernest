%%
%% The web server with sessions, in idiomatic Erlang, for comparison with
%% webserver.ern. It uses gen_tcp directly where the Ernest version assumes
%% Sys.net, and a session process where the Ernest version has since moved to
%% an ETS table. The measured comparison is in docs/webserver_comparison.md.
%%

-module(webserver).
-export([main/0]).

%% Pure code: HTTP parsing and sessions ---------------------------

%% request: {request, Method, Path, Headers}
%% response: {response, StatusCode, Headers, Body}

status_ok() -> 200.
status_not_found() -> 404.
render_status(N) -> integer_to_binary(N).

parse(Bytes) ->
    case unicode:characters_to_binary(Bytes) of
        {error, _, _} -> {error, bad_encoding};
        {incomplete, _, _} -> {error, bad_encoding};
        Text -> parse_lines(binary:split(Text, <<"\r\n">>, [global]))
    end.

parse_lines(Lines) ->
    case request_line(Lines) of
        {error, E} -> {error, E};
        {ok, {Method, Path}} ->
            case header_lines(Lines) of
                {error, E} -> {error, E};
                {ok, Headers} -> {ok, {request, Method, Path, Headers}}
            end
    end.

request_line([First | _]) ->
    case binary:split(First, <<" ">>, [global]) of
        [M, P, _] -> {ok, {M, P}};
        _ -> {error, bad_request_line}
    end;
request_line([]) -> {error, bad_request_line}.

header_lines([_ | Rest]) -> header_lines(Rest, []).
header_lines([], Acc) -> {ok, lists:reverse(Acc)};
header_lines([<<>> | _], Acc) -> {ok, lists:reverse(Acc)};
header_lines([L | Rest], Acc) ->
    case binary:split(L, <<": ">>) of
        [K, V] -> header_lines(Rest, [{K, V} | Acc]);
        _ -> {error, {bad_header, L}}
    end.

render({response, Status, Headers, Body}) ->
    [<<"HTTP/1.1 ">>, render_status(Status), <<" \r\n">>,
     [[K, <<": ">>, V, <<"\r\n">>] || {K, V} <- Headers],
     <<"\r\n">>, Body].

cookie({request, _, _, Headers}, Name) ->
    case lists:keyfind(<<"Cookie">>, 1, Headers) of
        false -> none;
        {_, V} ->
            case [X || <<N:(byte_size(Name))/binary, "=", X/binary>> <- binary:split(V, <<"; ">>, [global]), N =:= Name] of
                [X | _] -> {some, X};
                [] -> none
            end
    end.

with_cookie(Name, Value, {response, S, H, B}) ->
    {response, S, [{<<"Set-Cookie">>, <<Name/binary, "=", Value/binary>>} | H], B}.

session_fresh(N) -> integer_to_binary(N).
session_parse(T) ->
    case re:run(T, <<"^[0-9]+$">>) of
        nomatch -> none;
        _ -> {some, T}
    end.
session_text(T) -> T.

%% The session process --------------------------------------------

sessions(Store, Counter) ->
    receive
        {lookup, Id, Reply} ->
            Reply ! {found_session, maps:get(Id, Store, none)},
            sessions(Store, Counter);
        {put, Id, S} ->
            sessions(maps:put(Id, S, Store), Counter);
        sweep ->
            sessions(#{}, Counter)
    end.

%% The sweeper -----------------------------------------------------

sweeper(Sess) ->
    erlang:send_after(600000, self(), tick),
    receive tick -> Sess ! sweep end,
    sweeper(Sess).

%% One process per connection --------------------------------------

handler(Sess, Seq, Sock) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {error, _} ->
            gen_tcp:close(Sock);
        {ok, Bytes} ->
            case parse(Bytes) of
                {error, _} ->
                    gen_tcp:send(Sock, render({response, status_not_found(), [], <<>>})),
                    gen_tcp:close(Sock);
                {ok, Req} ->
                    Id = case cookie(Req, <<"sid">>) of
                             {some, T} ->
                                 case session_parse(T) of
                                     {some, Sid} -> Sid;
                                     none -> session_fresh(Seq)
                                 end;
                             none -> session_fresh(Seq)
                         end,
                    Sess ! {lookup, Id, self()},
                    receive
                        {found_session, S} ->
                            Visits = case S of {session, N} -> N + 1; none -> 1 end,
                            Sess ! {put, Id, {session, Visits}},
                            Body = <<"Visit number ", (integer_to_binary(Visits))/binary>>,
                            gen_tcp:send(Sock, render(with_cookie(<<"sid">>, session_text(Id),
                                                        {response, status_ok(), [], Body}))),
                            gen_tcp:close(Sock)
                    after 5000 ->
                        gen_tcp:close(Sock)
                    end
            end
    end.

%% Acceptor ------------------------------------------------------

acceptor(Sess, Seq, Listen) ->
    case gen_tcp:accept(Listen) of
        {ok, Sock} ->
            spawn(fun() -> handler(Sess, Seq, Sock) end),
            acceptor(Sess, Seq + 1, Listen);
        {error, _} ->
            acceptor(Sess, Seq, Listen)
    end.

main() ->
    Sess = spawn(fun() -> sessions(#{}, 0) end),
    spawn(fun() -> sweeper(Sess) end),
    {ok, Listen} = gen_tcp:listen(8080, [binary, {active, false}]),
    acceptor(Sess, 0, Listen).
