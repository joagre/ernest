%% The guide's examples, checked as the standard library's are (plan, MVP
%% 2.61 step 1). A block marked `ernest` is a complete module and compiles;
%% one whose first line names a file, `// net/http.ern`, is placed there, and
%% such blocks under one heading compile together as a source tree; blocks
%% that name the same file are its parts, in order. When the next fenced
%% block is a `console` block, the program its `$ ern` line names is run,
%% with the options the line gives, and its output compared with the
%% console's lines that are not commands. A block marked `ernest-rejected`
%% fails to compile, and for a reason of its own: not a parse error and not
%% an unknown name. When a console follows it, its `$ ernc` line names the
%% file and the error is compared whole. A console whose command is
%% `$ ern --shell` is a session: its `> ` lines are the inputs, and the rest
%% is what the shell prints. Any other block is a fragment, which nothing
%% checks.
-module(ern_guide_tests).

-include_lib("eunit/include/eunit.hrl").

-define(GUIDE, "../ernest_guide.md").

%% ernest_guide.md, plan MVP 2.61: the guide marks enough of its examples
%% for the check to hold something
guide_has_checked_examples_test() ->
    {Modules, Rejected} = lists:partition(fun({K, _}) -> K =/= rejected end, units()),
    ?assert(length(Modules) >= 15),
    ?assert(length(Rejected) >= 5).

%% ernest_guide.md: every complete example compiles, and every example with
%% its output shown prints that output
guide_examples_test_() ->
    [{Name, {timeout, 60, fun() -> check(Unit) end}}
     || {N, Unit} <- lists:zip(lists:seq(1, length(units())), units()),
        Name <- [label(N, Unit)]].

