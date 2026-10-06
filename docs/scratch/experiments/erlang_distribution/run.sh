#!/bin/sh
# Runs the experiment: three nodes on this machine over TLS distribution.
# Needs erl and openssl. It works in a directory it makes and removes, and
# keeps no key.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

# A key and a self-signed certificate for each node.
for node in a b c; do
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
        -keyout "$node.key" -out "$node.pem" -subj "/CN=$node" -days 2 \
        -addext "subjectAltName=IP:127.0.0.1" 2>/dev/null
done

# A node's TLS options: its own certificate, and the certificates it lists.
options() {
    node=$1
    shift
    listed=$(printf '"%s", ' "$@" | sed 's/, $//')
    cat "$@" > "trust_$node.pem"
    for side in server client; do
        printf ' {%s, [{certfile, "%s"}, {keyfile, "%s"}, {cacertfile, "%s"},\n' \
            "$side" "$work/$node.pem" "$work/$node.key" "$work/trust_$node.pem"
        printf '   {verify, verify_peer}, {versions, [%s]},\n' "'tlsv1.3'"
        if [ "$side" = server ]; then
            printf '   {fail_if_no_peer_cert, true},\n'
        fi
        printf '   {verify_fun, {fun ern_probe_pin:verify/3, [%s]}}]}' "$listed"
        if [ "$side" = server ]; then
            printf ',\n'
        fi
    done | { printf '['; cat; printf '].\n'; } > "$node.conf"
}

# a lists b; b lists a and c; c lists b.
options a "$work/b.pem"
options b "$work/a.pem" "$work/c.pem"
options c "$work/b.pem"

erlc -o "$work" "$here"/ern_probe_epmd.erl "$here"/ern_probe_pin.erl "$here"/ern_probe.erl
ERL_CRASH_DUMP_SECONDS=0 erl -noshell -pa "$work" -eval 'ern_probe:run(), halt().'
