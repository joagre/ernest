#!/usr/bin/env escript
%% -*- erlang -*-
%% make fresh (docs/review.md R4): the commands of the README and of
%% docs/development.md, run in a fresh clone of the checkout's last commit,
%% build/fresh/ernest, in the order the documents give them: the README's
%% *Installing*, then development.md's *Using*, then its *Building*. The
%% commands are read from the documents, so that the two cannot differ. A
%% command passes where it ends with status 0 and leaves every tracked
%% file of the clone as it was; one that changed a file is reported, and
%% the file put back, so that the next command begins on the commit. Each
%% command's output is kept in build/fresh/logs/, where the review reads it
%% against what the documents say it does.
%%
%% Where a command cannot be run here as it is written, the change is the
%% documents' own or the command is not run, each with its reason below:
%% an installation goes under a prefix in build/fresh, as the README's
%% `PREFIX` says, not into /usr/local; a shell is given `:quit`, as the
%% README says to leave it; a manual page is written out, not paged; and
%% the program tree of development.md's `app`, which is the reader's, is
%% not there to build. Two commands of *Building* are not run in the
%% clone: `make fresh`, which is this, and `make stress`, R2's four runs of
%% `make test`, which the clone runs once. The clone runs on this machine,
%% with what it has installed, and not on one with only what the documents
%% say is needed.

main([]) ->
    Repo = filename:absname("."),
    Dir = filename:join(Repo, "build/fresh"),
    Clone = filename:join(Dir, "ernest"),
    Prefix = filename:join(Dir, "prefix"),
    os:cmd("rm -rf " ++ Dir),
    ok = filelib:ensure_path(filename:join(Dir, "logs")),
    ok = filelib:ensure_path(filename:join(Dir, "home")),
    [] = os:cmd("git clone --quiet " ++ Repo ++ " " ++ Clone),
    Commands = readme(Prefix) ++ using() ++ building(Prefix),
    Env = [{"PATH", filename:join(Prefix, "bin") ++ ":" ++ os:getenv("PATH")},
           {"MANPAGER", "cat"}, {"HOME", filename:join(Dir, "home")}],
    Results = [run(N, C, Clone, Dir, Env)
               || {N, C} <- lists:zip(lists:seq(1, length(Commands)), Commands)],
    Failed = [R || {failed, _} = R <- Results],
    io:format("make fresh: ~B commands, ~B failed, ~B not run~n",
              [length(Results), length(Failed), length([R || {not_run, _} = R <- Results])]),
    halt(case Failed of [] -> 0; _ -> 1 end).

%% The README's installation, the lines of the block under *Installing*.
readme(Prefix) ->
    [{"README.md", command(Line, Prefix)} || Line <- block("README.md", "## Installing")].

%% development.md's *Using*: every `bin/ern` line of its blocks.
using() ->
    [{"docs/development.md", command(Line, none)}
     || Line <- lists:append(blocks("docs/development.md", "## Using")),
        lists:prefix("bin/ern", Line)].

%% development.md's *Building*: each line of its block that begins a
%% command, the command being the text before its description.
building(Prefix) ->
    [{"docs/development.md", command(hd(string:split(Line, "  ")), Prefix)}
     || Line <- block("docs/development.md", "## Building"), lists:prefix("make", Line)].

%% What runs for a command as the document writes it, the comment after
%% its `#` left out: {run, Command, Input} or {not_run, Command, Why}.
command(Line, Prefix) ->
    Written = string:trim(hd(string:split(Line, "#"))),
    case Written of
        "sudo make install" ->
            {run, Written, "make install PREFIX=" ++ Prefix, ""};
        "make install" ->
            {run, Written, "make install PREFIX=" ++ Prefix, ""};
        "make uninstall" ->
            {run, Written, "make uninstall PREFIX=" ++ Prefix, ""};
        "make fresh" ->
            {not_run, Written, "this command itself"};
        "make stress" ->
            {not_run, Written, "R2's four runs of make test, of which the clone runs one"};
        "make unicode UC_SPEC=dir" ->
            Spec = filename:join(code:lib_dir(stdlib), "uc_spec"),
            case filelib:is_dir(Spec) of
                true -> {run, Written, "make unicode UC_SPEC=" ++ Spec, ""};
                false -> {not_run, Written, "the host has no lib/stdlib/uc_spec, which OTP's "
                                            "source tree has"}
            end;
        _ ->
            case string:find(Written, "build/app") of
                nomatch ->
                    Input = case string:find(Written, " shell") of
                                nomatch -> "";
                                _ -> ":quit\n"
                            end,
                    {run, Written, Written, Input};
                _ ->
                    {not_run, Written, "names a program tree of the reader's own"}
            end
    end.

%% One command run in the clone with its input, its output kept.
run(_N, {Doc, {not_run, Written, Why}}, _Clone, _Dir, _Env) ->
    io:format("  not run  ~s: ~s: ~s~n", [Doc, Written, Why]),
    {not_run, Written};
run(N, {Doc, {run, Written, Command, Input}}, Clone, Dir, Env) ->
    Log = filename:join([Dir, "logs", integer_to_list(N) ++ ".log"]),
    In = filename:join(Dir, "input"),
    ok = file:write_file(In, Input),
    Started = erlang:monotonic_time(second),
    Port = open_port({spawn_executable, "/bin/sh"},
                     [{args, ["-c", Command ++ " < " ++ In ++ " > " ++ Log ++ " 2>&1"]},
                      {cd, Clone}, {env, Env}, exit_status]),
    Status = receive {Port, {exit_status, S}} -> S end,
    Seconds = erlang:monotonic_time(second) - Started,
    Changed = os:cmd("git -C " ++ Clone ++ " status --porcelain --untracked-files=no"),
    [] =:= Changed orelse os:cmd("git -C " ++ Clone ++ " checkout --quiet -- ."),
    Verdict = case {Status, Changed} of
                  {0, []} -> ok;
                  {0, _} -> {failed, "changed " ++ string:trim(Changed)};
                  _ -> {failed, "status " ++ integer_to_list(Status)}
              end,
    Shown = case Command of
                Written -> Written;
                _ -> Written ++ ", run as " ++ Command
            end,
    case Verdict of
        ok -> io:format("  ~5Bs    ~s: ~s~n", [Seconds, Doc, Shown]);
        {failed, Why} -> io:format("  FAILED   ~s: ~s: ~s; ~s~n", [Doc, Shown, Why, Log])
    end,
    case Verdict of
        ok -> {ok, Written};
        _ -> {failed, Written}
    end.

%% The lines of the first fenced block after a heading.
block(File, Heading) ->
    hd(blocks(File, Heading)).

%% The lines of every fenced block between a heading and the next of its
%% level.
blocks(File, Heading) ->
    {ok, Bin} = file:read_file(File),
    [_, After] = string:split(unicode:characters_to_list(Bin), Heading ++ "\n"),
    [Section | _] = string:split(After, "\n## "),
    fenced(string:split(Section, "\n", all), none, []).

fenced([], _, Acc) ->
    lists:reverse(Acc);
fenced(["```" ++ _ | Rest], none, Acc) ->
    fenced(Rest, [], Acc);
fenced(["```" ++ _ | Rest], Lines, Acc) ->
    fenced(Rest, none, [lists:reverse(Lines) | Acc]);
fenced([_ | Rest], none, Acc) ->
    fenced(Rest, none, Acc);
fenced([Line | Rest], Lines, Acc) ->
    fenced(Rest, [Line | Lines], Acc).
