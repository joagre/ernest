%% The toolchain of report §11: one command, ern, whose first word is its
%% job, build and doc (§11.1, §11.4), format (§11.6), run, test and shell
%% (§11.2), and config (§11.3). The launcher bin/ern is thin; everything is
%% here so that the tests can call it. `ern/1,2` returns the exit status,
%% which the launcher's entry point ends the host with.
-module(ern_cli).

-export([start/0, ern/1, ern/2]).

-include_lib("parser/include/ern_ast.hrl").
-include_lib("typer/include/ern_types.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_build.hrl").

%% VERSION is the top-level VERSION file, passed by the Makefile.

%%
%% Entry
%%

%% A word of the command line as the host gives it: decoded, or, where the
%% host's names are UTF-8 and the word is not, what decoding it left.
-type word() :: string() | {error | incomplete, string(), binary()}.

%% Report §11: the launcher's entry, the command line being what follows
%% the host's -extra. The host's signals are ern's before any of its work
%% (ern_signals). A run writes to the process's own standard output and
%% standard error (reporting/2). A failure of the toolchain itself is a
%% defect, which is reported on standard error with the host's stack and
%% ends `ern` with status 70, and is never left as a crash dump in the
%% working directory. `ern` ends by the signal that ended a run once its
%% output has flushed (§11.2), and otherwise with the status.
-spec start() -> no_return().
start() ->
    ok = ern_signals:install(),
    Args = init:get_plain_arguments(),
    %% a job writes through ports of its own, which end it when a stream's
    %% reader has gone (ern_out); the shell's terminal is the host's own
    Shell = case Args of
                ["shell" | Rest] -> Rest =:= [] orelse hd(Rest) =/= "--help";
                _ -> false
            end,
    Err = case Shell andalso ern_tty:is_terminal(stdout) of
              true -> standard_error;
              false -> ern_out:take()
          end,
    Status = try
                 persistent_term:put({?MODULE, streams}, fds),
                 ern(Args, Err)
             catch
                 Class:Reason:Stack ->
                     %% the host's text of the exception, which may end in a
                     %% line break or not, ends the line
                     Text = erl_error:format_exception(Class, Reason, Stack),
                     io:format(Err, "ern: internal error: ~ts~n", [string:trim(Text, trailing)]),
                     70
             end,
    case ern_signals:ended() of
        none -> ok;
        Signal -> ern_signals:die(Signal, Status)
    end,
    ok = ern_out:finish(Err),
    halt(Status).

-spec ern([word()]) -> 0..255.
ern(Args) ->
    ern(Args, standard_error).

%% Report §11: the first word is the job, and --help and --version stand
%% alone; a working directory whose name is not UTF-8 the launcher refused
%% before the host started. Err is the error device, standard_error for
%% the launcher; a test passes its own and reads what the user would see.
%% The status is 0 or 1, or a run's, which Os.exit or a signal may give
%% (§11.2).
-spec ern([word()], io:device()) -> 0..255.
ern(["--help"], _Err) ->
    usage(standard_io),
    0;
ern(["--version"], _Err) ->
    io:format("ern ~s~n", [?VERSION]),
    0;
ern([Word | Args], Err) ->
    case {is_utf8(Word), lists:keyfind(Word, 1, jobs())} of
        {false, _} -> refuse(not_utf8(Word), Err);
        {true, {Word, Spec, Positional, Fun}} -> job(Word, Spec, Positional, Args, Fun, Err);
        {true, false} -> refuse(no_job(Word), Err)
    end;
ern([], Err) ->
    refuse("a job is required", Err).

%% The jobs of §11, each with its options, what follows them, and its
%% function.
jobs() ->
    [{"build", build_options(), "file.ern | src-dir", fun build/3},
     {"doc", doc_options(), "file.ern | file.erc | src-dir", fun doc/3},
     {"format", format_options(), "file.ern | src-dir ... | -", fun format/3},
     {"run", run_options(), "file.erc [argument]...", fun run/3},
     {"test", test_options(), "file.erc", fun test/3},
     {"shell", shell_options(), "[file.erc]", fun shell/3},
     {"config", config_options(), "", fun config/3}].

%% Report §11: a first word that is no job. A spelling of the toolchain
%% before its jobs is refused with the one that replaces it.
no_job("--shell") -> "--shell is now the job: ern shell";
no_job("--test") -> "--test is now the job: ern test";
no_job("--doc") -> "--doc is now the job: ern doc";
no_job("--create-config-dir") ->
    "--create-config-dir is now the job ern config, whose --config-dir names the directory itself";
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
    "no job " ++ Word ++ "; the jobs are build, doc, format, run, test, shell and config".

%% An option's whole name, before any `=`.
option_name(Word) ->
    lists:takewhile(fun(Ch) -> Ch =/= $= end, Word).

refuse(Msg, Err) ->
    io:format(Err, "ern: ~ts~n", [Msg]),
    usage(Err),
    1.

usage(Device) ->
    io:format(Device, "Usage: ern <job> [options] ...~n~n"
              "  build   compile a module, or every module under a directory~n"
              "  doc     write the documentation of a module or a directory~n"
              "  format  lay out modules as the style guide does~n"
              "  run     run a program~n"
              "  test    run the tests of a module~n"
              "  shell   run an interactive shell~n"
              "  config  create the configuration directory~n~n"
              "ern <job> --help lists a job's options; ern --version prints the version.~n",
              []).

