%% The toolchain of report §11: one command, ern, whose first word is its
%% job, build and doc (§11.1, §11.4), format (§11.6), run, test and shell
%% (§11.2), config (§11.3), reload and stop (§11.2, §12.5), and unpack
%% (§11.9). The launcher bin/ern is thin;
%% everything is here so that the tests can call it.
%% `ern/1,2` returns the exit status, which the launcher's entry point ends
%% the host with.
-module(ern_cli).

-export([start/0, node_flags/0, ern/1, ern/2, said_otherwise/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("checker/include/ern_types.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("builder/include/ern_build.hrl").
-include_lib("nodes/include/ern_node.hrl").

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({ernest_wait, [waits/0, run_test/3, returned/2]}).
-receives({own_process, [host_end/0, in_runtime/2, read_input/2, cases_launch/6]}).

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
%% program's outcome says the signal ended it (report_outcome/3), and
%% otherwise with the status.
-spec start() -> no_return().
start() ->
    ok = ern_signals:install(),
    %% report §11: the host's code path holds the working directory, so a
    %% `.beam` there would answer a module no other directory holds; no job
    %% reads one
    _ = code:del_path("."),
    Args = init:get_plain_arguments(),
    %% a job writes through ports of its own, the shell's screen among them,
    %% which end it when a stream can no longer be written (ern_out)
    ErrorDevice = ern_out:take(),
    Status = try
                 persistent_term:put({?MODULE, streams}, fds),
                 ern_job_line:set_stamped(not ern_out:is_terminal(stderr)
                                          andalso not is_journal()),
                 %% report §11.1: the build of `ern`, set at the job's start as
                 %% every persistent term is set at a launch (docs/design/runtime.md)
                 _ = ern_build:compiler_build(),
                 ern(Args, ErrorDevice)
             catch
                 Class:Error:Trace ->
                     host_end(),
                     %% the host's text of the exception, which may end in a
                     %% line break or not, ends the line
                     Text = erl_error:format_exception(Class, Error, Trace),
                     io:format(ErrorDevice, "ern: internal error: ~ts~n",
                               [string:trim(Text, trailing)]),
                     70
             end,
    host_end(),
    Gone = case ern_rt:ended_at_once() of
               %% report §8.6: a termination once the run's end had begun
               %% ended it at once, and nothing more is written out
               true -> [];
               false -> written_out(ErrorDevice)
           end,
    %% report §8.6, §11, Appendix E.18: the job halts without the host's
    %% flush, which waits for every port to write what it holds, a
    %% socket's among them, without a limit where the socket's far end
    %% takes nothing; a socket's bytes are sent until the runtime stops,
    %% and the stop is their bound. The job's own output is carried by its
    %% own code instead: its streams written out above, and a stream that
    %% is stopped writing out what its port holds (ern_rt)
    case {ern_signals:ended(), Gone} of
        {none, []} -> halt(Status, [{flush, false}]);
        {none, [Stream | _]} -> ern_out:end_job(Stream);
        {Signal, _} -> ern_signals:die(Signal, Status)
    end.

%% Report §12.5, §11.2: the lines a node's gateway or its checks said since
%% its last launch's end written before the job ends. Report §11.8: then
%% the job's streams written out, whatever ends it, so that what it said
%% last, a shell's line of its end among it, is not lost to the signal it
%% sends itself; the signal that ended the program stands over a stream
%% found gone as the end waited (§8.6). The streams found gone.
written_out(ErrorDevice) ->
    ok = ern_rt:wait_for_later(),
    ern_out:finish(ErrorDevice).

%% Report §12.5, §11.8: a node's dial from a full table of processes ends
%% the host, which writes its line and exits with status 1 once its kernel
%% has ended, since the host's process of connections and each supervisor
%% above it is permanent, restarted by none. From the moment that process
%% has ended (said_otherwise/2), the job waits for the host's end: it ends
%% with no status of its own, and reports nothing it meets meanwhile, a
%% process of the host's gone among it.
host_end() ->
    case persistent_term:get({?MODULE, host_ends}, false) of
        true -> receive after infinity -> ok end;
        false -> ok
    end.

%% Report §12.5: the launcher's first start of the host, where its arguments
%% hold `--config-dir`, since the host takes a node's carrier only as it
%% boots. The command line is parsed as its job parses it, and the flags a
%% node's host boots with are written to standard output as shell words on
%% one line, after the marker `ern-node-flags`; none are written where the
%% command starts no node or is refused, which the launcher's second start
%% then says. Nothing the job would write reaches standard output, which
%% carries the flags alone, nor anything the host logs: the host's log
%% handler, which writes on standard output, is the job's own first
%% (ern_out:logged/0), which writes on the job's standard error.
-spec node_flags() -> no_return().
node_flags() ->
    ok = ern_out:logged(),
    Out = group_leader(),
    %% the job's text is written to it in UTF-8, as its devices write it. A
    %% regression: one of the host's default, Latin-1, raised at a
    %% `--verbose` line naming a path beyond it, and the node was given no
    %% flags (report §11.2)
    {ok, Null} = file:open("/dev/null", [write, {encoding, utf8}]),
    group_leader(Null, self()),
    persistent_term:put({?MODULE, flags}, true),
    Args = init:get_plain_arguments(),
    %% the launcher starts this only for a job that makes a node (bin/ern),
    %% since every other job's work, `ern config`'s among it, is the second
    %% start's
    Flags = try ern(Args, Null) of
                _ -> []
            catch
                throw:{node_flags, Found} -> Found;
                _:_ -> []
            end,
    io:put_chars(Out, ["ern-node-flags " | lists:join(" ", [shell_quoted(Flag) || Flag <- Flags])]),
    halt(0, [{flush, false}]).

%% A word as the shell reads it back, in single quotes.
shell_quoted(Word) ->
    ["'", string:replace(Word, "'", "'\\''", all), "'"].

-spec ern([word()]) -> 0..255.
ern(Args) ->
    ern(Args, standard_error).

%% Report §11: the first word is the job, and --help and --version stand
%% alone; a working directory whose name is not UTF-8 the launcher refused
%% before the host started. ErrorDevice is the error device, ern_out's
%% for the launcher (start/0); a test passes its own and reads what the
%% user would see. The status is 0 or 1, or a program's, which Os.exit
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
    refuse(jobs_help("a job is required"), ErrorDevice);
ern([Word | Args], ErrorDevice) ->
    case {is_utf8(Word), lists:keyfind(Word, 1, jobs())} of
        {false, _} -> refuse(not_utf8(Word), ErrorDevice);
        {true, {Word, Spec, Positional, Work}} ->
            job(Word, Spec, Positional, Args, Work, ErrorDevice);
        {true, false} -> refuse(no_job(Word), ErrorDevice)
    end;
ern([], ErrorDevice) ->
    refuse(jobs_help("a job is required"), ErrorDevice).

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
     {"stop", signal_options("the node that ends"), "", fun stop/3},
     {"unpack", [verbose_option(), help_option()], "", fun unpack/3}].

%% Report §11: a first word that is no job, refused with the jobs named
%% and `ern --help`, which describes them; an option a job takes, given
%% before it, is refused with where it goes, and the help named after it.
no_job("--help") -> "--help stands alone: ern --help, or ern <job> --help";
no_job("--version") -> jobs_help("--version stands alone: ern --version");
no_job("-" ++ _ = Word) ->
    Name = option_name(Word),
    Taken = [Job || {Job, Spec, _, _} <- jobs(), {_, _, Long, _, _} <- Spec, "--" ++ Long =:= Name],
    case Taken of
        [] -> no_such_job(Word);
        _ -> jobs_help(Name ++ " comes after the job: ern <job> " ++ Name)
    end;
no_job(Word) ->
    case filename:extension(Word) of
        ".erc" -> jobs_help("the job comes first: ern run " ++ Word);
        _ -> no_such_job(Word)
    end.

%% Report §11: a refusal of the form of a command line before a job is read
%% ends by naming the help that describes the jobs.
jobs_help(Refusal) ->
    Refusal ++ "; ern --help describes the jobs".

no_such_job(Word) ->
    "no job " ++ Word ++ "; the jobs are build, doc, format, run, test, shell, config, reload,"
        " stop and unpack; ern --help describes them".

%% An option's whole name, before any `=`.
option_name(Word) ->
    lists:takewhile(fun(Char) -> Char =/= $= end, Word).

%% An option's name as the command line writes it, `--load-path`, by its
%% key in the job's Spec.
long_name(Spec, Key) ->
    hd(["--" ++ Long || {Taken, _, Long, _, _} <- Spec, Taken =:= Key]).

%% Report §11: a refusal before a job, its text holding no control
%% character (ern_build:control_free/1), and nothing after it.
refuse(Message, ErrorDevice) ->
    io:format(ErrorDevice, "ern: ~ts~n", [ern_build:control_free(Message)]),
    1.

usage(Device) ->
    io:format(Device, "Usage: ern <job> [options] ...~n~n"
              "  build   compile a module, or every module under a directory~n"
              "  doc     write the documentation of a module or a directory~n"
              "  format  lay out modules in the language's one layout~n"
              "  run     run a program~n"
              "  test    run the tests of a module, or of every module under a directory~n"
              "  shell   run an interactive shell~n"
              "  config  create the configuration directory, or list a peer in it~n"
              "  reload  have a running node read its configuration again~n"
              "  stop    end a running node~n"
              "  unpack  unpack the archives of the packages a manifest names~n~n"
              "ern <job> --help lists a job's options; ern --version prints the version.~n",
              []).

%% Run a job with its options parsed by getopt. --help prints and stops
%% with status 0; a refusal of the form of the command line prints its
%% message and names the job's help (usage_fail/1), and any other refusal
%% its message, each one line on ErrorDevice with status 1 (report §11).
job(Job, Spec, Positional, Args, Work, ErrorDevice) ->
    %% report §12.5, §11.2: the job's own standard error, where a line of the
    %% toolchain's own goes while no launch's takes it (ern_job_line)
    ern_job_line:set_error_device(ErrorDevice),
    %% report §11: the host's report of an outcome said otherwise, which the
    %% program sees as a value or a fault or the job says in a line of its
    %% own, is not written, nor what the host logs as it ends the job, in
    %% every job (said_otherwise/2)
    _ = logger:add_primary_filter(?MODULE, {fun ?MODULE:said_otherwise/2, []}),
    Name = "ern " ++ Job,
    {Own, Program} = case Job of
                         "run" -> program_words(Spec, Args, []);
                         _ -> {Args, []}
                     end,
    try
        lists:foreach(fun(Word) -> is_utf8(Word) orelse ern_build:fail(not_utf8(Word)) end, Own),
        %% report §11: `--` ends a job's options, and a word after it is
        %% none, whatever it is spelled
        lists:foreach(fun(Word) -> one_spelling(Word, Spec) end,
                      lists:takewhile(fun(Word) -> Word =/= "--" end, Own)),
        {Options, Rest} = case getopt:parse(Spec, Own) of
                              {ok, Parsed} -> Parsed;
                              {error, {Reason, Data}} -> parse_refused(Job, Spec, Reason, Data)
                          end,
        %% report §11: `--help` stands alone after the job as before it,
        %% the refusal naming the help itself
        case {lists:member(help, Options), Options ++ Rest ++ Program} of
            {true, [help]} -> job_usage(Spec, Name, Positional, standard_io), 0;
            {true, _} -> ern_build:fail("--help stands alone: " ++ Name ++ " --help");
            {false, _} ->
                given_once(Options, Spec),
                Resolved = [resolved_option(Option) || Option <- Options],
                named_directories(Job, Spec, Resolved),
                Arguments = resolved_arguments(Job, Rest),
                counted(Job, Resolved, Arguments),
                Work(root_package(Job, Resolved, Arguments), Arguments ++ Program, ErrorDevice)
        end
    catch
        throw:{cli_usage, Usage} ->
            io:format(ErrorDevice, "~s: ~ts; ~s --help describes the job~n", [Name, Usage, Name]),
            1;
        throw:{cli_error, Refusal} ->
            io:format(ErrorDevice, "~s: ~ts~n", [Name, Refusal]),
            1;
        %% report §11.9: every fault of a root package, a line each
        throw:{cli_errors, Refusals} ->
            [io:format(ErrorDevice, "~s: ~ts~n", [Name, Refusal]) || Refusal <- Refusals],
            1
    end.

%% Report §11, §11.9: the count of a job's arguments, refused with the
%% rest of its command line, before its root package is read, so that a
%% job that refuses it says no refusal of its root package; the words
%% after `ern run`'s file are the program's, and are not counted. An
%% attached shell's file is refused with `--attach` (attachable/2), and so
%% is its `--main`. Report §8.1, §11.2: `--main` names a function of the
%% file, so it is refused where none is given, and a bare node has no
%% entry point.
counted(Job, Options, Arguments) ->
    case {Job, Arguments} of
        {"build", [_]} -> ok;
        {"doc", [_]} -> ok;
        {"test", [_]} -> ok;
        {Taken, _} when Taken =:= "build"; Taken =:= "doc" ->
            usage_fail(one_argument("a file or a directory", "one file or directory", Arguments));
        {"test", _} ->
            usage_fail(one_argument("a .erc or a directory", "one .erc or directory", Arguments));
        {"shell", [_, _ | _]} ->
            lists:keymember(attach, 1, Options)
                orelse usage_fail(too_many("one .erc or none", Arguments)),
            ok;
        {"shell", []} ->
            lists:keymember(attach, 1, Options) orelse not lists:keymember(main, 1, Options)
                orelse usage_fail(no_main_file(shell)),
            ok;
        {"unpack", [_ | _]} ->
            usage_fail(none_taken(Arguments));
        {"run", []} ->
            %% report §11.2: `--config-dir` makes a run a node, and a node
            %% with no `.erc` is a bare node; a run that is no node runs a
            %% program
            is_node(Options)
                orelse usage_fail("a .erc is required, or --config-dir for a bare node"),
            not lists:keymember(main, 1, Options) orelse usage_fail(no_main_file(run)),
            ok;
        _ ->
            ok
    end.

%% Report §11, §11.9: the job's options, with its root package where it
%% reads one: the directory `--package-dir` names, which holds a manifest,
%% or else the working directory where it holds one and the job's
%% arguments lie under it, none naming a path outside; an attached shell
%% reads none. The look for the manifest's name follows no link, and is
%% all a job pays where there is none.
root_package(Job, Options, Arguments) ->
    case {reads_manifest(Job), lists:keymember(attach, 1, Options),
          proplists:get_value(package_dir, Options)} of
        {false, _, _} ->
            Options;
        {true, true, _} ->
            Options;
        {true, false, undefined} ->
            case lists:all(fun(Path) -> filename:pathtype(Path) =/= absolute end, Arguments) of
                true -> packaged(Options, ".", working_directory, Job, Arguments);
                false -> Options
            end;
        {true, false, Dir} ->
            packaged(Options, Dir, package_dir, Job, Arguments)
    end.

%% Report §11.9: the jobs that read a manifest. What each takes of it is
%% the package's (ern_package:read/4).
reads_manifest(Job) ->
    lists:member(Job, ["build", "doc", "run", "test", "shell", "unpack"]).

%% Report §11.9: Options with the root package Dir, Place being the
%% `working_directory` or the `package_dir` `--package-dir` names, read
%% where Dir holds the name `package.conf`, whatever it reaches, by the job
%% Job given the paths Arguments, its `--build-root` and its `--doc-root`:
%% the package's directory, whose `src` and `build` are default roots
%% (§11.1, §11.2), its own `ebin` where the job runs code and it is there,
%% its named packages, as the load path holds them (ern_build:load_path/1),
%% under `ern build` the order it builds them in, under `ern unpack` the
%% entries with their `url` and their `sha256`, and, where `--verbose`
%% asks, what it says of them, as data, since the build, which is in the
%% compiler's hash, calls no module of the package's
%% (ern_build:load_path/1). A Dir `--package-dir` names that holds none is
%% refused, and so is one whose name cannot be looked for.
packaged(Options, Dir, Place, Job, Arguments) ->
    Manifest = filename:join(Dir, "package.conf"),
    case {file:read_link_info(Manifest, [raw]), Place} of
        {{ok, _}, _} ->
            Given = [{argument, Path} || Path <- Arguments]
                ++ [{Key, Path} || {Key, Path} <- Options,
                                   Key =:= build_root orelse Key =:= doc_root],
            Package = ern_package:read(Dir, Place, Job, Given),
            Root = ern_build:absolute(Dir),
            Options ++ [{root_package, Root}]
                ++ [{root_ebin, Ebin} || lists:member(Job, ["run", "test", "shell"]),
                                         Ebin <- [filename:join(Root, "ebin")],
                                         filelib:is_dir(Ebin)]
                ++ [{named_package, Named} || Named <- ern_package:packages(Package)]
                ++ [{package_order, Order} || Order <- [ern_package:built_order(Package)],
                                              Order =/= []]
                ++ [{package_entry, Entry} || Job =:= "unpack",
                                              Entry <- ern_package:entries(Package)]
                ++ [{package_said, Line} || lists:member(verbose, Options),
                                            Line <- ern_package:said(Package)];
        {{error, enoent}, working_directory} ->
            Options;
        {{error, Error}, _} ->
            ern_build:refused(Manifest, Error)
    end.

%% Report §11, §11.7: the option parser's refusal in the usage's words: an
%% option given no value with its metavariable, and one the job does not
%% take with the jobs that take it, which names them in place of the help.
-spec parse_refused(string(), [getopt:option_spec()], atom(), term()) -> no_return().
parse_refused(_Job, Spec, missing_option_arg, Key) ->
    Long = long_name(Spec, Key),
    usage_fail(Long ++ " takes a value: " ++ Long ++ " " ++ metavariable(Key));
parse_refused(Job, _Spec, invalid_option, Word) ->
    Name = option_name(Word),
    Refused = Name ++ " is not an option of ern " ++ Job,
    case [Other || {Other, Spec, _, _} <- jobs(), Other =/= Job,
                   lists:any(fun({_, _, Long, _, _}) -> "--" ++ Long =:= Name end, Spec)] of
        [] -> usage_fail(Refused);
        [Other] -> ern_build:fail(Refused ++ "; ern " ++ Other ++ " takes it");
        Others ->
            ern_build:fail(Refused ++ "; " ++ listed(["ern " ++ Other || Other <- Others])
                           ++ " take it")
    end.

%% Words in a sentence, the last after `and`.
listed([Word]) -> Word;
listed(Words) -> lists:join(", ", lists:droplast(Words)) ++ " and " ++ lists:last(Words).

%% Report §11: each path the command line gives, a job's argument or the
%% value of an option that names a file or a directory, is resolved once,
%% here, and the job judges, writes and opens it as resolved, and a refusal
%% names it so. A word after `ern run`'s file is the program's, and is no
%% path; `ern format`'s `-` is standard input, which a file named `-`,
%% `./-`, is not. An option's empty value is refused before (given_once/2).
resolved_option({Key, Path}) when Key =:= source_root; Key =:= build_root; Key =:= doc_root;
                                  Key =:= load_path; Key =:= libs_dir; Key =:= package_dir;
                                  Key =:= config_dir; Key =:= peer_dir ->
    {Key, resolved_path(Path)};
resolved_option(Option) ->
    Option.

resolved_arguments("format", Words) ->
    [case Word of
         "-" -> standard_input;
         _ -> resolved_path(Word)
     end || Word <- Words];
resolved_arguments(_Job, Words) ->
    [resolved_path(Word) || Word <- Words].

%% Report §11, §11.5: a path absolute from the working directory, its `.`
%% and `..` segments resolved without following a link (ern_build:absolute/1),
%% written from the working directory where it lies under it, and absolute
%% otherwise. The host opens it as resolved, since no `..` is left in it to
%% climb back out of a link. An empty word names nothing and stays empty,
%% refused as a path that names nothing is, and not taken for the working
%% directory.
resolved_path("") ->
    "";
resolved_path(Path) ->
    ern_build:shown(Path).

%% Report §11.7: an option that names a directory to read names one that is
%% there, and one that is a directory; `ern config`'s `--config-dir` names
%% the one it creates or reads the key of, which ern_node:create/2 judges,
%% but with `--peer-dir`, which writes into it; and `--peer-dir` names a
%% configuration directory, which holds `ernest.conf` and its certificate.
named_directories(Job, Spec, Options) ->
    Creates = Job =:= "config" andalso not lists:keymember(peer_dir, 1, Options),
    lists:foreach(fun({Key, Directory}) when Key =:= load_path; Key =:= libs_dir;
                                            Key =:= package_dir; Key =:= source_root;
                                            Key =:= config_dir andalso not Creates ->
                          Named = ", which " ++ long_name(Spec, Key) ++ " names",
                          case {filelib:is_dir(Directory), filelib:is_file(Directory)} of
                              {true, _} -> ok;
                              {false, true} -> ern_build:fail(Directory ++ ": not a directory"
                                                              ++ Named);
                              {false, false} -> no_such_directory(Directory, Named)
                          end;
                     ({peer_dir, Directory}) ->
                          %% report §11.7: one that names nothing is refused as a
                          %% --load-path is
                          filelib:is_file(Directory)
                              orelse no_such_directory(Directory, ", which --peer-dir names"),
                          lists:all(fun filelib:is_regular/1,
                                    [ern_node:file(Directory, conf),
                                     ern_node:file(Directory, certificate)])
                              orelse ern_build:fail(Directory ++ ": no configuration directory,"
                                                    " which --peer-dir names");
                     (_) ->
                          ok
                  end, Options).

%% Report §11, §11.7: a directory an option names that names nothing, in
%% the host's words for a missing path, and the option.
-spec no_such_directory(string(), string()) -> no_return().
no_such_directory(Directory, Named) ->
    ern_build:fail(Directory ++ ": " ++ file:format_error(enoent) ++ Named).

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
    case [Option || Option <- lists:usort(Keys), Option =/= load_path,
                    length([Other || Other <- Keys, Other =:= Option]) > 1] of
        [] -> ok;
        [Option | _] -> usage_fail(long_name(Spec, Option) ++ " is given more than once")
    end,
    case [Option || {Option, ""} <- Options] of
        [] -> ok;
        [Empty | _] -> usage_fail(long_name(Spec, Empty) ++ " is given an empty value")
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
metavariable(doc_root) -> "doc-root";
metavariable(load_path) -> "dir";
metavariable(libs_dir) -> "dir";
metavariable(package_dir) -> "dir";
metavariable(config_dir) -> "dir";
metavariable(listen) -> "address:port";
metavariable(peer_dir) -> "dir";
metavariable(main) -> "name";
metavariable(attach) -> "name".

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
      " directory, or src-dir, or the root package's src for a path under it"},
     {build_root, undefined, "build-root", string,
      "where the compiled tree goes; default: the source root, or the root"
      " package's build where that is its src"},
     {load_path, undefined, "load-path", string,
      "a root of compiled modules a module may use; may be repeated"},
     {emit_erl, undefined, "emit-erl", undefined,
      "write the module's Erlang source instead of .erc"},
     verbose_option(),
     help_option()].

