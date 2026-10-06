%% A table in place of the port-mapper daemon: a node's name gives its port.
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

-spec port_please(term(), term()) -> {port, inet:port_number(), 6}.
port_please(Name, Host) -> port_please(Name, Host, infinity).

-spec port_please(term(), term(), timeout()) -> {port, inet:port_number(), 6}.
port_please(Name, _Host, _Timeout) -> {port, port(Name), 6}.

-spec address_please(term(), term(), atom()) ->
          {ok, inet:ip_address(), inet:port_number(), 6}.
address_please(Name, _Host, _Family) -> {ok, {127, 0, 0, 1}, port(Name), 6}.

-spec listen_port_please(term(), term()) -> {ok, inet:port_number()}.
listen_port_please(Name, _Host) -> {ok, port(Name)}.

-spec names(term()) -> {error, address}.
names(_Host) -> {error, address}.

%% The host passes a name as a string, an atom or a binary.
port(Name) when is_atom(Name) -> port(atom_to_list(Name));
port(Name) when is_binary(Name) -> port(binary_to_list(Name));
port("a" ++ _) -> 47101;
port("b" ++ _) -> 47102;
port("c" ++ _) -> 47103.
