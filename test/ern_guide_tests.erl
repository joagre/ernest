%% The guide's examples, checked as the standard library's are, and the
%% report's by the same marks. A block marked `ernest` is a complete module
%% and compiles; one whose first line names a file, `// net/http.ern`, is
%% placed there, and such blocks under one heading compile together as a
%% source tree; blocks that name the same file are its parts, in order, and
%% one headed `// words.ern, continued` adds to the file as it stood
%% before, however many headings back. A tree takes beside its own files
%% each file an earlier heading wrote whose module its files name,
%% `Gather.` of `gather.ern`, as the file stood. An `erlang` block that
%% begins `-module(name).` joins them as `name.erl`, compiled with `erlc`
%% beside the compiled modules, where report §11.2 has `ern` find it.
%%
%% When the next fenced block is a `console` block, the program its `$ ern`
%% line names is run, with the options the line gives, and its output
%% compared with the console's lines that are not commands; `$ printf
%% 'a\nb\n' | ern run x.erc` gives the program those lines on standard
%% input. The run exits with status 0, or with report §11.8's status for a
%% fault of the entry process where a line shown is that fault's: the entry
%% point's name before `faulted:`, `X.main` for x.erc or the name that
%% `--main` gives.
%%
%% A block marked `ernest-rejected` fails to compile, and for a reason of
%% its own: not a parse error and not an unknown name; one after a source
%% tree under its heading is built beside the tree's files. When a console
%% follows it, its `$ ern build` line names the file and the error is
%% compared whole; where a line of the block holds a comment `// rejected`,
%% the error is on that line.
%%
%% A console whose command is `$ ern shell` is a session: its `> ` lines
%% are the inputs, and the rest is what the shell prints; `$ ern shell
%% words.erc` after a module is a session with that module loaded. A
%% session that reloads stands for an edit the document tells and does not
%% show, and a test of its own replays it (why_reload_session/0). A
%% console whose first line is a `> ` line continues the session of the
%% nearest console before it under its heading, its inputs and what the
%% shell prints added to that session's, so that a long session is shown in
%% parts with prose between; one with no session before it under its
%% heading is an error, named by its line.
%%
%% The lines the language and deployment guides quote of a run in their
%% prose are held to the run by a test of their own (quoted_runs/0).
%%
%% A block marked `ernest-prelude` holds the prelude's own declarations,
%% each one of `ern_prelude`'s as written. A block marked `ernest-fragment`,
%% and any other, is a fragment, which nothing checks; a console whose `$
%% ern run` names `--config-dir` runs on nodes, and those of the language
%% guide's §8.1 and §8.2 are tests of their own.
%%
%% The language guide's §9.6 makes two packages in a reader's directory,
%% each block a file of one or a console of commands beside `ern`: a test
%% of its own replays it (packages/0), and the check above passes over
%% every block under its heading.
%%
%% Each block a test here checks is recorded as the test reads it, its
%% document and its fence's line, for `make unchecked` to read
%% (ern_helpers:record_checked/3).
-module(ern_guide_tests).

%% EUnit's captured output (ern_helpers:captured_output/0), in place of
%% EUnit's own ?capturedOutput, which under load can answer "".
-define(capturedOutput, ern_helpers:captured_output()).

-include_lib("eunit/include/eunit.hrl").

-export([write_diagnostics/0]).

