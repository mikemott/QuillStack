#!/bin/bash
# Fetch Linear issues using their GraphQL API

# Set your Linear API key (create at https://linear.app/settings/api)
LINEAR_API_KEY="your-api-key"
LINEAR_TEAM_ID="your-team-id"  # Find in Linear team settings

# GraphQL query to fetch issues
QUERY='{
  "query": "query { team(id: \"'$LINEAR_TEAM_ID'\") { issues(first: 50) { nodes { id title description state { name } assignee { name } labels { nodes { name } } } } } }"
}'

# Fetch issues
curl -X POST https://api.linear.app/graphql \
     -H "Authorization: $LINEAR_API_KEY" \
     -H "Content-Type: application/json" \
     -d "$QUERY" \
     > linear-issues.json

# Create readable markdown
echo "# Linear Issues" > linear-issues.md
echo "" >> linear-issues.md
jq -r '.data.team.issues.nodes[] | "## \(.title)\n\n\(.description // "No description")\n\n**State:** \(.state.name)\n**Assignee:** \(.assignee.name // "Unassigned")\n**Labels:** \(.labels.nodes | map(.name) | join(", ") // "None")\n\n---\n"' linear-issues.json >> linear-issues.md

echo "Linear issues saved to linear-issues.json and linear-issues.md"


