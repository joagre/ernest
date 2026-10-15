#!/usr/bin/env escript
%% Re-signs NAME.pem with NAME.key so that its validity ended in 2021: the rule
%% accepts a listed key whatever the certificate's dates say.
-include_lib("public_key/include/public_key.hrl").
main([Name]) ->
    {ok, CertPem} = file:read_file(Name ++ ".pem"),
    [{'Certificate', Der, _}] = public_key:pem_decode(CertPem),
    {ok, KeyPem} = file:read_file(Name ++ ".key"),
    [Entry] = public_key:pem_decode(KeyPem),
    Key = public_key:pem_entry_decode(Entry),
    #'OTPCertificate'{tbsCertificate = Tbs} = public_key:pkix_decode_cert(Der, otp),
    Validity = #'Validity'{notBefore = {utcTime, "200101000000Z"}, notAfter = {utcTime, "210101000000Z"}},
    Der1 = public_key:pkix_sign(Tbs#'OTPTBSCertificate'{validity = Validity}, Key),
    ok = file:write_file(Name ++ ".pem", public_key:pem_encode([{'Certificate', Der1, not_encrypted}])).
