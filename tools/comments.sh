#!/bin/sh
# Every comment block past about a hundred words in the Erlang and the
# Ernest, for its writer to read again for a turn it may hide
# (docs/style.md, *Every language*): path, line and words. A block is a
# run of comment lines, `%%` or `//`, a doc block's `///` among them, which
# a blank comment line or a line of code ends, and a list item, `- ` or
# `1. ` after the marker, begins one of its own, as a document's does; a
# comment beside code is a block of its own. Given a number, the blocks past that many words
# instead: `150` is the ceiling a test holds every block to, the one a
# document's paragraph has. The vendored getopt is left out.
cd "$(dirname "$0")/.." || exit 1
ceiling=${1:-100}
git ls-files -- 'erl/*.erl' 'test/*.erl' 'test/fixtures/*.erl' 'src/*.ern' 'examples/*.ern' \
    'tools/*.ern' 'tour/*.ern' 'test/fixtures/*.ern' | grep -v '/getopt\.erl$' |
while read -r file; do
    awk -v file="$file" -v ceiling="$ceiling" '
        function flush() {
            if (words > ceiling) printf "%s:%d: %d words\n", file, start, words
            words = 0
        }
        /^[ \t]*(%%|\/\/)/ {
            line = $0; sub(/^[ \t]*(%%+|\/\/+)[ \t]?/, "", line)
            n = split(line, w, /[ \t]+/); c = 0
            for (i = 1; i <= n; i++) if (w[i] != "") c++
            if (c == 0) { flush(); next }
            if (line ~ /^(-|\*|[0-9]+\.) /) flush()
            if (words == 0) start = NR
            words += c; next
        }
        { flush() }
        END { flush() }
    ' "$file"
done
