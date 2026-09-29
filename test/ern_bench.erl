%% `make bench` (docs/development.md): the operations of bench/bench.ern,
%% each written as Erlang writes it, run as the Ernest program runs them,
%% the fastest of three runs of a loop, and printed beside what the Ernest
%% program took, in nanoseconds an iteration, the loop's own cost included
%% on both sides. It measures and asserts nothing, so it is not part of
%% `make test`.
-module(ern_bench).

-export([main/1]).

%% Prints the table for the Ernest program's lines in File, `key n ms` each,
%% and halts.
-spec main([string()]) -> no_return().
main([File]) ->
    {ok, Text} = file:read_file(File),
    Lines = [string:lexemes(L, " ") || L <- string:lexemes(binary_to_list(Text), "\n")],
    Server = spawn(fun serve/0),
    Ops = operations(Server),
    io:format("~-40s ~9s ~9s ~7s~n", ["ns an iteration", "Ernest", "Erlang", "ratio"]),
    lists:foreach(fun([Key, N, Ms]) ->
                          {Name, F} = maps:get(Key, Ops),
                          Count = list_to_integer(N),
                          Ernest = list_to_integer(Ms) * 1.0e6 / Count,
                          Erlang = fastest(Count, F),
                          io:format("~-40s ~9.1f ~9.1f ~7.1f~n",
                                    [Name, Ernest, Erlang, Ernest / Erlang])
                  end, Lines),
    halt(0).

%% Each key of bench.ern, what it measures, and the operation in Erlang.
operations(Server) ->
    P = {'Point', 1, 2},
    M = #{1 => 2, 3 => 4},
    Xs = lists:seq(1, 100),
    A = <<"ab">>,
    B = <<"cd">>,
    Bytes = <<"abcd">>,
    #{"loop" => {"the loop alone", fun(I) -> I end},
      "operator" => {"a record added by a function",
                     fun(I) -> element(2, add({'Point', I, 1}, P)) end},
      "equal" => {"two records compared",
                  fun(I) ->
                          case {'Point', I, 2} =:= P of
                              true -> 1;
                              false -> 0
                          end
                  end},
      "map_get" => {"Map.get, maps:find",
                    fun(I) ->
                            case maps:find(I rem 4, M) of
                                {ok, V} -> V;
                                error -> 0
                            end
                    end},
      "map_put" => {"Map.put, maps:put", fun(I) -> map_size(maps:put(I rem 8, I, M)) end},
      "list_map" => {"List.map over 100, lists:map",
                     fun(I) -> hd(lists:map(fun(X) -> X + I end, Xs)) end},
      "list_size" => {"List.size of 100, length", fun(I) -> length(Xs) + I end},
      "string_size" => {"String.size, string:length", fun(I) -> string:length(A) + I end},
      "string_append" => {"<> and String.size",
                          fun(I) -> string:length(<<A/binary, B/binary>>) + I end},
      "bytes_size" => {"Bytes.size, byte_size", fun(I) -> byte_size(Bytes) + I end},
      "send" => {"send and receive to self",
                 fun(I) ->
                         self() ! {'Ping', I},
                         receive
                             {'Ping', K} -> K
                         end
                 end},
      "call" => {"a call answered, as gen_server's", fun(I) -> call(Server) + I end},
      "spawn" => {"spawn a process that returns",
                  fun(I) ->
                          spawn(fun() -> ok end),
                          I
                  end}}.

add({'Point', X1, Y1}, {'Point', X2, Y2}) -> {'Point', X1 + X2, Y1 + Y2}.

%% A call as gen:do_call/4 makes one: a monitor that is the reply's alias.
call(Server) ->
    Ref = erlang:monitor(process, Server, [{alias, demonitor}]),
    Server ! {get, Ref},
    receive
        {Ref, V} ->
            erlang:demonitor(Ref, [flush]),
            V;
        {'DOWN', Ref, _, _, Reason} ->
            exit(Reason)
    end.

serve() ->
    receive
        {get, Ref} ->
            Ref ! {Ref, 1},
            serve()
    end.

%% The fastest of three runs of N iterations, in nanoseconds an iteration.
fastest(N, F) ->
    lists:min([run(N, F) || _ <- [1, 2, 3]]) / N.

run(N, F) ->
    Start = erlang:monotonic_time(nanosecond),
    _ = loop(N, F, 0),
    erlang:monotonic_time(nanosecond) - Start.

loop(0, _, Acc) -> Acc;
loop(N, F, Acc) -> loop(N - 1, F, Acc + F(N)).
