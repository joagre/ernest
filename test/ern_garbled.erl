%% docs/coherence.md C22, `make garbled`: the front end given input it was
%% not written for. Every example and every module of the standard library
%% is garbled at each of its tokens in turn, the token deleted, the token
%% doubled, and the token swapped with the next, and each garbled source is
%% given to `ern build`; every input of the shell's sessions, those of the
%% guide, the report and the catalogue of diagnostics and test/session/, is
%% garbled the same way and given to the shell, each garbled input before
%% the input it came from. Every one must be answered, `ern build` with a
%% module or a diagnostic and the shell with its answer, and none with a
%% failure of the toolchain: an exception out of `ern build`, a shell that
%% ends with a status other than 0 or writes to standard error, or no
%% answer at all. Not part of `make test`: it builds some eighty-six
%% thousand sources, in about seven minutes, and a release runs it, as
%% docs/coherence.md's row for a release says.
-module(ern_garbled).

-export([main/0]).

-define(REPO, "..").
-define(SCRATCH, "build/garbled").

%% How long one garbled source may take to build, and one shell session to
%% end, before it counts as no answer.
-define(BUILD_MS, 60000).
-define(SESSION_MS, 300000).

%% The input that stands before a session's last, whose answer shows the
%% session went on to it: a string, which the shell answers with itself.
-define(MARKER, "\"make garbled: the session went on\"").

%% A gigabyte of heap in words, past which a build counts as running away.
-define(HEAP_WORDS, (1024 * 1024 * 1024) div erlang:system_info(wordsize)).

%% Runs every garbling and halts with status 0 if every one was answered,
%% and 1 otherwise, after printing a line for each source and each failure.
%% A garbled source that failed is kept under build/garbled/failed/.
-spec main() -> no_return().
main() ->
    Tree = tree(),
    Failed = lists:append([source(S, Tree) || S <- sources()])
        ++ lists:append([session(Name, Inputs) || {Name, Inputs} <- sessions()]),
    [io:format("~s~n", [F]) || F <- Failed],
    io:format("make garbled: ~B failures~n", [length(Failed)]),
    halt(case Failed of [] -> 0; _ -> 1 end).

%%
%% The sources
%%

%% A copy of the sources beside a link to the toolchain, so that a module
%% of the standard library is built where `ern build` takes its namespace:
%% the standard library's source root is `stdlib/` beside the `erl/` its
%% modules were loaded from (report §4.2), and it is built into
%% `build/stdlib/` there, which holds a copy of the library's compiled
%% modules, since a module of it finds the others there. The toolchain is
%% loaded from the link before any of it runs.
tree() ->
    Tree = filename:absname(filename:join(?SCRATCH, "tree")),
    os:cmd("rm -rf " ++ ?SCRATCH),
    ok = filelib:ensure_path(filename:join(Tree, "build/stdlib")),
    ok = filelib:ensure_path(filename:join(?SCRATCH, "failed")),
    ok = file:make_symlink(filename:absname(filename:join(?REPO, "erl")),
                           filename:join(Tree, "erl")),
    [copy(F, Tree) || {F, _} <- sources()],
    [copy(F, Tree) || F <- filelib:wildcard("build/stdlib/*.erc", ?REPO)],
    ok = code:add_pathsa(filelib:wildcard(filename:join(Tree, "erl/*/ebin"))),
    %% loaded from anywhere else, the standard library's modules would be
    %% refused their namespace, and garbling them would check nothing
    {module, ern_cli} = code:ensure_loaded(ern_cli),
    true = lists:prefix(Tree, code:which(ern_cli)),
    Tree.

copy(Rel, Tree) ->
    To = filename:join(Tree, Rel),
    ok = filelib:ensure_dir(To),
    {ok, _} = file:copy(filename:join(?REPO, Rel), To).

%% Each source with the `ern build` that builds it in the tree: a module of
%% the standard library from its source root, an example as the tests of
%% the programs build it, and the example of two modules as the directory
%% it is.
sources() ->
    Stdlib = [{F, {"stdlib", F}} || F <- wildcard("stdlib/*.ern")],
    Tree = [{F, {dir, "examples/modules"}} || F <- wildcard("examples/modules/**/*.ern")],
    Single = [{F, {"examples", F}} || F <- wildcard("examples/*.ern")],
    Stdlib ++ Single ++ Tree.

%% An editor's lock or auto-save file, `.#x.ern` or `#x.ern#`, is no source.
wildcard(Pattern) ->
    [F || F <- filelib:wildcard(Pattern, ?REPO), not lists:member(hd(filename:basename(F)), ".#")].

build_args({dir, Dir}, Tree) ->
    ["--build-root", filename:join([Tree, "out", Dir]), filename:join(Tree, Dir)];
