%% The toolchain of report §11: one command, ern, whose first word is its
%% job, build and doc (§11.1, §11.4), format (§11.6), run, test and shell
%% (§11.2), config (§11.3), and reload and stop (§11.2, §8.7). The launcher
%% bin/ern is thin; everything is here so that the tests can call it.
%% `ern/1,2` returns the exit status, which the launcher's entry point ends
%% the host with.
-module(ern_cli).

-export([start/0, node_flags/0, ern/1, ern/2, stamp/1, is_stamped/0, load_path/0, say_limits/0]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_build.hrl").
-include("ern_node.hrl").

%%
%% Entry
%%

%% A word of the command line as the host gives it: decoded, or, where the
%% host's names are UTF-8 and the word is not, what decoding it left.
-type word() :: string() | {error | incomplete, string(), binary()}.

%% Report §11: the launcher's entry, the command line being what follows
%% the host's -extra. The host's signals are ern's before any of its work
%% (ern_signals). A running program writes to the process's own standard
%% output and standard error (reporting_options/2). A failure of the
%% toolchain itself is a defect, which is reported on standard error with
%% the host's stack and ends `ern` with status 70, and is never left as a
%% crash dump in the working directory. `ern` ends by the signal that ended
%% a running program once its output has flushed (§11.2), where the
%% program's outcome says the signal ended it (report_outcome/2), and
%% otherwise with the status.
-spec start() -> no_return().
start() ->
    ok = ern_signals:install(),
    %% report §11: the host's code path holds the working directory, so a
    %% `.beam` there would answer a module no other directory holds; no job
    %% reads one
    _ = code:del_path("."),
    Args = init:get_plain_arguments(),
    %% a job writes through ports of its own, which end it when a stream's
    %% reader has gone (ern_out); the shell's terminal is the host's own
    IsShell = case Args of
                  ["shell" | Rest] -> Rest =:= [] orelse hd(Rest) =/= "--help";
                  _ -> false
              end,
    ErrorDevice = case IsShell andalso ern_tty:is_terminal(stdout) of
                      true -> standard_error;
                      false -> ern_out:take()
                  end,
    Status = try
                 persistent_term:put({?MODULE, streams}, fds),
                 ern(Args, ErrorDevice)
             catch
                 Class:Error:Trace ->
                     %% the host's text of the exception, which may end in a
                     %% line break or not, ends the line
                     Text = erl_error:format_exception(Class, Error, Trace),
                     io:format(ErrorDevice, "ern: internal error: ~ts~n",
                               [string:trim(Text, trailing)]),
                     70
             end,
    case ern_signals:ended() of
        none -> ok;
        Signal -> ern_signals:die(Signal, Status)
    end,
    ok = ern_out:finish(ErrorDevice),
    halt(Status).

%% Report §8.7: the launcher's first start of the host, where its arguments
%% hold `--config-dir`, since the host takes a node's carrier only as it
%% boots. The command line is parsed as its job parses it, and the flags a
%% node's host boots with are written to standard output as shell words on
%% one line, after the marker `ern-node-flags`; none are written where the
%% command starts no node or is refused, which the launcher's second start
%% then says. Nothing the job would write reaches standard output, which
%% carries the flags alone.
-spec node_flags() -> no_return().
node_flags() ->
    Out = group_leader(),
    %% the job's text is written to it in UTF-8, as its devices write it. A
    %% regression: one of the host's default, Latin-1, raised at a
    %% `--verbose` line naming a path beyond it, and the node was given no
    %% flags (report §11.2)
    {ok, Null} = file:open("/dev/null", [write, {encoding, utf8}]),
    group_leader(Null, self()),
    persistent_term:put({?MODULE, flags}, true),
    Args = init:get_plain_arguments(),
    %% only the jobs that make a node are parsed: every other job's work,
    %% `ern config`'s among it, is the second start's
    Flags = case lists:member(hd(Args ++ [""]), ["run", "test", "shell"]) of
                false -> [];
                true ->
                    try ern(Args, Null) of
                        _ -> []
                    catch
                        throw:{node_flags, Found} -> Found;
                        _:_ -> []
                    end
            end,
    io:put_chars(Out, ["ern-node-flags " | lists:join(" ", [shell_quoted(Flag) || Flag <- Flags])]),
    halt(0).

%% A word as the shell reads it back, in single quotes.
shell_quoted(Word) ->
    ["'", string:replace(Word, "'", "'\\''", all), "'"].

-spec ern([word()]) -> 0..255.
ern(Args) ->
    ern(Args, standard_error).

%% Report §11: the first word is the job, and --help and --version stand
%% alone; a working directory whose name is not UTF-8 the launcher refused
%% before the host started. ErrorDevice is the error device,
%% standard_error for the launcher; a test passes its own and reads what
%% the user would see. The status is 0 or 1, or a program's, which Os.exit
%% or a signal may give (§11.2).
-spec ern([word()], io:device()) -> 0..255.
ern(["--help"], _ErrorDevice) ->
    usage(standard_io),
    0;
ern(["--version"], _ErrorDevice) ->
    io:format("ern ~s~n", [ern_release:version_text()]),
    0;
%% report §11: an empty first word names no job, as none does
ern([[] | _], ErrorDevice) ->
    refuse("a job is required", ErrorDevice);
ern([Word | Args], ErrorDevice) ->
    case {is_utf8(Word), lists:keyfind(Word, 1, jobs())} of
        {false, _} -> refuse(not_utf8(Word), ErrorDevice);
        {true, {Word, Spec, Positional, Work}} ->
            job(Word, Spec, Positional, Args, Work, ErrorDevice);
        {true, false} -> refuse(no_job(Word), ErrorDevice)
    end;
ern([], ErrorDevice) ->
    refuse("a job is required", ErrorDevice).

%% The jobs of §11, each with its options, what follows them, and its
%% function.
jobs() ->
    [{"build", build_options(), "file.ern | src-dir", fun build/3},
     {"doc", doc_options(), "file.ern | file.erc | src-dir", fun doc/3},
     {"format", format_options(), "path...", fun format/3},
     {"run", run_options(), "[file.erc [argument]...]", fun run/3},
     {"test", test_options(), "file.erc | dir", fun test/3},
     {"shell", shell_options(), "[file.erc]", fun shell/3},
     {"config", config_options(), "", fun config/3},
     {"reload", signal_options("the node that reads its configuration again"), "",
      fun reload/3},
     {"stop", signal_options("the node that ends"), "", fun stop/3}].

%% Report §11: a first word that is no job; an option a job takes, given
%% before it, is refused with where it goes.
no_job("--help") -> "--help stands alone: ern --help, or ern <job> --help";
no_job("--version") -> "--version stands alone: ern --version";
no_job("-" ++ _ = Word) ->
    Name = option_name(Word),
    Taken = [Job || {Job, Spec, _, _} <- jobs(), {_, _, Long, _, _} <- Spec, "--" ++ Long =:= Name],
    case Taken of
        [] -> no_such_job(Word);
        _ -> Name ++ " comes after the job: ern <job> " ++ Name
    end;
no_job(Word) ->
    case filename:extension(Word) of
        ".erc" -> "the job comes first: ern run " ++ Word;
        _ -> no_such_job(Word)
    end.

no_such_job(Word) ->
    "no job " ++ Word ++ "; the jobs are build, doc, format, run, test, shell, config, reload"
        " and stop".

%% An option's whole name, before any `=`.
option_name(Word) ->
    lists:takewhile(fun(Char) -> Char =/= $= end, Word).

refuse(Message, ErrorDevice) ->
    io:format(ErrorDevice, "ern: ~ts~n", [Message]),
    usage(ErrorDevice),
    1.

usage(Device) ->
    io:format(Device, "Usage: ern <job> [options] ...~n~n"
              "  build   compile a module, or every module under a directory~n"
              "  doc     write the documentation of a module or a directory~n"
              "  format  lay out modules in the language's one layout~n"
              "  run     run a program~n"
              "  test    run the tests of a module, or of every module under a directory~n"
              "  shell   run an interactive shell~n"
              "  config  create the configuration directory~n"
              "  reload  have a running node read its configuration again~n"
              "  stop    end a running node~n~n"
              "ern <job> --help lists a job's options; ern --version prints the version.~n",
              []).

%% Run a job with its options parsed by getopt. --help prints and stops
%% with status 0; a usage error prints the message and the job's usage on
%% ErrorDevice, any other error one line, both with status 1.
job(Job, Spec, Positional, Args, Work, ErrorDevice) ->
    Name = "ern " ++ Job,
    {Own, Program} = case Job of
                         "run" -> program_words(Spec, Args, []);
                         _ -> {Args, []}
                     end,
    try
        lists:foreach(fun(Word) -> is_utf8(Word) orelse ern_build:fail(not_utf8(Word)) end, Own),
        lists:foreach(fun(Word) -> one_spelling(Word, Spec) end, Own),
        {Options, Rest} = case getopt:parse(Spec, Own) of
                              {ok, Parsed} -> Parsed;
                              {error, Error} ->
                                  usage_fail(getopt:format_error(Spec, Error))
                          end,
        given_once(Options, Spec),
        named_directories(Job, Options),
        case lists:member(help, Options) of
            true -> job_usage(Spec, Name, Positional, standard_io), 0;
            false -> Work(Options, Rest ++ Program, ErrorDevice)
        end
    catch
        throw:{cli_usage, Usage} ->
            io:format(ErrorDevice, "~s: ~ts~n", [Name, Usage]),
            job_usage(Spec, Name, Positional, ErrorDevice),
            1;
        throw:{cli_error, Refusal} ->
            io:format(ErrorDevice, "~s: ~ts~n", [Name, Refusal]),
            1
    end.

%% Report §11.7: an option that names a directory to read names one that is
%% there; `ern config`'s `--config-dir` names the one it creates.
named_directories(Job, Options) ->
    lists:foreach(fun({Key, Directory}) when Key =:= load_path; Key =:= libs_dir;
                                            Key =:= source_root;
                                            Key =:= config_dir andalso Job =/= "config" ->
                          filelib:is_dir(Directory)
                              orelse ern_build:fail(Directory ++ ": no such directory, which --"
                                                    ++ option_long(Key) ++ " names");
                     (_) ->
                          ok
                  end, Options).

option_long(load_path) -> "load-path";
option_long(libs_dir) -> "libs-dir";
option_long(source_root) -> "source-root";
option_long(config_dir) -> "config-dir".

%% Report §11: an option's value is the next word, so `--name=value` is a
%% second spelling, refused with the first; a flag takes none. A name the
%% job does not take is getopt's to refuse.
one_spelling("--" ++ _ = Word, Spec) ->
    Name = option_name(Word),
    Known = lists:any(fun({_, _, Long, _, _}) -> "--" ++ Long =:= Name end, Spec),
    case {Name =:= Word, Known, takes_value(Spec, Name)} of
        {true, _, _} -> ok;
        {false, false, _} -> ok;
        {false, true, true} ->
            usage_fail(Word ++ ": an option's value is the next word, " ++ Name ++ " value");
        {false, true, false} ->
            usage_fail(Word ++ ": " ++ Name ++ " takes no value")
    end;
one_spelling(_, _) ->
    ok.

%% Report §11: only a `-path` option is given more than once, and no option
%% takes an empty value. A regression: a repeat took the first value, and
%% an empty directory was accepted.
given_once(Options, Spec) ->
    Keys = [Option || {Option, _} <- Options] ++ [Option || Option <- Options, is_atom(Option)],
    Name = fun(Option) -> hd(["--" ++ Long || {Key, _, Long, _, _} <- Spec, Key =:= Option]) end,
    case [Option || Option <- lists:usort(Keys), Option =/= load_path,
                    length([Other || Other <- Keys, Other =:= Option]) > 1] of
        [] -> ok;
        [Option | _] -> usage_fail(Name(Option) ++ " is given more than once")
    end,
    case [Option || {Option, ""} <- Options] of
        [] -> ok;
        [Empty | _] -> usage_fail(Name(Empty) ++ " is given an empty value")
    end.

%% Report §11: a word of the command line that is not UTF-8 is refused,
%% each byte past ASCII written as §11.1 writes a name's.
is_utf8(Word) ->
    is_binary(unicode:characters_to_binary(word_bytes(Word), utf8, utf8)).

not_utf8(Word) ->
    "a word that is not UTF-8: " ++ ern_build:bytes_text(word_bytes(Word)).

%% A word's bytes. Where the host's names are UTF-8 it gives a word
%% decoded, and one that is not as the part it decoded and the bytes from
%% the first it could not; where they are not, it gives a word's bytes.
word_bytes({_, Decoded, Bytes}) ->
    <<(unicode:characters_to_binary(Decoded))/binary, Bytes/binary>>;
word_bytes(Word) ->
    case file:native_name_encoding() of
        utf8 -> unicode:characters_to_binary(Word);
        latin1 -> list_to_binary(Word)
    end.

%% Report §11.2: the words after `ern run`'s file are the program's,
%% whatever they look like, so they are split off before the options are
%% read: the job's own words, the file last, and the program's. An option
%% that takes a value takes the next word; one written with `=` takes none,
%% and is refused as a second spelling. Report §11: `--` ends the options,
%% so the word after it is the file, whatever it looks like.
program_words(_Spec, ["--", File | Rest], Own) ->
    {lists:reverse([File, "--" | Own]), Rest};
program_words(Spec, ["-" ++ _ = Option | Rest], Own) when Option =/= "-" ->
    case {Rest, takes_value(Spec, Option)} of
        {[Value | Rest1], true} -> program_words(Spec, Rest1, [Value, Option | Own]);
        _ -> program_words(Spec, Rest, [Option | Own])
    end;
program_words(_Spec, [File | Rest], Own) ->
    {lists:reverse([File | Own]), Rest};
program_words(_Spec, [], Own) ->
    {lists:reverse(Own), []}.

takes_value(Spec, "--" ++ Long) ->
    lists:any(fun({_, _, Spelled, Type, _}) ->
                  Spelled =:= Long andalso Type =/= undefined
              end, Spec);
takes_value(_Spec, _Short) ->
    false.

%% Report §11: a job's synopsis as §11 writes it, then getopt's list of
%% its options, on any device.
job_usage(Spec, Name, Positional, Device) ->
    %% getopt leaves a space at the end of a description's line it wraps
    Lines = [string:trim(Line, trailing, " ")
             || Line <- string:split(getopt:usage_options(Spec), "\n", all)],
    io:format(Device, "~ts~n~n~ts~n", [synopsis(Name, Spec, Positional), lists:join("\n", Lines)]).

%% Report §11: `Usage: ern build [--source-root src-root] ...`, each option
%% with the metavariable §11 gives it and --load-path's repetition, wrapped
%% at 80 columns under the job's name.
synopsis(Name, Spec, Positional) ->
    Words = [case lists:member(Name, required_by(Key)) of
                 true -> "--" ++ Long ++ " " ++ metavariable(Key);
                 false -> option_synopsis(Option)
             end || {Key, _, Long, _, _} = Option <- Spec, Key =/= help]
        ++ [Positional || Positional =/= ""],
    Head = "Usage: " ++ Name,
    Indent = lists:duplicate(length(Head) + 1, $\s),
    Wrap = fun(Word, {Done, Line}) when length(Line) + 1 + length(Word) > 80 ->
                   {Done ++ [Line], Indent ++ Word};
              (Word, {Done, Line}) ->
                   {Done, Line ++ " " ++ Word}
           end,
    {Lines, Last} = lists:foldl(Wrap, {[], Head}, Words),
    lists:join("\n", Lines ++ [Last]).

option_synopsis({_, _, Long, undefined, _}) ->
    "[--" ++ Long ++ "]";
option_synopsis({Key, _, Long, _, _}) ->
    "[--" ++ Long ++ " " ++ metavariable(Key) ++ "]" ++ repetition(Key).

metavariable(source_root) -> "src-root";
metavariable(build_root) -> "build-root";
metavariable(load_path) -> "dir";
metavariable(libs_dir) -> "dir";
metavariable(config_dir) -> "dir";
metavariable(main) -> "Qualified.name".

%% An option that may be given more than once, which §11 marks `...`.
repetition(load_path) -> "...";
repetition(_) -> "".

help_option() ->
    {help, undefined, "help", undefined, "print this text"}.

%%
%% ern build and ern doc, report §11.1 and §11.4
%%

build_options() ->
    [{source_root, undefined, "source-root", string,
      "the directory whose layout yields namespaces; default: the working"
      " directory, or src-dir"},
     {build_root, undefined, "build-root", string,
      "where the compiled tree goes; default: the source root"},
     {load_path, undefined, "load-path", string,
      "a root of compiled modules a module may use; may be repeated"},
     {emit_erl, undefined, "emit-erl", undefined,
      "write the module's Erlang source instead of .erc"},
     {short_errors, undefined, "short-errors", undefined,
      "the first line of each error only"},
     verbose_option(),
     help_option()].

%% Report §11.4, §11.7: `ern doc` takes the build's options but
%% `--emit-erl` and `--verbose`, which are the build's alone.
doc_options() ->
    [{man, undefined, "man", undefined, "write manual pages in roff instead of CommonMark"}
     | [Option || {Key, _, _, _, _} = Option <- build_options(),
                  Key =/= emit_erl, Key =/= verbose]].

build(Options, [Path], ErrorDevice) ->
    ern_build:compile("ern build", Options, Path, ErrorDevice);
build(_Options, _Rest, _ErrorDevice) ->
    usage_fail("one file or directory argument is required").

%% Report §11.4: a file's documentation to stdout, a directory's into the
%% build directory, one document per module and an index, or with --man one
%% manual page per module and no index.
doc(Options, [Path], ErrorDevice) ->
    try doc_path(Options, Path, ErrorDevice)
    catch
        throw:{ended, Status} -> Status
    end;
doc(_Options, _Rest, _ErrorDevice) ->
    usage_fail("one file or directory argument is required").

doc_path(Options, Path, ErrorDevice) ->
    case filelib:is_dir(Path) of
        true ->
            doc_dir(Options, Path, ErrorDevice);
        false ->
            filelib:is_regular(Path) orelse ern_build:fail("no such file " ++ Path),
            try
                io:put_chars(page(Options, beam_of(Options, Path), ErrorDevice)),
                0
            catch
                throw:{errors, File, Diagnostics} ->
                    ern_build:report_errors(Options, File, Diagnostics, ErrorDevice)
            end
    end.

%% Report §11.4: the documentation comes from the compiled module. A `.erc`
%% is read; a source is compiled first, in memory, so that asking for a page
%% writes nothing. A file that is neither is refused for both.
beam_of(Options, Path) ->
    lists:member(filename:extension(Path), [".ern", ".erc"])
        orelse ern_build:fail(ern_build:shown(Path) ++ " ends in neither .ern nor .erc"),
    case filename:extension(Path) of
        ".erc" ->
            Compiled = compiled(Path),
            %% both chunks a page is built from, so that a module whose
            %% chunks are not the compiler's is refused and no page begun
            case {ern_docs:read(Compiled), ern_interface:read(Compiled)} of
                {{ok, _}, {ok, _}} -> Compiled;
                {{error, Error}, _} -> ern_build:fail(Path ++ ": " ++ Error);
                {_, {error, Error}} -> ern_build:fail(Path ++ ": " ++ Error)
            end;
        _ ->
            SourceRoot = ern_build:source_root(Options, Path, "."),
            BuildRoot = ern_build:build_root(Options, SourceRoot),
            %% report §11.1: a module outside the source root is found under
            %% build-root, then under each --load-path root
            DependencyRoots = [BuildRoot | ern_build:load_path(Options)],
            Module = ern_build:module_of(ern_build:absolute(Path), SourceRoot, file),
            [#build_module{namespace = Namespace, file = File, relative = Relative,
                           declarations = Declarations, dependencies = Dependencies}] =
                ern_build:compile_order([Module], SourceRoot, DependencyRoots),
            Reached = ern_build:dependency_interfaces(Namespace, Dependencies, #{}, DependencyRoots,
                                                      SourceRoot),
            DependencyInterfaces = [DependencyInterface || {_, DependencyInterface} <- Reached],
            case ern_typecheck:check(Namespace, Declarations, DependencyInterfaces) of
                {ok, Typed, Interface, Env} ->
                    Build = #{source_hash => <<>>, deps => [],
                              source => list_to_binary(filename:basename(Relative))},
                    {ok, _, Beam} = ern_compile:compile(Namespace, Typed, Interface, Env, Build),
                    Beam;
                {error, Diagnostics} ->
                    throw({errors, File, Diagnostics})
            end
    end.

