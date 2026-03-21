: "${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}"
: "${REPO_URL:?REPO_URL is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${COMMIT_MSG:?COMMIT_MSG is required}"

FILE_LIMIT=5

COMMIT_URL="$REPO_URL/commit/$COMMIT_SHA"
CHANGED_FILES=$(git diff --name-only ${COMMIT_SHA}~1 ${COMMIT_SHA} -- '*.json' 2>/dev/null || echo "")
TOTAL=$(echo "$CHANGED_FILES" | grep -c '.')

# remove new lines from commit msg
COMMIT_MSG="${COMMIT_MSG//$'\n'/}"

if [[ $COMMIT_MSG =~ Deadbot\ v([0-9.]+)\ \|\ Client\ ([0-9]+)\ \-\ ([A-Za-z]+\ [0-9]+\ [0-9]+)\ \(\deadbot@([0-9a-f]+)\) ]]; then
    DEADBOT_VERSION="${BASH_REMATCH[1]}"
    DEADLOCK_CLIENT="${BASH_REMATCH[2]}"
    DEADLOCK_DATE="${BASH_REMATCH[3]}"
    DEADBOT_COMMIT_SHA="${BASH_REMATCH[4]}"
fi

DATA_LIST=""
LOCALIZATION_LIST=""
CHANGELOG_LIST=""

DATA_COUNT=0
LOCALIZATION_COUNT=0
CHANGELOG_COUNT=0

TOTAL_ADDITIONS=0
TOTAL_DELETIONS=0

# For each file, add file name to the appropriate category and count the number of lines added and deleted
while IFS=$'\t' read -r additions deletions filename; do
    [ -z "$filename" ] && continue

    BASENAME=$(basename "$filename")
    LINE="${BASENAME}"$'\\n'
    case "$filename" in
        data/json/*)
            DATA_COUNT=$((DATA_COUNT + 1))
            [ "$DATA_COUNT" -le $FILE_LIMIT ] && DATA_LIST+="$LINE"
            ;;
        data/localizations/*)
            LOCALIZATION_COUNT=$((LOCALIZATION_COUNT + 1))
            [ "$LOCALIZATION_COUNT" -le $FILE_LIMIT ] && LOCALIZATION_LIST+="$LINE"
            ;;
        data/changelogs/wiki/*)
            CHANGELOG_COUNT=$((CHANGELOG_COUNT + 1))
            [ "$CHANGELOG_COUNT" -le $FILE_LIMIT ] && CHANGELOG_LIST+="$LINE"
            ;;
    esac

    TOTAL_ADDITIONS=$((TOTAL_ADDITIONS + additions))
    TOTAL_DELETIONS=$((TOTAL_DELETIONS + deletions))
done < <(git diff --numstat ${COMMIT_SHA}~1 ${COMMIT_SHA} 2>/dev/null)

# Show "...and xxx more" if file list exceeds row limit
[ "$DATA_COUNT" -gt $FILE_LIMIT ] && \
DATA_LIST+="+ [...and $((DATA_COUNT - $FILE_LIMIT)) more]($COMMIT_URL)\\n"

[ "$LOCALIZATION_COUNT" -gt $FILE_LIMIT ] && \
LOCALIZATION_LIST+="+ [...and $((LOCALIZATION_COUNT - $FILE_LIMIT)) more]($COMMIT_URL)\\n"

[ "$CHANGELOG_COUNT" -gt $FILE_LIMIT ] && \
CHANGELOG_LIST+="+ [...and $((CHANGELOG_COUNT - $FILE_LIMIT)) more]($COMMIT_URL)\\n"

TOTAL_FILES=$(($DATA_COUNT + $LOCALIZATION_COUNT + $CHANGELOG_COUNT))
if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "No files changed, skipping notification"
    exit 0
fi

PAYLOAD=$(cat <<EOF
{
    "embeds": [
        {
        "author": {
            "name": "Deadlock Wiki Update",
            "url": "$COMMIT_URL",
            "icon_url": "https://deadlock.wiki/resources/assets/logos/logo_icon.png"
        },
        "title": "$COMMIT_MSG",
        "description": "New data available on [deadlock.wiki](https://deadlock.wiki) (uploaded by [deadbot](https://github.com/deadlock-wiki/deadbot/tree/$DEADBOT_COMMIT_SHA))",
        "color": 5815783,
        "fields": [
            {
                "name": "Summary",
                "value": "Files changed: $TOTAL_FILES\\n+$TOTAL_ADDITIONS / -$TOTAL_DELETIONS lines",
                "inline": false
            },
            {
                "name": "Data",
                "value": "${DATA_LIST:-No changes}",
                "inline": true
            },
            {
                "name": "Localizations",
                "value": "${LOCALIZATION_LIST:-No changes}",
                "inline": true
            },
            {
                "name": "Changelogs",
                "value": "${CHANGELOG_LIST:-No changes}",
                "inline": true
            }
        ],
        "url": "$COMMIT_URL",
        "footer": {
            "text": "Deadbot v$DEADBOT_VERSION • Client $DEADLOCK_CLIENT ($DEADLOCK_DATE)"
        },
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
]
}
EOF
)

echo $PAYLOAD
curl -v -X POST \
-H "Content-Type: application/json" \
-d "$PAYLOAD" \
--fail \
"$DISCORD_WEBHOOK_URL"
