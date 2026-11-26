%% The tour, tour/README.md with its programs tour/1/ to tour/8/, run as its
%% reader runs it: chapter 1's shell over the first chapter's program; and
%% one shell that is the node `a`, in a working directory into which each
%% later chapter's files are copied in turn, `:load Counter` once and
%% `:reload` at each chapter, beside the two bare nodes `foo` and `bar`,
%% which chapter 2's commands make and the nodes' harness starts
%% (ern_nodes_tests), with chapter 5's build and test run in that directory,
%% and chapter 8's shell attached to `foo` and its stops.
%%
%% What is typed and what is held to come is read from the page's blocks
%% under each chapter's heading, each a console or the json block, bound in
%% the order the chapter shows them; each is recorded as a block this test
%% checks (ern_helpers:record_checked/3). A console's `$ ern` line is a
%% command run from the reader's directory, and its `> ` lines inputs
%% (inputs/1). What the page tells in its prose and does not show stays
%% here, each named where it is used: the files a chapter copies, the bare
%% nodes' start, what a node's terminal says, the shell a console is typed
%% at, and the stops.
%%
%% An input is typed once the shell has printed all that the one before it
%% prints, and what it prints is held to the lines the page shows, each
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
-define(PAGE, "../tour/README.md").
-define(README, "../README.md").
-define(EXAMPLE, "../site/example.md").
%% Report §11.2: the time before a line a node writes where its stream is
%% no terminal, which the tour leaves out.
-define(STAMP, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z ").

%% A shell the test types at, named by the directory its streams are
%% written beside (ern_harness:launched/2): the port its inputs are
%% written to, what waits for its end, all it has printed that the test
%% has read, the parts the input before printed none of, which nothing
%% ordered against its prompt, and which the next input's lines hold, and
%% the numbers of the addresses the page shows it print, in order.
-record(shell, {dir, port, wait, read, carried = [], addresses = []}).

%% The tour's working directory, the reader's own, which holds the program
%% and the configuration directories; the bare nodes' ports by their
%% directories' names; the bare nodes' directories and what waits for each
%% one's end; the shell that is `a`; chapter 8's shell attached to `foo`;
%% and the count of chapter 7's computes that name no node.
-record(tour, {base, ports, foo, bar, wait_foo, wait_bar, shell, attached, computes}).

%%
%% Chapter 1, a shell that is no node
%%

%% tour/README.md's chapter 1; report §6.1, §6.2, §6.6, §11.2, §11.5: the
%% counter, the program the chapter shows whole, written into the reader's
%% directory and loaded at a shell that is no node, a process spawned on
%% its loop, a send, a call that answers 5, a send of a String refused at
%% the prompt with the input's line and a caret under the argument, and a
%% function declared to receive a String refused for its call of `count`,
%% its declared mailbox type marked; the shell ends at `:quit` with status
%% 0. It does not cover the shell at a terminal, whose colors the tour does
%% not show. Its limit is the sum of its nine waits, each bounded by the
%% harness's time for one wait: the start, six inputs, the end and what the
%% shell said
chapter_1_test_() ->
    ern_harness:nodes_test({waits, 9}, fun chapter_1/1).

chapter_1(Base) ->
    [Program] = blocks(1, <<"ernest">>),
    ok = file:write_file(filename:join(Base, "counter.ern"), join(Program)),
    [Session] = consoles(1),
    quit(opened(Base, Session)).

%% tour/README.md's chapter 7, the line it tells and does not show; report
%% §4.7, §12.3, §8.4: `erlang:system_info/1` declared to answer a String,
%% which it does not, faults its caller as the answer arrives, the cause
%% naming the function and the type. The declaration is typed at a shell
%% that is no node and the call made there, where the tour's would be
%% made on a peer by a compute. It does not cover the compute, whose fault
%% the caller's node reports beneath the trace that crossed with it, nor
%% the input's own trace beneath its fault's line (report §11.2), whose
%% frames it takes as frames and does not read. Its limit is the sum of its
%% five waits: the start, two inputs, the end and what the shell said
told_boundary_test_() ->
    ern_harness:nodes_test({waits, 5}, fun told_boundary/1).

told_boundary(Base) ->
    Shell = started(Base, filename:join(Base, "shell"), ""),
    Declared = session(Shell,
                       [{"foreign fn systemInfo(item : Foreign.Term) : String ="
                         " \"erlang:system_info/1\"",
                         ["systemInfo : (Foreign.Term) -> String"]}]),
    %% report §12.3: the cause names the host's term, the count of the
    %% node's schedulers
    quit(faulted(Declared, "systemInfo(Foreign.atom(\"schedulers\"))",
                 "^fault: the return of foreign function erlang:system_info/1 does not match"
                 " String: is [0-9]+$")).

%%
%% The README's transcript
%%

%% README.md's console, the front page's transcript; report §8.7, §11.2,
%% Appendix E.27: `a` and `foo` made with `ern config` and listed in each
%% other's by `--peer-dir`, `a` with no `--listen`, a node that only dials,
%% and `foo` listening on a port the harness found free; `foo`
%% started bare; the README's counter, tour/2/counter.ern, in the reader's
%% directory; the shell started as `a`, its start line the release's as the
%% README shows it, and the console's inputs typed, each held to the lines
%% the console shows after it, in order, a peer's connection among them
%% held where the shell may print it, before or after the answer; `foo`
%% said where it listens, that `a` connected and, once the shell has quit,
%% that it ended, and nothing else.
%%
%% A regression test, written after the README; its four `ern config`
%% jobs make the two configuration directories the README names. It does
%% not cover the shell at a terminal. Its limit is the sum of its fifteen
%% waits, each bounded by the
%% harness's time for one wait: four `ern config` jobs, `foo`'s listening,
%% the shell's start, four inputs, the shell's end and what it said, the
%% stop, `foo`'s end and what it said.
readme_test_() ->
    ern_harness:nodes_test({waits, 15}, fun readme/1).

readme(Base) ->
    [{Number, Console}] = [{Number, Code}
                           || {Number, <<"console">>,
                               [<<"$ ern shell --config-dir a">> | _] = Code}
                                  <- fenced(numbered(?README))],
    recorded(?README, [Number]),
    PortFoo = ern_harness:free_port(),
    AddressFoo = ern_harness:address(PortFoo),
    Foo = filename:join(Base, "foo"),
    created(Base, "config --config-dir a"),
    created(Base, "config --config-dir foo --listen " ++ binary_to_list(AddressFoo)),
    [?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "config --config-dir " ++ Words))
     || Words <- ["a --peer-dir foo", "foo --peer-dir a"]],
    {ok, _} = file:copy(filename:join([?TOUR, "2", "counter.ern"]),
                        filename:join(Base, "counter.ern")),
    WaitFoo = ern_harness:bare_started(Foo, []),
    ern_deployment_tests:listens(Foo, PortFoo),
    quit(opened(Base, Console)),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir foo")),
    ?assertEqual(143, WaitFoo()),
    {"", Err} = ern_harness:said(Foo),
    ?assertEqual([<<"listening on ", AddressFoo/binary>>, <<"the peer a connected">>,
                  <<"the peer a ended">>],
                 stamped(Err)).