%% Run a job with its options parsed by getopt. --help prints and stops
%% with status 0; a usage error prints the message and the job's usage on
%% Err, any other error one line, both with status 1.
job(Job, Spec, Positional, Args, Fun, Err) ->
    Name = "ern " ++ Job,
    {Own, Program} = case Job of
                         "run" -> program_words(Spec, Args, []);
                         _ -> {Args, []}
                     end,
    try
        lists:foreach(fun(A) -> is_utf8(A) orelse ern_build:fail(not_utf8(A)) end, Own),
        lists:foreach(fun(A) ->
                          case old_option(A, Spec) of
                              none -> ok;
                              Msg -> usage_fail(Msg)
                          end
                      end, Own),
        lists:foreach(fun(A) -> one_spelling(A, Spec) end, Own),
        {Opts, Rest} = case getopt:parse(Spec, Own) of
                           {ok, Parsed} -> Parsed;
                           {error, {Reason, Data}} ->
                               usage_fail(getopt:format_error(Spec, {Reason, Data}))
                       end,
        given_once(Opts, Spec),
        case lists:member(help, Opts) of
            true -> job_usage(Spec, Name, Positional, standard_io), 0;
            false -> Fun(Opts, Rest ++ Program, Err)
        end
    catch
        throw:{cli_usage, Msg2} ->
            io:format(Err, "~s: ~ts~n", [Name, Msg2]),
            job_usage(Spec, Name, Positional, Err),
            1;
        throw:{cli_error, Msg3} ->
            io:format(Err, "~s: ~ts~n", [Name, Msg3]),
            1
    end.

%% Report §11: an option's value is the next word, so `--name=value` is a
%% second spelling, refused with the first; a flag takes none. A name the
%% job does not take is getopt's to refuse.
one_spelling("--" ++ _ = Word, Spec) ->
    Name = option_name(Word),
    Known = lists:any(fun({_, _, L, _, _}) -> "--" ++ L =:= Name end, Spec),
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
given_once(Opts, Spec) ->
    Keys = [K || {K, _} <- Opts] ++ [K || K <- Opts, is_atom(K)],
    Name = fun(K) -> hd(["--" ++ L || {Key, _, L, _, _} <- Spec, Key =:= K]) end,
    case [K || K <- lists:usort(Keys), K =/= load_path, length([X || X <- Keys, X =:= K]) > 1] of
        [] -> ok;
        [K | _] -> usage_fail(Name(K) ++ " is given more than once")
    end,
    case [K || {K, ""} <- Opts] of
        [] -> ok;
        [E | _] -> usage_fail(Name(E) ++ " is given an empty value")
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
%% and is refused as a second spelling.
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
    lists:any(fun({_, _, L, Type, _}) -> L =:= Long andalso Type =/= undefined end, Spec);
takes_value(_Spec, _Short) ->
    false.

%% Report §11: an option as the toolchain spelled it before its jobs,
%% matched by its whole name, refused with the spelling that replaces it
%% where the job takes that spelling. Elsewhere it is an option the job
%% does not take, refused as any other is.
old_option(Word, Spec) ->
    case old_spelling(option_name(Word)) of
        {job, Msg} -> Msg;
        {Key, Msg} ->
            case lists:keymember(Key, 1, Spec) of
                true -> Msg;
                false -> none
            end;
        none -> none
    end.

old_spelling("--out-dir") -> {build_root, "--out-dir is now --build-root"};
old_spelling("--no-clean") ->
    {build_root, "--no-clean is gone; a separate output takes a separate --build-root"};
old_spelling("--errors") -> {short_errors, "--errors short is now --short-errors"};
old_spelling("--emit") -> {emit_erl, "--emit erl is now --emit-erl"};
old_spelling("--create-config-dir") ->
    {job, "--create-config-dir is now the job ern config, whose --config-dir names the"
          " directory itself"};
old_spelling("--shell") -> {job, "--shell is now the job: ern shell"};
old_spelling("--test") -> {job, "--test is now the job: ern test"};
old_spelling("--doc") -> {job, "--doc is now the job: ern doc"};
old_spelling(_) -> none.

%% getopt's usage text on any device; getopt:usage/4 takes only an atom.
job_usage(Spec, Name, Positional, Device) ->
    Line = string:trim([getopt:usage_cmd_line(Name, Spec), " ", Positional], trailing),
    io:format(Device, "~ts~n~n~ts~n", [Line, getopt:usage_options(Spec)]).

help_option() ->
    {help, undefined, "help", undefined, "print this text"}.

%%
%% ern build and ern doc, report §11.1 and §11.4
%%

build_options() ->
    [{source_root, undefined, "source-root", string,
      "the directory whose layout yields namespaces"},
     {build_root, undefined, "build-root", string,
      "where the compiled tree goes; default: the source root"},
     {load_path, undefined, "load-path", string,
      "a root of compiled modules a module may use; may be repeated"},
     {emit_erl, undefined, "emit-erl", undefined,
      "write the module's Erlang source instead of .erc"},
     {short_errors, undefined, "short-errors", undefined,
      "the first line of each error only"},
     help_option()].

doc_options() ->
    [{man, undefined, "man", undefined, "write manual pages in roff instead of CommonMark"}
     | [Opt || {Key, _, _, _, _} = Opt <- build_options(), Key =/= emit_erl]].

build(Opts, [Path], Err) ->
    ern_build:compile(Opts, Path, Err);
build(_Opts, _Rest, _Err) ->
    usage_fail("one file or directory argument is required").

%% Report §11.4: a file's documentation to stdout, a directory's into the
%% build directory, one document per module and an index, or with --man one
%% manual page per module and no index. The modules are compiled first, so
%% every document is of a module that type-checks and every dependency has
%% an interface.
doc(Opts, [Path], Err) ->
    case filelib:is_dir(Path) of
        true ->
            case ern_build:compile(Opts, Path, Err) of
                0 -> doc_dir(Opts, Path);
                Status -> Status
            end;
        false ->
            filelib:is_regular(Path) orelse ern_build:fail("no such file " ++ Path),
            try
                io:put_chars(page(Opts, beam_of(Opts, Path))),
                0
            catch
                throw:{errors, F, Errors} -> ern_build:report_errors(Opts, F, Errors, Err)
            end
    end;