%% Report §11.4, §11.7: `ern doc` takes the build's options but
%% `--emit-erl`, which is the build's alone; its `--build-root` is where a
%% current `.erc` is read from, and its own `--doc-root` where the
%% documents go, the build root where it is not given.
doc_options() ->
    [{man, undefined, "man", undefined, "write manual pages in roff instead of CommonMark"}
     | lists:append(
         [case Key of
              build_root ->
                  [{build_root, undefined, "build-root", string,
                    "where a current .erc is read from; default: the source root, or the root"
                    " package's build where that is its src"},
                   {doc_root, undefined, "doc-root", string,
                    "where the documents or the pages go; default: the build root"}];
              _ ->
                  [Option]
          end || {Key, _, _, _, _} = Option <- build_options(), Key =/= emit_erl])].

build(Options, [Path], ErrorDevice) ->
    ern_build:compile("ern build", Options, Path, ErrorDevice).

%% Report §11: the refusal of a job's words that are not the one it takes:
%% none, which names what is required, or several, which counts them.
one_argument(Required, _One, []) ->
    Required ++ " is required";
one_argument(_Required, One, Rest) ->
    too_many(One, Rest).

too_many(One, Rest) ->
    io_lib:format("~s is taken, and ~B were given", [One, length(Rest)]).

%% Report §11: the refusal of the words given to a job that takes none.
none_taken([_]) ->
    "no argument is taken, and 1 was given";
none_taken(Rest) ->
    io_lib:format("no argument is taken, and ~B were given", [length(Rest)]).

%% Report §11.4: a file's documentation to stdout, a directory's into the
%% doc root, one document per module and an index, or with --man one manual
%% page per module and no index.
doc(Options, [Path], ErrorDevice) ->
    try doc_path(Options, Path, ErrorDevice)
    catch
        throw:{ended, Status} -> Status
    end.

doc_path(Options, Path, ErrorDevice) ->
    case ern_build:path_kind(Path) of
        directory ->
            doc_dir(Options, Path, ErrorDevice);
        regular ->
            case beam_of(Options, Path, ErrorDevice) of
                {ok, Beam} ->
                    io:put_chars(page(Options, Beam, source_named(Path, Beam), ErrorDevice)),
                    0;
                {failed, Status} ->
                    Status
            end;
        Kind ->
            ern_build:given_refused(Path, Kind)
    end.

%% Report §11.4, §11.5: the source a page names, from the working
%% directory: the source given, or for a `.erc` the one its interface chunk
%% records, from its build root, which lies as many directories up as its
%% namespace is deep.
source_named(Path, Beam) ->
    case {filename:extension(Path), ern_interface:read(Beam)} of
        {".erc", {ok, #{interface := #interface{namespace = Namespace},
                        source_path := SourcePath}}} ->
            BuildRoot = ern_build:root_of(ern_build:absolute(Path), Namespace),
            ern_build:shown(filename:join(BuildRoot, unicode:characters_to_list(SourcePath)));
        _ ->
            ern_build:shown(Path)
    end.

