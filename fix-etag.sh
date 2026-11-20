#!/usr/bin/env bash
PROJECT_ID="${1:-iam-demo-1}"
P=$(curl -s -X POST "http://localhost:4588/v1/projects/$PROJECT_ID:getIamPolicy" -H "Content-Type: application/json" -d "{}")
echo "Fetched policy with etag: $(echo "$P" | grep -o '"etag":"[^"]*' | cut -d'"' -f4)"
RESP=$(curl -s -X POST "http://localhost:4588/v1/projects/$PROJECT_ID:setIamPolicy" -H "Content-Type: application/json" -d "{\"policy\": $P}")
echo "New etag generated: $(echo "$RESP" | grep -o '"etag":"[^"]*' | cut -d'"' -f4)"
