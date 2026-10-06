%% A peer's certificate is accepted where its public key is one this node lists.
%% TLS calls verify/3 where the options file names it as the `verify_fun`.
-module(ern_probe_pin).

-export([verify/3]).

-include_lib("public_key/include/public_key.hrl").

%% A self-signed certificate is what the host refuses by default, and is the
%% one event this rule answers for itself.
-spec verify(#'OTPCertificate'{}, term(), [file:filename()]) ->
          {valid, [file:filename()]} | {unknown, [file:filename()]} | {fail, term()}.
verify(Certificate, {bad_cert, selfsigned_peer}, Listed) ->
    case lists:member(key(Certificate), [key(listed(File)) || File <- Listed]) of
        true -> {valid, Listed};
        false -> {fail, not_listed}
    end;
verify(_Certificate, {bad_cert, _} = Reason, _Listed) -> {fail, Reason};
verify(_Certificate, {extension, _}, Listed) -> {unknown, Listed};
verify(_Certificate, valid, Listed) -> {valid, Listed};
verify(_Certificate, valid_peer, Listed) -> {valid, Listed}.

key(#'OTPCertificate'{tbsCertificate = Tbs}) ->
    Tbs#'OTPTBSCertificate'.subjectPublicKeyInfo.

listed(File) ->
    {ok, Pem} = file:read_file(File),
    [{'Certificate', Der, _}] = public_key:pem_decode(Pem),
    public_key:pkix_decode_cert(Der, otp).