doc(_Opts, _Rest, _Err) ->
    usage_fail("one file or directory argument is required").

%% Report §11.4: the documentation comes from the compiled module. A `.erc`
%% is read; a source is compiled first, in memory, so that asking for a page
%% writes nothing.
beam_of(Opts, Path) ->
    case filename:extension(Path) of
        ".erc" ->
            Bin = compiled(Path),
            case ern_docs:read(Bin) of
                {ok, _} -> Bin;
                {error, Why} -> ern_build:fail(Path ++ ": " ++ Why)
            end;
        _ ->
            Root = ern_build:source_root(Opts, Path, "."),
            OutDir = ern_build:out_dir(Opts, Root),
            %% report §11.1: a module outside the source root is found under
            %% build-root, then under each --load-path root
            Dirs = [OutDir | ern_build:load_path(Opts)],
            [#mod{ns = Ns, file = File, rel = Rel, decls = Decls, deps = Deps}] =
                ern_build:compile_order([ern_build:module_of(ern_build:absolute(Path), Root)],
                                        Root, Dirs),
            DepIfaces = [I || D <- Deps, {_, I} <- [ern_build:dep_iface(D, #{}, Dirs, Root)]],
            case ern_typecheck:check(Ns, Decls, DepIfaces) of
                {ok, Typed, Iface, Env} ->
                    Build = #{source_hash => <<>>, deps => [],
                              source => list_to_binary(filename:basename(Rel))},
                    {ok, _, Beam} = ern_emitter:compile(Ns, Typed, Iface, Env, Build),
                    Beam;
                {error, Errors} ->
                    throw({errors, File, Errors})
            end
    end.

%% Report §11.4: a module's page, in CommonMark or with --man as a manual
%% page.
page(Opts, Beam) ->
    case lists:member(man, Opts) of
        true -> ern_page:manual(Beam);
        false -> ern_page:page(Beam)
    end.

doc_dir(Opts, Path) ->
    Root = ern_build:source_root(Opts, Path, Path),
    OutDir = ern_build:out_dir(Opts, Root),
    Files = ern_build:sources(Path),
    Mods = ern_build:compile_order([ern_build:module_of(ern_build:absolute(F), Root)
                                    || F <- Files], Root),
    Stdlib = ern_build:is_stdlib_root(Root),
    %% report §11.4: the page of a module whose source is gone goes, as the
    %% build's sweep takes its .erc
    Kept = [Ns || #mod{ns = Ns} <- Mods] ++ [['Prelude'] || Stdlib],
    case lists:member(man, Opts) of
        true ->
            man_dir(Mods, Stdlib, OutDir),
            ern_build:sweep_pages(man, Path, Root, OutDir, Kept);
        false ->
            markdown_dir(Mods, Stdlib, OutDir),
            ern_build:sweep_pages(markdown, Path, Root, OutDir, Kept)
    end,
    0.

markdown_dir(Mods, Stdlib, OutDir) ->
    Entries = [begin
                   Rel = ern_build:module_path(Ns) ++ ".md",
                   Out = filename:join(OutDir, Rel),
                   ok = ern_build:made_dir(Out),
                   Page = unicode:characters_to_binary(ern_page:page(built(OutDir, Ns))),
                   ok = ern_build:write_output(Out, Page),
                   ["- [", ern_build:qname(Ns), "](", Rel, ")\n"]
               end || #mod{ns = Ns} <- lists:sort(Mods)],
    Prelude = prelude_page(Stdlib, OutDir),
    ok = ern_build:write_output(filename:join(OutDir, "index.md"),
                     unicode:characters_to_binary(["# Modules\n\n", Prelude, Entries])).

%% Report §11.4: each manual page beside its module's .erc, in a file named
%% as `man` finds it, `Ernest.Net.Http.3ern`, and the prelude's at the top
%% of the standard library's own build root.
man_dir(Mods, Stdlib, OutDir) ->
    lists:foreach(fun(#mod{ns = Ns}) ->
                          Dir = filename:dirname(filename:join(OutDir, ern_build:module_path(Ns))),
                          Out = filename:join(Dir, "Ernest." ++ ern_build:qname(Ns) ++ ".3ern"),
                          Page = unicode:characters_to_binary(ern_page:manual(built(OutDir, Ns))),
                          ok = ern_build:write_output(Out, Page)
                  end, lists:sort(Mods)),
    case Stdlib of
        true ->
            %% a page is text, written as UTF-8
            Page = unicode:characters_to_binary(ern_page:prelude_manual()),
            ok = ern_build:write_output(filename:join(OutDir, "Ernest.Prelude.3ern"), Page);
        false -> ok
    end.

%% A module's compiled form, which the build just wrote under OutDir.
built(OutDir, Ns) ->
    ern_build:read(filename:join(OutDir, ern_build:module_path(Ns) ++ ".erc")).

%% Report §11.4: the standard library's own source root also gets the
%% prelude's page, first in the index.
prelude_page(false, _OutDir) ->
    [];
prelude_page(true, OutDir) ->
    ok = ern_build:write_output(filename:join(OutDir, "prelude.md"),
                     unicode:characters_to_binary(ern_page:prelude_page())),
    ["- [Prelude](prelude.md)\n"].

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
format(Opts, ["-"], Err) ->
    Text = read_input(open_input(), []),
    case ern_format:format(Text) of
        {ok, Text} -> format_result(Opts, Text, same);
        {ok, Out} -> format_result(Opts, Out, changed);
        {error, D} ->
            io:format(Err, "~ts~n", [error_text(Opts, "-", Text, D)]),
            1
    end;
format(_Opts, [], _Err) ->
    usage_fail("a file, a directory or - is required");
format(Opts, Paths, Err) ->
    lists:foreach(fun(P) ->
                      filelib:is_file(P) orelse ern_build:fail("no such file or directory " ++ P)
                  end, Paths),
    Files = lists:append([modules_named(P) || P <- Paths]),
    Results = [format_file(Opts, F, Err) || F <- Files],
    case lists:all(fun(R) -> R =:= ok end, Results) of
        true -> 0;
        false -> 1
    end.

%% Report §11.6: the modules a path names. Those under a directory are
%% found as `ern build` finds them (§11.1), each component of the path
%% under the directory one word; the directory is no source root, so
%% nothing that a namespace decides is checked. A file named alone is a
%% module when its name ends in `.ern` and is otherwise one word.
modules_named(Path) ->
    case filelib:is_dir(Path) of
        true ->
            [shaped(File, Path) || File <- ern_build:sources(Path)];
        false ->
            filename:extension(Path) =:= ".ern"
                orelse ern_build:fail(Path ++ " does not end in .ern"),
            ern_build:shape(Path, filename:basename(Path, ".ern")),
            [Path]
    end.

%% A module found under a directory, its path's shape checked from there.
shaped(File, Directory) ->
    Relative = ern_build:relative(ern_build:absolute(File), ern_build:absolute(Directory)),
    Components = filename:split(filename:rootname(Relative)),
    lists:foreach(fun(Component) -> ern_build:shape(Relative, Component) end, Components),
    File.

format_result(Opts, Out, Same) ->
    case {lists:member(check, Opts), Same} of
        {false, _} -> io:put_chars(Out), 0;
        {true, same} -> 0;
        {true, changed} -> io:format("-~n"), 1
    end.

format_file(Opts, File, Err) ->
    Text = ern_build:read(File),
    case ern_format:format(Text) of
        {ok, Text} -> ok;
        {ok, Out} ->
            case lists:member(check, Opts) of
                true -> io:format("~ts~n", [ern_build:shown(File)]), changed;
                false -> ok = ern_build:write_whole(File, Out)
            end;
        {error, D} ->
            io:format(Err, "~ts~n", [error_text(Opts, ern_build:shown(File), Text, D)]),
            error
    end.

error_text(Opts, Shown, Source, D) ->
    case lists:member(short_errors, Opts) of
        true -> ern_diag:short(Shown, D);
        false -> ern_diag:format(Shown, Source, D)
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

%% Report §11.2, §11.3: what each job reads of the configuration directory,
%% `ernest.conf` from MVP 3.0 (docs/development.md).
config_dir_option(What) ->
    {config_dir, undefined, "config-dir", string,
     "the configuration directory, default ./.ernest; " ++ What}.

load_path_option() ->
    {load_path, undefined, "load-path", string, "a root of compiled modules; may be repeated"}.

main_option() ->
    {main, undefined, "main", string, "the entry point, a qualified exported function"}.

run_options() ->
    [config_dir_option("its ernest.conf is read from MVP 3.0"), load_path_option(), main_option(),
     help_option()].

test_options() ->
    [config_dir_option("its ernest.conf is read from MVP 3.0"), load_path_option(), help_option()].

shell_options() ->
    [config_dir_option("its startup is run; its ernest.conf is read from MVP 3.0"),
     load_path_option(),
     {source_root, undefined, "source-root", string,
      "where the shell finds a module's source; default the working directory"},
     main_option(), help_option()].

config_options() ->
    [config_dir_option("the directory made"), help_option()].

run(Opts, [File | Words], Err) ->
    Arguments = program_arguments(Words, 1),
    quiet_signals(),
    {Ns, Roots, Loaded} = program(File, Opts),
    run_entry(Opts, Ns, Roots, Loaded, Arguments, Err);
run(_Opts, [], _Err) ->
    usage_fail("one .erc file argument is required").

%% Report §11.2, Appendix E.23: the program's arguments, Os.arguments, as
%% UTF-8 text, one that is not UTF-8 refused by its position before
%% anything runs.
program_arguments([], _N) ->
    [];
program_arguments([Word | Words], N) ->
    is_utf8(Word) orelse ern_build:fail(io_lib:format("argument ~B is not UTF-8", [N])),
    [word_bytes(Word) | program_arguments(Words, N + 1)].

test(Opts, [File], Err) ->
    quiet_signals(),
    {Ns, _Roots, Loaded} = program(File, Opts),
    run_tests(Ns, Loaded, Err);
test(_Opts, _Rest, _Err) ->
    usage_fail("one .erc file argument is required").

config(Opts, [], _Err) ->
    create_config_dir(proplists:get_value(config_dir, Opts, ".ernest"));
config(_Opts, _Rest, _Err) ->
    usage_fail("config takes no argument").

%% Report §11.2: the shell is the entry process, and a file's entry point is
%% spawned beside it, so §8.6 ends the program when the shell ends and not
%% when that entry point returns. The shell spawns it itself, through the
%% front end, after it has subscribed to faults (E.21); what the runner does is load
%% the modules, put their interfaces in the session's scope, and run their
%% initializers (§8.5) before the shell starts.
shell(Opts, Rest, Err) ->
    quiet_signals(),
    Mod = ern_emitter:module_atom(['Shell']),
    case code:ensure_loaded(Mod) of
        {module, Mod} -> ok;
        _ -> ern_build:fail("the shell is not built; run make")
    end,
    %% report §8.5: the shell's own modules are initialized as a program's
    %% are, before those of the file it loads
    Init = case Rest of
               [] ->
                   %% report §11.2: --main names a function of the file
                   not lists:keymember(main, 1, Opts) orelse usage_fail(no_main_file()),
                   host_path(ern_build:load_path(Opts)),
                   ern_shell:loaded(#{roots => ern_build:load_path(Opts),
                                      source_root => ern_build:source_root(Opts, ".", "."),
                                      ifaces => [], entry => none,
                                      startups => startups(Opts)}),
                   init_fun([Mod]);
               [File] ->
                   {Ns, Roots, Loaded} = program(File, Opts),
                   {Entry, Loaded1} = shell_entry(Opts, Ns, Roots, Loaded),
                   ern_shell:loaded(#{roots => Roots,
                                      source_root => ern_build:source_root(Opts, File, "."),
                                      ifaces => ifaces(Loaded1),
                                      entry => Entry,
                                      startups => startups(Opts)}),
                   init_fun(Loaded1 ++ [Mod]);
               _ ->
                   usage_fail("at most one .erc file argument")
           end,
    %% report §11.2: the sinks are the screen's, which the shell names
    Sink = fun(Bin) -> ern_shell:to_screen(Bin) end,
    %% report §11.2: Os.exit faults the process that calls it
    shell_outcome(Err, ern_rt:run_main(fun() -> Mod:main() end, <<"Shell.main">>,
                                       #{stdout => Sink, stderr => Sink, init => Init,
                                         exit => fault})).

no_main_file() ->
    "--main names the function to spawn from the file the shell loads, and no file is given".

%% Report §11.2: every fault on standard error as it happens, a line each,
%% the spawn site and the cause, and beneath a failure of the runtime or a
%% foreign function's raise the host's stack. It goes through standard
%% error's process, so that it keeps its place among what the program
%% wrote there, and is flushed with it when the program ends. The runtime's
%% own subscriber of Process.faults (Appendix E.21).
%% Where standard error is neither a terminal nor a service manager's
%% journal, each line begins with the time, in UTC as RFC 3339 writes it.
report_fault({'FaultReport', Cause, _Process, Restarted, Site, Trace}, Stamped) ->
    Faulted = case Restarted of
                  true -> <<" faulted, restarted: ">>;
                  false -> <<" faulted: ">>
              end,
    Time = case Stamped of
               true -> [calendar:system_time_to_rfc3339(erlang:system_time(millisecond),
                                                        [{unit, millisecond}, {offset, "Z"}]),
                        " "];
               false -> []
           end,
    ern_rt:send(ern_rt:sys(stderr),
                iolist_to_binary([Time, Site, Faulted, ern_show:controls(Cause, line), "\n",
                                  ern_show:controls(iolist_to_binary(Trace), lines)])).

%% The options of a run that reports its faults. From the command line the
%% program writes to the process's own standard output and standard error,
%% through ports that learn when a stream has gone (report §8.2), and a
%% fault line carries its time where standard error is neither a terminal
%% nor a journal (§11.2); in a test, standard error is the test's device.
reporting(Opts, Err) ->
    case persistent_term:get({?MODULE, streams}, device) of
        fds ->
            Stamped = not ern_tty:is_terminal(stderr) andalso not journal(),
            Opts#{faults => fun(R) -> report_fault(R, Stamped) end,
                  stdout => {fd, 1}, stderr => {fd, 2}};
        device ->
            Opts#{faults => fun(R) -> report_fault(R, false) end,
                  stderr => fun(Bin) -> file:write(Err, Bin) end}
    end.

%% Report §11.2: whether standard error is a service manager's journal,
%% which systemd says by JOURNAL_STREAM, the device and inode of the
%% stream it gave, so that a stream a shell has since redirected is not.
journal() ->
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
    Bin = ern_build:read(File),
    case beam_lib:chunks(Bin, [binary_to_list(ern_iface:chunk_name())]) of
        {error, beam_lib, _} -> ern_build:fail(File ++ " is not a compiled module");
        {ok, _} -> Bin
    end.

%% The module of a `.erc`, its load path, and every module loaded for it:
%% the file's own dependencies first (report §11.2, §4.2).
program(File, Opts) ->
    filelib:is_regular(File) orelse ern_build:fail("no such file " ++ File),
    filename:extension(File) =:= ".erc" orelse ern_build:fail(File ++ " does not end in .erc"),
    Abs = ern_build:absolute(File),
    Bin = compiled(File),
    Ns = case ern_iface:read(Bin) of
             {ok, #{iface := #iface{namespace = N}}} -> N;
             {error, Why} -> ern_build:fail(File ++ ": " ++ Why)
         end,
    %% the root lies as many directories up as the namespace is deep
    Root = lists:foldl(fun(_, D) -> filename:dirname(D) end, Abs, Ns),
    ern_build:relative(Abs, Root) =:= ern_build:module_path(Ns) ++ ".erc" orelse
        ern_build:fail(File ++ " is not at the path of its namespace " ++ ern_build:qname(Ns)),
    Components = filename:split(filename:rootname(ern_build:module_path(Ns))),
    lists:foreach(fun(C) -> ern_build:shape(File, C) end, Components),
    Roots = [Root | ern_build:load_path(Opts)],
    host_path(Roots),
    {Ns, Roots, load(Ns, Roots, [])}.

%% Report §11.2: an Erlang module a `foreign fn` names is the host's own or
%% a `.beam` in a directory of the load path, the host's own found first.
%% The working directory, which the host puts on its code path, is neither,
%% unless it is a root of the load path.
host_path(Roots) ->
    _ = code:del_path("."),
    ok = code:add_pathsz(Roots).

%% Report §11.2: the interfaces of the modules loaded, which the shell puts
%% in the session's scope, each with the hash of the source it was compiled
%% from, which `:reload` compares against the source it finds; both are in
%% the `ErnI` chunk of the `.erc` it came from (§11.1).
ifaces(Loaded) ->
    [{I, H} || Mod <- lists:reverse(Loaded),
               {ok, Bin} <- [file:read_file(code:which(Mod))],
               {ok, #{iface := I, source_hash := H}} <- [ern_iface:read(Bin)]].

%% Report §11.2: where the startup files are, the person's first and then
%% the node's; the shell reads them and finds out whether they are there.
%% The node's is in the configuration directory of §11.3, and is run only
%% where `--config-dir` names that directory, never for the default, which
%% is wherever the shell was started. A file both paths name is run once.
%% A HOME that is no absolute path names no person's file, since it would
%% name one under wherever the shell was started.
startups(Opts) ->
    Home = case os:getenv("HOME") of
               false -> [];
               Dir ->
                   case filename:pathtype(Dir) of
                       absolute -> [filename:join([Dir, ".ernest", "startup"])];
                       _ -> []
                   end
           end,
    Node = case proplists:get_value(config_dir, Opts) of
               undefined -> [];
               Config -> [filename:join(Config, "startup")]
           end,
    case {Home, Node} of
        {[H], [N]} -> [H | [N || not same_file(H, N)]];
        _ -> Home ++ Node
    end.

%% Two paths to one file: both there, on one device, with one inode.
same_file(A, B) ->
    case {file:read_file_info(A), file:read_file_info(B)} of
        {{ok, #file_info{major_device = D, inode = I}},
         {ok, #file_info{major_device = D, inode = I}}} -> true;
        _ -> false
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

%% Report §11.2: the status a run ends `ern` with, and what it prints of
%% its entry process's end: nothing when it returned, `killed` when it was
%% killed, its fault, nothing for a signal, whose status is 128 plus its
%% number, and nothing for Os.exit, whose status is its own.
outcome(_Err, ok) -> 0;
outcome(_Err, {exit, Status}) -> Status;
%% report §8.2, §11.2: a stream that can no longer be written, as a shell
%% reports a broken pipe
outcome(_Err, {gone, _Stream}) -> 128 + 13;
outcome(Err, killed) -> io:format(Err, "killed~n", []), 1;
outcome(_Err, {signal, Signal}) -> ern_signals:status(Signal);
%% report §11.2: the entry process's fault has been reported as it happened
outcome(_Err, _Fault) -> 1.

%% Report §11.2: the shell reports the faults of the session's processes
%% itself, as a subscriber, so its own end, which no subscriber of its own
%% is left to see, is said here, its cause escaped as every fault's is. A
%% fault of the shell's own is a failure of ern itself, but for one its
%% standard input gave it (§11.8).
shell_outcome(Err, {fault, Msg}) ->
    io:format(Err, "fault: ~ts~n", [ern_show:controls(Msg, line)]),
    case ern_rt:by_input(Msg) of
        true -> 1;
        false -> 70
    end;
%% report §8.5, §11.2: a binding that faulted before the shell began
shell_outcome(Err, {initializer_fault, Site, Msg}) ->
    io:format(Err, "~ts faulted: ~ts~n", [Site, ern_show:controls(Msg, line)]),
    1;
shell_outcome(Err, {initializer_fault, Site, Msg, Trace}) ->
    io:format(Err, "~ts faulted: ~ts~n~ts",
              [Site, ern_show:controls(Msg, line), ern_show:controls(Trace, lines)]),
    1;
shell_outcome(Err, {fault, Msg, Trace}) ->
    io:format(Err, "fault: ~ts~n~ts",
              [ern_show:controls(Msg, line), ern_show:controls(Trace, lines)]),
    70;
shell_outcome(Err, Other) -> outcome(Err, Other).

%% Report §8.5: every top-level let of the loaded modules, dependencies
%% first, once the runtime has bound the system references.
init_fun(Loaded) ->
    fun() -> ern_rt:init_modules(lists:reverse(Loaded)) end.

%% Report §11.2: every test of the module, one at a time in the order the
%% module declares them, each in a process of its own and its line printed
%% as it ends; status 1 unless every one passed.
run_tests(Ns, Loaded, Err) ->
    Mod = ern_emitter:module_atom(Ns),
    Me = self(),
    Main = fun() ->
               Tests = case erlang:function_exported(Mod, '$tests', 0) of
                           true -> Mod:'$tests'();
                           false -> []
                       end,
               Names = [Name || {'Test', Name, _} <- Tests],
               %% report §11.2: a module without tests says so, and one two
               %% of whose tests have one name is refused before any runs
               case {Tests, Names -- lists:usort(Names)} of
                   {[], _} ->
                       ern_rt:send(ern_rt:sys(stdout), <<"no tests\n">>),
                       Me ! {ern_tests, true};
                   {_, [Twice | _]} ->
                       ern_rt:send(ern_rt:sys(stderr),
                                   <<"ern test: two tests are named \"",
                                     (ern_show:controls(Twice, line))/binary, "\"\n">>),
                       Me ! {ern_tests, false};
                   {_, []} ->
                       Passed = [run_test(T) || T <- Tests],
                       Me ! {ern_tests, lists:all(fun(P) -> P end, Passed)}
               end
           end,
    Site = unicode:characters_to_binary(ern_build:qname(Ns) ++ ".$tests"),
    %% report §11.2: a test's own fault is its line, and every other is
    %% reported as `ern run` reports it
    %% report §11.2: Os.exit faults the test that calls it
    Opts = reporting(#{init => init_fun(Loaded), exit => fault}, Err),
    Report = maps:get(faults, Opts),
    Reporter = fun(R) ->
                   element(3, R) =:= persistent_term:get({?MODULE, test}, none)
                       orelse Report(R)
               end,
    case ern_rt:run_main(Main, Site, Opts#{faults => Reporter}) of
        ok ->
            receive
                {ern_tests, true} -> 0;
                {ern_tests, false} -> 1
            end;
        Other ->
            outcome(Err, Other)
    end.

%% One test, Test(name, run) in canonical field order, in a process of its
%% own, monitored from its start so that a fault is reported, however soon
%% it comes, and not taken for the run's (report §6.9). A deadlock while it
%% runs is its fault (§11.2). Its line goes through standard output's
%% process, after what the test wrote there; whether it passed is returned.
run_test({'Test', Name, Run}) ->
    Me = ern_rt:self(),
    Ref = make_ref(),
    Pid = ern_rt:spawn_monitored('Local', fun() -> receive {Ref, go} -> Me ! {Ref, Run()} end end,
                                 fun(Down) -> {Ref, down, Down} end, Name),
    ok = ern_rt:deadlock_target(Pid),
    %% the reporter hears of the test's fault before this process does,
    %% so the test is known before it runs and forgotten only once its end
    %% is here
    persistent_term:put({?MODULE, test}, Pid),
    Pid ! {Ref, go},
    Outcome = receive
                  {Ref, 'Passed'} -> returned(Ref, <<"passed">>);
                  {Ref, {'Failed', Text}} ->
                      returned(Ref, <<"failed: ", (ern_show:controls(Text, line))/binary>>);
                  {Ref, down, {'Down', Reason, _}} -> <<"faulted: ", (cause(Reason))/binary>>
              end,
    ok = ern_rt:deadlock_target(none),
    persistent_term:erase({?MODULE, test}),
    %% report §11.2: a test's name is written as a cause is, its controls
    %% escaped
    ern_rt:send(ern_rt:sys(stdout),
                <<(ern_show:controls(Name, line))/binary, ": ", Outcome/binary, "\n">>),
    Outcome =:= <<"passed">>.

%% A test that returned still sends its Down; it is taken so that it is not
%% left in the runner's mailbox.
returned(Ref, Outcome) ->
    receive {Ref, down, _} -> Outcome end.

cause({'Fault', Msg}) -> ern_show:controls(Msg, line);
cause(Reason) -> atom_to_binary(Reason).

run_entry(Opts, Ns, Roots, Loaded, Arguments, Err) ->
    {EntryMod, EntryFn, Loaded1} = entry_point(Opts, Ns, Roots, Loaded),
    Init = init_fun(Loaded1),
    Site = entry_site(EntryMod, EntryFn),
    Fn = ern_emitter:function_atom(EntryFn),
    %% report §8.6: a deadlock is the entry process's fault
    outcome(Err, ern_rt:run_main(fun() -> EntryMod:Fn() end, Site,
                                 reporting(#{init => Init, arguments => Arguments}, Err))).

%% Report §11.2: the entry point the shell spawns beside it, or none for a
%% file without one, which is loaded to be tried. A `main` that is not an
%% entry point (§8.1) leaves the file without one; a function `--main`
%% names must be one.
shell_entry(Opts, Ns, Roots, Loaded) ->
    Mod = ern_emitter:module_atom(Ns),
    case proplists:get_value(main, Opts) =:= undefined
         andalso entry_shape(Mod, main) =/= entry of
        true ->
            {none, Loaded};
        false ->
            {EntryMod, EntryFn, Loaded1} = entry_point(Opts, Ns, Roots, Loaded),
            {{EntryMod, EntryFn, entry_site(EntryMod, EntryFn)}, Loaded1}
    end.

%% Report §8.1: the entry point, the loaded module's `main` or the function
%% `--main` names, and every module loaded for it. It is an exported `fn`
%% of type `() -> Unit`, with a mailbox type or pure; a top-level `let`,
%% and a function of another shape, is refused.
entry_point(Opts, Ns, Roots, Loaded) ->
    {EntryMod, EntryFn, Loaded1} =
        case proplists:get_value(main, Opts) of
            undefined -> {ern_emitter:module_atom(Ns), main, Loaded};
            Q ->
                {MainNs, Fn} = main_name(Q),
                {ern_emitter:module_atom(MainNs), Fn, load(MainNs, Roots, Loaded)}
        end,
    Name = ern_build:qname(entry_ns(EntryMod) ++ [EntryFn]),
    Shape = "; an entry point is an exported fn of type () -> Unit (report §8.1)",
    case entry_shape(EntryMod, EntryFn) of
        entry -> ok;
        missing -> ern_build:fail("no exported function " ++ Name ++ Shape);
        {'let', Type} ->
            ern_build:fail(Name ++ " is not an entry point: it is a let of type " ++ Type ++ Shape);
        {other, Type} ->
            ern_build:fail(Name ++ " is not an entry point: its type is " ++ Type ++ Shape)
    end,
    {EntryMod, EntryFn, Loaded1}.

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
entry_shape(Mod, Fn) ->
    {ok, Bin} = file:read_file(code:which(Mod)),
    {ok, #{iface := #iface{namespace = Ns, values = Values, lets = Lets}}} =
        ern_iface:read(Bin),
    Q = Ns ++ [Fn],
    case maps:find(Q, Values) of
        error ->
            missing;
        {ok, #scheme{type = T} = Scheme} ->
            Type = ern_types:format_scheme(Scheme, ern_types:new()),
            case {lists:member(Q, Lets), T} of
                {true, _} -> {'let', Type};
                {false, {tfn, [], _, {tcon, ['Unit'], []}}} -> entry;
                {false, {tfn, [], _, {tvar, _}}} -> entry;
                {false, _} -> {other, Type}
            end
    end.

entry_site(Mod, Fn) ->
    unicode:characters_to_binary(ern_build:qname(entry_ns(Mod)) ++ "." ++ atom_to_list(Fn)).

entry_ns(Mod) ->
    "ern@" ++ Path = atom_to_list(Mod),
    ern_build:namespace(string:split(Path, "@", all)).

%% Load a module and, first, its dependencies, each once; the result lists
%% modules most recently loaded first, so dependencies come last.
load(Ns, Roots, Loaded) ->
    load(Ns, Roots, Loaded, ern_build:stdlib_hash(".")).

load(Ns, Roots, Loaded, Std) ->
    Mod = ern_emitter:module_atom(Ns),
    case lists:member(Mod, Loaded) of
        true -> Loaded;
        false ->
            Rel = ern_build:module_path(Ns) ++ ".erc",
            File = case [F || R <- Roots, F <- [filename:join(R, Rel)], filelib:is_regular(F)] of
                       [F | _] -> F;
                       [] -> ern_build:fail("cannot find module " ++ ern_build:qname(Ns)
                                            ++ " (" ++ Rel ++ ") on the load path")
                   end,
            Bin = ern_build:read(File),
            {Deps, Chunk} = case ern_iface:read(Bin) of
                                {ok, #{deps := Ds} = C} -> {Ds, C};
                                {error, Why} -> ern_build:fail(File ++ ": " ++ Why)
                            end,
            %% report §11.2: a module is found by its namespace, and a file
            %% there holding another is no module of that name
            case Chunk of
                #{iface := #iface{namespace = Ns}} -> ok;
                #{iface := #iface{namespace = Held}} ->
                    ern_build:fail(ern_build:shown(File) ++ " holds " ++ ern_build:qname(Held)
                                   ++ ", not " ++ ern_build:qname(Ns) ++ "; build it again from"
                                   " its source root")
            end,
            Loaded1 = lists:foldl(fun({D, _}, L) -> load(D, Roots, L, Std) end, Loaded, Deps),
            %% report §11.2: a module compiled against another interface of a
            %% module it uses, or of the standard library, is refused, not run
            %% to fault where they differ
            lists:foreach(fun({D, Hash}) -> same_interface(Ns, D, Hash) end, Deps),
            lists:member(maps:get(stdlib, Chunk, none), [none, Std])
                orelse ern_build:fail(ern_build:qname(Ns) ++ " was compiled against another"
                                      " standard library; build " ++ ern_build:qname(Ns)
                                      ++ " again"),
            code:purge(Mod),
            case code:load_binary(Mod, File, Bin) of
                {module, Mod} -> [Mod | Loaded1];
                {error, What} ->
                    ern_build:fail("cannot load " ++ File ++ ": " ++ atom_to_list(What))
            end
    end.

same_interface(Ns, D, Hash) ->
    {ok, Bin} = file:read_file(code:which(ern_emitter:module_atom(D))),
    {ok, #{iface := I}} = ern_iface:read(Bin),
    ern_iface:hash(I) =:= Hash
        orelse ern_build:fail(ern_build:qname(Ns) ++ " was compiled against another "
                              ++ ern_build:qname(D) ++ "; build " ++ ern_build:qname(Ns)
                              ++ " again").

%% Report §11.3, Appendix C: the configuration directory itself, with a
%% configuration of no peers and this node's key pair; the network address
%% is a placeholder to edit. The directory is made here or not at all, so
%% that one another made first, as this runs, is refused, and it is its
%% owner's alone before a file is written in it, so that no one else can
%% open a file there, the key's while it is being written among them. A
%% name ending in `/` names the directory before it.
create_config_dir(Given) ->
    Conf = filename:join([Given]),
    ok = ern_build:made_dir(Conf),
    case file:make_dir(Conf) of
        ok -> ok = file:change_mode(Conf, 8#700);
        {error, eexist} -> ern_build:fail(Conf ++ " exists");
        {error, Reason} -> ern_build:fail(Conf ++ ": " ++ file:format_error(Reason))
    end,
    Key = public_key:generate_key({namedCurve, ed25519}),
    Private = public_key:pem_encode([public_key:pem_entry_encode('PrivateKeyInfo', Key)]),
    %% the key names its curve, {namedCurve, Oid}, as its parameters
    {'ECPrivateKey', _, _, Curve, PublicPoint, _} = Key,
    Public = public_key:pem_encode(
               [public_key:pem_entry_encode('SubjectPublicKeyInfo',
                                            {{'ECPoint', PublicPoint}, Curve})]),
    %% laid out as Appendix C shows it, in its order, each value as JSON
    %% writes it; a PEM's line breaks are escapes, as in any JSON string
    Json = ["{\n",
            "  \"network-address\": ", json:encode(<<"127.0.0.1:8654">>), ",\n",
            "  \"public-key\": ", json:encode(Public), ",\n",
            "  \"peers\": []\n",
            "}\n"],
    ok = ern_build:write_whole(filename:join(Conf, "ernest.conf"), Json),
    %% the key is its owner's alone before it is written
    ok = ern_build:write_whole(filename:join(Conf, "private-key.pem"), Private, 8#600),
    0.

usage_fail(Msg) ->
    throw({cli_usage, lists:flatten(Msg)}).
