#!/bin/sh
# VERSION, the release the checkout works toward, set to the one given,
# x.y.z, with every line a test holds to it (docs/reviews/release.md, step
# 5): a shell's start line in a tracked document, the log and the proposals
# aside, `Ernest x.y.z, session 1. :help for help.`, the third line of each
# of the report's files, `For Ernest x.y.z.`, and the session fixtures'
# start line, which names the version text of a build that is no release,
# `x.y.z-dev` (ern_release). Each line is matched whole, so that
# a `since` line and a sentence naming a release stay as they are. The
# pages make man writes name the version text too, and make version writes
# them after this script.
#
# Given a directory, the checkout's files are rewritten under it instead,
# as ern_docs_tests' version_test does. VERSION is written last, so that a
# run that stopped is run again with the same version.

set -euf

repo=$(cd "$(dirname "$0")/.." && pwd -P)
new=${1:-}
dir=${2:-$repo}

# Whether Text is a version, x.y.z.
is_version() {
    printf '%s\n' "$1" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+'
}

is_version "$new" || { echo "usage: make version V=x.y.z" >&2; exit 2; }
old=$(cat "$dir/VERSION")
is_version "$old" || { echo "version.sh: $dir/VERSION holds no x.y.z" >&2; exit 1; }
[ "$new" != "$old" ] || exit 0

was=$(printf '%s' "$old" | sed 's/\./\\./g')
start=', session \([1-9][0-9]*\)\. :help for help\.$'
rest=', session \1. :help for help.'

# File, under dir, rewritten by the sed script Script, its mode kept.
rewrite() {
    sed "$2" "$dir/$1" > "$dir/$1.new"
    cat "$dir/$1.new" > "$dir/$1"
    rm "$dir/$1.new"
}

# The tracked documents that hold a start line, grep's 1 being none.
documents=$(git -C "$repo" ls-files -- '*.md' ':!docs/log/' ':!docs/proposals/')
held=$(cd "$dir" && grep -l "^Ernest $was$start" $documents) || [ $? -eq 1 ]
for file in $held; do
    rewrite "$file" "s/^Ernest $was$start/Ernest $new$rest/"
done
for file in report/language.md report/toolchain.md report/library.md; do
    rewrite "$file" "3s/^For Ernest $was\\.$/For Ernest $new./"
done
for file in test/fixtures/session/basic.out test/fixtures/session/attached.out; do
    rewrite "$file" "s/^Ernest $was-dev$start/Ernest $new-dev$rest/"
done
printf '%s\n' "$new" > "$dir/VERSION"
