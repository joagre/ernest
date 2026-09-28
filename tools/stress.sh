#!/bin/sh
# make stress (docs/review.md R2): the whole suite under the emulator's most
# modified timing, +T 9, and then three times in a row while every core of
# the machine runs a busy loop, since a race shows only now and then. Each
# run's output is kept in build/stress/, and the status is 1 where any run
# failed. The first argument is the make to run the suite with.
#
# Every time limit of the suite's EUnit runs is twenty times its own, since
# a limit is set for a quiet machine and these runs are slower on purpose:
# under +T 9 a test of a thousand rounds of monitors took 49 seconds of its
# five, and under the busy loops tests that only compute ran past theirs. A
# race still fails on what it gets wrong, and a wait that never ends still
# ends at its limit.

make=$1
scaled='EUNIT_OPTS=[{scale_timeouts, 20}]'
out=build/stress
rm -rf "$out"
mkdir -p "$out"
status=0

run() {
    name=$1
    shift
    if "$@" > "$out/$name.log" 2>&1; then
        echo "make stress: $name green"
    else
        echo "make stress: $name failed; $out/$name.log"
        status=1
    fi
}

run timing env ERL_AFLAGS="+T 9" "$make" test "$scaled"

cores=$(getconf _NPROCESSORS_ONLN)
busy=
i=0
while [ "$i" -lt "$cores" ]; do
    (while :; do :; done) &
    busy="$busy $!"
    i=$((i + 1))
done
trap 'kill $busy 2>/dev/null' EXIT
trap 'exit 1' INT TERM
for n in 1 2 3; do
    run "load$n" "$make" test "$scaled"
done
exit "$status"
