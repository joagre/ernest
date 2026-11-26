#!/bin/sh
# The toolchain on a host's code path, as bin/ern gives it, for the tree in
# $1: the flags for a host a shell starts, the tree quoted for that shell
# and each directory a pattern it expands. The Makefiles,
# test/machines/nodes.sh and ern_machine take them from here. bin/ern
# writes its own, since an installation holds no tools/, and
# ern_tree:code_path/0 names the same directories, which ern_tree_tests
# holds.

set -euf

quoted=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
flags=
for directory in toolchain/*/ebin shared/ebin nodes/ebin runtime/ebin shell/ebin; do
    flags="$flags -pa '$quoted'/build/$directory"
done
printf '%s\n' "${flags# }"
