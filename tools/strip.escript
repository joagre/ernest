#!/usr/bin/env escript
%% -*- erlang -*-
%% The installation's modules without the host's debug information
%% (docs/install.md): every .beam and .erc under the directory given,
%% stripped in place of every chunk the host does not load with, but for
%% Ernest's ErnI and the host's EEP 48 Docs, which its tools read. The host's
%% development tools, cover, xref and dialyzer, read what goes, and they
%% run in the checkout.

main([Dir]) ->
    Files = filelib:wildcard(filename:join(Dir, "**/*.{beam,erc}")),
    lists:foreach(fun(File) ->
                      {ok, Beam} = file:read_file(File),
                      {ok, {_, Stripped}} = beam_lib:strip(Beam, ["ErnI", "Docs"]),
                      ok = file:write_file(File, Stripped)
                  end, Files).
