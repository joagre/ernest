%% Target: what ernc produces for examples/hello.ern. Hand-written first, run
%% against ern_rt, then the golden test for the emitter. The module atom is
%% the namespace with the 'Ernest.' prefix, so Ernest never claims a bare
%% name on the BEAM (plan 2.4); the file is compiled from forms, never with
%% erlc, so its name is free.
%%
%%   export fn main() -> Unit with Never = Io.println("hello, world")
%%
%% The compiler also adds the module's interface as the BEAM chunk "ErnI".

-module('Ernest.Hello').

-export([main/0]).

main() ->
    'Ernest.Io':println(<<"hello, world">>).