%% Report §11.4: a module's page, in CommonMark or with --man as a manual
%% page.
page(Options, Beam, ErrorDevice) ->
    case lists:member(man, Options) of
        true -> in_runtime(fun() -> ern_page:manual(Beam) end, ErrorDevice);
        false -> ern_page:page(Beam)
    end.

%% Report §11.4, §8.5: a manual page is laid out by libs/markdown, whose code
%% runs as a program's does, in a started runtime, the standard library's
%% top-level bindings and the library's evaluated first, so that a function
%% that reads one finds its value. What Compute gives is passed back to the
%% job, which writes it. A fault there is reported as a run's is, its cause
%% and its trace whole on standard error (§11.2), and is then a failure of
%% ern itself; a signal ends the job as it ends a run (§11.8). Compute is
%% the job's own code, which calls libs/markdown as foreign code calls a
%% program's, and it is counted as a foreign call is (§8.4, §8.6): the
%% prelude's page reads the standard library's interfaces, a wait on the
%% host's code server and file server, which the deadlock detector would
%% otherwise take, under load, for every process waiting.
in_runtime(Compute, ErrorDevice) ->
    Caller = self(),
    Ref = make_ref(),
    Options = reporting_options(#{init => fun() -> ern_rt:init_modules(['ern@markdown']) end},
                                ErrorDevice),
    case ern_rt:run_main(fun() -> Caller ! {Ref, ern_rt:in_foreign(Compute)} end, <<"ern doc">>,
                         Options) of
        ok -> receive {Ref, Result} -> Result end;
        {signal, Signal} -> throw({ended, ern_signals:ended(Signal)});
        Outcome -> erlang:error({libs_markdown, Outcome})
    end.

