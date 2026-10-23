%% The tour, tour/1/ to tour/8/, run as its reader runs it (plan, MVP 3.3;
%% docs/proposals/tour/outline.md, sections 3 and 5): chapter 1's shell
%% over the first chapter's program; and one shell that is the node `a`,
%% in a working directory into which each later chapter's files are
%% copied in turn, `:load Counter` once and `:reload` at each chapter,
%% beside the two bare nodes `foo` and `bar`, which chapter 2's commands
%% make and the nodes' harness starts (ern_nodes_tests), with chapter 5's
%% build and test run in that directory and chapter 8's stops.
%%
%% An input is typed once the shell has printed all that the one before it
%% prints, and what it prints is held to the lines the outline quotes, each
%% whole, a node's line without its time. A line nothing orders against
%% the input's answer, a fault's report, a node's connection, a monitor's
%% message, is held to come once, its own lines together, before or after
%% the answer, or among the next input's lines: in line mode the shell
%% waits for the next line once it has prompted, and prints a fault
%% reported meanwhile after it has read that line. Regression tests,
%% written after the programs and the toolchain; each says what it does
%% not cover.
-module(ern_tour_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ERN, filename:absname("../bin/ern")).
-define(TOUR, "../tour").
%% Report §11.2: the time before a line a node writes where its stream is
%% no terminal, which the tour leaves out.
-define(STAMP, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z ").
%% What `Counter.apply` answers to an inc, whose send does not wait.
-define(SENT, "\"ok\" : String").

%% A shell the test types at, named by the directory its streams are
%% written beside (ern_nodes_tests:launched/2): the port its inputs are
%% written to, what waits for its end, all it has printed that the test
%% has read, and the parts the input before printed none of, which nothing
%% ordered against its prompt, and which the next input's lines hold.
-record(shell, {dir, port, wait, read, carried = []}).

%% The tour's working directory, the reader's own, which holds the program
%% and the three configuration directories; the bare nodes' directories
%% and what waits for each one's end; and the shell that is `a`.
-record(tour, {base, foo, bar, wait_foo, wait_bar, shell}).

%%
%% Chapter 1, a shell that is no node
%%

%% tour/1/, the outline's chapter 1; report §6.1, §6.2, §6.6, §11.2,
%% §11.5: the counter loaded at a shell that is no node, a process spawned
%% on its loop, a send, a call that answers 5, and a send of a String
%% refused at the prompt with the input's line and a caret under the
%% argument; the shell ends at `:quit` with status 0. It does not cover the
%% shell at a terminal, whose colors the tour does not show. Its limit is
%% the sum of its eight waits, each bounded by the harness's time for one
%% wait: the start, five inputs, the end and what the shell said
chapter_1_test_() ->
    ern_nodes_tests:nodes_test({waits, 8}, fun chapter_1/1).

chapter_1(Base) ->
    copied(1, Base),
    Shell = started(Base, filename:join(Base, "shell"), ""),
    quit(session(Shell,
                 [{":load Counter", ["Counter, compiled from counter.ern"]},
                  {"let counter = spawn(fn() = Counter.count(0))",
                   ["counter : Address(Counter.CounterMsg)"]},
                  {"send(counter, Counter.Inc(5))", []},
                  {"Address.call(counter, Counter.Get, 1000)", ["Some(5) : Optional(Int)"]},
                  {"send(counter, \"five\")",
                   ["input 5:1:15: the argument does not fit send: expected Counter.CounterMsg,"
                    " found String",
                    "1 | send(counter, \"five\")",
                    "  | ---- send : (Address(a), a) -> Unit",
                    "  |               ^^^^^^"]}])).

%% The outline's chapter 7, the line it tells and does not show; report
%% §4.7, §7.4, §8.4: `erlang:system_info/1` declared to answer a String,
%% which it does not, faults its caller as the answer arrives, the cause
%% naming the function and the type. The declaration is typed at a shell
%% that is no node and the call made there, where the tour's would be
%% made on a peer by a compute. It does not cover the compute, whose fault
%% the caller's node reports beneath the trace that crossed with it. Its
%% limit is the sum of its five waits: the start, two inputs, the end and
%% what the shell said
told_boundary_test_() ->
    ern_nodes_tests:nodes_test({waits, 5}, fun told_boundary/1).

told_boundary(Base) ->
    Shell = started(Base, filename:join(Base, "shell"), ""),
    quit(session(Shell,
                 [{"foreign fn systemInfo(item : Foreign.Term) : String = \"erlang:system_info/1\"",
                   ["systemInfo : (Foreign.Term) -> String"]},
                  {"systemInfo(Foreign.atom(\"schedulers\"))",
                   ["fault: the return of foreign function erlang:system_info/1 does not match"
                    " String"]}])).

%%
%% Chapters 2 to 8, one session on three nodes
%%

%% tour/2/ to tour/8/, the outline's chapters 2 to 8, one session; report
%% §3.6, §3.11, §4.4, §4.7, §4.9, §6.5, §6.9, §6.10, §7.3, §8.4, §8.6,
%% §8.7, §11.1, §11.2, §11.3, Appendix E.24, E.27, E.28: chapter 2's seven
%% commands, the bare nodes started and the shell as `a`, then each
%% chapter's files copied and its inputs typed, as each chapter's function
%% says, and at the end what each bare node wrote. A bare node's port is
%% one the harness found free, in place of the outline's 8655 and 8656, and
%% so is `a`'s listen, which `ern config` sets to 0.0.0.0:8654, since one
%% machine's nodes cannot share a port; the harness starts the bare nodes
%% from their absolute directories, where the reader types `ern run
%% --config-dir foo`. The inputs are the tour's, their deadlines among
%% them. Two inputs follow chapter 8's stop of foo, which the outline's
%% closing line tells and does not show: `far` answers "ok" to an inc and
%% "no answer" to a report. It does not cover the four terminals as a
%% reader sees them, a node's line's time, which bare node a compute that
%% names none runs on, nor how long anything took. Its limit is the sum of
%% its 81 waits, each bounded by the harness's time for one wait: eleven
%% jobs, two ports that answer, the shell's start, 57 inputs, two nodes'
%% first lines, two lines of a node's end, three ends and what three said
tour_test_() ->
    ern_nodes_tests:nodes_test({waits, 81}, fun tour/1).

tour(Base) ->
    [PortA, PortFoo, PortBar] = [ern_nodes_tests:free_port() || _ <- [a, foo, bar]],
    configured(Base, PortA, PortFoo, PortBar),
    [Foo, Bar] = [filename:join(Base, Name) || Name <- ["foo", "bar"]],
    WaitFoo = ern_nodes_tests:bare_started(Foo, []),
    WaitBar = ern_nodes_tests:bare_started(Bar, []),
    [ern_deployment_tests:answering(Port) || Port <- [PortFoo, PortBar]],
    Shell = started(Base, filename:join(Base, "a"), " --config-dir a"),
    Chapters = [{2, fun far/1}, {3, fun client/1}, {4, fun fault/1}, {5, fun per_key/1},
                {6, fun door/1}, {7, fun anywhere/1}, {8, fun fix/1}],
    Tour = #tour{base = Base, foo = Foo, bar = Bar, wait_foo = WaitFoo, wait_bar = WaitBar,
                 shell = Shell},
    #tour{shell = Ended} = lists:foldl(fun({Chapter, Run}, Before) ->
                                           copied(Chapter, Base),
                                           Run(Before)
                                       end, Tour, Chapters),
    quit(Ended),
    {FooOut, FooErr} = ern_nodes_tests:said(Foo),
    {BarOut, BarErr} = ern_nodes_tests:said(Bar),
    %% each said its peer's connection and nothing else, and each of
    %% chapter 7's three computes printed its line where it ran
    [?assertEqual([<<"the peer a connected">>], stamped(Err)) || Err <- [FooErr, BarErr]],
    ?assertEqual(lists:duplicate(3, <<"counting the primes below 200000">>),
                 untimed_lines(FooOut) ++ untimed_lines(BarOut)).

