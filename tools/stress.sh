#!/bin/sh
# make stress (docs/review.md R2): the whole suite under the emulator's most
# modified timing, +T 9, and then three times in a row while every core of
# the machine runs a busy loop, since a race shows only now and then. Each
# run's output is kept in build/stress/, and the status is 1 where any run
# failed. The first argument is the make to run the suite with.

make=$1
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

run timing env ERL_AFLAGS="+T 9" "$make" test

cores=$(getconf _NPROCESSORS_ONLN)
busy=
i=0
while [ "$i" -lt "$cores" ]; do
    (while :; do :; done) &
    busy="$busy $!"
    i=$((i + 1))
done
trap 'kill $busy 2>/dev/null' EXIT INT TERM
for n in 1 2 3; do
    run "load$n" "$make" test
done
exit "$status"
