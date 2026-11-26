%% Report §8.3, §8.7, §12.5, §11.3, Appendix C: a node's configuration directory,
%% the one owner of its shape. `ern config` makes it, a key, a certificate
%% the node signs itself and `ernest.conf`, prints the public key of one
%% that is there, and lists in it a peer of this machine read from the
%% peer's own directory; a node started with it checks it, reads
%% `ernest.conf` whole, makes the certificate where it is missing, writes
%% its process number to `ernest.pid`, holds the file locked until its
%% process has ended, when the file is removed, and starts the host's
%% measures the file names; `ern reload` and `ern stop` signal the node that
%% holds the file. A refusal is the runner's (ern_build:fail/1), naming the
%% file.
-module(ern_node).

-export([create/2, public_pem/1, add_peer/2, start/1, start/2, stop/0, file/2, read/1, read/2,
         certificate_made/1, measures_changed/3, signaled/2, stopped/1, listen_text/1, family/1]).

-include_lib("public_key/include/public_key.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("nodes/include/ern_node.hrl").

%% Report §8.6: each receive that can wait, by its kind (docs/code_style.md).
-receives({own_process, [measures_stopped/0]}).

-define(CONF, "ernest.conf").
-define(KEY, "private-key.pem").
-define(CERTIFICATE, "certificate.pem").
-define(PID_FILE, "ernest.pid").

%% The certificate's subject, the same for every node, since a peer is known
%% by its key and the host its key gives (report §12.5).
-define(NAME, <<"ernest">>).

%% Report §12.5, Appendix E.27: what `ernest.conf` may say.
-define(FIELDS, [<<"listen">>, <<"peers">>, <<"services">>, <<"measures">>,
                 <<"utilization-interval">>, <<"limits">>]).
-define(PEER_FIELDS, [<<"name">>, <<"public-key">>, <<"network-address">>]).

%%
%% ern config
%%

%% Report §11.3, Appendix C: `ern config` without `--peer-dir`, answering
%% the node's public key in PEM, which the job prints. In a directory Given
%% that is there and holds the node's key the key is read as a node reads
%% its own, and nothing changes, `--listen` refused there, since it would
%% change nothing; one that holds no key is refused, and so is anything at
%% Given that is no directory, as §11.7 refuses one. Else the directory is
%% made (made/2). A name ending in `/` names the directory before it.
-spec create(file:filename(), string() | none) -> binary().
create(Given, Listen) ->
    ConfigDir = filename:join([Given]),
    case file:read_link_info(ConfigDir) of
        {ok, _} -> standing(ConfigDir, Listen);
        {error, _} -> made(ConfigDir, Listen)
    end.

%% What stands at the directory's path: a directory, a link to one among
%% them, or anything else.
standing(ConfigDir, Listen) ->
    case filelib:is_dir(ConfigDir) of
        true -> existing(ConfigDir, Listen);
        false -> no_directory(ConfigDir)
    end.

%% Report §11.3: the public key of a configuration directory that is there,
%% its key read as a node reads its own (own_key/1), and nothing changed.
existing(ConfigDir, Listen) ->
    Shown = ern_build:shown(ConfigDir),
    case file:read_link_info(file(ConfigDir, key)) of
        {error, enoent} -> ern_build:fail(Shown ++ " exists and holds no " ++ ?KEY);
        _ -> ok
    end,
    Listen =:= none
        orelse ern_build:fail("--listen is not given for a directory that exists: ern config"
                              " changes nothing in " ++ Shown),
    public_pem(public_der(own_key(ConfigDir))).

%% Report §11.3, §11.7: what stands at `--config-dir`'s path and is no
%% directory, refused as §11.7 refuses a file an option names as one.
-spec no_directory(file:filename()) -> no_return().
no_directory(ConfigDir) ->
    ern_build:fail(ern_build:shown(ConfigDir) ++ ": not a directory, which --config-dir names").

%% Report §11.3, Appendix C: the configuration directory made, with this
%% node's key, the certificate it signs itself and `ernest.conf`. The
%% directory is made here or not at all, so that one another made first,
%% as this runs, is taken as one that is there (standing/2), and it is its
%% owner's alone before a file is written in it, the key's among them
%% (ern_build:make_private_dir/1). Its `listen` is the one `--listen`
%% gives, refused before the directory is made where a node would refuse
%% it, and none where it gives none, a node that only dials (§12.5); and
%% the directory is the one directory made, its parent there before it, so
%% that a mistyped path makes no tree.
made(ConfigDir, Listen) ->
    Listening = listening(Listen),
    Parent = filename:dirname(ConfigDir),
    %% report §11: a missing parent in the host's words
    case file:read_file_info(Parent) of
        {ok, #file_info{type = directory}} -> ok;
        {ok, _} -> ern_build:refused(Parent, enotdir);
        {error, Error} -> ern_build:refused(Parent, Error)
    end,
    case ern_build:make_private_dir(ConfigDir) of
        ok -> written(ConfigDir, Listening);
        exists -> standing(ConfigDir, Listen);
        {error, Why} -> ern_build:fail(ConfigDir ++ ": " ++ Why)
    end.

%% The files of a directory made: its key, the certificate and
%% `ernest.conf`, the key's public half answered.
written(ConfigDir, Listening) ->
    %% report §12.5: an ed25519 key, which serves in the handshake under the
    %% rule (the log's *The Node's Directory*)
    Key = public_key:generate_key({namedCurve, ed25519}),
    %% written by the host's JSON formatter, its fields in Appendix C's
    %% order, two spaces a level, and a line feed at its end
    Fields = Listening ++ [{<<"peers">>, []}, {<<"services">>, #{}}],
    Json = json:format({object, Fields}, fun ordered/3, #{indent => 2}),
    %% report §11.3: the two readable by all and writable by their owner
    %% alone, whatever the umask
    ok = ern_build:write_output(filename:join(ConfigDir, ?CONF), Json, 8#644),
    certificate_made(ConfigDir, Key),
    %% the key is its owner's alone before it is written
    Private = pem([public_key:pem_entry_encode('PrivateKeyInfo', Key)]),
    ok = ern_build:write_output(filename:join(ConfigDir, ?KEY), Private, 8#600),
    public_pem(public_der(Key)).

%% Report §11.3, §12.5, Appendix C: the certificate the node signs itself
%% with Key, written in the configuration directory, readable by all and
%% writable by its owner alone, whatever the umask; as `ern config` makes
%% it and as a node makes it where it is missing (read/2).
certificate_made(ConfigDir, Key) ->
    Certificate = pem([{'Certificate', signed_certificate(Key), not_encrypted}]),
    ok = ern_build:write_output(filename:join(ConfigDir, ?CERTIFICATE), Certificate, 8#644).

%% Report §11.3, §12.5: the `listen` field `--listen` gives, refused where
%% a node would refuse it, or none; a value not of the form, an
%% address:port, refused as the form of the command line is (§11).
listening(none) ->
    [];
listening(Listen) ->
    Text = unicode:characters_to_binary(Listen),
    case listener(Text) of
        {ok, _} -> [{<<"listen">>, Text}];
        not_endpoint -> ern_build:form_fail("--listen is not address:port: " ++ Listen);
        no_address -> ern_build:form_fail("--listen names no address: " ++ Listen);
        {mapped, Mapped} -> ern_build:fail("--listen names " ++ mapped_text(Mapped))
    end.

%% Report Appendix C: an object whose fields keep the order given, as
%% `ernest.conf` is decoded (decoded/1), for the host's JSON formatter,
%% which writes a map's fields in the order of their names; every other
%% value as the formatter writes it.
ordered({object, Fields}, Encode, State) ->
    json:format_key_value_list_checked(Fields, Encode, State);
ordered(Value, Encode, State) ->
    json:format_value(Value, Encode, State).

%% Report §12.5: a node's public key in PEM, the DER of its
%% SubjectPublicKeyInfo, as `ern config` prints it and a shell session's
%% namespace carries it (Appendix H).
-spec public_pem(binary()) -> binary().
public_pem(Der) ->
    pem([{'SubjectPublicKeyInfo', Der, not_encrypted}]).

%% PEM, ended by one line feed.
pem(Entries) ->
    <<(string:trim(public_key:pem_encode(Entries), trailing))/binary, "\n">>.

%% The DER of the SubjectPublicKeyInfo of an ed25519 key, or of its point.
%% A key read from its PEM carries no public point, which the private key
%% gives.
public_der({'ECPrivateKey', _, Private, {namedCurve, ?'id-Ed25519'}, _, _}) ->
    {PublicPoint, _} = crypto:generate_key(eddsa, ed25519, Private),
    point_der(PublicPoint).

point_der(PublicPoint) ->
    public_key:der_encode('SubjectPublicKeyInfo',
                          #'SubjectPublicKeyInfo'{
                             algorithm = #'AlgorithmIdentifier'{algorithm = ?'id-Ed25519'},
                             subjectPublicKey = PublicPoint}).

%% Report §12.5: a certificate the node signs itself, its subject a constant,
%% naming as its one alternative name the host its key gives, which binds
%% the key to the node's name on the carrier, and its validity the longest
%% RFC 5280 writes, from 1970 to the end of 9999, since a certificate's dates
%% mean nothing to a node; its serial number is drawn, as a certificate's
%% is.
signed_certificate({'ECPrivateKey', _, Private, _, _, _} = Key) ->
    {PublicPoint, _} = crypto:generate_key(eddsa, ed25519, Private),
    Host = ern_carrier:host(point_der(PublicPoint)),
    Name = {rdnSequence, [[#'AttributeTypeAndValue'{type = ?'id-at-commonName',
                                                    value = {utf8String, ?NAME}}]]},
    <<Serial:63, _:1>> = crypto:strong_rand_bytes(8),
    Tbs = #'OTPTBSCertificate'{
             version = v3,
             serialNumber = Serial + 1,
             signature = #'SignatureAlgorithm'{algorithm = ?'id-Ed25519'},
             issuer = Name,
             validity = #'Validity'{notBefore = {utcTime, "700101000000Z"},
                                    notAfter = {generalTime, "99991231235959Z"}},
             subject = Name,
             subjectPublicKeyInfo =
                 #'OTPSubjectPublicKeyInfo'{
                    algorithm = #'PublicKeyAlgorithm'{algorithm = ?'id-Ed25519'},
                    subjectPublicKey = #'ECPoint'{point = PublicPoint}},
             extensions = [#'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                                        extnValue = [{dNSName, Host}]}]},
    public_key:pkix_sign(Tbs, Key).

%%
%% ern config --peer-dir
%%

%% Report §11.3: the node whose configuration directory is PeerDir, of this
%% machine, listed last among the peers of the directory ConfigDir: its
%% name its directory's, its public key the one its certificate certifies,
%% and its address its `listen`, the loopback address in place of one for
%% every interface; `ernest.conf` is written again with every other field
%% as it was, its links followed (report §11), or not at all.
%%
%% It refuses a ConfigDir a node would refuse as its own; a PeerDir whose
%% directory, `ernest.conf` or certificate a node would refuse as its own,
%% or whose certificate names another host than its key gives
%% (peer_read/1); the entry where a node would refuse it as a peer's; a
%% peer with this node's own key; and one whose name or key ConfigDir lists
%% already. Neither read makes a certificate, and the peer's private key is
%% not read. Report §11.7: for a peer directory that names nothing, or that
%% holds no `ernest.conf` or no `certificate.pem`, the command line's own
%% check answers first (ern_cli:named_directories/3).
-spec add_peer(file:filename(), file:filename()) -> ok.
add_peer(ConfigDir, PeerDir) ->
    #configuration{listen = Listen, public_key = Own, peers = Peers} = read(ConfigDir, left),
    {Key, PeerListen} = peer_read(PeerDir),
    Shown = ern_build:shown(PeerDir),
    Name = unicode:characters_to_binary(filename:basename(ern_build:absolute(PeerDir))),
    Key =/= Own
        orelse ern_build:fail(Shown ++ " has this node's own key, and a node is no peer of itself"),
    not lists:keymember(Name, #peer.name, Peers)
        orelse fail(ConfigDir, ?CONF, "a peer is named " ++ ern_conf:quoted(Name) ++ " already"),
    case lists:keyfind(Key, #peer.public_key, Peers) of
        false -> ok;
        #peer{name = Listed} ->
            fail(ConfigDir, ?CONF, "the peer " ++ ern_conf:quoted(Listed) ++ " has the key of "
                                   ++ Shown ++ " already")
    end,
    Entry = maps:merge(#{<<"name">> => Name,
                         <<"public-key">> => pem([{'SubjectPublicKeyInfo', Key, not_encrypted}])},
                       local_address(PeerDir, PeerListen)),
    _ = peer(ConfigDir, {object, maps:to_list(Entry)}, Listen),
    {object, Fields} = decoded(ConfigDir),
    Listing = case lists:keyfind(<<"peers">>, 1, Fields) of
                  {_, Items} -> Items;
                  false -> []
              end,
    %% each peer a map, which the formatter writes a field a line in the
    %% order of the fields' names, Appendix C's
    Written = [maps:from_list(Pairs) || {object, Pairs} <- Listing] ++ [Entry],
    Json = json:format({object, lists:keystore(<<"peers">>, 1, Fields, {<<"peers">>, Written})},
                       fun ordered/3, #{indent => 2}),
    ern_build:write_whole(file(ConfigDir, conf), Json).

%% Report §11.3, §11.7, §12.5: the key a peer's certificate certifies, and
%% its `listen`: its directory, `ernest.conf` and certificate read as a node
%% reads its own, the certificate naming the host its key gives, its
%% refusal advising the removal that the peer's node mends at its start; a
%% directory without its certificate is no configuration directory, and
%% none is made for it.
peer_read(PeerDir) ->
    checked(PeerDir, "--peer-dir"),
    found(file(PeerDir, certificate), regular) =/= missing
        orelse no_configuration(PeerDir, "--peer-dir"),
    #configuration{listen = Listen} = configuration(PeerDir),
    Certificate = certificate(PeerDir),
    ern_carrier:names_own_host(Certificate)
        orelse fail(PeerDir, ?CERTIFICATE, "names another host than its key gives, and a peer"
                                           " refuses it; remove it, and its node makes one from"
                                           " its key at its start"),
    {certified_key(Certificate), Listen}.

%% Report §11.3: a peer's `network-address` on this machine, its `listen`
%% with the loopback address for every interface's, or none where it has
%% no `listen`; a port the host picks as the peer starts names no address.
local_address(_PeerDir, none) ->
    #{};
local_address(PeerDir, {_, 0}) ->
    fail(PeerDir, ?CONF, "listen names port 0, which the host picks as the node starts, so no"
                         " network-address can name it");
local_address(_PeerDir, {Address, Port}) ->
    Host = case Address of
               {0, 0, 0, 0} -> "127.0.0.1";
               {0, 0, 0, 0, 0, 0, 0, 0} -> "[::1]";
               {_, _, _, _} -> inet:ntoa(Address);
               _ -> "[" ++ inet:ntoa(Address) ++ "]"
           end,
    #{<<"network-address">> => list_to_binary(Host ++ ":" ++ integer_to_list(Port))}.

%%
%% A node's start and end
%%

%% Report §12.5: a node starts from its configuration directory: the
%% directory and its files checked, `ernest.conf` read whole, the process
%% number written to `ernest.pid`, and the host's measures the file names
%% started. Answers what `ernest.conf` says.
-spec start(file:filename()) -> #configuration{}.
start(ConfigDir) ->
    start(ConfigDir, read(ConfigDir)).

%% The same, of what `ernest.conf` says, read already.
-spec start(file:filename(), #configuration{}) -> #configuration{}.
start(ConfigDir, Configuration) ->
    pid_written(ConfigDir),
    try measures_started(ConfigDir, Configuration#configuration.measures)
    catch Class:Reason:Trace ->
        stop(),
        erlang:raise(Class, Reason, Trace)
    end,
    Configuration.

%% Report §12.5: a node stops the host's measures at its end; its
%% `ernest.pid` goes once its process has ended, removed by the helper that
%% holds its lock (pid_written/1).
-spec stop() -> ok.
stop() ->
    measures_stopped().

%% A file of the configuration directory: `ernest.conf`, the key, the
%% certificate or `ernest.pid`.
-spec file(file:filename(), conf | key | certificate | pid) -> file:filename().
file(ConfigDir, conf) -> filename:join(ConfigDir, ?CONF);
file(ConfigDir, key) -> filename:join(ConfigDir, ?KEY);
file(ConfigDir, certificate) -> filename:join(ConfigDir, ?CERTIFICATE);
file(ConfigDir, pid) -> filename:join(ConfigDir, ?PID_FILE).

%% Report §12.5: the directory checked and read as a node's start and its
%% reload read it, a missing certificate made (read/2).
-spec read(file:filename()) -> #configuration{}.
read(ConfigDir) ->
    read(ConfigDir, made).

%% Report §12.5, §11.2, §11.3: the directory checked and `ernest.conf` read:
%% the directory, `ernest.conf` and the key there, a link followed, and of
%% their kind (checked/2, key_found/1); the file JSON, every field known;
%% the node's key `private-key.pem`'s, and the certificate, where it is
%% there, certifying that key and naming the host the key gives. A missing
%% certificate is made from the key once nothing is refused, where Missing
%% is `made`, as a node's start and its reload make it, and `left` where
%% the reading makes nothing, `ern reload`'s own, `ern config
%% --peer-dir`'s and a reload's, which makes it once it has checked the key
%% (certificate_made/1). The node's public key is its key's.
-spec read(file:filename(), made | left) -> #configuration{}.
read(ConfigDir, Missing) ->
    checked(ConfigDir, "--config-dir"),
    Certificate = found(file(ConfigDir, certificate), regular),
    key_found(ConfigDir),
    Configuration = configuration(ConfigDir),
    Key = private_key(ConfigDir),
    Own = public_der(Key),
    case Certificate of
        missing -> ok;
        _ -> certified(ConfigDir, Own)
    end,
    lists:any(fun(#peer{public_key = Peer}) -> Peer =:= Own end,
              Configuration#configuration.peers)
        andalso fail(ConfigDir, ?CONF, "a peer has this node's own key, and a node is no peer"
                                       " of itself"),
    case {Certificate, Missing} of
        {missing, made} -> certificate_made(ConfigDir, Key);
        _ -> ok
    end,
    Configuration#configuration{public_key = Own}.

%% Report §12.5: where the directory holds no certificate, the one the node
%% makes from its key, as a reload makes it once it has found the key the
%% running node's (ern_carrier:reload/0).
-spec certificate_made(file:filename()) -> ok.
certificate_made(ConfigDir) ->
    case found(file(ConfigDir, certificate), regular) of
        missing -> certificate_made(ConfigDir, own_key(ConfigDir));
        _ -> ok
    end.

%% Report §12.5: the node's certificate certifies its key, Own, and names
%% the host that key gives; each refusal advises the removal, since the
%% node makes a missing certificate from its key (certificate_made/1).
certified(ConfigDir, Own) ->
    Certificate = certificate(ConfigDir),
    Remade = "; remove it, and the node makes one from its key",
    certified_key(Certificate) =:= Own
        orelse fail(ConfigDir, ?CERTIFICATE, "certifies another key than " ++ ?KEY ++ Remade),
    ern_carrier:names_own_host(Certificate)
        orelse fail(ConfigDir, ?CERTIFICATE, "names another host than its key gives, and a peer"
                                             " refuses it" ++ Remade),
    ok.

%% Report §12.5, §11: a configuration directory and its `ernest.conf`
%% there, of their kind, and written by none but their owner, by the bits
%% the key's test reads for writing; every other way the host lets another
%% write what a node reads, a directory a link reaches through among them,
%% held to no owner and no mode (§11). A directory without `ernest.conf` is
%% none, named with the option that names it, Option.
checked(ConfigDir, Option) ->
    case found(ConfigDir, directory) of
        missing -> ern_build:refused(ConfigDir, enoent);
        DirectoryMode -> owners_alone(ConfigDir, DirectoryMode, 8#022, "written", "go-w")
    end,
    Conf = file(ConfigDir, conf),
    case found(Conf, regular) of
        missing -> no_configuration(ConfigDir, Option);
        ConfMode -> owners_alone(Conf, ConfMode, 8#022, "written", "go-w")
    end.

%% Report §12.5: the node's key there, of its kind, and read and written by
%% none but its owner, as ssh reads one.
key_found(ConfigDir) ->
    Path = file(ConfigDir, key),
    case found(Path, regular) of
        missing -> ern_build:refused(Path, enoent);
        Mode -> owners_alone(Path, Mode, 8#066, "read or written", "go-rw")
    end.

%% Report §11.3, §12.5: the node's key, found and read as a node reads its
%% own.
own_key(ConfigDir) ->
    key_found(ConfigDir),
    private_key(ConfigDir).

%% Report §12.5: a file or a directory whose Mode lets none but its owner
%% do what the Bits of others' and its group's mean, else refused with the
%% cause and then the fix, the change of mode that mends it.
owners_alone(Path, Mode, Bits, Done, Fix) ->
    Shown = ern_build:shown(Path),
    Mode band Bits =:= 0
        orelse ern_build:fail(Shown ++ " may be " ++ Done ++ " by others than its owner; chmod "
                              ++ Fix ++ " " ++ Shown),
    ok.

%% Report §12.5, §11.7: a directory without `ernest.conf`, or a peer's
%% without its certificate, named with the option that names it.
-spec no_configuration(file:filename(), string()) -> no_return().
no_configuration(Dir, Option) ->
    ern_build:fail(ern_build:shown(Dir) ++ ": no configuration directory, which " ++ Option
                   ++ " names").

%% A file or the directory, a link followed: its mode where it is there and
%% of Kind, one of another kind refused as §11 refuses one, `is no regular
%% file`, and a path the host cannot read with its reason; missing where
%% nothing is there.
found(Path, Kind) ->
    case file:read_file_info(Path) of
        {ok, #file_info{type = Kind, mode = Mode}} -> Mode;
        {ok, _} when Kind =:= directory -> ern_build:fail(ern_build:shown(Path)
                                                          ++ " is not a directory");
        {ok, _} -> ern_build:refused(Path, unopened);
        {error, enoent} -> missing;
        {error, Error} -> ern_build:refused(Path, Error)
    end.

%% Each file is read through ern_build:read/1, which refuses one that cannot
%% be read with its name and the host's reason; what does not decode is
%% refused with the file and the rule, the host's decoder's failure among
%% it, and nothing of it escapes as a failure of `ern` (report §12.5).
private_key(ConfigDir) ->
    Pem = ern_build:read(file(ConfigDir, key)),
    Decoded = try [public_key:pem_entry_decode(Entry) || Entry <- public_key:pem_decode(Pem)]
              catch _:_ -> none
              end,
    case Decoded of
        [{'ECPrivateKey', _, _, {namedCurve, ?'id-Ed25519'}, _, _} = Key] -> Key;
        [_] -> fail(ConfigDir, ?KEY, "is not an ed25519 key");
        _ -> fail(ConfigDir, ?KEY, "is not one key in PEM")
    end.

%% The node's certificate, an ed25519 certificate in PEM.
certificate(ConfigDir) ->
    Pem = ern_build:read(file(ConfigDir, certificate)),
    Decoded = try public_key:pem_decode(Pem) of
                  [{'Certificate', Der, not_encrypted}] -> decoded_certificate(Der);
                  _ -> none
              catch _:_ -> none
              end,
    case Decoded of
        #'OTPCertificate'{} = Certificate -> Certificate;
        none -> fail(ConfigDir, ?CERTIFICATE, "is not one certificate in PEM");
        not_ed25519 -> fail(ConfigDir, ?CERTIFICATE, "is not an ed25519 certificate in PEM")
    end.

%% A certificate's DER decoded, or not_ed25519 where it does not decode to
%% one that certifies a key of a curve.
decoded_certificate(Der) ->
    Decoded = try public_key:pkix_decode_cert(Der, otp) catch _:_ -> none end,
    case Decoded of
        #'OTPCertificate'{tbsCertificate = Tbs} ->
            case Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo of
                #'OTPSubjectPublicKeyInfo'{subjectPublicKey = #'ECPoint'{}} -> Decoded;
                _ -> not_ed25519
            end;
        none ->
            not_ed25519
    end.

%% The DER of the SubjectPublicKeyInfo a certificate certifies.
certified_key(#'OTPCertificate'{tbsCertificate = Tbs}) ->
    #'OTPSubjectPublicKeyInfo'{subjectPublicKey = #'ECPoint'{point = Point}} =
        Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo,
    point_der(Point).

%% Report §12.5: `ernest.pid` holds this node's process number from its
%% start, and the node holds it locked until its process has ended, however
%% it ends, through the runtime's helper, which watches the process and
%% removes the file then (ern_os:locked/2); a file a living node holds
%% refuses the start, naming the number it holds, and one no node holds is
%% overwritten, whatever number it names. A host that cannot watch a process
%% for its end refuses the start, naming its system and its release, and no
%% file is made. A name that reaches no regular file is not opened (report §11).
pid_written(ConfigDir) ->
    PidFile = file(ConfigDir, pid),
    case ern_os:locked(PidFile, list_to_integer(os:getpid())) of
        locked ->
            ok;
        {held, <<>>} ->
            ern_build:fail(ern_build:shown(ConfigDir) ++ " is the configuration directory of a"
                           " running node, which holds " ++ ?PID_FILE);
        {held, Number} ->
            ern_build:fail(ern_build:shown(ConfigDir) ++ " is the configuration directory of the"
                           " running node " ++ binary_to_list(Number) ++ ", which "
                           ++ ?PID_FILE ++ " names");
        unopened ->
            fail(ConfigDir, ?PID_FILE, ern_build:reason(unopened));
        {unwatched, Host} ->
            ern_build:fail("a node needs pidfd_open, of Linux 5.3 and later, which this host, "
                           ++ binary_to_list(Host) ++ ", does not have");
        {failed, Text} ->
            fail(ConfigDir, ?PID_FILE, Text)
    end.

%% Report §12.5: a reload's measures: the host's services stopped and those
%% the new file names started, where the file changed them; where they do
%% not start, those that ran are started again and the reload is refused,
%% whatever stopped them.
-spec measures_changed(file:filename(), map(), map()) -> ok.
measures_changed(_ConfigDir, Measures, Measures) ->
    ok;
measures_changed(ConfigDir, Measures, NewMeasures) ->
    measures_stopped(),
    try measures_started(ConfigDir, NewMeasures)
    catch Class:Reason:Trace ->
        measures_stopped(),
        measures_started(ConfigDir, Measures),
        erlang:raise(Class, Reason, Trace)
    end.

%% Report §12.5: the host's measures stopped, each program the host runs for
%% them ended in order, so that none says, as its port closes when the host
%% ends, that the host has closed; and the application unloaded, so that the
%% measures started next take their parameters from the host's defaults and
%% the file, and none from a file before it. The programs are the ports the
%% application opens from its own directory.
measures_stopped() ->
    Programs = filename:join(code:priv_dir(os_mon), "bin"),
    MonitorRefs = [erlang:monitor(port, Port)
                   || Port <- erlang:ports(),
                      {name, Name} <- [erlang:port_info(Port, name)],
                      string:find(Name, Programs) =/= nomatch],
    _ = application:stop(os_mon),
    lists:foreach(fun(MonitorRef) -> receive {'DOWN', MonitorRef, port, _, _} -> ok end end,
                  MonitorRefs),
    _ = application:unload(os_mon),
    ok.

%% Report §12.5, §11.2: the signal sent to the node that runs from the
%% directory, the one that holds its `ernest.pid`, the process the file
%% names; where there is no file, its name reaches no regular file, which
%% is not opened (§11), no node holds it, the file is another
%% user's, or its process has ended or is another user's, the job fails,
%% saying so, and nothing is signaled.
-spec signaled(file:filename(), non_neg_integer()) -> ok.
signaled(ConfigDir, Number) ->
    node_signaled(ConfigDir, Number, false).

%% Report §8.6, §11.2: termination sent to the node as signaled/2 sends a
%% signal, and its end waited for, on the lock it holds on `ernest.pid`,
%% which its helper lets go once the node's process has ended, however it
%% ends.
-spec stopped(file:filename()) -> ok.
stopped(ConfigDir) ->
    node_signaled(ConfigDir, ern_os:signal_number('Termination'), true).

node_signaled(ConfigDir, Number, Wait) ->
    case ern_os:node_signaled(file(ConfigDir, pid), Number, Wait) of
        sent -> ok;
        no_file -> fail(ConfigDir, ?PID_FILE, file:format_error(enoent)
                                              ++ ": no node runs from the directory");
        unopened -> fail(ConfigDir, ?PID_FILE, ern_build:reason(unopened));
        no_node -> fail(ConfigDir, ?PID_FILE, "no node holds it: no node runs from the directory");
        no_process -> fail(ConfigDir, ?PID_FILE, "names no process");
        none -> fail(ConfigDir, ?PID_FILE, "names a process that has ended: no node runs from the"
                                           " directory");
        others -> fail(ConfigDir, ?PID_FILE, "names another user's process");
        {failed, Text} -> fail(ConfigDir, ?PID_FILE, Text)
    end.

%% Report §12.5: the host's measures `measures` names, started with their
%% parameters, and none where the section is absent. The host's memory
%% measure counts its interval in minutes, which the file's milliseconds
%% were held to when it was read.
measures_started(_ConfigDir, Measures) when map_size(Measures) =:= 0 ->
    ok;
measures_started(ConfigDir, Measures) ->
    Memory = maps:get(memory, Measures, none),
    Disk = maps:get(disk, Measures, none),
    Env = [{start_cpu_sup, is_map_key(cpu, Measures)},
           {start_memsup, Memory =/= none},
           {start_disksup, Disk =/= none},
           {start_os_sup, false}]
        ++ [{memory_check_interval, Ms div 60000} || #{check_interval := Ms} <- [Memory]]
        ++ [{system_memory_high_watermark, Full} || #{almost_full := Full} <- [Memory]]
        ++ [{disk_space_check_interval, {millisecond, Ms}} || #{check_interval := Ms} <- [Disk]]
        ++ [{disk_almost_full_threshold, Full} || #{almost_full := Full} <- [Disk]],
    %% the application's own defaults are loaded first, and then set over
    case application:load(os_mon) of
        ok -> ok;
        {error, {already_loaded, os_mon}} -> ok
    end,
    lists:foreach(fun({Name, Value}) -> ok = application:set_env(os_mon, Name, Value) end, Env),
    case application:ensure_all_started(os_mon) of
        {ok, _} -> ok;
        {error, Error} ->
            fail(ConfigDir, ?CONF, io_lib:format("the host's measures did not start: ~p", [Error]))
    end.

%%
%% ernest.conf
%%

%% Report §12.5, Appendix C: `ernest.conf` read whole: JSON, an object whose
%% every field is known, and none twice in one object, and each whole
%% number one the host can hold.
configuration(ConfigDir) ->
    Fields = object(ConfigDir, "the file", decoded(ConfigDir), ?FIELDS),
    Listen = case Fields of
                 #{<<"listen">> := ListenText} -> listen(ConfigDir, ListenText);
                 _ -> none
             end,
    Peers = peers(ConfigDir, maps:get(<<"peers">>, Fields, []), Listen),
    #configuration{config_dir = ConfigDir, listen = Listen, peers = Peers,
                   services = services(ConfigDir, maps:get(<<"services">>, Fields, {object, []}),
                                       Peers),
                   measures = measures(ConfigDir, maps:get(<<"measures">>, Fields, none)),
                   utilization_interval =
                       utilization_interval(ConfigDir,
                                            maps:get(<<"utilization-interval">>, Fields, 5000)),
                   limits = limits(ConfigDir, maps:get(<<"limits">>, Fields, none))}.

%% `ernest.conf` as one JSON value, read as every JSON file of the
%% toolchain's is (ern_conf), the file and the fault named where it is not
%% one a node reads: no JSON, more than one value, or a number too long for
%% the host to hold (report §12.5).
decoded(ConfigDir) ->
    case ern_conf:decoded(ern_build:read(file(ConfigDir, conf))) of
        {ok, Decoded} -> Decoded;
        {fault, Fault} -> fail(ConfigDir, ?CONF, Fault)
    end.

%% A JSON object's fields as a map, each name among Known and none given
%% twice, the first fault refused.
object(ConfigDir, What, Item, Known) ->
    case ern_conf:fields(What, Item, Known) of
        {Fields, []} -> Fields;
        {_, [Fault | _]} -> fail(ConfigDir, ?CONF, Fault);
        not_object -> fail(ConfigDir, ?CONF, What ++ " is not a JSON object")
    end.

%% Report §12.5: `listen`, an address of one interface, or `0.0.0.0` or `::`
%% for all, and a port, 0 for one the host picks.
listen(ConfigDir, Text) when is_binary(Text) ->
    case listener(Text) of
        {ok, Listen} -> Listen;
        not_endpoint ->
            fail(ConfigDir, ?CONF, "listen is not address:port: " ++ ern_conf:quoted(Text));
        no_address -> fail(ConfigDir, ?CONF, "listen names no address: " ++ ern_conf:quoted(Text));
        {mapped, Mapped} -> fail(ConfigDir, ?CONF, "listen names " ++ mapped_text(Mapped))
    end;
listen(ConfigDir, _) ->
    fail(ConfigDir, ?CONF, "listen is not a string").

%% The interface and the port a `listen` names, or what it lacks. Report
%% §12.5: an IPv4-mapped address, `::ffff:a.b.c.d`, is none a listener
%% takes, as `Tcp.listen` refuses it (Appendix E.18).
listener(Text) ->
    case endpoint(Text) of
        {ok, Host, Port} ->
            case inet:parse_strict_address(Host) of
                {ok, {0, 0, 0, 0, 0, 16#ffff, _, _} = Address} -> {mapped, {Address, Port}};
                {ok, Address} -> {ok, {Address, Port}};
                {error, _} -> no_address
            end;
        error ->
            not_endpoint
    end.

%% The refusal of a mapped listen address, which names it as a listen
%% address is written (listen_text/1), so that an address given in hex,
%% `[::ffff:7f00:1]:0`, shows the IPv4 address it maps.
mapped_text(Listen) ->
    lists:flatten(["an IPv4-mapped address, ", listen_text(Listen), ", which no listener takes"]).

%% Report §12.5: a listen address as `listen` writes it, an IPv6 address in
%% brackets.
-spec listen_text({inet:ip_address(), inet:port_number()}) -> iolist().
listen_text({{_, _, _, _} = Address, Port}) ->
    [inet:ntoa(Address), ":", integer_to_list(Port)];
listen_text({Address, Port}) ->
    ["[", inet:ntoa(Address), "]:", integer_to_list(Port)].

%% Host and port of `host:port`, an IPv6 address in brackets, the port
%% from 0 to 65535.
endpoint(Text) ->
    Parsed = case string:split(binary_to_list(Text), ":", trailing) of
                 ["[" ++ Bracketed, Port] ->
                     case lists:reverse(Bracketed) of
                         "]" ++ Host -> {lists:reverse(Host), Port};
                         _ -> error
                     end;
                 [Host, Port] ->
                     case lists:member($:, Host) orelse lists:member($[, Host)
                          orelse lists:member($], Host) orelse Host =:= "" of
                         true -> error;
                         false -> {Host, Port}
                     end;
                 _ ->
                     error
             end,
    case Parsed of
        {Name, Digits} ->
            case Digits =/= "" andalso lists:all(fun(C) -> C >= $0 andalso C =< $9 end, Digits)
                 andalso length(Digits) =< 5 andalso list_to_integer(Digits) =< 65535 of
                true -> {ok, Name, list_to_integer(Digits)};
                false -> error
            end;
        error ->
            error
    end.

%% Report §12.5: a node runs over its listener's family of addresses, or
%% IPv4 where it has no listener; the carrier boots over it.
-spec family(none | {inet:ip_address(), inet:port_number()}) -> inet | inet6.
family(none) -> inet;
family({Address, _}) when tuple_size(Address) =:= 4 -> inet;
family({_, _}) -> inet6.

%% Report §12.5: each peer a name, a public key and an address, the address
%% left out where the peer is never dialed, of the family of the node's
%% listener, Listen; names and keys each once.
peers(ConfigDir, List, Listen) when is_list(List) ->
    Peers = [peer(ConfigDir, Item, Listen) || Item <- List],
    Names = [Name || #peer{name = Name} <- Peers],
    Keys = [Key || #peer{public_key = Key} <- Peers],
    case Names -- lists:usort(Names) of
        [] -> ok;
        [Twice | _] -> fail(ConfigDir, ?CONF, "two peers are named " ++ ern_conf:quoted(Twice))
    end,
    length(Keys) =:= length(lists:usort(Keys))
        orelse fail(ConfigDir, ?CONF, "two peers have one public-key, and two nodes with one key"
                                      " are one node"),
    Peers;
peers(ConfigDir, _, _) ->
    fail(ConfigDir, ?CONF, "peers is not a JSON array").

%% Report §12.5: a peer's name is not empty and holds no control character
%% (§2.1), so that §12.5's lines and a printed process (Appendix E.1) write
%% it as it stands; every read of the file comes through here, a start, a
%% reload, `ern reload`'s and `ern config --peer-dir`'s, which judges its
%% new entry so too (§11.3).
peer(ConfigDir, Item, Listen) ->
    Fields = object(ConfigDir, "a peer", Item, ?PEER_FIELDS),
    Name = case Fields of
               #{<<"name">> := Text} when is_binary(Text), Text =/= <<>> -> Text;
               _ -> fail(ConfigDir, ?CONF, "a peer has no name")
           end,
    lists:any(fun ern_build:is_control/1, unicode:characters_to_list(Name))
        andalso fail(ConfigDir, ?CONF, "a peer's name holds a control character: "
                                       ++ ern_conf:quoted(Name)),
    Shown = "peer " ++ ern_conf:quoted(Name),
    Key = case Fields of
              #{<<"public-key">> := Pem} ->
                  public_key_der(ConfigDir, Shown ++ "'s public-key", Pem);
              _ -> fail(ConfigDir, ?CONF, Shown ++ " has no public-key")
          end,
    Address = case Fields of
                  #{<<"network-address">> := AddressText} ->
                      address(ConfigDir, Shown, AddressText, Listen);
                  _ -> none
              end,
    #peer{name = Name, public_key = Key, address = Address}.

%% Report §12.5: a peer's address, `host:port`, the host an address of the
%% node's family or a name, which is not resolved here: the host resolves
%% it at each dial, where its family is checked (ern_epmd), so that reading
%% the file waits on no resolver.
address(ConfigDir, Shown, Text, Listen) when is_binary(Text) ->
    case endpoint(Text) of
        {ok, Host, Port} when Port > 0 ->
            case inet:parse_strict_address(Host) of
                {ok, Address} ->
                    same_family(ConfigDir, Shown, Text, family({Address, Port}), Listen),
                    {Address, Port};
                {error, _} ->
                    {Host, Port}
            end;
        _ ->
            fail(ConfigDir, ?CONF, Shown ++ "'s network-address is not host:port with a port from"
                                            " 1 to 65535: " ++ ern_conf:quoted(Text))
    end;
address(ConfigDir, Shown, _, _) ->
    fail(ConfigDir, ?CONF, Shown ++ "'s network-address is not a string").

%% A peer's address of the family the node runs over, its listener's or
%% IPv4 where it has none; one of the other family is refused, saying
%% which of the two the node's is.
same_family(ConfigDir, Shown, Text, PeerFamily, Listen) ->
    case family(Listen) of
        PeerFamily ->
            ok;
        Family ->
            {Own, Other} = case Family of inet -> {"IPv4", "IPv6"}; inet6 -> {"IPv6", "IPv4"} end,
            Why = case Listen of
                      none -> ", since it has no listener";
                      _ -> ", its listener's family"
                  end,
            fail(ConfigDir, ?CONF, Shown ++ "'s network-address " ++ ern_conf:quoted(Text) ++ " is "
                                   ++ Other ++ ", and this node runs over " ++ Own ++ Why)
    end.

%% A public key in PEM: the DER of its SubjectPublicKeyInfo, which the
%% host's decoder reads; one it cannot read is no public key (report §12.5).
public_key_der(ConfigDir, Shown, Pem) when is_binary(Pem) ->
    Decoded = try
                  [{Entry, public_key:pem_entry_decode(Entry)}
                   || Entry <- public_key:pem_decode(Pem)]
              catch _:_ -> none
              end,
    case Decoded of
        [{{'SubjectPublicKeyInfo', Der, not_encrypted}, _}] -> Der;
        _ -> fail(ConfigDir, ?CONF, Shown ++ " is not one public key in PEM")
    end;
public_key_der(ConfigDir, Shown, _) ->
    fail(ConfigDir, ?CONF, Shown ++ " is not a string").

%% Report §8.7: `services`, a service's name to the peers that may offer
%% it, each a listed peer once, in the order a find asks them.
services(ConfigDir, Item, Peers) ->
    PeerNames = [Name || #peer{name = Name} <- Peers],
    Pairs = case Item of
                {object, Found} -> Found;
                _ -> fail(ConfigDir, ?CONF, "services is not a JSON object")
            end,
    lists:foldl(fun({Name, Listed}, Acc) ->
                    Shown = "service " ++ ern_conf:quoted(Name),
                    Name =/= <<>>
                        orelse fail(ConfigDir, ?CONF, "services names a service with no name"),
                    is_map_key(Name, Acc)
                        andalso fail(ConfigDir, ?CONF, "services gives " ++ Shown ++ " twice"),
                    is_list(Listed) andalso lists:all(fun is_binary/1, Listed)
                        orelse fail(ConfigDir, ?CONF, Shown ++ " is not a list of peers' names"),
                    lists:foreach(fun(Peer) ->
                                      lists:member(Peer, PeerNames)
                                          orelse fail(ConfigDir, ?CONF,
                                                      Shown ++ " names " ++ ern_conf:quoted(Peer)
                                                      ++ ", which is no peer's name")
                                  end, Listed),
                    length(Listed) =:= length(lists:usort(Listed))
                        orelse fail(ConfigDir, ?CONF, Shown ++ " names a peer twice"),
                    Acc#{Name => Listed}
                end, #{}, Pairs).

%% Report §12.5: `measures`, `cpu`, `memory` and `disk`, each with the host's
%% parameters by their meaning: `check-interval` in milliseconds, a whole
%% number of minutes for memory, whose host measure counts minutes, and
%% `almost-full` a fraction from 0 to 1.
measures(_ConfigDir, none) ->
    #{};
measures(ConfigDir, Item) ->
    Fields = object(ConfigDir, "measures", Item, [<<"cpu">>, <<"memory">>, <<"disk">>]),
    maps:from_list([{binary_to_atom(Name), measure(ConfigDir, Name, Value)}
                    || {Name, Value} <- maps:to_list(Fields)]).

measure(ConfigDir, <<"cpu">>, Item) ->
    object(ConfigDir, "measures' cpu", Item, []);
measure(ConfigDir, Name, Item) ->
    Shown = "measures' " ++ binary_to_list(Name),
    Fields = object(ConfigDir, Shown, Item, [<<"check-interval">>, <<"almost-full">>]),
    maps:from_list(
      [{check_interval, interval(ConfigDir, Shown, Name, Ms)}
       || #{<<"check-interval">> := Ms} <- [Fields]]
      ++ [{almost_full, fraction(ConfigDir, Shown, Full)}
          || #{<<"almost-full">> := Full} <- [Fields]]).

interval(ConfigDir, Shown, Name, Ms) ->
    is_integer(Ms) andalso Ms > 0
        orelse fail(ConfigDir, ?CONF, Shown ++ "'s check-interval is not a count of milliseconds"
                                               " above 0"),
    Name =/= <<"memory">> orelse Ms rem 60000 =:= 0
        orelse fail(ConfigDir, ?CONF, Shown ++ "'s check-interval is not a whole number of"
                                               " minutes, which the host's memory measure counts"),
    Ms.

fraction(ConfigDir, Shown, Full) ->
    is_number(Full) andalso Full >= 0 andalso Full =< 1
        orelse fail(ConfigDir, ?CONF, Shown ++ "'s almost-full is not a fraction from 0 to 1"),
    Full.

%% Report Appendix C, Appendix E.27: `utilization-interval`, the
%% milliseconds between the node's tellings of how busy it is to its peers,
%% 5000 where the entry is absent; a count of milliseconds, as
%% `check-interval` is.
utilization_interval(_ConfigDir, Ms) when is_integer(Ms), Ms > 0 ->
    Ms;
utilization_interval(ConfigDir, _) ->
    fail(ConfigDir, ?CONF, "utilization-interval is not a count of milliseconds above 0").

%% Report §12.5: `limits`, the most of the host's processes and of its ports
%% the node holds, `processes` and `ports`, each a whole number from 1024 to
%% 67108864, kept as given: the node's limit is the least power of two at or
%% above it, which the host takes as it boots (ern_carrier:boot_flags/1);
%% none where the section is absent, the host's own.
limits(_ConfigDir, none) ->
    #{};
limits(ConfigDir, Item) ->
    Fields = object(ConfigDir, "limits", Item, [<<"processes">>, <<"ports">>]),
    maps:from_list([{binary_to_atom(Name), limit(ConfigDir, Name, Count)}
                    || {Name, Count} <- maps:to_list(Fields)]).

limit(_ConfigDir, _Name, Count) when is_integer(Count), Count >= 1024, Count =< 67108864 ->
    Count;
limit(ConfigDir, Name, _) ->
    fail(ConfigDir, ?CONF, "limits' " ++ binary_to_list(Name) ++ " is not a whole number from"
                           " 1024 to 67108864").

%%
%% Utilities
%%

-spec fail(file:filename(), string(), iodata()) -> no_return().
fail(ConfigDir, File, Message) ->
    ern_build:fail(ern_build:shown(filename:join(ConfigDir, File)) ++ ": " ++ Message).
