# Comparison: The Web Server in Ernest and in Erlang

The same program, the same structure, the same error handling: a session process, a sweeper, one handler per connection, an acceptor, parsing with three failing steps, timeouts on the client and on the session lookup. The Ernest version is the process version that [`ernest-webserver.md`](ernest-webserver.md) had at the time; that document has since moved the session store to an ETS table, which the Erlang version below also could, and the comparison is of the two process versions. The Erlang version below uses `gen_tcp` directly where Ernest assumes `net`.

Counted: lines without blank lines and comments, and characters without indentation. Only the parts fully written in both.

| Part | Ernest lines | Erlang lines | Ernest chars | Erlang chars |
|---|---|---|---|---|
| Processes (sessions, sweeper, handler, acceptor, main) | 61 | 59 | 2022 | 1464 |
| of which type signatures and type declarations | 11 | 0 | 473 | 0 |
| Processes without signatures | 50 | 59 | 1549 | 1464 |
| parse + parseLines | 10 | 8 | 342 | 231 |
| handler alone | 31 | 32 | 971 | 768 |

## Where the Difference Lies

The same number of lines. More characters in Ernest, and they can be pointed out:

1. **Type signatures and type declarations: 473 characters.** Erlang has none. That is not verbosity, it is the language; an Erlang programmer writing `-spec` and `-type` for the same thing lands on the same figure. Without them Ernest is six percent longer than Erlang in the process part.
2. **The filter in selective receive: about 45 characters each time, twice.** `(m -> match m { Data b -> Some b | _ -> None })` against Erlang's pattern directly in `receive`. That is the only per-use cost that is large. Data, not decision.
3. **`Got` and `Timeout`: four lines.** Erlang's `after` is one line. The same number of arms; Ernest's carry one more word.
4. **`Sys { clock = clock, net = net }`: one line, 35 characters.** Erlang has `gen_tcp` as a global name.
5. **`via X self`: twice, ten characters in total.** Erlang sends `self()`.
6. **`StatusCode.notFound`, `SessionId.fresh seq`: longer names.** Erlang has `status_not_found()`; about equal.

What Erlang lacks and therefore does not pay for: the encapsulation of `SessionId` is a convention in Erlang (`session_parse` can be bypassed), and `{found_session, S}` in `receive` accepts anything with that tag. Ernest's characters buy that the compiler knows what `S` is.

## Conclusion

Afterwards: `recv` was made a form with arms and `after`, like Erlang's `receive`, and the syntax switched to n-ary functions with parentheses (revision 3). The table is from before both; with parentheses in types and calls the Ernest version is a few percent longer in characters than then, and the same number of lines.

### The conclusion that led there

Without type signatures: six percent more characters, the same number of lines, and almost the whole difference is the filter lambda in `recvFor`. None of the five suspects (`via`, `sys`, match instead of `=`, one function per failing step, field functions) shows up in the figures as more than a line each. What shows is what was not on the list: the filter. If anything is to get shorter it is there.

## The Erlang Version

```erlang
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
```
