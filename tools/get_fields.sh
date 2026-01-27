#!/bin/zsh
set -euo pipefail

if [ -z "$CONFLUENCE_EMAIL" ] || [ -z "$CONFLUENCE_TOKEN" ]; then
  echo ">>> CONFLUENCE_EMAIL and CONFLUENCE_TOKEN must be set ❌"
  exit 1
fi

JIRA_BASE_URL="https://<myorg>.atlassian.net"
PROJECT_NAME="" # such as KAN, AWS, ITHELP, etc.

if [ "$JIRA_BASE_URL" = "https://<myorg>.atlassian.net" ]; then
  echo ">>> Edit this file and set the JIRA_BASE_URL ❌"
  exit 1
fi


if [ -z "$PROJECT_NAME" ]; then
  echo ">>> Edit this file and set the PROJECT_NAME (key of the project) ❌"
  exit 1
fi

### Get project ID

PROJECT_ID=$(curl -sH "Content-Type: application/json" \
 -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
 "$JIRA_BASE_URL/rest/api/3/project/$PROJECT_NAME" | jq -r .id)

echo ">>> Project ID: $PROJECT_ID"

### Gets all issue types for the project

curl -sH "Content-Type: application/json" \
 -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
 "$JIRA_BASE_URL/rest/api/3/project/$PROJECT_NAME" \
 | jq '.issueTypes[] | [.id, .name, .description]'

### Same as above

curl -sH "Content-Type: application/json" \
  -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/issue/createmeta/${PROJECT_ID}/issuetypes/" \
  | jq '.issueTypes[]'
  

# DB access ticket type from the command above!
WORK_TYPE_ID=10008

curl -sH "Content-Type: application/json" \
  -u "$CONFLUENCE_EMAIL:$CONFLUENCE_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/issue/createmeta/${PROJECT_ID}/issuetypes/${WORK_TYPE_ID}" \
  | jq '.fields'