%% site/example.md, the homepage's example (docs/design/site.md
%% *The homepage*); report §8.7, §11.2, Appendix E.27: `a` and `foo` made
%% and listed in each other's as readme/1's are, `foo` started bare, the
%% shell started as `a`, its start line the release's as the example shows
%% it, the example's code typed, each of its declarations an input as line
%% mode reads one, the function's over lines the shell prompts `... ` for,
%% and the console's inputs typed, each held to the lines the console shows
%% after it, a peer's connection among them where the shell may print it;
%% `foo` said where it listens, that `a` connected and, once the shell has
%% quit, that it ended, and nothing else.
%%
%% A regression test, written after the example; what each declaration
%% prints, which the example does not show, is written here. It does not
%% cover the Paste of a browser, which brings the code as one input, nor
%% the shell at a terminal. Its limit is the sum of its sixteen waits, each
%% bounded by the harness's time for one wait: four `ern config` jobs,
%% `foo`'s listening, the shell's start, two declarations, three inputs, the
%% shell's end and what it said, the stop, `foo`'s end and what it said.
home_example_test_() ->
    ern_harness:nodes_test({waits, 16}, fun home_example/1).

home_example(Base) ->
    [{CodeLine, <<"ernest">>, Code}, {ConsoleLine, <<"console">>, Console}] =
        fenced(numbered(?EXAMPLE)),
    recorded(?EXAMPLE, [CodeLine, ConsoleLine]),
    Declared = [{Declaration, [lists:append(lists:duplicate(Continued, "... ")) ++ Printed]}
                || {{Declaration, Continued}, Printed}
                       <- lists:zip(declarations(Code),
                                    ["type CounterMsg",
                                     "count : (Int) -> Unit receiving CounterMsg"])],
    PortFoo = ern_harness:free_port(),
    AddressFoo = ern_harness:address(PortFoo),
    Foo = filename:join(Base, "foo"),
    created(Base, "config --config-dir a"),
    created(Base, "config --config-dir foo --listen " ++ binary_to_list(AddressFoo)),
    [?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "config --config-dir " ++ Words))
     || Words <- ["a --peer-dir foo", "foo --peer-dir a"]],
    WaitFoo = ern_harness:bare_started(Foo, []),
    ern_deployment_tests:listens(Foo, PortFoo),
    quit(opened(Base, Console, Declared)),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir foo")),
    ?assertEqual(143, WaitFoo()),
    {"", Err} = ern_harness:said(Foo),
    ?assertEqual([<<"listening on ", AddressFoo/binary>>, <<"the peer a connected">>,
                  <<"the peer a ended">>],
                 stamped(Err)).