build_args({"stdlib", File}, Tree) ->
    ["--source-root", filename:join(Tree, "stdlib"), "--build-root",
     filename:join(Tree, "build/stdlib"), filename:join(Tree, File)];
build_args({Root, File}, Tree) ->
    ["--source-root", filename:join(Tree, Root), "--build-root", filename:join([Tree, "out", Root]),
     filename:join(Tree, File)].

%% Every garbling of one source, each built, and the source and what it
%% compiles to put back.
source({Rel, How}, Tree) ->
    {ok, Bin} = file:read_file(filename:join(?REPO, Rel)),
    Text = unicode:characters_to_list(Bin),
    Path = filename:join(Tree, Rel),
    {ok, Null} = file:open("/dev/null", [write]),
    Args = ["build", "--short-errors" | build_args(How, Tree)],
    %% a source that does not build as it is would have its garblings
    %% refused for that, which would check nothing
    Unchanged = build(Path, Text, Args, Null),
    {Built, Refused, Failed} =
        lists:foldl(fun(G, {B, R, F}) ->
                        Variant = garbled(Text, G),
                        case build(Path, Variant, Args, Null) of
                            0 -> {B + 1, R, F};
                            1 -> {B, R + 1, F};
                            Why -> {B, R, [failed(Rel, G, Why, Variant) | F]}
                        end
                    end, {0, 0, []}, garblings(Text)),
    ok = file:write_file(Path, Bin),
    [copy(Erc, Tree) || {"stdlib", _} <- [How],
                        Erc <- ["build/stdlib/" ++ filename:basename(Rel, ".ern") ++ ".erc"]],
    ok = file:close(Null),
    io:format("~s: ~B garbled, ~B built, ~B refused~n",
              [Rel, Built + Refused + length(Failed), Built, Refused]),
    [io_lib:format("~s: does not build as it is: ~P", [Rel, Unchanged, 30]) || Unchanged =/= 0]
        ++ lists:reverse(Failed).

%% A garbled source written where its original was, and built in a process
%% of its own, so that one that never ends, or whose heap passes a
%% gigabyte, can be ended.
build(Path, Variant, Args, Null) ->
    ok = file:write_file(Path, unicode:characters_to_binary(Variant)),
    {Pid, Ref} = spawn_opt(fun() ->
                               exit(try ern_cli:ern(Args, Null)
                                    catch Class:Reason:Stack -> {Class, Reason, Stack}
                                    end)
                           end,
                           [monitor, {max_heap_size, #{size => ?HEAP_WORDS, kill => true,
                                                       error_logger => false}}]),
    receive
        {'DOWN', Ref, process, Pid, killed} -> heap_passed_a_gigabyte;
        {'DOWN', Ref, process, Pid, Answer} -> Answer
    after ?BUILD_MS ->
        exit(Pid, kill),
        no_answer
    end.

failed(Rel, {Kind, {Line, Col}, _}, Why, Variant) ->
    Name = io_lib:format("~s.~s.~B.~B.ern", [string:replace(Rel, "/", "@", all), Kind, Line, Col]),
    Kept = filename:join([?SCRATCH, "failed", lists:flatten(Name)]),
    ok = file:write_file(Kept, unicode:characters_to_binary(Variant)),
    io_lib:format("~s:~B:~B: the token ~s: ~P~n  kept in ~s",
                  [Rel, Line, Col, Kind, Why, 30, Kept]).

%%
%% Garbling
%%

%% Every garbling of a text, as how it garbles the text, where the token
%% begins, and the span or spans it cuts: each token deleted, doubled, and
%% swapped with the next. The end of the input is a token of no text, and
%% is not garbled, since that would change nothing or add a space. A
%% garbled text is made from one as it is needed, since the texts of all a
%% module's garblings would fill the memory.
garblings(Text) ->
    {ok, Tokens} = ern_lexer:tokenize(Text),
    Starts = list_to_tuple(line_starts(Text)),
    Spans = [{span(element(2, T), Starts), where(element(2, T))} || T <- Tokens,
                                                                   element(1, T) =/= eof],
    [{deleted, W, Span} || {Span, W} <- Spans]
        ++ [{doubled, W, Span} || {Span, W} <- Spans]
        ++ [{swapped, W, {Span, Next}}
            || {{Span, W}, {Next, _}} <- lists:zip(lists:droplast(Spans), tl(Spans))].

%% The text a garbling makes. A token is cut from the text by its span, so
%% that what lies between tokens stays.
garbled(Text, {deleted, _, {S, E}}) ->
    cut(Text, S, E, "");
garbled(Text, {doubled, _, {S, E}}) ->
    cut(Text, E, E, " " ++ slice(Text, S, E));
garbled(Text, {swapped, _, {{S1, E1}, {S2, E2}}}) ->
    lists:sublist(Text, S1) ++ slice(Text, S2, E2) ++ slice(Text, E1, S2) ++ slice(Text, S1, E1)
        ++ lists:nthtail(E2, Text).

