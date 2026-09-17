#!/usr/bin/env escript
%% Compile Erlang sources whose module atom differs from the file name into
%% Ebin, naming each beam after its atom. Used by the per-application
%% Makefiles for modules implementing Ernest namespaces, 'Ernest.Io' in
%% ernest_io.erl, which erlc refuses to compile from a file of another name.
%%
%%   escript compile_ns.escript Ebin File.erl ...

main([Ebin | Files]) ->
    lists:foreach(fun(File) -> compile(Ebin, File) end, Files);
main(_) ->
    io:format("usage: compile_ns.escript Ebin File.erl ...~n"),
    halt(2).

compile(Ebin, File) ->
    {ok, Forms} = epp:parse_file(File, [{includes, ["../include"]}]),
    Opts = [debug_info, return_errors, return_warnings, warnings_as_errors],
    case compile:forms(Forms, Opts) of
        {ok, Module, Bin, _Warnings} ->
            Out = filename:join(Ebin, atom_to_list(Module) ++ ".beam"),
            ok = file:write_file(Out, Bin);
        {error, Errors, Warnings} ->
            report(Errors),
            report(Warnings),
            halt(1)
    end.

report(PerFile) ->
    lists:foreach(fun({File, Items}) ->
                      lists:foreach(fun({Line, Mod, Desc}) ->
                                        io:format("~s:~p: ~s~n",
                                                  [File, Line, Mod:format_error(Desc)])
                                    end, Items)
                  end, PerFile).
