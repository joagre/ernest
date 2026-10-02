%% The guide's examples, checked as the standard library's are (plan, MVP
%% 2.61 step 1), and the report's by the same marks. A block marked
%% `ernest` is a complete module and compiles; one whose first line names
%% a file, `// net/http.ern`, is placed there, and such blocks under one
%% heading compile together as a source tree; blocks that name the same
%% file are its parts, in order, and one headed `// words.ern, continued`
%% adds to the file as it stood before, however many headings back. An
%% `erlang` block that begins `-module(name).` joins them as `name.erl`,
%% compiled with `erlc` beside the compiled modules, where report §11.2 has
%% `ern` find it. When the next fenced block is a `console` block, the
%% program its `$ ern` line names is run, with the options the line gives,
%% and its output compared with the console's lines that are not commands;
%% `$ printf 'a\nb\n' | ern run x.erc` gives the program those lines on
%% standard input. A block marked `ernest-rejected` fails to compile, and
%% for a reason of its own: not a parse error and not an unknown name. When
%% a console follows it, its `$ ern build` line names the file and the
%% error is compared whole; where a line of the block holds a comment
%% `// rejected`, the error is on that line. A console whose command is
%% `$ ern shell` is a session: its `> ` lines are the inputs, and the rest
%% is what the shell prints; `$ ern shell words.erc` after a module is a
%% session with that module loaded. A block marked `ernest-prelude` holds
%% the prelude's own declarations, each one of `ern_prelude`'s as written.
%% A block marked `ernest-fragment`, and any other, is a fragment, which
%% nothing checks.
-module(ern_guide_tests).

%% EUnit's captured output, asked of the test's group leader, which is
%% EUnit's. EUnit's own ?capturedOutput first asks whether it is by the
%% function it is running, which under load it can sample while that
%% process runs another module's code, and then answers "" (MVP 2.95's
%% intermittent failure of the diagnostics' examples).
-define(capturedOutput, captured_output()).

-include_lib("eunit/include/eunit.hrl").

-export([units/1, write_diagnostics/0]).

-define(GUIDE, "../ernest_guide.md").
-define(DIAGNOSTICS, "diagnostics.md").
-define(REPORT, "../ernest_report.md").
-define(README, "../README.md").

%% A fenced block of a document: the line its fence opens on, the word
%% after the fence, the heading it stands under, and its lines.
-record(block, {line, info, heading, code}).

%% What a console after an example runs: the job and its options as the
%% console writes them, `run --main M.f `; the compiled file; the words
%% after it; the lines it is given on standard input; and what it shows.
-record(launch, {invocation, compiled_file, words, inputs = [], shown}).

%% ernest_guide.md, plan MVP 2.61: the guide marks enough of its examples
%% for the check to hold something
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

%% report §9.3, ernest_guide.md: a declaration the guide quotes from the
%% prelude is the prelude's, word for word once spaces are ignored
guide_prelude_declarations_test() ->
    prelude_declarations(?GUIDE).

%% report §9.3: the declarations §9.3 shows are the prelude's own
report_prelude_declarations_test() ->
    prelude_declarations(?REPORT).

