%% Target: what ern build produces for examples/hello.ern. Hand-written first, run
%% against ern_rt, then the golden test for the emitter. The module atom is
%% the module's path with @ for / and the prefix ern@, so Ernest never
%% claims a bare name on the BEAM (plan 2.4); the file is compiled from
%% forms, never with erlc, so its name is free. A unit's functions are
%% named by their position in it (report §11.1): main, the module's first
%% definition, is '$1', and Io.println is the function at its position in
%% the standard library's unit, so this target changes where io.ern's
%% positions do.
%%
%%   export fn main() : Unit = Io.println("hello, world")
%%
%% The compiler also adds the module's interface as the BEAM chunk "ErnI".

-module('ern@hello').

%% report §3.9: a function that never returns is meant, which Dialyzer is told
-dialyzer(no_return).

-export(['$1'/0, '$spawned'/2]).

%% Hello.main
'$1'() ->
    'ern@io':'$8'(<<"hello, world">>).

%% A function of this module a spawn on a peer may start, by its position,
%% run in the calling process over what it captured, as the peer's code
%% table finds it by its identity (report §8.7).
'$spawned'('$1', []) -> '$1'().
