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
    Lines = [string:lexemes(Line, " ") || Line <- string:lexemes(binary_to_list(Text), "\n")],
    Server = spawn(fun serve/0),
    Operations = operations(Server),
    io:format("~-40s ~9s ~9s ~7s~n", ["ns an iteration", "Ernest", "Erlang", "ratio"]),
    lists:foreach(fun([Key, Iterations, Ms]) ->
                      {Name, Operation} = maps:get(Key, Operations),
                      Count = list_to_integer(Iterations),
                      Ernest = list_to_integer(Ms) * 1.0e6 / Count,
                      Erlang = fastest(Count, Operation),
                      io:format("~-40s ~9.1f ~9.1f ~7.1f~n",
                                [Name, Ernest, Erlang, Ernest / Erlang])
                  end, Lines),
    halt(0).

%% Each key of bench.ern, what it measures, and the operation in Erlang.
operations(Server) ->
    Point = {'Point', 1, 2},
    Map = #{1 => 2, 3 => 4},
    Numbers = lists:seq(1, 100),
    %% made at run time, as the Ernest program makes its own, so that the
    %% host's compiler folds no operation on them into a literal
    Left = binary:copy(<<"ab">>),
    Right = binary:copy(<<"cd">>),
    Bytes = binary:copy(<<"abcd">>),
    Tail = lists:seq(1, 10),
    Path = <<"srv/site">>,
    Ended = ended(),
    #{"loop" => {"the loop alone", fun(Iteration) -> Iteration end},
      "operator" => {"a record added by a function",
                     fun(Iteration) ->
                         {'Point', SumX, _} = add({'Point', Iteration, 1}, Point),
                         SumX
                     end},
      "equal" => {"two records compared",
                  fun(Iteration) ->
                      case {'Point', Iteration, 2} =:= Point of
                          true -> 1;
                          false -> 0
                      end
                  end},
      "map_get" => {"Map.get, maps:find",
                    fun(Iteration) ->
                        case maps:find(Iteration rem 4, Map) of
                            {ok, Value} -> Value;
                            error -> 0
                        end
                    end},
      "map_put" => {"Map.put, maps:put",
                    fun(Iteration) -> map_size(maps:put(Iteration rem 8, Iteration, Map)) end},
      "list_map" => {"List.map over 100, lists:map",
                     fun(Iteration) ->
                         hd(lists:map(fun(Number) -> Number + Iteration end, Numbers))
                     end},
      "list_size" => {"List.size of 100, length",
                      fun(Iteration) -> length(Numbers) + Iteration end},
      "string_size" => {"String.size, string:length",
                        fun(Iteration) -> string:length(Left) + Iteration end},
      "string_append" => {"<> and String.size",
                          fun(Iteration) ->
                              string:length(<<Left/binary, Right/binary>>) + Iteration
                          end},
      "bytes_size" => {"Bytes.size, byte_size",
                       fun(Iteration) -> byte_size(Bytes) + Iteration end},
      "send" => {"send and receive to self",
                 fun(Iteration) ->
                     self() ! {'Ping', Iteration},
                     receive
                         {'Ping', Echo} -> Echo
                     end
                 end},
      "call" => {"a call answered, as gen_server's",
                 fun(Iteration) -> call(Server) + Iteration end},
      "spawn" => {"spawn a process that returns",
                  fun(Iteration) ->
                      spawn(fun() -> ok end),
                      Iteration
                  end},
      %% report §9.4 to §9.6, MVP 2.99d's item 2: the rest of the prelude
      "self" => {"self", fun(Iteration) -> _ = self(), Iteration end},
      "spawn_monitored" => {"spawnMonitored, its Down received",
                            fun(Iteration) ->
                                {_, MonitorRef} = spawn_monitor(fun() -> ok end),
                                receive {'DOWN', MonitorRef, _, _, _} -> Iteration end
                            end},
      "show" => {"Io.show of an Int, integer_to_binary",
                 fun(Iteration) ->
                     case integer_to_binary(Iteration) of
                         <<>> -> 0;
                         _ -> Iteration
                     end
                 end},
      "adapted" => {"a send through an adapted address, a tagged send",
                    fun(Iteration) ->
                        self() ! {'Ping', Iteration},
                        receive {'Ping', Echo} -> Echo end
                    end},
      "call_within" => {"Address.call with a limit, a call with after",
                        fun(Iteration) -> call(Server, 1000) + Iteration end},
      "monitor" => {"monitor an ended process, its Down received",
                    fun(Iteration) ->
                        MonitorRef = erlang:monitor(process, Ended),
                        receive {'DOWN', MonitorRef, _, _, _} -> Iteration end
                    end},
      "kill" => {"kill an ended process", fun(Iteration) -> exit(Ended, kill), Iteration end},
      "list_append" => {"List.<> of 10 and 10, ++",
                        fun(Iteration) -> length(Tail ++ Tail) + Iteration end},
      "bytes_append" => {"Bytes.<>, a binary built",
                         fun(Iteration) ->
                             byte_size(<<Bytes/binary, Bytes/binary>>) + Iteration
                         end},
      "path_join" => {"Path.<>, filename:join",
                      fun(Iteration) ->
                          case filename:join(Path, <<"index.html">>) of
                              Path -> 0;
                              _ -> Iteration
                          end
                      end},
      "int_compare" => {"Int.compare, a comparison",
                        fun(Iteration) when Iteration < 5000000 -> 1;
                           (_) -> 0
                        end},
      "string_compare" => {"String.compare, a function comparing binaries",
                           fun(Iteration) ->
                               case ordering(Left, Right) of
                                   'Less' -> Iteration;
                                   _ -> 0
                               end
                           end},
      "float_times" => {"Float.*, *", fun(Iteration) -> trunc(float(Iteration) * 1.5) end},
      "int_divide" => {"Int./ and Int.%, div and rem",
                       fun(Iteration) -> Iteration div 3 + Iteration rem 7 end},
      "restarting" => {"restarting entered and returning, a try",
                       fun(Iteration) ->
                           try ok catch _:_ -> ok end,
                           Iteration
                       end}}.