%% Chapter 2's seven commands, run from the reader's directory as the
%% outline writes them, each `--listen`'s port one the harness found free:
%% the three that make a directory print its key, and the four that list a
%% peer print nothing. `a`'s listen is set to a free port before it is
%% listed. a/ernest.conf, which the tour shows, then lists foo and bar at
%% their ports, each by its key, and offers no service, and each bare node
%% lists `a` at its port (report §8.7, §11.3).
configured(Base, PortA, PortFoo, PortBar) ->
    [A, Foo, Bar] = [filename:join(Base, Name) || Name <- ["a", "foo", "bar"]],
    created(Base, "config --config-dir a"),
    ern_nodes_tests:edit(A, fun(Conf) -> Conf#{<<"listen">> => address(PortA)} end),
    created(Base, "config --config-dir foo --listen " ++ binary_to_list(address(PortFoo))),
    created(Base, "config --config-dir bar --listen " ++ binary_to_list(address(PortBar))),
    [?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "config --config-dir " ++ Words))
     || Words <- ["a --peer-dir foo", "a --peer-dir bar", "foo --peer-dir a", "bar --peer-dir a"]],
    ?assertEqual(#{<<"listen">> => address(PortA), <<"public-key">> => key(A),
                   <<"peers">> => [peer("foo", Foo, PortFoo), peer("bar", Bar, PortBar)],
                   <<"services">> => #{}},
                 configuration(A)),
    [?assertEqual([peer("a", A, PortA)], maps:get(<<"peers">>, configuration(Dir)))
     || Dir <- [Foo, Bar]].

