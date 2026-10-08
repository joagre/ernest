%% Report §8.7: what the programs of test/peers/ ask of the host and no
%% module of Ernest's gives, for the tests alone: the count of the node's
%% atoms, the count of the notes of calls on a callee it keeps for other
%% nodes, and a
%% connection ended by a frame its peer's gateway cannot read.
-module(ern_peers_host).

-export([atoms/0, notes/1, sever/1]).

-spec atoms() -> non_neg_integer().
atoms() ->
    erlang:system_info(atom_count).

-spec notes(pid()) -> non_neg_integer().
notes(Callee) ->
    ets:select_count(ern_notes, [{{'_', Callee, '_'}, [], [true]}]).

-spec sever(pid()) -> 'Unit'.
sever(Pid) ->
    erlang:send({ern_gateway, node(Pid)}, {ern_frame, self(), unreadable}),
    'Unit'.
