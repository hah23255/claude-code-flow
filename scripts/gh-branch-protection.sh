#!/bin/bash
# GitHub Branch Protection Configuration Script
set -euo pipefail

REPO="${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${1:-main}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
	case $1 in
	--repo)
		REPO="$2"
		shift 2
		;;
	--branch)
		BRANCH="$2"
		shift 2
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	*) shift ;;
	esac
done

echo "Branch Protection: $REPO/$BRANCH (Dry: $DRY_RUN)"

if [ "$DRY_RUN" = true ]; then
	echo "Would apply: PR reviews (1 approval), status checks, conversation resolution, no force push"
	exit 0
fi

gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - <<EOF
{
  "required_status_checks": {"strict": true, "contexts": []},
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo "✓ Branch protection applied"
