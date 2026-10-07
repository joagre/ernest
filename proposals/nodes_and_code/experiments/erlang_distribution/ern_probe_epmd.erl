%% A table in place of the port-mapper daemon: a node's name gives its port.
%% Node d has none: it does not listen, and no node can dial it. Node e is
%% no node: its address is one that nothing answers from. Node f reaches b
%% through the proxy where ERN_PROBE_B_PORT names the proxy's port.
%% Erlang calls this module where `-epmd_module ern_probe_epmd` names it.
-module(ern_probe_epmd).

-export([start_link/0, register_node/2, register_node/3, port_please/2, port_please/3,
         address_please/3, listen_port_please/2, names/1]).

-spec start_link() -> ignore.
start_link() -> ignore.

-spec register_node(term(), inet:port_number()) -> {ok, pos_integer()}.
register_node(Name, Port) -> register_node(Name, Port, inet).

%% The number answered is the node's creation, which marks the pids of this start.
-spec register_node(term(), inet:port_number(), atom()) -> {ok, pos_integer()}.
register_node(_Name, _Port, _Family) ->
    {ok, erlang:unique_integer([positive]) rem 16#7fffffff + 1}.

-spec port_please(term(), term()) -> {port, inet:port_number(), 6} | noport.
port_please(Name, Host) -> port_please(Name, Host, infinity).

-spec port_please(term(), term(), timeout()) -> {port, inet:port_number(), 6} | noport.
port_please(Name, _Host, _Timeout) ->
    case port(Name) of
        none -> noport;
        Port -> {port, Port, 6}
    end.

-spec address_please(term(), term(), atom()) ->
          {ok, inet:ip_address(), inet:port_number(), 6} | {error, nxdomain}.
address_please(Name, _Host, _Family) ->
    case port(Name) of
        none -> {error, nxdomain};
        Port -> {ok, ip(Name), Port, 6}
    end.

-spec listen_port_please(term(), term()) -> {ok, inet:port_number()}.
listen_port_please(Name, _Host) ->
    case port(Name) of
        none -> {ok, 0};
        Port -> {ok, Port}
    end.

-spec names(term()) -> {error, address}.
names(_Host) -> {error, address}.

%% The host passes a name as a string, an atom or a binary.
port(Name) when is_atom(Name) -> port(atom_to_list(Name));
port(Name) when is_binary(Name) -> port(binary_to_list(Name));
port("a" ++ _) -> 47101;
port("b" ++ _) ->
    case os:getenv("ERN_PROBE_B_PORT") of
        false -> 47102;
        Port -> list_to_integer(Port)
    end;
port("c" ++ _) -> 47103;
port("d" ++ _) -> none;
port("e" ++ _) -> 47105;
port("f" ++ _) -> 47107.

ip(Name) when is_atom(Name) -> ip(atom_to_list(Name));
ip(Name) when is_binary(Name) -> ip(binary_to_list(Name));
ip("e" ++ _) -> {192, 0, 2, 1};
ip(_Name) -> {127, 0, 0, 1}.
