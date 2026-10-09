%% Report §8.3, §8.7, §11.3, Appendix C: a node's configuration directory,
%% the one owner of its shape. `ern config` makes it, a key, a certificate
%% the node signs itself and `ernest.conf`; a node started with it checks
%% it, reads `ernest.conf` whole, writes its process number to `ernest.pid`
%% and removes it at its end, and starts the host's measures the file
%% names. A refusal is the runner's (ern_build:fail/1), naming the file.
-module(ern_node).

-export([create/1, start/1, start/2, stop/1, file/2, read/1, measures_changed/3, signalled/2,
         family/1]).

-include_lib("public_key/include/public_key.hrl").
-include_lib("kernel/include/file.hrl").
-include("ern_node.hrl").

-define(CONF, "ernest.conf").
-define(KEY, "private-key.pem").
-define(CERTIFICATE, "certificate.pem").
-define(PID_FILE, "ernest.pid").

%% The certificate's subject, the same for every node, since a peer is known
%% by its key and the host its key gives (report §8.7).
-define(NAME, <<"ernest">>).

%% Report §8.7, Appendix E.27: what `ernest.conf` may say.
-define(FIELDS, [<<"listen">>, <<"public-key">>, <<"peers">>, <<"keys">>, <<"measures">>]).
-define(PEER_FIELDS, [<<"name">>, <<"public-key">>, <<"network-address">>]).

%%
%% ern config
%%