created(Base, Words) ->
    {Status, Out, Err} = ern_deployment_tests:job(Base, Words),
    ?assertEqual({0, ""}, {Status, Err}),
    ern_deployment_tests:keyed(Out).

peer(Name, Dir, Port) ->
    #{<<"name">> => list_to_binary(Name), <<"network-address">> => address(Port),
      <<"public-key">> => key(Dir)}.

key(Dir) ->
    maps:get(<<"public-key">>, configuration(Dir)).

configuration(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    json:decode(Text).

address(Port) ->
    list_to_binary("127.0.0.1:" ++ integer_to_list(Port)).

%% Chapter 2: the counter loaded at the shell that is `a`, one spawned
%% here as in chapter 1, and one on foo, a bare node that holds none of
%% its code, which the shell's first connection reaches; a send to it and
%% a call it answers. foo says that `a` connected, and nothing before it
%% (report §8.7, §11.2, Appendix E.27).
far(#tour{foo = Foo, shell = Shell} = Tour) ->
    Typed = session(Shell,
                    [{":load Counter", ["Counter, compiled from counter.ern"]},
                     {"let counter = spawn(fn() = Counter.count(0))",
                      ["counter : Address(Counter.CounterMsg)"]},
                     {"let far = match Peer.spawn(\"foo\", fn() = Counter.count(0), 5000) {"
                      " Right(address) -> address | Left(error) -> fault(Io.show(error)) }",
                      ["far : Address(Counter.CounterMsg)"],
                      [["the peer foo connected"]]},
                     {"send(far, Counter.Inc(5))", []},
                     {"Address.call(far, Counter.Get, 1000)", ["Some(5) : Optional(Int)"]}]),
    ern_nodes_tests:says(Foo, "the peer a connected"),
    ?assertEqual([<<"the peer a connected">>], untimed_lines(ern_nodes_tests:written(Foo, err))),
    Tour#tour{shell = Typed}.

%% Chapter 3: a reload that changes no type says the module compiled
%% again and nothing else, and one function serves the counter here and
%% the one on foo, an address being a value (report §6.5, §11.2).
client(#tour{shell = Shell} = Tour) ->
    Tour#tour{shell = session(Shell,
                              [{":reload", ["Counter, compiled again"]},
                               {"Counter.apply(counter, \"inc 3\")", [?SENT]},
                               {"Counter.apply(far, \"get\")", ["\"5\" : String"]}])}.

%% Chapter 4: the counter of the old loop killed and one of the new
%% started, which a negative amount faults, reported with its site and its
%% trace, the version's number in it, while the send answers "ok"; a call
%% to it then answers "no answer". A counter under `restarting`, limit one,
%% watched by a monitor: faulted and restarted, its count lost and its
%% address kept, then faulted past the limit, which the watcher hears as
%% the fault's `Down` (report §6.9, §6.10, §7.3, §11.2, Appendix E.21).
fault(#tour{shell = Shell} = Tour) ->
    Trace = "    Counter$3.count:8",
    Tour#tour{shell = session(
        Shell,
        [{":reload", ["Counter, compiled again"]},
         {"kill(counter)", []},
         {"let counter = spawn(fn() = Counter.count(0))",
          ["counter : Address(Counter.CounterMsg)"]},
         {"Counter.apply(counter, \"inc -1\")", [?SENT],
          [["input 11:1 faulted: a negative amount", Trace]]},
         {"Counter.apply(counter, \"get\")", ["\"no answer\" : String"]},
         {"let counter = spawn(restarting(RestartLimit(restarts = 1, within = 5000),"
          " fn() = Counter.count(0)))",
          ["counter : Address(Counter.CounterMsg)"]},
         {"let watcher = spawn(fn() = Counter.watch(counter))",
          ["watcher : Address(Counter.WatchMsg)"]},
         {"Counter.apply(counter, \"inc 2\")", [?SENT]},
         {"Counter.apply(counter, \"inc -1\")", [?SENT],
          [["input 14:1 faulted, restarted: a negative amount", Trace]]},
         {"Counter.apply(counter, \"get\")", ["\"0\" : String"]},
         {"Counter.apply(counter, \"inc -1\")", [?SENT],
          [["input 14:1 faulted: a negative amount", Trace],
           ["the counter ended: Fault(\"a negative amount\")"]]}])}.

