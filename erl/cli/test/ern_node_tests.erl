%% A node's configuration directory (report §8.3, §8.7, §11.3, Appendix C):
%% what `ern config` makes, what a node checks and reads of it as it
%% starts, its `ernest.pid`, and the host's measures it starts.
-module(ern_node_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("public_key/include/public_key.hrl").

tmp() ->
    Base = os:getenv("ERN_TEST_DIR", os:getenv("TMPDIR", "/tmp")),
    Dir = filename:join(Base, "ern_node_" ++ os:getpid() ++ "_"
                              ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(Dir),
    Dir.

%% A directory `ern config` made.
made() ->
    Dir = filename:join(tmp(), "node"),
    _ = ern_node:create(Dir),
    Dir.

%% The refusal `ern_node` throws, as the runner prints it.
refusal(Fun) ->
    try Fun() of
        Result -> {accepted, Result}
    catch
        throw:{cli_error, Message} -> Message
    end.

%% ernest.conf of the directory written as Text.
conf(Dir, Text) ->
    ok = file:write_file(filename:join(Dir, "ernest.conf"), Text).

public(Dir) ->
    {ok, Text} = file:read_file(filename:join(Dir, "ernest.conf")),
    maps:get(<<"public-key">>, json:decode(Text)).

%% A peer's public key, another directory's.
other_key() ->
    public(made()).

%% ernest.conf of Dir with its own key and the fields given, laid out as
%% JSON writes it.
with(Dir, Fields) ->
    conf(Dir, json:encode(maps:merge(#{<<"public-key">> => public(Dir)}, Fields))).

ends(Message, Suffix) ->
    lists:suffix(Suffix, Message).

%% report §11.3, Appendix C: `ern config` makes the directory, its owner's
%% alone, with an ed25519 key readable by its owner alone, the certificate
%% the node signs itself, its name a constant and its validity the longest,
%% and `ernest.conf` with the key's public half, no peer and no key; it
%% answers the public key
create_test() ->
    Dir = filename:join(tmp(), "node"),
    Public = ern_node:create(Dir),
    {ok, #file_info{mode = DirMode}} = file:read_file_info(Dir),
    ?assertEqual(8#700, DirMode band 8#777),
    {ok, #file_info{mode = KeyMode}} = file:read_file_info(filename:join(Dir, "private-key.pem")),
    ?assertEqual(8#600, KeyMode band 8#777),
    ?assertEqual(Public, public(Dir)),
    ?assertMatch(<<"-----BEGIN PUBLIC KEY-----\n", _/binary>>, Public),
    ?assertEqual($\n, binary:last(Public)),
    ?assertNotEqual(<<"\n\n">>, binary:part(Public, byte_size(Public), -2)),
    {ok, KeyPem} = file:read_file(filename:join(Dir, "private-key.pem")),
    [KeyEntry] = public_key:pem_decode(KeyPem),
    ?assertMatch({'ECPrivateKey', _, _, {namedCurve, ?'id-Ed25519'}, _, _},
                 public_key:pem_entry_decode(KeyEntry)),
    {ok, CertificatePem} = file:read_file(filename:join(Dir, "certificate.pem")),
    [{'Certificate', Der, not_encrypted}] = public_key:pem_decode(CertificatePem),
    #'OTPCertificate'{tbsCertificate = Tbs} = Certificate = public_key:pkix_decode_cert(Der, otp),
    ?assertEqual(Tbs#'OTPTBSCertificate'.issuer, Tbs#'OTPTBSCertificate'.subject),
    ?assertMatch({rdnSequence, [[#'AttributeTypeAndValue'{type = ?'id-at-commonName',
                                                          value = {utf8String, <<"ernest">>}}]]},
                 Tbs#'OTPTBSCertificate'.subject),
    ?assertEqual(#'Validity'{notBefore = {utcTime, "700101000000Z"},
                             notAfter = {generalTime, "99991231235959Z"}},
                 Tbs#'OTPTBSCertificate'.validity),
    %% signed by the node's own key
    [SpkiEntry] = public_key:pem_decode(Public),
    ?assert(public_key:pkix_verify(Der, public_key:pem_entry_decode(SpkiEntry))),
    ?assert(public_key:pkix_is_self_signed(Certificate)),
    ?assertEqual(<<"node exists">>,
                 iolist_to_binary(lists:last(string:split(refusal(fun() ->
                                                                      ern_node:create(Dir)
                                                                  end), "/", trailing)))),
    %% what it makes, a node reads
    ?assertMatch({configuration, _, {{0, 0, 0, 0}, 8654}, _, [], #{}, #{}}, ern_node:read(Dir)).

%% report §8.7, Appendix C: what ernest.conf may say, read whole: a
%% listener of IPv6, peers with an address, a name, or none, keys naming
%% them in the order a find asks them, and the host's measures
read_test() ->
    Dir = made(),
    One = other_key(),
    Two = other_key(),
    with(Dir, #{<<"listen">> => <<"[::]:0">>,
                <<"peers">> => [#{<<"name">> => <<"store">>, <<"public-key">> => One,
                                  <<"network-address">> => <<"[::1]:8654">>},
                                #{<<"name">> => <<"desk">>, <<"public-key">> => Two}],
                <<"keys">> => #{<<"counter">> => [<<"desk">>, <<"store">>]},
                <<"measures">> => #{<<"cpu">> => #{},
                                    <<"memory">> => #{<<"check-interval">> => 120000,
                                                      <<"almost-full">> => 0.9},
                                    <<"disk">> => #{<<"check-interval">> => 500}}}),
    {configuration, _, Listen, _, Peers, Keys, Measures} = ern_node:read(Dir),
    ?assertEqual({{0, 0, 0, 0, 0, 0, 0, 0}, 0}, Listen),
    ?assertMatch([{peer, <<"store">>, _, {{0, 0, 0, 0, 0, 0, 0, 1}, 8654}},
                  {peer, <<"desk">>, _, none}], Peers),
    ?assertEqual(#{<<"counter">> => [<<"desk">>, <<"store">>]}, Keys),
    ?assertEqual(#{cpu => #{}, memory => #{check_interval => 120000, almost_full => 0.9},
                   disk => #{check_interval => 500}}, Measures),
    %% a node without a listener runs over IPv4, and a peer's name is
    %% kept for the dial, which resolves it
    with(Dir, #{<<"peers">> => [#{<<"name">> => <<"store">>, <<"public-key">> => One,
                                  <<"network-address">> => <<"localhost:8654">>}]}),
    ?assertMatch({configuration, _, none, _, [{peer, <<"store">>, _, {"localhost", 8654}}], _, _},
                 ern_node:read(Dir)).

%% report §8.7, Appendix C: what ernest.conf may not say, each refused when
%% the file is read, naming the file and why
read_refusals_test() ->
    Dir = made(),
    Own = public(Dir),
    One = other_key(),
    Peer = fun(Fields) -> maps:merge(#{<<"name">> => <<"store">>, <<"public-key">> => One},
                                     Fields)
           end,
    Refused = fun(Fields) ->
                  conf(Dir, json:encode(maps:merge(#{<<"public-key">> => Own}, Fields))),
                  refusal(fun() -> ern_node:read(Dir) end)
              end,
    Cases =
        [{fun() -> conf(Dir, <<"{">>) end, "is not JSON"},
         {fun() -> conf(Dir, <<"{} {}">>) end, "holds more than one JSON value"},
         {fun() -> conf(Dir, <<"[]">>) end, "the file is not a JSON object"},
         {fun() -> conf(Dir, <<"{\"peers\": [], \"peers\": []}">>) end,
          "the file gives peers twice"},
         {#{<<"port">> => 1}, "the file has the unknown field port"},
         {#{<<"drain">> => 60000}, "the file has the unknown field drain"},
         {#{<<"listen">> => <<"8654">>}, "listen is not address:port: \"8654\""},
         {#{<<"listen">> => <<"node.example:8654">>},
          "listen names no address: \"node.example:8654\""},
         {#{<<"listen">> => <<"0.0.0.0:65536">>}, "listen is not address:port: \"0.0.0.0:65536\""},
         {#{<<"public-key">> => One}, "public-key is not the key of private-key.pem"},
         {#{<<"public-key">> => <<"key">>}, "public-key is not one public key in PEM"},
         {#{<<"peers">> => #{}}, "peers is not a JSON array"},
         {#{<<"peers">> => [#{<<"public-key">> => One}]}, "a peer has no name"},
         {#{<<"peers">> => [Peer(#{<<"coordinator">> => true})]},
          "a peer has the unknown field coordinator"},
         {#{<<"peers">> => [#{<<"name">> => <<"store">>}]}, "peer \"store\" has no public-key"},
         {#{<<"peers">> => [Peer(#{}), Peer(#{<<"public-key">> => other_key()})]},
          "two peers are named \"store\""},
         {#{<<"peers">> => [Peer(#{}), Peer(#{<<"name">> => <<"desk">>})]},
          "two peers have one public-key, and two nodes with one key are one node"},
         {#{<<"peers">> => [Peer(#{<<"public-key">> => Own})]},
          "a peer has this node's own key, and a node is no peer of itself"},
         {#{<<"peers">> => [Peer(#{<<"network-address">> => <<"store:0">>})]},
          "peer \"store\"'s network-address is not host:port with a port from 1 to 65535:"
          " \"store:0\""},
         {#{<<"peers">> => [Peer(#{<<"network-address">> => <<"[::1]:8654">>})]},
          "peer \"store\"'s network-address \"[::1]:8654\" is IPv6, and this node runs over IPv4,"
          " its listener's family or IPv4 where it has none"},
         {#{<<"listen">> => <<"[::]:8654">>,
            <<"peers">> => [Peer(#{<<"network-address">> => <<"127.0.0.1:8654">>})]},
          "peer \"store\"'s network-address \"127.0.0.1:8654\" is IPv4, and this node runs over"
          " IPv6, its listener's family or IPv4 where it has none"},
         {#{<<"keys">> => []}, "keys is not a JSON object"},
         {#{<<"keys">> => #{<<"counter">> => [<<"store">>]}},
          "key \"counter\" names \"store\", which is no peer's name"},
         {#{<<"peers">> => [Peer(#{})],
            <<"keys">> => #{<<"counter">> => [<<"store">>, <<"store">>]}},
          "key \"counter\" names a peer twice"},
         {#{<<"measures">> => #{<<"network">> => #{}}}, "measures has the unknown field network"},
         {#{<<"measures">> => #{<<"cpu">> => #{<<"check-interval">> => 60000}}},
          "measures' cpu has the unknown field check-interval"},
         {#{<<"measures">> => #{<<"memory">> => #{<<"check-interval">> => 1000}}},
          "measures' memory's check-interval is not a whole number of minutes, which the host's"
          " memory measure counts"},
         {#{<<"measures">> => #{<<"disk">> => #{<<"check-interval">> => 0}}},
          "measures' disk's check-interval is not a count of milliseconds above 0"},
         {#{<<"measures">> => #{<<"disk">> => #{<<"almost-full">> => 2}}},
          "measures' disk's almost-full is not a fraction from 0 to 1"}],
    Ends = fun(Message, Expected) ->
               case is_list(Message) andalso ends(Message, Expected) of
                   true -> ok;
                   false -> ?assertEqual(Expected, Message)
               end
           end,
    lists:foreach(fun({Fields, Expected}) when is_map(Fields) ->
                          Ends(Refused(Fields), Expected);
                     ({Write, Expected}) ->
                          Write(),
                          Ends(refusal(fun() -> ern_node:read(Dir) end), Expected)
                  end, Cases),
    %% the refusal names the file
    conf(Dir, <<"{">>),
    ?assertEqual(filename:join(Dir, "ernest.conf") ++ ": is not JSON",
                 refusal(fun() -> ern_node:read(Dir) end)).

%% report §8.7: a public key in PEM whose body is no key the host's decoder
%% reads, a peer's or the node's own, is refused with the file and the
%% rule. A regression test: the decoder's failure escaped the check, and
%% `ern` failed with an internal error at the start, and the signal handler
%% at a reload
undecodable_key_test() ->
    Dir = made(),
    Own = public(Dir),
    %% the body's first bytes, the key's algorithm, made another DER's
    [Head, Body] = binary:split(other_key(), <<"\n">>),
    Broken = <<Head/binary, "\nAAAAAAAAAAAA",
               (binary:part(Body, 12, byte_size(Body) - 12))/binary>>,
    ?assertMatch([{'SubjectPublicKeyInfo', _, not_encrypted}], public_key:pem_decode(Broken)),
    Conf = filename:join(Dir, "ernest.conf"),
    with(Dir, #{<<"peers">> => [#{<<"name">> => <<"store">>, <<"public-key">> => Broken}]}),
    ?assertEqual(Conf ++ ": peer \"store\"'s public-key is not one public key in PEM",
                 refusal(fun() -> ern_node:read(Dir) end)),
    conf(Dir, json:encode(#{<<"public-key">> => Broken})),
    ?assertEqual(Conf ++ ": public-key is not one public key in PEM",
                 refusal(fun() -> ern_node:read(Dir) end)),
    conf(Dir, json:encode(#{<<"public-key">> => Own})),
    ?assertMatch({accepted, _}, refusal(fun() -> ern_node:read(Dir) end)).

%% report §8.7: a whole number of ernest.conf too large for the host to
%% hold, a numeral of more than a million digits, is refused with the file
%% and the rule. A regression test: the host's failure to read it was taken
%% as a file that is not JSON
large_number_test() ->
    Dir = made(),
    Text = iolist_to_binary(json:encode(#{<<"public-key">> => public(Dir)})),
    Fields = binary:part(Text, 0, byte_size(Text) - 1),
    conf(Dir, <<Fields/binary, ", \"measures\": {\"disk\": {\"check-interval\": ",
                (binary:copy(<<"9">>, 1300000))/binary, "}}}">>),
    ?assertEqual(filename:join(Dir, "ernest.conf") ++ ": holds a number too large for the host"
                 " to read",
                 refusal(fun() -> ern_node:read(Dir) end)).

%% report §8.7: a node refuses a configuration directory, or a file of it
%% that it reads, that anyone beyond its owner and group may write, as the
%% shell's startup files are refused, and a key any but its owner may read
%% or write; a file it needs that is not there is named with the command
%% that makes a directory, and one it cannot read with the host's reason, a
%% regression: such a file made `ern` fail with an internal error. Not
%% covered: a directory or a file of another user, which a test run as one
%% user cannot make
permissions_test() ->
    Dir = made(),
    Refused = fun(Path, Mode) ->
                  {ok, #file_info{mode = Was}} = file:read_file_info(Path),
                  ok = file:change_mode(Path, Mode),
                  try refusal(fun() -> ern_node:read(Dir) end)
                  after ok = file:change_mode(Path, Was band 8#7777)
                  end
              end,
    Conf = filename:join(Dir, "ernest.conf"),
    Key = filename:join(Dir, "private-key.pem"),
    Certificate = filename:join(Dir, "certificate.pem"),
    ?assertEqual(Dir ++ " may be written by anyone beyond its owner and group",
                 Refused(Dir, 8#702)),
    ?assertEqual(Conf ++ " may be written by anyone beyond its owner and group",
                 Refused(Conf, 8#646)),
    ?assertEqual(Certificate ++ " may be written by anyone beyond its owner and group",
                 Refused(Certificate, 8#666)),
    ?assertEqual(Key ++ " may be read or written by others than its owner", Refused(Key, 8#640)),
    %% written by its group, as a umask of 002 leaves a file
    ?assertMatch({accepted, _}, Refused(Conf, 8#664)),
    ?assertMatch({accepted, _}, Refused(Dir, 8#770)),
    [?assertEqual(File ++ ": permission denied", Refused(File, 8#000))
     || File <- [Conf, Key, Certificate]],
    ok = file:delete(Certificate),
    ?assertEqual(Certificate ++ " is not there; ern config --config-dir " ++ Dir
                 ++ " makes a configuration directory",
                 refusal(fun() -> ern_node:read(Dir) end)).

%% report §8.7: a node writes its process number to ernest.pid as it starts
%% and removes it at its end; a file that names a living process refuses
%% the start, and one a dead node left, or that names no process, is
%% replaced; a file another wrote meanwhile is not removed
pid_test() ->
    Dir = made(),
    Pid = filename:join(Dir, "ernest.pid"),
    _ = ern_node:start(Dir),
    ?assertEqual({ok, list_to_binary(os:getpid() ++ "\n")}, file:read_file(Pid)),
    ?assertEqual(Dir ++ " is the configuration directory of the running node " ++ os:getpid()
                 ++ ", which ernest.pid names",
                 refusal(fun() -> ern_node:start(Dir) end)),
    ok = ern_node:stop(Dir),
    ?assertNot(filelib:is_file(Pid)),
    lists:foreach(fun(Left) ->
                      ok = file:write_file(Pid, Left),
                      _ = ern_node:start(Dir),
                      ?assertEqual({ok, list_to_binary(os:getpid() ++ "\n")},
                                   file:read_file(Pid)),
                      ok = ern_node:stop(Dir)
                  end, [<<"999999\n">>, <<"not a process\n">>, <<"0\n">>]),
    ok = file:write_file(Pid, <<"1\n">>),
    ok = ern_node:stop(Dir),
    ?assertEqual({ok, <<"1\n">>}, file:read_file(Pid)).

%% report §8.7: the host's measures `measures` names start with the node,
%% and none where the section is absent; they stop at the node's end, each
%% program the host runs for them ended before the host ends, a
%% regression: the host ended them as it ended, and one said so on the
%% node's standard error
measures_test() ->
    Dir = made(),
    _ = ern_node:start(Dir),
    ok = ern_node:stop(Dir),
    ?assertEqual(false, lists:keymember(os_mon, 1, application:which_applications())),
    with(Dir, #{<<"measures">> => #{<<"cpu">> => #{},
                                    <<"disk">> => #{<<"check-interval">> => 60000,
                                                    <<"almost-full">> => 0.95}}}),
    try
        _ = ern_node:start(Dir),
        ?assert(is_pid(whereis(cpu_sup))),
        ?assert(is_pid(whereis(disksup))),
        ?assertEqual(undefined, whereis(memsup)),
        ?assertEqual(60000, disksup:get_check_interval()),
        ?assertEqual(95, disksup:get_almost_full_threshold()),
        ?assertNotEqual([], measure_programs()),
        ok = ern_node:stop(Dir),
        ?assertEqual(false, lists:keymember(os_mon, 1, application:which_applications())),
        ?assertEqual([], measure_programs())
    after
        ok = ern_node:stop(Dir),
        _ = application:stop(sasl)
    end.

%% Until the host's memory measure has collected once, its program then
%% waiting for the next request: the host closes the program's port with a
%% collection under way, as it starts, and the program then says on
%% standard error that its pipe broke.
collected() ->
    _ = memsup:get_system_memory_data(),
    ok.

%% The ports of the programs the host runs for its measures.
measure_programs() ->
    Programs = filename:join(code:priv_dir(os_mon), "bin"),
    [Port || Port <- erlang:ports(), {name, Name} <- [erlang:port_info(Port, name)],
             string:find(Name, Programs) =/= nomatch].

%% report §8.7: a reload's measures take their parameters from the new file
%% and the host's defaults alone, a parameter the file before it gave and
%% the new one leaves out back at the host's default. A regression test:
%% the earlier file's parameters stayed, the application never unloaded
measures_reloaded_test() ->
    Dir = made(),
    Measures = #{memory => #{check_interval => 120000}},
    with(Dir, #{<<"measures">> => #{<<"memory">> => #{<<"check-interval">> => 120000}}}),
    try
        _ = ern_node:start(Dir),
        ?assertEqual(120000, memsup:get_check_interval()),
        collected(),
        ok = ern_node:measures_changed(Dir, Measures, #{memory => #{}}),
        ?assertEqual(60000, memsup:get_check_interval()),
        collected()
    after
        ok = ern_node:stop(Dir),
        _ = application:stop(sasl)
    end.