%% The order of two terms, as a `compare` answers it.
ordering(Left, Right) when Left < Right -> 'Less';
ordering(Left, Right) when Left > Right -> 'Greater';
ordering(_, _) -> 'Equal'.

%% A process that has ended, which a monitor reports at once.
ended() ->
    {Pid, MonitorRef} = spawn_monitor(fun() -> ok end),
    receive {'DOWN', MonitorRef, _, _, _} -> Pid end.

add({'Point', LeftX, LeftY}, {'Point', RightX, RightY}) ->
    {'Point', LeftX + RightX, LeftY + RightY}.

%% A call as gen:do_call/4 makes one with a limit: the answer, or `none`
%% when the limit passes first.
call(Server, Ms) ->
    MonitorRef = erlang:monitor(process, Server, [{alias, demonitor}]),
    Server ! {get, MonitorRef},
    receive
        {MonitorRef, Value} ->
            erlang:demonitor(MonitorRef, [flush]),
            Value;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            exit(ExitReason)
    after Ms ->
        erlang:demonitor(MonitorRef, [flush]),
        0
    end.

%% A call as gen:do_call/4 makes one: a monitor that is the reply's alias.
call(Server) ->
    MonitorRef = erlang:monitor(process, Server, [{alias, demonitor}]),
    Server ! {get, MonitorRef},
    receive
        {MonitorRef, Value} ->
            erlang:demonitor(MonitorRef, [flush]),
            Value;
        {'DOWN', MonitorRef, _, _, ExitReason} ->
            exit(ExitReason)
    end.

serve() ->
    receive
        {get, Reply} ->
            Reply ! {Reply, 1},
            serve()
    end.

%% The fastest of three timings of Count iterations, in nanoseconds an
%% iteration.
fastest(Count, Operation) ->
    lists:min([duration(Count, Operation) || _ <- [1, 2, 3]]) / Count.

%% The nanoseconds Count iterations of Operation take.
duration(Count, Operation) ->
    Start = erlang:monotonic_time(nanosecond),
    _ = loop(Count, Operation, 0),
    erlang:monotonic_time(nanosecond) - Start.

loop(0, _, Acc) -> Acc;
loop(Count, Operation, Acc) -> loop(Count - 1, Operation, Acc + Operation(Count)).