%% Report §11.3, Appendix C: the configuration directory made, with this
%% node's key, the certificate it signs itself and `ernest.conf`; the
%% public key is answered, which `ern config` prints. The directory is made
%% here or not at all, so that one another made first, as this runs, is
%% refused, and it is its owner's alone before a file is written in it, so
%% that no one else can open a file there, the key's while it is being
%% written among them. What another put in it before it was its owner's
%% alone would be written through, a link among them, so it must hold
%% nothing then. A name ending in `/` names the directory before it.
-spec create(file:filename()) -> binary().
create(Given) ->
    ConfigDir = filename:join([Given]),
    ok = ern_build:make_dirs(ConfigDir),
    case file:make_dir(ConfigDir) of
        ok -> ok = file:change_mode(ConfigDir, 8#700);
        {error, eexist} -> ern_build:fail(ConfigDir ++ " exists");
        {error, Error} -> ern_build:fail(ConfigDir ++ ": " ++ file:format_error(Error))
    end,
    file:list_dir_all(ConfigDir) =:= {ok, []}
        orelse ern_build:fail(ConfigDir ++ " was written to by another as it was made"),
    %% report §8.7: an ed25519 key, which serves in the handshake under the
    %% rule (the log's *The Node's Directory*)
    Key = public_key:generate_key({namedCurve, ed25519}),
    Public = pem([{'SubjectPublicKeyInfo', public_der(Key), not_encrypted}]),
    Certificate = pem([{'Certificate', signed_certificate(Key), not_encrypted}]),
    Private = pem([public_key:pem_entry_encode('PrivateKeyInfo', Key)]),
    %% written by the host's JSON formatter, its fields in Appendix C's
    %% order, two spaces a level, and a line feed at its end; a PEM's line
    %% breaks are escapes, as in any JSON string
    Fields = [{<<"listen">>, <<"0.0.0.0:8654">>}, {<<"public-key">>, Public}, {<<"peers">>, []},
              {<<"keys">>, #{}}],
    Json = json:format({ordered, Fields}, fun ordered/3, #{indent => 2}),
    ok = ern_build:write_output(filename:join(ConfigDir, ?CONF), Json),
    ok = ern_build:write_output(filename:join(ConfigDir, ?CERTIFICATE), Certificate),
    %% the key is its owner's alone before it is written
    ok = ern_build:write_output(filename:join(ConfigDir, ?KEY), Private, 8#600),
    Public.

%% Report Appendix C: an object whose fields keep the order given, for the
%% host's JSON formatter, which writes a map's fields in an order of its
%% own; every other value as the formatter writes it.
ordered({ordered, Fields}, Encode, State) ->
    json:format_key_value_list_checked(Fields, Encode, State);
ordered(Value, Encode, State) ->
    json:format_value(Value, Encode, State).

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

%% Report §8.7: a certificate the node signs itself, its subject a constant,
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
%% A node's start and end
%%

%% Report §8.7: a node starts from its configuration directory: the
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
        stop(ConfigDir),
        erlang:raise(Class, Reason, Trace)
    end,
    Configuration.

%% Report §8.7: a node stops the host's measures at its end, and removes
%% `ernest.pid`, where the file is still its own.
-spec stop(file:filename()) -> ok.
stop(ConfigDir) ->
    measures_stopped(),
    PidFile = file(ConfigDir, pid),
    Own = list_to_binary(os:getpid() ++ "\n"),
    case file:read_file(PidFile) of
        {ok, Own} -> _ = file:delete(PidFile), ok;
        _ -> ok
    end.

%% A file of the configuration directory: `ernest.conf`, the key, the
%% certificate or `ernest.pid`.
-spec file(file:filename(), conf | key | certificate | pid) -> file:filename().
file(ConfigDir, conf) -> filename:join(ConfigDir, ?CONF);
file(ConfigDir, key) -> filename:join(ConfigDir, ?KEY);
file(ConfigDir, certificate) -> filename:join(ConfigDir, ?CERTIFICATE);
file(ConfigDir, pid) -> filename:join(ConfigDir, ?PID_FILE).

%% Report §8.7: the directory checked and `ernest.conf` read: the
%% directory, and each file a node reads in it, its user's own or the
%% superuser's and written by none beyond its owner and group, as the
%% shell's startup files are (§11.2), and the key read by none but its
%% owner, as ssh reads one; the file JSON, every field known; the key the
%% one `ernest.conf` names and the certificate's, and the certificate naming
%% the host the key gives.
-spec read(file:filename()) -> #configuration{}.
read(ConfigDir) ->
    User = ern_os:user(),
    owned(ConfigDir, ConfigDir, directory, User),
    lists:foreach(fun(File) -> owned(ConfigDir, filename:join(ConfigDir, File), regular, User) end,
                  [?CONF, ?CERTIFICATE, ?KEY]),
    Configuration = configuration(ConfigDir),
    Key = private_key(ConfigDir),
    Own = public_der(Key),
    Own =:= Configuration#configuration.public_key
        orelse fail(ConfigDir, ?CONF, "public-key is not the key of " ++ ?KEY),
    Certificate = certificate(ConfigDir),
    certified_key(Certificate) =:= Own
        orelse fail(ConfigDir, ?CERTIFICATE, "certifies another key than " ++ ?KEY),
    ern_carrier:names_own_host(Certificate)
        orelse fail(ConfigDir, ?CERTIFICATE, "names another host than its key gives, and a peer"
                                             " refuses it; ern config makes one that names it"),
    lists:any(fun(#peer{public_key = Peer}) -> Peer =:= Own end,
              Configuration#configuration.peers)
        andalso fail(ConfigDir, ?CONF, "a peer has this node's own key, and a node is no peer"
                                       " of itself"),
    Configuration.

%% A file or the directory: there, of its kind, its user's own or the
%% superuser's, and written by none beyond its owner and group; the key
%% neither read nor written by any but its owner.
owned(ConfigDir, Path, Kind, User) ->
    Shown = ern_build:shown(Path),
    Info = case file:read_file_info(Path, [{time, posix}]) of
               {ok, Found} -> Found;
               {error, enoent} when Kind =:= regular ->
                   ern_build:fail(Shown ++ " is not there; ern config --config-dir "
                                  ++ ern_build:shown(ConfigDir) ++ " makes a configuration"
                                  " directory");
               {error, Error} -> ern_build:refused(Path, Error)
           end,
    Info#file_info.type =:= Kind
        orelse ern_build:fail(Shown ++ " is not a " ++ kind(Kind)),
    lists:member(Info#file_info.uid, [User, 0])
        orelse ern_build:fail(Shown ++ " is another user's, and a node reads only its user's"
                              " own or the superuser's"),
    Info#file_info.mode band 8#002 =:= 0
        orelse ern_build:fail(Shown ++ " may be written by anyone beyond its owner and group"),
    filename:basename(Path) =/= ?KEY orelse Info#file_info.mode band 8#077 =:= 0
        orelse ern_build:fail(Shown ++ " may be read or written by others than its owner"),
    ok.

kind(directory) -> "directory";
kind(regular) -> "regular file".

%% Each file is read through ern_build:read/1, which refuses one that cannot
%% be read with its name and the host's reason; what does not decode is
%% refused with the file and the rule, the host's decoder's failure among
%% it, and nothing of it escapes as a failure of `ern` (report §8.7).
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

%% Report §8.7: `ernest.pid` holds this node's process number from its
%% start, made only where no file is there, so that two nodes started at
%% once cannot both take it; a file that names a living process refuses the
%% start, and one a dead node left, or that names no process, is replaced.
pid_written(ConfigDir) ->
    PidFile = file(ConfigDir, pid),
    case taken(PidFile) of
        ok ->
            ok;
        held ->
            case living(PidFile) of
                {true, ProcessNumber} ->
                    ern_build:fail(ern_build:shown(ConfigDir) ++ " is the configuration directory"
                                   " of the running node " ++ integer_to_list(ProcessNumber)
                                   ++ ", which " ++ ?PID_FILE ++ " names");
                false ->
                    _ = file:delete(PidFile),
                    taken(PidFile) =:= ok
                        orelse ern_build:fail(ern_build:shown(ConfigDir) ++ " was taken by another"
                                              " node as this one started")
            end
    end.

%% The file made with this process's number, or `held` where one is there.
taken(PidFile) ->
    case file:open(PidFile, [write, exclusive, raw, binary]) of
        {ok, Device} ->
            ok = file:write(Device, os:getpid() ++ "\n"),
            ok = file:close(Device);
        {error, eexist} ->
            held;
        {error, Error} ->
            ern_build:refused(PidFile, Error)
    end.

%% Whether the file names a living process, by the helper's signal 0; a
%% file gone meanwhile names none.
living(PidFile) ->
    Text = case file:read_file(PidFile) of
               {ok, Bytes} -> string:trim(binary_to_list(Bytes));
               {error, _} -> ""
           end,
    case string:to_integer(Text) of
        {ProcessNumber, ""} when ProcessNumber > 0 ->
            case ern_os:signal(0, ProcessNumber) of
                none -> false;
                _ -> {true, ProcessNumber}
            end;
        _ ->
            false
    end.

%% Report §8.7: a reload's measures: the host's services stopped and those
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

%% Report §8.7: the host's measures stopped, each program the host runs for
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

%% Report §8.7, §11.2: the signal sent to the node that runs from the
%% directory, which its `ernest.pid` names; where there is none, or its
%% process has ended or is another user's, the job fails, saying so.
-spec signalled(file:filename(), pos_integer()) -> ok.
signalled(ConfigDir, Number) ->
    Text = case file:read_file(file(ConfigDir, pid)) of
               {ok, Bytes} -> string:trim(binary_to_list(Bytes));
               {error, _} -> fail(ConfigDir, ?PID_FILE, "no such file: no node runs from the"
                                                        " directory")
           end,
    ProcessNumber = case string:to_integer(Text) of
                        {Named, ""} when Named > 0 -> Named;
                        _ -> fail(ConfigDir, ?PID_FILE, "names no process")
                    end,
    case ern_os:signal(Number, ProcessNumber) of
        sent -> ok;
        none -> fail(ConfigDir, ?PID_FILE, "names a process that has ended: no node runs from the"
                                           " directory");
        others -> fail(ConfigDir, ?PID_FILE, "names another user's process")
    end.

%% Report §8.7: the host's measures `measures` names, started with their
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

%% Report §8.7, Appendix C: `ernest.conf` read whole: JSON, an object whose
%% every field is known, and none twice in one object, and each whole
%% number one the host can hold.
configuration(ConfigDir) ->
    Text = ern_build:read(file(ConfigDir, conf)),
    Decoders = #{object_start => fun(_) -> [] end,
                 object_push => fun(Name, Item, Acc) -> [{Name, Item} | Acc] end,
                 object_finish => fun(Acc, Outer) -> {{object, lists:reverse(Acc)}, Outer} end,
                 integer => fun(Numeral) -> integer(ConfigDir, Numeral) end},
    Value = try json:decode(Text, ok, Decoders) of
                {Decoded, ok, Rest} ->
                    string:trim(Rest) =:= <<>>
                        orelse fail(ConfigDir, ?CONF, "holds more than one JSON value"),
                    Decoded
            catch
                error:_ -> fail(ConfigDir, ?CONF, "is not JSON")
            end,
    Fields = object(ConfigDir, "the file", Value, ?FIELDS),
    Listen = case Fields of
                 #{<<"listen">> := ListenText} -> listen(ConfigDir, ListenText);
                 _ -> none
             end,
    Family = family(Listen),
    PublicKey = case Fields of
                    #{<<"public-key">> := Pem} -> public_key_der(ConfigDir, "public-key", Pem);
                    _ -> fail(ConfigDir, ?CONF, "names no public-key")
                end,
    Peers = peers(ConfigDir, maps:get(<<"peers">>, Fields, []), Family),
    #configuration{config_dir = ConfigDir, listen = Listen, public_key = PublicKey,
                   peers = Peers,
                   keys = keys(ConfigDir, maps:get(<<"keys">>, Fields, {object, []}), Peers),
                   measures = measures(ConfigDir, maps:get(<<"measures">>, Fields, none))}.

%% A whole number of the file, as the host reads its numeral; one too long
%% for the host to hold, which the host would raise for, is refused with the
%% file and the rule (report §8.7).
integer(ConfigDir, Numeral) ->
    try binary_to_integer(Numeral)
    catch
        error:system_limit ->
            fail(ConfigDir, ?CONF, "holds a number too large for the host to read")
    end.

%% A JSON object's fields as a map, each name among Known.
object(ConfigDir, What, {object, Pairs}, Known) ->
    lists:foldl(fun({Name, Item}, Acc) ->
                    lists:member(Name, Known)
                        orelse fail(ConfigDir, ?CONF, What ++ " has the unknown field "
                                                      ++ binary_to_list(Name)),
                    is_map_key(Name, Acc)
                        andalso fail(ConfigDir, ?CONF, What ++ " gives " ++ binary_to_list(Name)
                                                       ++ " twice"),
                    Acc#{Name => Item}
                end, #{}, Pairs);
object(ConfigDir, What, _, _) ->
    fail(ConfigDir, ?CONF, What ++ " is not a JSON object").

%% Report §8.7: `listen`, an address of one interface, or `0.0.0.0` or `::`
%% for all, and a port, 0 for one the host picks.
listen(ConfigDir, Text) when is_binary(Text) ->
    case endpoint(Text) of
        {ok, Host, Port} ->
            case inet:parse_strict_address(Host) of
                {ok, Address} -> {Address, Port};
                {error, _} ->
                    fail(ConfigDir, ?CONF, "listen names no address: " ++ json_quoted(Text))
            end;
        error ->
            fail(ConfigDir, ?CONF, "listen is not address:port: " ++ json_quoted(Text))
    end;
listen(ConfigDir, _) ->
    fail(ConfigDir, ?CONF, "listen is not a string").

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

%% Report §8.7: a node runs over its listener's family of addresses, or
%% IPv4 where it has no listener; the carrier boots over it.
-spec family(none | {inet:ip_address(), inet:port_number()}) -> inet | inet6.
family(none) -> inet;
family({Address, _}) when tuple_size(Address) =:= 4 -> inet;
family({_, _}) -> inet6.

%% Report §8.7: each peer a name, a public key and an address, the address
%% left out where the peer is never dialled; names and keys each once.
peers(ConfigDir, List, Family) when is_list(List) ->
    Peers = [peer(ConfigDir, Item, Family) || Item <- List],
    Names = [Name || #peer{name = Name} <- Peers],
    Keys = [Key || #peer{public_key = Key} <- Peers],
    case Names -- lists:usort(Names) of
        [] -> ok;
        [Twice | _] -> fail(ConfigDir, ?CONF, "two peers are named " ++ json_quoted(Twice))
    end,
    length(Keys) =:= length(lists:usort(Keys))
        orelse fail(ConfigDir, ?CONF, "two peers have one public-key, and two nodes with one key"
                                      " are one node"),
    Peers;
peers(ConfigDir, _, _) ->
    fail(ConfigDir, ?CONF, "peers is not a JSON array").

peer(ConfigDir, Item, Family) ->
    Fields = object(ConfigDir, "a peer", Item, ?PEER_FIELDS),
    Name = case Fields of
               #{<<"name">> := Text} when is_binary(Text), Text =/= <<>> -> Text;
               _ -> fail(ConfigDir, ?CONF, "a peer has no name")
           end,
    Shown = "peer " ++ json_quoted(Name),
    Key = case Fields of
              #{<<"public-key">> := Pem} ->
                  public_key_der(ConfigDir, Shown ++ "'s public-key", Pem);
              _ -> fail(ConfigDir, ?CONF, Shown ++ " has no public-key")
          end,
    Address = case Fields of
                  #{<<"network-address">> := AddressText} ->
                      address(ConfigDir, Shown, AddressText, Family);
                  _ -> none
              end,
    #peer{name = Name, public_key = Key, address = Address}.

%% Report §8.7: a peer's address, `host:port`, the host an address of the
%% node's family or a name, which is not resolved here: the host resolves
%% it at each dial, where its family is checked (ern_epmd), so that reading
%% the file waits on no resolver.
address(ConfigDir, Shown, Text, Family) when is_binary(Text) ->
    case endpoint(Text) of
        {ok, Host, Port} when Port > 0 ->
            case inet:parse_strict_address(Host) of
                {ok, Address} ->
                    same_family(ConfigDir, Shown, Text, family({Address, Port}) =:= Family,
                                Family),
                    {Address, Port};
                {error, _} ->
                    {Host, Port}
            end;
        _ ->
            fail(ConfigDir, ?CONF, Shown ++ "'s network-address is not host:port with a port from"
                                            " 1 to 65535: " ++ json_quoted(Text))
    end;
address(ConfigDir, Shown, _, _) ->
    fail(ConfigDir, ?CONF, Shown ++ "'s network-address is not a string").

same_family(_, _, _, true, _) ->
    ok;
same_family(ConfigDir, Shown, Text, false, Family) ->
    {Own, Other} = case Family of inet -> {"IPv4", "IPv6"}; inet6 -> {"IPv6", "IPv4"} end,
    fail(ConfigDir, ?CONF, Shown ++ "'s network-address " ++ json_quoted(Text) ++ " is " ++ Other
                           ++ ", and this node runs over " ++ Own ++ ", its listener's family or"
                           " IPv4 where it has none").

%% A public key in PEM: the DER of its SubjectPublicKeyInfo, which the
%% host's decoder reads; one it cannot read is no public key (report §8.7).
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

%% Report §8.7: `keys`, a key's name to the peers that may offer it, each a
%% listed peer once, in the order a find asks them.
keys(ConfigDir, Item, Peers) ->
    Names = [Name || #peer{name = Name} <- Peers],
    Pairs = case Item of
                {object, Found} -> Found;
                _ -> fail(ConfigDir, ?CONF, "keys is not a JSON object")
            end,
    lists:foldl(fun({Key, Listed}, Acc) ->
                    Shown = "key " ++ json_quoted(Key),
                    Key =/= <<>> orelse fail(ConfigDir, ?CONF, "keys names a key with no name"),
                    is_map_key(Key, Acc) andalso fail(ConfigDir, ?CONF, "keys gives " ++ Shown
                                                                        ++ " twice"),
                    is_list(Listed) andalso lists:all(fun is_binary/1, Listed)
                        orelse fail(ConfigDir, ?CONF, Shown ++ " is not a list of peers' names"),
                    lists:foreach(fun(Name) ->
                                      lists:member(Name, Names)
                                          orelse fail(ConfigDir, ?CONF,
                                                      Shown ++ " names " ++ json_quoted(Name)
                                                      ++ ", which is no peer's name")
                                  end, Listed),
                    length(Listed) =:= length(lists:usort(Listed))
                        orelse fail(ConfigDir, ?CONF, Shown ++ " names a peer twice"),
                    Acc#{Key => Listed}
                end, #{}, Pairs).

%% Report §8.7: `measures`, `cpu`, `memory` and `disk`, each with the host's
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

%%
%% Utilities
%%

%% A text as JSON writes it, in its quotes, as a refusal shows a value of
%% the file.
json_quoted(Text) ->
    binary_to_list(iolist_to_binary(json:encode(Text))).

-spec fail(file:filename(), string(), iodata()) -> no_return().
fail(ConfigDir, File, Message) ->
    ern_build:fail(ern_build:shown(filename:join(ConfigDir, File)) ++ ": " ++ Message).
