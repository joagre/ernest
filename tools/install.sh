#!/bin/sh
# The installation (docs/install.md), which make install and make uninstall
# run: `install.sh install DESTDIR PREFIX` and `install.sh uninstall
# DESTDIR PREFIX`. Every path is under DESTDIR followed by PREFIX. The
# toolchain's tree goes to lib/ernest, as the repository lays it out, and
# bin/ern is a relative link to its launcher; the manual pages, the
# documents and the Emacs mode go under share. The tree's `installed`
# lists every file put outside it, a directory with a slash after it, so
# that uninstall removes exactly those. Nothing is changed where a
# directory to be written cannot be.

set -eu

job=$1
root=$2$3
tree=$root/lib/ernest
repo=$(cd "$(dirname "$0")/.." && pwd -P)

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

# A file of the repository copied into the tree, its directories made.
into_tree() {
    mkdir -p "$(dirname "$tree/$1")"
    cp "$repo/$1" "$tree/$1"
}

# A file copied to a place outside the tree, and listed.
outside() {
    mkdir -p "$(dirname "$root/$2")"
    cp "$1" "$root/$2"
    echo "$2" >> "$tree/installed"
}

install() {
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
    cd "$repo"
    into_tree bin/ern
    for f in erl/*/ebin/*.beam; do
        case $f in
            *_tests.beam) ;;
            *) into_tree "$f" ;;
        esac
    done
    into_tree erl/runtime/priv/ern_exec
    for f in stdlib/*.ern build/stdlib/*.erc build/stdlib/ern@*.beam; do
        into_tree "$f"
    done
    find build/shell build/libs -type f \( -name '*.erc' -o -name '*.beam' \) | sort |
        while read -r f; do
            into_tree "$f"
        done
    chmod -R u=rwX,go=rX "$tree"
    : > "$tree/installed"
    mkdir -p "$root/bin"
    ln -s ../lib/ernest/bin/ern "$root/bin/ern"
    echo bin/ern >> "$tree/installed"
    outside build/man/ern.1 share/man/man1/ern.1
    for f in build/stdlib/*.3ern build/libs/*/*.3ern; do
        outside "$f" "share/man/man3/$(basename "$f")"
    done
    for f in ernest_report.md ernest_guide.md README.md LICENSE THIRD_PARTY_LICENSES; do
        outside "$f" "share/doc/ernest/$f"
    done
    echo share/doc/ernest/ >> "$tree/installed"
    outside emacs/ernest-mode.el share/emacs/site-lisp/ernest-mode.el
    while read -r f; do
        case $f in
            */) chmod u=rwx,go=rx "$root/$f" ;;
            bin/ern) ;;
            *) chmod u=rw,go=r "$root/$f" ;;
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

case $job in
    install) install ;;
    uninstall) uninstall ;;
    *) fail "no job $job" ;;
esac
