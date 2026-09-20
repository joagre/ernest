%% Target: what ernc produces for examples/counter.ern. Hand-written first,
%% run against ern_rt, then the golden test for the emitter.
%%
%% Values follow the ABI of report §8.4. The type
%%
%%   type CounterMsg
%%       = Inc(Int)
%%       | Get(reply : Reply(Int))
%%       | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)
%%
%% has no code of its own; its constructors are the tuples
%%
%%   Inc(k)                          {'Inc', K}
%%   Get(reply = r)                  {'Get', R}
%%   Upgrade(migrate = m, next = k)  {'Upgrade', M, K}     fields in canonical
%%                                                         (sorted) order
%%
%% The module atom is the module's path with @ for / and the prefix ern@,
%% as Gleam names gleam@list, so Ernest never claims a bare name on the BEAM.
%% Functions keep their local names; only exported ones are exported. Every
%% Address is a pid, a Reply is an alias, and the process primitives go
%% through ern_rt (plan 2.4). spawn gets a third argument naming the spawn
%% site for Down (report §6.9). Int arithmetic is emitted inline; String.<>
%% is binary concatenation; stdlib calls go to the namespace's module,
%% 'ern@int' for Int. A reply a call observes is checked against the
%% declared type through ern_boundary (report §8.4), the type described once
%% per module by a '$type_N' function; a message from a foreign process is
%% checked by the proxy that delivered it, so a receive checks nothing.
%%
%% The compiler also adds the module's interface as the BEAM chunk "ErnI".

-module('ern@counter').

-export([main/0]).

%% export fn main() -> Unit with m = {
%%     let c = spawn(Local, fn() = counter(0));
%%     send(c, Inc(5));
%%     send(c, Inc(3));
%%     match Address.call(c, fn(r) = Get(reply = r), 1000) {
%%         Some(n) -> Io.println("count is " <> Int.toString(n))
%%       | None -> Io.println("counter is not answering")
%%     }
%% }
main() ->
    C = ern_rt:spawn('Local', fun() -> counter(0) end, <<"Counter.main:17">>),
    ern_rt:send(C, {'Inc', 5}),
    ern_rt:send(C, {'Inc', 3}),
    case ern_boundary:value('$type_1'(), ern_rt:call(C, fun(R) -> {'Get', R} end, 1000),
                         <<"reply does not match Optional(Int)">>) of
        {'Some', N} ->
            'ern@io':println(<<"count is ", ('ern@int':toString(N))/binary>>);
        'None' ->
            'ern@io':println(<<"counter is not answering">>)
    end.

%% fn counter(n : Int) -> Unit with CounterMsg = receive {
%%     Inc(k) -> counter(n + k)
%%   | Get(reply = r) -> { answer(r, n); counter(n) }
%%   | Upgrade(migrate = m, next = k) -> k(m(n))
%% }
counter(N) ->
    receive
        {'Inc', K} ->
            counter(N + K);
        {'Get', R} ->
            ern_rt:answer(R, N),
            counter(N);
        {'Upgrade', M, K} ->
            K(M(N))
    end.

'$type_1'() -> {con, [{'None', []}, {'Some', [int]}]}.
