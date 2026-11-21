#!/usr/bin/env bash
# ==============================================================================
# Setup Script for Order & Payment Processing Pipeline
# Run from gcp/projects/order-payment-pipeline/ or root with: ./setup.sh
# ==============================================================================

set -e

# Load Floci environment if not loaded
if [ -f "../../env.sh" ]; then
  source "../../env.sh"
elif [ -f "../env.sh" ]; then
  source "../env.sh"
fi

# Ensure gcloud calls the native Windows cmd wrapper to bypass MSYS2 Python path mangling
GCLOUD="gcloud.cmd"
if ! command -v gcloud.cmd >/dev/null 2>&1; then
  GCLOUD="gcloud"
fi

export PROJECT_ID="${PROJECT_ID:-order-platform-prod}"
export TOPIC_NAME="orders-topic"
export SUB_PAYMENTS="orders-payment-sub"
export SUB_AUDIT="orders-audit-sub"
export BUCKET_NAME="gs://${PROJECT_ID}-receipts-archive"
export SECRET_NAME="payment-gateway-api-key"

echo "=========================================================="
echo "🚀 Provisioning GCP Resources for Project: $PROJECT_ID"
echo "=========================================================="

# 1. Create Project
echo "1. Creating project: $PROJECT_ID..."
$GCLOUD projects create "$PROJECT_ID" 2>/dev/null || echo "Project $PROJECT_ID ready"

# 2. Create Cloud Pub/Sub Topic and Subscriptions (Fan-out pattern)
echo "2. Setting up Cloud Pub/Sub Topic & Subscriptions..."
$GCLOUD pubsub topics create "$TOPIC_NAME" --project="$PROJECT_ID" 2>/dev/null || echo "Topic ready"

$GCLOUD pubsub subscriptions create "$SUB_PAYMENTS" \
  --project="$PROJECT_ID" \
  --topic="$TOPIC_NAME" 2>/dev/null || echo "Subscription $SUB_PAYMENTS ready"

$GCLOUD pubsub subscriptions create "$SUB_AUDIT" \
  --project="$PROJECT_ID" \
  --topic="$TOPIC_NAME" 2>/dev/null || echo "Subscription $SUB_AUDIT ready"

# 3. Create Cloud Storage Bucket
echo "3. Creating Cloud Storage Archive Bucket: $BUCKET_NAME..."
$GCLOUD storage buckets create "$BUCKET_NAME" \
  --project="$PROJECT_ID" \
  --location="us-central1" \
  --uniform-bucket-level-access 2>/dev/null || echo "Bucket ready"

# 4. Create Secret in Secret Manager
echo "4. Storing Payment Gateway credentials in Secret Manager..."
$GCLOUD secrets create "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --replication-policy="automatic" 2>/dev/null || echo "Secret ready"

printf "sk_live_gcp_mock_key_998877665544" | $GCLOUD secrets versions add "$SECRET_NAME" \
  --project="$PROJECT_ID" \
  --data-file=- 2>/dev/null || echo "Secret version ready"

# 5. Create Service Accounts
echo "5. Creating Dedicated Service Accounts..."
$GCLOUD iam service-accounts create payment-worker \
  --project="$PROJECT_ID" \
  --display-name="Payment Processing Worker SA" 2>/dev/null || echo "SA payment-worker ready"

$GCLOUD iam service-accounts create audit-archiver \
  --project="$PROJECT_ID" \
  --display-name="Audit & Compliance Archiver SA" 2>/dev/null || echo "SA audit-archiver ready"

# 6. Apply Principle of Least Privilege via IAM Bindings
echo "6. Applying IAM Role Bindings..."

# Helper to safely apply policy binding with ETag auto-refresh on Floci
safe_add_binding() {
  local member="$1"
  local role="$2"
  for attempt in 1 2 3; do
    if $GCLOUD projects add-iam-policy-binding "$PROJECT_ID" --member="$member" --role="$role" >/dev/null 2>&1; then
      return 0
    fi
    # If hit with Floci +/- ETag mismatch, refresh via raw REST get+set
    local pol
    pol=$(curl -s -X POST "http://localhost:4588/v1/projects/${PROJECT_ID}:getIamPolicy" -H "Content-Type: application/json" -d "{}")
    curl -s -X POST "http://localhost:4588/v1/projects/${PROJECT_ID}:setIamPolicy" -H "Content-Type: application/json" -d "{\"policy\": $pol}" >/dev/null 2>&1
    sleep 0.5
  done
}

# Payment Worker: Subscriber + Secret Accessor
safe_add_binding "serviceAccount:payment-worker@${PROJECT_ID}.iam.gserviceaccount.com" "roles/pubsub.subscriber"
safe_add_binding "serviceAccount:payment-worker@${PROJECT_ID}.iam.gserviceaccount.com" "roles/secretmanager.secretAccessor"

# Audit Archiver: Subscriber + Storage Object Creator
safe_add_binding "serviceAccount:audit-archiver@${PROJECT_ID}.iam.gserviceaccount.com" "roles/pubsub.subscriber"

$GCLOUD storage buckets add-iam-policy-binding "$BUCKET_NAME" \
  --member="serviceAccount:audit-archiver@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectCreator" >/dev/null 2>&1 || true

echo "=========================================================="
echo "✅ All resources provisioned successfully!"
echo "Pub/Sub Topic:      $TOPIC_NAME"
echo "Sub 1:              $SUB_PAYMENTS"
echo "Sub 2:              $SUB_AUDIT"
echo "Secret:             $SECRET_NAME"
echo "GCS Bucket:         $BUCKET_NAME"
echo "=========================================================="