%% Chapter 5: `ern build .` compiles both modules and says nothing, and
%% `ern test counter.erc` passes the first test and faults the second with
%% a deadlock, its trace beneath it, ending with status 1. The reload
%% loads Tally from the build and names the two bindings of the previous
%% type, chapter 4's ended counter among them; the counter on foo is
%% refused the new protocol, with the help naming the previous version;
%% it is killed, and a counter of the new type counts per key (report
%% §3.6, §4.4, §4.9, §8.6, §11.1, §11.2, §11.5, Appendix E.24).
per_key(#tour{base = Base, shell = Shell} = Tour) ->
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "build .")),
    ?assertEqual({1, "counts per key: passed\nreports: faulted: deadlock\n    Counter.reports:70\n",
                  ""},
                 ern_deployment_tests:job(Base, "test counter.erc")),
    Tour#tour{shell = session(
        Shell,
        [{":reload",
          ["Tally, from tally.erc",
           "Counter, compiled again",
           "Counter.CounterMsg changed: the bindings counter and far are of its previous version,"
           " Counter$3.CounterMsg"]},
         {"Counter.apply(far, \"inc apples 2\")",
          ["input 21:1:15: the argument does not fit Counter.apply: expected"
           " Address(Counter.CounterMsg), found Address(Counter$3.CounterMsg)",
           "1 | Counter.apply(far, \"inc apples 2\")",
           "  | ------------- Counter.apply : (Address(Counter.CounterMsg), String) -> String",
           "  |               ^^^",
           "  | = help: the types differ at Counter.CounterMsg and Counter$3.CounterMsg;"
           " Counter$3.CounterMsg is of a previous version of Counter, which a reload replaced"]},
         {"kill(far)", []},
         {"let counter = spawn(fn() = Counter.count(Tally.empty()))",
          ["counter : Address(Counter.CounterMsg)"]},
         {"Counter.apply(counter, \"inc apples 2\")", [?SENT]},
         {"Counter.apply(counter, \"inc pears 1\")", [?SENT]},
         {"Counter.apply(counter, \"inc apples 1\")", [?SENT]},
         {"Counter.apply(counter, \"report\")", ["\"apples: 3, pears: 1\" : String"]}])}.

%% Chapter 6: the reload names the binding of the previous type; a spawn
%% on foo of the loop whose mailbox type carries `Upgrade` is refused as
%% bound to its node; the counter here killed, and one started here and
%% one on foo by a compute, each behind an adapted address of the client's
%% type, the one on foo counting what this node sends it (report §3.11,
%% §6.5, §6.10, §8.7, §11.2, §11.5, Appendix E.27).
door(#tour{shell = Shell} = Tour) ->
    Tour#tour{shell = session(
        Shell,
        [{":reload",
          ["Counter, compiled again",
           "Counter.CounterMsg changed: the binding counter is of its previous version,"
           " Counter$4.CounterMsg"]},
         {"Peer.spawn(\"foo\", fn() = Counter.count(Tally.empty()), 5000)",
          ["input 29:1:19: Peer.spawn starts a process whose mailbox type Counter.CounterMsg is"
           " bound to its node, since it holds a function",
           "1 | Peer.spawn(\"foo\", fn() = Counter.count(Tally.empty()), 5000)",
           "  |                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^",
           "  | = help: the spawn answers an address that may cross to another node, so its"
           " messages are values that cross (report §3.11)"]},
         {"kill(counter)", []},
         {"let counter = Counter.start()", ["counter : Address(Counter.ClientMsg)"]},
         {"let far = match Peer.computeAt(\"foo\", fn() = Counter.start(), 5000) {"
          " Right(address) -> address | Left(error) -> fault(Io.show(error)) }",
          ["far : Address(Counter.ClientMsg)"]},
         {"Counter.apply(counter, \"inc apples 2\")", [?SENT]},
         {"Counter.apply(far, \"inc apples 3\")", [?SENT]},
         {"Counter.apply(far, \"inc pears 1\")", [?SENT]},
         {"Counter.apply(far, \"report\")", ["\"apples: 3, pears: 1\" : String"]}])}.

