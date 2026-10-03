#!/bin/sh
# The installation (docs/install.md). Its jobs:
#
#   install.sh stage DIR                    the installation's tree from the checkout
#   install.sh install DIR DESTDIR PREFIX   a staged tree installed
#   install.sh uninstall DESTDIR PREFIX     an installation removed
#   install.sh release DIR VERSION          the release archive, DIR/ern-VERSION.tar.gz
#
# A staged tree is laid out as under the prefix: the toolchain's tree in
# lib/ernest, as the repository lays it out and without the host's debug
# information, bin/ern a relative link to its launcher, and the manual
# pages, the documents and the Emacs mode under share. The README staged
# is the release's, tools/release/README.md, and a document's link into the
# checkout, to a file that is not installed, is staged as a link into the
# repository at $ref: main from a checkout, the release's tag in an archive.
# The tree's `installed` lists every file outside it, a directory with a
# slash after it, so that uninstall removes exactly those. make install stages the
# checkout and installs what it staged; the release archive is a staged
# tree whose helper is compiled where it is installed. Nothing is changed
# where a directory to be written cannot be.

set -eu

job=$1
repo=$(cd "$(dirname "$0")/.." && pwd -P)
repository=https://github.com/joagre/ernest

fail() {
    echo "make $job: $*" >&2
    exit 1
}

# A directory can be written into where it can be written, or where the
# nearest directory above it that exists can, so that it can be made.
writable() {
    d=$1
    while [ ! -e "$d" ]; do
        d=$(dirname "$d")
    done
    [ -d "$d" ] && [ -w "$d" ] || fail "$d cannot be written; run make $job as a user" \
        "who can write there, or give another PREFIX"
}

# The installation's tree from the checkout, in $1.
stage() {
    stage=$1
    rm -rf "$stage"
    tree=$stage/lib/ernest
    cd "$repo"
    for f in bin/ern erl/*/ebin/*.beam erl/runtime/priv/ern_exec stdlib/*.ern \
             build/stdlib/*.erc build/stdlib/ern@*.beam \
             $(find build/shell build/libs -type f \( -name '*.erc' -o -name '*.beam' \) | sort)
    do
        case $f in
            *_tests.beam) ;;
            *) mkdir -p "$(dirname "$tree/$f")" && cp "$f" "$tree/$f" ;;
        esac
    done
    escript tools/strip.escript "$tree"
    mkdir -p "$stage/bin"
    ln -s ../lib/ernest/bin/ern "$stage/bin/ern"
    echo bin/ern > "$tree/installed"
    shared build/man/ern.1 share/man/man1/ern.1
    for f in build/stdlib/*.3ern build/libs/*/*.3ern; do
        shared "$f" "share/man/man3/$(basename "$f")"
    done
    for f in LICENSE THIRD_PARTY_LICENSES; do
        shared "$f" "share/doc/ernest/$f"
    done
    for f in ernest_report.md ernest_guide.md; do
        edited "$f" "share/doc/ernest/$f" "s|](\\([a-z_]*\\)/|]($repository/blob/$ref/\\1/|g"
    done
    edited tools/release/README.md share/doc/ernest/README.md "s/@VERSION@/$(cat VERSION)/g"
    echo share/doc/ernest/ >> "$tree/installed"
    shared emacs/ernest-mode.el share/emacs/site-lisp/ernest-mode.el
    chmod -R u=rwX,go=rX "$stage"
}

# A file of the checkout staged outside the tree, and listed.
shared() {
    mkdir -p "$(dirname "$stage/$2")"
    cp "$1" "$stage/$2"
    echo "$2" >> "$tree/installed"
}

# A document of the checkout staged outside the tree as sed's $3 edits
# it, and listed.
edited() {
    mkdir -p "$(dirname "$stage/$2")"
    sed "$3" "$1" > "$stage/$2"
    echo "$2" >> "$tree/installed"
}

# A staged tree in $1 installed under root, the files it lists outside
# its tree copied, and any installation already there removed first.
install() {
    from=$1
    [ -x "$from/lib/ernest/erl/runtime/priv/ern_exec" ] ||
        fail "$from holds no helper; make builds it"
    for d in "$tree" "$root/bin" "$root/share/man/man1" "$root/share/man/man3" \
             "$root/share/doc" "$root/share/emacs/site-lisp"; do
        writable "$d"
    done
    if [ -f "$tree/installed" ]; then
        uninstall
    elif [ -e "$tree" ]; then
        fail "$tree is there already and is no installation of Ernest"
    fi
    if [ -e "$root/bin/ern" ] || [ -L "$root/bin/ern" ]; then
        fail "$root/bin/ern is there already and is not Ernest's"
    fi
    mkdir -p "$root/lib"
    cp -R "$from/lib/ernest" "$tree"
    chmod -R u=rwX,go=rX "$tree"
    while read -r f; do
        case $f in
            */) ;;
            bin/ern) mkdir -p "$root/bin" && ln -s ../lib/ernest/bin/ern "$root/bin/ern" ;;
            *) mkdir -p "$(dirname "$root/$f")" && cp "$from/$f" "$root/$f" &&
                   chmod u=rw,go=r "$root/$f" ;;
        esac
    done < "$tree/installed"
}

# The files the tree lists, then the directories it lists where they are
# empty, then the tree.
uninstall() {
    [ -f "$tree/installed" ] || fail "no installation of Ernest in $root"
    writable "$root/lib"
    while read -r f; do
        writable "$(dirname "$root/${f%/}")"
    done < "$tree/installed"
    while read -r f; do
        case $f in
            */) ;;
            *) rm -f "$root/$f" ;;
        esac
    done < "$tree/installed"
    while read -r f; do
        case $f in
            */) rmdir "$root/$f" 2>/dev/null || true ;;
        esac
    done < "$tree/installed"
    rm -rf "$tree"
}

# The release archive: a staged tree without the helper, whose C source
# it carries instead with the Makefile of tools/release, the README it
# installs, and this script, packed as ern-VERSION.
release() {
    dir=$1
    version=$2
    name=ern-$version
    ref=v$version
    stage "$dir/$name"
    rm "$dir/$name/lib/ernest/erl/runtime/priv/ern_exec"
    cd "$repo"
    cp erl/runtime/c_src/ern_exec.c tools/install.sh "$dir/$name/"
    cp "$dir/$name/share/doc/ernest/README.md" "$dir/$name/README.md"
    sed "s/@VERSION@/$version/g" tools/release/Makefile > "$dir/$name/Makefile"
    chmod -R u=rwX,go=rX "$dir/$name"
    rm -f "$dir/$name.tar.gz"
    (cd "$dir" && tar -czf "$name.tar.gz" "$name")
}

case $job in
    stage) ref=main && stage "$2" ;;
    install) root=$3$4 && tree=$root/lib/ernest && install "$2" ;;
    uninstall) root=$2$3 && tree=$root/lib/ernest && uninstall ;;
    release) release "$2" "$3" ;;
    *) fail "no job $job" ;;
esac