label(N, {_, #{line := Line}}) -> "guide example " ++ integer_to_list(N) ++ " at line "
                                  ++ integer_to_list(Line).

check({modules, #{files := Files, run := Run}}) ->
    Dir = tmp(),
    [ok = write(filename:join(Dir, F), Code) || {F, Code} <- Files],
    Build = filename:join(Dir, "build"),
    {Status, Out} = sh("../bin/ernc --errors short --source-root " ++ Dir ++ " --out-dir "
                       ++ Build ++ " " ++ Dir),
    ?assertEqual({0, <<>>}, {Status, Out}),
    case Run of
        none -> ok;
        {Flags, Module, Expected} ->
            {0, Printed} = sh("../bin/ern " ++ Flags ++ filename:join(Build, Module)),
            ?assertEqual(Expected, Printed)
    end;
check({rejected, #{files := [{F, Code}], shown := Shown}}) ->
    Dir = tmp(),
    ok = write(filename:join(Dir, F), Code),
    {Status, Out} = sh("cd " ++ Dir ++ " && " ++ filename:absname("../bin/ernc") ++ " " ++ F),
    ?assertMatch({1, _}, {Status, Out}),
    %% rejected for its own reason, not for a slip in the example
    ?assertEqual(nomatch, re:run(Out, "^[^:\\s]+:[0-9]+:[0-9]+: (expected |unknown name)",
                                 [multiline])),
    case Shown of
        none -> ok;
        Expected -> ?assertEqual(trim(Expected), trim(Out))
    end;
check({session, #{inputs := Inputs, shown := Expected}}) ->
    Dir = tmp(),
    In = filename:join(Dir, "inputs"),
    ok = write(In, [[I, <<"\n">>] || I <- Inputs]),
    {0, Out} = sh("cd " ++ Dir ++ " && HOME=" ++ Dir ++ " " ++ filename:absname("../bin/ern")
                  ++ " --shell < " ++ In),
    %% a session not at a terminal echoes no input, and ends at the last prompt
    ?assertEqual(trim(Expected), trim(string:trim(trim(Out), trailing, ">"))).

%% The checked units of the guide, in order: {modules, Unit} for one module
%% or a heading's source tree, {rejected, Unit} for an example that must
%% not compile.
units() ->
    {ok, Text} = file:read_file(?GUIDE),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Blocks = blocks(lists:zip(lists:seq(1, length(Lines)), Lines), none, []),
    group(Blocks).

%% Every fenced block: {Line, Info, Heading, CodeLines}.
blocks([], _, Acc) ->
    lists:reverse(Acc);
blocks([{_, <<"#", _/binary>> = H} | Rest], _, Acc) ->
    blocks(Rest, H, Acc);
blocks([{N, <<"```", Info/binary>>} | Rest], Heading, Acc) ->
    {Code, [_ | After]} = lists:splitwith(fun({_, L}) -> not fence(L) end, Rest),
    blocks(After, Heading, [{N, Info, Heading, [L || {_, L} <- Code]} | Acc]);
blocks([_ | Rest], Heading, Acc) ->
    blocks(Rest, Heading, Acc).

fence(<<"```", _/binary>>) -> true;
fence(_) -> false.

%% `ernest` blocks that name a file join the other such blocks under their
%% heading; a block that names none is a module of its own, in the file its
%% console runs, or `example.ern`.
group([]) ->
    [];
group([{N, <<"ernest-rejected">>, _, Code} | Rest]) ->
    {File, Shown} = case compiled(Rest) of
                        {F, Text} -> {F, Text};
                        none -> {file_of(Code), none}
                    end,
    [{rejected, #{line => N, files => [{File, join(Code)}], shown => Shown}} | group(Rest)];
group([{N, <<"console">>, _, [<<"$ ern --shell">> | Lines]} | Rest]) ->
    Inputs = [I || <<"> ", I/binary>> <- Lines],
    %% the prompt stays; the input after it is the terminal's echo
    Shown = [case L of <<"> ", _/binary>> -> <<"> ">>; _ -> [L, <<"\n">>] end || L <- Lines],
    [{session, #{line => N, inputs => Inputs, shown => iolist_to_binary(Shown)}} | group(Rest)];
group([{N, <<"ernest">>, Heading, Code} = B | Rest]) ->
    case named(Code) of
        none ->
            %% a module the console runs is the file the console names
            Run = run(Rest),
            File = case Run of
                       {_, Module, _} -> filename:rootname(Module) ++ ".ern";
                       none -> "example.ern"
                   end,
            [{modules, #{line => N, files => [{File, join(Code)}], run => Run}} | group(Rest)];
        _ ->
            {Same, Others} = lists:splitwith(
                               fun({_, I, H, C}) -> I =:= <<"ernest">> andalso H =:= Heading
                                                        andalso named(C) =/= none end, Rest),
            Tree = [B | Same],
            [{modules, #{line => N, files => parts([{named(C), C} || {_, _, _, C} <- Tree]),
                         run => run(Others)}} | group(Others)]
    end;
group([_ | Rest]) ->
    group(Rest).

%% The files of a source tree, each the blocks that name it joined in order.
parts(Named) ->
    Files = lists:usort([F || {F, _} <- Named]),
    [{F, join(lists:append([C || {G, C} <- Named, G =:= F]))} || F <- Files].

%% `// net/http.ern  (namespace Net.Http)` names net/http.ern.
named([First | _]) ->
    case re:run(First, "^// ([a-z0-9/]+\\.ern)", [{capture, all_but_first, list}]) of
        {match, [Path]} -> Path;
        nomatch -> none
    end;
named([]) ->
    none.

file_of(Code) ->
    case named(Code) of
        none -> "example.ern";
        Path -> Path
    end.

%% The next fenced block, when it is a console: the options and the module
%% its `$ ern` line runs, and the lines it shows that are not commands.
run([{_, <<"console">>, _, Lines} | _]) ->
    Commands = [L || <<"$ ", _/binary>> = L <- Lines],
    Shown = [[L, <<"\n">>] || L <- Lines, not lists:member(L, Commands)],
    Runs = [{Flags, M} || C <- Commands,
                          {match, [Flags, M]} <- [re:run(C, "^\\$ ern ((?:--[a-z]+ )*)(?:\\S*/)?"
                                                          "([a-z0-9]+\\.erc)",
                                                          [{capture, all_but_first, list}])]],
    case Runs of
        [{Flags, Module} | _] -> {Flags, Module, iolist_to_binary(Shown)};
        [] -> none
    end;
run(_) ->
    none.

%% The next fenced block, when it is a console whose command is `$ ernc`:
%% the file it compiles, and the lines it shows.
compiled([{_, <<"console">>, _, [Command | Lines]} | _]) ->
    case re:run(Command, "^\\$ ernc ([a-z0-9]+\\.ern)$", [{capture, all_but_first, list}]) of
        {match, [File]} -> {File, join(Lines)};
        nomatch -> none
    end;
compiled(_) ->
    none.

trim(Text) ->
    string:trim(Text, trailing).

join(Lines) ->
    iolist_to_binary([[L, <<"\n">>] || L <- Lines]).

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

sh(Cmd) ->
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", Cmd]}, exit_status, stderr_to_stdout, binary]),
    collect(Port, []).

collect(Port, Acc) ->
    receive
        {Port, {data, D}} -> collect(Port, [D | Acc]);
        {Port, {exit_status, S}} -> {S, iolist_to_binary(lists:reverse(Acc))}
    end.