%% The code's declarations, each a run of lines between blank ones, as
%% one input, with the count of its lines after its first, for each of
%% which line mode prompts `... ` (report §11.2).
declarations(Lines) ->
    case lists:dropwhile(fun(Line) -> Line =:= <<>> end, Lines) of
        [] ->
            [];
        Rest ->
            {Part, After} = lists:splitwith(fun(Line) -> Line =/= <<>> end, Rest),
            [{binary_to_list(iolist_to_binary(lists:join(<<"\n">>, Part))), length(Part) - 1}
             | declarations(After)]
    end.

%% The shell's start line as the README shows it, the release's version.
readme_start() ->
    {ok, Version} = file:read_file("../VERSION"),
    <<"Ernest ", (string:trim(Version))/binary,
      ", session 1. :help for help.">>.

%%
%% Chapters 2 to 8, one session on three nodes
%%

%% tour/2/ to tour/8/, tour/README.md's chapters 2 to 8, one session; report
%% §3.6, §3.11, §4.4, §4.7, §4.9, §6.5, §6.9, §6.10, §7.3, §8.4, §8.6,
%% §8.7, §11.1, §11.2, §11.3, Appendix E.24, E.27, E.28: chapter 2's seven
%% commands, the bare nodes started and the shell as `a`, then each
%% chapter's files copied and its consoles typed, as each chapter's
%% function says, and at the end what each bare node wrote.
%%
%% A bare node's port is one the harness found free, in place of the
%% tour's 8655 and 8656, since one machine's nodes cannot share a port, and
%% `a`, made with no `--listen`, only dials; the harness
%% starts the bare nodes from their absolute directories, where the reader
%% types `ern run --config-dir foo`. The inputs are the tour's, their
%% deadlines among them.
%%
%% The test does not cover the five terminals as a reader sees them, a
%% node's line's time, which bare node a compute that names none runs on,
%% nor how long anything took. Its limit is the sum of its 95 waits, each
%% bounded by the harness's time for one wait: fifteen jobs, two ports that
%% answer, two shells' starts, 62 inputs, two nodes' first lines, two of
%% foo's lines of the attach, two lines of a node's end, four ends and what
%% four said. Chapter 8's attach was written with the guides over the
%% attached shell.
tour_test_() ->
    ern_harness:nodes_test({waits, 95}, fun tour/1).

tour(Base) ->
    Chapters = [{3, fun client/1}, {4, fun fault/1}, {5, fun per_key/1}, {6, fun door/1},
                {7, fun anywhere/1}, {8, fun fix/1}],
    #tour{ports = Ports, foo = Foo, bar = Bar, shell = Ended, computes = Computes} =
        lists:foldl(fun({Chapter, Run}, Before) ->
                        copied(Chapter, Base),
                        Run(Before)
                    end, far(Base), Chapters),
    quit(Ended),
    {FooOut, FooErr} = ern_harness:said(Foo),
    {BarOut, BarErr} = ern_harness:said(Bar),
    [AddressFoo, AddressBar] = [ern_harness:address(maps:get(Name, Ports))
                                || Name <- ["foo", "bar"]],
    %% each said where it listens and its peer's connection, foo the reload
    %% that listed ops and ops's connection too, and nothing else but, on
    %% foo, the end of ops, which comes as foo ends or not at all, as the
    %% chapters' prose says their terminals show; and each of chapter 7's
    %% computes printed its line where it ran, as the chapter's prose says
    ?assertEqual([<<"listening on ", AddressBar/binary>>, <<"the peer a connected">>],
                 stamped(BarErr)),
    SaidFoo = [<<"listening on ", AddressFoo/binary>>,
               <<"the peer a connected">>, <<"ernest.conf was read again">>,
               <<"the peer ops was added">>, <<"the peer ops connected">>],
    ?assert(lists:member(stamped(FooErr), [SaidFoo, SaidFoo ++ [<<"the peer ops ended">>]])),
    ?assertEqual(lists:duplicate(Computes, <<"counting the primes below 200000">>),
                 untimed_lines(FooOut) ++ untimed_lines(BarOut)).

