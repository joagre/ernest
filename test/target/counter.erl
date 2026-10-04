%% Target: what ern build produces for examples/counter.ern. Hand-written first,
%% run against ern_rt, then the golden test for the emitter.
%%
%% Values follow the ABI of report §8.4. The type
%%
%%   type CounterMsg =
%%       Inc(Int)
%%     | Get(reply : Reply(Int))
%%     | Upgrade(migrate : (Int) -> Int, next : (Int) -> Unit with CounterMsg)
%%
%% has no code of its own; its constructors are the tuples
%%
%%   Inc(amount)                                {'Inc', Amount}
%%   Get(reply = reply)                         {'Get', Reply}
%%   Upgrade(migrate = migrate, next = next)    {'Upgrade', Migrate, Next}, fields
%%                                              in canonical (sorted) order
%%
%% The module atom is the module's path with @ for / and the prefix ern@,
%% as Gleam names gleam@list, so Ernest never claims a bare name on the BEAM.
%% Functions keep their local names; only exported ones are exported. Every
%% Address is a pid, a Reply is an alias, and the process primitives go
%% through ern_rt (plan 2.4). spawn gets a third argument naming the spawn
%% site for Down (report §6.9). Int arithmetic is emitted inline; String.<>
%% is binary concatenation; stdlib calls go to the namespace's module,
%% 'ern@int' for Int. A call gives the runtime what an answer from foreign
%% code is checked by, the reply's descriptor and the fault's text, and a
%% message from a foreign process is checked by the proxy that delivered
%% it, so a receive checks nothing (report §8.4).
%%
%% The compiler also adds the module's interface as the BEAM chunk "ErnI".

-module('ern@counter').

-export([main/0, '$fun'/2]).

%% export fn main() : Unit with m = {
%%     let counter = spawn(fn() = count(0));
%%     send(counter, Inc(5));
%%     send(counter, Inc(3));
%%     match Address.call(counter, fn(reply) = Get(reply = reply), 1000) {
%%         Some(total) -> Io.println("count is " <> Int.toString(total))
%%       | None -> Io.println("counter is not answering")
%%     }
%% }
main() ->
    Counter = ern_rt:spawn(fun() -> count(0) end, <<"Counter.main:17">>),
    ern_rt:send(Counter, {'Inc', 5}),
    ern_rt:send(Counter, {'Inc', 3}),
    case ern_rt:call(Counter, fun(Reply) -> {'Get', Reply} end, 1000,
                     {int, <<"reply does not match Int">>}) of
        {'Some', Total} ->
            'ern@io':println(<<"count is ", ('ern@int':toString(Total))/binary>>);
        'None' ->
            'ern@io':println(<<"counter is not answering">>)
    end.

%% fn count(total : Int) : Unit with CounterMsg = receive {
%%     Inc(amount) -> count(total + amount)
%%   | Get(reply = reply) -> { answer(reply, total); count(total) }
%%   | Upgrade(migrate = migrate, next = next) -> next(migrate(total))
%% }
%%
%% Every receive takes first the restart a supervisor asks for (report
%% §6.9), which arrives before every other message, and then the fault a
%% foreign message that did not match left in its place (§8.4).
count(Total) ->
    receive
        '$ern_restart' ->
            ern_rt:restart_now();
        {'$ern_fault', Cause} ->
            ern_rt:fault(Cause);
        {'Inc', Amount} ->
            count(Total + Amount);
        {'Get', Reply} ->
            ern_rt:answer(Reply, Total),
            count(Total);
        {'Upgrade', Migrate, Next} ->
            Next(Migrate(Total))
    end.

%% A function of this module taken as a value by another is a fun made here,
%% which keeps this version when the module is loaded again (report §11.2).
'$fun'(main, 0) -> fun main/0.