%% Chapter 7: a foreign function asked on each bare node answers the
%% host's count of schedulers, the shell's first compute on bar connecting
%% to it; the shell holds both peers' utilizations, in the configuration's
%% order; and three computes that name no node each answer the count of the
%% primes below 200000, each printing its line where it runs, which the
%% test holds once the nodes have ended (report §4.7, §8.4, §8.7, Appendix
%% E.27).
anywhere(#tour{bar = Bar, shell = Shell} = Tour) ->
    Schedulers = "Right(" ++ integer_to_list(erlang:system_info(schedulers))
        ++ ") : Either(Io.Error, Int)",
    Utilization = "[0-9]+\\.[0-9]+(?:e-?[0-9]+)?, [0-9]+",
    Primes = {"Peer.compute(fn() = Counter.primes(200000), 5000)",
              ["Right(17984) : Either(Io.Error, Int)"]},
    Typed = session(
        Shell,
        [{":reload", ["Counter, compiled again"]},
         {"Peer.computeAt(\"foo\", fn() = Counter.schedulers(), 5000)", [Schedulers]},
         {"Peer.computeAt(\"bar\", fn() = Counter.schedulers(), 5000)", [Schedulers],
          [["the peer bar connected"]]},
         {"Peer.utilizations()",
          [{re, "\\[#\\(\"foo\", " ++ Utilization ++ "\\), #\\(\"bar\", " ++ Utilization
                ++ "\\)\\] : List\\(#\\(String, Float, Int\\)\\)"}]},
         Primes,
         Primes,
         Primes]),
    ern_nodes_tests:says(Bar, "the peer a connected"),
    Tour#tour{shell = Typed}.

%% Chapter 8: the fix, a second loop, moved to on this node and on foo,
%% each counter keeping its tally, and the nodes stopped.
fix(Tour) ->
    stopped(moved_there(moved_here(Tour))).

%% The reload changes no type; `Code.running` lists the counter on the
%% first loop and none on the second, and `Counter.move()` sends it its
%% `Upgrade`. A report, which the counter answers after the `Upgrade` it
%% took first, says the tally is kept, and the lists are then the other
%% way round, the same address on each; a negative amount is passed over
%% and the tally kept (report §6.4, §6.10, §11.2, Appendix E.28).
moved_here(#tour{shell = Shell} = Tour) ->
    Running = "\\[<address [0-9]+>\\] : List\\(Address\\(Counter\\.CounterMsg\\)\\)",
    Empty = "[] : List(Address(Counter.CounterMsg))",
    #shell{read = Read} = Moved = session(
        Shell,
        [{":reload", ["Counter, compiled again"]},
         {"Code.running(Counter.count)", [{re, Running}]},
         {"Code.running(Counter.count2)", [Empty]},
         {"Counter.move()", []},
         {"Counter.apply(counter, \"report\")", ["\"apples: 2\" : String"]},
         {"Code.running(Counter.count)", [Empty]},
         {"Code.running(Counter.count2)", [{re, Running}]},
         {"Counter.apply(counter, \"inc apples -1\")", [?SENT]},
         {"Counter.apply(counter, \"report\")", ["\"apples: 2\" : String"]}]),
    {match, [[First], [Second]]} = re:run(Read, Running, [global, {capture, first, binary}]),
    ?assertEqual(First, Second),
    Tour#tour{shell = Moved}.

%% A compute on foo of `move`, which foo never had, answers once `move` has
%% sent foo's counter its `Upgrade`, which is then in the counter's mailbox
%% before anything this node sends it; the counter passes a negative amount
%% over and keeps its tally (report §6.4, §8.7, Appendix E.27, E.28).
moved_there(#tour{shell = Shell} = Tour) ->
    Tour#tour{shell = session(
        Shell,
        [{"Peer.computeAt(\"foo\", fn() = Counter.move(), 5000)",
          ["Right(Unit) : Either(Io.Error, Unit)"]},
         {"Counter.apply(far, \"inc apples -1\")", [?SENT]},
         {"Counter.apply(far, \"report\")", ["\"apples: 3, pears: 1\" : String"]}])}.

