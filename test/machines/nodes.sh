#!/bin/sh
# Nodes across the machines of test/machines/machines.txt (plan, MVP 3.27
# item 1, docs/development.md): `check`, each machine's commit, version and
# floor against this checkout's; `pull`, each other clone pulled and built
# by make; `start`, a bare node on each machine listening on 8654, every
# node listing every other, and a shell's directory here that lists them
# all; `stop`; and `status`. Each step is ern_machines's, run from test/.

case $1 in
    check|pull|start|stop|status) ;;
    *) echo "usage: $0 check | pull | start | stop | status" >&2; exit 2 ;;
esac

tests=$(cd "$(dirname "$0")/.." && pwd -P)
if ! test -f "$tests/../erl/shared/ebin/ern_tree.beam"; then
    echo "nodes.sh: this checkout is not built: make at its top builds it" >&2
    exit 1
fi
make -s -C "$tests" machines || exit 1
cd "$tests" && exec erl -noinput -pa ../erl/*/ebin -pa ebin -eval "ern_machines:main([\"$1\"])"
