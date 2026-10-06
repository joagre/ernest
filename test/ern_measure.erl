%% `make bench`'s second half (docs/development.md), MVP 2.99d's item 1:
%% every exported function of the standard library and the libraries
%% measured beside the host's, so that what Ernest adds to the host's work
%% shows (Appendix E.0 rule 1, CLAUDE.md's cost rule). A function
%% that needs no process is called with arguments drawn from its type, at
%% 10, 100 and 10,000 elements, graphemes or bytes, and timed beside the
%% host's function that does the same work, where one does (hosts/0), and
%% by its own growth. A function that needs a process is timed in a
%% scenario of its own beside the host's operation it stands on
%% (scenarios/1), by what Ernest adds. All of it runs in one launch, so the
%% system processes and the modules' bindings are those a program has.
%% Beside the time, what each call allocates, against the host's, with no
%% line of its own yet (allocated/1). Time is the wall clock's, which holds
%% what a call waits for as well as what it computes; the load average
%% before the run says whether the machine was idle. It prints what is
%% past the line, and the whole table into the file given, and asserts
%% nothing: a function past the line is the user's decision.
%% ern_measure_tests holds that every function is measured or listed with
%% the reason it is not, and that each call made here runs.
-module(ern_measure).

-export([main/1, entries/0, measured/2]).

-include_lib("kernel/include/file.hrl").
-include_lib("typer/include/ern_types.hrl").

%% The machine's line, for what to look at: E.0 rule 1 has none since MVP
%% 2.99d's item 12, deciding by whether a host function does the work. Past
%% it, the Ernest form costs more than three times the host's at the sizes
%% a program meets, or grows with what the host's does not. Growth is judged from 100 to 10,000: at
%% least tenfold, and more than three times the host's own where hosts/0
%% names one, since at 10,000 the host's memory makes a linear operation
%% grow by several hundred; where none does, above what a sort with that
%% grows by, and near the line between.
-define(HOST_LINE, 3.0).
-define(HOST_GROWTH_LINE, 3.0).
%% growth below this is no growth with the input: a constant cost's noise
-define(GROWTH_FLOOR, 10.0).
-define(GROWTH_LINE, 1000.0).
-define(GROWTH_NEAR, 300.0).
%% The prelude's line (CLAUDE.md, plan MVP 2.99d item 2), which a system
%% module's function is held to by what Ernest adds to the host's work.
-define(SYSTEM_LINE, 2.0).
-define(SIZES, [10, 100, 10000]).
%% A timing runs its call until this many nanoseconds have passed, the
%% fastest of three such runs kept.
-define(RUN_NS, 1000000).
-define(SLOW_NS, 500000000).
%% The heap, in words, a call's allocation is counted in, which grows
%% eightfold where a collection still runs, up to the last.
-define(FIRST_HEAP, 1048576).
-define(LAST_HEAP, 67108864).

%% Prints the summary, and writes the whole table into File.
-spec main([string()]) -> no_return().
main([File]) ->
    Load = load(),
    Rows = measured(?SIZES, timed),
    ok = file:write_file(File, [load_text(Load), [row_text(Row) || Row <- Rows]]),
    io:put_chars([load_text(Load), summary(Rows)]),
    io:format("The whole table is in ~s.~n", [File]),
    halt(0).

%% Every exported function, each as the interface of its module states it:
%% #{module, name, display, scheme, kind}, kind being `pure`, `process`
%% for a function whose effect is process-only or a mailbox type, and
%% `value` for a top-level binding, which is no function and is left out.
-spec entries() -> [map()].
entries() ->
    lists:sort(fun(A, B) -> maps:get(display, A) =< maps:get(display, B) end,
               [Entry || Interface <- interfaces(), Entry <- entries(Interface)]).

entries(#interface{namespace = Namespace, values = Values, lets = Lets}) ->
    [#{module => ern_namespace:erlang_module(Namespace),
       name => lists:last(QualifiedName),
       display => display(QualifiedName),
       scheme => Scheme,
       kind => kind(QualifiedName, Scheme, Lets)}
     || {QualifiedName, Scheme} <- maps:to_list(Values)].

kind(QualifiedName, #scheme{quantified = Quantified, type = {tfn, _, Effect, _}}, Lets) ->
    case lists:member(QualifiedName, Lets) of
        true -> value;
        false -> effect_kind(Effect, Quantified)
    end;
kind(_, _, _) ->
    value.

%% Report §3.9: an effect variable that is process-only, and a mailbox
%% type, need a process; an effect variable a callback brings does not.
effect_kind(pure, _) -> pure;
effect_kind({tvar, Id}, Quantified) ->
    case lists:member(process_only, proplists:get_value(Id, Quantified, [])) of
        true -> process;
        false -> pure
    end;
effect_kind(_, _) -> process.

display(QualifiedName) ->
    lists:join(".", [atom_to_list(Part) || Part <- QualifiedName]).

%% The standard library's interfaces and the libraries', each library's
%% module loaded from its .erc, as a program's load path would give it.
interfaces() ->
    ern_prelude:stdlib_interfaces() ++ [library(Erc) || Erc <- library_files()].

library_files() ->
    Root = filename:dirname(filename:dirname(filename:dirname(
                                                filename:dirname(code:which(ern_rt))))),
    lists:sort(filelib:wildcard(filename:join([Root, "build", "libs", "*", "*.erc"]))).

library(Erc) ->
    {ok, Bytes} = file:read_file(Erc),
    {ok, #{interface := #interface{namespace = Namespace} = Interface}} = ern_interface:read(Bytes),
    Module = ern_namespace:erlang_module(Namespace),
    {module, Module} = code:load_binary(Module, Erc, Bytes),
    Interface.

%%
%% Measuring
%%

%% Each function's row at Sizes, in one launch: a pure function's by its
%% generated arguments, a process's by its scenario, each with the host's
%% where there is one. Mode `timed` times them; `once` makes each call once
%% at the first size, for ern_measure_tests.
-spec measured([pos_integer()], timed | once) -> [map()].
measured(Sizes, Mode) ->
    Self = self(),
    Entries = entries(),
    Dir = scratch(),
    ok = filelib:ensure_path(Dir),
    Options = #{stdout => fun(_) -> ok end, stderr => fun(_) -> ok end, exit => fault},
    try
        ok = ern_rt:run_main(fun() -> Self ! {rows, rows(Entries, Sizes, Mode, Dir)} end,
                             <<"ern_measure">>, Options),
        receive {rows, Rows} -> Rows after 0 -> error(no_rows) end
    after
        file:del_dir_r(Dir)
    end.

rows(Entries, Sizes, Mode, Dir) ->
    ern_rt:init_modules([Module || Module <- library_modules()]),
    Types = types(),
    Scenarios = scenarios(Dir),
    {Counter, Stop} = counter(),
    try [row(Entry, Sizes, Mode, Types, Scenarios, Counter) || Entry <- Entries]
    after Stop()
    end.

library_modules() ->
    [begin
         {ok, Bytes} = file:read_file(Erc),
         {ok, #{interface := #interface{namespace = Namespace}}} = ern_interface:read(Bytes),
         ern_namespace:erlang_module(Namespace)
     end || Erc <- library_files()].

row(#{kind := value} = Entry, _, _, _, _, _) ->
    Entry#{outcome => {not_measured, <<"a top-level binding, no function">>}};
row(#{display := Display} = Entry, Sizes, Mode, Types, Scenarios, Counter) ->
    Name = iolist_to_binary(Display),
    case {maps:get(kind, Entry), lists:keyfind(Name, 1, Scenarios)} of
        {_, {Name, Scenario}} -> Entry#{outcome => scenario(Scenario, Mode, Counter)};
        {process, false} -> Entry#{outcome => not_listed};
        {pure, false} -> Entry#{outcome => pure_row(Entry, Sizes, Mode, Types, Counter)}
    end.

%% A pure function at each size: its time, the host's where hosts/0 names
%% one, and whether either faulted on the arguments drawn.
pure_row(#{module := Module, name := Name, scheme := Scheme, display := Display}, Sizes,
         Mode, Types, Counter) ->
    Host = maps:get(iolist_to_binary(Display), hosts(), none),
    try
        {timed, [sized(Module, Name, Scheme, Size, Mode, Types, Host, Counter)
                 || Size <- Sizes]}
    catch
        throw:{no_value, Type} ->
            {not_measured, iolist_to_binary(io_lib:format("no argument drawn for ~p", [Type]))};
        Class:Reason ->
            {failed, iolist_to_binary(io_lib:format("~p:~p", [Class, Reason]))}
    end.

sized(Module, Name, Scheme, Size, Mode, Types, Host, Counter) ->
    Arguments = arguments(Module, Name, Scheme, Size, Types),
    Ernest = fun() -> erlang:apply(Module, Name, Arguments) end,
    HostCall = case Host of
                   none -> none;
                   _ -> fun() -> erlang:apply(Host, Arguments) end
               end,
    %% the largest size once where one call takes SLOW_NS, which a function
    %% that grows fast makes long
    Timing = case {Mode, Size} of
                 {timed, 10000} -> large;
                 _ -> Mode
             end,
    {Size, time(Ernest, Timing), time(HostCall, Timing), allocated(Ernest, Counter),
     allocated(HostCall, Counter)}.

time(none, _) -> none;
time(Call, once) -> _ = Call(), 0;
time(Call, timed) -> lists:min([run(Call) || _ <- [1, 2, 3]]);
time(Call, large) ->
    case run(Call) of
        Slow when Slow >= ?SLOW_NS -> Slow;
        First -> lists:min([First, run(Call), run(Call)])
    end.

%% The nanoseconds a call takes, over as many calls as fill RUN_NS, or one
%% call where one takes longer.
run(Call) ->
    Start = erlang:monotonic_time(nanosecond),
    _ = Call(),
    First = erlang:monotonic_time(nanosecond) - Start,
    case First >= ?RUN_NS of
        true -> First;
        false -> run(Call, 1, Start)
    end.

run(Call, Count, Start) ->
    Elapsed = erlang:monotonic_time(nanosecond) - Start,
    case Elapsed >= ?RUN_NS of
        true ->
            Elapsed / Count;
        false ->
            _ = Call(),
            run(Call, Count + 1, Start)
    end.

%% What the host's side of a scenario gives, measured as foreign code.
foreign(none, _) -> none;
foreign(Host, Measure) -> ern_rt:in_foreign(fun() -> Measure(Host) end).

%% The bytes a call allocates, counted in the process that makes it, since
%% a port's or a socket's answers come to the process that opened it. The
%% process is traced by the collector's events, its heap made too large for
%% a collection to start during the call, and collected before and after
%% it: what the heap holds as the second collection starts, its fragments
%% and the binaries it holds off the heap among it, beside what the first
%% left, is what was allocated, less what an empty call's measurement
%% allocates. A collection that runs during the call all the same counts
%% the call again in a heap eight times larger, and past the last the
%% allocation is `{more_than, Bytes}`.
allocated(none, _) -> none;
allocated(Call, Counter) -> Counter(Call).

%% A counter of allocations, with its tracer and its baseline, and the
%% function that stops the tracer.
counter() ->
    Tracer = erlang:spawn(fun() -> tracer([]) end),
    Baseline = counted(fun() -> ok end, Tracer, ?FIRST_HEAP),
    Count = fun(Call) ->
                    case counted(Call, Tracer, ?FIRST_HEAP) of
                        {more_than, _} = Bound -> Bound;
                        Bytes -> max(Bytes - Baseline, 0)
                    end
            end,
    {Count, fun() -> exit(Tracer, kill) end}.

counted(Call, Tracer, Heap) ->
    ern_rt:in_foreign(fun() -> counted_now(Call, Tracer, Heap) end).

counted_now(Call, Tracer, Heap) ->
    MinHeap = erlang:process_flag(min_heap_size, Heap),
    MinBinHeap = erlang:process_flag(min_bin_vheap_size, Heap),
    _ = erlang:trace(erlang:self(), true, [garbage_collection, {tracer, Tracer}]),
    erlang:garbage_collect(),
    _ = Call(),
    erlang:garbage_collect(),
    _ = erlang:trace(erlang:self(), false, [garbage_collection]),
    erlang:process_flag(min_heap_size, MinHeap),
    erlang:process_flag(min_bin_vheap_size, MinBinHeap),
    Events = events(Tracer),
    erlang:garbage_collect(),
    case {Events, Heap < ?LAST_HEAP} of
        {[{gc_major_start, _}, {gc_major_end, Left}, {gc_major_start, Holds}, {gc_major_end, _}],
         _} ->
            (words(Holds) - words(Left)) * erlang:system_info(wordsize);
        {_, true} ->
            counted_now(Call, Tracer, Heap * 8);
        {_, false} ->
            {more_than, Heap * erlang:system_info(wordsize)}
    end.

words(Info) ->
    lists:sum([proplists:get_value(Key, Info, 0) || Key <- [heap_size, mbuf_size, bin_vheap_size]]).

%% The collector's events since the last asking, each delivered first.
events(Tracer) ->
    Ref = erlang:trace_delivered(erlang:self()),
    receive {trace_delivered, _, Ref} -> ok end,
    Tracer ! {events, erlang:self()},
    receive {events, Tracer, Events} -> Events end.

tracer(Events) ->
    receive
        {trace, _, Event, Info} -> tracer([{Event, Info} | Events]);
        {events, Asker} -> Asker ! {events, erlang:self(), lists:reverse(Events)}, tracer([])
    end.

%% A scenario at its one size: the Ernest operation and the host's, each
%% given its setup and cleanup, the host's run as foreign code, since it
%% may wait in a receive the runtime does not watch (report §8.6).
scenario({within, Other}, _, _) ->
    {within, Other};
scenario({not_measured, Reason}, _, _) ->
    {not_measured, Reason};
scenario({Ernest, Host}, Mode, Counter) ->
    try
        {system, time(Ernest, Mode), foreign(Host, fun(Call) -> time(Call, Mode) end),
         allocated(Ernest, Counter), allocated(Host, Counter)}
    catch
        Class:Reason ->
            {failed, iolist_to_binary(io_lib:format("~p:~p", [Class, Reason]))}
    end.

%%
%% Arguments drawn from a type
%%

types() ->
    lists:foldl(fun(#interface{types = Types}, Acc) -> maps:merge(Acc, Types) end, #{},
                interfaces()).

%% The arguments the function's type asks for, then a member for each its
%% requirement names (report §4.9). The first, the function's subject, is
%% drawn at Size, and the rest at 10 at most, as a separator, a part or a
%% second set is. Every type variable is an `Int`, so `compare` is
%% `Int.compare`, and `show` the descriptor that shows any value.
arguments(Module, Name, #scheme{type = {tfn, Params, _, _}, requirement = Requirement},
          Size0, Types) ->
    Size = case small(Module, Name) of
               true -> min(Size0, 10);
               false -> Size0
           end,
    Drawn = case {scaled(Module, Name), Params} of
                {_, []} -> [];
                {true, [_ | Rest]} -> [digits(Size) | others(Rest, Size, Types)];
                {false, [Subject | Rest]} ->
                    [value(Subject, Size, Types) | others(Rest, Size, Types)]
            end,
    Drawn ++ [member(Member) || {_, Member} <- Requirement].

others(Params, Size, Types) ->
    [value(Param, min(Size, 10), Types) || Param <- Params].

%% A function whose subject cannot grow: an atom holds 255 characters.
small('ern@erl', atom) -> true;
small(_, _) -> false.

member(compare) -> fun 'ern@int':compare/2;
member(show) -> any.

%% The functions whose cost is their integer's length, measured on one of
%% Size digits; every other `Int` is a small count or index.
scaled('ern@int', toString) -> true;
scaled('ern@int', toStringBase) -> true;
scaled(_, _) -> false.

digits(Size) ->
    binary_to_integer(binary:copy(<<"7">>, Size)).

value({tvar, _}, _, _) -> 7;
value({tcon, ['Int'], []}, _, _) -> 7;
value({tcon, ['Float'], []}, _, _) -> 1.5;
value({tcon, ['String'], []}, Size, _) -> text(Size);
value({tcon, ['Bytes'], []}, Size, _) -> binary:copy(<<"x">>, Size);
value({tcon, ['Char'], []}, _, _) -> $a;
value({tcon, ['Bool'], []}, _, _) -> true;
value({tcon, ['Unit'], []}, _, _) -> 'Unit';
value({tcon, ['Ordering'], []}, _, _) -> 'Less';
value({tcon, ['Path'], []}, Size, _) -> {'Path', path(Size)};
value({tcon, ['List'], [Element]}, Size, Types) -> elements(Element, Size, Types);
value({tcon, ['Optional'], [Element]}, Size, Types) -> {'Some', value(Element, Size, Types)};
value({tcon, ['Either'], [_, Element]}, Size, Types) -> {'Right', value(Element, Size, Types)};
value({tcon, ['Map'], [Key, Element]}, Size, Types) ->
    maps:from_list(pairs(Key, Element, Size, Types));
value({tcon, ['Set'], [Element]}, Size, Types) ->
    'ern@set':fromList(elements(Element, Size, Types));
value({tcon, ['OrderedSet', 'Set'], [Element]}, Size, Types) ->
    'ern@ordered_set':fromList(elements(Element, Size, Types), fun 'ern@int':compare/2);
value({tcon, ['OrderedMap', 'Map'], [Key, Element]}, Size, Types) ->
    'ern@ordered_map':fromList(pairs(Key, Element, Size, Types), fun 'ern@int':compare/2);
value({tcon, ['Random', 'Seed'], []}, _, _) -> 'ern@random':seed(1);
value({tcon, ['Foreign', 'Term'], []}, Size, _) -> lists:seq(1, Size);
value({ttuple, Elements}, Size, Types) ->
    list_to_tuple([value(Element, Size, Types) || Element <- Elements]);
value({tfn, [_, _], _, {tcon, ['Ordering'], []}}, _, _) ->
    fun ordered/2;
value({tfn, Params, _, {tcon, ['Bool'], []}}, _, _) ->
    half(length(Params));
value({tfn, Params, _, Result}, _, Types) ->
    callback(length(Params), value(Result, 1, Types));
value({tcon, QualifiedName, _} = Type, Size, Types) ->
    constructed(maps:get(QualifiedName, Types, none), Type, Size, Types).

%% A value of a declared type: its first constructor, its fields drawn
%% from their types in declared order.
constructed(#type_info{constructors = [#constructor_info{} = Constructor | _]}, _, Size, Types) ->
    case Constructor of
        #constructor_info{name = Name, scheme = #scheme{type = {tfn, Fields, _, _}}} ->
            list_to_tuple([Name | [value(Field, Size, Types) || Field <- Fields]]);
        #constructor_info{name = Name} ->
            Name
    end;
constructed(_, Type, _, _) ->
    throw({no_value, Type}).

%% Size elements, distinct where the type lets them be, so that a set or a
%% map's keys are Size of them, and in an order of their hashes, the same
%% each run, so that a sort meets no run the host's would read as sorted.
elements({tvar, _}, Size, _) -> shuffled(lists:seq(1, Size));
elements({tcon, ['Int'], []}, Size, _) -> shuffled(lists:seq(1, Size));
elements({tcon, ['String'], []}, Size, _) ->
    [integer_to_binary(I) || I <- shuffled(lists:seq(1, Size))];
elements({tcon, ['Char'], []}, Size, _) -> [$a + I rem 26 || I <- shuffled(lists:seq(1, Size))];
elements(Type, Size, Types) -> lists:duplicate(Size, value(Type, 1, Types)).

shuffled(List) ->
    [Element || {_, Element} <- lists:sort([{erlang:phash2(Element), Element} || Element <- List])].

pairs(Key, Element, Size, Types) ->
    lists:zip(elements(Key, Size, Types), lists:duplicate(Size, value(Element, 1, Types))).

%% An order on any value drawn, the host's order of terms, which for the
%% values drawn is each type's own: a comparison that is no order measures a
%% sort that need not do its work (report §3.10).
ordered(Left, Right) when Left < Right -> 'Less';
ordered(Left, Right) when Left > Right -> 'Greater';
ordered(_, _) -> 'Equal'.

%% A test that holds for about half of what it is given, by its first
%% argument's hash, so that a filter keeps some and drops some.
half(1) -> fun(Value) -> erlang:phash2(Value) rem 2 =:= 0 end;
half(2) -> fun(Value, _) -> erlang:phash2(Value) rem 2 =:= 0 end;
half(3) -> fun(_, Value, _) -> erlang:phash2(Value) rem 2 =:= 0 end.

callback(0, Result) -> fun() -> Result end;
callback(1, Result) -> fun(_) -> Result end;
callback(2, Result) -> fun(_, _) -> Result end;
callback(3, Result) -> fun(_, _, _) -> Result end.

%% Size graphemes of plain words, a space between.
text(Size) ->
    Words = binary:copy(<<"words ">>, Size div 6 + 1),
    binary:part(Words, 0, Size).

%% A relative path of about Size bytes, in segments.
path(Size) ->
    Segments = binary:copy(<<"seg/">>, max(Size div 4, 1)),
    <<Segments/binary, "name.txt">>.

%%
%% Hosts: the host's function that does the same work as a pure function,
%% given the same arguments. A function absent here is judged by its growth
%% alone.
%%

hosts() ->
    #{<<"List.size">> => fun erlang:length/1,
      <<"List.isEmpty">> => fun(List) -> List =:= [] end,
      <<"List.contains">> => fun(List, X) -> lists:member(X, List) end,
      <<"List.get">> => fun(List, Index) -> lists:nth(min(Index + 1, length(List)), List) end,
      <<"List.map">> => fun(List, F) -> lists:map(F, List) end,
      <<"List.filter">> => fun(List, Keep) -> lists:filter(Keep, List) end,
      <<"List.filterMap">> => fun(List, F) -> lists:filtermap(fun(X) -> some(F(X)) end, List) end,
      <<"List.foldLeft">> => fun(List, Acc, Step) -> lists:foldl(fun(X, A) -> Step(A, X) end,
                                                                 Acc, List) end,
      <<"List.foldRight">> => fun(List, Acc, Step) -> lists:foldr(Step, Acc, List) end,
      <<"List.foreach">> => fun(List, F) -> lists:foreach(F, List) end,
      <<"List.any">> => fun(List, Test) -> lists:any(Test, List) end,
      <<"List.all">> => fun(List, Test) -> lists:all(Test, List) end,
      <<"List.find">> => fun(List, Test) -> lists:search(Test, List) end,
      <<"List.last">> => fun(List) -> lists:last(List) end,
      <<"List.take">> => fun(List, Count) -> lists:sublist(List, Count) end,
      <<"List.drop">> => fun(List, Count) -> lists:nthtail(min(Count, length(List)), List) end,
      <<"List.span">> => fun(List, Test) -> lists:splitwith(Test, List) end,
      <<"List.partition">> => fun(List, Test) -> lists:partition(Test, List) end,
      <<"List.remove">> => fun(List, X) -> lists:delete(X, List) end,
      <<"List.reverse">> => fun lists:reverse/1,
      <<"List.sort">> => fun(List, Compare) ->
                                 lists:sort(fun(A, B) -> Compare(A, B) =/= 'Greater' end, List)
                         end,
      <<"List.zip">> => fun(List, Other) -> lists:zip(List, Other, trim) end,
      <<"List.unzip">> => fun lists:unzip/1,
      <<"List.flatMap">> => fun(List, F) -> lists:flatmap(F, List) end,
      <<"List.range">> => fun lists:seq/2,
      <<"List.repeat">> => fun(X, Count) -> lists:duplicate(Count, X) end,
      <<"List.indexed">> => fun(List) -> lists:enumerate(0, List) end,
      <<"String.size">> => fun string:length/1,
      <<"String.isEmpty">> => fun(Text) -> Text =:= <<>> end,
      <<"String.toUpper">> => fun string:uppercase/1,
      <<"String.toLower">> => fun string:lowercase/1,
      <<"String.reverse">> => fun string:reverse/1,
      <<"String.trim">> => fun(Text) -> string:trim(Text) end,
      <<"String.trimStart">> => fun(Text) -> string:trim(Text, leading) end,
      <<"String.trimEnd">> => fun(Text) -> string:trim(Text, trailing) end,
      <<"String.split">> => fun(Text, Separator) -> string:split(Text, Separator, all) end,
      <<"String.join">> => fun(Parts, Separator) -> iolist_to_binary(lists:join(Separator, Parts))
                           end,
      <<"String.contains">> => fun(Text, Part) -> string:find(Text, Part) =/= nomatch end,
      <<"String.startsWith">> => fun(Text, Prefix) -> string:prefix(Text, Prefix) =/= nomatch end,
      <<"String.replace">> => fun(Text, Old, New) -> string:replace(Text, Old, New, all) end,
      <<"String.toList">> => fun(Text) -> unicode:characters_to_list(Text) end,
      <<"String.graphemes">> => fun(Text) -> string:to_graphemes(Text) end,
      <<"String.lines">> => fun(Text) -> string:split(Text, <<"\n">>, all) end,
      <<"String.toInt">> => fun(Text) -> try binary_to_integer(Text) catch _:_ -> none end end,
      <<"String.toFloat">> => fun(Text) -> try binary_to_float(Text) catch _:_ -> none end end,
      <<"String.fromUtf8">> => fun(Bytes) -> unicode:characters_to_binary(Bytes) end,
      <<"String.toUtf8">> => fun(Text) -> Text end,
      <<"Map.size">> => fun maps:size/1,
      <<"Map.isEmpty">> => fun(Map) -> map_size(Map) =:= 0 end,
      <<"Map.contains">> => fun(Map, Key) -> maps:is_key(Key, Map) end,
      <<"Map.get">> => fun(Map, Key) -> maps:find(Key, Map) end,
      <<"Map.put">> => fun(Map, Key, Value) -> maps:put(Key, Value, Map) end,
      <<"Map.remove">> => fun(Map, Key) -> maps:remove(Key, Map) end,
      <<"Map.keys">> => fun maps:keys/1,
      <<"Map.values">> => fun maps:values/1,
      <<"Map.toList">> => fun maps:to_list/1,
      <<"Map.fromList">> => fun maps:from_list/1,
      <<"Map.map">> => fun(Map, F) -> maps:map(F, Map) end,
      <<"Map.filter">> => fun(Map, Keep) -> maps:filter(Keep, Map) end,
      <<"Map.foldLeft">> => fun(Map, Acc, Step) -> maps:fold(fun(K, V, A) -> Step(A, K, V) end,
                                                              Acc, Map) end,
      <<"Map.merge">> => fun maps:merge/2,
      <<"Set.size">> => fun(Set) -> map_size(set_map(Set)) end,
      <<"Bytes.size">> => fun erlang:byte_size/1,
      <<"Bytes.isEmpty">> => fun(Bytes) -> Bytes =:= <<>> end,
      <<"Bytes.toList">> => fun erlang:binary_to_list/1,
      <<"Bytes.slice">> => fun(Bytes, Index, Count) ->
                                   binary:part(Bytes, min(Index, byte_size(Bytes)),
                                               min(Count, byte_size(Bytes) - Index))
                           end,
      <<"Bytes.split">> => fun(Bytes, Separator) -> binary:split(Bytes, Separator, [global]) end,
      <<"Bytes.contains">> => fun(Bytes, Part) -> binary:match(Bytes, Part) =/= nomatch end,
      <<"Int.toString">> => fun erlang:integer_to_binary/1,
      <<"Int.toStringBase">> => fun(Int, Base) -> integer_to_binary(Int, Base) end,
      <<"Int.abs">> => fun erlang:abs/1,
      <<"Int.max">> => fun erlang:max/2,
      <<"Int.min">> => fun erlang:min/2,
      <<"Int.toFloat">> => fun erlang:float/1,
      <<"Float.abs">> => fun erlang:abs/1,
      <<"Float.sqrt">> => fun math:sqrt/1,
      <<"Float.floor">> => fun erlang:floor/1,
      <<"Float.ceil">> => fun erlang:ceil/1,
      <<"Float.round">> => fun erlang:round/1,
      <<"Float.toString">> => fun erlang:float_to_binary/1,
      <<"Char.toUpper">> => fun(Char) -> hd(string:uppercase([Char])) end,
      <<"Char.toLower">> => fun(Char) -> hd(string:lowercase([Char])) end,
      <<"Char.toInt">> => fun(Char) -> Char end,
      <<"Path.toString">> => fun({'Path', Text}) -> Text end,
      <<"Path.name">> => fun({'Path', Text}) -> filename:basename(Text) end,
      <<"Path.parent">> => fun({'Path', Text}) -> filename:dirname(Text) end,
      <<"Path.extension">> => fun({'Path', Text}) -> filename:extension(Text) end,
      <<"Path.segments">> => fun({'Path', Text}) -> filename:split(Text) end}.

some({'Some', Value}) -> {true, Value};
some('None') -> false.

%% A Set is the host's map, its elements the keys (report Appendix E.0,
%% Appendix E.9).
set_map(Set) when is_map(Set) -> Set;
set_map({_, Map}) when is_map(Map) -> Map.

%%
%% Scenarios: a function that needs a process, as {Ernest, Host} closures
%% over what Dir holds, Host `none` where no one operation of the host's
%% does the same work; {within, Other} where another's scenario measures
%% it; and {not_measured, Reason}.
%%

-define(SIZE, 100).

scenarios(Dir) ->
    Self = erlang:self(),
    Bytes = binary:copy(<<"x">>, ?SIZE),
    DevNull = dev_null(),
    lists:append([clock_scenarios(Self), fs_scenarios(Dir, Bytes), io_scenarios(Bytes, DevNull),
                  os_scenarios(Bytes), process_scenarios(), supervisor_scenarios(),
                  tcp_scenarios(Bytes), terminal_scenarios(), ets_scenarios()]).

dev_null() ->
    {ok, Fd} = file:open("/dev/null", [write, raw, binary]),
    Fd.

clock_scenarios(_Self) ->
    Wrap = fun(Time) -> Time end,
    [{<<"Clock.now">>, {fun 'ern@clock':now/0, fun() -> erlang:system_time(millisecond) end}},
     {<<"Clock.monotonic">>,
      {fun 'ern@clock':monotonic/0, fun() -> erlang:monotonic_time(millisecond) end}},
     {<<"Clock.alarm">>, {fun() -> 'ern@clock':alarm(3600000, Wrap) end,
                          fun() -> erlang:send_after(3600000, erlang:self(), alarm) end}},
     {<<"Clock.alarmAt">>,
      {fun() -> 'ern@clock':alarmAt(erlang:system_time(millisecond) + 3600000, Wrap) end,
       fun() -> erlang:send_after(3600000, erlang:self(), alarm) end}}].

fs_scenarios(Dir, Bytes) ->
    In = fun(Name) -> filename:join(Dir, Name) end,
    P = fun(Name) -> {'Path', list_to_binary(In(Name))} end,
    ok = file:write_file(In("file"), Bytes),
    ok = filelib:ensure_path(In("dir")),
    [ok = file:write_file(filename:join(In("dir"), integer_to_list(I)), <<>>)
     || I <- lists:seq(1, ?SIZE)],
    ok = file:make_symlink(In("file"), In("link")),
    Fs = 'ern@fs',
    [{<<"Fs.read">>, {fun() -> Fs:read(P("file"), 5000) end,
                      fun() -> file:read_file(In("file"), [raw]) end}},
     {<<"Fs.readRange">>,
      {fun() -> Fs:readRange(P("file"), 0, ?SIZE, 5000) end,
       fun() ->
               {ok, Fd} = file:open(In("file"), [read, raw, binary]),
               {ok, _} = file:pread(Fd, 0, ?SIZE),
               file:close(Fd)
       end}},
     {<<"Fs.write">>, {fun() -> Fs:write(P("written"), Bytes, 5000) end,
                       fun() -> file:write_file(In("written"), Bytes, [raw]) end}},
     {<<"Fs.append">>, {fun() -> Fs:append(P("appended"), Bytes, 5000) end,
                        fun() -> file:write_file(In("appended"), Bytes, [append, raw]) end}},
     {<<"Fs.list">>, {fun() -> Fs:list(P("dir"), 5000) end,
                      fun() ->
                              {ok, Names} = file:list_dir(In("dir")),
                              [file:read_link_info(filename:join(In("dir"), Name), [raw])
                               || Name <- Names]
                      end}},
     {<<"Fs.stat">>, {fun() -> Fs:stat(P("file"), 5000) end,
                      fun() -> file:read_link_info(In("file"), [raw]) end}},
     {<<"Fs.makeDir">>, {fun() -> Fs:makeDir(P("made"), 5000), file:del_dir(In("made")) end,
                         fun() -> file:make_dir(In("made")), file:del_dir(In("made")) end}},
     {<<"Fs.remove">>,
      {fun() -> file:write_file(In("removed"), <<>>), Fs:remove(P("removed"), 5000) end,
       fun() -> file:write_file(In("removed"), <<>>), file:delete(In("removed"), [raw]) end}},
     {<<"Fs.rename">>,
      {fun() ->
               Fs:rename(P("file"), P("renamed"), 5000),
               Fs:rename(P("renamed"), P("file"), 5000)
       end,
       fun() ->
               file:rename(In("file"), In("renamed")),
               file:rename(In("renamed"), In("file"))
       end}},
     {<<"Fs.copy">>, {fun() -> Fs:copy(P("file"), P("copied"), 5000) end,
                      fun() -> file:copy(In("file"), In("copied")) end}},
     {<<"Fs.makeLink">>,
      {fun() -> Fs:makeLink(P("linked"), P("file"), 5000), file:delete(In("linked")) end,
       fun() -> file:make_symlink(In("file"), In("linked")), file:delete(In("linked")) end}},
     {<<"Fs.makeHardLink">>,
      {fun() -> Fs:makeHardLink(P("hard"), P("file"), 5000), file:delete(In("hard")) end,
       fun() -> file:make_link(In("file"), In("hard")), file:delete(In("hard")) end}},
     {<<"Fs.readLink">>, {fun() -> Fs:readLink(P("link"), 5000) end,
                          fun() -> file:read_link_all(In("link")) end}},
     {<<"Fs.makeFile">>,
      {fun() -> Fs:makeFile(P("new"), Bytes, 5000), file:delete(In("new")) end,
       fun() ->
               {ok, Fd} = file:open(In("new"), [write, exclusive, raw, binary]),
               ok = file:write(Fd, Bytes),
               ok = file:close(Fd),
               file:delete(In("new"))
       end}},
     {<<"Fs.setModified">>,
      {fun() -> Fs:setModified(P("file"), 86400000, 5000) end,
       fun() -> file:write_file_info(In("file"), #file_info{mtime = 86400}, [{time, posix}, raw])
       end}},
     {<<"Fs.setMode">>, {fun() -> Fs:setMode(P("file"), 8#644, 5000) end,
                         fun() -> file:change_mode(In("file"), 8#644) end}}].

io_scenarios(Bytes, DevNull) ->
    Text = text(?SIZE),
    Io = 'ern@io',
    Written = fun(Data) -> fun() -> file:write(DevNull, Data) end end,
    [{<<"Io.print">>, {fun() -> Io:print(Text) end, Written(Text)}},
     {<<"Io.println">>, {fun() -> Io:println(Text) end, Written(Text)}},
     {<<"Io.printError">>, {fun() -> Io:printError(Text) end, Written(Text)}},
     {<<"Io.printlnError">>, {fun() -> Io:printlnError(Text) end, Written(Text)}},
     {<<"Io.write">>, {fun() -> Io:write(Bytes) end, Written(Bytes)}},
     {<<"Io.writeError">>, {fun() -> Io:writeError(Bytes) end, Written(Bytes)}},
     %% the descriptor the compiler passes for the value's type (Appendix E.1)
     {<<"Io.debug">>, {fun() -> Io:debug(lists:seq(1, ?SIZE), any) end,
                       fun() -> file:write(DevNull, io_lib:format("~p~n", [lists:seq(1, ?SIZE)]))
                       end}},
     {<<"Io.readLine">>, {not_measured, <<"reads standard input">>}},
     {<<"Io.read">>, {not_measured, <<"reads standard input">>}}].

os_scenarios(Bytes) ->
    Os = 'ern@os',
    True = {'Command', <<"true">>, [], <<>>},
    Cat = {'Command', <<"cat">>, [], <<>>},
    Exited = fun Exited(Program) ->
                     case Os:read(Program, 5000) of
                         {'Right', {'Exited', _}} -> ok;
                         {'Right', _} -> Exited(Program)
                     end
             end,
    HostRun = fun(Name) ->
                      fun() ->
                              Port = erlang:open_port({spawn_executable, os:find_executable(Name)},
                                                      [exit_status, binary]),
                              receive {Port, {exit_status, _}} -> ok end
                      end
              end,
    {'Right', Echo} = Os:start(Cat),
    HostEcho = erlang:open_port({spawn_executable, os:find_executable("cat")}, [binary, stream]),
    Size = byte_size(Bytes),
    [{<<"Os.run">>, {fun() -> {'Right', _} = Os:run(True, 5000) end, HostRun("true")}},
     {<<"Os.start">>, {fun() -> {'Right', Program} = Os:start(True), Exited(Program) end,
                       HostRun("true")}},
     {<<"Os.write">>,
      {fun() -> Os:write(Echo, Bytes, 5000), echoed(fun() -> Os:read(Echo, 5000) end, Size) end,
       fun() -> erlang:port_command(HostEcho, Bytes), port_echoed(HostEcho, Size) end}},
     {<<"Os.read">>, {within, <<"Os.write">>}},
     %% the host cannot close a program's input alone, so its side starts a
     %% program and waits for its end, as Ernest's does once the input ends
     {<<"Os.closeInput">>,
      {fun() -> {'Right', Program} = Os:start(Cat), Os:closeInput(Program), Exited(Program) end,
       HostRun("true")}},
     {<<"Os.give">>, {fun() -> Os:give(Echo, 'ern@process':fromAddress(ern_rt:self())) end,
                      fun() -> erlang:port_connect(HostEcho, erlang:self()) end}},
     {<<"Os.exit">>, {not_measured, <<"ends the program, or faults the caller">>}}].

%% Reads what a program or a socket gives back until Size bytes are in.
echoed(Read, Size) ->
    echoed(Read, Size, 0).

echoed(_, Size, Count) when Count >= Size -> ok;
echoed(Read, Size, Count) ->
    {'Right', Piece} = Read(),
    echoed(Read, Size, Count + piece_size(Piece)).

piece_size({'Stdout', Bytes}) -> byte_size(Bytes);
piece_size(Bytes) when is_binary(Bytes) -> byte_size(Bytes).

port_echoed(Port, Size) ->
    port_echoed(Port, Size, 0).

port_echoed(_, Size, Count) when Count >= Size -> ok;
port_echoed(Port, Size, Count) ->
    receive {Port, {data, Bytes}} -> port_echoed(Port, Size, Count + byte_size(Bytes)) end.

process_scenarios() ->
    Process = 'ern@process',
    Me = Process:fromAddress(ern_rt:self()),
    [{<<"Process.fromAddress">>,
      {fun() -> Process:fromAddress(ern_rt:self()) end, fun() -> erlang:self() end}},
     {<<"Process.info">>, {fun() -> Process:info(Me) end,
                           fun() -> erlang:process_info(erlang:self(),
                                                        [message_queue_len, status])
                           end}},
     {<<"Process.live">>, {fun() -> Process:live() end, fun() -> erlang:processes() end}},
     {<<"Process.faults">>, {fun() -> Process:faults(fun(Report) -> Report end) end, none}}].

supervisor_scenarios() ->
    Supervisor = 'ern@supervisor',
    Group = ern_rt:spawn(Supervisor:group('OneForOne', 'Unlimited'), <<"ern_measure:group">>),
    Waits = fun() -> receive stop -> 'Unit' end end,
    HostSpawned = fun() -> exit(erlang:spawn(Waits), kill) end,
    [{<<"Supervisor.group">>,
      {fun() ->
               ern_rt:kill(ern_rt:spawn(Supervisor:group('OneForOne', 'Unlimited'),
                                        <<"ern_measure:group">>))
       end,
       HostSpawned}},
     {<<"Supervisor.child">>,
      {fun() -> ern_rt:kill(ern_rt:spawn(Supervisor:child(Group, Waits), <<"ern_measure:child">>))
       end,
       HostSpawned}}].

tcp_scenarios(Bytes) ->
    Tcp = 'ern@tcp',
    Loopback = <<"127.0.0.1">>,
    {'Right', Listener} = Tcp:listen(Loopback, 0),
    {'Right', Port} = Tcp:port(Listener),
    {'Right', Client} = Tcp:connect(Loopback, Port, 1000),
    {'Right', Server} = Tcp:accept(Listener, 1000),
    Options = [binary, {active, false}, {ip, {127, 0, 0, 1}}],
    {ok, HostListener} = gen_tcp:listen(0, Options),
    {ok, HostPort} = inet:port(HostListener),
    {ok, HostClient} = gen_tcp:connect({127, 0, 0, 1}, HostPort, [binary, {active, false}]),
    {ok, HostServer} = gen_tcp:accept(HostListener),
    Size = byte_size(Bytes),
    [{<<"Tcp.listen">>,
      {fun() -> {'Right', Other} = Tcp:listen(Loopback, 0), Tcp:closeListener(Other) end,
       fun() -> {ok, Other} = gen_tcp:listen(0, Options), gen_tcp:close(Other) end}},
     {<<"Tcp.closeListener">>, {within, <<"Tcp.listen">>}},
     {<<"Tcp.port">>, {fun() -> Tcp:port(Listener) end, fun() -> inet:port(HostListener) end}},
     {<<"Tcp.connect">>,
      {fun() ->
               {'Right', Near} = Tcp:connect(Loopback, Port, 1000),
               {'Right', Far} = Tcp:accept(Listener, 1000),
               Tcp:close(Near),
               Tcp:close(Far)
       end,
       fun() ->
               {ok, Near} = gen_tcp:connect({127, 0, 0, 1}, HostPort, [binary, {active, false}]),
               {ok, Far} = gen_tcp:accept(HostListener),
               gen_tcp:close(Near),
               gen_tcp:close(Far)
       end}},
     {<<"Tcp.accept">>, {within, <<"Tcp.connect">>}},
     {<<"Tcp.close">>, {within, <<"Tcp.connect">>}},
     {<<"Tcp.write">>,
      {fun() -> Tcp:write(Client, Bytes, 1000), echoed(fun() -> Tcp:read(Server, 1000) end, Size)
       end,
       fun() ->
               ok = gen_tcp:send(HostClient, Bytes),
               {ok, _} = gen_tcp:recv(HostServer, Size)
       end}},
     {<<"Tcp.read">>, {within, <<"Tcp.write">>}},
     {<<"Tcp.give">>,
      {fun() -> Tcp:give(Client, 'ern@process':fromAddress(ern_rt:self())) end,
       fun() -> gen_tcp:controlling_process(HostClient, erlang:self()) end}},
     {<<"Tcp.remote">>, {fun() -> Tcp:remote(Client) end, fun() -> inet:peername(HostClient) end}},
     {<<"Tcp.local">>, {fun() -> Tcp:local(Client) end, fun() -> inet:sockname(HostClient) end}}].

terminal_scenarios() ->
    [{<<"Terminal.subscribe">>, {not_measured, <<"reads a terminal">>}},
     {<<"Terminal.size">>, {not_measured, <<"reads a terminal">>}}].

ets_scenarios() ->
    Ets = 'ern@ets',
    Table = Ets:new(),
    [Ets:put(Table, Key, Key) || Key <- lists:seq(1, ?SIZE)],
    Host = ets:new(ern_measure, [set, public]),
    [ets:insert(Host, {Key, Key}) || Key <- lists:seq(1, ?SIZE)],
    [{<<"Ets.new">>, {fun() -> Ets:close(Ets:new()) end,
                      fun() -> ets:delete(ets:new(ern_measure, [set, public])) end}},
     {<<"Ets.close">>, {within, <<"Ets.new">>}},
     {<<"Ets.put">>, {fun() -> Ets:put(Table, 7, 7) end, fun() -> ets:insert(Host, {7, 7}) end}},
     {<<"Ets.get">>, {fun() -> Ets:get(Table, 7) end, fun() -> ets:lookup(Host, 7) end}},
     {<<"Ets.contains">>, {fun() -> Ets:contains(Table, 7) end, fun() -> ets:member(Host, 7) end}},
     {<<"Ets.remove">>, {fun() -> Ets:remove(Table, 0) end, fun() -> ets:delete(Host, 0) end}},
     {<<"Ets.size">>, {fun() -> Ets:size(Table) end, fun() -> ets:info(Host, size) end}},
     {<<"Ets.clear">>,
      {fun() -> Ets:clear(Table), Ets:put(Table, 7, 7) end,
       fun() -> ets:delete_all_objects(Host), ets:insert(Host, {7, 7}) end}},
     {<<"Ets.toList">>, {fun() -> Ets:toList(Table) end, fun() -> ets:tab2list(Host) end}}].

%%
%% The report
%%

%% A row's line in the whole table.
row_text(#{display := Display, outcome := Outcome}) ->
    [Display, "\t", outcome_text(Outcome), "\n"].

outcome_text({timed, Sizes}) ->
    lists:join("  ", [io_lib:format("~B: ~s ~s~s", [Size, ns(Ernest), bytes(Allocated),
                                                    host_text(Ernest, Host, Allocated, Of)])
                      || {Size, Ernest, Host, Allocated, Of} <- Sizes])
        ++ growth_text(Sizes);
outcome_text({system, Ernest, Host, Allocated, Of}) ->
    io_lib:format("~s ~s~s", [ns(Ernest), bytes(Allocated),
                              host_text(Ernest, Host, Allocated, Of)]);
outcome_text({within, Other}) -> ["measured with ", Other];
outcome_text({not_measured, Reason}) -> ["not measured: ", Reason];
outcome_text({failed, Reason}) -> ["FAILED: ", Reason];
outcome_text(not_listed) -> "NOT LISTED: needs a process, and has no scenario".

host_text(_, none, _, _) -> "";
host_text(Ernest, Host, Allocated, Of) ->
    io_lib:format(" (host ~s ~s, ~.1fx~s)", [ns(Host), bytes(Of), ratio(Ernest, Host),
                                              allocation_ratio(Allocated, Of)]).

%% Bytes allocated, as a person reads them.
bytes({more_than, Bytes}) -> ["more than ", bytes(Bytes)];
bytes(none) -> "";
bytes(Bytes) when Bytes >= 1048576 -> io_lib:format("~.1f MB", [Bytes / 1048576]);
bytes(Bytes) when Bytes >= 1024 -> io_lib:format("~.1f KB", [Bytes / 1024]);
bytes(Bytes) -> io_lib:format("~B B", [Bytes]).

allocation_ratio(Allocated, Of) when is_integer(Allocated), is_integer(Of), Of > 0 ->
    io_lib:format(", ~.1fx the bytes", [Allocated / Of]);
allocation_ratio(_, _) -> "".

growth_text(Sizes) ->
    case {growth(Sizes), host_growth(Sizes)} of
        {none, _} -> "";
        {Growth, none} -> io_lib:format("  growth ~Bx", [round(Growth)]);
        {Growth, Host} -> io_lib:format("  growth ~Bx (host ~Bx)", [round(Growth), round(Host)])
    end.

ns(Ns) when Ns < 0 -> ["-", ns(-Ns)];
ns(Ns) when Ns >= 1000000 -> io_lib:format("~.1f ms", [Ns / 1000000]);
ns(Ns) when Ns >= 1000 -> io_lib:format("~.1f us", [Ns / 1000]);
ns(Ns) -> io_lib:format("~B ns", [round(Ns)]).

ratio(_, Host) when Host == 0 -> 0.0;
ratio(Ernest, Host) -> Ernest / Host.

growth(Sizes) ->
    case {lists:keyfind(100, 1, Sizes), lists:keyfind(10000, 1, Sizes)} of
        {{100, Small, _, _, _}, {10000, Large, _, _, _}} when Small > 0 -> Large / Small;
        _ -> none
    end.

host_growth(Sizes) ->
    case {lists:keyfind(100, 1, Sizes), lists:keyfind(10000, 1, Sizes)} of
        {{100, _, Small, _, _}, {10000, _, Large, _, _}} when is_number(Small), Small > 0,
                                                             is_number(Large) ->
            Large / Small;
        _ ->
            none
    end.

%% past, near or under the growth line
growth_judged(Sizes) ->
    case {growth(Sizes), host_growth(Sizes)} of
        {none, _} -> under;
        {Growth, _} when Growth < ?GROWTH_FLOOR -> under;
        {Growth, none} when Growth > ?GROWTH_LINE -> past;
        {Growth, none} when Growth > ?GROWTH_NEAR -> near;
        {_, none} -> under;
        {Growth, Host} when Growth > ?HOST_GROWTH_LINE * Host -> past;
        {_, _} -> under
    end.

%% What is past the line, then the counts.
summary(Rows) ->
    Host = [{Row, Worst} || #{outcome := {timed, Sizes}} = Row <- Rows,
                            Worst <- [worst(Sizes)], Worst > ?HOST_LINE],
    Grows = [{Row, growth_text(Sizes)} || #{outcome := {timed, Sizes}} = Row <- Rows,
                                          growth_judged(Sizes) =:= past],
    Near = [{Row, growth_text(Sizes)} || #{outcome := {timed, Sizes}} = Row <- Rows,
                                         growth_judged(Sizes) =:= near],
    System = [{Row, io_lib:format("~.1fx, ~s added", [ratio(Ernest, Of), ns(Ernest - Of)])}
              || #{outcome := {system, Ernest, Of, _, _}} = Row <- Rows,
                 Of =/= none, ratio(Ernest, Of) > ?SYSTEM_LINE],
    Allocates = [{Row, Worst} || #{outcome := {timed, Sizes}} = Row <- Rows,
                                 Worst <- [allocation_worst(Sizes)], Worst > ?HOST_LINE],
    Unmeasured = [Row || #{outcome := Outcome} = Row <- Rows, unmeasured(Outcome)],
    Count = fun(Test) -> length([Row || #{outcome := Outcome} = Row <- Rows, Test(Outcome)]) end,
    [io_lib:format("~nEvery function of the library, measured (MVP 2.99d item 1)~n", []),
     section(io_lib:format("Past the line: more than ~B times the host's", [round(?HOST_LINE)]),
             [{Row, io_lib:format("~.1fx", [Worst])} || {Row, Worst} <- Host]),
     section(io_lib:format("Past the line: growing from 100 to 10,000 at least ~B times, and "
                           "more than ~B times the host's growth, or ~B times where no host "
                           "does the work",
                           [round(?GROWTH_FLOOR), round(?HOST_GROWTH_LINE), round(?GROWTH_LINE)]),
             Grows),
     section(io_lib:format("Near the line, for a thorough measurement: growing ~B to ~B times, "
                           "no host", [round(?GROWTH_NEAR), round(?GROWTH_LINE)]),
             Near),
     section(io_lib:format("A system module's function past ~B times the host's operation, "
                           "and what Ernest adds", [round(?SYSTEM_LINE)]),
             System),
     section(io_lib:format("Allocating more than ~B times the host's, at any size: no line yet, "
                           "for the user to weigh", [round(?HOST_LINE)]),
             [{Row, io_lib:format("~.1fx", [Worst])} || {Row, Worst} <- Allocates]),
     section("Not measured, or failing", [{Row, outcome_text(maps:get(outcome, Row))}
                                          || Row <- Unmeasured]),
     io_lib:format("~nTimed by drawn arguments: ~B, of which with a host: ~B. By scenario: ~B, "
                   "and measured with another's: ~B. Not measured: ~B, values left out: ~B.~n",
                   [Count(fun({timed, _}) -> true; (_) -> false end),
                    length([Row || #{outcome := {timed, Sizes}} = Row <- Rows,
                                   [Host1 || {_, _, Host1, _, _} <- Sizes, Host1 =/= none]
                                       =/= []]),
                    Count(fun({system, _, _, _, _}) -> true; (_) -> false end),
                    Count(fun({within, _}) -> true; (_) -> false end),
                    Count(fun({not_measured, Reason}) ->
                                  Reason =/= <<"a top-level binding, no function">>;
                             (_) -> false end),
                    Count(fun({not_measured, <<"a top-level binding, no function">>}) -> true;
                             (_) -> false end)])].

worst(Sizes) ->
    lists:max([0.0 | [ratio(Ernest, Host) || {Size, Ernest, Host, _, _} <- Sizes,
                                              Size =< 100, Host =/= none]]).

%% The most a call allocates beside the host's call at any size, where
%% both are counted.
allocation_worst(Sizes) ->
    lists:max([0.0 | [Allocated / Of || {_, _, _, Allocated, Of} <- Sizes,
                                        is_integer(Allocated), is_integer(Of), Of > 0]]).

unmeasured({not_measured, <<"a top-level binding, no function">>}) -> false;
unmeasured({not_measured, _}) -> true;
unmeasured({failed, _}) -> true;
unmeasured(not_listed) -> true;
unmeasured(_) -> false.

section(_, []) -> [];
section(Title, Lines) ->
    [io_lib:format("~n~s:~n", [Title])
     | [io_lib:format("  ~-28s ~s~n", [Display, Text]) || {#{display := Display}, Text} <- Lines]].

%% The host's load average over the last minute, and its processors, read
%% before the run: a machine busy with more than half of them gives times
%% that read high (the log's *The Release Review Before 0.3.1*).
load() ->
    Average = case file:read_file("/proc/loadavg") of
                  {ok, Text} -> number(hd(string:lexemes(Text, " ")));
                  _ -> number(hd(string:lexemes(os:cmd("sysctl -n vm.loadavg"), "{ ")))
              end,
    {Average, erlang:system_info(logical_processors_available)}.

number(Text) ->
    try binary_to_float(iolist_to_binary(Text))
    catch error:badarg -> unknown
    end.

load_text({unknown, _}) ->
    "The load average could not be read; the times hold only on an idle machine.\n";
load_text({Average, Processors}) when is_number(Processors), Average > Processors / 2 ->
    io_lib:format("NOT IDLE: load average ~.2f on ~B processors; the times read high. Run it "
                  "again when the machine has rested.~n", [Average, Processors]);
load_text({Average, Processors}) ->
    io_lib:format("Load average ~.2f on ~p processors.~n", [Average, Processors]).

%% A scratch directory of the run's own, which measured/2 removes.
scratch() ->
    Base = case os:getenv("ERN_TEST_DIR") of
               false -> "/tmp";
               Dir -> Dir
           end,
    filename:join(Base, "ern_measure_" ++ os:getpid() ++ "_"
                        ++ integer_to_list(erlang:unique_integer([positive]))).
