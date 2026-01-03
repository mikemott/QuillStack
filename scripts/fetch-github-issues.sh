#!/bin/bash
# Fetch GitHub issues and save to a file that Claude can read

# Set your repo details
REPO_OWNER="your-username"
REPO_NAME="QuillStack"
GITHUB_TOKEN="your-token"  # Create at https://github.com/settings/tokens

# Fetch open issues
curl -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/issues?state=open" \
     > github-issues.json

# Also create a readable markdown file
echo "# GitHub Issues for $REPO_OWNER/$REPO_NAME" > github-issues.md
echo "" >> github-issues.md
jq -r '.[] | "## #\(.number) - \(.title)\n\n\(.body)\n\n**Labels:** \(.labels | map(.name) | join(", "))\n**Assignee:** \(.assignee.login // "Unassigned")\n\n---\n"' github-issues.json >> github-issues.md

echo "Issues saved to github-issues.json and github-issues.md"