where({L, C, _, _}) -> {L, C}.

%% A token's span as offsets into the text, from its line and column and
%% those of its end.
span({L, C, {EL, EC}, _}, Starts) ->
    {element(L, Starts) + C - 1, element(EL, Starts) + EC - 1}.

line_starts(Text) ->
    line_starts(Text, 0, [0]).

line_starts([], _, Acc) -> lists:reverse(Acc);
line_starts([$\n | Rest], At, Acc) -> line_starts(Rest, At + 1, [At + 1 | Acc]);
line_starts([_ | Rest], At, Acc) -> line_starts(Rest, At + 1, Acc).

slice(Text, S, E) ->
    lists:sublist(Text, S + 1, E - S).

%% The text with its part from S to E replaced by New.
cut(Text, S, E, New) ->
    lists:sublist(Text, S) ++ New ++ lists:nthtail(E, Text).

%%
%% The shell
%%

%% The sessions of the documents and of test/session/, each its name and
%% its inputs.
sessions() ->
    Documents = ["../ernest_guide.md", "../ernest_report.md", "diagnostics.md"],
    [{io_lib:format("~s:~B", [D, N]), [binary_to_list(I) || I <- Inputs]}
     || D <- Documents, {session, #{line := N, inputs := Inputs}} <- ern_guide_tests:units(D)]
        ++ [{F, string:split(string:trim(read(F), trailing), "\n", all)}
            || F <- filelib:wildcard("session/*.in")].

read(File) ->
    {ok, Bin} = file:read_file(File),
    unicode:characters_to_list(Bin).

%% One session with each input's garblings before the input itself, and
%% before the last input a marker, whose answer shows that no garbling
%% ended the session, since a session may end in `:quit`. Where the session
%% gives no answer, each input's garblings are tried after the inputs
%% before it, and where those give none, each garbling alone after them,
%% so that the garbling that gives none is the one named.
session(Name, Inputs) ->
    Garbled = [[garbled(I, G) || G <- garblings(I)] || I <- Inputs],
    Whole = lists:append([G ++ [I] || {G, I} <- lists:zip(Garbled, Inputs)]),
    io:format("~s: ~B garbled inputs~n", [Name, length(Whole) - length(Inputs)]),
    case shell(lists:droplast(Whole) ++ [?MARKER, lists:last(Whole)]) of
        ok -> [];
        no_answer -> narrowed(Name, Inputs, Garbled);
        {failed, Why} -> [io_lib:format("~s: the shell failed: ~ts", [Name, Why])]
    end.

narrowed(Name, Inputs, Garbled) ->
    lists:append(
      [case shell(Before ++ G) of
           ok -> [];
           {failed, Why} -> [io_lib:format("~s: the shell failed: ~ts", [Name, Why])];
           no_answer -> [io_lib:format("~s: no answer to ~ts", [Name, V])
                         || V <- G, shell(Before ++ [V]) =:= no_answer]
       end
       || {K, G} <- lists:zip(lists:seq(1, length(Inputs)), Garbled),
          Before <- [lists:sublist(Inputs, K - 1)]]).

%% A shell given the inputs as its standard input, in a directory of its
%% own that is also its home: `ok` where it ends with status 0, writes
%% nothing to standard error, and answers the marker where it was given.
shell(Inputs) ->
    Dir = filename:absname(filename:join(?SCRATCH, "shell")),
    os:cmd("rm -rf " ++ Dir),
    ok = filelib:ensure_path(Dir),
    In = filename:join(Dir, "in"),
    Err = filename:join(Dir, "err"),
    ok = file:write_file(In, unicode:characters_to_binary([[I, "\n"] || I <- Inputs])),
    Ern = filename:absname(filename:join(?REPO, "bin/ern")),
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", "exec " ++ Ern ++ " shell < in > out 2> err"]},
                      {cd, Dir}, {env, [{"HOME", Dir}]}, exit_status]),
    receive
        {Port, {exit_status, 0}} ->
            Answered = not lists:member(?MARKER, Inputs)
                orelse string:find(read(filename:join(Dir, "out")), ?MARKER) =/= nomatch,
            case {read(Err), Answered} of
                {"", true} -> ok;
                {"", false} -> {failed, "the session ended before its last input"};
                {Text, _} -> {failed, Text}
            end;
        {Port, {exit_status, Status}} ->
            {failed, io_lib:format("status ~B: ~ts", [Status, read(Err)])}
    after ?SESSION_MS ->
        {os_pid, Pid} = erlang:port_info(Port, os_pid),
        os:cmd("kill -KILL " ++ integer_to_list(Pid)),
        receive {Port, {exit_status, _}} -> ok end,
        no_answer
    end.
