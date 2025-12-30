#!/bin/bash
# GitHub Notification Cleanup Script
set -euo pipefail

MODE="analyze"
REASON=""

while [[ $# -gt 0 ]]; do
	case $1 in
	--analyze)
		MODE="analyze"
		shift
		;;
	--cleanup)
		MODE="cleanup"
		shift
		;;
	--reason)
		REASON="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

analyze() {
	echo "Fetching notifications..."
	TEMP=$(mktemp)
	gh api notifications --paginate >"$TEMP"

	TOTAL=$(jq length "$TEMP")
	echo "Total: $TOTAL"

	echo -e "\nBy reason:"
	jq -r 'group_by(.reason) | map({reason: .[0].reason, count: length}) | sort_by(-.count) | .[] | "\(.reason): \(.count)"' "$TEMP"

	echo -e "\nTop 10 repos:"
	jq -r '[.[].repository.full_name] | group_by(.) | map({repo: .[0], count: length}) | sort_by(-.count) | .[:10] | .[] | "\(.repo): \(.count)"' "$TEMP"

	rm "$TEMP"
}

cleanup() {
	if [ -z "$REASON" ]; then
		echo "Error: --reason required"
		exit 1
	fi

	echo "Fetching $REASON notifications..."
	TEMP=$(mktemp)
	gh api notifications --paginate | jq "[.[] | select(.reason == \"$REASON\")]" >"$TEMP"

	COUNT=$(jq length "$TEMP")
	echo "Found $COUNT notifications"

	if [ "$COUNT" -eq 0 ]; then
		rm "$TEMP"
		exit 0
	fi

	echo "Mark as read? (y/N)"
	read -r CONFIRM

	if [ "$CONFIRM" != "y" ]; then
		echo "Cancelled"
		rm "$TEMP"
		exit 0
	fi

	jq -r '.[].id' "$TEMP" | while read -r ID; do
		gh api -X PATCH "notifications/threads/$ID" >/dev/null 2>&1
	done

	echo "✓ Marked $COUNT as read"
	rm "$TEMP"
}

case $MODE in
analyze) analyze ;;
cleanup) cleanup ;;
esac