%% Chapter 2: the chapter's seven commands run, a/ernest.conf held to the
%% page (listed/4), and each bare node, which the chapter's prose starts in
%% a terminal of its own, started and said where it listens; then the
%% shell that is `a` started and its session typed: the counter loaded,
%% one spawned here as in chapter 1, and one on foo, a bare node that holds
%% none of its code, which the shell's first connection reaches; a send to
%% it and a call it answers. foo says that `a` connected, and nothing
%% before it, as the chapter's prose says its terminal shows (report §8.7,
%% §11.2, §11.3, Appendix E.27).
far(Base) ->
    copied(2, Base),
    [Commands, Session] = consoles(2),
    [Conf] = blocks(2, <<"json">>),
    Ports = #{Name => ern_harness:free_port() || Name <- ["foo", "bar"]},
    [ran(Base, Ports, Command) || Command <- commands(Commands)],
    listed(Base, Ports, commands(Commands), Conf),
    [Foo, Bar] = [filename:join(Base, Name) || Name <- ["foo", "bar"]],
    WaitFoo = ern_harness:bare_started(Foo, []),
    WaitBar = ern_harness:bare_started(Bar, []),
    [ern_deployment_tests:listens(filename:join(Base, Name), Port) || Name := Port <- Ports],
    Shell = opened(Base, Session),
    ern_harness:says(Foo, "the peer a connected"),
    ?assertMatch([<<"listening on ", _/binary>>, <<"the peer a connected">>],
                 untimed_lines(ern_harness:written(Foo, err))),
    #tour{base = Base, ports = Ports, foo = Foo, bar = Bar, wait_foo = WaitFoo,
          wait_bar = WaitBar, shell = Shell}.

%% Report §8.7, §11.3: a/ernest.conf, which the chapter's prose names, as
%% the page's json block shows it, each peer's address and key those the
%% harness gave the peer's directory in place of the page's, which are
%% those the page's commands gave and printed: it lists foo and bar at
%% their ports, each by its key, and offers no service. Each bare node
%% lists `a`, with no address, as the chapter's prose says.
listed(Base, Ports, Commands, Conf) ->
    Given = maps:from_list([{Dir, list_to_binary(Address)}
                            || {Words, _} <- Commands,
                               {match, [Dir, Address]}
                                   <- [re:run(Words, "--config-dir (\\S+) --listen (\\S+)",
                                              [{capture, all_but_first, list}])]]),
    Printed = maps:from_list([{Dir, join(Shown)}
                              || {"config --config-dir " ++ Rest, [_, _, _] = Shown} <- Commands,
                                 [Dir | _] <- [string:split(Rest, " ")]]),
    #{<<"peers">> := Peers} = Page = json:decode(join(Conf)),
    Peer = fun(#{<<"name">> := Name, <<"network-address">> := Address,
                 <<"public-key">> := Key} = Listed) ->
                   Dir = binary_to_list(Name),
                   ?assertEqual({Dir, maps:get(Dir, Given), maps:get(Dir, Printed)},
                                {Dir, Address, Key}),
                   maps:merge(Listed, ern_harness:peer(Dir, filename:join(Base, Dir),
                                                       maps:get(Dir, Ports)))
           end,
    A = filename:join(Base, "a"),
    ?assertEqual(Page#{<<"peers">> => lists:map(Peer, Peers)}, ern_harness:configuration(A)),
    [?assertEqual([ern_harness:peer("a", A, none)],
                  maps:get(<<"peers">>, ern_harness:configuration(filename:join(Base, Name))))
     || Name := _ <- Ports].

%% Report §11.3: a job that makes a directory, whose key it prints.
created(Base, Words) ->
    {Status, Out, Err} = ern_deployment_tests:job(Base, Words),
    ?assertEqual({0, ""}, {Status, Err}),
    ern_deployment_tests:keyed(Out).

%% Chapter 3: a reload that changes no type says the module compiled
%% again and nothing else, and one function serves the counter here and
%% the one on foo, an address being a value (report §6.5, §11.2).
client(#tour{shell = Shell} = Tour) ->
    [Session] = consoles(3),
    Tour#tour{shell = typed_console(Shell, Session)}.

%% Chapter 4: the counter of the old loop killed and one of the new
%% started, which a negative amount faults, reported with its site and its
%% trace, the version's number in it, while the send answers "ok"; a call
%% to it then answers "no answer". A counter under `restarting`, limit one
%% restart in an hour, watched by a monitor: faulted and restarted, its
%% count lost and its address kept, then faulted past the limit, which the
%% watcher hears as the fault's `Down` (report §6.9, §6.10, §7.3, §11.2,
%% Appendix E.21).
fault(#tour{shell = Shell} = Tour) ->
    [Killed, Restarted, Ended] = consoles(4),
    Tour#tour{shell = typed_console(typed_console(typed_console(Shell, Killed), Restarted),
                                    Ended)}.

