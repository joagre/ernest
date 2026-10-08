%% Report §8.7: no port-mapper daemon. A node finds a peer's address in its
%% configuration and nowhere else, so this module answers the host in the
%% daemon's place, where `-epmd_module ern_epmd` names it (ern_carrier's
%% boot flags): a peer's address by the name on the carrier, its key's
%% digest, the name a peer's `network-address` holds resolved at each dial;
%% this node's port from `listen`; and the number of this start, which the
%% host puts in every address. A callback module the host calls, not a
%% process of the toolchain's own (docs/style.md).
-module(ern_epmd).

-export([start_link/0, register_node/2, register_node/3, port_please/2, port_please/3,
         address_please/3, listen_port_please/2, names/1]).

-include("ern_node.hrl").

%% The distribution protocol's version the host speaks.
-define(DISTRIBUTION, 6).

%% No process: the configuration answers.
-spec start_link() -> ignore.
start_link() ->
    ignore.

-spec register_node(term(), inet:port_number()) -> {ok, pos_integer()}.
register_node(Name, Port) ->
    register_node(Name, Port, inet).

%% Report §8.7: the number of this start, drawn, which marks every address
%% of the start; and the port the listener bound, which the node says where
%% `listen` let the host pick it.
-spec register_node(term(), inet:port_number(), atom()) -> {ok, pos_integer()}.
register_node(_Name, Port, _Family) ->
    case ern_carrier:configuration() of
        #configuration{listen = {_, 0}} -> ern_carrier:say(["listening on port ",
                                                             integer_to_list(Port)]);
        _ -> ok
    end,
    {ok, rand:uniform(16#7fffffff)}.

-spec port_please(term(), term()) -> {port, inet:port_number(), pos_integer()} | noport.
port_please(Name, Host) ->
    port_please(Name, Host, infinity).

-spec port_please(term(), term(), timeout()) ->
          {port, inet:port_number(), pos_integer()} | noport.
port_please(Name, _Host, _Timeout) ->
    case ern_carrier:peer(text(Name)) of
        #peer{address = {_, Port}} -> {port, Port, ?DISTRIBUTION};
        _ -> noport
    end.

%% Report §8.7: a peer's address, a name the host resolves at each dial in
%% the node's family, or none for a peer listed without one, or for a node
%% listed by no peer, which is never dialled.
-spec address_please(term(), term(), inet:address_family()) ->
          {ok, inet:ip_address(), inet:port_number(), pos_integer()} | {error, term()}.
address_please(Name, _Host, Family) ->
    case ern_carrier:peer(text(Name)) of
        #peer{address = {Host, Port}} when is_tuple(Host) ->
            {ok, Host, Port, ?DISTRIBUTION};
        #peer{address = {Host, Port}} ->
            case inet:getaddr(Host, Family) of
                {ok, Address} -> {ok, Address, Port, ?DISTRIBUTION};
                {error, _} = Error -> Error
            end;
        _ ->
            {error, nxdomain}
    end.

%% Report §8.7: this node's listener's port, 0 for one the host picks.
-spec listen_port_please(term(), term()) -> {ok, inet:port_number()}.
listen_port_please(_Name, _Host) ->
    case ern_carrier:configuration() of
        #configuration{listen = {_, Port}} -> {ok, Port};
        _ -> {ok, 0}
    end.

%% No node is listed by asking a host.
-spec names(term()) -> {error, address}.
names(_Host) ->
    {error, address}.

%% The host passes a name as a string, an atom or a binary.
text(Name) when is_atom(Name) -> atom_to_list(Name);
text(Name) when is_binary(Name) -> binary_to_list(Name);
text(Name) -> Name.
