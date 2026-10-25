#!/bin/sh
# Every prose paragraph past about a hundred words in the tracked documents,
# a list item among them, for its writer to read again for a turn it may
# hide (CLAUDE.md, *Writing*): path, line, words and the paragraph's first
# words. A list, not a limit: a paragraph that holds one thing stays whole.
# A list item is a paragraph of its own, which ends at the next item, at a
# blank line or where its indentation ends. A heading, a table row or an
# HTML line is no prose, after an item as anywhere. The log, the proposals
# and the generated pages are left out.
cd "$(dirname "$0")/.." || exit 1
git ls-files -- '*.md' ':!docs/log.md' ':!docs/proposals/' ':!docs/man/' |
while read -r file; do
    awk -v file="$file" '
        function flush() {
            if (!skip && words > 100)
                printf "%s:%d: %d words  %s\n", file, start, words, substr(first, 1, 60)
            words = 0; item = 0
        }
        /^(```|~~~)/ { fence = !fence; flush(); next }
        fence { next }
        /^[ \t]*$/ { flush(); next }
        /^[ \t]*(-|\*|[0-9]+[a-z]?\.) / { flush(); item = 1 }
        {
            if (item && words > 0 && match($0, /[^ \t]/) - 1 <= indent)
                flush()
            if (words == 0) {
                start = NR; first = $0
                skip = ($0 ~ /^(#|\||<)/)
                indent = match($0, /[^ \t]/) - 1
            }
            words += NF
        }
        END { flush() }
    ' "$file"
done