%% Report §11.4: the documentation comes from the compiled module. A `.erc`
%% is read; a source is compiled first, in memory, as a directory's is, so
%% that asking for a page writes nothing, and a module that fails is
%% reported as a build reports it, and its status answered. Under --verbose
%% the `.erc`'s branch says the root package and the module read (§11.9),
%% and the source's compile says the source root, the build root, the root
%% package and each module read or compiled (ern_build:compile_in_memory/5).
%% A file that is neither is refused for both.
beam_of(Options, Path, ErrorDevice) ->
    lists:member(filename:extension(Path), [".ern", ".erc"])
        orelse ern_build:fail(ern_build:shown(Path) ++ " ends in neither .ern nor .erc"),
    case filename:extension(Path) of
        ".erc" ->
            Say = ern_build:verbose(Options, ErrorDevice),
            ern_build:package_said(Options, Say),
            Compiled = compiled(Path),
            %% both chunks a page is built from, so that a module whose
            %% chunks are not the compiler's is refused and no page begun
            case {ern_docs:read(Compiled), ern_interface:read(Compiled)} of
                {{ok, _}, {ok, #{interface := #interface{namespace = Namespace}}}} ->
                    Say(["read ", ern_namespace:text(Namespace), " from ",
                         ern_build:shown(Path)]),
                    {ok, Compiled};
                {{error, Error}, _} -> ern_build:fail(Path ++ ": " ++ Error);
                {_, {error, Error}} -> ern_build:fail(Path ++ ": " ++ Error)
            end;
        _ ->
            case ern_build:compile_in_memory("ern doc", Options, Path, ErrorDevice,
                                             fun(_) -> #{} end) of
                {0, Compiled} ->
                    [Beam] = maps:values(Compiled),
                    {ok, Beam};
                {Status, _} ->
                    {failed, Status}
            end
    end.

%% Report §11.4: a module's page, in CommonMark or with --man as a manual
%% page, naming its source, Source.
page(Options, Beam, Source, ErrorDevice) ->
    case lists:member(man, Options) of
        true -> in_runtime(fun() -> ern_page:manual(Beam, Source) end, ErrorDevice);
        false -> ern_page:page(Beam, Source)
    end.

%% Report §11.4, §8.5: a manual page is laid out by libs/markdown, whose code
%% runs as a program's does, in a started runtime, the standard library's
%% top-level bindings and the library's evaluated first, so that a function
%% that reads one finds its value. What Compute gives is passed back to the
%% job, which writes it. A fault there is reported as a run's is, its cause
%% and its trace whole on standard error (§11.2), and is then a failure of
%% ern itself; a signal ends the job as it ends a run, also where it cut
%% short an end begun by Compute's return (§11.8).
%%
%% Compute is the job's own code, which calls libs/markdown as foreign code
%% calls a program's (§8.4); where it waits, the prelude's page reading the
%% standard library's interfaces, it waits on the host's code server and
%% file server, whose functions the deadlock detector reads on top of the
%% process's stack as the host's work (§8.6).
in_runtime(Compute, ErrorDevice) ->
    Caller = self(),
    Ref = make_ref(),
    Options = reporting_options(#{init => fun() -> ern_rt:init_modules(['ern@markdown']) end},
                                ErrorDevice),
    Outcome = ern_rt:run_main(fun() -> Caller ! {Ref, Compute()} end, <<"ern doc">>, Options),
    case {Outcome, ern_signals:taken()} of
        {ok, none} -> receive {Ref, Result} -> Result end;
        {ok, Signal} -> throw({ended, ern_signals:ended(Signal)});
        {{signal, Signal}, _} -> throw({ended, ern_signals:ended(Signal)});
        _ -> erlang:error({libs_markdown, Outcome})
    end.

%% Report §11.4: a directory's documents, or with --man its manual pages,
%% each written under the doc root where it is not current. A page is made
%% from its module compiled, so that every page is of a module that
%% type-checks: a module whose .erc in build-root is as new as its source is
%% read from it, wherever the pages go, and the rest are compiled as `ern
%% build` compiles them, writing nothing.
%% Where every page is current, nothing is compiled, but where a module
%% hides a library's, which the build tests by the job's reach (§11.1,
%% §4.2). A file whose path is no module's fails as a module that does not
%% compile does (§11.1), whose page is never current.
%%
%% A module that fails does not stop the others, as in `ern build`: the
%% compiled modules are those that neither failed nor use one that failed,
%% each failure reported as the build reports it, and a page is written of
%% a compiled module alone, the prelude's being no module's. A page of a
%% module that failed is left as it is, and the index lists it.
doc_dir(Options, Path, ErrorDevice) ->
    SourceRoot = ern_build:source_root(Options, Path, Path),
    BuildRoot = ern_build:build_root(Options, SourceRoot),
    DocRoot = ern_build:doc_root(Options, BuildRoot),
    %% the modules by their files and namespaces, which is all that tells
    %% whether a page is current, so no source is parsed to tell it
    Sources = ern_build:sources(Path),
    {Unsorted, Misnamed} = ern_build:modules_of(Sources, SourceRoot, tree,
                                                ern_build:load_path(Options)),
    Modules = lists:sort(Unsorted),
    IsStdlib = ern_build:is_stdlib_root(SourceRoot),
    Kind = case lists:member(man, Options) of
               true -> man;
               false -> markdown
           end,
    no_index_module(Kind, Modules),
    %% report §11.4: --verbose says each module read or compiled, and each
    %% document or page written or removed
    Say = ern_build:verbose(Options, ErrorDevice),
    Outdated = outdated(pages(Kind, Modules, IsStdlib, BuildRoot, DocRoot),
                        code_modified(Kind)),
    Libraries = ern_tree:libraries(),
    Hiding = [Module || #build_module{namespace = Namespace, file = File} = Module <- Modules,
                        ern_build:hidden_library(Namespace, File, Libraries) =/= none],
    {Status, Compiled} = case {Outdated, Misnamed, Hiding} of
                             {[], [], []} ->
                                 %% report §11.4: the roots and the root
                                 %% package said as a compile says them
                                 ern_build:started_said(Options, SourceRoot, BuildRoot,
                                                        Say),
                                 {0, #{}};
                             _ -> ern_build:compile_in_memory(
                                    "ern doc", Options, Path, ErrorDevice,
                                    fun(SaidRead) ->
                                        read_compiled(Modules, BuildRoot, SaidRead)
                                    end)
                         end,
    write_outdated(Kind, [{Output, Make} || {Output, Make, Of} <- Outdated,
                                            Of =:= prelude orelse is_map_key(Of, Compiled)],
                   Compiled, ErrorDevice, Say),
    %% report §11.4: the documents and pages of a module whose source is
    %% gone go, whichever a run writes, as the build's sweep takes its
    %% .erc, after a run in which every module compiled, each said with the
    %% flag or without
    Status =:= 0
        andalso ern_build:sweep_pages(Path, SourceRoot, DocRoot,
                                      [Namespace || #build_module{namespace = Namespace} <- Modules]
                                          ++ [['Prelude'] || IsStdlib],
                                      ern_build:saying(ErrorDevice)),
    write_index(Kind, directory_namespaces(Sources, SourceRoot), IsStdlib, DocRoot),
    Status.

%% Report §11.4: without --man, a module `Index` at the directory's root is
%% refused before anything is written, since its document would be the
%% listing's, index.md; `Net.Index`'s is `net/index.md`, and is none.
no_index_module(man, _Modules) ->
    ok;
no_index_module(markdown, Modules) ->
    case [File || #build_module{namespace = ['Index'], file = File} <- Modules] of
        [] -> ok;
        [File | _] ->
            ern_build:fail(ern_build:path_text(File) ++ ": the module Index's document would be"
                           " index.md, which lists the modules; ern doc --man writes its page")
    end.

%% Report §11.4, §11.1: the namespaces of the directory's modules, Sources,
%% in order, each source whose path is a module's, one that failed among
%% them; a path that breaks the shape is no module's.
directory_namespaces(Sources, SourceRoot) ->
    lists:usort([Namespace || Source <- Sources, Namespace <- namespace_of(Source, SourceRoot)]).

namespace_of(Source, SourceRoot) ->
    try ern_build:module_of(ern_build:absolute(ern_build:found_path(Source)), SourceRoot, tree) of
        #build_module{namespace = Namespace} -> [Namespace]
    catch
        throw:{cli_error, _} -> []
    end.

%% Report §11.4: each module's page, with what makes it from the compiled
%% modules, the times of what it is made from of its own, its .erc's in
%% BuildRoot among them, and whose it is, the module's namespace or
%% `prelude`: under DocRoot, in CommonMark at the place `ern build` writes
%% its .erc under BuildRoot, with `.md` for `.erc`, or a manual page in
%% that directory in a file named as `man` finds it,
%% `Ernest.Net.Http.3ern`. The standard library's own source root also has
%% the prelude's page, at the top of DocRoot, first in the index.
pages(markdown, Modules, IsStdlib, BuildRoot, DocRoot) ->
    [{filename:join(DocRoot, "prelude.md"), fun(_) -> ern_page:prelude_page() end, [], prelude}
     || IsStdlib]
        ++ [{filename:join(DocRoot, ern_namespace:module_path(Namespace) ++ ".md"),
             fun(Compiled) -> ern_page:page(maps:get(Namespace, Compiled), ern_build:shown(File))
             end,
             module_modified(Module, BuildRoot), Namespace}
            || #build_module{namespace = Namespace, file = File} = Module <- Modules];
pages(man, Modules, IsStdlib, BuildRoot, DocRoot) ->
    [{man_page(DocRoot, Namespace),
      fun(Compiled) -> ern_page:manual(maps:get(Namespace, Compiled), ern_build:shown(File)) end,
      module_modified(Module, BuildRoot), Namespace}
     || #build_module{namespace = Namespace, file = File} = Module <- Modules]
        ++ [{filename:join(DocRoot, "Ernest.Prelude.3ern"),
             fun(_) -> ern_page:prelude_manual() end, [], prelude}
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
%% (§11.1). Say says each module read.
read_compiled(Modules, BuildRoot, Say) ->
    Read = [{Namespace, Erc, Beam}
            || #build_module{namespace = Namespace, file = File} = Module <- Modules,
               Erc <- [erc_of(Module, BuildRoot)],
               {ok, Time} <- [modified(File)],
               is_current(Erc, [Time]),
               Beam <- [ern_build:read(Erc)],
               is_compiled_from(Beam, Namespace, File, BuildRoot)],
    [Say(["read ", ern_namespace:text(Namespace), " from ", ern_build:shown(Erc)])
     || {Namespace, Erc, _} <- Read],
    maps:from_list([{Namespace, Beam} || {Namespace, _, Beam} <- Read]).

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
write_outdated(_Kind, [], _Compiled, _ErrorDevice, _Say) ->
    ok;
write_outdated(markdown, Outdated, Compiled, _ErrorDevice, Say) ->
    write_pages([{Output, Make(Compiled)} || {Output, Make} <- Outdated], Say);
write_outdated(man, Outdated, Compiled, ErrorDevice, Say) ->
    LaidOut = fun() -> [{Output, Make(Compiled)} || {Output, Make} <- Outdated] end,
    write_pages(in_runtime(LaidOut, ErrorDevice), Say).

%% Report §11.4: index.md, listing each of the modules of Namespaces whose
%% document stands, the prelude first in the standard library's own build
%% root, written where its text would differ from the one there and left
%% as it is otherwise: a module that failed is listed where its document
%% stands from an earlier run, and a run of `--man`, which writes no
%% document, lists none the sweep removed. A run of `--man` writes it only
%% where it is there. What stands at its place or a document's and is no
%% regular file itself, a link among them, is none (§11.4): at the index's
%% place it is not opened, and a run of `--man` leaves it, and any other
%% run replaces it.
write_index(Kind, Namespaces, IsStdlib, DocRoot) ->
    Index = filename:join(DocRoot, "index.md"),
    Listed = [{Name, Document}
              || {Name, Document} <- [{"Prelude", "prelude.md"} || IsStdlib]
                     ++ [{ern_namespace:text(Namespace),
                          ern_namespace:module_path(Namespace) ++ ".md"}
                         || Namespace <- Namespaces],
                 is_regular_file(filename:join(DocRoot, Document))],
    Text = unicode:characters_to_binary(["# Modules\n\n",
                                         [["- [", Name, "](", Document, ")\n"]
                                          || {Name, Document} <- Listed]]),
    There = case file:read_link_info(Index) of
                {ok, #file_info{type = regular}} -> file:read_file(Index);
                _ -> none
            end,
    case {Kind, There} of
        {_, {ok, Text}} -> ok;
        {man, none} -> ok;
        _ -> ern_build:write_output(Index, Text)
    end.

%% A module's manual page, under DocRoot in the directory its .erc has
%% under the build root.
man_page(DocRoot, Namespace) ->
    Directory = filename:dirname(filename:join(DocRoot, ern_namespace:module_path(Namespace))),
    filename:join(Directory, "Ernest." ++ ern_namespace:text(Namespace) ++ ".3ern").

%% Each page written to its file whole, as UTF-8, and said by Say.
write_pages(Pages, Say) ->
    lists:foreach(fun({Output, Page}) ->
                      ok = ern_build:make_dirs(Output),
                      ok = ern_build:write_output(Output, unicode:characters_to_binary(Page)),
                      Say(["wrote ", ern_build:shown(Output)])
                  end, Pages).

%% Report §11.4: each page of Pages that is not current, with what makes
%% it and whose it is. A page is current where its file is there and is as
%% new as all it is made from: its module's own files, whose times Pages
%% gives, and the code that makes every page, whose times Code gives. A
%% link or anything else at the file's place is no page, and is replaced,
%% as ern_build:write_output/2 replaces it. The times are compared as make
%% compares them, to the second the host gives.
outdated(Pages, Code) ->
    [{Output, Make, Of} || {Output, Make, Times, Of} <- Pages,
                           not is_current(Output, Code ++ Times)].

is_current(Page, Times) ->
    case file:read_link_info(Page, [{time, posix}]) of
        {ok, #file_info{type = regular, mtime = Written}} ->
            lists:all(fun(Time) -> Time =< Written end, Times);
        _ ->
            false
    end.

%% Report §11.4: whether a regular file stands at File itself, a link
%% followed by none.
is_regular_file(File) ->
    case file:read_link_info(File) of
        {ok, #file_info{type = regular}} -> true;
        _ -> false
    end.

%% Report §11.4: the times of what a module's page is made from of its
%% own: its source, and its .erc where `ern build` has written one in
%% BuildRoot.
module_modified(#build_module{file = File} = Module, BuildRoot) ->
    [Time || Input <- [File, erc_of(Module, BuildRoot)], {ok, Time} <- [modified(Input)]].

%% Report §11.1: where `ern build` writes a module's .erc in BuildRoot.
erc_of(#build_module{relative = Relative}, BuildRoot) ->
    filename:join(BuildRoot, filename:rootname(Relative)) ++ ".erc".

%% Report §11.4: the newest time of the toolchain's own code, of the tree it
%% runs from, the checkout or an installation (ern_tree:own_code/0).
toolchain_modified() ->
    lists:max([Time || Beam <- ern_tree:own_code(), {ok, Time} <- [modified(Beam)]]).

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

%%
%% ern format, report §11.6
%%

format_options() ->
    [{check, undefined, "check", undefined,
      "name the modules not laid out, and change none"},
     verbose_option(), help_option()].

%% Report §11.6: each module named, and every module under each directory
%% named, laid out in place; with --check, each one not laid out named on
%% standard output and none changed, the status 1 when there was one; with
%% `-`, standard input laid out onto standard output (resolved_arguments/2);
%% with --verbose, each module written back said on standard error,
%% `formatted src/x.ern`. A module that does not parse is left as it is and
%% its diagnostic written, the status 1.
format(Options, [standard_input], ErrorDevice) ->
    Text = read_input(open_input(), []),
    case ern_format:format(Text) of
        {ok, Text} -> format_result(Options, Text, same);
        {ok, Output} -> format_result(Options, Output, changed);
        %% report §11.6: a module that does not parse is written back as
        %% it is, since standard output stands for the file it came from
        {error, Diagnostic} ->
            io:format(ErrorDevice, "~ts~n", [ern_diagnostic:format("-", Text, Diagnostic)]),
            lists:member(check, Options) orelse io:put_chars(Text),
            1
    end;
format(_Options, [], _ErrorDevice) ->
    usage_fail("a file, a directory or - is required");
format(Options, Paths, ErrorDevice) ->
    %% report §11.6: `-` reads standard input, and stands alone
    lists:member(standard_input, Paths) andalso usage_fail("- stands alone, for standard input"),
    lists:foreach(fun(Path) ->
                      Kind = ern_build:path_kind(Path),
                      Kind =:= regular orelse Kind =:= directory
                          orelse ern_build:given_refused(Path, Kind)
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
        true -> [{ern_build:found_path(File), Path} || File <- ern_build:sources(Path)];
        false -> [{Path, none}]
    end.

%% Report §11.6, §11.1: a file laid out where it is a module, and refused
%% where it is none, which fails that file alone, the rest laid out; so is
%% a file the job cannot read, named alone or found under a directory, and
%% report §11: one that reaches no regular file is one the job cannot read
%% (ern_build:read/1).
format_named(Options, File, Directory, ErrorDevice) ->
    try
        shaped(File, Directory),
        ern_build:read(File)
    of
        Text -> format_file(Options, File, Text, ErrorDevice)
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

format_file(Options, File, Text, ErrorDevice) ->
    case ern_format:format(Text) of
        {ok, Text} -> ok;
        {ok, Output} ->
            case lists:member(check, Options) of
                true -> io:format("~ts~n", [ern_build:path_text(File)]), changed;
                false ->
                    ok = ern_build:write_whole(File, Output),
                    Say = ern_build:verbose(Options, ErrorDevice),
                    Say(["formatted ", ern_build:path_text(File)])
            end;
        {error, Diagnostic} ->
            io:format(ErrorDevice, "~ts~n",
                      [ern_diagnostic:format(ern_build:path_text(File), Text, Diagnostic)]),
            error
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

%% Report §11.9: the root package, whose manifest the job reads, named in
%% place of the directory the job is started in.
package_dir_option() ->
    {package_dir, undefined, "package-dir", string,
     "the root package, whose manifest the job reads in place of the working directory's"}.

%% Report §11.2: --main of `ern run` names the entry point, and of `ern
%% shell` the function spawned beside the shell, the shell being the entry
%% point.
main_option(What) ->
    {main, undefined, "main", string, What}.

%% Report §11.1, §11.2: what the job decided, a line each on standard error.
verbose_option() ->
    {verbose, undefined, "verbose", undefined, "say on standard error what the job decided"}.

run_options() ->
    [config_dir_option("the run is a node"), load_path_option(), libs_dir_option(),
     package_dir_option(), main_option("the entry point, an exported function by its name"),
     verbose_option(), help_option()].

test_options() ->
    [config_dir_option("the tests run on a node"), load_path_option(), libs_dir_option(),
     package_dir_option(), verbose_option(), help_option()].

shell_options() ->
    [config_dir_option("the shell is a node, and its startup is run"),
     load_path_option(),
     libs_dir_option(),
     package_dir_option(),
     {source_root, undefined, "source-root", string,
      "where the shell finds a module's source; default: the root package's"
      " src, or the working directory"},
     main_option("the function spawned beside the shell, from the file loaded"),
     {attach, undefined, "attach", string,
      "the listed peer the shell attaches to, its inputs run on that node"},
     help_option()].

%% Report §11.2: `ern reload` and `ern stop` name the node by its
%% directory, so --config-dir is theirs to require.
signal_options(What) ->
    [config_dir_option(What), help_option()].

required_by(config_dir) -> ["ern config", "ern reload", "ern stop"];
required_by(_) -> [].

%% Report §11.3: the directory made, its `listen`, or the peer listed in it.
config_options() ->
    [config_dir_option("the directory made, or with --peer-dir the one written"),
     {listen, undefined, "listen", string,
      "the address and port the node listens on; without it, the node only dials"},
     {peer_dir, undefined, "peer-dir", string,
      "list the node of this configuration directory, on this machine, as a peer"},
     help_option()].

run(Options, [File | Words], ErrorDevice) ->
    given_file(File),
    Arguments = program_arguments(Words, 1),
    run_started(),
    Say = ern_build:verbose(Options, ErrorDevice),
    %% report §11.2, §11.9: --verbose says the root package first
    ern_build:package_said(Options, Say),
    {Namespace, LoadPath, Loaded} = program(File, Options, Say),
    as_node(Options, LoadPath, Say,
            fun(Node) -> run_entry(Options, Namespace, Loaded, Arguments, ErrorDevice, Node) end);
run(Options, [], ErrorDevice) ->
    run_started(),
    Say = ern_build:verbose(Options, ErrorDevice),
    ern_build:package_said(Options, Say),
    LoadPath = ern_build:load_path(Options),
    host_path(LoadPath),
    as_node(Options, LoadPath, Say, bare, fun(Node) -> run_bare(Options, ErrorDevice, Node) end).

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
run_bare(Options, ErrorDevice, Node) ->
    RunOptions = reporting_options(maps:merge(#{init => fun ern_carrier:say_limits/0,
                                                ended => ended_said(Options, ErrorDevice)},
                                              Node),
                                   ErrorDevice),
    report_outcome(ErrorDevice, <<"bare node">>,
                   ern_rt:run_main(fun waits/0, <<"bare node">>, RunOptions)).

%% Report §8.1, §8.6: a bare node's entry process does not return: it waits
%% for the node's end, which ends it with every other process, and no
%% process has its address to send it anything.
-spec waits() -> no_return().
waits() ->
    receive after infinity -> ok end.

%% Report §11.2: the tests of a module, or of every module under a
%% directory.
test(Options, [Path], ErrorDevice) ->
    run_started(),
    Say = ern_build:verbose(Options, ErrorDevice),
    %% report §11.2, §11.9: --verbose says the root package first
    ern_build:package_said(Options, Say),
    case ern_build:path_kind(Path) of
        directory ->
            Files = ern_build:compiled_under(Path),
            %% report §11.2, §8.7: a node's load path holds the root of each
            %% module found, as each module's run puts its own first
            Roots = case is_node(Options) of
                        true -> module_roots(Files);
                        false -> []
                    end,
            LoadPath = lists:foldr(fun ern_build:with_root/2, ern_build:load_path(Options), Roots),
            as_node(Options, LoadPath, Say,
                    fun(Node) ->
                        report_tree(tree_tests(Files, Options, Say, ErrorDevice, Node))
                    end);
        regular ->
            {Namespace, LoadPath, Loaded} = program(Path, Options, Say),
            as_node(Options, LoadPath, Say,
                    fun(Node) ->
                        tallied(run_tests(Namespace, Loaded,
                                          examples(Namespace, LoadPath, Loaded, Say), none,
                                          ErrorDevice, Node))
                    end);
        Kind ->
            ern_build:given_refused(Path, Kind)
    end.

%% Report §11.2, §8.7: the root of each module of Files, once each, in
%% their order, a `.erc` at the path of the namespace it holds; one that
%% does not read or stands elsewhere gives none, and its run refuses it at
%% its turn (program/3).
module_roots(Files) ->
    lists:foldl(fun(File, Roots) ->
                        Absolute = ern_build:absolute(File),
                        case module_root(Absolute) of
                            {ok, Root} -> Roots ++ [Root || not lists:member(Root, Roots)];
                            none -> Roots
                        end
                end, [], Files).

module_root(File) ->
    case ern_build:regular_bytes(File) of
        {ok, Beam} ->
            case ern_interface:read(Beam) of
                {ok, #{interface := #interface{namespace = Namespace}}} ->
                    Root = ern_build:root_of(File, Namespace),
                    case ern_build:relative(File, Root) =:= ern_namespace:module_path(Namespace)
                         ++ ".erc" of
                        true -> {ok, Root};
                        false -> none
                    end;
                _ ->
                    none
            end;
        {error, _} ->
            none
    end.

%% Report §11.2: the modules of a directory in the order of their paths,
%% each with tests run as `ern test file.erc` runs it, in a runtime of its
%% own, its name before its tests' lines, and one without passed over,
%% loaded and not run; what each run came to (run_tests/6). A run a signal
%% ended or whose end it cut short (report §11.8), or whose output could no
%% longer be written, is the last. Say says each module read (--verbose). A
%% module that cannot be loaded, or two of whose tests have one name, ends
%% the job at its turn, and report §11: a `.erc` found that reaches no
%% regular file is one the job cannot read (ern_build:read/1).
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
                {ran, _, _} = Ran -> [Ran | tree_tests(Files, Options, Say, ErrorDevice, Node)];
                Ended -> [Ended]
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
%% a case failed or a fault counted, and the status of the run that ended
%% the job where one did; and every module's cases counted in one line, as
%% a module's are (tallied/1).
report_tree([]) ->
    io:format("no tests~n"),
    0;
report_tree(Runs) ->
    case lists:last(Runs) of
        {ended, Status} ->
            Status;
        {ran, _, _} ->
            Tallies = [Tally || {ran, _, Tally} <- Runs],
            tallied({ran, lists:max([Status || {ran, Status, _} <- Runs]),
                     lists:foldl(fun added/2, {0, 0, 0}, Tallies)})
    end.

%% Report §11.2: what a job that ran its cases came to, its status, and the
%% line it ends with on standard output, which counts its cases, those that
%% failed, and the faults that counted for the status (§11.8) and stand in
%% no case's line, `14 cases, 2 failed, 1 fault outside a case`; none where
%% it ran no case, which says so where it had none (tests_entry/4), or where
%% a refusal or a signal ended it.
tallied({ended, Status}) ->
    Status;
tallied({ran, Status, {0, _, _}}) ->
    Status;
tallied({ran, Status, {Cases, Failed, Outside}}) ->
    io:format("~ts~n", [[plural(Cases, "case"), ", ", integer_to_list(Failed), " failed",
                         [[", ", plural(Outside, "fault"), " outside a case"] || Outside > 0]]]),
    Status.

plural(1, Noun) -> ["1 ", Noun];
plural(Count, Noun) -> [integer_to_list(Count), " ", Noun, "s"].

added({Cases, Failed, Outside}, {CasesAcc, FailedAcc, OutsideAcc}) ->
    {Cases + CasesAcc, Failed + FailedAcc, Outside + OutsideAcc}.

%% Report §12.5, §11.2: hangup sent to the node that holds the directory's
%% `ernest.pid`, which reads its configuration again; the directory is read
%% first as the node reads it at a reload, making no certificate, so that
%% one the node would refuse is refused here, with the node's refusal, and
%% not signaled. The status 0 says that the signal was delivered.
reload(Options, [], _ErrorDevice) ->
    ConfigDir = node_dir(Options),
    _ = ern_node:read(ConfigDir, left),
    ern_node:signaled(ConfigDir, ern_os:signal_number('Hangup')),
    0;
reload(_Options, Rest, _ErrorDevice) ->
    usage_fail(none_taken(Rest)).

%% Report §8.6, §12.5, §11.2: termination sent to the node that holds the
%% directory's `ernest.pid`, which ends in order; the status says that the
%% node has ended, which the job waits for on the node's lock, with no time
%% of its own.
stop(Options, [], _ErrorDevice) ->
    ern_node:stopped(node_dir(Options)),
    0;
stop(_Options, Rest, _ErrorDevice) ->
    usage_fail(none_taken(Rest)).

%% Report §11.9: `ern unpack`, started in its root package, the working
%% directory, whose manifest's entries the job's Erlang half holds
%% (ern_unpack:given/2) for its Ernest, `Ernest.Unpack`, which the shell's
%% build holds and is loaded as the shell's is, and runs as `ern run` runs an
%% entry point; started where there is no manifest it is refused. Its
%% status is 1 where it refused anything (§11.8), which its `Os.exit` gives.
unpack(Options, [], ErrorDevice) ->
    lists:keymember(root_package, 1, Options)
        orelse ern_build:refused("package.conf", enoent),
    ern_unpack:given([Entry || {package_entry, Entry} <- Options], lists:member(verbose, Options)),
    run_started(),
    Namespace = ['Ernest', 'Unpack'],
    ErlangModule = ern_namespace:erlang_module(Namespace),
    case ern_code:ensure_loaded(ErlangModule) of
        {module, ErlangModule} -> ok;
        _ -> ern_build:fail(shell_not_built())
    end,
    %% report §11.1: the unit names its functions by their position
    {Main, 0} = ern_code:function(ErlangModule, Namespace ++ [main]),
    Site = entry_site(Namespace, main),
    RunOptions = reporting_options(#{init => init_fun([ErlangModule])}, ErrorDevice),
    report_outcome(ErrorDevice, Site,
                   ern_rt:run_main(fun() -> ErlangModule:Main() end, Site, RunOptions)).

%% Report §11.2, §11.3: `ern config`, `ern reload` and `ern stop` name the
%% configuration directory they act on, which they require.
node_dir(Options) ->
    case proplists:get_value(config_dir, Options) of
        undefined -> usage_fail("--config-dir is required: it names the configuration directory");
        ConfigDir -> ConfigDir
    end.

%% Report §11.3: the configuration directory made, its `listen` the one
%% --listen gives or none, or one that is there read, and the node's public
%% key printed, which another node's configuration lists; or, given
%% --peer-dir, the node of that directory listed among the directory's
%% peers, and nothing printed.
config(Options, [], _ErrorDevice) ->
    ConfigDir = node_dir(Options),
    case proplists:get_value(peer_dir, Options) of
        undefined ->
            Listen = proplists:get_value(listen, Options, none),
            io:format("~ts", [ern_node:create(ConfigDir, Listen)]);
        PeerDir ->
            proplists:is_defined(listen, Options)
                andalso usage_fail("--listen and --peer-dir are not given together: --peer-dir"
                                   " creates no directory"),
            ern_node:add_peer(ConfigDir, PeerDir)
    end,
    0;
config(_Options, Rest, _ErrorDevice) ->
    usage_fail(none_taken(Rest)).

%% Report §11.2: the shell is the entry process, and a file's entry point is
%% spawned beside it, so §8.6 ends the program when the shell ends and not
%% when that entry point returns. The shell spawns it itself, through the
%% front end, after it has subscribed to faults (E.21); what the runner does is load
%% the modules, put their interfaces in the session's scope, and run their
%% initializers (§8.5) before the shell starts.
shell(Options, Rest, ErrorDevice) ->
    run_started(),
    %% report §11.2: an attached shell takes no file and no load path, which
    %% are the node's, and attaches from a node of its own
    case proplists:get_value(attach, Options) of
        undefined -> ok;
        _ -> attachable(Options, Rest)
    end,
    %% report §11.7: the shell takes no --verbose, and says nothing of what
    %% it reads
    Say = fun(_) -> ok end,
    %% report §11.2, §4.2: the shell's modules, `Ernest.Shell` and those
    %% under it, are loaded from build/shell as each is first called
    %% (ern_code:ensure_loaded/1), and a node's start loads them whole
    %% (shell_build/0)
    ErlangModule = ern_namespace:erlang_module(['Ernest', 'Shell']),
    case ern_code:ensure_loaded(ErlangModule) of
        {module, ErlangModule} -> ok;
        _ -> ern_build:fail(shell_not_built())
    end,
    Attach = proplists:get_value(attach, Options, none),
    %% report §8.5: the shell's own modules are initialized as a program's
    %% are, before those of the file it loads
    {Init, LoadPath} =
        case Rest of
            [] ->
                %% report §11.2: an attached shell's own node holds the
                %% terminal and the operator's files, and its entry point is
                %% the local half, which spawns the session on the peer; it
                %% read no manifest, so its source root is `--source-root`'s
                %% or the working directory
                GivenLoadPath = ern_build:load_path(Options),
                host_path(GivenLoadPath),
                ern_shell:loaded(#loaded{load_path = GivenLoadPath,
                                         source_root = shell_source_root(Options, "."),
                                         config_startup = config_startup(Options),
                                         attach = Attach}),
                {init_fun([ErlangModule]), GivenLoadPath};
            [File] ->
                given_file(File),
                {Namespace, FileLoadPath, Loaded} = program(File, Options, Say),
                Entry = shell_entry(Options, Namespace),
                ern_shell:loaded(#loaded{load_path = FileLoadPath,
                                         source_root = shell_source_root(Options, File),
                                         interfaces = interfaces(Loaded),
                                         program = program_modules(
                                                     Loaded,
                                                     hd(ern_build:directories(FileLoadPath))),
                                         entry = Entry,
                                         config_startup = config_startup(Options)}),
                {init_fun(Loaded ++ [ErlangModule]), FileLoadPath}
        end,
    %% report §11.2: the sinks are the screen's, which the shell names
    Sink = fun(Bytes) -> ern_shell:to_screen(Bytes) end,
    %% report §11.1: the unit names its functions by their position
    {EntryName, EntrySite} = case Attach of
                                 none -> {main, <<"Ernest.Shell.main">>};
                                 _ -> {attach, <<"Ernest.Shell.attach">>}
                             end,
    {Main, 0} = ern_code:function(ErlangModule, ['Ernest', 'Shell', EntryName]),
    Outcome = as_node(Options, LoadPath, Say,
                      fun(Node) ->
                          %% report §11.2, Appendix E.27: an attached shell's
                          %% own node tells no peer how busy it is, and says
                          %% nothing of its session's node's end or loss
                          Attach =:= none
                              orelse ern_carrier:attaching(unicode:characters_to_binary(Attach)),
                          %% report §11.2: Os.exit faults the process that
                          %% calls it
                          ern_rt:run_main(fun() -> ErlangModule:Main() end, EntrySite,
                                          Node#{stdout => Sink, stderr => Sink, init => Init,
                                                exit => fault,
                                                flush => fun ern_shell:flush_screen/0})
                      end),
    %% report §11.2, §11.8: an attached shell's end, its line said and its
    %% status given by its local half's Os.exit (Appendix E.23)
    report_shell_outcome(ErrorDevice, Outcome).

%% Report §11.2, §11.9: where the shell finds a module's source: the root
%% `--source-root` names, or else the root package's `src` where the shell
%% read a manifest and the package has one, then for a shell given a file
%% the root of the loaded module where that root holds the source the file
%% records (recorded_root/1), and the working directory otherwise; a path
%% under the toolchain's own roots takes that root, as a build's does. An
%% attached shell reads no manifest and is given no file, Path being the
%% working directory.
shell_source_root(Options, Path) ->
    Default = case [Src || {root_package, Dir} <- Options, Src <- [filename:join(Dir, "src")],
                           filelib:is_dir(Src)] of
                  [Src] -> Src;
                  [] -> recorded_root(Path)
              end,
    ern_build:source_root(Options, Path, Default).

%% Report §11.2, §11.1: the root of the loaded module File, the directory
%% reached from it by going up one directory per segment of its namespace,
%% where the source the file records, from that root, is a file under it;
%% the working directory otherwise, and for an attached shell's ".".
recorded_root(".") ->
    ".";
recorded_root(File) ->
    case ern_interface:read(compiled(File)) of
        {ok, #{interface := #interface{namespace = Namespace}, source_path := SourcePath}} ->
            Root = ern_build:root_of(ern_build:absolute(File), Namespace),
            Source = ern_build:absolute(filename:join(Root,
                                                      unicode:characters_to_list(SourcePath))),
            case ern_build:relative(Source, Root) =/= outside andalso filelib:is_regular(Source) of
                true -> Root;
                false -> "."
            end;
        _ ->
            "."
    end.

%% Report §11.2: `--attach` takes no file, `--main`, `--load-path`,
%% `--libs-dir` or `--package-dir`, each refused naming it, and needs
%% `--config-dir`.
attachable(Options, Rest) ->
    Rest =:= [] orelse usage_fail("a file is not given with --attach: the node's program runs"
                                  " there, and :load loads a module"),
    lists:foreach(fun({Option, Why}) ->
                      not lists:keymember(Option, 1, Options)
                          orelse usage_fail([long_name(shell_options(), Option),
                                             " is not given with --attach: ", Why])
                  end, [{main, "the node's program runs there"},
                        {load_path, "the load path is the node's"},
                        {libs_dir, "the load path is the node's"},
                        {package_dir, "the load path is the node's"}]),
    is_node(Options)
        orelse usage_fail("--attach needs --config-dir: the shell attaches from a node of its"
                          " own").

%% Report §8.3: a run given `--config-dir` is a node.
is_node(Options) ->
    proplists:is_defined(config_dir, Options).

%% Report §8.3, §8.7, §12.5, §11.2: a run given `--config-dir` is a node: its
%% directory checked and read before anything of it runs, its carrier
%% started once the bindings have their values, which the run's options
%% carry (ern_rt:run_main/3), and its `ernest.pid` removed at its end,
%% however it ends, a start refused once the file is written among the
%% ways; a run without it is no node. The directory is held absolute from
%% the node's start, since a doc example's run sets the host's working
%% directory (ern_examples:in_directory/3) and a reload reads the
%% directory again (ern_carrier:reload/0); a path a refusal names is still
%% written from the working directory (§11.5). Where the launcher asks for
%% the host's flags (node_flags/0), they are answered and nothing runs, and
%% a run that is no node, whose `--config-dir` was a program's word,
%% answers none. Say says each module the node's start reads (§11.2,
%% --verbose).
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
            %% report §12.5, §11.2: the launcher's first start runs no
            %% program, which would read the standard input the second's
            %% is given and make its effects twice
            persistent_term:get({?MODULE, flags}, false) andalso throw({node_flags, []}),
            Run(#{});
        Given ->
            ConfigDir = ern_build:absolute(Given),
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
        %% report §8.7: a node carries the shell of its build of `ern` and
        %% its whole build, so that a function a peer spawns finds its
        %% code, a shell's of that build among them; nothing of either is
        %% initialized because a peer asked
        shell_build(),
        whole_build(LoadPath, Say),
        %% report §8.7: its peers listed from its start, so that a find or a
        %% spawn in an initializer is a peer's, which no connection reaches
        %% yet
        ok = ern_carrier:list(Configuration),
        Run(#{node => fun() -> ern_carrier:start(Configuration) end})
    after
        %% report §8.7, §12.5: a node stops in order; its ernest.pid goes
        %% once its process has ended
        ern_carrier:depart(),
        ern_node:stop()
    end.

%% Report §11.2: `--main` names a function of the file the job is given, and
%% none is.
no_main_file(shell) ->
    "--main names the function to spawn from the file the shell loads, and no file is given";
no_main_file(run) ->
    "--main names the entry point of the file run, and no file is given: a bare node has none".

%% Report §11.2: every fault on standard error as it happens, a line each:
%% the process of its spawn site and the cause, the entry process's by its
%% site alone, an initializer's binding's among them (§8.5); after the
%% cause, where a call carried the fault from its callee or the cause says
%% how the callee ended, the callee's site (§6.6), where a compute or a call
%% carried it from a peer, the peer's name (§6.6, §8.7), and for a process
%% a peer spawned, the peer, named as a node's line names it (§12.5), since
%% the site is the spawner's; then Suffix, `ern test`'s case
%% (cases_launch/6); and beneath it the fault's trace (§7.3,
%% ern_show:indented_trace/1). It goes through standard error's
%% process, so that it keeps its place among what the program wrote there,
%% and is flushed with it when the program ends.
%%
%% The runtime's own subscriber of Process.subscribeFaults (Appendix E.21),
%% given the peer's node or none, by which a peer a reload has removed since
%% is named as a node's line names one not listed, where the report's
%% `spawnedBy` is `None`. Where standard error is neither a terminal nor a
%% service manager's journal, each line begins with the moment the fault was
%% met, the report's `time`, in UTC as RFC 3339 writes it. A fault of a
%% process Test.faults started never comes here, the runtime telling no one
%% of it (Appendix E.24, ern_rt:expected/2). Report §12.4: beneath a
%% deadlock's trace, the processes it left waiting (left_waiting/1).
report_fault({'FaultReport', Process, Site, Cause, Restarted, Trace, _, Callee, From, Time},
             Peer, Stamped, Suffix) ->
    Faulted = case Restarted of
                  true -> <<" faulted, restarted: ">>;
                  false -> <<" faulted: ">>
              end,
    SpawnedBy = case Peer of
                    none -> [];
                    _ -> [", spawned by ", ern_carrier:named(Peer)]
                end,
    Of = case ern_rt:entry_process() of
             Process -> [];
             _ -> "the process of "
         end,
    ern_rt:send(ern_rt:system_process(stderr),
                iolist_to_binary([ern_job_line:stamp(Stamped, Time), Of,
                                  ern_show:controls(Site, line), Faulted,
                                  ern_show:controls(Cause, line), carried(Callee, From),
                                  SpawnedBy, Suffix, "\n",
                                  ern_show:indented_trace(Trace),
                                  left_waiting(Process)])).

%% Report §11.2, §6.6, §8.7: what follows a fault's cause on its line, a
%% report's and a test's alike: the callee's site where a call carried the
%% fault from its callee, or where the cause says how the callee ended
%% (Appendix E.21), then the peer's name where a compute, or a call of a
%% callee on the peer, carried it from the peer, each escaped as a site is.
carried(Callee, From) ->
    [case Callee of
         {'Some', {'Faulted', Site}} ->
             [", the fault of the callee ", ern_show:controls(Site, line)];
         {'Some', {'Ended', Site}} -> [", the callee ", ern_show:controls(Site, line)];
         'None' -> []
     end,
     case From of
         {'Some', Name} -> [", on the peer ", ern_show:controls(Name, line)];
         'None' -> []
     end].

%% Report §12.4, §11.2: the lines of the processes a deadlock left waiting
%% beside the process it faulted, indented as a trace's frames are, beneath
%% the trace; none for any other fault.
left_waiting(Process) ->
    [["    ", Line, "\n"] || Line <- ern_rt:left_waiting(Process)].

%% The options of a launch that reports its faults. From the command line the
%% program writes to the process's own standard output and standard error,
%% through ports that learn when a stream has gone (report §12.1), and a
%% fault line, and the runtime's line of the end's wait (§8.6), carries
%% its time where standard error is neither a terminal nor a journal
%% (§11.2); in a test, standard error is the test's device. Each fault is
%% reported by fault_reporter/0's line, or by Faults where the launch gives
%% its own reporter (cases_launch/6).
reporting_options(RunOptions, ErrorDevice) ->
    Report = fault_reporter(),
    reporting_options(RunOptions, fun(FaultReport, Peer) -> Report(FaultReport, Peer, []) end,
                      ErrorDevice).

reporting_options(RunOptions, Faults, ErrorDevice) ->
    case persistent_term:get({?MODULE, streams}, device) of
        fds ->
            RunOptions#{faults => Faults, say => fun ern_carrier:say/1, stdout => {fd, 1},
                        stderr => {fd, 2}};
        device ->
            RunOptions#{faults => Faults,
                        stderr => fun(Bytes) -> file:write(ErrorDevice, Bytes) end}
    end.

%% A fault's line as report_fault/4 writes it, with what `ern test` writes
%% after everything else it names (cases_launch/6), stamped where the lines
%% of a launch from the command line are.
fault_reporter() ->
    Stamped = case persistent_term:get({?MODULE, streams}, device) of
                  fds -> ern_job_line:is_stamped();
                  device -> false
              end,
    fun(FaultReport, Peer, Suffix) -> report_fault(FaultReport, Peer, Stamped, Suffix) end.

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
    case ern_chunk:read(Beam, ern_interface:chunk_name()) of
        {ok, _} -> Beam;
        _ -> ern_build:fail(File ++ " is not a compiled module")
    end.

%% Report §11.2: a file given to run that is no `.erc`, and a module's
%% source among them, which is built first.
not_compiled(File) ->
    case filename:extension(File) of
        ".ern" -> File ++ " does not end in .erc; build it first: ern build " ++ File;
        _ -> File ++ " does not end in .erc"
    end.

%% Report §11: a file a job that takes a file alone is given, which reaches
%% a regular file, a link followed; it is refused otherwise, and not opened.
given_file(File) ->
    case ern_build:path_kind(File) of
        regular -> ok;
        Kind -> ern_build:given_refused(File, Kind)
    end.

%% The module of a `.erc` that is a regular file, its load path, and every
%% module loaded for it: the file's own dependencies first (report §11.2,
%% §4.2), each said by Say as it is read (--verbose).
program(File, Options, Say) ->
    filename:extension(File) =:= ".erc" orelse ern_build:fail(not_compiled(File)),
    Absolute = ern_build:absolute(File),
    Beam = compiled(File),
    Namespace = case ern_interface:read(Beam) of
                    {ok, #{interface := #interface{namespace = Found}}} -> Found;
                    {error, Error} -> ern_build:fail(File ++ ": " ++ Error)
                end,
    ModuleRoot = ern_build:root_of(Absolute, Namespace),
    %% report §11.2: the path shape of §11.1 holds for each directory
    %% between the root and the file and for the file's name, refused as
    %% `ern build` refuses a source's, before the path is held to the
    %% namespace
    Relative = ern_build:relative(Absolute, ModuleRoot),
    shaped_under(File, Relative),
    Relative =:= ern_namespace:module_path(Namespace) ++ ".erc"
        orelse ern_build:fail(File ++ " is not at the path of its namespace "
                              ++ ern_namespace:text(Namespace)),
    Given = ern_build:load_path(Options),
    %% report §11.9: a file at a named package's namespace outside that
    %% package's build, and one in a named package's build at another
    %% namespace, is refused before anything runs
    case ern_build:form_out_of_place(Absolute, Namespace, Given) of
        none -> ok;
        Refusal -> ern_build:fail(Refusal)
    end,
    LoadPath = ern_build:with_root(ModuleRoot, Given),
    host_path(LoadPath),
    {Namespace, LoadPath, load(Namespace, [], LoadPath, [], reading(program, Say))}.

%% Report §11.1, §11.2: each component of a `.erc`'s path from its root,
%% Relative, of the path shape, the refusal naming the file from the
%% working directory (§11.5).
shaped_under(File, Relative) ->
    Shown = ern_build:shown(File),
    lists:foreach(fun(Component) -> ern_build:shape(Shown, Component) end,
                  filename:split(filename:rootname(Relative))).

%% Report §11.2: an Erlang module a `foreign fn` names is the host's own or
%% a `.beam` in a directory of the load path, the host's own found first.
%% The working directory, which the host puts on its code path, is neither,
%% unless it is a root of the load path; start/0 has taken it off. A
%% library's shim is the toolchain's and so the host's own, which the
%% library's build, ahead of the program's roots, keeps found first; ahead of
%% the host's would take the name `crypto` from the host's application, whose
%% library the host then does not find.
%% Appendix E.28: the load path is kept, where Code.load finds the modules
%% a module it loads uses (ern_build:load_path/0).
host_path(LoadPath) ->
    ern_build:set_load_path(LoadPath),
    Libraries = ern_tree:libraries(),
    ok = code:add_pathsz(Libraries ++ (ern_build:directories(LoadPath) -- Libraries)).

%% Report §11.2: the interfaces of the modules loaded, which the shell puts
%% in the session's scope, each with the hash of the source it was compiled
%% from, which `:reload` compares against the source it finds; both are in
%% the `ErnI` chunk of the `.erc` it came from (§11.1), as the load read it
%% (ern_code:chunk/1).
interfaces(Loaded) ->
    [{Interface, Hash} || ErlangModule <- lists:reverse(Loaded),
                          {ok, #{interface := Interface, source_hash := Hash}}
                              <- [ern_code:chunk(ErlangModule)]].

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
%% run only where `--config-dir` names that directory; none otherwise. The
%% person's the shell finds itself.
config_startup(Options) ->
    case proplists:get_value(config_dir, Options) of
        undefined -> none;
        ConfigDir -> filename:join(ConfigDir, "startup")
    end.

%% Report §12: a run's start, before it reads a file of its own: the host's
%% signals quieted, and the toolchain's own Erlang of the run's side loaded
%% (ern_code:load_runtime/0).
run_started() ->
    quiet_signals(),
    ern_code:load_runtime().

%% Report §8.6, §12.4: the host's termination and hangup end the program as the
%% end of its entry process does, and the runtime prints nothing of its own
%% about them (ern_signals).
quiet_signals() ->
    ok = ern_signals:install(),
    %% the job's handler stands at warning from the job's start, the
    %% launcher's first start's among them (ern_out:logged/0), so the level
    %% set here matters only in a host that took no streams, a test's, whose
    %% handler, the host's own, would write the host's note about a signal,
    %% logged at notice level; a warning or an error from the host still
    %% comes through, but the reports said otherwise (said_otherwise/2,
    %% installed by job/6)
    _ = logger:set_handler_config(default, level, warning),
    ok.

%% Report §12.1, §7.4, §12.5: the host's own report of a spawn beyond its
%% limit of processes, which the job would write on standard error as the
%% host formats it (report §11), is dropped: the spawn faults its asker,
%% whose fault's line says it (§11.2). So are the reports of what such a
%% spawn ends in the host's own processes, a supervisor's child it could
%% not start and a process of the host's the spawn ended, the start of a
%% socket's processes over TLS and a node's handshake among them: the
%% operation answers, and the node says a connection it refused
%% (ern_tls_dist).
%%
%% Report §12, §11.2: so are the host's loader's report of a file it could
%% not read, a module's at the limit of open files among them, and the
%% emulator's of a module it could not load, or whose code the build or a
%% load asked of it (ern_chunk:is_loadable/2): the caller answers or
%% faults, as a run says the file is no compiled module.
%%
%% Report §12.5, §11.8: the host's process of a node's connections, ended
%% by a spawn beyond the limit as the node dials, ends the host after it,
%% and its report and every one after it, of what the host ends on its
%% way, are dropped: the host's line says it. The filter runs in that
%% process as it ends, before any process can see the loss, and the job's
%% end waits for the host's from then on (host_end/0).
-spec said_otherwise(logger:log_event(), term()) -> logger:filter_return().
said_otherwise(#{msg := {report, #{label := {gen_server, terminate}, name := net_kernel,
                                   reason := {system_limit, _}}}}, _) ->
    persistent_term:put({?MODULE, host_ends}, true),
    ok = logger:set_primary_config(level, none),
    stop;
said_otherwise(#{msg := {"~s~n", ["Too many processes\n"]},
                 meta := #{error_logger := #{emulator := true}}}, _) ->
    stop;
said_otherwise(#{msg := {report, #{label := {supervisor, start_error}, report := Report}}}, _) ->
    case proplists:get_value(reason, Report) of
        {'EXIT', {system_limit, _}} -> stop;
        _ -> ignore
    end;
said_otherwise(#{msg := {"Error in process " ++ _, [_ | Args]},
                 meta := #{error_logger := #{emulator := true}}}, _) ->
    case lists:last(Args) of
        {system_limit, [{erlang, Spawn, _, _} | _]}
          when Spawn =:= spawn; Spawn =:= spawn_link; Spawn =:= spawn_opt;
               Spawn =:= spawn_monitor -> stop;
        _ -> ignore
    end;
said_otherwise(#{msg := {report, #{label := {erl_prim_loader, file_error}}}}, _) ->
    stop;
said_otherwise(#{msg := {"~s~n", ["beam/beam_load.c(" ++ _]},
                 meta := #{error_logger := #{emulator := true}}}, _) ->
    stop;
said_otherwise(_Event, _) ->
    ignore.

%% Report §11.2: the status a running program ends `ern` with, and what it
%% prints of its entry process's end, whose site is Site: nothing when it
%% returned, `killed` when it was killed, its fault, nothing for a signal,
%% whose status is 128 plus its number, and nothing for Os.exit, whose
%% status is its own. The line of a kill is written as a fault's is, its
%% time first where the lines are stamped, then the site (report_fault/4),
%% on the job's standard error, since the launch has ended.
report_outcome(_ErrorDevice, _Site, ok) -> 0;
report_outcome(_ErrorDevice, _Site, {exit, Status}) -> Status;
%% report §12.5, §11.8: a run that could not start, a node whose carrier did
%% not, is the job's refusal, said in the job's line form with status 1
report_outcome(_ErrorDevice, _Site, {refused, Text}) ->
    ern_build:fail(unicode:characters_to_list(Text));
%% report §12.1, §11.8: keys that can no longer be read, or a stream that
%% can no longer be written, by the hangup's signal where the terminal has
%% gone, and otherwise as a shell reports a broken pipe (ern_out:gone_status/1)
report_outcome(_ErrorDevice, _Site, {gone, Stream}) ->
    case ern_out:gone_status(Stream) of
        sighup -> ern_signals:ended(sighup);
        Status -> Status
    end;
report_outcome(ErrorDevice, Site, killed) ->
    io:put_chars(ErrorDevice, [ern_job_line:stamp(ern_job_line:is_stamped()),
                               ern_show:controls(Site, line), " killed\n"]),
    1;
%% report §8.6, §11.2: the signal ended the program, and `ern` ends by it
report_outcome(_ErrorDevice, _Site, {signal, Signal}) -> ern_signals:ended(Signal);
%% report §11.2: the entry process's fault has been reported as it happened
report_outcome(_ErrorDevice, _Site, _Fault) -> 1.

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
                      [ern_show:controls(Cause, line), ern_show:indented_trace(Trace)]),
            70
    end;
%% report §12.1, §11.8: keys the shell can no longer read, or its terminal
%% that can no longer be written, said as its end; a standard error that is
%% the terminal that has gone ends `ern` at the line, by the same signal
%% (ern_out).
report_shell_outcome(ErrorDevice, {gone, Stream} = Gone) ->
    case ern_out:gone_status(Stream) of
        sighup ->
            io:put_chars(ErrorDevice, "the shell ends: its terminal is gone\n"),
            ern_signals:ended(sighup);
        _ ->
            report_outcome(ErrorDevice, <<"Ernest.Shell.main">>, Gone)
    end;
%% report §8.5, §11.2: a binding that faulted before the shell began
report_shell_outcome(ErrorDevice, {initializer_fault, Site, Cause, Trace}) ->
    io:format(ErrorDevice, "~ts faulted: ~ts~n~ts",
              [Site, ern_show:controls(Cause, line), ern_show:indented_trace(Trace)]),
    1;
report_shell_outcome(ErrorDevice, Other) ->
    report_outcome(ErrorDevice, <<"Ernest.Shell.main">>, Other).

%% Report §8.5: every top-level let of the loaded modules, dependencies
%% first, once the runtime has bound the system references.
init_fun(Loaded) ->
    fun() ->
        ern_rt:init_modules(lists:reverse(Loaded)),
        ern_carrier:say_limits()
    end.

%% Report §11.2: every test of the module, one at a time in the order the
%% module declares them, each in a process of its own and its line printed
%% as it ends, then, once their launch has ended, its doc examples,
%% Examples, as ern_examples made them, each a program of its own, in a
%% launch of its own in an empty directory of its own. The units the
%% examples' compiling loaded go once the last has run.
%%
%% It answers what the module's run came to, `{ran, Status, Tally}`, the
%% status 1 where a case failed or a fault counted (report §11.8), or
%% `{ended, Status}` where its end ends the job (run_examples/4). A tests'
%% launch that ends otherwise than by its entry process's return, by an
%% initializer's fault among them, or that a signal reached
%% (cases_launch/6), ends the module's run with the status that end gives
%% (report_outcome/3); an example's fails that example alone, but for a
%% signal's or a stream's (example_launch/3).
run_tests(Namespace, Loaded, {Examples, Units}, Heading, ErrorDevice, Node) ->
    Caller = self(),
    Entry = fun(Running) ->
                tests_entry(ern_namespace:erlang_module(Namespace), Examples =/= [], Caller,
                            Running)
            end,
    Site = unicode:characters_to_binary(ern_namespace:text(Namespace) ++ ".$tests"),
    Ran = case cases_launch(tests, Entry, Site, headed(Heading, init_fun(Loaded)),
                            ErrorDevice, Node) of
              {told, refused, _} ->
                  {ended, 1};
              {told, {Cases, Failed}, Outside} ->
                  run_examples(Examples, {Cases, Failed, Outside}, ErrorDevice, Node);
              {ended, Ended, _, Outside} ->
                  case report_outcome(ErrorDevice, Site, Ended) of
                      Status when Status =:= 0; Status =:= 1 -> {ran, Status, {0, 0, Outside}};
                      Status -> {ended, Status}
                  end
          end,
    ern_examples:unload(Units),
    Ran.

%% Report §11.2: each doc example run as a program of its own (§8.5), in
%% an empty directory of its own (ern_examples:in_directory/3), by a launch
%% of its own (example_launch/3), Tally counting the cases before, those
%% that failed and the faults outside a case; what the module's run came
%% to, `{ran, Status, Tally}`, the status 1 where a case failed or a fault
%% counted (report §11.8), or `{ended, Status}` where its end ends the job.
run_examples([], {_, Failed, Outside} = Tally, _ErrorDevice, _Node) ->
    case Failed + Outside of
        0 -> {ran, 0, Tally};
        _ -> {ran, 1, Tally}
    end;
run_examples([Example | Examples], Tally, ErrorDevice, Node) ->
    Launched = fun(Ready) -> example_launch(Ready, ErrorDevice, Node) end,
    case ern_examples:in_directory(Example, Launched, ErrorDevice) of
        {told, Passed, Outside} ->
            Failed = case Passed of
                         true -> 0;
                         false -> 1
                     end,
            run_examples(Examples, added({1, Failed, Outside}, Tally), ErrorDevice, Node);
        {ended, Ended} ->
            {ended, Ended}
    end.

%% Report §11.2: an example's launch, which initializes the modules the
%% example uses, the documented one among them, and whose entry process
%% runs it as a test is run, in a process of its own, and prints its line;
%% nothing it leaves, a process or an offer, outlives its launch. An
%% example whose program ends before the example returns, an initializer's
%% fault among them, fails with `faulted` and the cause, its line written
%% as a test's is, its trace beneath it, and the fault is not reported
%% apart from it (cases_launch/6).
%%
%% The line is the job's own, written once the launch has ended, since the
%% launch's standard output has ended with it, flushed. A signal, or a
%% stream that can no longer be written, ends the module's run, as it ends
%% the tests' launch. It answers `{told, Passed, Outside}`, whether the
%% example passed, with the count of the faults outside its case, or
%% `{ended, Status}`, the status of that end.
example_launch(#example{test_case = {'Case', Name, _} = Case, initialized = Initialized,
                        frames = Frames}, ErrorDevice, Node) ->
    Caller = self(),
    Entry = fun(Running) ->
                fun() -> Caller ! {ern_tests, run_test(Case, Running, Frames)} end
            end,
    case cases_launch(example, Entry, Name, init_fun(Initialized), ErrorDevice, Node) of
        {told, _, _} = Told ->
            Told;
        {ended, Ended, Carried, Outside} ->
            case ended_reason(Ended) of
                {Reason, Trace} ->
                    io:put_chars(case_line(Name, [ended(Reason), Carried], Frames(Trace))),
                    {told, false, Outside};
                none ->
                    {ended, report_outcome(ErrorDevice, Name, Ended)}
            end
    end.

%% Report §11.2: the Reason (§9.3) of an example's program's end before
%% the example returned, as a test's Down carries it, and its fault's
%% trace; none for a signal or a stream that can no longer be written. The
%% program cannot end by Os.exit, which faults its caller here.
ended_reason(killed) -> {'Killed', <<>>};
ended_reason({fault, Cause, Trace}) -> {{'Fault', Cause}, Trace};
ended_reason({initializer_fault, _Site, Cause, Trace}) -> {{'Fault', Cause}, Trace};
ended_reason({signal, _}) -> none;
ended_reason({gone, _}) -> none.

%% Report §11.2: a launch whose entry process, Entry(Running), runs cases
%% by run_test/3 and tells the runner what they came to, Init run before it
%% (§8.5), the cases being the module's tests or a doc example; what it
%% told, or the outcome it ended with otherwise, and what follows the
%% cause on the line of an example's entry process's fault (carried/2),
%% each with the count of the faults outside a case. A case's own fault is
%% its line, and so, in an example's launch, is the entry process's, an
%% initializer's among them, which the outcome carries (example_launch/3).
%%
%% Every other fault is reported as `ern run` reports it, and counts as a
%% fault outside a case, since §11.8 has `ern test` exit with status 1
%% where any process faulted during the run, but one a case started,
%% directly or through one it started, while the case runs, and those
%% `Test.faults` started, which reach no report (Appendix E.24); the trace
%% of a fault one of those met that was not the one asked for is kept for
%% the case's line (run_test/3). The line of a process a case started ends
%% by naming the case (reported/4).
%%
%% A signal the job took during the launch makes its outcome the signal's,
%% whatever began the end (ern_signals:taken/0).
cases_launch(Cases, Entry, Site, Init, ErrorDevice, Node) ->
    %% the test that runs, which the reporter asks for: a row, since it
    %% changes with each test, and the host copies its table of persistent
    %% terms at each change of one
    Running = ets:new(running_test, [public]),
    Report = fault_reporter(),
    %% report §11.2: a test's own fault is its line, its trace and what
    %% follows its cause beneath it, which its row keeps until its end is
    %% here; an example's entry process's is the example's line, which the
    %% outcome carries, what follows its cause kept under `entry`
    Reporter = fun({'FaultReport', Process, _, _, _, Trace, _, Callee, From, _} = FaultReport,
                   Peer) ->
                       case {ets:member(Running, Process), Cases} of
                           {true, _} ->
                               ets:insert(Running, {Process, Trace, carried(Callee, From)});
                           {false, example} ->
                               case ern_rt:entry_process() of
                                   Process -> ets:insert(Running, {entry, carried(Callee, From)});
                                   _ -> reported(Running, Report, FaultReport, Peer)
                               end;
                           {false, tests} ->
                               reported(Running, Report, FaultReport, Peer)
                       end
               end,
    %% report §11.2: Os.exit faults the test that calls it
    RunOptions = reporting_options(maps:merge(#{init => Init, exit => fault}, Node), Reporter,
                                   ErrorDevice),
    %% Appendix E.24: the first fault of a case's `Test.faults` that met
    %% another cause than the one asked for, its trace kept under the case
    %% for its line
    Unasked = fun(Process, Trace) ->
                      Root = ern_rt:root_of(Process),
                      ets:member(Running, Root)
                          andalso ets:insert_new(Running, {{unasked, Root}, Trace})
              end,
    Outcome = ern_rt:run_main(Entry(Running), Site, RunOptions#{unasked => Unasked}),
    Carried = case ets:lookup(Running, entry) of
                  [{entry, EntryCarried}] -> EntryCarried;
                  [] -> []
              end,
    Outside = case ets:lookup(Running, outside) of
                  [{outside, Count}] -> Count;
                  [] -> 0
              end,
    ets:delete(Running),
    Launched = case Outcome of
                   ok -> receive {ern_tests, Told} -> {told, Told, Outside} end;
                   Ended -> {ended, Ended, Carried, Outside}
               end,
    %% report §11.8: a signal the launch took ends the job at its end, by
    %% the signal, also where it cut short an end begun otherwise, whose
    %% outcome is what began it (§8.6)
    case ern_signals:taken() of
        none -> Launched;
        Signal -> {ended, {signal, Signal}, Carried, Outside}
    end.

%% Report §11.2, §11.8: a fault reported as `ern run` reports it, beside a
%% case's line, and counted as a fault outside a case, but where the
%% process is one a case that runs started, directly or through one it
%% started, whose root the case is (run_test/3). The line of a process a
%% case started ends by naming the case, as a string literal is written
%% (§2.5), and, where the case has ended, saying so: that fault counts. A
%% case's name stands for the launch, as the runner's list of the tests
%% holds it (tests_entry/4), since a process of its chain may fault until
%% the end.
%%
%% A case has ended once its process has (§6.9): the reaper, which
%% applies the reporter, removes a process's row as it handles the
%% process's end, so whether the case's process keeps its row is judged in
%% the reaper's order of ends, where the runner's own row, which the runner
%% clears from its own process, would order nothing against the report.
reported(Running, Report, {'FaultReport', Process, _, _, _, _, _, _, _, _} = FaultReport, Peer) ->
    Root = ern_rt:root_of(Process),
    Case = ets:lookup(Running, {'case', Root}),
    IsRunning = Case =/= [] andalso ern_rt:is_started(Root),
    IsRunning orelse ets:update_counter(Running, outside, 1, {outside, 0}),
    Suffix = case Case of
                 [{_, Name}] ->
                     [", started by the case ", ern_show:show(string, Name),
                      [", which had ended" || not IsRunning]];
                 [] ->
                     []
             end,
    Report(FaultReport, Peer, Suffix).

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
%% tells Caller how many ran and how many of them failed, or that they were
%% refused, before the module's doc examples run, which it is told the
%% module has.
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
                Caller ! {ern_tests, {0, 0}};
            {false, [Twice | _]} ->
                ern_rt:send(ern_rt:system_process(stderr),
                            <<"ern test: two tests are named \"",
                              (ern_show:controls(Twice, line))/binary, "\"\n">>),
                Caller ! {ern_tests, refused};
            {false, []} ->
                Passed = [run_test(Case, Running, fun(Trace) -> Trace end) || Case <- Tests],
                Caller ! {ern_tests, {length(Passed), length([false || false <- Passed])}}
        end
    end.

%% One test, Test.Case(name, run) in declared field order, in a process of
%% its own, monitored from its start so that a fault is reported, however
%% soon it comes, and not taken for the entry process's (report §6.9). A
%% deadlock while it runs is its fault (§11.2). Its line goes through
%% standard output's process, after what the test wrote there, a fault's
%% cause followed by the callee or the peer it was carried from, and the
%% trace of its fault beneath it, both of which the reporter kept in its
%% row; Appendix E.24: a case that failed carries beneath its line the
%% trace of the first fault its `Test.faults` met that was not the one
%% asked for. A trace is written by Frames, which names a doc example's
%% frames as its case is (ern_examples); whether it passed, or, for an
%% example that only compiles, compiled, is returned.
run_test({'Case', Name, Run}, Running, Frames) ->
    Self = erlang:self(),
    Ref = make_ref(),
    %% report §11.8: the case heads a spawn chain of its own, so that a
    %% process it started, directly or through one it started, is known as
    %% the case's by its root (cases_launch/6)
    Pid = ern_rt:spawn_monitored_root(fun() -> receive {Ref, go} -> Self ! {Ref, Run()} end end,
                                      fun(Down) -> {Ref, down, Down} end, Name),
    ok = ern_rt:deadlock_victim(Pid),
    %% the reporter hears of the test's fault before this process does,
    %% so the test is known before it runs and forgotten only once its end
    %% is here; its name stands for the launch (reported/4)
    ets:insert(Running, [{Pid}, {{'case', Pid}, Name}]),
    Pid ! {Ref, go},
    Outcome = receive
                  {Ref, 'Passed'} -> returned(Ref, <<"passed">>);
                  {Ref, 'Compiled'} -> returned(Ref, <<"compiled">>);
                  {Ref, {'Failed', Text}} ->
                      returned(Ref, <<"failed: ", (ern_show:controls(Text, line))/binary>>);
                  {Ref, down, {'Down', _, Reason, _}} -> ended(Reason)
              end,
    ok = ern_rt:deadlock_victim(none),
    Unasked = case ets:take(Running, {unasked, Pid}) of
                  [{_, UnaskedTrace}] -> UnaskedTrace;
                  [] -> <<>>
              end,
    {Trace, Carried} = case {ets:take(Running, Pid), Outcome} of
                           {[{_, Faulted, FaultCarried}], _} -> {Faulted, FaultCarried};
                           {[{_}], <<"failed: ", _/binary>>} -> {Unasked, []};
                           {[{_}], _} -> {<<>>, []}
                       end,
    ern_rt:send(ern_rt:system_process(stdout),
                iolist_to_binary([case_line(Name, [Outcome, Carried], Frames(Trace)),
                                  left_waiting(Pid)])),
    lists:member(Outcome, [<<"passed">>, <<"compiled">>]).

%% Report §11.2: a case's line, its name written as a cause is, its
%% controls escaped, then what it came to, and beneath the line of a case
%% that faulted its trace, and beneath a deadlock's the processes it left
%% waiting (§12.4).
case_line(Name, Outcome, Trace) ->
    iolist_to_binary([ern_show:controls(Name, line), ": ", Outcome, "\n",
                      ern_show:indented_trace(Trace)]).

%% A test that returned still sends its Down; it is taken so that it is not
%% left in the runner's mailbox.
returned(Ref, Outcome) ->
    receive {Ref, down, _} -> Outcome end.

%% Report §11.2: what a case whose process ended before it returned came
%% to, the Reason (§9.3) its Down carries: `killed` where it was killed,
%% and `faulted` with the cause, its controls escaped, where it faulted. A
%% case's process is monitored on this node from its spawn and by no
%% service monitor, so its Down is neither Unknown, Unreachable nor
%% Restarted (§6.9), and the program's end, which ends its runner with it,
%% delivers no Down (ern_rt:run_main/3).
ended('Killed') -> <<"killed">>;
ended({'Fault', Cause}) -> <<"faulted: ", (ern_show:controls(Cause, line))/binary>>.

run_entry(Options, Namespace, Loaded, Arguments, ErrorDevice, Node) ->
    EntryFunction = entry_point(Options, Namespace),
    EntryModule = ern_namespace:erlang_module(Namespace),
    Init = init_fun(Loaded),
    Site = entry_site(Namespace, EntryFunction),
    %% report §11.1: the unit names its functions by their position
    {Function, 0} = ern_code:function(EntryModule, Namespace ++ [EntryFunction]),
    %% report §8.6: a deadlock is the entry process's fault
    RunOptions = reporting_options(maps:merge(#{init => Init, arguments => Arguments,
                                                ended => ended_said(Options, ErrorDevice)},
                                              Node),
                                   ErrorDevice),
    Outcome = ern_rt:run_main(fun() -> EntryModule:Function() end, Site, RunOptions),
    report_outcome(ErrorDevice, Site, Outcome).

%% Report §11.2, §8.6: what `--verbose` says once the program's end has
%% ended its processes, how many it ended, `the end ended 3 processes`, and
%% `the end ended 1 process` for one.
ended_said(Options, ErrorDevice) ->
    Say = ern_build:verbose(Options, ErrorDevice),
    fun(1) -> Say("the end ended 1 process");
       (Count) -> Say(["the end ended ", integer_to_list(Count), " processes"])
    end.

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
%% `fn` of no parameters whose result is `Unit`, receiving or not; a
%% top-level `let`, a function of another shape, and one the module keeps
%% private, in §11.5's words for a private name, is refused.
entry_point(Options, Namespace) ->
    EntryFunction = case proplists:get_value(main, Options) of
                        undefined -> main;
                        Given -> main_name(Given)
                    end,
    Name = ern_namespace:text(Namespace ++ [EntryFunction]),
    Shape = "; an entry point is an exported fn of no parameters whose result is Unit",
    case entry_shape(ern_namespace:erlang_module(Namespace), EntryFunction) of
        entry -> ok;
        missing -> ern_build:fail("no exported function " ++ Name ++ Shape);
        {private, Kind} ->
            ern_build:fail([Name, " is a ", atom_to_list(Kind), " ", ern_namespace:text(Namespace),
                            " keeps private", Shape]);
        {'let', Type} ->
            ern_build:fail(Name ++ " is not an entry point: it is a let of type " ++ Type ++ Shape);
        {other, Type} ->
            ern_build:fail(Name ++ " is not an entry point: its type is " ++ Type ++ Shape)
    end,
    EntryFunction.

%% Report §11.2, Appendix A: `--main` names a function of the file given
%% by its name alone, an ident as the lexer reads it, so the file and the
%% option never name two modules to run; a qualified name is refused with
%% what to write, its last segment, and any other word with the form.
main_name(Text) ->
    Named = case ern_lexer:tokenize(Text, []) of
                {ok, Tokens} -> qualified_name(Tokens, 1);
                {error, _} -> error
            end,
    case Named of
        {ok, [], Function} -> Function;
        {ok, _Namespace, Function} ->
            usage_fail("--main takes the function's name: --main " ++ atom_to_list(Function));
        error ->
            usage_fail("--main takes the function's name: --main name")
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
%% point, a `let`, a function of another shape, a name it keeps private,
%% or nothing it exports. A result type that is a type variable is
%% instantiated to `Unit`, as a polymorphic mailbox type is to `Never`
%% (report §8.1). The file it was loaded from is read as every file a job
%% reads is (report §11).
entry_shape(ErlangModule, Function) ->
    Beam = ern_build:read(code:which(ErlangModule)),
    {ok, #{interface := #interface{namespace = Namespace, values = Values, lets = Lets,
                                   private_values = Private}}} = ern_interface:read(Beam),
    QualifiedName = Namespace ++ [Function],
    case {maps:find(QualifiedName, Values), Private} of
        {error, #{QualifiedName := {Kind, _}}} ->
            {private, Kind};
        {error, _} ->
            missing;
        {{ok, #scheme{type = SchemeType} = Scheme}, _} ->
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
            #{deps := DependencyHashes} = Chunk = held_chunk(Namespace, File, Beam, Reader),
            same_build(File, Chunk),
            say_read(Say, Namespace, File),
            Loaded1 = lists:foldl(fun({Dependency, _}, Acc) ->
                                      load(Dependency, [Namespace | Waiting], LoadPath, Acc,
                                           Reading)
                                  end, Loaded, DependencyHashes),
            %% report §11.2: a module compiled against another interface of a
            %% module it uses, or of the standard library, is refused, not run
            %% to fault where they differ
            lists:foreach(fun({Dependency, Hash}) ->
                              same_interface(Namespace, File, Dependency, Hash)
                          end, DependencyHashes),
            same_stdlib(Namespace, Chunk, StdlibHash),
            loaded_unit(ErlangModule, File, Beam, Chunk, {Reader, Waiting} =:= {program, []}),
            [ErlangModule | Loaded1]
    end.

%% Report §11.2: a module loaded from its file, or taken as the host holds
%% it, and in the code table as it loads (§8.7), with the interface chunk
%% read as it was checked, which what reads the module's interface later
%% reads (ern_code:load/4). Report §11: a file whose code the host will not
%% load is no compiled module, the one the program was given refused as
%% §11 refuses one, and another as a chunk it cannot read is (held_chunk/4).
loaded_unit(ErlangModule, File, Beam, Chunk, IsGiven) ->
    case ern_code:load(ErlangModule, File, Beam, Chunk) of
        ok ->
            ok;
        {error, badfile} when IsGiven ->
            ern_build:fail(ern_build:shown(File) ++ " is not a compiled module");
        {error, badfile} ->
            ern_build:fail(ern_build:shown(File) ++ ": not a compiled module");
        {error, Error} ->
            ern_build:fail("cannot load " ++ ern_build:shown(File) ++ ": " ++ atom_to_list(Error))
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
%% each said by Say as it is read (§11.2, --verbose); report §11.9: a
%% named package's namespace under its build alone, which provides no other
%% (ern_build:compiled_on/1).
whole_build(LoadPath, Say) ->
    Namespaces = [placed(Root, File, Beam, Namespace)
                  || {Root, File} <- ern_build:compiled_on(LoadPath),
                     Beam <- [ern_build:read(File)],
                     {ok, #{interface := #interface{namespace = Namespace}}}
                         <- [ern_interface:read(Beam)]],
    Loaded = [ErlangModule || {ErlangModule, _} <- code:all_loaded()],
    Reading = reading(node, Say),
    lists:foldl(fun(Namespace, Acc) -> load(Namespace, [], LoadPath, Acc, Reading) end, Loaded,
                Namespaces),
    ok.

%% Report §8.7, §11.2: the shell of this build of `ern`, held by a node from
%% its start: each unit of the shell's own in `build/shell`, `Ernest.Shell`
%% and those under it (is_shells/1), loaded as the standard library's are,
%% from its `.erc` and into the code table (ern_code:ensure_loaded/1),
%% and none initialized. The build is on no load path, so no name resolves
%% to one of its units, a session's interfaces hold none (ern_shell), and
%% no --verbose line says one, as none says the standard library's. It is
%% read before the load path, so that a unit of the load path that holds
%% one of its identities is the later and answers a peer for it
%% (ern_code:answering/1). A tree whose shell is not built is refused, as
%% `ern shell` refuses it, since such a node would hold no shell.
shell_build() ->
    Build = ern_tree:build("shell"),
    Files = case filelib:is_dir(Build) of
                true -> [File || File <- ern_build:compiled_under(Build),
                                 is_shells(filename:split(ern_build:relative(File, Build)))];
                false -> []
            end,
    Files =/= [] orelse ern_build:fail(shell_not_built()),
    lists:foreach(fun(File) ->
                      Relative = filename:rootname(ern_build:relative(File, Build)),
                      Unit = ern_namespace:erlang_module(
                               ern_namespace:namespace(filename:split(Relative))),
                      case ern_code:ensure_loaded(Unit) of
                          {module, Unit} -> ok;
                          {error, _} -> ern_build:fail(shell_not_built())
                      end
                  end, Files).

%% Report §11.2, §4.2: a unit of the shell's own, `Ernest.Shell` or one
%% under it, by its path under the shell's build; the build holds `ern
%% unpack`'s Ernest beside them (§11.9), which no node holds.
is_shells(["ernest", "shell.erc"]) -> true;
is_shells(["ernest", "shell" | _]) -> true;
is_shells(_) -> false.

shell_not_built() ->
    "the shell is not built; run make".

%% Report §11.2: the namespace of a compiled module of the load path, which
%% stands at the path of its namespace under its root; one at another
%% module's path is refused as a program's load refuses it: a path that
%% breaks §11.1's shape by the component that breaks it, and one of the
%% shape naming the file and the module it holds (held_chunk/4), and not
%% as the module its namespace names, missing at its own path.
placed(Root, File, Beam, Namespace) ->
    case filename:join(Root, ern_namespace:module_path(Namespace) ++ ".erc") =:= File of
        true ->
            Namespace;
        false ->
            Relative = ern_build:relative(File, Root),
            shaped_under(File, Relative),
            Components = filename:split(filename:rootname(Relative)),
            _ = held_chunk(ern_namespace:namespace(Components), File, Beam, node),
            Namespace
    end.

%% Report §11.2: a module's compiled form, found by its namespace on the
%% load path, and report §11.9: a named package's under its build alone.
%% One the path lacks is named with the module that uses it, `no module
%% Util, which Main uses, on the load path`; report §8.7: and, for a node,
%% with the rule that makes a module the program does not use its need,
%% after a semicolon. The program's own load comes first, so a module its
%% reach lacks is refused with the program's text.
compiled_file(Namespace, Waiting, LoadPath, Reader) ->
    Path = ern_namespace:module_path(Namespace),
    Relative = Path ++ ".erc",
    {none, Roots} = ern_build:looked_in(Path, none, LoadPath),
    case [Found || Dir <- Roots, Found <- [filename:join(Dir, Relative)],
                   filelib:is_regular(Found)] of
        [Found | _] ->
            Found;
        [] ->
            ern_build:fail(["no module ", ern_namespace:text(Namespace), used_by(Waiting),
                            " on the load path", read_by(Reader)])
    end.

used_by([]) -> "";
used_by([User | _]) -> [", which ", ern_namespace:text(User), " uses,"].

read_by(program) -> "";
read_by(node) -> "; a node reads every module of its load path".

%% Report §11.2: the interface chunk of a module's compiled form; a file
%% found by a module's namespace that holds another is no module of that
%% name, refused with the advice of the program's load or, report §8.7, of
%% the node's, whose load path holds it.
held_chunk(Namespace, File, Beam, Reader) ->
    Advice = case Reader of
                 program -> rebuild;
                 node -> node
             end,
    case ern_interface:read(Beam) of
        {ok, #{interface := #interface{namespace = Namespace}} = Chunk} ->
            Chunk;
        {ok, #{interface := #interface{namespace = Held}}} ->
            ern_build:fail(ern_build:held_another(File, Held, Namespace, Advice));
        {error, Error} ->
            ern_build:fail(ern_build:shown(File) ++ ": " ++ Error)
    end.

%% Report §11.2, §11.1: a compiled form another build of `ern` wrote,
%% another version or the same version's code changed, is refused, naming
%% the file, since `ern build` compiles it again (ern_build:current/6) and
%% a run cannot.
same_build(File, Chunk) ->
    maps:get(compiler, Chunk, none) =:= ern_build:compiler_build()
        orelse ern_build:fail(ern_build:shown(File) ++ ": compiled by another build of ern").

%% Report §11.1, §11.2: a compiled form compiled against another standard
%% library than the run's is refused, naming the module, which a build
%% compiles again; one that records none is the standard library's own.
same_stdlib(Namespace, Chunk, StdlibHash) ->
    Name = ern_namespace:text(Namespace),
    lists:member(maps:get(stdlib, Chunk, none), [none, StdlibHash])
        orelse ern_build:fail(Name ++ " was compiled against another standard library; build "
                              ++ Name ++ " again").

%% Report §11.2: a module, its compiled form at File, compiled against
%% another interface of a module it uses than the form the run found is
%% refused; where the module is a library's and the form found for a
%% library's module it uses is not that library's build's, the refusal
%% names the form found as §11.1 names a module that hides the library's
%% (ern_build:hiding_found/5), since no build of the program mends it. The
%% form found is read as every file a job reads is (report §11).
same_interface(Namespace, File, Dependency, Hash) ->
    Found = code:which(ern_namespace:erlang_module(Dependency)),
    Beam = ern_build:read(Found),
    {ok, #{interface := Interface}} = ern_interface:read(Beam),
    ern_interface:hash(Interface) =:= Hash
        orelse ern_build:fail(another_interface(Namespace, File, Dependency, Found)).

another_interface(Namespace, File, Dependency, Found) ->
    case ern_build:hiding_found(File, Dependency, Found, ern_tree:libraries(),
                                ern_build:load_path()) of
        none ->
            Name = ern_namespace:text(Namespace),
            Name ++ " was compiled against another " ++ ern_namespace:text(Dependency) ++ "; build "
                ++ Name ++ " again";
        Refusal ->
            Refusal
    end.

%% Report §11: a refusal of the form of a job's command line, its text
%% holding no control character, the job's help named after it
%% (ern_build:form_fail/1).
-spec usage_fail(io_lib:chars()) -> no_return().
usage_fail(Message) ->
    ern_build:form_fail(Message).