%% Report §11.4: a directory's documents, or with --man its manual pages,
%% each written where it is not current. A page is made from its module
%% compiled, so that every page is of a module that type-checks: a module
%% whose .erc in build-root is as new as its source is read from it, and
%% the rest are compiled as `ern build` compiles them, writing nothing.
%% Where every page is current, nothing is compiled. A file whose path is
%% no module's fails as a module that does not compile does (§11.1), whose
%% page is never current.
doc_dir(Options, Path, ErrorDevice) ->
    SourceRoot = ern_build:source_root(Options, Path, Path),
    BuildRoot = ern_build:build_root(Options, SourceRoot),
    %% the modules by their files and namespaces, which is all that tells
    %% whether a page is current, so no source is parsed to tell it
    {Unsorted, Misnamed} = ern_build:modules_of(ern_build:sources(Path), SourceRoot, tree),
    Modules = lists:sort(Unsorted),
    IsStdlib = ern_build:is_stdlib_root(SourceRoot),
    Kind = case lists:member(man, Options) of
               true -> man;
               false -> markdown
           end,
    Outdated = outdated(pages(Kind, Modules, IsStdlib, BuildRoot), code_modified(Kind)),
    Outcome = case {Outdated, Misnamed} of
                  {[], []} -> {0, #{}};
                  _ -> ern_build:compile_in_memory("ern doc", Options, Path, ErrorDevice,
                                                   read_compiled(Modules, BuildRoot))
              end,
    case Outcome of
        {0, Compiled} ->
            write_outdated(Kind, Outdated, Compiled, ErrorDevice),
            Kind =:= markdown andalso write_index(Modules, IsStdlib, BuildRoot),
            %% report §11.4: the page of a module whose source is gone goes,
            %% as the build's sweep takes its .erc
            Kept = [Namespace || #build_module{namespace = Namespace} <- Modules]
                ++ [['Prelude'] || IsStdlib],
            ern_build:sweep_pages(Kind, Path, SourceRoot, BuildRoot, Kept),
            0;
        {Status, _} ->
            Status
    end.

%% Report §11.4: each module's page, with what makes it from the compiled
%% modules and the times of what it is made from of its own: in CommonMark
%% where `ern build` writes its .erc with `.md` for `.erc`, or a manual
%% page in that directory in a file named as `man` finds it,
%% `Ernest.Net.Http.3ern`. The standard library's own source root also has
%% the prelude's page, at the top of its build root, first in the index.
pages(markdown, Modules, IsStdlib, BuildRoot) ->
    [{filename:join(BuildRoot, "prelude.md"), fun(_) -> ern_page:prelude_page() end, []}
     || IsStdlib]
        ++ [{filename:join(BuildRoot, ern_build:module_path(Namespace) ++ ".md"),
             fun(Compiled) -> ern_page:page(maps:get(Namespace, Compiled)) end,
             module_modified(Module, BuildRoot)}
            || #build_module{namespace = Namespace} = Module <- Modules];
pages(man, Modules, IsStdlib, BuildRoot) ->
    [{man_page(BuildRoot, Namespace),
      fun(Compiled) -> ern_page:manual(maps:get(Namespace, Compiled)) end,
      module_modified(Module, BuildRoot)}
     || #build_module{namespace = Namespace} = Module <- Modules]
        ++ [{filename:join(BuildRoot, "Ernest.Prelude.3ern"),
             fun(_) -> ern_page:prelude_manual() end, []}
            || IsStdlib].

%% Report §11.4: the times of the code that makes every page: the
%% toolchain's own, and for a manual page libs/markdown's, which lays it
%% out.
code_modified(markdown) -> [toolchain_modified()];
code_modified(man) -> [toolchain_modified() | markdown_modified()].

%% Report §11.4: the modules read from their .erc in build-root, each the
%% module's own, compiled from its source, and as new as it, by namespace.
%% A .erc this toolchain does not read is none: its module is compiled, as
%% `ern build` compiles again a module another build of `ern` compiled
%% (§11.1).
read_compiled(Modules, BuildRoot) ->
    maps:from_list([{Namespace, Beam}
                    || #build_module{namespace = Namespace, file = File} = Module <- Modules,
                       Erc <- [erc_of(Module, BuildRoot)],
                       {ok, Time} <- [modified(File)],
                       is_current(Erc, [Time]),
                       Beam <- [ern_build:read(Erc)],
                       is_compiled_from(Beam, Namespace, File, BuildRoot)]).

is_compiled_from(Beam, Namespace, File, BuildRoot) ->
    case {ern_interface:read(Beam), ern_docs:read(Beam)} of
        {{ok, #{interface := #interface{namespace = Namespace}, source_path := SourcePath}},
         {ok, _}} ->
            Source = filename:join(BuildRoot, unicode:characters_to_list(SourcePath)),
            ern_build:absolute(Source) =:= ern_build:absolute(File);
        _ ->
            false
    end.

%% Report §11.4: each page not current written, laid out from the compiled
%% modules. libs/markdown lays out the manual pages to be written, in a
%% started runtime, and none is started where there is none.
write_outdated(_Kind, [], _Compiled, _ErrorDevice) ->
    ok;
write_outdated(markdown, Outdated, Compiled, _ErrorDevice) ->
    write_pages([{Output, Make(Compiled)} || {Output, Make} <- Outdated]);
write_outdated(man, Outdated, Compiled, ErrorDevice) ->
    LaidOut = fun() -> [{Output, Make(Compiled)} || {Output, Make} <- Outdated] end,
    write_pages(in_runtime(LaidOut, ErrorDevice)).

%% Report §11.4: index.md, listing the modules, the prelude first in the
%% standard library's own build root, written where its text would differ
%% from the one there and left as it is otherwise. A link or anything else
%% at its place is no index, and is replaced, as a page is.
write_index(Modules, IsStdlib, BuildRoot) ->
    Entries = ["- [Prelude](prelude.md)\n" || IsStdlib]
        ++ [["- [", ern_namespace:text(Namespace), "](", ern_build:module_path(Namespace),
             ".md)\n"] || #build_module{namespace = Namespace} <- Modules],
    Text = unicode:characters_to_binary(["# Modules\n\n", Entries]),
    Index = filename:join(BuildRoot, "index.md"),
    case {file:read_link_info(Index), file:read_file(Index)} of
        {{ok, #file_info{type = regular}}, {ok, Text}} -> ok;
        _ -> ern_build:write_output(Index, Text)
    end.

%% A module's manual page, in the directory of its .erc.
man_page(BuildRoot, Namespace) ->
    Directory = filename:dirname(filename:join(BuildRoot, ern_build:module_path(Namespace))),
    filename:join(Directory, "Ernest." ++ ern_namespace:text(Namespace) ++ ".3ern").

%% Each page written to its file whole, as UTF-8.
write_pages(Pages) ->
    lists:foreach(fun({Output, Page}) ->
                      ok = ern_build:make_dirs(Output),
                      ok = ern_build:write_output(Output, unicode:characters_to_binary(Page))
                  end, Pages).

%% Report §11.4: each page of Pages that is not current, with what makes
%% it. A page is current where its file is there and is as new as all it
%% is made from: its module's own files, whose times Pages gives, and the
%% code that makes every page, whose times Code gives. A link or
%% anything else at the file's place is no page, and is replaced, as
%% ern_build:write_output/2 replaces it. The times are compared as make
%% compares them, to the second the host gives.
outdated(Pages, Code) ->
    [{Output, Make} || {Output, Make, Times} <- Pages, not is_current(Output, Code ++ Times)].

is_current(Page, Times) ->
    case file:read_link_info(Page, [{time, posix}]) of
        {ok, #file_info{type = regular, mtime = Written}} ->
            lists:all(fun(Time) -> Time =< Written end, Times);
        _ ->
            false
    end.

%% Report §11.4: the times of what a module's page is made from of its
%% own: its source, and its .erc where `ern build` has written one in
%% BuildRoot.
module_modified(#build_module{file = File} = Module, BuildRoot) ->
    [Time || Input <- [File, erc_of(Module, BuildRoot)], {ok, Time} <- [modified(Input)]].

%% Report §11.1: where `ern build` writes a module's .erc in BuildRoot.
erc_of(#build_module{relative = Relative}, BuildRoot) ->
    filename:join(BuildRoot, filename:rootname(Relative)) ++ ".erc".

%% Report §11.4: the newest time of the toolchain's own code, the .beam
%% files of the applications bin/ern puts on the path, `erl/*/ebin` of the
%% tree it runs from, the checkout or an installation.
toolchain_modified() ->
    Erl = filename:dirname(filename:dirname(filename:dirname(
                                                ern_build:absolute(code:which(?MODULE))))),
    lists:max([Time || Application <- names(Erl),
                       Beam <- application_code(filename:join(Erl, Application)),
                       {ok, Time} <- [modified(Beam)]]).

%% An application's .beam files but its tests': a module whose source is in
%% its test/ is a test's, and no code of the toolchain's, as no
%% installation holds it (tools/install.sh).
application_code(Directory) ->
    Tests = [filename:rootname(Name) || Name <- names(filename:join(Directory, "test")),
                                        filename:extension(Name) =:= ".erl"],
    [filename:join([Directory, "ebin", Name]) || Name <- names(filename:join(Directory, "ebin")),
                                                 filename:extension(Name) =:= ".beam",
                                                 not lists:member(filename:rootname(Name), Tests)].

%% Report §11.4: the time of libs/markdown's compiled code, which lays a
%% manual page out: the file the host holds it from, or else the one the
%% runtime loads it from at its first call (in_runtime/2); none where
%% there is none, and laying a page out then fails in the runtime.
markdown_modified() ->
    Found = case code:is_loaded('ern@markdown') of
                {file, File} -> {ok, File};
                false -> ern_code:own_file('ern@markdown')
            end,
    [Time || {ok, File} <- [Found], {ok, Time} <- [modified(File)]].

%% A file's last modification, in seconds, as the host gives it.
modified(File) ->
    case file:read_file_info(File, [{time, posix}]) of
        {ok, #file_info{mtime = Time}} -> {ok, Time};
        {error, _} -> error
    end.

%% The names in a directory, none where there is none.
names(Directory) ->
    case file:list_dir(Directory) of
        {ok, Names} -> Names;
        {error, _} -> []
    end.

%%
%% ern format, report §11.6
%%

format_options() ->
    [{check, undefined, "check", undefined,
      "name the modules not laid out, and change none"},
     {short_errors, undefined, "short-errors", undefined,
      "the first line of each error only"},
     help_option()].

%% Report §11.6: each module named, and every module under each directory
%% named, laid out in place; with --check, each one not laid out named on
%% standard output and none changed, the status 1 when there was one; with
%% `-`, standard input laid out onto standard output. A module that does
%% not parse is left as it is and its diagnostic written, the status 1.
format(Options, ["-"], ErrorDevice) ->
    Text = read_input(open_input(), []),
    case ern_format:format(Text) of
        {ok, Text} -> format_result(Options, Text, same);
        {ok, Output} -> format_result(Options, Output, changed);
        %% report §11.6: a module that does not parse is written back as
        %% it is, since standard output stands for the file it came from
        {error, Diagnostic} ->
            io:format(ErrorDevice, "~ts~n", [error_text(Options, "-", Text, Diagnostic)]),
            lists:member(check, Options) orelse io:put_chars(Text),
            1
    end;
format(_Options, [], _ErrorDevice) ->
    usage_fail("a file, a directory or - is required");
format(Options, Paths, ErrorDevice) ->
    %% report §11.6: `-` reads standard input, and stands alone
    lists:member("-", Paths) andalso usage_fail("- stands alone, for standard input"),
    lists:foreach(fun(Path) ->
                      filelib:is_file(Path)
                          orelse ern_build:fail(Path ++ ": no such file or directory")
                  end, Paths),
    Files = lists:append([files_named(Path) || Path <- Paths]),
    Results = [format_named(Options, File, Directory, ErrorDevice) || {File, Directory} <- Files],
    case lists:all(fun(Result) -> Result =:= ok end, Results) of
        true -> 0;
        false -> 1
    end.

%% Report §11.6: the files a path names, each with the directory it was
%% found under, or none for a file named alone.
files_named(Path) ->
    case filelib:is_dir(Path) of
        true -> [{File, Path} || File <- ern_build:sources(Path)];
        false -> [{Path, none}]
    end.

%% Report §11.6, §11.1: a file laid out where it is a module, and refused
%% where it is none, which fails that file alone, the rest laid out.
format_named(Options, File, Directory, ErrorDevice) ->
    try shaped(File, Directory) of
        ok -> format_file(Options, File, ErrorDevice)
    catch
        throw:{cli_error, Refusal} ->
            io:format(ErrorDevice, "ern format: ~ts~n", [Refusal]),
            error
    end.

%% Report §11.6: whether a file is a module. One under a directory is found
%% as `ern build` finds them (§11.1), each component of the path under the
%% directory one word; the directory is no source root, so nothing that a
%% namespace decides is checked. A file named alone is a module when its
%% name ends in `.ern` and is otherwise one word. A refusal names the file
%% from the working directory (§11.5).
shaped(File, none) ->
    Shown = ern_build:shown(File),
    filename:extension(File) =:= ".ern" orelse ern_build:fail(Shown ++ " does not end in .ern"),
    ern_build:shape(Shown, filename:basename(File, ".ern"));
shaped(File, Directory) ->
    Relative = ern_build:relative(ern_build:absolute(File), ern_build:absolute(Directory)),
    Components = filename:split(filename:rootname(Relative)),
    Shown = ern_build:shown(File),
    lists:foreach(fun(Component) -> ern_build:shape(Shown, Component) end, Components).

format_result(Options, Output, Same) ->
    case {lists:member(check, Options), Same} of
        {false, _} -> io:put_chars(Output), 0;
        {true, same} -> 0;
        {true, changed} -> io:format("-~n"), 1
    end.

format_file(Options, File, ErrorDevice) ->
    Text = ern_build:read(File),
    case ern_format:format(Text) of
        {ok, Text} -> ok;
        {ok, Output} ->
            case lists:member(check, Options) of
                true -> io:format("~ts~n", [ern_build:shown(File)]), changed;
                false -> ok = ern_build:write_whole(File, Output)
            end;
        {error, Diagnostic} ->
            io:format(ErrorDevice, "~ts~n",
                      [error_text(Options, ern_build:shown(File), Text, Diagnostic)]),
            error
    end.

error_text(Options, Shown, Source, Diagnostic) ->
    case lists:member(short_errors, Options) of
        true -> ern_diagnostic:short(Shown, Diagnostic);
        false -> ern_diagnostic:format(Shown, Source, Diagnostic)
    end.

%% Standard input to its end, through a port on its descriptor, since
%% `bin/ern` starts the host with -noinput.
open_input() ->
    erlang:open_port({fd, 0, 1}, [in, binary, eof, stream]).

read_input(Port, Acc) ->
    receive
        {Port, {data, Data}} -> read_input(Port, [Data | Acc]);
        {Port, eof} ->
            port_close(Port),
            iolist_to_binary(lists:reverse(Acc))
    end.

%%
%% ern run, ern test, ern shell and ern config, report §11.2 and §11.3
%%

%% Report §8.3, §11.2, §11.3: the configuration directory, which makes a
%% run a node and which `ern config` makes.
config_dir_option(What) ->
    {config_dir, undefined, "config-dir", string, "the configuration directory; " ++ What}.

load_path_option() ->
    {load_path, undefined, "load-path", string, "a root of compiled modules; may be repeated"}.

%% Report §11.2: a directory of the host's applications, each one's `ebin`
%% a directory of the load path.
libs_dir_option() ->
    {libs_dir, undefined, "libs-dir", string,
     "a directory of the host's applications; each one's ebin joins the load path"}.

main_option() ->
    {main, undefined, "main", string, "the entry point, a qualified exported function"}.

%% Report §11.1, §11.2: what the job decided, a line each on standard error.
verbose_option() ->
    {verbose, undefined, "verbose", undefined, "say on standard error what the job decided"}.

run_options() ->
    [config_dir_option("the run is a node"), load_path_option(), libs_dir_option(), main_option(),
     verbose_option(), help_option()].

test_options() ->
    [config_dir_option("the tests run on a node"), load_path_option(), libs_dir_option(),
     verbose_option(), help_option()].

shell_options() ->
    [config_dir_option("the shell is a node, and its startup is run"),
     load_path_option(),
     libs_dir_option(),
     {source_root, undefined, "source-root", string,
      "where the shell finds a module's source; default: the working directory"},
     main_option(), help_option()].

%% Report §11.2: `ern reload` and `ern stop` name the node by its
%% directory, so --config-dir is theirs to require.
signal_options(What) ->
    [config_dir_option(What), help_option()].

required_by(config_dir) -> ["ern reload", "ern stop"];
required_by(_) -> [].

config_options() ->
    [config_dir_option("the directory made, ./.ernest by default"), help_option()].

run(Options, [File | Words], ErrorDevice) ->
    Arguments = program_arguments(Words, 1),
    quiet_signals(),
    Say = ern_build:verbose(Options, ErrorDevice),
    {Namespace, LoadPath, Loaded} = program(File, Options, Say),
    as_node(Options, LoadPath, Say,
            fun(Node) -> run_entry(Options, Namespace, Loaded, Arguments, ErrorDevice, Node) end);
run(Options, [], ErrorDevice) ->
    %% report §11.2: `--config-dir` makes a run a node, and a node with no
    %% `.erc` is a bare node; a run that is no node runs a program
    is_node(Options) orelse usage_fail("one .erc file argument is required"),
    %% report §8.1, §11.2: --main names a function of the file, and a bare
    %% node has no entry point
    not lists:keymember(main, 1, Options) orelse usage_fail(no_main_file(run)),
    quiet_signals(),
    LoadPath = ern_build:load_path(Options),
    host_path(LoadPath),
    as_node(Options, LoadPath, ern_build:verbose(Options, ErrorDevice), bare,
            fun(Node) -> run_bare(ErrorDevice, Node) end).

%% Report §11.2, Appendix E.23: the program's arguments, Os.arguments, as
%% UTF-8 text, one that is not UTF-8 refused by its position before
%% anything runs.
program_arguments([], _Position) ->
    [];
program_arguments([Word | Words], Position) ->
    is_utf8(Word) orelse ern_build:fail(io_lib:format("argument ~B is not UTF-8", [Position])),
    [word_bytes(Word) | program_arguments(Words, Position + 1)].

%% Report §8.1, §8.5, §8.6, §8.7, §11.8: a bare node's run. Its entry
%% process evaluates the standard library's bindings, which the runtime
%% evaluates in every run, and no other, its `init` saying the host's limits
%% alone, then listens and waits; the node ends by termination, by an
%% `Os.exit` a process spawned on it calls, or by a stream that can no
%% longer be written, each ending it as it ends a program. Report §8.1,
%% §6.9: its entry process's site is `bare node`.
run_bare(ErrorDevice, Node) ->
    RunOptions = reporting_options(maps:merge(#{init => fun say_limits/0}, Node), ErrorDevice),
    report_outcome(ErrorDevice, ern_rt:run_main(fun waits/0, <<"bare node">>, RunOptions)).

%% Report §8.1, §8.6: a bare node's entry process does not return: it waits
%% for the node's end, which ends it with every other process, and no
%% process has its address to send it anything.
-spec waits() -> no_return().
waits() ->
    receive after infinity -> ok end.

%% Report §11.2: the tests of a module, or of every module under a
%% directory.
test(Options, [Path], ErrorDevice) ->
    quiet_signals(),
    Say = ern_build:verbose(Options, ErrorDevice),
    case filelib:is_dir(Path) of
        true ->
            Files = ern_build:compiled_under(Path),
            LoadPath = [ern_build:absolute(Path) | ern_build:load_path(Options)],
            as_node(Options, LoadPath, Say,
                    fun(Node) ->
                        report_tree(tree_tests(Files, Options, Say, ErrorDevice, Node))
                    end);
        false ->
            {Namespace, LoadPath, Loaded} = program(Path, Options, Say),
            as_node(Options, LoadPath, Say,
                    fun(Node) ->
                        run_tests(Namespace, Loaded, examples(Namespace, LoadPath, Loaded, Say),
                                  none, ErrorDevice, Node)
                    end)
    end;
test(_Options, _Rest, _ErrorDevice) ->
    usage_fail("one .erc file or one directory is required").

%% Report §11.2: the modules of a directory in the order of their paths,
%% each with tests run as `ern test file.erc` runs it, in a runtime of its
%% own, its name before its tests' lines, and one without passed over,
%% loaded and not run; the status of each run. A run a signal ended, or
%% whose output could no longer be written, is the last. Say says each
%% module read (--verbose).
tree_tests([], _Options, _Say, _ErrorDevice, _Node) ->
    [];
tree_tests([File | Files], Options, Say, ErrorDevice, Node) ->
    {Namespace, LoadPath, Loaded} = program(File, Options, Say),
    %% report §11.2: a module's doc examples are cases as its tests are
    {Examples, _} = Cases = examples(Namespace, LoadPath, Loaded, Say),
    case erlang:function_exported(ern_namespace:erlang_module(Namespace), '$tests', 0)
         orelse Examples =/= [] of
        false ->
            tree_tests(Files, Options, Say, ErrorDevice, Node);
        true ->
            Name = unicode:characters_to_binary(ern_namespace:text(Namespace)),
            case run_tests(Namespace, Loaded, Cases, Name, ErrorDevice, Node) of
                Status when Status =:= 0; Status =:= 1 ->
                    [Status | tree_tests(Files, Options, Say, ErrorDevice, Node)];
                Ended ->
                    [Ended]
            end
    end.

%% Report §11.2: the doc examples of the module Namespace, which the run
%% loaded from LoadPath with those it uses, Loaded, as ern_examples makes
%% them: a module an example names is found on LoadPath and loaded as the
%% run loads a module the documented one uses, said by Say as it is read.
examples(Namespace, LoadPath, Loaded, Say) ->
    Reading = reading(program, Say),
    Load = fun(Named, Waiting, Acc) -> load(Named, Waiting, LoadPath, Acc, Reading) end,
    ern_examples:cases(Namespace, Loaded, LoadPath, Load).

%% Report §11.2, §11.8: a directory without a test says so; status 1 where
%% a test failed or faulted, and the status of the run that ended the job
%% where one did.
report_tree([]) ->
    io:format("no tests~n"),
    0;
report_tree(Statuses) ->
    lists:max(Statuses).

%% Report §8.7, §11.2: hangup sent to the node that holds the directory's
%% `ernest.pid`, which reads its configuration again; the status says only
%% that the signal was delivered.
reload(Options, [], _ErrorDevice) ->
    ern_node:signaled(node_dir(Options), 1),
    0;
reload(_Options, _Rest, _ErrorDevice) ->
    usage_fail("reload takes no argument").

%% Report §8.6, §8.7, §11.2: termination sent to the node that holds the
%% directory's `ernest.pid`, which ends in order; the status says that the
%% node has ended, which the job waits for on the node's lock, with no time
%% of its own.
stop(Options, [], _ErrorDevice) ->
    ern_node:stopped(node_dir(Options)),
    0;
stop(_Options, _Rest, _ErrorDevice) ->
    usage_fail("stop takes no argument").

node_dir(Options) ->
    case proplists:get_value(config_dir, Options) of
        undefined -> usage_fail("--config-dir is required: it names the node");
        ConfigDir -> ConfigDir
    end.

%% Report §11.3: the configuration directory made, and the node's public key
%% printed, which another node's configuration lists.
config(Options, [], _ErrorDevice) ->
    Public = ern_node:create(proplists:get_value(config_dir, Options, ".ernest")),
    io:format("~ts", [Public]),
    0;
config(_Options, _Rest, _ErrorDevice) ->
    usage_fail("config takes no argument").

%% Report §11.2: the shell is the entry process, and a file's entry point is
%% spawned beside it, so §8.6 ends the program when the shell ends and not
%% when that entry point returns. The shell spawns it itself, through the
%% front end, after it has subscribed to faults (E.21); what the runner does is load
%% the modules, put their interfaces in the session's scope, and run their
%% initializers (§8.5) before the shell starts.
shell(Options, Rest, ErrorDevice) ->
    quiet_signals(),
    %% report §11.7: the shell takes no --verbose, and says nothing of what
    %% it reads
    Say = fun(_) -> ok end,
    %% report §11.2: the shell's modules are loaded from build/shell as each
    %% is first called (ern_code:ensure_loaded/1)
    ErlangModule = ern_namespace:erlang_module(['Shell']),
    case ern_code:ensure_loaded(ErlangModule) of
        {module, ErlangModule} -> ok;
        _ -> ern_build:fail("the shell is not built; run make")
    end,
    %% report §8.5: the shell's own modules are initialized as a program's
    %% are, before those of the file it loads
    {Init, LoadPath} =
        case Rest of
            [] ->
                %% report §11.2: --main names a function of the file
                not lists:keymember(main, 1, Options) orelse usage_fail(no_main_file(shell)),
                GivenLoadPath = ern_build:load_path(Options),
                host_path(GivenLoadPath),
                ern_shell:loaded(#loaded{load_path = GivenLoadPath,
                                         source_root = ern_build:source_root(Options, ".", "."),
                                         config_startup = config_startup(Options)}),
                {init_fun([ErlangModule]), GivenLoadPath};
            [File] ->
                {Namespace, FileLoadPath, Loaded} = program(File, Options, Say),
                Entry = shell_entry(Options, Namespace),
                ern_shell:loaded(#loaded{load_path = FileLoadPath,
                                         source_root = ern_build:source_root(Options, File, "."),
                                         interfaces = interfaces(Loaded),
                                         program = program_modules(Loaded, hd(FileLoadPath)),
                                         entry = Entry,
                                         config_startup = config_startup(Options)}),
                {init_fun(Loaded ++ [ErlangModule]), FileLoadPath};
            _ ->
                usage_fail("at most one .erc file argument")
        end,
    %% report §11.2: the sinks are the screen's, which the shell names
    Sink = fun(Bytes) -> ern_shell:to_screen(Bytes) end,
    %% report §11.2: Os.exit faults the process that calls it
    %% report §11.1: the unit names its functions by their position
    {Main, 0} = ern_code:function(ErlangModule, ['Shell', main]),
    Outcome = as_node(Options, LoadPath, Say,
                      fun(Node) ->
                          ern_rt:run_main(fun() -> ErlangModule:Main() end, <<"Shell.main">>,
                                          Node#{stdout => Sink, stderr => Sink, init => Init,
                                                exit => fault,
                                                flush => fun ern_shell:flush_screen/0})
                      end),
    report_shell_outcome(ErrorDevice, Outcome).

%% Report §8.3: a run given `--config-dir` is a node.
is_node(Options) ->
    proplists:is_defined(config_dir, Options).

%% Report §8.3, §8.7, §11.2: a run given `--config-dir` is a node: its
%% directory checked and read before anything of it runs, its carrier
%% started once the bindings have their values, which the run's options
%% carry (ern_rt:run_main/3), and its `ernest.pid` removed at its end,
%% however it ends, a start refused once the file is written among the
%% ways; a run without it is no node. Where the launcher asks for the
%% host's flags (node_flags/0), they are answered and nothing runs. Say
%% says each module the node's start reads (§11.2, --verbose).
as_node(Options, LoadPath, Say, Run) ->
    as_node(Options, LoadPath, Say, program, Run).

%% The same, Holds bare for `ern run`'s bare node, which is refused where
%% it does not listen (§8.7, §11.2) before the host's flags are answered,
%% so that the launcher's second start says the refusal, and program for
%% every other node. Report §8.7, §11.2: a shell's with no `.erc` is a bare
%% node with a prompt, which dials from its prompt and is not refused
%% without `listen`.
as_node(Options, LoadPath, Say, Holds, Run) ->
    case proplists:get_value(config_dir, Options) of
        undefined ->
            Run(#{});
        ConfigDir ->
            %% the configuration is read first: one the first start could not
            %% read gave it no flags, and its refusal is what is said
            Read = ern_node:read(ConfigDir),
            listens(Holds, ConfigDir, Read),
            case persistent_term:get({?MODULE, flags}, false) of
                true -> throw({node_flags, ern_carrier:boot_flags(Read)});
                false -> run_node(ConfigDir, Read, LoadPath, Say, Run)
            end
    end.

%% Report §8.7, §11.2: a bare node listens, since it never dials, and one
%% whose `ernest.conf` has no `listen` is refused at its start.
listens(bare, ConfigDir, #configuration{listen = none}) ->
    ern_build:fail("a bare node listens: " ++ ern_build:shown(ern_node:file(ConfigDir, conf))
                   ++ " has no listen");
listens(_Holds, _ConfigDir, _Configuration) ->
    ok.

%% A node's run, from its configuration read.
run_node(ConfigDir, Read, LoadPath, Say, Run) ->
    ern_carrier:booted()
        orelse ern_build:fail("the host was not started as a node, which ern does where"
                              " the command line holds --config-dir"),
    Configuration = ern_node:start(ConfigDir, Read),
    try
        %% report §8.7: a node carries the whole build, so that a function a
        %% peer spawns finds its code; nothing of it is initialized because
        %% a peer asked
        whole_build(LoadPath, Say),
        %% report §8.7: its peers listed from its start, so that a find or a
        %% spawn in an initializer is a peer's, which no connection reaches
        %% yet
        ok = ern_carrier:list(Configuration),
        Run(#{node => fun() -> ern_carrier:start(Configuration) end})
    after
        %% report §8.7: a node stops in order, then its ernest.pid goes
        ern_carrier:depart(),
        ern_node:stop(ConfigDir)
    end.

%% Report §11.2: `--main` names a function of the file the job is given, and
%% none is.
no_main_file(shell) ->
    "--main names the function to spawn from the file the shell loads, and no file is given";
no_main_file(run) ->
    "--main names the entry point of the file run, and no file is given; a bare node has none".

%% Report §11.2: every fault on standard error as it happens, a line each:
%% the spawn site and the cause; after the cause, for a process a peer
%% spawned, the peer, named as a node's line names it (§8.7), since the
%% site is the spawner's; and beneath it the fault's trace (§7.3,
%% indented_trace/1). It goes through standard error's
%% process, so that it keeps its place among what the program wrote there,
%% and is flushed with it when the program ends. The runtime's own
%% subscriber of Process.faults (Appendix E.21), given the peer's node or
%% none, by which a peer a reload has removed since is named as a node's
%% line names one not listed, where the report's `peer` is `None`. Where
%% standard error is neither a terminal nor a service manager's journal,
%% each line begins with the time, in UTC as RFC 3339 writes it. Report
%% §11.2, Appendix E.24: a fault of a process Test.faults started, whose
%% site is that function's (§6.9), is not reported, since the call's answer
%% carries it; `ern run` and `ern test` alike.
report_fault({'FaultReport', _, <<"Test.faults:", _/binary>>, _, _, _, _}, _, _) ->
    ok;
report_fault({'FaultReport', _Process, Site, Cause, Restarted, Trace, _}, Peer, Stamped) ->
    Faulted = case Restarted of
                  true -> <<" faulted, restarted: ">>;
                  false -> <<" faulted: ">>
              end,
    SpawnedBy = case Peer of
                    none -> [];
                    _ -> [", spawned by ", ern_carrier:named(Peer)]
                end,
    ern_rt:send(ern_rt:system_process(stderr),
                iolist_to_binary([stamp(Stamped), Site, Faulted, ern_show:controls(Cause, line),
                                  SpawnedBy, "\n", indented_trace(Trace)])).

%% Report §11.2, Appendix E.21: a fault's trace as it is printed beneath
%% the fault's line, a frame a line, each indented by four spaces, a
%% control character written as its escape.
-spec indented_trace(binary()) -> iodata().
indented_trace(Trace) ->
    [["    ", ern_show:controls(Frame, line), "\n"]
     || Frame <- binary:split(Trace, <<"\n">>, [global, trim_all])].

%% Report §11.2, §8.7: what a line on standard error begins with, a fault's
%% or a node's: its time, in UTC as RFC 3339 writes it, where the lines are
%% stamped, and nothing where they are not.
-spec stamp(boolean()) -> iodata().
stamp(true) ->
    [calendar:system_time_to_rfc3339(erlang:system_time(millisecond),
                                     [{unit, millisecond}, {offset, "Z"}]), " "];
stamp(false) ->
    [].

%% The options of a launch that reports its faults. From the command line the
%% program writes to the process's own standard output and standard error,
%% through ports that learn when a stream has gone (report §8.2), and a
%% fault line, and the runtime's line of the end's wait (§8.6), carries
%% its time where standard error is neither a terminal nor a journal
%% (§11.2); in a test, standard error is the test's device.
reporting_options(RunOptions, ErrorDevice) ->
    case persistent_term:get({?MODULE, streams}, device) of
        fds ->
            Stamped = is_stamped(),
            RunOptions#{faults => fun(FaultReport, Peer) ->
                                      report_fault(FaultReport, Peer, Stamped)
                                  end,
                        say => fun ern_carrier:say/1, stdout => {fd, 1}, stderr => {fd, 2}};
        device ->
            RunOptions#{faults => fun(FaultReport, Peer) ->
                                      report_fault(FaultReport, Peer, false)
                                  end,
                        stderr => fun(Bytes) -> file:write(ErrorDevice, Bytes) end}
    end.

%% Report §11.2, §8.7: whether a line on standard error begins with its
%% time: where the program writes to the process's own standard error, and
%% that is neither a terminal nor a journal.
-spec is_stamped() -> boolean().
is_stamped() ->
    persistent_term:get({?MODULE, streams}, device) =:= fds
        andalso not ern_tty:is_terminal(stderr) andalso not is_journal().

%% Report §11.2: whether standard error is a service manager's journal,
%% which systemd says by JOURNAL_STREAM, the device and inode of the
%% stream it gave, so that a stream a shell has since redirected is not.
is_journal() ->
    case {os:getenv("JOURNAL_STREAM"), file:read_file_info("/dev/stderr")} of
        {false, _} -> false;
        {Stream, {ok, #file_info{major_device = Device, inode = Inode}}} ->
            Stream =:= integer_to_list(Device) ++ ":" ++ integer_to_list(Inode);
        _ -> false
    end.

%% Report §11: a compiled module's bytes, or the refusal of a file that is
%% none, named as the user named it and not by what it holds. A module the
%% host compiled from another language holds no interface, and is none.
compiled(File) ->
    Beam = ern_build:read(File),
    case beam_lib:chunks(Beam, [binary_to_list(ern_interface:chunk_name())]) of
        {error, beam_lib, _} -> ern_build:fail(File ++ " is not a compiled module");
        {ok, _} -> Beam
    end.

%% Report §11.2: a file given to run that is no `.erc`, and a module's
%% source among them, which is built first.
not_compiled(File) ->
    case filename:extension(File) of
        ".ern" -> File ++ " does not end in .erc; build it first: ern build " ++ File;
        _ -> File ++ " does not end in .erc"
    end.

%% The module of a `.erc`, its load path, and every module loaded for it:
%% the file's own dependencies first (report §11.2, §4.2), each said by Say
%% as it is read (--verbose).
program(File, Options, Say) ->
    filelib:is_regular(File) orelse ern_build:fail("no such file " ++ File),
    filename:extension(File) =:= ".erc" orelse ern_build:fail(not_compiled(File)),
    Absolute = ern_build:absolute(File),
    Beam = compiled(File),
    Namespace = case ern_interface:read(Beam) of
                    {ok, #{interface := #interface{namespace = Found}}} -> Found;
                    {error, Error} -> ern_build:fail(File ++ ": " ++ Error)
                end,
    %% the root lies as many directories up as the namespace is deep
    ModuleRoot = lists:foldl(fun(_, Dir) -> filename:dirname(Dir) end, Absolute, Namespace),
    ern_build:relative(Absolute, ModuleRoot) =:= ern_build:module_path(Namespace) ++ ".erc" orelse
        ern_build:fail(File ++ " is not at the path of its namespace "
                       ++ ern_namespace:text(Namespace)),
    Components = filename:split(filename:rootname(ern_build:module_path(Namespace))),
    lists:foreach(fun(Component) -> ern_build:shape(File, Component) end, Components),
    LoadPath = [ModuleRoot | ern_build:load_path(Options)],
    host_path(LoadPath),
    {Namespace, LoadPath, load(Namespace, [], LoadPath, [], reading(program, Say))}.

%% Report §11.2: an Erlang module a `foreign fn` names is the host's own or
%% a `.beam` in a directory of the load path, the host's own found first.
%% The working directory, which the host puts on its code path, is neither,
%% unless it is a root of the load path; start/0 has taken it off.
%% Appendix E.28: the load path is kept, where Code.load finds the modules
%% a module it loads uses (load_path/0).
host_path(LoadPath) ->
    persistent_term:put({?MODULE, load_path}, LoadPath),
    ok = code:add_pathsz(LoadPath).

%% Appendix E.28, report §11.2: the load path of the run in progress, its
%% roots in order, the standard library aside, which every run holds; none
%% where no run of `ern` gave one, as in a test that runs a program itself.
-spec load_path() -> [file:filename()].
load_path() ->
    persistent_term:get({?MODULE, load_path}, []).

%% Report §11.2: the interfaces of the modules loaded, which the shell puts
%% in the session's scope, each with the hash of the source it was compiled
%% from, which `:reload` compares against the source it finds; both are in
%% the `ErnI` chunk of the `.erc` it came from (§11.1).
interfaces(Loaded) ->
    [{Interface, Hash} || ErlangModule <- lists:reverse(Loaded),
                          {ok, Beam} <- [file:read_file(code:which(ErlangModule))],
                          {ok, #{interface := Interface, source_hash := Hash}}
                              <- [ern_interface:read(Beam)]].

%% Report §11.2: the namespaces of the loaded modules whose compiled forms
%% lie under the file's own root, the program the shell runs, and not a
%% library's on another root of the load path.
program_modules(Loaded, ModuleRoot) ->
    [Namespace
     || {#interface{namespace = Namespace}, _}
            <- interfaces([ErlangModule || ErlangModule <- Loaded,
                                           lists:prefix(ModuleRoot ++ "/",
                                                        code:which(ErlangModule))])].

%% Report §11.2: the startup file of the configuration directory of §11.3,
%% run only where `--config-dir` names that directory, never for the
%% default, which is wherever the shell was started; none otherwise. The
%% person's the shell finds itself.
config_startup(Options) ->
    case proplists:get_value(config_dir, Options) of
        undefined -> none;
        ConfigDir -> filename:join(ConfigDir, "startup")
    end.

%% Report §8.6: the host's termination and hangup end the program as the
%% end of its entry process does, and the runtime prints nothing of its own
%% about them (ern_signals).
quiet_signals() ->
    ok = ern_signals:install(),
    %% the host logs its own note about a signal at notice level, and a
    %% program's output is not to be mixed with it; a warning or an error
    %% from the host still comes through.
    _ = logger:set_handler_config(default, level, warning),
    ok.

%% Report §11.2: the status a running program ends `ern` with, and what it
%% prints of its entry process's end: nothing when it returned, `killed`
%% when it was killed, its fault, nothing for a signal, whose status is 128
%% plus its number, and nothing for Os.exit, whose status is its own.
report_outcome(_ErrorDevice, ok) -> 0;
report_outcome(_ErrorDevice, {exit, Status}) -> Status;
%% report §8.2, §11.2: a stream that can no longer be written, as a shell
%% reports a broken pipe
report_outcome(_ErrorDevice, {gone, _Stream}) -> 128 + 13;
report_outcome(ErrorDevice, killed) -> io:format(ErrorDevice, "killed~n", []), 1;
%% report §8.6, §11.2: the signal ended the program, and `ern` ends by it
report_outcome(_ErrorDevice, {signal, Signal}) -> ern_signals:ended(Signal);
%% report §11.2: the entry process's fault has been reported as it happened
report_outcome(_ErrorDevice, _Fault) -> 1.

%% Report §11.2: the shell reports the faults of the session's processes
%% itself, as a subscriber, so its own end, which no subscriber of its own
%% is left to see, is said here, its cause escaped as every fault's is. A
%% fault of the shell's own is a failure of ern itself, but for one its
%% standard input gave it, which ends the shell and is said as its end,
%% not as an input's fault (§11.8). Every such cause is the standard
%% input's, `the standard input is not UTF-8`.
report_shell_outcome(ErrorDevice, {fault, Cause, Trace}) ->
    case ern_rt:by_input(Cause) of
        true ->
            <<"the ", Input/binary>> = Cause,
            io:format(ErrorDevice, "the shell ends: its ~ts~n", [ern_show:controls(Input, line)]),
            1;
        false ->
            io:format(ErrorDevice, "fault: ~ts~n~ts",
                      [ern_show:controls(Cause, line), indented_trace(Trace)]),
            70
    end;
%% report §6.9: a shell the host ended otherwise met no fault, and has no
%% trace
report_shell_outcome(ErrorDevice, {fault, Cause}) ->
    report_shell_outcome(ErrorDevice, {fault, Cause, <<>>});
%% report §8.5, §11.2: a binding that faulted before the shell began
report_shell_outcome(ErrorDevice, {initializer_fault, Site, Cause, Trace}) ->
    io:format(ErrorDevice, "~ts faulted: ~ts~n~ts",
              [Site, ern_show:controls(Cause, line), indented_trace(Trace)]),
    1;
report_shell_outcome(ErrorDevice, {initializer_fault, Site, Cause}) ->
    report_shell_outcome(ErrorDevice, {initializer_fault, Site, Cause, <<>>});
report_shell_outcome(ErrorDevice, Other) -> report_outcome(ErrorDevice, Other).

%% Report §8.5: every top-level let of the loaded modules, dependencies
%% first, once the runtime has bound the system references.
init_fun(Loaded) ->
    fun() ->
        ern_rt:init_modules(lists:reverse(Loaded)),
        say_limits()
    end.

%% Report §11.2: each of the host's limits on what a runtime loads that the
%% loads so far have brought to four fifths, said once, as a node's line is
%% (§8.7): at a run's start, once its units are loaded, and at each load of
%% the shell's.
-spec say_limits() -> ok.
say_limits() ->
    lists:foreach(fun ern_carrier:say/1, ern_code:nearing()).

%% Report §11.2: every test of the module, one at a time in the order the
%% module declares them, each in a process of its own and its line printed
%% as it ends, then, once their launch has ended, its doc examples,
%% Examples, as ern_examples made them, each a program of its own, in a
%% launch of its own in an empty directory of its own; status 1 unless
%% every one passed. A tests' launch that ends otherwise than by its entry
%% process's return, by an initializer's fault among them, ends the
%% module's run with the status that end gives (report_outcome/2); an
%% example's fails that example alone, but for a signal's or a stream's
%% (example_launch/3). The units the examples' compiling loaded go once the
%% last has run.
run_tests(Namespace, Loaded, {Examples, Units}, Heading, ErrorDevice, Node) ->
    Caller = self(),
    Entry = fun(Running) ->
                tests_entry(ern_namespace:erlang_module(Namespace), Examples =/= [], Caller,
                            Running)
            end,
    Site = unicode:characters_to_binary(ern_namespace:text(Namespace) ++ ".$tests"),
    Status = case cases_launch(tests, Entry, Site, headed(Heading, init_fun(Loaded)),
                               ErrorDevice, Node) of
                 {told, refused} -> 1;
                 {told, Passed} -> run_examples(Examples, Passed, ErrorDevice, Node);
                 Ended -> report_outcome(ErrorDevice, Ended)
             end,
    ern_examples:unload(Units),
    Status.

%% Report §11.2: each doc example run as a program of its own (§8.5), in
%% an empty directory of its own (ern_examples:in_directory/2), by a launch
%% of its own (example_launch/3). Passed says whether every case before
%% passed; the status of the module's run.
run_examples([], Passed, _ErrorDevice, _Node) ->
    case Passed of
        true -> 0;
        false -> 1
    end;
run_examples([Example | Examples], Passed, ErrorDevice, Node) ->
    Launched = fun(Ready) -> example_launch(Ready, ErrorDevice, Node) end,
    case ern_examples:in_directory(Example, Launched) of
        {told, ExamplePassed} ->
            run_examples(Examples, Passed andalso ExamplePassed, ErrorDevice, Node);
        {ended, Ended} ->
            Ended
    end.

%% Report §11.2: an example's launch, which initializes the modules the
%% example uses, the documented one among them, and whose entry process
%% runs it as a test is run, in a process of its own, and prints its line;
%% nothing it leaves, a process or an offer, outlives its launch. An
%% example whose program ends before the example returns, an initializer's
%% fault among them, fails with `faulted` and the cause, its line written
%% as a test's is, its trace beneath it, and the fault is not reported
%% apart from it (cases_launch/6). The line is the job's own, written once
%% the launch has ended, since the launch's standard output has ended with
%% it, flushed. A signal, or a stream that can no longer be written, ends
%% the module's run, as it ends the tests' launch. Whether the example
%% passed, or the status of that end.
example_launch({{'Case', Name, _} = Case, Initialized}, ErrorDevice, Node) ->
    Caller = self(),
    Entry = fun(Running) ->
                fun() -> Caller ! {ern_tests, run_test(Case, Running)} end
            end,
    case cases_launch(example, Entry, Name, init_fun(Initialized), ErrorDevice, Node) of
        {told, _} = Told ->
            Told;
        Ended ->
            case ended_reason(Ended) of
                {Reason, Trace} ->
                    io:put_chars(case_line(Name, <<"faulted: ", (cause(Reason))/binary>>, Trace)),
                    {told, false};
                none ->
                    {ended, report_outcome(ErrorDevice, Ended)}
            end
    end.

%% Report §11.2: the Reason (§9.3) of an example's program's end before
%% the example returned, as a test's Down carries it, and its fault's
%% trace; none for a signal or a stream that can no longer be written. The
%% program cannot end by Os.exit, which faults its caller here.
ended_reason(killed) -> {'Killed', <<>>};
ended_reason({fault, Cause}) -> {{'Fault', Cause}, <<>>};
ended_reason({fault, Cause, Trace}) -> {{'Fault', Cause}, Trace};
ended_reason({initializer_fault, _Site, Cause}) -> {{'Fault', Cause}, <<>>};
ended_reason({initializer_fault, _Site, Cause, Trace}) -> {{'Fault', Cause}, Trace};
ended_reason({signal, _}) -> none;
ended_reason({gone, _}) -> none.

%% Report §11.2: a launch whose entry process, Entry(Running), runs cases
%% by run_test/2 and tells the runner what they came to, Init run before it
%% (§8.5), the cases being the module's tests or a doc example; what it
%% told, or the outcome it ended with otherwise. A case's own fault is its
%% line, and so, in an example's launch, is the entry process's, an
%% initializer's among them, which the outcome carries (example_launch/3);
%% every other fault is reported as `ern run` reports it.
cases_launch(Cases, Entry, Site, Init, ErrorDevice, Node) ->
    %% the test that runs, which the reporter asks for: a row, since it
    %% changes with each test, and the host copies its table of persistent
    %% terms at each change of one
    Running = ets:new(running_test, [public]),
    %% report §11.2: Os.exit faults the test that calls it
    RunOptions = reporting_options(maps:merge(#{init => Init, exit => fault}, Node),
                                   ErrorDevice),
    Report = maps:get(faults, RunOptions),
    %% report §11.2: a test's own fault is its line, its trace beneath it,
    %% which its row keeps until its end is here; an example's entry
    %% process's is the example's line, which the outcome carries
    Reporter = fun({'FaultReport', Process, _, _, _, Trace, _} = FaultReport, Peer) ->
                       case {ets:member(Running, Process), Cases} of
                           {true, _} ->
                               ets:insert(Running, {Process, Trace});
                           {false, example} ->
                               case ern_rt:entry_process() of
                                   Process -> ok;
                                   _ -> Report(FaultReport, Peer)
                               end;
                           {false, tests} ->
                               Report(FaultReport, Peer)
                       end
               end,
    Outcome = ern_rt:run_main(Entry(Running), Site, RunOptions#{faults => Reporter}),
    ets:delete(Running),
    case Outcome of
        ok -> receive {ern_tests, Told} -> {told, Told} end;
        Ended -> Ended
    end.

%% Report §11.2: under a directory the module's name stands on a line
%% before everything its run writes, its initializers' output among it.
headed(none, Init) ->
    Init;
headed(Heading, Init) ->
    fun() ->
        ern_rt:send(ern_rt:system_process(stdout), <<Heading/binary, "\n">>),
        Init()
    end.

%% The entry point of a module's tests, which runs them one at a time and
%% tells Caller whether every one passed, or that they were refused, before
%% the module's doc examples run, which it is told the module has.
tests_entry(ErlangModule, HasExamples, Caller, Running) ->
    fun() ->
        Tests = case erlang:function_exported(ErlangModule, '$tests', 0) of
                    true -> ErlangModule:'$tests'();
                    false -> []
                end,
        Names = [Name || {'Case', Name, _} <- Tests],
        %% report §11.2: a module without tests or examples says so, and
        %% one two of whose tests have one name is refused before any runs
        case {Tests =:= [] andalso not HasExamples, Names -- lists:usort(Names)} of
            {true, _} ->
                ern_rt:send(ern_rt:system_process(stdout), <<"no tests\n">>),
                Caller ! {ern_tests, true};
            {false, [Twice | _]} ->
                ern_rt:send(ern_rt:system_process(stderr),
                            <<"ern test: two tests are named \"",
                              (ern_show:controls(Twice, line))/binary, "\"\n">>),
                Caller ! {ern_tests, refused};
            {false, []} ->
                Passed = [run_test(Case, Running) || Case <- Tests],
                Caller ! {ern_tests, not lists:member(false, Passed)}
        end
    end.

%% One test, Test.Case(name, run) in declared field order, in a process of its
%% own, monitored from its start so that a fault is reported, however soon
%% it comes, and not taken for the entry process's (report §6.9). A deadlock while it
%% runs is its fault (§11.2). Its line goes through standard output's
%% process, after what the test wrote there, the trace of its fault beneath
%% it, which the reporter kept in its row; whether it passed is returned.
run_test({'Case', Name, Run}, Running) ->
    Self = ern_rt:self(),
    Ref = make_ref(),
    Pid = ern_rt:spawn_monitored(fun() -> receive {Ref, go} -> Self ! {Ref, Run()} end end,
                                 fun(Down) -> {Ref, down, Down} end, Name),
    ok = ern_rt:deadlock_victim(Pid),
    %% the reporter hears of the test's fault before this process does,
    %% so the test is known before it runs and forgotten only once its end
    %% is here
    ets:insert(Running, {Pid}),
    Pid ! {Ref, go},
    Outcome = receive
                  {Ref, 'Passed'} -> returned(Ref, <<"passed">>);
                  {Ref, {'Failed', Text}} ->
                      returned(Ref, <<"failed: ", (ern_show:controls(Text, line))/binary>>);
                  {Ref, down, {'Down', _, Reason, _}} -> <<"faulted: ", (cause(Reason))/binary>>
              end,
    ok = ern_rt:deadlock_victim(none),
    Trace = case ets:take(Running, Pid) of
                [{_, Faulted}] -> Faulted;
                [{_}] -> <<>>
            end,
    ern_rt:send(ern_rt:system_process(stdout), case_line(Name, Outcome, Trace)),
    Outcome =:= <<"passed">>.

%% Report §11.2: a case's line, its name written as a cause is, its
%% controls escaped, then what it came to, and beneath the line of a case
%% that faulted its trace.
case_line(Name, Outcome, Trace) ->
    iolist_to_binary([ern_show:controls(Name, line), ": ", Outcome, "\n", indented_trace(Trace)]).

%% A test that returned still sends its Down; it is taken so that it is not
%% left in the runner's mailbox.
returned(Ref, Outcome) ->
    receive {Ref, down, _} -> Outcome end.

cause({'Fault', Cause}) -> ern_show:controls(Cause, line);
cause(Reason) -> atom_to_binary(Reason).

run_entry(Options, Namespace, Loaded, Arguments, ErrorDevice, Node) ->
    EntryFunction = entry_point(Options, Namespace),
    EntryModule = ern_namespace:erlang_module(Namespace),
    Init = init_fun(Loaded),
    Site = entry_site(Namespace, EntryFunction),
    %% report §11.1: the unit names its functions by their position
    {Function, 0} = ern_code:function(EntryModule, Namespace ++ [EntryFunction]),
    %% report §8.6: a deadlock is the entry process's fault
    RunOptions = reporting_options(maps:merge(#{init => Init, arguments => Arguments}, Node),
                                   ErrorDevice),
    Outcome = ern_rt:run_main(fun() -> EntryModule:Function() end, Site, RunOptions),
    report_outcome(ErrorDevice, Outcome).

%% Report §11.2: the entry point the shell spawns beside it, or none for a
%% file without one, which is loaded to be tried. A `main` that is not an
%% entry point (§8.1) leaves the file without one; a function `--main`
%% names must be one.
shell_entry(Options, Namespace) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    case proplists:get_value(main, Options) =:= undefined
         andalso entry_shape(ErlangModule, main) =/= entry of
        true ->
            none;
        false ->
            EntryFunction = entry_point(Options, Namespace),
            %% report §11.1: the unit names its functions by their position
            {Function, 0} = ern_code:function(ErlangModule, Namespace ++ [EntryFunction]),
            #entry_point{erlang_module = ErlangModule, function = Function,
                         site = entry_site(Namespace, EntryFunction)}
    end.

%% Report §8.1: the entry point, the loaded module's `main` or the function
%% of that module `--main` names (§11.2), by its name. It is an exported
%% `fn` of type `() -> Unit`, receiving or not; a top-level
%% `let`, and a function of another shape, is refused.
entry_point(Options, Namespace) ->
    EntryFunction = case proplists:get_value(main, Options) of
                        undefined -> main;
                        Given -> main_of(Given, Namespace)
                    end,
    Name = ern_namespace:text(Namespace ++ [EntryFunction]),
    Shape = "; an entry point is an exported fn of type () -> Unit (report §8.1)",
    case entry_shape(ern_namespace:erlang_module(Namespace), EntryFunction) of
        entry -> ok;
        missing -> ern_build:fail("no exported function " ++ Name ++ Shape);
        {'let', Type} ->
            ern_build:fail(Name ++ " is not an entry point: it is a let of type " ++ Type ++ Shape);
        {other, Type} ->
            ern_build:fail(Name ++ " is not an entry point: its type is " ++ Type ++ Shape)
    end,
    EntryFunction.

%% Report §11.2: the function `--main` names, which is one of the module
%% given, so the file and the option never name two modules to run.
main_of(Given, Namespace) ->
    {GivenNamespace, Function} = main_name(Given),
    GivenNamespace =:= Namespace
        orelse ern_build:fail("--main " ++ Given ++ " names a function of "
                              ++ ern_namespace:text(GivenNamespace)
                              ++ ", and the file given is the module "
                              ++ ern_namespace:text(Namespace)),
    Function.

%% Report §11.2, Appendix A: `--main` names a function by its qualified
%% name, a typename for each segment of the module's namespace and an
%% ident for the function, as the lexer reads them, and nothing between
%% them or after them.
main_name(Text) ->
    Named = case ern_lexer:tokenize(Text, []) of
                {ok, Tokens} -> qualified_name(Tokens, 1);
                {error, _} -> error
            end,
    case Named of
        {ok, [_ | _] = Namespace, Function} -> {Namespace, Function};
        _ -> usage_fail("--main takes a qualified name, Module.function")
    end.

%% The namespace and the function a qualified name's tokens spell, each
%% token beginning in the column where the one before it ended.
qualified_name([{typename, {1, Column, {1, End}, _}, Segment},
                {'.', {1, End, {1, Next}, _}} | Rest], Column) ->
    case qualified_name(Rest, Next) of
        {ok, Namespace, Function} -> {ok, [Segment | Namespace], Function};
        error -> error
    end;
qualified_name([{ident, {1, Column, {1, End}, _}, Function}, {eof, {1, End, _, _}}], Column) ->
    {ok, [], Function};
qualified_name(_, _) ->
    error.

%% What the interface of a loaded module says of one of its names: an entry
%% point, a `let`, a function of another shape, or nothing it exports. A
%% result type that is a type variable is instantiated to `Unit`, as a
%% polymorphic mailbox type is to `Never` (report §8.1).
entry_shape(ErlangModule, Function) ->
    {ok, Beam} = file:read_file(code:which(ErlangModule)),
    {ok, #{interface := #interface{namespace = Namespace, values = Values, lets = Lets}}} =
        ern_interface:read(Beam),
    QualifiedName = Namespace ++ [Function],
    case maps:find(QualifiedName, Values) of
        error ->
            missing;
        {ok, #scheme{type = SchemeType} = Scheme} ->
            Type = ern_types:format_scheme(Scheme, ern_types:new()),
            case {lists:member(QualifiedName, Lets), SchemeType} of
                {true, _} -> {'let', Type};
                {false, {tfn, [], _, {tcon, ['Unit'], []}}} -> entry;
                {false, {tfn, [], _, {tvar, _}}} -> entry;
                {false, _} -> {other, Type}
            end
    end.

entry_site(Namespace, Function) ->
    unicode:characters_to_binary(ern_namespace:text(Namespace ++ [Function])).

%% How a load reads: Reader is the program, which loads the modules a
%% module uses, or the node, which reads every module of its load path
%% (§8.7); beside it the standard library's hash, which each module read is
%% checked against, and Say, which says each module read (§11.2, --verbose).
reading(Reader, Say) ->
    {Reader, ern_build:stdlib_hash(), Say}.

%% Load a module and, first, its dependencies, each once; the result lists
%% modules most recently loaded first, so dependencies come last. Waiting
%% are the modules whose loads wait on Namespace's, the one that uses it
%% first, and none for one loaded for itself.
load(Namespace, Waiting, LoadPath, Loaded, {Reader, StdlibHash, Say} = Reading) ->
    ErlangModule = ern_namespace:erlang_module(Namespace),
    case lists:member(ErlangModule, Loaded) of
        true ->
            Loaded;
        false ->
            no_cycle(Namespace, Waiting),
            File = compiled_file(Namespace, Waiting, LoadPath, Reader),
            Beam = ern_build:read(File),
            #{deps := DependencyHashes} = Chunk = held_chunk(Namespace, File, Beam),
            say_read(Say, Namespace, File),
            Loaded1 = lists:foldl(fun({Dependency, _}, Acc) ->
                                      load(Dependency, [Namespace | Waiting], LoadPath, Acc,
                                           Reading)
                                  end, Loaded, DependencyHashes),
            %% report §11.2: a module compiled against another interface of a
            %% module it uses, or of the standard library, is refused, not run
            %% to fault where they differ
            lists:foreach(fun({Dependency, Hash}) ->
                              same_interface(Namespace, Dependency, Hash)
                          end, DependencyHashes),
            same_stdlib(Namespace, Chunk, StdlibHash),
            loaded_unit(ErlangModule, File, Beam),
            [ErlangModule | Loaded1]
    end.

%% Report §11.2: a module loaded from its file, or taken as the host holds
%% it (ern_code:load/3), and in the code table as it loads (§8.7).
loaded_unit(ErlangModule, File, Beam) ->
    case ern_code:load(ErlangModule, File, Beam) of
        ok -> ok;
        {error, Error} -> ern_build:fail("cannot load " ++ File ++ ": " ++ atom_to_list(Error))
    end.

%% Report §11.1, §4.1: a module whose load waits on its own load uses
%% itself through the modules between, a cycle, which no build holds and
%% which a build's files may hold all the same where each was compiled
%% against another form of the other; it is refused as `ern build`
%% refuses one, naming its modules, before anything runs.
no_cycle(Namespace, Waiting) ->
    case lists:member(Namespace, Waiting) of
        true ->
            {Between, _} = lists:splitwith(fun(User) -> User =/= Namespace end, Waiting),
            ern_build:fail(ern_build:module_cycle([Namespace | Between]));
        false ->
            ok
    end.

%% Report §11.2: --verbose's line of a module read, `read Main from
%% build/main.erc`, the standard library's aside, whose modules the host
%% holds for every run.
say_read(Say, Namespace, File) ->
    filename:dirname(File) =:= ern_prelude:stdlib_directory()
        orelse Say(["read ", ern_namespace:text(Namespace), " from ", ern_build:shown(File)]).

%% Report §8.7: every compiled module on the load path loaded, as the
%% modules a program uses are, with the same checks, and none initialized,
%% each said by Say as it is read (§11.2, --verbose).
whole_build(LoadPath, Say) ->
    Namespaces = [placed(Root, File, Beam, Namespace)
                  || Root <- LoadPath, File <- ern_build:compiled_under(Root),
                     Beam <- [ern_build:read(File)],
                     {ok, #{interface := #interface{namespace = Namespace}}}
                         <- [ern_interface:read(Beam)]],
    Loaded = [ErlangModule || {ErlangModule, _} <- code:all_loaded()],
    Reading = reading(node, Say),
    lists:foldl(fun(Namespace, Acc) -> load(Namespace, [], LoadPath, Acc, Reading) end, Loaded,
                Namespaces),
    ok.

%% Report §11.2: the namespace of a compiled module of the load path, which
%% stands at the path of its namespace under its root; one at another
%% module's path is refused as a program's load refuses it, naming the file
%% and the module it holds (held_chunk/3), and not as the module its
%% namespace names, missing at its own path.
placed(Root, File, Beam, Namespace) ->
    case filename:join(Root, ern_build:module_path(Namespace) ++ ".erc") =:= File of
        true ->
            Namespace;
        false ->
            Components = filename:split(filename:rootname(ern_build:relative(File, Root))),
            _ = held_chunk(ern_namespace:namespace(Components), File, Beam),
            Namespace
    end.

%% Report §11.2: a module's compiled form, found by its namespace on the
%% load path. One the path lacks is named with the module that uses it;
%% report §8.7: and, for a node, with the rule that makes a module the
%% program does not use its need.
compiled_file(Namespace, Waiting, LoadPath, Reader) ->
    Relative = ern_build:module_path(Namespace) ++ ".erc",
    case [Found || Dir <- LoadPath, Found <- [filename:join(Dir, Relative)],
                   filelib:is_regular(Found)] of
        [Found | _] ->
            Found;
        [] ->
            ern_build:fail(["cannot find module ", ern_namespace:text(Namespace), " (", Relative,
                            ")", needed_by(Waiting), " on the load path", read_by(Reader)])
    end.

needed_by([]) -> "";
needed_by([User | _]) -> [", which ", ern_namespace:text(User), " needs,"].

read_by(program) -> "";
read_by(node) -> ": a node reads every module of its load path".

%% Report §11.2: the interface chunk of a module's compiled form; a file
%% found by a module's namespace that holds another is no module of that
%% name.
held_chunk(Namespace, File, Beam) ->
    case ern_interface:read(Beam) of
        {ok, #{interface := #interface{namespace = Namespace}} = Chunk} ->
            Chunk;
        {ok, #{interface := #interface{namespace = Held}}} ->
            ern_build:fail(ern_build:shown(File) ++ " holds "
                           ++ ern_namespace:text(Held) ++ ", not "
                           ++ ern_namespace:text(Namespace)
                           ++ "; build it again from its source root");
        {error, Error} ->
            ern_build:fail(File ++ ": " ++ Error)
    end.

same_stdlib(Namespace, Chunk, StdlibHash) ->
    Name = ern_namespace:text(Namespace),
    lists:member(maps:get(stdlib, Chunk, none), [none, StdlibHash])
        orelse ern_build:fail(Name ++ " was compiled against another standard library; build "
                              ++ Name ++ " again").

same_interface(Namespace, Dependency, Hash) ->
    {ok, Beam} = file:read_file(code:which(ern_namespace:erlang_module(Dependency))),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    Name = ern_namespace:text(Namespace),
    ern_interface:hash(Interface) =:= Hash
        orelse ern_build:fail(Name ++ " was compiled against another "
                              ++ ern_namespace:text(Dependency) ++ "; build "
                              ++ Name ++ " again").

usage_fail(Message) ->
    throw({cli_usage, lists:flatten(Message)}).
