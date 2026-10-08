%% A node's configuration, as its directory's `ernest.conf` says it (report
%% §8.7, Appendix C), which ern_node reads and ern_carrier starts the node's
%% carrier from.

%% listen: none or {Address, Port}, the listener's interface and port;
%% public_key: the DER of this node's SubjectPublicKeyInfo; peers: [#peer{}]
%% in the file's order; keys: a key's name to its peers' names, in the order
%% a find asks them; measures: the host's measures to start, each to its
%% parameters; dir: the configuration directory, whose key and certificate
%% the carrier's TLS takes.
-record(configuration, {dir, listen = none, public_key, peers = [], keys = #{}, measures = #{}}).

%% A peer as listed: address none, or {Host, Port}, Host a name or an
%% address the host resolves at each dial.
-record(peer, {name, public_key, address = none}).