-define(GUIDE, "../guide/language.md").
-define(DIAGNOSTICS, "../docs/diagnostics.md").
%% The report, in its three files (report §0): the language, the toolchain
%% and the standard library.
-define(REPORT, ["../report/language.md", "../report/toolchain.md", "../report/library.md"]).
-define(LANGUAGE, "../report/language.md").
-define(README, "../README.md").
-define(WHY, "../guide/why.md").
-define(FAQ, "../guide/faq.md").
-define(DEPLOYMENT, "../guide/deployment.md").
%% Report §11.2: the time before a line a node writes where its stream is
%% no terminal, which the guide leaves out.
-define(STAMP, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z ").
%% The language guide's section that packages/0 replays.
-define(PACKAGES, <<"### 9.6 ">>).
%% A digest the guide cuts short, its first digits and `…`.
-define(CUT_DIGEST, "[0-9a-f]+\\x{2026}").

%% The state of a replay of the guide's §9.6 (packages/0): the directory
%% the replay began in, the one its last command left, the `PATH` each
%% command is given, and each cut digest with the digest the run printed
%% for it.
-record(replay, {start, dir, path, digests = #{}}).

%% A fenced block of a document: the line its fence opens on, the word
%% after the fence, the heading it stands under, its lines, and the lines
%% the fences of the blocks it stands for open on, its own and those of the
%% consoles joined to it (continued/2).
-record(block, {line, info, heading, code, fences}).

%% What a console after an example runs: the job and its options as the
%% console writes them, `run --main f `; the compiled file; the words
%% after it; the lines it is given on standard input; and what it shows.
-record(launch, {invocation, compiled_file, words, inputs = [], shown}).

%% guide/language.md: the guide marks enough of its examples for the check
%% to hold something
guide_has_checked_examples_test() ->
    {Modules, Rejected} = lists:partition(fun({Kind, _}) -> Kind =/= rejected end, units(?GUIDE)),
    ?assert(length(Modules) >= 15),
    ?assert(length(Rejected) >= 5).

%% report Appendix B: the report marks its examples,
%% its programs and a rejected one among them
report_has_checked_examples_test() ->
    {Modules, Rejected} = lists:partition(fun({Kind, _}) -> Kind =/= rejected end, units(?REPORT)),
    ?assert(length(Modules) >= 8),
    ?assert(length(Rejected) >= 1).

%% report §9.3, guide/language.md: a declaration the guide quotes from the
%% prelude is the prelude's, word for word once spaces are ignored
guide_prelude_declarations_test() ->
    prelude_declarations(?GUIDE).

%% report §9.3: the declarations §9.3 shows are the prelude's own
report_prelude_declarations_test() ->
    prelude_declarations(?LANGUAGE).

prelude_declarations(Document) ->
    {ok, Text} = file:read_file(Document),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Numbered = lists:zip(lists:seq(1, length(Lines)), Lines),
    Blocks = [Block || #block{info = <<"ernest-prelude">>} = Block <- blocks(Numbered)],
    recorded(Document, [Number || #block{line = Number} <- Blocks]),
    Quoted = [normalize(Declaration)
              || #block{code = Code} <- Blocks,
                 Declaration <- declarations([uncommented(Line) || Line <- Code])],
    PreludeLines = binary:split(list_to_binary(ern_prelude:declared_types()), <<"\n">>, [global]),
    Prelude = [normalize(Declaration)
               || Declaration <- declarations([uncommented(Line) || Line <- PreludeLines])],
    %% the scan found the blocks
    ?assertNotEqual([], Quoted),
    ?assertEqual([], Quoted -- Prelude).

%% Each `type` declaration of some lines, with the lines that continue it.
declarations([]) -> [];
declarations([<<"type ", _/binary>> = Line | Lines]) ->
    {Continued, Rest} = lists:splitwith(fun(Next) ->
                                            binary:first(<<Next/binary, "x">>) =:= $\s
                                        end, Lines),
    [iolist_to_binary(lists:join(" ", [Line | Continued])) | declarations(Rest)];
declarations([_ | Lines]) -> declarations(Lines).

normalize(Declaration) ->
    re:replace(string:trim(Declaration), "\\s+", " ", [global, {return, binary}]).

%% A line without its comment, which is no part of a declaration.
uncommented(Line) ->
    hd(binary:split(Line, <<"//">>)).

%% guide/language.md: every complete example compiles, and every example with
%% its output shown prints that output
%%
%% A unit that loads no code into this node runs in parallel with the others
%% of its kind, as many at once as this host has schedulers, the next begun
%% as soon as one has ended (ern_eunit:side_by_side/2): a shell session or a
%% program given standard input, each a host of its own, and a program that
%% is refused, built in this node. The rest compile and run in this node,
%% one after another, since two of them may share a module's name.
guide_examples_test_() ->
    examples(?GUIDE, "guide").

%% report §6.6, Appendix B, Appendix D: every module
%% the report shows compiles, and the example it shows rejected is refused
%% on the line it marks
report_examples_test_() ->
    examples(?REPORT, "report").

%% README.md: the front page's counter compiles; its shell console is
%% ern_tour_tests' (readme), which copies the counter, tour/2/counter.ern,
%% beside the shell
readme_examples_test_() ->
    examples(?README, "readme").

%% README.md: the front page shows the refusal of a program and not the
%% program, which is fixtures/refused/other.ern, refused as the console
%% shows. A regression test, written when the page stopped showing the
%% program (the log's *The README Recut*).
readme_refused_test_() ->
    {ok, Code} = file:read_file("fixtures/refused/other.ern"),
    {ok, Text} = file:read_file(?README),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Blocks = blocks(lists:zip(lists:seq(1, length(Lines)), Lines)),
    [{Number, Shown}] = [{Number, Shown}
                         || #block{line = Number, info = <<"console">>,
                                   code = [<<"$ ern build other.ern">> | Shown]} <- Blocks],
    recorded(?README, [Number]),
    checked({"readme's refused program",
             {rejected, #{line => Number, files => [{"other.ern", Code}], shown => join(Shown)}}}).

%% guide/why.md, guide/faq.md: the argument's programs compile as the
%% guide's do, and the questions' would if they had any
why_examples_test_() ->
    examples(?WHY, "why").

faq_examples_test_() ->
    examples(?FAQ, "faq").

%% guide/why.md, report §11.2: the session of versions, replayed as a
%% session is, its inputs and what the shell prints held to the console,
%% with the edit the prose tells made before `:reload`: `CounterMsg` gains
%% a `Reset`. The counter is the argument's, whose fragment stands above
%% the session. Its limit is the sum of its eight waits: the first prompt,
%% the five inputs, the shell's end at `:quit` and what it printed.
why_reload_session_test_() ->
    ern_harness:counted_test({waits, 8}, fun why_reload_session/0).

why_reload_session() ->
    [{Number, Lines}] = [{Number, Lines}
                         || #block{line = Number, info = <<"console">>,
                                   code = [<<"$ ern shell">> | Lines]}
                                <- blocks(numbered(?WHY)),
                            lists:member(<<":reload">>, inputs(Lines))],
    recorded(?WHY, [Number]),
    Counter = fun(Reset) ->
                  ["export type CounterMsg =
"
                   "    Inc(Int)
"
                   "  | Get(Reply(Int))
",
                   ["  | Reset
" || Reset],
                   "  | Upgrade(next : (Int) -> Unit receiving CounterMsg)

"
                   "export fn count(total : Int) : Unit receiving CounterMsg =
"
                   "    receive {
"
                   "        Inc(amount) ->
"
                   "            count(total + amount)
"
                   "      | Get(reply) -> {
"
                   "            answer(reply, total);
"
                   "            count(total)
"
                   "        }
",
                   ["      | Reset ->
            count(0)
" || Reset],
                   "      | Upgrade(=next) ->
"
                   "            next(total)
"
                   "    }
"]
              end,
    Inputs = [case Input of
                  <<":reload">> -> {Counter(true), Input};
                  _ -> Input
              end || Input <- inputs(Lines)],
    Printed = ern_helpers:tmp("ern_guide_",
                              fun(Dir) ->
                                  replayed(Dir, {"counter.ern", Counter(false)}, Inputs)
                              end),
    ?assertEqual(trim(session_shown(Lines)), session_end(Printed)).

%% guide/language.md §4.4, §5.4, §7.1, §8.1, §8.4, §9.2, §9.3 and §12,
%% guide/deployment.md section 5; report §6.9, §11.2, §12.4: each line a
%% guide quotes of a run is what the run prints, the line read from the
%% guide by the text before it. The lease broker run with `deadlock` writes
%% §5.4's line among its deadlock's report. The site of the counter
%% `examples/upgrade`'s tool spawns is the one `:processes` lists after
%% `Counter.main()` at the prompt: plain in a session that loaded the
%% second build, and with the version's number in one that loaded the
%% first and reloaded the second, its source put in the first's place after
%% the load; each guide quotes both.
%%
%% The language guide's other lines of a job are each what the job prints
%% of the program the prose describes (quoted_programs/0): the refusals of
%% one build, `ern run`'s line of a faulted and of a killed entry process,
%% `ern test`'s line of its count and of a fault a case's process made,
%% what `Test.equal` and `Test.faults` answer, a node's refusal of one key
%% under two names, `:load`'s line of a module it compiled, and what a
%% compute answers at the prompt for a function that captures a binding of
%% the session.
%%
%% Written with the lines, which the guides quoted and no test held. It
%% reads prose and no fenced block, so it records none. Its limit is the
%% sum of its thirty-three waits: the broker's build and run, the build
%% of the programs and five runs of them, each session's first prompt, a
%% prompt after each input, its end and what it printed, and the compute's
%% eight (not_loaded/1).
quoted_runs_test_() ->
    ern_harness:counted_test({waits, 33}, fun quoted_runs/0).

quoted_runs() ->
    ern_helpers:tmp("ern_guide_", fun quoted_runs/1).

quoted_runs(Base) ->
    ?assertEqual(0, ern_harness:built(["--source-root", "../examples", "--build-root", Base,
                                       "../examples/lease_broker.ern"])),
    {1, Deadlocked} = sh("../bin/ern run " ++ filename:join(Base, "lease_broker.erc")
                         ++ " deadlock"),
    Waiting = quoted(?GUIDE, <<"which call the broker: `">>),
    ?assertEqual([Waiting], [Line || Line <- [string:trim(Written, leading)
                                              || Written <- lines(Deadlocked)],
                                     Line =:= Waiting]),
    {ok, First} = file:read_file("../examples/upgrade/v1/counter.ern"),
    {ok, Second} = file:read_file("../examples/upgrade/v2/counter.ern"),
    Plain = listed(filename:join(Base, "plain"), Second,
                   [<<":load Counter">>, <<"Counter.main()">>]),
    Reloaded = listed(filename:join(Base, "reloaded"), First,
                      [<<":load Counter">>, {Second, <<":reload">>}, <<"Counter.main()">>]),
    ?assertEqual([Plain, Reloaded, Plain, Reloaded],
                 [[quoted(?GUIDE, <<"the build's plain, `">>)],
                  [quoted(?GUIDE, <<"a reload's with the version's number, `">>)],
                  [quoted(?DEPLOYMENT, <<"with the spawn's line, `">>)],
                  [quoted(?DEPLOYMENT, <<"for a reload's, `">>)]]),
    Programs = filename:join(Base, "quoted"),
    [ok = write(filename:join(Programs, Name), Code) || {Name, Code} <- quoted_programs()],
    ?assertEqual(1, ern_harness:built(["--source-root", Programs, "--build-root", Programs,
                                       Programs])),
    Refused = ?capturedOutput,
    Compiled = fun(Name) -> filename:join(Programs, Name ++ ".erc") end,
    {1, Faulted} = sh("../bin/ern run " ++ Compiled("main")),
    {1, Killed} = sh("../bin/ern run " ++ Compiled("hello")),
    {1, Tested} = sh("../bin/ern test " ++ Compiled("checks")),
    {0, Answered} = sh("../bin/ern run " ++ Compiled("checks")),
    A = ern_harness:made(Base, "a", none),
    B = ern_harness:made(Base, "b", none),
    ern_harness:lists(A, [{"b", B, none}, {"c", B, none}]),
    {1, OneKey} = sh("../bin/ern run --config-dir " ++ A ++ " " ++ Compiled("main")),
    Loaded = replayed(filename:join(Base, "words"),
                      {"words.ern", <<"export fn count(text : String) : Int =\n"
                                      "    List.size(String.words(text))\n">>},
                      [<<":load Words">>]),
    Computed = not_loaded(Base),
    ?assertEqual([], [{Before, Quoted, Output}
                      || {Before, Output}
                             <- [{<<"the caller is refused, `">>, Refused},
                                 {<<"so the read would have no one type, `">>, Refused},
                                 {<<"The build stops at the service: `">>, Refused},
                                 {<<"`ern run` prints the fault, `">>, Faulted},
                                 {<<"prints its site and `killed`, `">>, Killed},
                                 {<<"names any fault that counted outside a case, `">>, Tested},
                                 {<<"whose line names the test, `">>, Tested},
                                 {<<"where the two are equal, and otherwise `">>, Answered},
                                 {<<"naming what came instead, `">>, Answered},
                                 {<<"One key listed under two names is refused, `">>, OneKey},
                                 {<<"and says which, `">>, Loaded},
                                 {<<"5000)` answers `">>, Computed}],
                         Quoted <- [quoted(?GUIDE, Before)],
                         binary:match(Output, Quoted) =:= nomatch]).

%% The guide's §9.3 compute at the prompt of a binding of the session: a
%% shell that is the node `a` asks the bare node `foo`, which listens on a
%% port the harness found free, after `let below = 2000`, its deadline the
%% harness's time for one wait in place of the guide's 5000. Answers what
%% the shell printed, once `foo`'s standard error holds the reason of the
%% answer too, as the guide says: eight waits, `foo`'s listening, the
%% shell's first prompt and one after each input, its end and what it
%% printed, and `foo`'s end and what it said.
not_loaded(Base) ->
    Listen = ern_harness:free_port(),
    Foo = ern_harness:made(Base, "foo", Listen),
    A = ern_harness:made(Base, "desk", none),
    ok = ern_harness:lists(A, [{"foo", Foo, Listen}]),
    ok = ern_harness:lists(Foo, [{"a", A, none}]),
    Wait = ern_harness:bare_started(Foo, []),
    ok = ern_harness:says(Foo, "listening on "),
    {Port, Ended} = ern_harness:shell_started(A, Base),
    ok = ern_harness:prints(A, "> "),
    Typed = fun({Count, Input}) ->
                    true = port_command(Port, [Input, "\n"]),
                    ok = ern_harness:prints(A, "> ", Count, ern_harness:wait_ms())
            end,
    lists:foreach(Typed, [{2, "let below = 2000"},
                          {3, ["Peer.compute(\"foo\", fn() = below + 1, ",
                               ern_harness:wait_ms_text(), ")"]}]),
    true = port_command(Port, ":quit\n"),
    ?assertEqual(0, Ended()),
    {Out, _} = ern_harness:said(A),
    ern_harness:stop(Foo, Wait),
    {"", Err} = ern_harness:said(Foo),
    Printed = unicode:characters_to_binary(Out),
    {match, [Reason]} = re:run(Printed, "NotLoaded\\(\"([^\"]*)\"\\)",
                               [{capture, all_but_first, binary}]),
    ?assertNotEqual(nomatch, binary:match(unicode:characters_to_binary(Err), Reason)),
    Printed.

%% The programs the language guide's prose describes whose jobs' lines
%% quoted_runs/1 holds, each a module of one directory: three the build
%% refuses, skip's caller with no mailbox, a read of a field of two types
%% and a service at a type that holds a function, with the module it
%% names; an entry process that faults and one killed, the kill ending its
%% sleep; and a module of tests, whose cases wait for the processes they
%% start or poke to end, so that each fault comes while its case runs, and
%% whose `main` prints what `Test.equal` and `Test.faults` answer.
quoted_programs() ->
    [{"skip.ern",
      <<"fn skip() : Unit receiving e =\n"
        "    receive {\n"
        "        _ -> Unit\n"
        "    }\n\n"
        "fn rest() : Unit = skip()\n">>},
     {"reading.ern",
      <<"type Reading = Count(value : Int, unit : String) | Ratio(value : Float, unit : String)\n\n"
        "fn b(r : Reading) = r.value\n">>},
     {"registry.ern",
      <<"export type Msg = Register((Int) -> Int)\n\n"
        "fn serve() : Unit receiving Msg =\n"
        "    receive {\n"
        "        Register(_) -> serve()\n"
        "    }\n\n"
        "export let registry : Address(Msg) = spawn(fn() = serve())\n">>},
     {"client.ern",
      <<"let service : Peer.Service(Registry.Msg) = Peer.service(\"registry\")\n">>},
     {"main.ern",
      <<"fn first(list : List(Int)) : Int =\n"
        "    match list {\n"
        "        x :: _ -> x\n"
        "      | [] -> fault(\"first of an empty list\")\n"
        "    }\n\n"
        "export fn main() : Unit =\n"
        "    Io.println(Int.toString(first([])))\n">>},
     {"hello.ern",
      ["export fn main() : Unit = {\n"
       "    kill(Process.current());\n"
       "    Clock.sleep(", ern_harness:wait_ms_text(), ")\n"
       "}\n"]},
     {"checks.ern",
      <<"export fn add(left : Int, right : Int) : Int =\n"
        "    left + right\n\n"
        "type CaseMsg = Ended(Down)\n\n"
        "let addsTwo = Test.Case(name = \"adds two\", run = fn() = {\n"
        "    let _ = spawnMonitored(fn() = fault(\"the case's own process faulted\"), Ended);\n"
        "    receive {\n"
        "        Ended(_) -> Test.equal(add(1, 1), 2)\n"
        "    }\n"
        "})\n\n"
        "let addsZero = Test.Case(name = \"adds zero\", run = fn() = Test.equal(add(1, 0), 1))\n\n"
        "let pokes = Test.Case(name = \"pokes the service\", run = fn() = {\n"
        "    monitor(Process.fromAddress(service), Ended);\n"
        "    send(service, 1);\n"
        "    receive {\n"
        "        Ended(_) -> Test.Passed\n"
        "    }\n"
        "})\n\n"
        "let service : Address(Int) =\n"
        "    spawn(fn() = receive { _ -> fault(\"the service faulted\") })\n\n"
        "export fn main() : Unit = {\n"
        "    Io.println(Io.show(Test.equal(add(1, 2), 2)));\n"
        "    Io.println(Io.show(Test.faults(fn() = add(1, 1), \"division by zero\")))\n"
        "}\n">>}].

%% The span Document quotes after Before, which stands once in it, up to
%% the backtick that closes it.
quoted(Document, Before) ->
    {ok, Text} = file:read_file(Document),
    [_, After] = binary:split(Text, Before, [global]),
    hd(binary:split(After, <<"`">>)).

%% The sites `:processes` lists at the end of a session replayed in Dir
%% with Source and Inputs (replayed/3). A line of the listing is a site, an
%% activity and the bytes (report §11.2), and its first follows the prompt,
%% which a shell not at a terminal ends no line after.
listed(Dir, Source, Inputs) ->
    Out = replayed(Dir, {"counter.ern", Source}, Inputs ++ [<<":processes">>]),
    [Site || Line <- lines(Out),
             {match, [Site]} <- [re:run(Line, "^(?:> )?([^ ]+) [a-z]+ [0-9]+ bytes$",
                                        [{capture, all_but_first, binary}])]].

%% What a shell session begun in Dir, its source root and its home, prints
%% on its standard output, with Source as the file Name there: each of
%% Inputs typed at its prompt, one given as {Edit, Input} once Edit stands
%% in the file's place, then `:quit`, after which the shell ends with 0.
replayed(Dir, {Name, Source}, Inputs) ->
    File = filename:join(Dir, Name),
    ok = write(File, Source),
    Shell = filename:join(Dir, "shell"),
    {Port, Wait} = ern_harness:launched(Shell, ["cd ", Dir, " && HOME=", Dir, " ",
                                                filename:absname("../bin/ern"), " shell"]),
    ok = ern_harness:prints(Shell, "> "),
    Typed = fun({Count, Input}) ->
                    Line = case Input of
                               {Edit, Edited} -> ok = write(File, Edit), Edited;
                               _ -> Input
                           end,
                    true = port_command(Port, [Line, <<"\n">>]),
                    ok = ern_harness:prints(Shell, "> ", Count + 1, ern_harness:wait_ms())
            end,
    lists:foreach(Typed, lists:enumerate(Inputs)),
    true = port_command(Port, <<":quit\n">>),
    ?assertEqual(0, Wait()),
    {Out, _} = ern_harness:said(Shell),
    unicode:characters_to_binary(Out).

%% guide/language.md §8.1; report §8.7, §11.2, §11.3, Appendix E.27: the
%% section's square.ern run on two nodes from one directory, as the
%% console after its two directories shows it. `a` and `foo` are made
%% with `ern config` and listed in each other's by `--peer-dir`, `a` with
%% no `--listen`, a node that only dials, and `foo` listening on a port the
%% harness found free in place of 8655. `foo`, a bare node
%% started first, says where it listens, that `a` connected and that `a`
%% ended, as the section's prose says its terminal shows, each line without
%% its time; `a`'s run prints the lines its console shows, standard output
%% and standard error each in its own order, `foo computed 25` among them;
%% and `ern stop` ends `foo` by termination.
%%
%% A regression test, written after the program; it does not cover `foo`'s
%% lines against `a`'s, which two terminals do not order. Its limit is the
%% sum of its ten waits, each bounded by the harness's time for one wait:
%% the build, four `ern config` jobs, `foo`'s listening, the run, the stop,
%% `foo`'s end and what it said
work_on_a_peer_test_() ->
    ern_harness:nodes_test({waits, 10}, fun work_on_a_peer/1).

work_on_a_peer(Base) ->
    built(Base, tree_of("square.ern")),
    [[{"run --config-dir a square.erc" = RunWords, RunShown},
      {"stop --config-dir foo" = StopWords, []}]] = node_consoles(<<"### 8.1 ">>),
    ListenFoo = ern_harness:address(ern_harness:free_port()),
    [?assertMatch({0, _, ""}, ern_deployment_tests:job(Base, Words))
     || Words <- ["config --config-dir a",
                  "config --config-dir foo --listen " ++ binary_to_list(ListenFoo)]],
    [?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, Words))
     || Words <- ["config --config-dir a --peer-dir foo", "config --config-dir foo --peer-dir a"]],
    Foo = filename:join(Base, "foo"),
    Wait = ern_harness:bare_started(Foo, []),
    ern_harness:says(Foo, "listening on "),
    ran(Base, RunWords, RunShown),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, StopWords)),
    ?assertEqual(143, Wait()),
    {"", Err} = ern_harness:said(Foo),
    ?assertEqual([<<"listening on ", ListenFoo/binary>>, <<"the peer a connected">>,
                  <<"the peer a ended">>],
                 stamped(Err)).

%% guide/language.md §8.2; report §8.6, §8.7, §11.2, §11.3, Appendix E.23,
%% E.27, G.7: the section's store, desk and board run on two nodes from one
%% directory, as the two consoles after its programs show them. The
%% store's directory is made listening on a port the harness found free,
%% in place of the guide's 8655, and the desk's with no `listen`, each
%% listed in the other's by `--peer-dir` and the desk's naming the
%% service, as the section says.
%%
%% The store, run as a node, says each line its console shows, each without
%% its time, and prints nothing; the desk finds the counter and the board
%% reaches it through a proxy, each run printing the lines its console
%% shows, standard output and standard error each in its own order; and
%% `ern stop` ends the store by termination. Each run waits on what comes
%% before it: the desk on the store's listening line, the board on the
%% store's saying that the desk ended.
%%
%% A regression test, written after the programs; it does not cover the
%% store's lines against the desk's, which two terminals do not order, nor
%% that the store's counter has offered the service when the desk, a host
%% started once the store listens, asks for it, which nothing the store
%% says shows. Its limit is the sum of its twelve waits, each bounded by
%% the harness's time for one wait: the build, four `ern config` jobs, the
%% store's listening, two runs, the desk's end on the store, the stop, the
%% store's end and what it said
services_across_nodes_test_() ->
    ern_harness:nodes_test({waits, 12}, fun services_across_nodes/1).

services_across_nodes(Base) ->
    built(Base, tree_of("store.ern")),
    [[{StoreWords, StoreShown}],
     [{"run --config-dir desk desk.erc" = DeskWords, DeskShown},
      {"run --config-dir desk board.erc" = BoardWords, BoardShown},
      {"stop --config-dir store" = StopWords, []}]] = node_consoles(<<"### 8.2 ">>),
    Port = ern_harness:free_port(),
    Listen = ern_harness:address(Port),
    [Store, Desk] = [filename:join(Base, Name) || Name <- ["store", "desk"]],
    [?assertMatch({0, _, ""}, ern_deployment_tests:job(Base, Words))
     || Words <- ["config --config-dir store --listen " ++ binary_to_list(Listen),
                  "config --config-dir desk"]],
    [?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, Words))
     || Words <- ["config --config-dir desk --peer-dir store",
                  "config --config-dir store --peer-dir desk"]],
    ern_harness:edit(Desk, fun(Conf) ->
                               Conf#{<<"services">> => #{<<"counter">> => [<<"store">>]}}
                           end),
    Ern = filename:absname("../bin/ern"),
    {_, Wait} = ern_harness:launched(Store, ["cd ", Base, " && ", Ern, " ", StoreWords]),
    ern_harness:says(Store, "listening on "),
    ran(Base, DeskWords, DeskShown),
    ern_harness:says(Store, "the peer desk ended"),
    ran(Base, BoardWords, BoardShown),
    ?assertEqual({0, "", ""}, ern_deployment_tests:job(Base, StopWords)),
    ?assertEqual(143, Wait()),
    {Out, Err} = ern_harness:said(Store),
    ?assertEqual("", Out),
    ?assertEqual([binary:replace(Line, <<"127.0.0.1:8655">>, Listen) || Line <- StoreShown],
                 stamped(Err)).

%% guide/language.md §9.6; report §11.1, §11.7, §11.9: the section replayed
%% in an empty directory as a reader follows it, its blocks in order. Each
%% `$` line of its consoles is run as shown by `sh`, this checkout's `bin`
%% first on the `PATH`, in the directory the commands before it left, and
%% prints the lines the console shows after it, standard output and
%% standard error together; it exits with status 1 where those lines begin
%% with its `ern` job's refusal, `ern build: `, and with 0 otherwise. Each
%% `ernest` block is written at the path its first line names, and the
%% `json` block at `chart/package.conf`, when the section reaches it.
%%
%% The page cuts a digest short, `bbba7f66…`, and each run's archive has a
%% digest of its own, since `tar` records times and owners: a digest shown
%% cut stands for any 64 lowercase hexadecimal digits, and the manifest is
%% written with the digest the run printed in place of the cut one it
%% shows, which must be one the run printed.
%%
%% A regression test, written after the section; it does not cover what
%% the prose quotes outside a console, a named package's least version and
%% a changed entry's refusals among it, nor `--package-dir` of `ern test`
%% and `ern shell`. Its limit is the sum of its commands' waits, one each
packages_test_() ->
    Commands = [Command || #block{info = <<"console">>, code = Code} <- section_blocks(?PACKAGES),
                           Command <- replayed_commands(Code)],
    ern_harness:counted_test({waits, length(Commands)}, fun packages/0).

packages() ->
    Base = tmp(),
    Start = filename:join(Base, "section"),
    ok = filelib:ensure_path(Start),
    Path = filename:absname("../bin") ++ ":" ++ os:getenv("PATH"),
    Blocks = section_blocks(?PACKAGES),
    ?assertNotEqual([], Blocks),
    recorded(?GUIDE, [Number || #block{line = Number} <- Blocks]),
    lists:foldl(fun replayed/2, #replay{start = Start, dir = Start, path = Path}, Blocks),
    ok = file:del_dir_r(Base).

%% A block of §9.6 replayed: a console's commands run, a module and the
%% manifest written.
replayed(#block{info = <<"console">>, code = Code}, Replay) ->
    lists:foldl(fun ran_as_shown/2, Replay, replayed_commands(Code));
replayed(#block{info = <<"ernest">>, code = [First | _] = Code}, #replay{start = Start} = Replay) ->
    {match, [File]} = re:run(First, "^// (\\S+\\.ern)(?:\\s|$)", [{capture, all_but_first, list}]),
    ok = write(filename:join(Start, File), join(Code)),
    Replay;
replayed(#block{info = <<"json">>, code = Code},
         #replay{start = Start, digests = Digests} = Replay) ->
    Manifest = join(Code),
    Cut = cut_digests(Manifest),
    %% the manifest cuts the digest that the page's `sha256sum` printed
    ?assertNotEqual([], Cut),
    ?assertEqual([], [unicode:characters_to_list(Digest) || Digest <- Cut -- maps:keys(Digests)]),
    Whole = lists:foldl(fun(Digest, Text) ->
                            binary:replace(Text, Digest, maps:get(Digest, Digests), [global])
                        end, Manifest, Cut),
    ok = write(filename:join(Start, "chart/package.conf"), Whole),
    Replay;
replayed(#block{line = Line, info = Info}, _) ->
    error({unreplayed_block, Line, Info}).

%% A command run as the console shows it, by `sh` in the directory the
%% commands before it left, which it leaves in turn: its status and the
%% lines it printed, standard error among them, those the console shows.
ran_as_shown({Command, Shown}, #replay{start = Start, dir = Dir, path = Path,
                                       digests = Digests} = Replay) ->
    Left = filename:join(filename:dirname(Start), "left"),
    Script = [Command, "\nstatus=$?\npwd > '", Left, "'\nexit $status\n"],
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", iolist_to_binary(Script)]}, {cd, Dir},
                      {env, [{"PATH", Path}]}, exit_status, stderr_to_stdout, binary]),
    {Status, Printed} = ern_harness:collected(Port, 1),
    {Written, Read} = as_shown(Shown, lines(string:trim(Printed, trailing)), Digests),
    %% compared as text, which a failure prints whole, where it cuts a binary
    Text = fun(Lines) -> [unicode:characters_to_list(Line) || Line <- Lines] end,
    ?assertEqual({Text([Command]), shown_status(Command, Shown), Text(Shown)},
                 {Text([Command]), Status, Text(Written)}),
    {ok, Cwd} = file:read_file(Left),
    Replay#replay{dir = binary_to_list(string:trim(Cwd, trailing)), digests = Read}.

%% A console's commands, each `$` line's command with the lines the console
%% shows after it.
replayed_commands([<<"$ ", Command/binary>> | Lines]) ->
    {Shown, Rest} = lists:splitwith(fun(Line) -> not lists:prefix("$ ", binary_to_list(Line)) end,
                                    Lines),
    [{Command, Shown} | replayed_commands(Rest)];
replayed_commands([]) ->
    [].

%% Report §11.8: the status a command exits with, 1 for an `ern` job whose
%% lines begin with its refusal, `ern build: `, and 0 for every other.
shown_status(<<"ern ", Words/binary>>, [First | _]) ->
    [Job | _] = binary:split(Words, <<" ">>),
    case string:prefix(First, [<<"ern ">>, Job, <<": ">>]) of
        nomatch -> 0;
        _ -> 1
    end;
shown_status(_, _) ->
    0.

%% The lines a command printed, each that matches its shown line's cut
%% digests, each standing for 64 lowercase hexadecimal digits, taken as the
%% shown line; and Digests with the digest printed for each cut one.
as_shown([Shown | ShownRest], [Printed | PrintedRest], Digests) ->
    {Line, Read} = case cut_digests(Shown) of
                       [] ->
                           {Printed, Digests};
                       Cut ->
                           Parts = re:split(Shown, ?CUT_DIGEST, [unicode, {return, binary}]),
                           Pattern = ["^", lists:join("([0-9a-f]{64})",
                                                      [["\\Q", Part, "\\E"] || Part <- Parts]),
                                      "$"],
                           case re:run(Printed, iolist_to_binary(Pattern),
                                       [unicode, {capture, all_but_first, binary}]) of
                               {match, Whole} ->
                                   Found = maps:from_list(lists:zip(Cut, Whole)),
                                   {Shown, maps:merge(Digests, Found)};
                               nomatch ->
                                   {Printed, Digests}
                           end
                   end,
    {Lines, Last} = as_shown(ShownRest, PrintedRest, Read),
    {[Line | Lines], Last};
as_shown(_, Printed, Digests) ->
    {Printed, Digests}.

%% The digests a text cuts short, `bbba7f66…`, in order.
cut_digests(Text) ->
    case re:run(Text, ?CUT_DIGEST, [global, unicode, {capture, first, binary}]) of
        {match, Matches} -> [Digest || [Digest] <- Matches];
        nomatch -> []
    end.

%% The files of the guide's source tree that holds File.
tree_of(File) ->
    [Files] = [Files || {modules, #{files := Files}} <- units(?GUIDE),
                        lists:keymember(File, 1, Files)],
    Files.

%% Files written under Base and built there, Base their source root.
built(Base, Files) ->
    [ok = write(filename:join(Base, Name), Code) || {Name, Code} <- Files],
    ?assertEqual(0, ern_harness:built([Base])).

%% The commands of each console under the guide's heading that begins with
%% Heading whose first command starts a node, `$ ern run --config-dir`.
node_consoles(Heading) ->
    Consoles = [Block || #block{info = <<"console">>,
                                code = [<<"$ ern run --config-dir ", _/binary>> | _]} = Block
                             <- section_blocks(Heading)],
    recorded(?GUIDE, [Number || #block{line = Number} <- Consoles]),
    [commands(Code) || #block{code = Code} <- Consoles].

%% The blocks under the guide's heading that begins with Heading, in order.
section_blocks(Heading) ->
    [Block || #block{heading = Under} = Block <- blocks(numbered(?GUIDE)),
              is_under(Heading, Under)].

%% Whether a block's heading, Under, begins with Heading; a block before
%% any heading has none.
is_under(Heading, Under) ->
    is_binary(Under) andalso string:prefix(Under, Heading) =/= nomatch.

%% A document's lines, each with its number.
numbered(Document) ->
    {ok, Text} = file:read_file(Document),
    Lines = binary:split(Text, <<"\n">>, [global]),
    lists:zip(lists:seq(1, length(Lines)), Lines).

%% A console's commands, {Words, Shown}: a `$ ern` line's words after
%% `ern`, and the lines the console shows it print.
commands([]) ->
    [];
commands([<<"$ ern ", Words/binary>> | Lines]) ->
    {Shown, Rest} = lists:splitwith(fun(Line) -> not lists:prefix("$ ", binary_to_list(Line)) end,
                                    Lines),
    [{binary_to_list(Words), Shown} | commands(Rest)].

%% A job run from Base, which ends with status 0 and prints the lines Shown,
%% standard output and standard error each in its own order (report §11.2).
ran(Base, Words, Shown) ->
    {Status, Out, Err} = ern_deployment_tests:job(Base, Words),
    ?assertEqual(0, Status),
    same_streams(join(Shown), unicode:characters_to_binary(Out), untimed(Err)).

%% Report §11.2: what a job wrote on standard error to a file, each line
%% without the time before it.
untimed(Text) ->
    re:replace(Text, ?STAMP, "", [global, multiline, unicode, {return, binary}]).

%% Report §11.2: the lines a node wrote on standard error with the time
%% before them, as its runtime writes its own there, each without it. The
%% line after them is the launching shell's, which says that termination
%% ended the node, as a reader's shell may in the node's terminal.
stamped(Text) ->
    [untimed(Line) || Line <- lines(trim(unicode:characters_to_binary(Text))),
                      re:run(Line, ?STAMP) =/= nomatch].

%% report §11.5: each error the catalog shows is
%% the compiler's, printed as the catalog prints it; the catalog's
%% errors are its point, a parse error and an unknown name among them
diagnostics_test_() ->
    examples(?DIAGNOSTICS, "diagnostics").

examples(Document, Kind) ->
    Units = [cataloged(Kind, Unit) || Unit <- recorded_units(Document)],
    Named = [{label(Kind, Number, Unit), Unit}
             || {Number, Unit} <- lists:zip(lists:seq(1, length(Units)), Units)],
    {Apart, Here} = lists:partition(fun({_, Unit}) -> loads_nothing(Unit) end, Named),
    [ern_eunit:side_by_side(erlang:system_info(schedulers_online),
                            [checked(Example) || Example <- Apart])
     | [checked(Example) || Example <- Here]].

%% The check of a unit, a test of the harness's steps
%% (ern_harness:counted_test/3), named Name.
checked({Name, Unit}) ->
    ern_harness:counted_test(Name, {waits, steps(Unit)}, fun() -> check(Unit) end).

%% The steps check/1 takes for a unit: each Erlang module's compile by
%% `erlc`, the build, and the console's run, in this node or a host of its
%% own; a refused program's build; a session's run. A continuation fails
%% before it takes its one.
steps({modules, #{files := Files, launch := Launch}}) ->
    length([Name || {Name, _} <- Files, filename:extension(Name) =:= ".erl"]) + 1
        + case Launch of none -> 0; #launch{} -> 1 end;
steps({rejected, _}) -> 1;
steps({session, _}) -> 1;
steps({continuation, _}) -> 1.

%% The catalog's errors may be the parser's or an unknown name's, and its
%% programs are written with each picture unpictured (unpictured/1).
cataloged("diagnostics", {rejected, #{files := [{Name, Code} | Beside]} = Unit}) ->
    {rejected, Unit#{any_reason => true, files => [{Name, unpictured(Code)} | Beside]}};
cataloged(_, Unit) -> Unit.

%% Report §2.1, §11.5: a catalog's program as it is compiled, each control
%% character's picture, U+2400 to U+241F and U+2421, the character it
%% pictures, and U+FFFD the byte 0xFF, which begins no UTF-8 character, as
%% the compiler's output shows them.
unpictured(Code) ->
    iolist_to_binary([if
                          Char >= 16#2400, Char =< 16#241F -> Char - 16#2400;
                          Char =:= 16#2421 -> 16#7F;
                          Char =:= 16#FFFD -> 16#FF;
                          true -> <<Char/utf8>>
                      end || Char <- unicode:characters_to_list(Code)]).

loads_nothing({modules, #{launch := #launch{invocation = Invocation, inputs = Inputs}}}) ->
    Invocation =:= "shell " orelse Inputs =/= [];
loads_nothing({modules, _}) -> false;
loads_nothing(_) -> true.

label(Kind, Index, {_, #{line := Line}}) ->
    Kind ++ " example " ++ integer_to_list(Index) ++ " at line " ++ integer_to_list(Line).

check({modules, #{files := Files, launch := Launch}}) ->
    Dir = tmp(),
    [ok = write(filename:join(Dir, Name), Code) || {Name, Code} <- Files],
    Build = filename:join(Dir, "build"),
    ok = filelib:ensure_path(Build),
    [{0, <<>>} = sh("erlc -o " ++ Build ++ " " ++ filename:join(Dir, Name))
     || {Name, _} <- Files, filename:extension(Name) =:= ".erl"],
    ?assertEqual(0, ern_harness:built(["--source-root", Dir, "--build-root", Build, Dir])),
    ?assertEqual(<<>>, iolist_to_binary(?capturedOutput)),
    Checked = case Launch of
        none ->
            ok;
        #launch{invocation = Invocation, compiled_file = CompiledFile, words = Words,
                inputs = [], shown = Expected} when Invocation =/= "shell " ->
            %% in this node: the program's output is what the test captures
            Args = string:lexemes(Invocation, " ") ++ [filename:join(Build, CompiledFile) | Words],
            ErrorFile = filename:join(Dir, "stderr"),
            {ok, ErrorDevice} = file:open(ErrorFile, [write]),
            %% a step, bounded as a build in this node is, by the test's limit
            ern_harness:step({run, Args}),
            ?assertEqual(exit_status(Launch), ern_cli:ern(Args, ErrorDevice)),
            ok = file:close(ErrorDevice),
            {ok, Stderr} = file:read_file(ErrorFile),
            same_streams(Expected, iolist_to_binary(?capturedOutput), Stderr);
        #launch{invocation = Invocation, compiled_file = CompiledFile, words = Words,
                inputs = Inputs, shown = Expected} ->
            InputFile = filename:join(Dir, "inputs"),
            ok = write(InputFile, [[Input, <<"\n">>] || Input <- Inputs]),
            ErrorFile = filename:join(Dir, "stderr"),
            {Status, Printed} = sh("cd " ++ Dir ++ " && HOME=" ++ Dir ++ " "
                                   ++ filename:absname("../bin/ern") ++ " " ++ Invocation
                                   ++ filename:join(Build, CompiledFile)
                                   ++ [[" ", Word] || Word <- Words]
                                   ++ " < " ++ InputFile
                                   ++ " 2> " ++ ErrorFile),
            ?assertEqual(exit_status(Launch), Status),
            {ok, Stderr} = file:read_file(ErrorFile),
            same_streams(Expected, session_end(Printed), Stderr)
    end,
    ok = file:del_dir_r(Dir),
    Checked;
check({rejected, #{files := [{Name, Code} | Beside], shown := Shown} = Unit}) ->
    Dir = tmp(),
    [ok = write(filename:join(Dir, BesideName), BesideCode) || {BesideName, BesideCode} <- Beside],
    File = filename:join(Dir, Name),
    ok = write(File, Code),
    %% built in this node, the file named as a build started in Dir names it
    Status = ern_harness:built(["--source-root", Dir, File]),
    Output = named_from(Dir, unicode:characters_to_binary(?capturedOutput)),
    ok = file:del_dir_r(Dir),
    ?assertMatch({1, _}, {Status, Output}),
    %% rejected for its own reason, not for a slip in the example
    maps:get(any_reason, Unit, false) orelse
        ?assertEqual(nomatch, re:run(Output, "^[^:\\s]+:[0-9]+:[0-9]+: (expected |unknown name)",
                                     [multiline])),
    %% on the line the block marks, where it marks one
    Marked = [Number
              || {Number, Line} <- lists:zip(lists:seq(1, length(lines(Code))), lines(Code)),
                 binary:match(Line, <<"// rejected">>) =/= nomatch],
    case Marked of
        [] -> ok;
        [LineNumber | _] -> ?assertEqual({ok, LineNumber}, error_line(Output))
    end,
    case Shown of
        none -> ok;
        Expected -> ?assertEqual(trim(Expected), trim(Output))
    end;
check({session, #{inputs := Inputs, shown := Expected}}) ->
    Dir = tmp(),
    InputFile = filename:join(Dir, "inputs"),
    ok = write(InputFile, [[Input, <<"\n">>] || Input <- Inputs]),
    {0, Output} = sh("cd " ++ Dir ++ " && HOME=" ++ Dir ++ " " ++ filename:absname("../bin/ern")
                     ++ " shell < " ++ InputFile),
    ok = file:del_dir_r(Dir),
    ?assertEqual(trim(Expected), session_end(Output));
check({continuation, _}) ->
    %% a console that begins with a `> ` line, with no session before it
    %% under its heading to continue
    error(no_session_to_continue).

%% Report §11.8: the status a console's `ern run` exits with, 1 where a
%% line shown is the entry process's fault, which begins with the entry
%% point's name, its site (§6.9, §11.2), and 0 where the entry point
%% returns. Another job is held to 0.
exit_status(#launch{invocation = "run " ++ Flags, compiled_file = CompiledFile, shown = Shown}) ->
    {ok, Segment} = ern_namespace:segment(filename:rootname(CompiledFile)),
    EntryPoint = case re:run(Flags, "--main (\\S+)", [{capture, all_but_first, list}]) of
                     {match, [Given]} -> Segment ++ "." ++ Given;
                     nomatch -> Segment ++ ".main"
                 end,
    Faulted = list_to_binary(EntryPoint ++ " faulted: "),
    case [Line || Line <- lines(trim(Shown)), string:prefix(Line, Faulted) =/= nomatch] of
        [] -> 0;
        [_ | _] -> 1
    end;
exit_status(#launch{}) ->
    0.

%% Report §11.2: a console shows standard output and standard error as a
%% terminal does, but two processes write them and nothing orders one
%% against the other, so each stream is held to its own order: its lines
%% are the console's, the other stream's taken out, in order.
same_streams(Expected, Output, Stderr) ->
    Shown = lines(trim(Expected)),
    Written = lines(trim(Output)),
    Said = lines(trim(Stderr)),
    ?assertEqual(Shown -- Said, Written),
    ?assertEqual(Shown -- Written, Said).

lines(<<>>) -> [];
lines(Text) -> binary:split(Text, <<"\n">>, [global]).

%% A session not at a terminal echoes no input, and ends at the last
%% prompt, which a program's output does not end in. Its start line is
%% read as a release prints it (released/1).
session_end(Output) ->
    trim(string:trim(trim(released(Output)), trailing, ">")).

%% Report §11.2, §12.5: the shell's start line as a release prints it. The
%% repository's build is no release, and its version text carries the mark
%% (ern_release), which a document's session, shown to a release's reader,
%% does not.
released(Output) ->
    {ok, Version} = file:read_file("../VERSION"),
    binary:replace(Output, list_to_binary(["Ernest ", ern_release:version_text(), ","]),
                   <<"Ernest ", (string:trim(Version))/binary, ",">>).

%% The checked units of a document, in order: {modules, Unit} for one
%% module or a heading's source tree, {rejected, Unit} for an example that
%% must not compile, {session, Unit} for a session at the shell, and
%% {continuation, Unit} for a console that continues no session, which
%% fails.
units([First | _] = Documents) when is_list(First) ->
    lists:append([units(Document) || Document <- Documents]);
units(Document) ->
    {ok, Text} = file:read_file(Document),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Blocks = [Block || Block <- blocks(lists:zip(lists:seq(1, length(Lines)), Lines)),
                       not is_replayed(Document, Block)],
    group(continued(Blocks, []), #{}).

%% The checked units of a document, or of each of several, each document's
%% blocks its units check recorded as this test's.
recorded_units([First | _] = Documents) when is_list(First) ->
    lists:append([recorded_units(Document) || Document <- Documents]);
recorded_units(Document) ->
    Units = units(Document),
    recorded(Document, [Fence || {_, #{fences := Fences}} <- Units, Fence <- Fences]),
    Units.

%% The blocks of a document whose fences open on Lines recorded as blocks
%% this test checks, which tools/documents.ern's listing reads
%% (ern_helpers:record_checked/3).
recorded(Document, Lines) ->
    ok = ern_helpers:record_checked(?MODULE, Document, Lines).

%% Whether a block is the language guide's §9.6, which packages/0 replays.
is_replayed(?GUIDE, #block{heading = Heading}) -> is_under(?PACKAGES, Heading);
is_replayed(_, _) -> false.

%% Every fenced block of a document's numbered lines, a #block{}
%% (ern_helpers:blocks/1).
blocks(Numbered) ->
    [#block{line = Number, info = Info, heading = Heading, code = Code, fences = [Number]}
     || {Number, Heading, Info, Code} <- ern_helpers:blocks(Numbered)].

fence(<<"```", _/binary>>) -> true;
fence(_) -> false.

%% The blocks, each console whose first line is a `> ` line joined to the
%% session it continues: its lines are added to that console's, which
%% stays in its place. One that continues no session stays as it is.
continued([], Acc) ->
    lists:reverse(Acc);
continued([#block{info = <<"console">>, code = [<<"> ", _/binary>> | _] = Code,
                   fences = Fences} = Block | Rest],
          Acc) ->
    {Between, Before} = lists:splitwith(fun(#block{info = Info}) -> Info =/= <<"console">> end,
                                        Acc),
    case continues(Block, Before) of
        true ->
            [#block{code = Session, fences = Earlier} = Console | Others] = Before,
            Joined = Console#block{code = Session ++ Code, fences = Earlier ++ Fences},
            continued(Rest, Between ++ [Joined | Others]);
        false ->
            continued(Rest, [Block | Acc])
    end;
continued([Block | Rest], Acc) ->
    continued(Rest, [Block | Acc]).

%% Whether a console continues a session: the nearest console before it,
%% the first of Before, stands under its heading and holds a `$ ern shell`
%% command.
continues(#block{heading = Heading}, [#block{heading = Heading, code = Session} | _]) ->
    lists:any(fun shell_command/1, Session);
continues(_, _) ->
    false.

shell_command(<<"$ ern shell">>) -> true;
shell_command(<<"$ ern shell ", _/binary>>) -> true;
shell_command(_) -> false.

%% `ernest` blocks that name a file join the other such blocks under their
%% heading; a block that names none is a module of its own, in the file its
%% console runs, or `example.ern`.
%% Seen: each named file as it stands so far, for a block that continues it.
group([], _Seen) ->
    [];
group([#block{line = Number, info = <<"ernest-rejected">>, heading = Heading, code = Code,
              fences = Own} | Rest],
      Seen) ->
    {File, Shown, Console} = case compiled(Rest) of
                                 {Name, Text} -> {Name, Text, console_fences(Rest)};
                                 none -> {file_of(Code), none, []}
                             end,
    %% the files the source tree before it under its heading names, which
    %% it is built beside
    Beside = maps:get({tree, Heading}, Seen, []),
    Unit = #{line => Number, fences => Own ++ Console, files => [{File, join(Code)} | Beside],
             shown => Shown},
    [{rejected, Unit} | group(Rest, Seen)];
group([#block{line = Number, info = <<"console">>, code = [<<"$ ern shell">> | Lines],
              fences = Fences} | Rest],
      Seen) ->
    case lists:member(<<":reload">>, inputs(Lines)) of
        true ->
            group(Rest, Seen);
        false ->
            [{session, #{line => Number, fences => Fences, inputs => inputs(Lines),
                         shown => session_shown(Lines)}}
             | group(Rest, Seen)]
    end;
group([#block{line = Number, info = <<"console">>, code = [<<"> ", _/binary>> | _],
              fences = Fences} | Rest],
      Seen) ->
    %% continued/2 joined every console that continues a session to it
    [{continuation, #{line => Number, fences => Fences}} | group(Rest, Seen)];
group([#block{line = Number, info = Info, heading = Heading, code = Code,
              fences = BlockFences} = Block | Rest], Seen)
  when Info =:= <<"ernest">>; Info =:= <<"erlang">> ->
    case named(Code) of
        none when Info =:= <<"erlang">> ->
            %% Erlang without a module line is a fragment
            group(Rest, Seen);
        none ->
            %% a module the console runs is the file the console names
            Launch = launch(Rest),
            File = case Launch of
                       #launch{compiled_file = CompiledFile} ->
                           filename:rootname(CompiledFile) ++ ".ern";
                       none -> "example.ern"
                   end,
            [{modules, #{line => Number, fences => BlockFences ++ launch_fences(Launch, Rest),
                         files => [{File, join(Code)}], launch => Launch}}
             | group(Rest, Seen)];
        _ ->
            InTree = fun(#block{info = BlockInfo, heading = BlockHeading, code = BlockCode}) ->
                         lists:member(BlockInfo, [<<"ernest">>, <<"erlang">>])
                             andalso BlockHeading =:= Heading andalso named(BlockCode) =/= none
                     end,
            {Same, Others} = lists:splitwith(InTree, Rest),
            Tree = [Block | Same],
            Own = parts([{named(BlockCode), BlockCode} || #block{code = BlockCode} <- Tree],
                        Seen),
            Files = Own ++ used(Own, Seen),
            Seen1 = (maps:merge(Seen, maps:from_list(Own)))#{{tree, Heading} => Files},
            Launch = launch(Others),
            Fences = lists:append([Each || #block{fences = Each} <- Tree])
                ++ launch_fences(Launch, Others),
            Unit = #{line => Number, fences => Fences, files => Files, launch => Launch},
            [{modules, Unit} | group(Others, Seen1)]
    end;
group([_ | Rest], Seen) ->
    group(Rest, Seen).

%% The fences of the console a unit's launch is read from, the next block,
%% or none where nothing launches it.
launch_fences(none, _) -> [];
launch_fences(#launch{}, Blocks) -> console_fences(Blocks).

%% The fences of the next block, a console a unit reads.
console_fences([#block{info = <<"console">>, fences = Fences} | _]) -> Fences.

%% The files an earlier heading wrote, Seen, that a source tree's files,
%% Own, name the module of and do not hold, each as it stood.
used(Own, Seen) ->
    [{Name, Code} || {Name, Code} <- maps:to_list(Seen), is_list(Name),
                     not lists:keymember(Name, 1, Own),
                     lists:any(fun({_, OwnCode}) -> names_module(OwnCode, Name) end, Own)].

%% Whether Code names the module of File, `gather.ern`'s `Gather.`.
names_module(Code, File) ->
    Segments = [string:titlecase(Segment)
                || Segment <- string:split(filename:rootname(File), "/", all)],
    Module = list_to_binary(lists:join(".", [lists:append([string:titlecase(Word)
                                                            || Word <- string:split(Segment, "_",
                                                                                    all)])
                                             || Segment <- Segments])),
    binary:match(Code, <<Module/binary, ".">>) =/= nomatch.

%% The files of a source tree, each the blocks that name it joined in order,
%% after the file as it stood when its first block here continues it.
parts(Named, Seen) ->
    Files = lists:usort([Name || {Name, _} <- Named]),
    [{Name, iolist_to_binary([before(Name, Named, Seen)
                              | [join(Code) || {BlockName, Code} <- Named, BlockName =:= Name]])}
     || Name <- Files].

before(Name, Named, Seen) ->
    [First | _] = [Code || {BlockName, Code} <- Named, BlockName =:= Name],
    case re:run(hd(First), "^// [a-z0-9_/]+\\.ern, continued") of
        {match, _} -> maps:get(Name, Seen);
        nomatch -> <<>>
    end.

%% `// net/http.ern  (namespace Net.Http)` names net/http.ern, and
%% `-module(store_helper).` names store_helper.erl.
named([First | _]) ->
    case re:run(First, "^// ([a-z0-9_/]+\\.ern)", [{capture, all_but_first, list}]) of
        {match, [Path]} ->
            Path;
        nomatch ->
            case re:run(First, "^-module\\(([a-z0-9_]+)\\)\\.", [{capture, all_but_first, list}]) of
                {match, [Module]} -> Module ++ ".erl";
                nomatch -> none
            end
    end;
named([]) ->
    none.

file_of(Code) ->
    case named(Code) of
        none -> "example.ern";
        Path -> Path
    end.

%% The next fenced block, when it is a console: the job, its options, the
%% module its `$ ern run`, `test` or `shell` line runs and the words after
%% it, and the lines it shows that are not commands.
launch([#block{info = <<"console">>, code = Lines} | _]) ->
    Commands = [Line || <<"$ ", _/binary>> = Line <- Lines],
    Output = [Line || Line <- Lines, not lists:member(Line, Commands)],
    Launches = [{Piped, #launch{invocation = Job ++ " " ++ Flags, compiled_file = CompiledFile,
                                words = string:lexemes(Words, " ")}}
                || Command <- Commands,
                   {match, [Piped, Job, Flags, CompiledFile, Words]}
                       <- [re:run(Command,
                                  "^\\$ (?:printf '([^']*)' \\| )?ern (run|test|shell) "
                                  "((?:--[a-z]+ \\S+ )*)(?:\\S*/)?([a-z0-9_]+\\.erc)"
                                  "((?: +[^#\\s]\\S*)*) *(?:#.*)?$",
                                  [{capture, all_but_first, list}])]],
    case Launches of
        [{_, #launch{invocation = "shell "} = Launch} | _] ->
            Launch#launch{inputs = inputs(Output), shown = session_shown(Output)};
        [{Piped, Launch} | _] ->
            Stdin = [Line || Line <- string:split(Piped, "\\n", all), Line =/= ""],
            Launch#launch{inputs = Stdin, shown = join(Output)};
        [] ->
            none
    end;
launch(_) ->
    none.

%% The next fenced block, when it is a console whose command is `$ ern build`:
%% the file it compiles, and the lines it shows.
compiled([#block{info = <<"console">>, code = [Command | Lines]} | _]) ->
    case re:run(Command, "^\\$ ern build ([a-z0-9_/]+\\.ern)$",
                [{capture, all_but_first, list}]) of
        {match, [File]} -> {File, join(Lines)};
        nomatch -> none
    end;
compiled(_) ->
    none.

%% A session's inputs are its `> ` lines.
inputs(Lines) ->
    [Input || <<"> ", Input/binary>> <- Lines].

%% What a session prints not at a terminal: the prompt stays, and the input
%% after it, which is the terminal's echo, goes.
session_shown(Lines) ->
    iolist_to_binary([case Line of <<"> ", _/binary>> -> <<"> ">>; _ -> [Line, <<"\n">>] end
                      || Line <- Lines]).

%% The text without its trailing blanks, and with the number the host gives
%% a process masked in `<process.84>` and `<address.84>`, and after a
%% peer's name in `<process.store.84>`, since it is the host's count and
%% not the language's (report Appendix E.1).
trim(Text) ->
    re:replace(string:trim(Text, trailing), "<(address|process)\\.([^>\\n]*?)[0-9]+>",
               "<\\1.\\2N>", [global, unicode, {return, binary}]).

join(Lines) ->
    iolist_to_binary([[Line, <<"\n">>] || Line <- Lines]).

%% The line of the first error a compilation reports.
error_line(Output) ->
    case re:run(Output, "^[^:\\s]+:([0-9]+):", [{capture, all_but_first, list}]) of
        {match, [Digits]} -> {ok, list_to_integer(Digits)};
        nomatch -> none
    end.

%% make diagnostics: every program of the catalog compiled again, and
%% the console after it written with what `ern build` prints for it, after
%% a change to a message that is meant
-spec write_diagnostics() -> ok.
write_diagnostics() ->
    {ok, Text} = file:read_file(?DIAGNOSTICS),
    Lines = binary:split(Text, <<"\n">>, [global]),
    ok = file:write_file(?DIAGNOSTICS, lists:join(<<"\n">>, rewrite(Lines, []))).

%% Beside: the files the `ernest` blocks under the heading so far name,
%% which a program refused under it is built beside, as check/1 builds it.
rewrite([<<"#", _/binary>> = Heading | Rest], _Beside) ->
    [Heading | rewrite(Rest, [])];
rewrite([<<"```ernest-rejected">> = Open | Rest], Beside) ->
    {Code, [Close | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    File = file_of(Code),
    Console = [<<"```console">>, iolist_to_binary(["$ ern build ", File])
               | lines(string:trim(printed(File, unpictured(join(Code)), Beside), trailing))]
        ++ [<<"```">>],
    [Open | Code] ++ [Close | consoled(After, Console, Beside)];
rewrite([<<"```", Info/binary>> = Open | Rest], Beside) ->
    {Code, [Close | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    Named = [{Name, join(Code)} || Info =:= <<"ernest">>, Name <- [named(Code)], Name =/= none],
    [Open | Code] ++ [Close | rewrite(After, Beside ++ Named)];
rewrite([Line | Rest], Beside) ->
    [Line | rewrite(Rest, Beside)];
rewrite([], _Beside) ->
    [].

%% The program's console, in place of the one after it or where none is.
consoled([<<>>, <<"```console">> | Rest], Console, Beside) ->
    {_, [_ | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    [<<>> | Console] ++ rewrite(After, Beside);
consoled(After, Console, Beside) ->
    [<<>> | Console] ++ rewrite(After, Beside).

%% What `ern build Name` prints for a program, in a directory of its own
%% with the files Beside: built in this node, as the catalog's test builds
%% it (check/1), so that the catalog costs its compiling and not a host's
%% start for each program. The build's output and its errors go to one
%% file, in the order they are written, as a console shows them; the group
%% leader is put back however the build ends, so that a failure of ern's
%% own is seen.
printed(Name, Code, Beside) ->
    Dir = tmp(),
    [ok = write(filename:join(Dir, BesideName), BesideCode) || {BesideName, BesideCode} <- Beside],
    File = filename:join(Dir, Name),
    ok = write(File, Code),
    Printed = filename:join(Dir, "printed"),
    {ok, Device} = file:open(Printed, [write, {encoding, utf8}]),
    Leader = group_leader(),
    true = group_leader(Device, self()),
    try ern_cli:ern(["build", "--source-root", Dir, File], Device)
    after
        true = group_leader(Leader, self())
    end,
    ok = file:close(Device),
    {ok, Output} = file:read_file(Printed),
    ok = file:del_dir_r(Dir),
    named_from(Dir, Output).

%% Report §11.5: a build's output, Dir's path taken out, so that each file
%% is named as a build started in Dir names it.
named_from(Dir, Output) ->
    binary:replace(Output, list_to_binary(Dir ++ "/"), <<>>, [global]).

%% A fresh directory of the check's own, named by the run and a count so
%% that no earlier run's is read, and removed once the check has what it
%% needs; one a failed check leaves stays, for a reader.
tmp() ->
    ern_helpers:tmp("ern_guide_").

write(Path, Code) ->
    ok = filelib:ensure_dir(Path),
    file:write_file(Path, Code).

%% A command run by the host's shell to its end: its status, and what it
%% wrote, its standard error beside its standard output; one step of the
%% harness's (ern_harness:collected/2).
sh(Command) ->
    ern_harness:collected(open_port({spawn_executable, "/bin/sh"},
                                    [{args, ["-c", Command]}, exit_status, stderr_to_stdout,
                                     binary]), 1).