%% Chapter 5: `ern build .` compiles both modules and says nothing, and
%% `ern test counter.erc` passes the first test and faults the second with
%% a deadlock, its trace beneath it and the processes left waiting beneath
%% that, and counts the two cases, ending with status 1. The reload
%% loads Tally from the build and names the two bindings of the previous
%% type, chapter 4's ended counter among them; the counter on foo is
%% refused the new protocol, with the help naming the previous version;
%% it is killed, and a counter of the new type counts per key (report
%% §3.6, §4.4, §4.9, §8.6, §12.4, §11.1, §11.2, §11.5, Appendix E.24).
per_key(#tour{base = Base, ports = Ports, shell = Shell} = Tour) ->
    [Built, Reloaded, Counted] = consoles(5),
    [ran(Base, Ports, Command) || Command <- commands(Built)],
    Tour#tour{shell = typed_console(typed_console(Shell, Reloaded), Counted)}.

%% Chapter 6: the reload names the binding of the previous type; a spawn
%% on foo of the loop whose mailbox type carries `Upgrade` is refused as
%% bound to its node; the counter here killed, and one started here and
%% one on foo by a compute, each behind an adapted address of the client's
%% type, the one on foo counting what this node sends it (report §3.11,
%% §6.5, §6.10, §8.7, §11.2, §11.5, Appendix E.27).
door(#tour{shell = Shell} = Tour) ->
    [Session] = consoles(6),
    Tour#tour{shell = typed_console(Shell, Session)}.

%% Chapter 7: a foreign function asked on each bare node answers the
%% host's count of schedulers, the shell's first compute on bar connecting
%% to it, which bar says, as the chapter's prose says; the shell holds both
%% peers' utilizations, in the configuration's order; and the computes
%% that name no node each answer the count of the primes below 200000, each
%% printing its line where it runs, which the test holds once the nodes
%% have ended (report §4.7, §8.4, §8.7, Appendix E.27).
anywhere(#tour{bar = Bar, shell = Shell} = Tour) ->
    [Asked, Anywhere] = consoles(7),
    Typed = typed_console(typed_console(Shell, Asked), Anywhere),
    ern_harness:says(Bar, "the peer a connected"),
    Computes = [Input || {"Peer.computeAnywhere(" ++ _ = Input, _, _} <- inputs(Anywhere)],
    Tour#tour{shell = Typed, computes = length(Computes)}.

%% Chapter 8: the fix, a second loop, moved to on this node and on foo,
%% each counter keeping its tally, and the nodes stopped.
fix(Tour) ->
    [Here, Ops, Attached, Called, There, Ended, Lost] = consoles(8),
    stopped(moved_there(moved_here(Tour, Here), Ops, Attached, Called, There), Ended, Lost).

%% The reload changes no type; `Code.running` lists the counter on the
%% first loop and none on the second, and `Counter.move()` sends it its
%% `Upgrade`. A report, which the counter answers after the `Upgrade` it
%% took first, says the tally is kept, and the lists are then the other
%% way round, the same address on each (quit/1); a negative amount is
%% passed over and the tally kept (report §6.4, §6.10, §11.2, Appendix
%% E.28).
moved_here(#tour{shell = Shell} = Tour, Here) ->
    Tour#tour{shell = typed_console(Shell, Here)}.

%% A shell attached to foo from ops, made by the chapter's commands with
%% no `listen`, listed in foo's file, which a reload reads, and listing
%% foo; foo says it read its file and added ops, as the prose says. The
%% shell's node says that foo connected before its start line. `:load
%% Counter` sends the sources of Counter and Tally to foo, which compiles
%% them, and foo says that ops connected; `Code.running` lists foo's
%% counter, chapter 6's, on the old loop and none on the new, and
%% `Counter.move()` sends it its `Upgrade`. The counter, which the shell
%% that is `a` then calls, as the prose says, passes a negative amount
%% over and keeps its tally, and answers the report after the `Upgrade`, so
%% the lists at foo's prompt are then the other way round, the same address
%% on each (stopped/3) (report §6.4, §8.7, §11.2, §11.3, Appendix E.28).
moved_there(#tour{base = Base, ports = Ports, foo = Foo, shell = Shell} = Tour, Ops, Attached,
            Called, There) ->
    [ran(Base, Ports, Command) || Command <- commands(Ops)],
    ern_harness:says(Foo, "the peer ops was added"),
    Sent = opened(Base, Attached),
    ern_harness:says(Foo, "the peer ops connected"),
    Back = typed_console(Shell, Called),
    Tour#tour{attached = typed_console(Sent, There), shell = Back}.

%% `ern stop --config-dir foo`, which the prose runs, ends foo by
%% termination, with status 143; the shell attached to foo ends with it,
%% with status 0, saying on its standard error that foo ended, under its
%% last prompt, as the chapter's block shows it
%% (ern_deployment_tests:ended/3), and the shell that is `a` says so too;
%% `far` then answers "ok" to an inc, since a send does not wait, and "no
%% answer" to a report; `ern stop --config-dir bar` ends bar, which the
%% shell says too, since chapter 7 connected to it, as the prose says
%% (report §8.6, §8.7, §11.2, §11.3, §11.8).
stopped(#tour{base = Base, wait_foo = WaitFoo, wait_bar = WaitBar, shell = Shell,
              attached = #shell{dir = Ops, wait = WaitAttached, read = Read} = Attached} = Tour,
        Ended, Lost) ->
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir foo")),
    ?assertEqual(143, WaitFoo()),
    ?assertEqual(0, WaitAttached()),
    addressed(Attached),
    {Out, Err} = ern_harness:said(Ops),
    ?assertEqual(Read, binary:part(list_to_binary(Out), 0, byte_size(Read))),
    Shown = [binary_to_list(Line) || Line <- Ended],
    ern_deployment_tests:ended(Shown, {Out, Err}, lists:last(Shown)),
    Told = typed_console(Shell, Lost),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, "stop --config-dir bar")),
    ?assertEqual(143, WaitBar()),
    Tour#tour{shell = unasked(Told, [<<"the peer bar ended">>])}.

%%
%% The page read
%%

%% The blocks under chapter Chapter's heading, `## 5. Per key`, up to the
%% next chapter's, whose fence's word is Mark, in order, each its lines;
%% each is recorded as a block this test checks.
blocks(Chapter, Mark) ->
    Heading = iolist_to_binary(["## ", integer_to_list(Chapter), ". "]),
    {_, [_ | Rest]} = lists:splitwith(fun({_, Line}) -> not is_prefix(Heading, Line) end,
                                      numbered(?PAGE)),
    {Section, _} = lists:splitwith(fun({_, Line}) -> not is_prefix(<<"## ">>, Line) end, Rest),
    Blocks = [{Number, Code} || {Number, Info, Code} <- fenced(Section), Info =:= Mark],
    recorded(?PAGE, [Number || {Number, _} <- Blocks]),
    [Code || {_, Code} <- Blocks].

consoles(Chapter) ->
    blocks(Chapter, <<"console">>).

%% The blocks of Document whose fences open on Lines recorded as blocks
%% this test checks, which tools/documents.ern's listing reads
%% (ern_helpers:record_checked/3).
recorded(Document, Lines) ->
    ok = ern_helpers:record_checked(?MODULE, Document, Lines).

%% A document's lines, each with its number.
numbered(Document) ->
    {ok, Text} = file:read_file(Document),
    lists:enumerate(binary:split(Text, <<"\n">>, [global])).

%% The fenced blocks of numbered lines, each the line its fence opens on,
%% the word after its fence and its lines.
fenced([]) ->
    [];
fenced([{Number, <<"```", Info/binary>>} | Rest]) ->
    {Code, [_ | After]} = lists:splitwith(fun({_, Line}) -> not is_prefix(<<"```">>, Line) end,
                                          Rest),
    [{Number, Info, [Line || {_, Line} <- Code]} | fenced(After)];
fenced([_ | Rest]) ->
    fenced(Rest).

is_prefix(Prefix, Line) ->
    binary:longest_common_prefix([Prefix, Line]) =:= byte_size(Prefix).

join(Lines) ->
    iolist_to_binary([[Line, <<"\n">>] || Line <- Lines]).

%% A console's commands, each a `$ ern` line's words after `ern` and the
%% lines the console shows it print.
commands([]) ->
    [];
commands([<<"$ ern ", Words/binary>> | Lines]) ->
    {Shown, Rest} = lists:splitwith(fun(Line) -> not is_prefix(<<"$ ">>, Line) end, Lines),
    [{binary_to_list(Words), Shown} | commands(Rest)].

%% A command of the page's run from the reader's directory, Base, a
%% `--listen` given its directory's port of Ports in place of the page's.
%% One whose lines are a key, `ern config`'s that makes a directory, prints
%% a key (report §11.3), the page's of the same form; `ern test` ends with
%% status 1 where its count says a case failed (report §11.8); every other
%% ends with status 0, and each prints the lines the page shows, none where
%% it shows none, and nothing on its standard error.
ran(Base, Ports, {Words, Shown}) ->
    {Status, Out, Err} = ern_deployment_tests:job(Base, listening(Words, Ports)),
    case Shown of
        [<<"-----BEGIN PUBLIC KEY-----">>, _, <<"-----END PUBLIC KEY-----">>] ->
            ern_deployment_tests:keyed(binary_to_list(join(Shown))),
            ?assertEqual({Words, 0, ""}, {Words, Status, Err}),
            ern_deployment_tests:keyed(Out);
        _ ->
            ?assertEqual({Words, status(Words, Shown), binary_to_list(join(Shown)), ""},
                         {Words, Status, Out, Err})
    end.

%% Report §11.8: `ern test` exits with status 1 where a case failed, which
%% its count, its last line, says.
status("test " ++ _, Shown) ->
    case re:run(lists:last(Shown), "^[0-9]+ cases?, [1-9][0-9]* failed$") of
        {match, _} -> 1;
        nomatch -> 0
    end;
status(_, _) ->
    0.

%% A command's words, its `--listen` address the harness's port for its
%% `--config-dir`.
listening(Words, Ports) ->
    case re:run(Words, "--config-dir (\\S+) --listen (\\S+)", [{capture, all_but_first, list}]) of
        {match, [Dir, Address]} ->
            Port = binary_to_list(ern_harness:address(maps:get(Dir, Ports))),
            lists:flatten(string:replace(Words, Address, Port));
        nomatch ->
            Words
    end.

%% A shell started as a console shows it, `$ ern shell` with its options,
%% in the reader's directory, Base, the lines its node says before its
%% start line held to those the console shows there and its start line the
%% release's (readme_start/0); then Before typed, each an input that
%% typed/2 types, and the console's lines (typed_console/2). A shell given
%% `--config-dir` writes its streams beside that directory.
opened(Base, Console) ->
    opened(Base, Console, []).

opened(Base, [<<"$ ern shell", Options/binary>> | Lines], Before) ->
    {Said, [Start | Rest]} = lists:splitwith(fun(Line) -> not is_prefix(<<"Ernest ">>, Line) end,
                                             Lines),
    ?assertEqual(readme_start(), Start),
    Dir = case re:run(Options, "--config-dir (\\S+)", [{capture, all_but_first, list}]) of
              {match, [Name]} -> filename:join(Base, Name);
              nomatch -> filename:join(Base, "shell")
          end,
    typed_console(session(started(Base, Dir, binary_to_list(Options), Said), Before), Rest).

%% A console's lines typed at a shell: the lines before its first input,
%% which the shell prints unasked after its prompt, then its inputs
%% (inputs/1); the numbers of the addresses the console shows are kept for
%% the shell's end (addressed/1).
typed_console(Shell, Lines) ->
    {Unasked, Rest} = lists:splitwith(fun(Line) -> not is_prefix(<<"> ">>, Line) end, Lines),
    Told = case Unasked of
               [] -> Shell;
               _ -> unasked(Shell, Unasked)
           end,
    #shell{addresses = Addresses} = Typed = session(Told, inputs(Rest)),
    Typed#shell{addresses = Addresses ++ addresses(join(Lines))}.

%% A console's inputs as typed/2 types them, read by the form the page
%% writes them in: each `> ` line, with the lines after it up to the next,
%% which it prints. A line that begins `the ` is said beside the answer, a
%% node's connection or end, a fault's report or a process's line, and
%% nothing orders it against the answer: it is a part of its own, with the
%% lines indented by four spaces after it, a trace's frames. The rest is
%% the answer, in order, a refusal's lines among it (shown/2).
inputs([]) ->
    [];
inputs([<<"> ", Input/binary>> | Rest]) ->
    {Printed, After} = lists:splitwith(fun(Line) -> not is_prefix(<<"> ">>, Line) end, Rest),
    {Answer, Said} = parted(Printed),
    [{binary_to_list(Input), [shown(binary_to_list(Input), Line) || Line <- Answer], Said}
     | inputs(After)].

parted([]) ->
    {[], []};
parted([<<"the ", _/binary>> = Line | Rest]) ->
    {Frames, After} = lists:splitwith(fun(Next) -> is_prefix(<<"    ">>, Next) end, Rest),
    {Answer, Said} = parted(After),
    {Answer, [[Line | Frames] | Said]};
parted([Line | Rest]) ->
    {Answer, Said} = parted(Rest),
    {[Line | Answer], Said}.

%% A line of an answer as this host prints it: the page's numbers that are
%% the host's or the run's stand for this host's and this run's. The
%% count of the host's schedulers, `Right(8)` of a compute of
%% `Counter.schedulers()`, is this host's; each utilization and its age,
%% `0.25, 387`, of `Peer.utilizations()` is any; and an address,
%% `<address.221>`, is any, the same where the page's are the same
%% (addressed/1).
shown("Peer.utilizations()", Line) ->
    {re, pattern(Line, "[0-9]+\\.[0-9]+, [0-9]+", "[0-9]+\\.[0-9]+(?:e-?[0-9]+)?, [0-9]+")};
shown(Input, Line) ->
    case {string:find(Input, "Counter.schedulers()"), addresses(Line)} of
        {nomatch, []} ->
            Line;
        {nomatch, _} ->
            {re, pattern(Line, "<address\\.[0-9]+>", "<address\\.[0-9]+>")};
        _ ->
            Count = integer_to_list(erlang:system_info(schedulers)),
            re:replace(Line, "^Right\\([0-9]+\\)", ["Right(", Count, ")"], [{return, binary}])
    end.

%% The line as a regular expression that matches it whole, each part that
%% Page matches standing for any text Any matches.
pattern(Line, Page, Any) ->
    Parts = re:split(Line, Page, [{return, binary}]),
    iolist_to_binary(lists:join(Any, [["\\Q", Part, "\\E"] || Part <- Parts])).

%% The numbers of the addresses a text shows, `221` of `<address.221>`, in
%% order.
addresses(Text) ->
    case re:run(Text, "<address\\.([0-9]+)>", [global, {capture, all_but_first, binary}]) of
        {match, Numbers} -> [Number || [Number] <- Numbers];
        nomatch -> []
    end.

%% Report Appendix E.1: the addresses a shell printed are the same where
%% the page's are the same, and differ where they differ, the host's
%% numbers being its own.
addressed(#shell{read = Read, addresses = Shown}) ->
    Same = fun(Numbers) -> [[Each =:= Other || Other <- Numbers] || Each <- Numbers] end,
    ?assertEqual(Same(Shown), Same(addresses(Read))).

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

%% Report §11.2, §12.5: a shell started in the reader's directory, `ern
%% shell` with Options, its HOME a directory of its own so that no
%% person's startup file runs; once it has printed its start line, as this
%% build writes it, and its first prompt, after the lines its node says as
%% it starts, Said, each without its time.
started(Base, Dir, Options) ->
    started(Base, Dir, Options, []).

started(Base, Dir, Options, Said) ->
    Home = Dir ++ ".home",
    ok = filelib:ensure_path(Home),
    {Port, Wait} = ern_harness:launched(Dir, ["cd ", Base, " && HOME=", Home, " ", ?ERN,
                                              " shell", Options]),
    ern_harness:prints(Dir, "> "),
    Started = written(Dir),
    Start = iolist_to_binary(["Ernest ", ern_release:version_text(),
                              ", session 1. :help for help.\n> "]),
    Before = byte_size(Started) - byte_size(Start),
    ?assertEqual({Said, Start}, {stamped(binary:part(Started, 0, Before)),
                                 binary:part(Started, Before, byte_size(Start))}),
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
    ern_harness:prints(Dir, "> ", Prompts, ern_harness:wait_ms()),
    {Lines, Text} = since(Shell, 1),
    Shell#shell{read = Text, carried = held(Lines, [Shown | Carried], Unordered)}.

%% Report §11.2: an input that faults, typed once the input before it has
%% printed all it prints, and held, once the prompt after it has come, to
%% its fault's line, which the regular expression Line matches, and beneath
%% it frames of its trace, each a line indented by four spaces, which this
%% does not read.
faulted(#shell{dir = Dir, port = Port, read = Read, carried = []} = Shell, Input, Line) ->
    true = port_command(Port, [Input, "\n"]),
    ern_harness:prints(Dir, "> ", count(Read, "> ") + 1, ern_harness:wait_ms()),
    {[Fault | Frames], Text} = since(Shell, 1),
    ?assertMatch({match, _}, re:run(Fault, Line, [unicode])),
    ?assertEqual([], [Frame || Frame <- Frames, string:prefix(Frame, "    ") =:= nomatch]),
    Shell#shell{read = Text}.

%% Lines the shell prints unasked after its prompt, a node's end, once its
%% stream holds them.
unasked(#shell{dir = Dir, read = Read, carried = Carried} = Shell, Lines) ->
    [ern_harness:prints(Dir, unicode:characters_to_list(Line), count(Read, Line) + 1,
                        ern_harness:wait_ms())
     || Line <- Lines],
    {Written, Text} = since(Shell, 0),
    Shell#shell{read = Text, carried = held(Written, [Lines | Carried], [])}.

%% Report §11.2: `:quit` ends the session, which leaves the cursor on a
%% line of its own and ends with status 0, having written nothing on
%% standard error, since in line mode all it says goes to standard output;
%% the addresses it printed are as the page's (addressed/1).
quit(#shell{dir = Dir, port = Port, wait = Wait, read = Read, carried = Carried} = Shell) ->
    ?assertEqual([], Carried),
    addressed(Shell),
    true = port_command(Port, ":quit\n"),
    ?assertEqual(0, Wait()),
    {Out, Err} = ern_harness:said(Dir),
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
    list_to_binary(ern_harness:written(Dir, out)).

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
