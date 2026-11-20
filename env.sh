#!/usr/bin/env bash
# ==============================================================================
# Floci GCP — Session Environment Setup for Bash / Zsh
# Run in your shell: source env.sh
# ==============================================================================

FLOCI_HOST="http://localhost:4588/"
PROJECT="floci-local"

echo "Configuring gcloud CLI and GCP SDKs for Floci local emulator..."

# Core GCP Settings
export CLOUDSDK_CORE_PROJECT="$PROJECT"
export CLOUDSDK_AUTH_ACCESS_TOKEN="floci"
export GOOGLE_CLOUD_PROJECT="$PROJECT"

# gcloud CLI API Endpoint Overrides (all services on port 4588)
export CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDRESOURCEMANAGER="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SERVICEUSAGE="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_IAM="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDFUNCTIONS="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_RUN="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDTASKS="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_FIRESTORE="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_DATASTORE="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_BIGQUERY="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDKMS="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_LOGGING="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_MONITORING="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CLOUDSCHEDULER="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_EVENTARC="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SQLADMIN="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_COMPUTE="$FLOCI_HOST"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_CONTAINER="$FLOCI_HOST"

# Official Google Cloud Client SDK Emulator Hosts (Python, Node.js, Go, Java)
export STORAGE_EMULATOR_HOST="http://localhost:4588"
export PUBSUB_EMULATOR_HOST="localhost:4588"
export FIRESTORE_EMULATOR_HOST="localhost:4588"
export DATASTORE_EMULATOR_HOST="localhost:4588"
export SECRET_MANAGER_EMULATOR_HOST="localhost:4588"
export CLOUD_TASKS_EMULATOR_HOST="localhost:4588"
export BIGQUERY_EMULATOR_HOST="http://localhost:4588"
export FIREBASE_AUTH_EMULATOR_HOST="localhost:4588"

# Git Bash on Windows Performance Optimizations
export MSYS_NO_PATHCONV=1
export CLOUDSDK_CORE_CHECK_GCE_METADATA="false"
if command -v gcloud.cmd >/dev/null 2>&1; then
  alias gcloud="gcloud.cmd"
fi

# Helper: Refresh IAM ETag if Floci gets stuck on a + or / character
fix-iam-etag() {
  local p="${1:-${PROJECT_ID:-floci-local}}"
  local pol
  pol=$(curl -s -X POST "http://localhost:4588/v1/projects/$p:getIamPolicy" -H "Content-Type: application/json" -d "{}")
  curl -s -X POST "http://localhost:4588/v1/projects/$p:setIamPolicy" -H "Content-Type: application/json" -d "{\"policy\": $pol}" > /dev/null
  echo "✅ IAM ETag refreshed for project: $p"
}

echo "✅ Environment configured! All gcloud CLI calls and SDKs will route to $FLOCI_HOST"
