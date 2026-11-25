%% The helpers the tests share beside their waits (ern_waits): a module
%% compiled from text, loaded, and unloaded again, a unit out of the code
%% table among them; the messages of one tag a process's mailbox holds; the
%% side of an Either; the options of a run whose standard output is let
%% go; a process of another node; and a node's certificate forged.
-module(ern_helpers).

-export([loaded/2, unloaded/1, taken/1, side/1, quiet/0, quiet/1, far_process/0,
         forged_certificate/2]).

-include_lib("public_key/include/public_key.hrl").

%% Module compiled from Forms, each the text of one form, every function of
%% no argument exported, and loaded from memory, so that no file is
%% written; a test unloads it once it ends (unloaded/1), since the flake
%% hunt runs a test again in the same host.
-spec loaded(module(), [iodata()]) -> module().
loaded(Module, Forms) ->
    Texts = [io_lib:format("-module(~w).", [Module]),
             "-compile([export_all, nowarn_export_all])." | Forms],
    {ok, Module, Binary} = compile:forms([form(Text) || Text <- Texts]),
    {module, Module} = code:load_binary(Module, atom_to_list(Module) ++ ".erl", Binary),
    Module.

form(Text) ->
    {ok, Tokens, _} = erl_scan:string(lists:flatten(Text)),
    {ok, Form} = erl_parse:parse_form(Tokens),
    Form.

%% Report §8.7, §11.2: Module out of the code table, where it is a unit
%% there, and out of the host, its old code and its current purged; a
%% module the host does not hold is passed over.
-spec unloaded(module()) -> ok.
unloaded(Module) ->
    ok = ern_code:unloaded(Module),
    _ = code:purge(Module),
    _ = code:delete(Module),
    _ = code:purge(Module),
    ok.

%% What the calling process's mailbox holds under Tag, every `{Tag, Value}`
%% so far, taken, their values in the order they came.
-spec taken(term()) -> [term()].
taken(Tag) ->
    receive {Tag, Value} -> [Value | taken(Tag)] after 0 -> [] end.

%% Which side of an Either a result is, Left or Right.
-spec side({'Left' | 'Right', term()}) -> 'Left' | 'Right'.
side({Side, _}) -> Side.

%% A run's options, ern_rt:run_main/3's, its standard output let go.
-spec quiet() -> map().
quiet() ->
    #{stdout => fun(_) -> ok end}.

%% The same, with Options beside it.
-spec quiet(map()) -> map().
quiet(Options) ->
    maps:merge(quiet(), Options).

%% Report §8.7: a process of another node, `other@node.er`, which no
%% connection names, read from its external term.
-spec far_process() -> pid().
far_process() ->
    binary_to_term(<<131, 88, 119, 13, "other@node.er", 0:32, 1:32, 1:32>>).

%% Report §12.5: a certificate signed with the key of the configuration
%% directory Dir that names the host given, its DER, for the rule to refuse
%% where the host is another node's or none a key gives.
-spec forged_certificate(file:filename(), string()) -> binary().
forged_certificate(Dir, Host) ->
    {ok, Pem} = file:read_file(filename:join(Dir, "private-key.pem")),
    [Entry] = public_key:pem_decode(Pem),
    {'ECPrivateKey', _, Private, _, _, _} = Key = public_key:pem_entry_decode(Entry),
    {Point, _} = crypto:generate_key(eddsa, ed25519, Private),
    Name = {rdnSequence, [[#'AttributeTypeAndValue'{type = ?'id-at-commonName',
                                                    value = {utf8String, <<"ernest">>}}]]},
    Tbs = #'OTPTBSCertificate'{
             version = v3, serialNumber = 1,
             signature = #'SignatureAlgorithm'{algorithm = ?'id-Ed25519'},
             issuer = Name, subject = Name,
             validity = #'Validity'{notBefore = {utcTime, "700101000000Z"},
                                    notAfter = {generalTime, "99991231235959Z"}},
             subjectPublicKeyInfo = #'OTPSubjectPublicKeyInfo'{
                                       algorithm = #'PublicKeyAlgorithm'{algorithm = ?'id-Ed25519'},
                                       subjectPublicKey = #'ECPoint'{point = Point}},
             extensions = [#'Extension'{extnID = ?'id-ce-subjectAltName', critical = false,
                                        extnValue = [{dNSName, Host}]}]},
    public_key:pkix_sign(Tbs, Key).
