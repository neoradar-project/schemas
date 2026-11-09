#!/bin/sh
# PostToolUse on Edit|Write: flags the root CLAUDE.md writing rules in the lines added since HEAD, exit 2.
# --allow-xmldoc: /// lines do not count toward the comment-block limit (public plugin surface).

allow_xmldoc=0
[ "$1" = "--allow-xmldoc" ] && allow_xmldoc=1

input=$(cat)
file=$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//; s/\\\\/\//g')
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
    *.g.cs|*.Designer.cs|*.min.js|*.lock|*-lock.json|*.sum|*.svg|*.png|*.jpg|*.ico|*.dll|*.exe|*.zip) exit 0 ;;
esac

dir=$(dirname "$file")
base=$(basename "$file")
added=""
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && git -C "$dir" ls-files --error-unmatch -- "$base" >/dev/null 2>&1; then
    added=$(git -C "$dir" diff --no-color --no-ext-diff -U0 HEAD -- "$base" \
        | grep -v '^+++' | grep -E '^(\+|@@)' | sed 's/^+//; s/^@@.*/@@/')
else
    added=$(cat "$file")
fi
[ -n "$added" ] || exit 0

case "$file" in
    *.cs|*.go|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.css|*.scss|*.java|*.kt|*.swift|*.c|*.h|*.cpp|*.hpp|*.glsl|*.hlsl|*.metal)
        lang=slash ;;
    *.sh|*.ps1|*.py|*.yml|*.yaml|*.toml|*.rb|*.props|*.targets) lang=hash ;;
    *) lang=none ;;
esac

report=""
note() { report="${report}${1}
"; }

emdash=$(printf '\342\200\224')
printf '%s\n' "$added" | grep "$emdash" | head -n 5 | while IFS= read -r l; do
    printf 'em dash: %s\n' "$(printf '%s' "$l" | cut -c1-140)"
done > "${TMPDIR:-/tmp}/style-check.$$"
[ -s "${TMPDIR:-/tmp}/style-check.$$" ] && note "$(cat "${TMPDIR:-/tmp}/style-check.$$")"

case "$file" in
    *.cs)
        hits=$(printf '%s\n' "$added" | grep -v '^[[:space:]]*//' \
            | grep -E '(^|[^A-Za-z0-9_.])var[[:space:]]+[A-Za-z_(]' | head -n 5 | cut -c1-140)
        [ -n "$hits" ] && note "var (use the explicit type):
$hits" ;;
esac

if [ "$lang" != none ]; then
    if [ "$lang" = slash ]; then
        comments=$(printf '%s\n' "$added" | awk -v xml="$allow_xmldoc" '
            /^@@$/ { run = 0; next }
            {
                line = $0; sub(/^[ \t]+/, "", line)
                isxml = (substr(line, 1, 3) == "///")
                isc = (substr(line, 1, 2) == "//" || substr(line, 1, 2) == "/*" || substr(line, 1, 1) == "*")
                if (isc && !(isxml && xml == 1)) { run++; if (run == 3) print "comment block over two lines near: " line }
                else run = 0
            }')
        text=$(printf '%s\n' "$added" | grep -E '(^[[:space:]]*(//|/\*|\*)|[^:]//)' | sed 's|^.*//||')
    else
        comments=$(printf '%s\n' "$added" | awk '
            /^@@$/ { run = 0; next }
            {
                line = $0; sub(/^[ \t]+/, "", line)
                if (substr(line, 1, 1) == "#" && substr(line, 1, 2) != "#!") { run++; if (run == 3) print "comment block over two lines near: " line }
                else run = 0
            }')
        text=$(printf '%s\n' "$added" | grep -E '^[[:space:]]*#' | grep -v '^#!')
    fi
    [ -n "$comments" ] && note "$(printf '%s' "$comments" | head -n 5 | cut -c1-160)"

    ids=$(printf '%s\n' "$text" \
        | grep -oE '(^|[^A-Za-z0-9_])(P[0-9]{1,2}|Wave [0-9]+|[A-Z][0-9]*-D[0-9]+|B[0-9]{2,3}|G-[A-Z]+-[0-9]+)([^A-Za-z0-9_]|$)' \
        | sed 's/^[^A-Za-z]*//; s/[^A-Za-z0-9]*$//' | grep -vE '^B7[0-9]{2}$' | sort -u | tr '\n' ' ')
    [ -n "$ids" ] && note "comment cites a plan id: $ids(say what the code does; name a test or method instead)"
fi

rm -f "${TMPDIR:-/tmp}/style-check.$$"
[ -n "$report" ] || exit 0
printf 'Writing rules (root CLAUDE.md, Writing rules) in %s:\n%s' "$file" "$report" >&2
exit 2