%% `ern stop --config-dir foo` ends foo by termination, with status 143,
%% and the shell says that foo ended; `far` then answers "ok" to an inc,
%% since a send does not wait, and "no answer" to a report; `ern stop
%% --config-dir bar` ends bar, which the shell says too, since chapter 7
%% connected to it (report §8.6, §8.7, §11.2, §11.3).
stopped(#tour{base = Base, wait_foo = WaitFoo, wait_bar = WaitBar, shell = Shell} = Tour) ->
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir foo")),
    ?assertEqual(143, WaitFoo()),
    Lost = session(told(Shell, ["the peer foo ended"]),
                   [{"Counter.apply(far, \"inc apples 1\")", [?SENT]},
                    {"Counter.apply(far, \"report\")", ["\"no answer\" : String"]}]),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir bar")),
    ?assertEqual(143, WaitBar()),
    Tour#tour{shell = told(Lost, ["the peer bar ended"])}.

%%
%% The reader's directory and the shell
%%

%% A chapter's files copied into the reader's directory, over the files of
%% the chapter before.
copied(Chapter, Base) ->
    Sources = filelib:wildcard(filename:join([?TOUR, integer_to_list(Chapter), "*.ern"])),
    ?assertNotEqual([], Sources),
    [{ok, _} = file:copy(Source, filename:join(Base, filename:basename(Source)))
     || Source <- Sources],
    ok.

%% Report §11.2: a shell started in the reader's directory, `ern shell`
%% with Options, its HOME a directory of its own so that no person's
%% startup file runs; once it has printed its start line, as this build
%% writes it, and its first prompt.
started(Base, Dir, Options) ->
    Home = Dir ++ ".home",
    ok = filelib:ensure_path(Home),
    {Port, Wait} = ern_nodes_tests:launched(Dir, ["cd ", Base, " && HOME=", Home, " ", ?ERN,
                                                  " shell", Options]),
    ern_nodes_tests:prints(Dir, "> "),
    Started = written(Dir),
    ?assertEqual(iolist_to_binary(["Ernest ", ern_release:version_text(),
                                   ". :help for the commands, :quit to leave.\n> "]),
                 Started),
    #shell{dir = Dir, port = Port, wait = Wait, read = Started}.

%% Inputs typed in order, each once the one before it has printed all it
%% prints.
session(Shell, Inputs) ->
    lists:foldl(fun typed/2, Shell, Inputs).

%% Report §11.2: an input typed at the shell, in line mode, which echoes
%% none, once the prompt after it has come, counted beside the `> ` that
%% the lines it prints before the prompt hold, a function type's arrow
%% among them. What it printed is held to Shown, those lines in order, to
%% the parts the input before it carried, and to Unordered, each a line or
%% lines that nothing orders against its answer and its prompt, which hold
%% no `> `; those of Unordered it has not printed it carries to the next.
%% A line of Shown is a line, or {re, Pattern} for a line Pattern matches
%% whole.
typed({Input, Shown}, Shell) ->
    typed({Input, Shown, []}, Shell);
typed({Input, Shown, Unordered},
      #shell{dir = Dir, port = Port, read = Read, carried = Carried} = Shell) ->
    ?assertEqual([], [Line || Line <- lists:append(Unordered), count(Line, "> ") > 0]),
    true = port_command(Port, [Input, "\n"]),
    Prompts = count(Read, "> ") + 1
        + lists:sum([count(Line, "> ") || Line <- Shown, not is_tuple(Line)]),
    ern_nodes_tests:prints(Dir, "> ", Prompts, ern_nodes_tests:wait_ms()),
    {Lines, Text} = since(Shell, 1),
    Shell#shell{read = Text, carried = held(Lines, [Shown | Carried], Unordered)}.

%% Lines the shell prints unasked after its prompt, a node's end, once its
%% stream holds them.
told(#shell{dir = Dir, read = Read, carried = Carried} = Shell, Lines) ->
    [ern_nodes_tests:prints(Dir, Line, count(Read, Line) + 1, ern_nodes_tests:wait_ms())
     || Line <- Lines],
    {Written, Text} = since(Shell, 0),
    Shell#shell{read = Text, carried = held(Written, [Lines | Carried], [])}.

%% Report §11.2: `:quit` ends the session, which leaves the cursor on a
%% line of its own and ends with status 0, having written nothing on
%% standard error, since in line mode all it says goes to standard output.
quit(#shell{dir = Dir, port = Port, wait = Wait, read = Read, carried = Carried}) ->
    ?assertEqual([], Carried),
    true = port_command(Port, ":quit\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_nodes_tests:said(Dir),
    ?assertEqual(<<Read/binary, "\n">>, list_to_binary(Out)),
    ?assertEqual("", Err).

%% What the shell printed since the test last read it, a line each without
%% a node's time, and its prompts, Prompts of them, taken out: each stands
%% at the start of a line, and a line printed after it follows it there.
%% Answers the lines and all the shell has printed.
since(#shell{dir = Dir, read = Read}, Prompts) ->
    Text = written(Dir),
    Size = byte_size(Read),
    ?assertEqual(Read, binary:part(Text, 0, Size)),
    Lines = binary:split(binary:part(Text, Size, byte_size(Text) - Size), <<"\n">>, [global]),
    ?assertEqual(Prompts, length([Line || <<"> ", _/binary>> = Line <- Lines])),
    {[untimed(Line) || Line <- [unprompted(Line) || Line <- Lines], Line =/= <<>>], Text}.

unprompted(<<"> ", Line/binary>>) -> Line;
unprompted(Line) -> Line.

%% Whether Lines are the lines of Parts and of some of Later, each part's
%% together and in its order, the parts in some order; answers the parts of
%% Later they do not hold. Where none fits, the failure shows the parts in
%% the order given.
held(Lines, Parts, Later) ->
    Fitting = [Later -- Some || Some <- subsets(Later),
                                lists:any(fun(Order) -> fits(lists:append(Order), Lines) end,
                                          orders([[expected(Line) || Line <- Part]
                                                  || Part <- Parts ++ Some]))],
    case Fitting of
        [Left | _] -> Left;
        [] -> ?assertEqual([expected(Line) || Line <- lists:append(Parts ++ Later)], Lines)
    end.

%% Every subset of the parts, all of them first.
subsets([]) -> [[]];
subsets([Part | Rest]) -> [[Part | Some] || Some <- subsets(Rest)] ++ subsets(Rest).

expected({re, Pattern}) -> {re, Pattern};
expected(Line) -> unicode:characters_to_binary(Line).

orders([]) -> [[]];
orders(Parts) -> [[Part | Rest] || Part <- Parts, Rest <- orders(Parts -- [Part])].

fits(Expected, Lines) ->
    length(Expected) =:= length(Lines) andalso lists:all(fun fit/1, lists:zip(Expected, Lines)).

fit({{re, Pattern}, Line}) -> re:run(Line, ["^(?:", Pattern, ")$"]) =/= nomatch;
fit({Expected, Line}) -> Expected =:= Line.

written(Dir) ->
    list_to_binary(ern_nodes_tests:written(Dir, out)).

count(Text, Part) ->
    length(binary:matches(iolist_to_binary(Text), unicode:characters_to_binary(Part))).

%% Report §11.2: the lines a node wrote on its standard error with the
%% time before them, as its runtime writes its own there, each without it.
%% A bare node that ends by termination writes no other, and the line after
%% them is the launching shell's, which says that termination ended it, as
%% a reader's shell may in the node's terminal.
stamped(Text) ->
    [untimed(Line) || Line <- binary:split(iolist_to_binary(Text), <<"\n">>, [global]),
                      re:run(Line, ?STAMP) =/= nomatch].

%% A node's stream, a line each without its time.
untimed_lines(Text) ->
    [untimed(Line) || Line <- binary:split(iolist_to_binary(Text), <<"\n">>, [global]),
                      Line =/= <<>>].

untimed(Line) ->
    re:replace(Line, ?STAMP, "", [{return, binary}]).
