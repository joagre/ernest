#!/bin/sh
# Every prose paragraph past about a hundred words in the tracked documents,
# for its writer to read again for a turn it may hide (CLAUDE.md, *Writing*):
# path, line, words and the paragraph's first words. A list, not a limit:
# a paragraph that holds one thing stays whole. The log, the proposals and
# the generated pages are left out.
cd "$(dirname "$0")/.." || exit 1
git ls-files -- '*.md' ':!docs/decisions.md' ':!docs/proposals/' ':!docs/man/' |
while read -r file; do
    awk -v file="$file" '
        function flush() {
            if (!skip && words > 100)
                printf "%s:%d: %d words  %s\n", file, start, words, substr(first, 1, 60)
            words = 0
        }
        /^(```|~~~)/ { fence = !fence; flush(); next }
        fence { next }
        /^[ \t]*$/ { flush(); next }
        {
            if (words == 0) {
                start = NR; first = $0
                skip = ($0 ~ /^(#|\||<|- |[0-9]+\. )/)
            }
            words += NF
        }
        END { flush() }
    ' "$file"
done
