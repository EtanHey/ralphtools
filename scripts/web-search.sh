#!/bin/bash
#
# Web Search - Search for AI agents to use
# Uses ddgr (DuckDuckGo CLI) or falls back to lite.duckduckgo.com scraping
#
# Usage: ./scripts/web-search.sh "your search query"
#
# Install ddgr for best results: brew install ddgr
#

QUERY="$*"

if [[ -z "$QUERY" ]]; then
    echo "Usage: ./scripts/web-search.sh \"your search query\""
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  Web Search: $QUERY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Try ddgr first (best option)
if command -v ddgr &>/dev/null; then
    ddgr --np -n 5 "$QUERY" 2>/dev/null
    exit 0
fi

# Fallback: Use DuckDuckGo lite HTML and parse it
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

# Fetch and parse lite.duckduckgo.com (simpler HTML)
RESULTS=$(curl -s "https://lite.duckduckgo.com/lite/?q=${ENCODED}" \
    -H "User-Agent: Mozilla/5.0" \
    | python3 -c "
import sys
import re
from html.parser import HTMLParser

html = sys.stdin.read()

# Extract result links and snippets
links = re.findall(r'<a[^>]*class=\"result-link\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>', html)
snippets = re.findall(r'<td[^>]*class=\"result-snippet\"[^>]*>([^<]+)', html)

for i, (url, title) in enumerate(links[:5]):
    print(f'{i+1}. {title.strip()}')
    print(f'   {url}')
    if i < len(snippets):
        print(f'   {snippets[i].strip()[:200]}')
    print()
" 2>/dev/null)

if [[ -n "$RESULTS" ]]; then
    echo "$RESULTS"
else
    echo "Search returned no results."
    echo ""
    echo "For better results, install ddgr:"
    echo "  brew install ddgr"
    echo ""
    echo "Or open in browser:"
    echo "  open \"https://duckduckgo.com/?q=${ENCODED}\""
fi

echo "═══════════════════════════════════════════════════════════════"