prelude_declarations(Document) ->
    {ok, Text} = file:read_file(Document),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Numbered = lists:zip(lists:seq(1, length(Lines)), Lines),
    Quoted = [normalize(Declaration)
              || #block{info = <<"ernest-prelude">>, code = Code} <- blocks(Numbered, none, []),
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

%% ernest_guide.md: every complete example compiles, and every example with
%% its output shown prints that output
%%
%% A unit that loads no code into this node runs in parallel with the others
%% of its kind, as many at once as this host has schedulers: a shell session
%% or a program given standard input, each a host of its own, and a program
%% that is refused, built in this node. The rest compile and run in this
%% node, one after another, since two of them may share a module's name
%% (plan, MVP 2.6).
guide_examples_test_() ->
    examples(?GUIDE, "guide").

%% report §6.6, Appendix B, Appendix D: every module
%% the report shows compiles, and the example it shows rejected is refused
%% on the line it marks
report_examples_test_() ->
    examples(?REPORT, "report").

%% README.md: the front page's example compiles, as the guide's do
readme_examples_test_() ->
    examples(?README, "readme").

%% report §11.5: each error the catalogue shows is
%% the compiler's, printed as the catalogue prints it; the catalogue's
%% errors are its point, a parse error and an unknown name among them
diagnostics_test_() ->
    examples(?DIAGNOSTICS, "diagnostics").

examples(Document, Kind) ->
    Units = [catalogued(Kind, Unit) || Unit <- units(Document)],
    Named = [{label(Kind, Number, Unit), Unit}
             || {Number, Unit} <- lists:zip(lists:seq(1, length(Units)), Units)],
    {Apart, Here} = lists:partition(fun({_, Unit}) -> loads_nothing(Unit) end, Named),
    [{inparallel, erlang:system_info(schedulers_online),
      [{Name, {timeout, 60, fun() -> check(Unit) end}} || {Name, Unit} <- Apart]}
     | [{Name, {timeout, 60, fun() -> check(Unit) end}} || {Name, Unit} <- Here]].

%% The catalogue's errors may be the parser's or an unknown name's.
catalogued("diagnostics", {rejected, Unit}) -> {rejected, Unit#{any_reason => true}};
catalogued(_, Unit) -> Unit.

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
    %% guide §8.3: a program that uses a library under libs/ has it on its
    %% load path, as every example here may
    LoadPathOptions = lists:append([["--load-path", filename:absname(Library)]
                                    || Library <- filelib:wildcard("../build/libs/*"),
                                       filelib:is_dir(Library)]),
    ?assertEqual(0, ern_cli:ern(["build", "--short-errors", "--source-root", Dir,
                                 "--build-root", Build | LoadPathOptions] ++ [Dir],
                                group_leader())),
    ?assertEqual(<<>>, iolist_to_binary(?capturedOutput)),
    case Launch of
        none ->
            ok;
        #launch{invocation = Invocation, compiled_file = CompiledFile, words = Words,
                inputs = [], shown = Expected} when Invocation =/= "shell " ->
            %% in this node: the program's output is what the test captures
            Args = string:lexemes(Invocation, " ") ++ [filename:join(Build, CompiledFile) | Words],
            ErrorFile = filename:join(Dir, "stderr"),
            {ok, ErrorDevice} = file:open(ErrorFile, [write]),
            ?assertEqual(0, ern_cli:ern(Args, ErrorDevice)),
            ok = file:close(ErrorDevice),
            {ok, Stderr} = file:read_file(ErrorFile),
            same_streams(Expected, iolist_to_binary(?capturedOutput), Stderr);
        #launch{invocation = Invocation, compiled_file = CompiledFile, words = Words,
                inputs = Inputs, shown = Expected} ->
            InputFile = filename:join(Dir, "inputs"),
            ok = write(InputFile, [[Input, <<"\n">>] || Input <- Inputs]),
            ErrorFile = filename:join(Dir, "stderr"),
            {0, Printed} = sh("cd " ++ Dir ++ " && HOME=" ++ Dir ++ " "
                              ++ filename:absname("../bin/ern") ++ " " ++ Invocation
                              ++ filename:join(Build, CompiledFile)
                              ++ [[" ", Word] || Word <- Words]
                              ++ " < " ++ InputFile
                              ++ " 2> " ++ ErrorFile),
            {ok, Stderr} = file:read_file(ErrorFile),
            same_streams(Expected, session_end(Printed), Stderr)
    end;
