#!/bin/bash
# GitHub Fork Cleanup Script
# Analyzes and archives inactive forks (0 stars, 6+ months no activity)
set -euo pipefail

MODE="analyze"
DRY_RUN=true
MONTHS=6
OUTPUT_DIR="./fork-cleanup-reports"

# Parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--analyze)
		MODE="analyze"
		shift
		;;
	--archive)
		MODE="archive"
		DRY_RUN=false
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--months)
		MONTHS="$2"
		shift 2
		;;
	*) shift ;;
	esac
done

mkdir -p "$OUTPUT_DIR"

analyze_forks() {
	echo "📊 Fetching fork list..."
	USER=$(gh api user -q .login)
	TEMP="$OUTPUT_DIR/all-forks-$(date +%Y%m%d-%H%M%S).json"

	gh repo list "$USER" --fork --limit 1000 --json name,pushedAt,stargazerCount,url,diskUsage >"$TEMP"

	TOTAL=$(jq length "$TEMP")
	echo "Total forks: $TOTAL"

	# Calculate cutoff date (6 months ago)
	CUTOFF=$(date -d "$MONTHS months ago" +%Y-%m-%d 2>/dev/null || date -v-${MONTHS}m +%Y-%m-%d)

	# Filter: 0 stars AND last push older than cutoff
	jq --arg cutoff "$CUTOFF" '[.[] | select(.stargazerCount == 0 and .pushedAt < $cutoff)]' "$TEMP" >"$OUTPUT_DIR/archive-candidates.json"

	ARCHIVE=$(jq length "$OUTPUT_DIR/archive-candidates.json")

	echo "✅ Analysis complete!"
	echo "Archive candidates: $ARCHIVE"
	echo "Report saved: $OUTPUT_DIR/archive-candidates.json"
}

archive_forks() {
	if [ ! -f "$OUTPUT_DIR/archive-candidates.json" ]; then
		echo "❌ Error: Run --analyze first"
		exit 1
	fi

	COUNT=$(jq length "$OUTPUT_DIR/archive-candidates.json")
	echo "📦 Found $COUNT forks to archive"

	if [ "$DRY_RUN" = true ]; then
		echo "🔍 Dry-run mode (would archive):"
		jq -r '.[] | "  - \(.name)"' "$OUTPUT_DIR/archive-candidates.json" | head -20
		exit 0
	fi

	echo "⚠️  Archive $COUNT repos? (yes/N)"
	read -r CONFIRM

	if [ "$CONFIRM" != "yes" ]; then
		echo "❌ Cancelled"
		exit 0
	fi

	USER=$(gh api user -q .login)
	jq -r '.[] | .name' "$OUTPUT_DIR/archive-candidates.json" | while read -r REPO; do
		echo "📦 Archiving: $REPO"
		gh api -X PATCH "repos/$USER/$REPO" -f archived=true >/dev/null 2>&1 || echo "  ❌ Failed: $REPO"
	done

	echo "✅ Archival complete"
}

case $MODE in
analyze) analyze_forks ;;
archive) archive_forks ;;
esac
