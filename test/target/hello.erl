%% Target: what ern build produces for examples/hello.ern. Hand-written first, run
%% against ern_rt, then the golden test for the emitter. The module atom is
%% the module's path with @ for / and the prefix ern@, so Ernest never
%% claims a bare name on the BEAM (plan 2.4); the file is compiled from
%% forms, never with erlc, so its name is free.
%%
%%   export fn main() -> Unit with Never = Io.println("hello, world")
%%
%% The compiler also adds the module's interface as the BEAM chunk "ErnI".

-module('ern@hello').

-export([main/0, '$fun'/2]).

main() ->
    'ern@io':println(<<"hello, world">>).

%% A function of this module taken as a value by another is a fun made here,
%% which keeps this version when the module is loaded again (report §11.2).
'$fun'(main, 0) -> fun main/0.