check({rejected, #{files := [{Name, Code}], shown := Shown} = Unit}) ->
    Dir = tmp(),
    File = filename:join(Dir, Name),
    ok = write(File, Code),
    %% built in this node, the file named as a build started in Dir names it
    Status = ern_cli:ern(["build", "--source-root", Dir, File], group_leader()),
    Output = binary:replace(unicode:characters_to_binary(?capturedOutput),
                            list_to_binary(Dir ++ "/"), <<>>, [global]),
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
    ?assertEqual(trim(Expected), session_end(Output)).

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
%% prompt, which a program's output does not end in.
session_end(Output) ->
    trim(string:trim(trim(Output), trailing, ">")).

%% The checked units of a document, in order: {modules, Unit} for one
%% module or a heading's source tree, {rejected, Unit} for an example that
%% must not compile, and {session, Unit} for a session at the shell.
units(Document) ->
    {ok, Text} = file:read_file(Document),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Blocks = blocks(lists:zip(lists:seq(1, length(Lines)), Lines), none, []),
    group(Blocks, #{}).

%% Every fenced block, a #block{}.
blocks([], _, Acc) ->
    lists:reverse(Acc);
blocks([{_, <<"#", _/binary>> = Heading} | Rest], _, Acc) ->
    blocks(Rest, Heading, Acc);
blocks([{Number, <<"```", Info/binary>>} | Rest], Heading, Acc) ->
    {Code, [_ | After]} = lists:splitwith(fun({_, Line}) -> not fence(Line) end, Rest),
    Block = #block{line = Number, info = Info, heading = Heading,
                   code = [Line || {_, Line} <- Code]},
    blocks(After, Heading, [Block | Acc]);
blocks([_ | Rest], Heading, Acc) ->
    blocks(Rest, Heading, Acc).

fence(<<"```", _/binary>>) -> true;
fence(_) -> false.

%% `ernest` blocks that name a file join the other such blocks under their
%% heading; a block that names none is a module of its own, in the file its
%% console runs, or `example.ern`.
%% Seen: each named file as it stands so far, for a block that continues it.
group([], _Seen) ->
    [];
group([#block{line = Number, info = <<"ernest-rejected">>, code = Code} | Rest], Seen) ->
    {File, Shown} = case compiled(Rest) of
                        {Name, Text} -> {Name, Text};
                        none -> {file_of(Code), none}
                    end,
    Unit = #{line => Number, files => [{File, join(Code)}], shown => Shown},
    [{rejected, Unit} | group(Rest, Seen)];
group([#block{line = Number, info = <<"console">>, code = [<<"$ ern shell">> | Lines]} | Rest],
      Seen) ->
    [{session, #{line => Number, inputs => inputs(Lines), shown => session_shown(Lines)}}
     | group(Rest, Seen)];
group([#block{line = Number, info = Info, heading = Heading, code = Code} = Block | Rest], Seen)
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
            [{modules, #{line => Number, files => [{File, join(Code)}], launch => Launch}}
             | group(Rest, Seen)];
        _ ->
            InTree = fun(#block{info = BlockInfo, heading = BlockHeading, code = BlockCode}) ->
                         lists:member(BlockInfo, [<<"ernest">>, <<"erlang">>])
                             andalso BlockHeading =:= Heading andalso named(BlockCode) =/= none
                     end,
            {Same, Others} = lists:splitwith(InTree, Rest),
            Tree = [Block | Same],
            Files = parts([{named(BlockCode), BlockCode} || #block{code = BlockCode} <- Tree],
                          Seen),
            Seen1 = maps:merge(Seen, maps:from_list(Files)),
            Unit = #{line => Number, files => Files, launch => launch(Others)},
            [{modules, Unit} | group(Others, Seen1)]
    end;
group([_ | Rest], Seen) ->
    group(Rest, Seen).

%% The files of a source tree, each the blocks that name it joined in order,
%% after the file as it stood when its first block here continues it.
parts(Named, Seen) ->
    Files = lists:usort([Name || {Name, _} <- Named]),
    [{Name, iolist_to_binary([before(Name, Named, Seen)
                              | [join(Code) || {BlockName, Code} <- Named, BlockName =:= Name]])}
     || Name <- Files].

before(Name, Named, Seen) ->
    [First | _] = [Code || {BlockName, Code} <- Named, BlockName =:= Name],
    case re:run(hd(First), "^// [a-z0-9/]+\\.ern, continued") of
        {match, _} -> maps:get(Name, Seen);
        nomatch -> <<>>
    end.

%% `// net/http.ern  (namespace Net.Http)` names net/http.ern, and
%% `-module(store_helper).` names store_helper.erl.
named([First | _]) ->
    case re:run(First, "^// ([a-z0-9/]+\\.ern)", [{capture, all_but_first, list}]) of
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
                                  "((?:--[a-z]+ \\S+ )*)(?:\\S*/)?([a-z0-9]+\\.erc)"
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
    case re:run(Command, "^\\$ ern build ([a-z0-9]+\\.ern)$",
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
%% a process masked in `<process 84>` and `<address 84>`, since it is the
%% host's count and not the language's (report Appendix E.1).
trim(Text) ->
    re:replace(string:trim(Text, trailing), "<(address|process) [0-9]+>", "<\\1 N>",
               [global, unicode, {return, binary}]).

join(Lines) ->
    iolist_to_binary([[Line, <<"\n">>] || Line <- Lines]).

%% The line of the first error a compilation reports.
error_line(Output) ->
    case re:run(Output, "^[^:\\s]+:([0-9]+):", [{capture, all_but_first, list}]) of
        {match, [Digits]} -> {ok, list_to_integer(Digits)};
        nomatch -> none
    end.

%% make diagnostics: every program of the catalogue compiled again, and
%% the console after it written with what `ern build` prints for it, after
%% a change to a message that is meant
-spec write_diagnostics() -> ok.
write_diagnostics() ->
    {ok, Text} = file:read_file(?DIAGNOSTICS),
    Lines = binary:split(Text, <<"\n">>, [global]),
    ok = file:write_file(?DIAGNOSTICS, lists:join(<<"\n">>, rewrite(Lines))).

rewrite([<<"```ernest-rejected">> = Open | Rest]) ->
    {Code, [Close | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    Console = [<<"```console">>, <<"$ ern build example.ern">>
               | lines(string:trim(printed(join(Code)), trailing))] ++ [<<"```">>],
    [Open | Code] ++ [Close | consoled(After, Console)];
rewrite([Line | Rest]) ->
    [Line | rewrite(Rest)];
rewrite([]) ->
    [].

%% The program's console, in place of the one after it or where none is.
consoled([<<>>, <<"```console">> | Rest], Console) ->
    {_, [_ | After]} = lists:splitwith(fun(Line) -> not fence(Line) end, Rest),
    [<<>> | Console] ++ rewrite(After);
consoled(After, Console) ->
    [<<>> | Console] ++ rewrite(After).

%% What `ern build` prints for a program, in a directory of its own.
printed(Code) ->
    Dir = tmp(),
    ok = write(filename:join(Dir, "example.ern"), Code),
    {_, Output} = sh("cd " ++ Dir ++ " && " ++ filename:absname("../bin/ern")
                     ++ " build example.ern"),
    Output.

%% A fresh directory: the counter restarts with each run, so one left by an
%% earlier run is removed first.
tmp() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    Dir = filename:join("/tmp", "ern_guide_" ++ Unique),
    _ = file:del_dir_r(Dir),
    ok = filelib:ensure_path(Dir),
    Dir.

write(Path, Code) ->
    ok = filelib:ensure_dir(Path),
    file:write_file(Path, Code).

sh(Command) ->
    Shell = open_port({spawn_executable, "/bin/sh"},
                      [{args, ["-c", Command]}, exit_status, stderr_to_stdout, binary]),
    collect(Shell, []).

collect(Shell, Acc) ->
    receive
        {Shell, {data, Data}} -> collect(Shell, [Data | Acc]);
        {Shell, {exit_status, Status}} -> {Status, iolist_to_binary(lists:reverse(Acc))}
    end.

captured_output() ->
    group_leader() ! {get_output, self()},
    receive {output, Output} -> Output end.
